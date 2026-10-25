extends "res://tests/extraction_stages_v31.gd"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/work/v34-gameplay-polish/"):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);Outpost.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=false;SaveService.data.control_setup_done=true
	StoryState.flags.chapter_2_unlocked=true
	for chapter:StringName in [ChapterCatalog.FIRST,ChapterCatalog.NEXT]:
		for stage in range(1,5):await direct_sample(chapter,stage)
	AudioManager.shutdown();await get_tree().create_timer(.3,true,false,true).timeout
	print("DIRECT_GATE_V34 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
func direct_sample(chapter:StringName,stage:int)->void:
	SaveService.data.run={};Outpost.data.active={};Outpost.data.inventory={"forest_sample":5};Outpost.data.gold=0;Outpost.pending_checkpoint=false
	Characters.set_current(&"ilyua");GameState.new_run(4501);GameState.chapter_id=chapter
	check(Outpost.start_sortie([],0,0,1,1,chapter),"real direct-gate departure")
	GameState.sortie_id=Outpost.active_id();GameState.fate.star_pending=false
	var graph:=RoomGraph.new();graph.begin(4501,chapter)
	for previous in range(1,stage):
		graph.enter(graph.stage_terminal);graph.clear_current();graph.rooms[graph.current].rewarded=true;check(graph.advance_stage(),"prior terminal finished")
	graph.enter(graph.stage_terminal);graph.clear_current();graph.rooms[graph.current].rewarded=true;GameState.chapter_cleared=graph.normal_clear_eligible
	var snap:=GameState.snapshot();snap.world_state={"graph":graph.snapshot()}
	var room:=ProbeRoom.new();add_child(room);room._build_world();room._build_ui();room._connect_events();await room._begin_run(snap)
	var player:RoomPlayer=room.player
	player.set_physics_process(false);player.caster.set_physics_process(false);player.equipment_mechanics.set_process(false);GameState.set_process(false)
	for node in [room.director,room.special_rooms,room.expansion,room.expedition,room.gm_pilot]:node.set_process(false)
	room._story_queue.clear();room._story_context="";room._reward_offers.clear();room._reward_pending.clear();room.dialogue.cancel();room.director._queue.clear();room.director.room_pending.clear()
	for enemy in room.enemies_root.get_children():room.enemies_root.remove_child(enemy);enemy.queue_free()
	room.graph.rooms[room.graph.current].cleared=true;room.graph.rooms[room.graph.current].rewarded=true;room._navigation_pending=false;room._room_transfer=false
	GameState.add_item(ExpeditionData.material("forest_sample"));var before:Dictionary=Outpost.data.duplicate(true);var carried:=GameState.items.duplicate(true)
	var extraction:RoomExtraction=room.expedition.extraction;extraction.set_process(false)
	var path:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp";DirAccess.make_dir_recursive_absolute(path)
	room.stage_gate.open();room.stage_gate._leave();await get_tree().process_frame
	check(not room.returned and GameState.run_active and Outpost.data.inventory==before.inventory and GameState.items==carried,"direct-gate save failure keeps bank and carried material")
	check(extraction.state==ExtractionDirector.IDLE and not room._navigation_pending and not TransitionLayer.busy,"failed direct exit gives control back without cinematic")
	DirAccess.remove_absolute(path);var epoch:=TransitionLayer._epoch
	room.stage_gate.open();room.stage_gate._leave();room.stage_gate._leave();await get_tree().process_frame
	check(room.returned and not GameState.run_active,"real stage menu commits return immediately")
	check(TransitionLayer._epoch==epoch and not TransitionLayer.busy,"direct exit never starts goddess transition")
	var result:Dictionary=Outpost.data.last_result
	check(str(result.get("clear_tier",""))==("extreme" if stage==4 else "normal" if stage==3 else "withdrawal"),"terminal clear qualification preserved")
	check(int(Outpost.data.inventory.get("forest_sample",0))==6,"success banks exactly one material")
	check(Outpost.settle_sortie("extracted").is_empty() and int(Outpost.data.inventory.get("forest_sample",0))==6,"direct exit cannot duplicate settlement")
	GameState.run_active=false;room.queue_free();await get_tree().process_frame;await get_tree().process_frame;Outpost.pending_checkpoint=false
