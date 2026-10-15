extends Node
## 菜单不依赖关卡预加载。载入进度来自 ResourceLoader，实例化阶段单独提示。
const ROOM_PATH := "res://src/room_mode/room_main.tscn"
# Initialize this lightweight UI script dependency on the main thread.
# InventoryUI preloads it while the room scene compiles; leaving its first
# script load to that worker can stall cold threaded loading.
const INVENTORY_SHELL := preload("res://src/ui/inventory_shell.tscn")
var camp: CampWorld
var menu: MainMenu
var game: Node
var loading: CanvasLayer
var status: Label
var bar: ProgressBar
var _loading_chapter:Label
var busy := false
var _request_ok := false
var _load_epoch := 0
var _game_path := ROOM_PATH
var _review_dialogue: DialogueUI
var _resume_countdown:ResumeCountdown
var _booting := false
var _control_setup:ControlSetupUI
var _release_prompted:=false

func _process(_dt:float)->void:
	if busy or _booting or TransitionLayer.busy:return
	if not is_instance_valid(menu) or not menu.is_open() or not UIFlow.is_top(menu) or is_instance_valid(_control_setup):return
	if not bool(SaveService.data.get("control_setup_done",false)):
		_control_setup=ControlSetupUI.new();add_child(_control_setup);return
	if not _release_prompted and menu._view==MainMenu.View.MAIN and not menu._settings_only:
		_release_prompted=true
		if ReleaseNotes.needs_prompt():menu.open_release_notes()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = PixelUi.theme()
	# The process-wide autoload survives menu returns and combat-mode changes.
	if get_tree().root.has_meta("pending_departure"):
		TransitionLayer.boot_played = true
	elif not TransitionLayer.boot_played:
		_start_boot_sequence()
	menu = MainMenu.new()
	add_child(menu)
	menu.start_requested.connect(_open_camp)
	menu.continue_requested.connect(begin)
	menu.quit_requested.connect(func() -> void: SaveService.quit_game())
	menu.story_replay_requested.connect(_open_story_review)
	_build_loading()
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if get_tree().root.has_meta("pending_departure"):
		var pending:Dictionary=get_tree().root.get_meta("pending_departure")
		get_tree().root.remove_meta("pending_departure")
		begin(pending)
	elif get_tree().root.has_meta("pending_camp"):
		var entry:Dictionary=get_tree().root.get_meta("pending_camp");get_tree().root.remove_meta("pending_camp")
		if entry.has("character"):Characters.set_current(StringName(entry.character))
		_open_camp(str(entry.get("reason","new")))
	elif args.has("--autoplay"):
		begin({})
	else:
		menu.open()
	if _booting: TransitionLayer.set_loading_progress(-1.0,"旅途已备妥 · 正在迎接新的故事…")

func _start_boot_sequence() -> void:
	_booting = true
	var completed:bool = await TransitionLayer.play_boot_sequence("正在准备菜单与旅途资源…",self)
	if not is_instance_valid(self) or is_queued_for_deletion():return
	_booting = false
	if not completed and busy:
		_load_epoch += 1
		busy = false

func _open_story_review(id: StringName,character_id:StringName=&"") -> void:
	if busy: return
	if not is_instance_valid(_review_dialogue):
		_review_dialogue = DialogueUI.new()
		add_child(_review_dialogue)
	_review_dialogue.play_replay(id,character_id)

