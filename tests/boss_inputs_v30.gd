extends "res://tests/boss_phases_v30.gd"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=false
	Input.emulate_mouse_from_touch=true
	await begin(&"sylphiette");main.process_mode=Node.PROCESS_MODE_PAUSABLE
	for extent in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(5)
		for kind in ["keyboard","joypad","mouse","touch"]:
			var boss:RoomBoss=await spawn("sephra");boss.hp=boss.max_hp*.25;boss._physics_process(0);var ui:BossPhaseUI=boss._phase_ui
			await frames(5);check(get_viewport().get_visible_rect().encloses(ui._skip.get_global_rect()),"phase skip inside viewport "+str(extent)+kind)
			var started:=Time.get_ticks_msec()
			while ui.elapsed<.23 and Time.get_ticks_msec()-started<3000:await frames(1)
			ui._released=true
			if kind in ["keyboard","joypad"]:
				var event:InputEvent
				if kind=="keyboard":
					for binding:InputEvent in InputMap.action_get_events("ui_accept"):
						if binding is InputEventKey:event=binding.duplicate();break
					check(event!=null,"configured keyboard accept binding exists")
					if event==null:ui.finish();continue
					event.pressed=true
				else:
					var joy:=InputEventJoypadButton.new();joy.button_index=JOY_BUTTON_A;joy.pressed=true;event=joy
				get_viewport().push_input(event,true);await frames(2)
				event.pressed=false;get_viewport().push_input(event,true)
			else:
				var point:=ui._skip.get_global_rect().get_center()
				if kind=="mouse":
					var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;get_viewport().push_input(motion,true)
					for down in [true,false]:
						var mouse:=InputEventMouseButton.new();mouse.position=point;mouse.global_position=point;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=down;get_viewport().push_input(mouse,true);await frames(1)
				else:
					var physical:=get_viewport().get_screen_transform()*point
					for down in [true,false]:
						var touch:=InputEventScreenTouch.new();touch.index=0;touch.position=physical;touch.pressed=down;Input.parse_input_event(touch);await frames(2)
			await frames(3);check(not boss.phase_presenting and not get_tree().paused,"physical event skips phase "+str(extent)+kind)
			if boss.phase_presenting:ui.finish()
	get_window().size=Vector2i(1280,720);await clear_world();await settle_actor();await seconds(.1);AudioManager.shutdown();await seconds(.25)
	print("BOSS_INPUTS_V30 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
