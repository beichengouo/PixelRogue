extends Node
## 音效管理：统一播放接口 + 播放器池。
##
## 战斗事件自动出声（接在信号总线上），需要精确时机的地方（跳跃、挥砍、拾取）
## 由调用方直接 play()。想换音效，把 assets/sfx/ 下的同名 wav 替换即可。

const SFX_DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"
const ROOM_MUSIC := preload("res://src/data/room_music_catalog.gd")
## Menu MP3s are user-provided: E:/素材/轻盈哼唱.mp3 and 轻盈哼唱 (1).mp3.
## Forest/king/mage originate in tools/build_music.gd; Tide in build_tide_music.gd.
const POOL_SIZE := 12
const CUE_SOURCE:={"skill_unavailable":"ui_click","purchase_failed":"ui_click","shield_hit":"hit","shield_break":"land","reward_claim":"coin","boss_warning":"wave_start"}
const CUE_PITCH:={"skill_unavailable":.78,"purchase_failed":.72,"shield_hit":1.3,"shield_break":.8,"reward_claim":1.15,"boss_warning":.9}
const CUE_GAPS:={"hit":65,"swing":70,"enemy_die":80,"enemy_shoot":85,"coin":70,"skill_unavailable":300,"purchase_failed":250,"shield_hit":120,"shield_break":200,"boss_warning":150}
var _priority_voices:Dictionary={}
const DEDUP_MS := 30          # 同一音效在这段时间内不重复播，避免连发时糊成噪音

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}
var _achievement_player:AudioStreamPlayer
## Two reused music players crossfade without stopping the incoming music.
var _music_player: AudioStreamPlayer
var _music_spare: AudioStreamPlayer
var _outgoing_gain := 0.0
var _music_streams: Dictionary = {}
var _current_music: StringName = &""
var _music_volume := 0.7
var _music_tween: Tween
var _music_gain := 1.0
var _music_epoch := 0
var _music_context: StringName = &""
var _active_boss: StringName = &""
var _room_music_synced := false
var _room_music_group: StringName = &""
var _environment_group: StringName = &""
var _environment_index := 0
var _environment_playlist_active := false
var _gameplay_loading := false


func _ready() -> void:
	if "--room-editor" in OS.get_cmdline_user_args(): return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_streams()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_connect_events()
	set_master_volume(float(SaveService.data.get("master_volume", 0.8)))
	_sfx_volume = float(SaveService.data.get("sfx_volume", 0.9))
	_music_volume = float(SaveService.data.get("music_volume", 0.7))
	_load_music()
	UIFlow.stack_changed.connect(_sync_screen_music)


## ---------------- BGM ----------------

func _load_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "BackgroundMusic"
	_music_player.bus = "Master"
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished.bind(_music_player))
	_music_spare=AudioStreamPlayer.new();_music_spare.name="BackgroundMusicCrossfade";_music_spare.bus="Master"
	add_child(_music_spare)
	_music_spare.finished.connect(_on_music_finished.bind(_music_spare))
	# ResourceLoader preserves original names in editor and exported PCKs.
	for file in ResourceLoader.list_directory(MUSIC_DIR):
		if not file.get_extension().to_lower() in ["wav", "mp3", "ogg"]:
			continue
		var loaded := load(MUSIC_DIR + file) as AudioStream
		if loaded == null: continue
		var stream := loaded.duplicate() as AudioStream
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = maxi(1, roundi(stream.get_length() * stream.mix_rate))
		elif stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
			stream.loop = true
			stream.loop_offset = 0.0
		_music_streams[file.get_basename()] = stream
	for id in ROOM_MUSIC.entries():
		var path: String = ROOM_MUSIC.entries()[id]
		if not ResourceLoader.exists(path):continue
		var loaded := load(path) as AudioStream
		if loaded==null:continue
		var stream := loaded.duplicate() as AudioStream
		# Every scene group alternates A/B. Its original tracks must never self-loop.
		if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:stream.loop=false
		elif stream is AudioStreamWAV:stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
		_music_streams[id]=stream


func play_music(id: StringName, fade := 0.6) -> void:
	var key := String(id)
	if not _music_streams.has(key) or not is_instance_valid(_music_player): return
	if _gameplay_loading and _music_context==&"gameplay":return
	if _active_boss != &"" and id != _boss_music_id(_active_boss): return
	# Once the room clock owns music, legacy forest requests cannot overwrite
	# the scene playlist. Boss requests retain higher priority.
	if _active_boss==&"" and _music_context==&"gameplay" and _room_music_synced:return
	if _current_music == id and (_music_player.playing or (_music_tween != null and _music_tween.is_running())): return
	_environment_playlist_active=false
	_crossfade_to(id,fade)