func _build_loading() -> void:
	loading = CanvasLayer.new()
	loading.layer = 40
	add_child(loading)
	var root := UiFactory.full_rect()
	root.theme = PixelUi.theme()
	loading.add_child(root)
	var background := TextureRect.new()
	background.texture = load("res://assets/art_phase4/forest_backdrop_v1.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.055, 0.09, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var frame := StarUi.frame(root, Vector2(980, 580))
	var panel := PixelUi.panel()
	panel.position = Vector2(60, 310)
	panel.size = Vector2(860, 248)
	frame.add_child(panel)
	var box := UiFactory.vbox(18)
	panel.add_child(box)
	box.add_child(PixelUi.label("旅途将启  /  A NEW JOURNEY", 15, PixelUi.GOLD))
	_loading_chapter=PixelUi.title("苏醒林地",32);box.add_child(_loading_chapter)
	status = PixelUi.label("正在载入旅途…", 18)
	box.add_child(status)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.add_theme_stylebox_override("background", PixelUi.style(PixelUi.NIGHT, PixelUi.LINE, 0, 0))
	bar.add_theme_stylebox_override("fill", PixelUi.style(PixelUi.GOLD, PixelUi.GOLD, 0, 0))
	box.add_child(bar)
	box.add_child(PixelUi.label("火焰照亮前路，自然守护旅途。", 15, PixelUi.MUTED))
	loading.visible = false

func begin(snapshot: Dictionary) -> void:
	if busy or (is_instance_valid(_review_dialogue) and _review_dialogue.is_open()): return
	var destination:=ChapterCatalog.normalize(snapshot.get("chapter_id",snapshot.get("departure",{}).get("chapter_id",ChapterCatalog.FIRST)))
	_loading_chapter.text=ChapterCatalog.title(destination)
	busy = true
	if is_instance_valid(camp):camp._leave_camp();remove_child(camp);camp.queue_free();camp=null
	AudioManager.begin_gameplay_loading()
	_load_epoch += 1
	var ticket := _load_epoch
	_game_path=ROOM_PATH
	# Start I/O before the cover; short loads finish inside the same pass.
	if not _request_ok:
		var error := ResourceLoader.load_threaded_request(_game_path, "PackedScene", false)
		if error != OK:
			_failed("资源载入失败（%d）" % error)
			return
		_request_ok = true
	# I/O may start during the cold intro; its cover begins only after that lease ends.
	while _booting:
		await get_tree().process_frame
		if ticket != _load_epoch:return
	if not await TransitionLayer.cover(ChapterCatalog.title(destination)+" · 旅途将启", "goddess", self):
		if ticket == _load_epoch: _failed("转场暂时无法开始")
		return
	if ticket != _load_epoch: return
	menu.close()
	UIFlow.push_screen(loading)
	var progress: Array = []
	var load_started := Time.get_ticks_msec()
	while ticket == _load_epoch:
		if Time.get_ticks_msec() - load_started > 60000:
			_failed("载入超时，可重试或返回")
			return
		var state := ResourceLoader.load_threaded_get_status(_game_path, progress)
		if state == ResourceLoader.THREAD_LOAD_LOADED: break
		if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_failed("冒险资源暂时无法载入")
			return
		var fraction := float(progress[0]) if not progress.is_empty() else 0.0
		bar.value = fraction * 100.0
		TransitionLayer.set_loading_progress(fraction, "正在载入"+ChapterCatalog.title(destination)+"与冒险资源 · %d%%" % int(fraction * 100.0))
		await get_tree().process_frame
	if ticket != _load_epoch: return
	# Let the worker release its completed task before collecting the resource.
	await get_tree().process_frame
	if ticket != _load_epoch: return
	var scene := ResourceLoader.load_threaded_get(_game_path) as PackedScene
	_request_ok = false
	if scene == null:
		_failed("冒险场景读取失败")
		return
	TransitionLayer.set_loading_progress(-1.0, "正在布置场景与角色…")
	await get_tree().process_frame
	if ticket != _load_epoch: return
	AudioManager.begin_gameplay()
	# Saved identity must precede construction of character-dependent menus and art.
	if snapshot.has("character"): Characters.set_current(StringName(snapshot.character))
	game = scene.instantiate()
	game.set("show_menu_on_ready", false)
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if not args.has("--autoplay"): await game.call("_begin_run", snapshot)
	if ticket != _load_epoch: return
	_resume_countdown=game.call("prepare_resume_countdown",snapshot)
	await get_tree().process_frame
	if ticket != _load_epoch: return
	loading.visible = false
	UIFlow.pop_screen(loading)
	await TransitionLayer.uncover()
	if ticket != _load_epoch: return
	AudioManager.finish_gameplay_loading()
	if is_instance_valid(_resume_countdown):
		await _resume_countdown.play()
		if ticket != _load_epoch:return
		_resume_countdown.queue_free();_resume_countdown=null
	menu.queue_free()
	if is_instance_valid(camp):camp.queue_free()
	if is_instance_valid(_review_dialogue): _review_dialogue.queue_free()
	loading.queue_free()
	busy = false

func cancel_loading() -> void:
	_failed("载入已取消")

func _exit_tree() -> void:
	_load_epoch += 1
	if busy or _booting:
		if TransitionLayer._request_owner!=null and TransitionLayer._request_owner.get_ref()==self:TransitionLayer.cancel()
	if _request_ok:
		var state:=ResourceLoader.load_threaded_get_status(_game_path)
		if state in [ResourceLoader.THREAD_LOAD_LOADED,ResourceLoader.THREAD_LOAD_FAILED]: ResourceLoader.load_threaded_get(_game_path)

func _failed(reason: String) -> void:
	_load_epoch += 1
	TransitionLayer.cancel()
	if is_instance_valid(camp):
		camp._leave_camp();remove_child(camp);camp.queue_free();camp=null
	if is_instance_valid(_resume_countdown):
		_resume_countdown.cancel();_resume_countdown.queue_free();_resume_countdown=null
	if is_instance_valid(game):
		game.queue_free()
		game = null
	status.text = reason + "，正在返回菜单。"
	push_warning(reason)
	loading.visible = false
	UIFlow.pop_screen(loading)
	busy = false
	if _request_ok:
		var load_state := ResourceLoader.load_threaded_get_status(_game_path)
		if load_state==ResourceLoader.THREAD_LOAD_FAILED: ResourceLoader.load_threaded_get(_game_path)
		# Retry reuses a pending request instead of creating an unconsumed duplicate.
		_request_ok = load_state in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]
	menu.set_notice(reason + "，请重试。")
	menu.open()

