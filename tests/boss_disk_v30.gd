extends "res://tests/boss_phases_v30.gd"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);SaveService.data.reduced_motion=true;TransitionLayer.boot_played=true
	var args:=OS.get_cmdline_user_args();var mode:=str(args[0]);var id:=str(args[1]);var version:=int(args[2]);var legacy:=args.size()>3 and args[3]=="legacy"
	if mode=="write":
		await begin(&"sylphiette");main.process_mode=Node.PROCESS_MODE_PAUSABLE;await clear_world()
		main.graph.begin(3001,ChapterCatalog.NEXT if id in ["sephra","verena","nameless"] else ChapterCatalog.FIRST,version==3);GameState.chapter_id=main.graph.chapter_id
		var destination:=main.graph.stage_terminal
		if version<3:
			var location:=RoomGraph.cell(main.graph.current)+Vector2i.RIGHT
			while main.graph.rooms.has(RoomGraph.key(location)):location+=Vector2i.RIGHT
			destination=RoomGraph.key(location);main.graph.rooms[destination]=main.graph._allocate(location,"boss",id);main.graph._connect(main.graph.current,destination)
		main.graph.current=destination;main.graph.rooms[destination].boss=id
		var record:Dictionary=main.graph.rooms[destination];record.terrain_layout=arena_record(id).terrain_layout;record.cleared=false;record.rewarded=false;record.encounter=20;record.strength=20
		var boss:RoomBoss=await spawn(id);boss.hp=boss.max_hp*.25;boss.phase=boss.phase_for_health();boss.phase_seen=boss.phase;boss.room_cooldown=1.7;boss.phase_presenting=true;actor._invuln=0
		main.director.room_record=record;main.director.phase=WaveDirector.Phase.FIGHT;main.director.room_pending.clear();boss._bullet(boss.position,Vector2.RIGHT,150,.35,{"life":5})
		var minion:=RoomEnemy.new();minion.configure(&"guard");minion.room=main.level;minion.director=main.director;minion.fx_root=main.fx_root;minion.setup(actor,main.level,1,1,1);minion.boss_wave_tag=boss.owner_tag+":survivor";minion.reward_uid="v30:disk:minion";main.enemies_root.add_child(minion);minion.hp=17;minion.set_physics_process(false)
		var snapshot:=GameState.snapshot();snapshot.world_state=main.expedition.snapshot();snapshot.world_state.graph.version=version
		if legacy:
			for entity:Dictionary in snapshot.world_state.graph.rooms[destination].delta.runtime.entities:
				if str(entity.script)=="res://src/room_mode/city_boss.gd":entity.fields.erase("boss_pattern_revision");entity.fields.timeline=[{"type":"repeat_pattern","left":.1}];entity.fields.phase_presenting=false
		check(SaveService.save_run(snapshot),"boss checkpoint committed to isolated disk "+id)
	else:
		var snapshot:=SaveService.run_info().duplicate(true);check(not snapshot.is_empty(),"restart reads committed boss checkpoint")
		main=ProbeRoom.new();main.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(main);main._build_world();main._build_ui();main.set_process(false);await main._begin_run(snapshot);actor=main.player;main.director.set_process(false);actor.set_physics_process(false);GameState.set_process(false)
		var boss:=main.director.boss as RoomBoss
		check(is_instance_valid(boss),"live boss restored "+id)
		if is_instance_valid(boss):
			boss.set_physics_process(false)
			check(boss.boss_id==StringName(id) and is_equal_approx(boss.hp/boss.max_hp,.25),"boss identity and remaining HP unchanged")
			check(boss.phase==boss.phase_for_health() and not boss.phase_presenting and not get_tree().paused,"restored phase resumes without a blocking cut-in")
			check(BossStageArt.frames(boss.boss_id,boss.phase)==(boss.visual as AnimatedSprite2D).sprite_frames,"correct phase model after restart")
			check(boss.room_cooldown>0 and main.graph.staged==(version==3),"cooldown and legacy/staged graph preserved")
			if not legacy:check(actor._invuln>0 and boss.phase_guard_left>0,"interrupted transition buffers player and boss")
			else:
				check(boss.timeline.is_empty() and boss.recovery>0,"old city timeline retired")
				check(get_tree().get_nodes_in_group("room_projectiles").filter(func(n:Node)->bool:return n is BossPatternProjectile and not n.is_queued_for_deletion()).is_empty(),"old city projectiles retired")
		var minions:=main.enemies_root.get_children().filter(func(n:Node)->bool:return n is RoomEnemy and n.reward_uid=="v30:disk:minion")
		check(minions.size()==1 and minions[0].hp==17,"surviving add retained without healing or reward duplication")
		var committed:Dictionary=SaveService.data.run.duplicate(true);var bytes:=FileAccess.get_file_as_bytes(SaveService.SAVE_PATH);var blocker:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp"
		check(blocker.replace("\\","/").begins_with(ROOT) and DirAccess.make_dir_absolute(blocker)==OK,"save fault blocker isolated")
		var changed:Dictionary=committed.duplicate(true);changed["v30_fault"]=true
		check(not SaveService.save_run(changed) and SaveService.data.run==committed and FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)==bytes,"failed save leaves memory and disk untouched")
		check(DirAccess.remove_absolute(blocker)==OK,"save fault blocker removed")
		check(SaveService.save_run(GameState.snapshot().merged({"world_state":main.expedition.snapshot()},true)),"checkpoint resaves for repeat restart")
	await clear_world();await settle_actor();await seconds(.1);AudioManager.shutdown();await seconds(.25)
	print("BOSS_DISK_V30 checks=",checks," failures=",failures," boss=",id," version=",version," legacy=",legacy);get_tree().quit(1 if failures else 0)