func _crossfade_to(id: StringName, fade: float, finish_outgoing := false) -> void:
	if not _music_streams.has(String(id)):return
	if _music_tween != null and _music_tween.is_valid(): _music_tween.kill()
	_music_epoch += 1
	var ticket := _music_epoch
	# On a rapid switch keep the louder previous track, then reuse the other slot.
	if _music_spare.playing and _outgoing_gain>_music_gain:
		var player := _music_player;_music_player=_music_spare;_music_spare=player
		var gain := _music_gain;_music_gain=_outgoing_gain;_outgoing_gain=gain
	var retained := _music_player
	var incoming := _music_spare
	var old_gain := clampf(_music_gain+_outgoing_gain,0,1) if retained.playing else 0.0
	incoming.stop();incoming.stream=_music_streams[String(id)]
	_music_player=incoming;_music_spare=retained
	_current_music = id
	_music_gain=0.0;_outgoing_gain=old_gain;_apply_music_volumes()
	incoming.play()
	if fade<=0:
		_mix_crossfade(1.0,ticket,old_gain)
		if not finish_outgoing:retained.stop();retained.stream=null
		return
	_music_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_method(_mix_crossfade.bind(ticket,old_gain),0.0,1.0,fade)
	_music_tween.tween_callback(func() -> void:
		if ticket!=_music_epoch:return
		# Natural A/B handoffs let the outgoing non-looping stream actually finish.
		if not finish_outgoing:retained.stop();retained.stream=null)

func _mix_crossfade(progress: float, ticket: int, outgoing_start: float) -> void:
	if ticket!=_music_epoch:return
	_music_gain=progress;_outgoing_gain=outgoing_start*(1.0-progress)
	_apply_music_volumes()

func stop_music(fade := 0.5) -> void:
	if _music_player == null: return
	_environment_playlist_active=false
	if _current_music==&"" and _music_tween!=null and _music_tween.is_running():return
	if _current_music==&"" and not _music_player.playing and not _music_spare.playing:return
	if _music_tween != null and _music_tween.is_valid(): _music_tween.kill()
	_current_music = &""
	_music_epoch += 1
	var ticket := _music_epoch
	var active_gain := _music_gain;var old_gain := _outgoing_gain
	var active := _music_player;var old := _music_spare
	_music_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_method(func(progress: float) -> void:
		if ticket!=_music_epoch:return
		_music_gain=active_gain*(1-progress);_outgoing_gain=old_gain*(1-progress);_apply_music_volumes(),0.0,1.0,maxf(0.0,fade))
	_music_tween.tween_callback(func() -> void:
		if ticket!=_music_epoch:return
		active.stop();active.stream=null;old.stop();old.stream=null)

func _set_music_gain(value: float) -> void:
	_music_gain = value
	_apply_music_volumes()

func _apply_music_volumes() -> void:
	if is_instance_valid(_music_player):
		_music_player.volume_db=linear_to_db(maxf(0.00001,_music_volume*_music_gain))
	if is_instance_valid(_music_spare):
		_music_spare.volume_db=linear_to_db(maxf(0.00001,_music_volume*_outgoing_gain))

func _restart_finished_music() -> void:
	_on_music_finished(_music_player)

func _on_music_finished(player: AudioStreamPlayer) -> void:
	# A queued finished notification from an older use of this slot cannot
	# advance or restart its replacement, which is already playing.
	if player.playing:return
	if player!=_music_player:return
	if _current_music == &"" or not _music_streams.has(String(_current_music)): return
	if _environment_playlist_active:
		_advance_environment();return
	if player.stream==_music_streams[String(_current_music)]:player.play()

func sync_room_music(minutes: float, weather_kind: String) -> void:
	_room_music_group=ROOM_MUSIC.group(minutes,weather_kind)
	_room_music_synced=true
	if _active_boss!=&"" or _music_context!=&"gameplay" or not GameState.run_active:return
	_apply_room_music()