func _open_camp(reason:="new") -> void:
	if busy or is_instance_valid(camp):return
	if not bool(SaveService.data.get("control_setup_done",false)):
		if not is_instance_valid(_control_setup):_control_setup=ControlSetupUI.new();add_child(_control_setup)
		var open_after_choice:=_open_camp.bind(reason)
		if not _control_setup.chosen.is_connected(open_after_choice):_control_setup.chosen.connect(open_after_choice,CONNECT_ONE_SHOT)
		return
	busy=true;_load_epoch+=1
	var ticket:=_load_epoch
	while _booting:
		await get_tree().process_frame
		if ticket!=_load_epoch:return
	# Returning from extraction may already own a covered transition.
	var covered_here:=not TransitionLayer.busy
	if covered_here:
		if not await TransitionLayer.cover("星辉回廊 · 进入营地","goddess",self):
			if ticket==_load_epoch:_failed("营地转场暂时无法开始")
			return
		if ticket!=_load_epoch:return
		TransitionLayer.set_loading_progress(-1.0,"正在布置营地与训练场…")
		await get_tree().process_frame
		if ticket!=_load_epoch:return
	menu.close()
	camp=CampWorld.new();camp.entry_reason=reason
	if covered_here:camp.loading_transition_epoch=TransitionLayer._epoch
	add_child(camp)
	var load_started:=Time.get_ticks_msec()
	while is_instance_valid(camp) and not camp.initialization_complete:
		if Time.get_ticks_msec()-load_started>60000:
			_failed("营地载入超时，可重试或返回");return
		await get_tree().process_frame
		if ticket!=_load_epoch:return
	if not is_instance_valid(camp) or not camp.initialization_success:
		_failed("营地资源暂时无法载入");return
	camp.departure_requested.connect(begin);camp.resume_requested.connect(begin)
	camp.back_requested.connect(func()->void:
		if is_instance_valid(camp):remove_child(camp);camp.queue_free();camp=null
		menu.open())
	if covered_here:
		await get_tree().process_frame
		if ticket!=_load_epoch:return
		await TransitionLayer.uncover()
		if ticket!=_load_epoch:return
	busy=false
