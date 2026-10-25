extends "res://tests/boss_flow_v31.gd"
## Resume an isolated natural campaign; door assistance never changes combat.
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(OUTPUT_ROOT):get_tree().quit(2);return
	var args:=OS.get_cmdline_user_args()
	hero=StringName(args[0]);chapter=ChapterCatalog.normalize(args[1]);seed_value=int(args[2])
	var source:=OUTPUT_ROOT+"profiles/flow-%s-%s/appdata/PixelRogue_CombatRevision_QA/pixel_rogue_save.json"%[hero,chapter]
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
	SaveService.data=saved.duplicate(true);Outpost.data=saved.outpost.duplicate(true)
	SaveService.data.reduced_motion=true;ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true
	var snapshot:Dictionary=saved.run.duplicate(true);snapshot.gm_pilot_used=false;snapshot.gm_pilot_active=false
	SaveService.data.run=snapshot.duplicate(true);Engine.max_fps=0;Engine.physics_ticks_per_second=60
	main=CampaignRoom.new();main.observer=self;main.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(main)
	main._build_world();main._build_ui();main._connect_events();await main._begin_run(snapshot)
	main.gm_pilot.activate();started=true
	var last_room:="";var stationary:=0.0
	while seconds<1600 and main.player.hp>0 and not main.returned and main.graph.defeated.size()<3:
		await get_tree().process_frame
		if main.graph.current!=last_room:last_room=main.graph.current;stationary=0
		if not get_tree().paused and main.safe_room() and not TransitionLayer.busy:stationary+=1.0/60
		if stationary>60:
			var exits:=main.gm_pilot._frontier_exits()
			if not exits.is_empty():
				set_meta("navigation_assistance",true)
				print("V31_NAVIGATION_ASSIST ",main.graph.current," -> ",exits[0])
				await main._change_room(RoomGraph.cell(exits[0])-RoomGraph.cell(main.graph.current))
			stationary=0
	started=false
	var file:=FileAccess.open(OUTPUT_ROOT+"resume-%s-%s.json"%[hero,chapter],FileAccess.WRITE)
	file.store_string(JSON.stringify({"state":state(),"navigation_assistance":get_meta("navigation_assistance",false)},"\t"));file.close()
	main.gm_pilot.stop();GameState.run_active=false;main.queue_free();await get_tree().process_frame;await get_tree().process_frame
	AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout;get_tree().quit()