func _apply_room_music() -> void:
	if _gameplay_loading or not _room_music_synced or _active_boss!=&"" or _music_context!=&"gameplay":return
	if _room_music_group==&"":
		_environment_group=&"";_environment_index=0
		stop_music(ROOM_MUSIC.CROSSFADE_SECONDS);return
	var tracks: PackedStringArray = ROOM_MUSIC.tracks(_room_music_group)
	if tracks.is_empty() or not _music_streams.has(tracks[0]) or not _music_streams.has(tracks[1]):
		stop_music(ROOM_MUSIC.CROSSFADE_SECONDS);return
	if _environment_group==_room_music_group and _environment_playlist_active and _music_player.playing:return
	if _environment_group!=_room_music_group:_environment_index=0
	_environment_group=_room_music_group;_environment_playlist_active=true
	_crossfade_to(StringName(tracks[_environment_index]),ROOM_MUSIC.CROSSFADE_SECONDS)

func _process(_delta: float) -> void:
	if not _environment_playlist_active or _active_boss!=&"" or _music_context!=&"gameplay":return
	if _music_player==null or not _music_player.playing or _music_player.stream==null:return
	if _music_tween!=null and _music_tween.is_running():return
	var remaining := _music_player.stream.get_length()-_music_player.get_playback_position()
	if remaining<=ROOM_MUSIC.CROSSFADE_SECONDS:_advance_environment()

func _advance_environment() -> void:
	if not _environment_playlist_active or _active_boss!=&"" or _music_context!=&"gameplay":return
	if _environment_group!=_room_music_group:_apply_room_music();return
	var tracks: PackedStringArray = ROOM_MUSIC.tracks(_environment_group)
	if tracks.size()!=2:return
	_environment_index=(_environment_index+1)%2
	_crossfade_to(StringName(tracks[_environment_index]),ROOM_MUSIC.CROSSFADE_SECONDS,true)

func _boss_music_id(id: StringName) -> StringName:
	if str(id) in ChapterCatalog.bosses(ChapterCatalog.NEXT):return StringName("music_boss_"+str(ChapterCatalog.bosses(ChapterCatalog.FIRST)[ChapterCatalog.stage(str(id))]))
	return StringName("music_boss_%s" % id)

func play_menu(secondary := false) -> void:
	play_context(&"menu_secondary" if secondary else &"menu_main")

func begin_gameplay() -> void:
	_active_boss = &""
	_music_context = &"gameplay"
	_room_music_synced=false;_room_music_group=&"";_environment_group=&"";_environment_index=0
	_environment_playlist_active=false
	if not _gameplay_loading:play_music(&"music_forest")

func begin_gameplay_loading() -> void:
	# Preparation and loading share a track; play_music's same-track guard
	# preserves the playback position instead of restarting it.
	play_context(&"menu_secondary")
	_gameplay_loading=true

func finish_gameplay_loading() -> void:
	if not _gameplay_loading:return
	_gameplay_loading=false
	_music_context=&"gameplay"
	if _active_boss!=&"":play_music(_boss_music_id(_active_boss),0.4)
	elif _room_music_synced:_apply_room_music()
	else:play_music(&"music_forest")

func play_context(context: StringName) -> void:
	if context == &"gameplay":
		if _music_context != context: begin_gameplay()
		return
	_gameplay_loading=false
	_active_boss = &""
	_music_context = context
	_environment_playlist_active=false
	play_music(&"menu_humming" if context == &"menu_main" else &"menu_humming_alt")

func _sync_screen_music() -> void:
	var top := UIFlow.top_screen()
	if top == null:
		if GameState.run_active: play_context(&"gameplay")
		return
	var script := top.get_script() as Script
	var kind := script.get_global_name() if script != null else &""
	match kind:
		&"CampUI": play_context(&"camp")
		&"GameOverUI", &"ChapterEndUI": play_context(&"settlement")
		&"MainMenu":
			if not bool(top.get("_settings_only")):
				play_menu(int(top.get("_view")) != 0)


func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	SaveService.data["music_volume"] = _music_volume
	_apply_music_volumes()


func music_volume() -> float:
	return _music_volume


## ---------------- 音量 ----------------

var _sfx_volume := 0.9


func set_master_volume(value: float) -> void:
	SaveService.data["master_volume"] = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, value)))


func master_volume() -> float:
	return float(SaveService.data.get("master_volume", 0.8))


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	SaveService.data["sfx_volume"] = _sfx_volume


func sfx_volume() -> float:
	return _sfx_volume


func _load_streams() -> void:
	var files := ResourceLoader.list_directory(SFX_DIR)
	if files.is_empty():
		push_warning("找不到音效目录：%s（先跑 tools/build_sfx.gd）" % SFX_DIR)
		return
	for file in files:
		if not file.ends_with(".wav"):
			continue
		_streams[file.get_basename()] = load(SFX_DIR + file)


