extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v33-bot-suspend/"
var ticks:=0
var screen:Control
var mode:="quit"
var suspended_tick:=-1
var committed:Dictionary={}
var disk_bytes:=PackedByteArray()
var capture_attached:=false
func _process(_dt:float)->void:ticks+=1
func emit_state(tag:String)->void:
	EngineDebugger.send_message("botprobe:state",[tag,{"checks":checks,"failures":failures,"can_process":UIFlow.can_process(),"paused":get_tree().paused,"active":GameState.gm_pilot_active,"ticks":ticks}])
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT) or not EngineDebugger.is_active():get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	mode=OS.get_cmdline_user_args()[0]
	EngineDebugger.register_message_capture("botprobe",receive)
	capture_attached=true
	await begin(&"ilyua");await frames(4)
	EngineDebugger.send_message("botprobe:ready",[mode,KEY_F9,KEY_F10])
func receive(message:String,args:Array)->bool:
	match message:
		"key":
			var event:=InputEventKey.new();event.keycode=int(args[0]);event.physical_keycode=int(args[0]);event.pressed=true
			get_window().window_input.emit(event)
			get_viewport().push_input(event,true)
			emit_state("key")
		"suspended":
			check(not UIFlow.can_process(),"native editor suspension is active")
			suspended_tick=ticks
			emit_state("suspended")
		"frozen":
			check(ticks==suspended_tick,"PROCESS_MODE_ALWAYS is frozen by real suspension")
			emit_state("frozen")
		"lease":
			screen=Control.new();add_child(screen);UIFlow.push_screen(screen);UIFlow.refresh()
			check(UIFlow.is_top(screen),"pause lease retained while engine is suspended")
			emit_state("lease")
		"resumed":
			check(UIFlow.can_process() and get_tree().paused,"resume reconciles pending pause lease")
			UIFlow.pop_screen(screen);screen.queue_free();screen=null
			check(not get_tree().paused,"last lease resumes ordinary play")
			emit_state("resumed")
		"block_save":
			check(SaveService.save_run(GameState.snapshot()),"pre-fault checkpoint committed")
			committed=SaveService.data.run.duplicate(true);disk_bytes=FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)
			var block:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp"
			check(block.replace("\\","/").begins_with(ROOT) and DirAccess.make_dir_absolute(block)==OK,"save blocker isolated")
			emit_state("block_save")
		"close":
			print("NATIVE_SUSPEND_V33 checks=",checks," failures=",failures," closing=",mode)
			SaveService.notification(NOTIFICATION_WM_CLOSE_REQUEST)
			if SaveService._quitting:detach_capture.call_deferred()
			if mode=="quit_fail" and not SaveService._quitting:
				check(SaveService.data.run==committed and FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)==disk_bytes,"suspended save failure preserves memory and disk")
				check(main.pause_ui.is_open(),"failed close leaves recoverable pause screen")
				emit_state("close_failed")
		"unblock":
			check(UIFlow.can_process() and get_tree().paused,"failed close pause lease restored on resume")
			check(DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp")==OK,"fault blocker removed")
			emit_state("unblock")
		"finish":finish.call_deferred()
		_:return false
	return true
func finish()->void:
	if GameState.gm_pilot_active:main.gm_pilot.stop()
	detach_capture()
	await settle_actor();AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout
	print("NATIVE_SUSPEND_V33 checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
func detach_capture()->void:
	if not capture_attached:return
	capture_attached=false
	EngineDebugger.unregister_message_capture("botprobe")
