extends "res://tests/stability_render_v30.gd"
## Functional GL coverage beyond the 120-second city segment of the fixed soak.
## This fixture is equipped and invulnerable, never a legal-start score or FPS proof.
func run()->void:
	check(OS.get_user_data_dir().replace("\\","/").begins_with(OUTPUT_ROOT),"isolated city Rush profile")
	if failures:get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true
	SaveService.data.reduced_motion=true;Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var kills:Array=[];var phases:Dictionary={}
	EventBus.boss_defeated.connect(func(id:StringName)->void:kills.append(str(id)))
	_clock_start=Time.get_ticks_msec();_segment_index=1;await begin_segment(1);await enter_arena(0)
	var game_seconds:=0.0;var wall:=Time.get_ticks_msec()
	while game_seconds<600 and Time.get_ticks_msec()-wall<300000 and not main.safe_room():
		if UIFlow.has_screen():main.gm_pilot._advance_screen()
		var boss:=main.director.boss as RoomBoss
		if is_instance_valid(boss):phases[str(boss.boss_id)+":"+str(boss.phase)]=true
		await get_tree().process_frame
		if not get_tree().paused:game_seconds+=get_process_delta_time()
	check(kills==["sephra","verena","nameless"],"complete actual city three-boss Rush in order")
	check(main.safe_room() and main.director.rush_index==2,"city Rush room cleared through production director")
	var result:={"kills":kills,"phases_observed":phases.keys(),"game_seconds":game_seconds,"wall_seconds":(Time.get_ticks_msec()-wall)/1000.0,"passed":failures==0,"QA_equipped_invulnerable":true,"not_legal_start_or_fps_proof":true}
	var file:=FileAccess.open(OUTPUT_ROOT+"city-rush.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	GameState.gm_pilot_active=false;GameState.run_active=false;main.queue_free();await frames(4);await get_tree().create_timer(.1,true,false,true).timeout;AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout
	print("CITY_RUSH_V30 checks=",checks," failures=",failures," result=",JSON.stringify(result));get_tree().quit(1 if failures else 0)
