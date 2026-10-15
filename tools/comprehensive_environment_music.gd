extends Node
const CATALOG := preload("res://src/data/room_music_catalog.gd")
const OUTPUT := "E:/CodexWorkspace/PixelRogue/temp/comprehensive-environment-music-result.json"
var failures: Array[String] = []
var checks := 0
var durations := {}
var natural_finishes: Array[Dictionary] = []
var short_sequence: Array[String] = []
var overlap_samples := 0
var minimum_gain := 10.0
var started := 0
var real_progress := {}
var real_clear_progress := {}
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr("ENV_MUSIC_FAIL: "+label)
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds,true,false,true).timeout
func run() -> void:
	started=Time.get_ticks_msec()
	check(AudioManager.has_method("sync_room_music"),"Room clock/weather music API exists")
	check(CATALOG.group(400,"clear")==&"morning_clear","Clear skies select their dedicated scene group")
	if not failures.is_empty():finish();return
	AudioServer.set_bus_mute(0,true)
	check(AudioServer.get_driver_name()=="WASAPI","Real WASAPI driver")
	check(OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/test-userdata/comprehensive-environment-music/"),"Dedicated E profile")
	check(is_equal_approx(Engine.time_scale,1.0),"Normal simulation speed")
	Engine.max_fps=60
	check(CATALOG.entries().size()==24,"All twenty-four original music entries")
	for minutes in [299.0,300.0,719.999,720.0,1079.999,1080.0,1439.0,1440.0]:
		var expected: String = "morning" if minutes>=300 and minutes<720 else ("noon" if minutes>=720 and minutes<1080 else "night")
		check(CATALOG.period(minutes)==expected,"Period boundary "+str(minutes))
	check(CATALOG.group(400,"storm")==&"morning_rain","Storm reuses rain group")
	check(CATALOG.tracks(&"morning_clear").size()==2 and CATALOG.tracks(&"noon_clear").size()==2 and CATALOG.tracks(&"night_clear").size()==2,"Three clear-sky groups each have two tracks")
	for id in CATALOG.entries():
		var stream := AudioManager._music_streams.get(id) as AudioStreamMP3
		check(stream!=null and not stream.loop,"Non-looping loaded MP3: "+id)
		if stream!=null:
			durations[id]=stream.get_length();check(stream.get_length()>30,"Decoded original duration: "+id)
		var imported := ConfigFile.new()
		check(imported.load(CATALOG.entries()[id]+".import")==OK and not bool(imported.get_value("params","loop",true)),"Non-looping import metadata: "+id)
	for id in ["music_forest","music_boss_king","music_boss_mage","music_boss_tide"]:
		var stream := AudioManager._music_streams.get(id) as AudioStreamWAV
		check(stream!=null and stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Existing WAV loop retained: "+id)
	for id in ["menu_humming","menu_humming_alt"]:
		check((AudioManager._music_streams[id] as AudioStreamMP3).loop,"Existing menu loop retained: "+id)
	GameState.run_active=true
	AudioManager.begin_gameplay();AudioManager.sync_room_music(600,"rain")
	await wait(1.1)
	check(AudioManager._current_music==&"environment_morning_rain_1" and AudioManager._music_player.stream is AudioStreamMP3,"Actual original MP3 plays through AudioManager")
	var before := AudioManager._music_player.get_playback_position()
	await wait(2.0)
	var after := AudioManager._music_player.get_playback_position()
	real_progress={"id":String(AudioManager._current_music),"before_seconds":before,"after_seconds":after,"elapsed_seconds":2.0,"driver":AudioServer.get_driver_name(),"seek_used":false}
	check(after>before+1.5 and after<before+2.5,"Original MP3 advances at real speed without seek")
	var epoch := AudioManager._music_epoch
	AudioManager.sync_room_music(650,"rain")
	AudioManager.play_music(&"music_forest",0)
	EventBus.wave_started.emit(4,5)
	check(AudioManager._music_epoch==epoch,"Same group, same room transfer and wave/forest events do not restart music")
	var page := CanvasLayer.new();get_tree().root.add_child(page);UIFlow.push_screen(page)
	await wait(0.2);UIFlow.pop_screen(page);page.queue_free();await wait(0.2)
	check(AudioManager._music_epoch==epoch and AudioManager._current_music==&"environment_morning_rain_1","Gameplay UI pause/pop preserves environment track")
	AudioManager.sync_room_music(600,"snow")
	var changed_epoch := AudioManager._music_epoch
	await wait(0.25)
	check(AudioManager._music_player.playing and AudioManager._music_spare.playing,"Weather crossfade has two simultaneous real players")
	check(AudioManager._music_gain>0.1 and AudioManager._outgoing_gain>0.1,"Incoming/outgoing crossfade gains overlap")
	check(absf(AudioManager._music_gain+AudioManager._outgoing_gain-1.0)<0.03,"Crossfade total gain has no dip")
	AudioManager.sync_room_music(610,"snow")
	check(AudioManager._music_epoch==changed_epoch,"Repeated group during fade does not restart incoming music")
	AudioManager.sync_room_music(750,"fog");await wait(0.1);AudioManager.sync_room_music(1250,"storm")
	await wait(1.0)
	check(AudioManager._current_music==&"environment_night_rain_1" and not AudioManager._music_spare.playing,"Rapid changes leave only newest group")
	epoch=AudioManager._music_epoch;AudioManager._music_spare.finished.emit();AudioManager._music_player.finished.emit()
	check(AudioManager._music_epoch==epoch,"Obsolete finished notifications cannot change a playing replacement")
	EventBus.boss_started.emit(&"king");await wait(0.5)
	epoch=AudioManager._music_epoch
	AudioManager.sync_room_music(400,"fog");EventBus.wave_started.emit(10,2)
	check(AudioManager._current_music==&"music_boss_king" and AudioManager._music_epoch==epoch,"Boss protects music while pending group changes")
	EventBus.boss_defeated.emit(&"king");await wait(0.9)
	check(AudioManager._current_music==&"environment_morning_fog_1","Boss ending restores latest pending scene group")
	EventBus.boss_started.emit(&"mage");await wait(0.45);AudioManager.sync_room_music(900,"clear")
	check(AudioManager._current_music==&"music_boss_mage","Clear group during Boss keeps Boss playing")
	EventBus.boss_defeated.emit(&"mage");await wait(0.9)
	check(AudioManager._current_music==&"environment_noon_clear_1" and AudioManager._music_player.playing,"Boss ending restores current noon clear-sky group")
	before=AudioManager._music_player.get_playback_position();await wait(2.0);after=AudioManager._music_player.get_playback_position()
	real_clear_progress={"id":String(AudioManager._current_music),"before_seconds":before,"after_seconds":after,"elapsed_seconds":2.0,"seek_used":false}
	check(after>before+1.5 and after<before+2.5,"Actual clear-sky MP3 advances naturally")
	epoch=AudioManager._music_epoch
	AudioManager.sync_room_music(1000,"clear");EventBus.wave_started.emit(12,3);AudioManager.play_music(&"music_forest",0)
	check(AudioManager._music_epoch==epoch and AudioManager._current_music==&"environment_noon_clear_1","Clear-sky playlist survives repeat sync and ordinary forest requests")
	AudioManager.play(&"ui_click");check(AudioManager._players.any(func(player):return player.playing),"SFX remain active in clear weather")
	for pair in [[400,"environment_morning_clear_1"],[1300,"environment_night_clear_1"]]:
		AudioManager.sync_room_music(float(pair[0]),"clear");await wait(0.9)
		check(String(AudioManager._current_music)==pair[1] and AudioManager._music_player.playing,"Clear-sky music for period: "+str(pair[0]))
	AudioManager.sync_room_music(1300,"fog");await wait(0.9)
	AudioManager.stop_music(0.2);await wait(0.3);AudioManager.sync_room_music(1301,"fog");await wait(0.9)
	check(AudioManager._current_music==&"environment_night_fog_1" and AudioManager._music_player.playing,"Explicit stop can recover same room group")
	AudioManager.play_context(&"camp");AudioManager.sync_room_music(600,"snow");await wait(0.8)
	check(AudioManager._current_music==&"menu_humming_alt" and not AudioManager._environment_playlist_active,"Camp stops environment playlist")
	AudioManager.play_context(&"settlement");await wait(0.1)
	check(AudioManager._current_music==&"menu_humming_alt" and not AudioManager._environment_playlist_active,"Settlement stops environment playlist")
	AudioManager.play_menu();await wait(0.8)
	check(AudioManager._current_music==&"menu_humming" and not AudioManager._environment_playlist_active,"Main menu stops environment playlist")
	await short_playlist()
	finish()

func short_stream(id: String, pitch: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new();stream.mix_rate=22050;stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
	var data := PackedByteArray();data.resize(int(2.2*22050)*2)
	for i in int(data.size()/2):data.encode_s16(i*2,int(sin(float(i)/22050*TAU*pitch)*5000))
	stream.data=data;stream.set_meta("qa_id",id)
	return stream

func on_natural_finished(player: AudioStreamPlayer) -> void:
	if player.stream!=null and player.stream.has_meta("qa_id"):
		natural_finishes.append({"id":player.stream.get_meta("qa_id"),"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0})

func short_playlist() -> void:
	# Two transient, non-looping WAVs exercise actual natural endpoints quickly.
	# All user MP3s remain untouched and their real playback was checked above.
	AudioManager.stop_music(0);await wait(0.1)
	for index in [1,2]:
		var id := "environment_morning_clear_"+str(index)
		AudioManager._music_streams[id]=short_stream(id,220.0 if index==1 else 330.0)
	for player in [AudioManager._music_player,AudioManager._music_spare]:player.finished.connect(on_natural_finished.bind(player))
	AudioManager.begin_gameplay();AudioManager.sync_room_music(600,"clear")
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began<7500:
		await wait(0.025)
		var id := String(AudioManager._current_music)
		if short_sequence.is_empty() or short_sequence.back()!=id:short_sequence.append(id)
		if AudioManager._music_player.playing and AudioManager._music_spare.playing and AudioManager._music_gain>0.02 and AudioManager._outgoing_gain>0.02:overlap_samples+=1
		if Time.get_ticks_msec()-began>900:
			var gain := (AudioManager._music_gain if AudioManager._music_player.playing else 0.0)+(AudioManager._outgoing_gain if AudioManager._music_spare.playing else 0.0)
			minimum_gain=minf(minimum_gain,gain)
			check(gain>0.9,"A/B handoff has no silent gap")
	check(natural_finishes.any(func(item):return item.id=="environment_morning_clear_1") and natural_finishes.any(func(item):return item.id=="environment_morning_clear_2"),"Both clear-sky A and B reach actual natural finished events")
	check(short_sequence.size()>=4 and short_sequence[0]=="environment_morning_clear_1" and short_sequence[1]=="environment_morning_clear_2" and short_sequence[2]=="environment_morning_clear_1","Clear-sky playlist alternates A/B/A naturally")
	check(overlap_samples>10,"Natural handoffs overlap real playback")
	var epoch := AudioManager._music_epoch
	AudioManager.play_menu();await wait(1.0)
	check(AudioManager._current_music==&"menu_humming" and AudioManager._music_epoch==epoch+1,"Returning to menu cancels playlist successors")

func finish() -> void:
	GameState.run_active=false
	var result := {"passed":failures.is_empty(),"failures":failures,"checks":checks,"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0,"decoded_original_lengths":durations,"real_original_playback":real_progress,"real_clear_playback":real_clear_progress,"natural_short_stream_finishes":natural_finishes,"short_sequence":short_sequence,"crossfade_overlap_samples":overlap_samples,"minimum_handoff_gain":minimum_gain,"seek_used":false,"time_scale":Engine.time_scale,"driver":AudioServer.get_driver_name(),"profile":OS.get_user_data_dir()}
	var file := FileAccess.open(OUTPUT,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	print("ENVIRONMENT_MUSIC_RESULT ",JSON.stringify({"failures":failures,"passed":failures.is_empty(),"checks":checks,"natural_finishes":natural_finishes.size(),"overlap_samples":overlap_samples,"minimum_gain":minimum_gain,"real_original_playback":real_progress}))
	AudioManager.shutdown()
	get_tree().quit(0 if failures.is_empty() else 1)
