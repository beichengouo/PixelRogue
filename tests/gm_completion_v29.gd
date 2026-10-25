extends "res://tests/inventory_v17.gd"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/work/v29-forest-stability/"):get_tree().quit(2);return
	AchievementTracker.set_process(false);ErrorReporter.interactive=false;SaveService.data.reduced_motion=true;TransitionLayer.boot_played=true
	await begin(&"ilyua")
	for root in [main.chests_root,main.fx_root,main.enemies_root]:
		for child in root.get_children():root.remove_child(child);child.queue_free()
	await frames()
	main._reward_offers.clear();main._reward_pending.clear();main._story_queue.clear();main._story_context="";main.special_rooms.state["deliveries"]=[]
	var pilot:=main.gm_pilot as GMPilot;pilot.set_process(false);check(pilot.activate(),"legal GM activation")
	var graph:=main.graph as RoomGraph;var record:Dictionary=graph.rooms[graph.current]
	record.cleared=true;record.rewarded=true
	check(graph.current!=graph.stage_terminal,"fixture is away from boss terminal")
	for stage in [1,2,3,4]:
		main.expedition.extraction.cancel(false,false);graph.stage_index=stage;graph.stage_boss_cleared=false;graph.normal_clear_eligible=false
		GameState.mp=100;actor.hp=actor.max_hp;pilot._gear_elapsed=0;pilot._process(.1)
		check(main.expedition.extraction.state==ExtractionDirector.IDLE,"no premature departure at stage "+str(stage))
	graph.stage_index=3;graph.stage_boss_cleared=true;graph.normal_clear_eligible=true;GameState.chapter_cleared=true;GameState.mp=100
	pilot._process(.1)
	check(main.expedition.extraction.state==ExtractionDirector.PRAYING,"third-stage clear permits GM departure from another cleared room")
	var epoch:=main.expedition.extraction._epoch
	pilot._process(.1);await frames(3);pilot._process(.1)
	check(main.expedition.extraction.state==ExtractionDirector.PRAYING and main.expedition.extraction._epoch==epoch,"GM never repeats request to cancel a live prayer")
	pilot.stop();main.expedition.extraction.cancel(false,false);await settle_actor();AudioManager.shutdown();await frames()
	print("GM_COMPLETION_V29 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