func play(sfx: StringName, volume_db := 0.0, pitch_variation := 0.06) -> void:
	var key := String(sfx)
	var source:String=CUE_SOURCE.get(key,key)
	if not _streams.has(source):return
	var now := Time.get_ticks_msec()
	if _last_played.has(key) and now - int(_last_played[key]) < int(CUE_GAPS.get(key,DEDUP_MS)):
		return
	_last_played[key] = now
	if key=="achievement_unlock":
		# A dense fight can recycle the combat pool before the chime finishes.
		# Unlocks have their own voice, still governed by the normal SFX volume.
		if not is_instance_valid(_achievement_player):
			_achievement_player=AudioStreamPlayer.new();_achievement_player.name="AchievementChime";add_child(_achievement_player)
		_achievement_player.stream=_streams[key]
		_achievement_player.volume_db=volume_db+linear_to_db(maxf(.0001,_sfx_volume))
		_achievement_player.pitch_scale=1
		_achievement_player.play()
		return
	var priority:="danger" if key=="boss_warning" else "hurt" if key in ["hurt","shield_break"] else "feedback" if CUE_SOURCE.has(key) or key in ["wave_clear","wave_start"] else ""
	if not priority.is_empty():
		if not is_instance_valid(_priority_voices.get(priority)):
			var voice:=AudioStreamPlayer.new();voice.name="Priority_"+priority;add_child(voice);_priority_voices[priority]=voice
		var voice:AudioStreamPlayer=_priority_voices[priority];voice.stream=_streams[source];voice.volume_db=volume_db+linear_to_db(maxf(.0001,_sfx_volume));voice.pitch_scale=float(CUE_PITCH.get(key,1.0));voice.play();return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[key]
	player.volume_db = volume_db + linear_to_db(maxf(0.0001, _sfx_volume))
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func _connect_events() -> void:
	EventBus.player_damaged.connect(func(_amount: float, _hp: float, _max_hp: float) -> void:
		play(&"hurt")
	)
	EventBus.enemy_died.connect(func(_kind: StringName, _where: Vector2, _coins: int) -> void:
		play(&"enemy_die", -4.0)
	)
	EventBus.wave_started.connect(func(_wave: int, _total: int) -> void:
		play(&"wave_start")
		# 普通波次：悠闲的森林曲（Boss 波会被 boss_started 换成专属曲）
		if _active_boss == &"" and GameState.run_active:
			_music_context = &"gameplay"
			if _room_music_synced:_apply_room_music()
			else:play_music(&"music_forest")
	)
	EventBus.boss_started.connect(func(boss_id: StringName) -> void:
		if not GameState.run_active: return
		_active_boss = boss_id
		_music_context = &"gameplay"
		_environment_playlist_active=false
		play_music(_boss_music_id(boss_id), 0.4)
	)
	EventBus.boss_defeated.connect(func(boss_id: StringName) -> void:
		if boss_id != _active_boss: return
		_active_boss = &""
		if _room_music_synced:_apply_room_music()
		else:play_music(&"music_forest", 1.2)
	)
	EventBus.run_started.connect(func(_id: int) -> void: begin_gameplay())
	EventBus.run_ended.connect(func(_wave: int, _coins: int) -> void: play_context(&"settlement"))
	EventBus.player_died.connect(func() -> void: play_context(&"settlement"))
	EventBus.wave_cleared.connect(func(_wave: int) -> void:
		play(&"wave_clear")
	)
	EventBus.item_acquired.connect(func(_item: Dictionary) -> void:
		play(&"ui_click")
	)
	EventBus.shop_opened.connect(func(_offers: Array) -> void:
		play(&"ui_click")
	)

func shutdown() -> void:
	_music_epoch += 1
	_current_music = &""
	_environment_playlist_active=false;_room_music_synced=false;_active_boss=&"";_gameplay_loading=false
	if _music_tween != null and _music_tween.is_valid(): _music_tween.kill()
	for player in _players:
		if is_instance_valid(player): player.stop(); player.stream = null
	if is_instance_valid(_music_player): _music_player.stop(); _music_player.stream = null
	if is_instance_valid(_music_spare): _music_spare.stop(); _music_spare.stream=null
	if is_instance_valid(_achievement_player):_achievement_player.stop();_achievement_player.stream=null
	for voice in _priority_voices.values():
		if is_instance_valid(voice):voice.stop();voice.stream=null
	_streams.clear()
	_music_streams.clear()

func _exit_tree() -> void:
	shutdown()
