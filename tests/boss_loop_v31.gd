extends "res://tests/boss_phase_base_v31.gd"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);SaveService.data.reduced_motion=true;TransitionLayer.boot_played=true
	# Warm the complete finite resource set before looking for lifecycle growth.
	for id:String in BossPhaseRules.SKILLS:
		await BossEntranceArt.warm_async(get_tree(),id)
		for stage in range(1,BossPhaseRules.thresholds(StringName(id)).size()):BossStageArt.frames(StringName(id),stage);BossStageArt.icon(StringName(id),stage)
	var samples:Array=[];var baseline:Dictionary={}
	await begin(&"sylphiette");var snapshot:=GameState.snapshot();snapshot.world_state=main.expedition.snapshot();await settle_actor()
	for index in 18:
		main=ProbeRoom.new();main.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(main);main._build_world();main._build_ui();main.set_process(false);await main._begin_run(snapshot);actor=main.player
		GameState.set_process(false);actor.set_physics_process(false);actor.caster.set_physics_process(false);actor.equipment_mechanics.set_process(false);main.director.set_process(false);main.special_rooms.set_process(false);main.expansion.set_process(false);main.expedition.set_process(false)
		if is_instance_valid(actor.holy_runtime):actor.holy_runtime.set_process(false)
		for id:String in BossPhaseRules.SKILLS:
			var boss:RoomBoss=await spawn(id);boss.hp=boss.max_hp*.1;boss._physics_process(1.0/60);await frames(3);boss._phase_ui.finish();await frames(3)
		await clear_world();await settle_actor();await frames(12)
		var sample:={"iteration":index,"nodes":get_tree().get_node_count(),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"memory":Performance.get_monitor(Performance.MEMORY_STATIC)};samples.append(sample)
		if index==7:baseline=sample
		if index>7:
			check(sample.nodes==baseline.nodes and sample.orphans==baseline.orphans,"ten warmed Boss/UI enter-leave cycles retain no nodes or orphans "+str(index))
			check(sample.resources==baseline.resources and sample.objects<=baseline.objects+2 and sample.memory-baseline.memory<1048576,"Boss/UI objects and resources plateau "+str(index))
	await seconds(.1);AudioManager.shutdown();await seconds(.25)
	var file:=FileAccess.open(ROOT+"boss-loops.json",FileAccess.WRITE);file.store_string(JSON.stringify(samples,"\t"));file.close()
	print("BOSS_LOOP_V30 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
