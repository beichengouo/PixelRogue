extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v33-bot-suspend/"
func click(button:Button)->void:
	var point:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;get_viewport().push_input(event,true);await frames(2)
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	await begin(&"ilyua")
	for extent in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(5)
		var pause:PauseUI=main.pause_ui
		pause.open();await frames(20)
		var button:Button=pause._bot_test
		check(button.is_visible_in_tree() and get_viewport().get_visible_rect().encloses(button.get_global_rect()),"Bot button visible inside viewport "+str(extent))
		check(pause._panel.get_global_rect().encloses(button.get_global_rect()),"button adds no extra menu height "+str(extent))
		check(not button.get_global_rect().intersects(button.get_parent().get_child(0).get_global_rect()),"save and Bot buttons do not overlap")
		await click(button);check(GameState.gm_pilot_active and not get_tree().paused and not pause.is_open(),"mouse starts Bot and closes only pause lease")
		pause.open();await frames(20);check(button.text=="停止 Bot","active state updates menu action")
		await click(button);check(not GameState.gm_pilot_active and not get_tree().paused,"mouse stops and returns control")
		pause.configure_bot_test(false);pause.open();await frames(20)
		check(not button.visible,"release-style configuration hides test button")
		pause.close(true);pause.configure_bot_test(true)
	await settle_actor();AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout
	print("BOT_MENU_V33 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
