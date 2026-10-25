extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v30-boss-phases/"
var report:Dictionary={"live":[],"cycles":[],"achievements":[],"coverage":{}}
var hurt_count:=0
func _hurt(_amount:float,_hp:float,_maximum:float)->void:hurt_count+=1
func seconds(value:float)->void:await get_tree().create_timer(value,true,false,true).timeout
func finish(label:String)->void:
	await seconds(.1);AudioManager.shutdown();await seconds(.25)
	report["pre_exit_caches"]={"health_profiles":UnitHealthArt._profiles.size(),"skill_detail":SizedSkillArt._cache.size(),"light_models":LightModelArt._cache.size(),"contact_banks":CombatContactFX._banks.size(),"boss_packs":BossEntranceArt._packs.size(),"fate_textures":FateSpellFX._textures.size(),"strike_shader":HostileAttackFX._strike_shader!=null}
	var file:=FileAccess.open(ROOT+label+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("FOREST_LIVE_V29 checks=",checks," failures=",failures," mode=",label);get_tree().quit(1 if failures else 0)
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	var args:=OS.get_cmdline_user_args();var mode:=str(args[0]) if args.size()>0 else "live"
	AchievementTracker.set_process(false);ErrorReporter.interactive=false;SaveService.data.reduced_motion=true;SaveService.data.control_setup_done=true;TransitionLayer.boot_played=true
	if mode=="empty":await finish(mode);return
	if mode=="resources":
		for kind in EnemyCombatPolicy.GOBLINS:PixelEnemyArt.make_frames(kind);HostileAttackFX.frames(str(kind),"flight")
		UnitHealthArt.profile("enemy");SizedSkillArt.warm();CombatContactFX.bank("holy")
		for id in BossPhaseRules.SKILLS:
			for phase in range(1,BossPhaseRules.thresholds(StringName(id)).size()):BossStageArt.frames(StringName(id),phase);BossStageArt.icon(StringName(id),phase)
		var room:=RoomLevel.new();var effect:=HostileAttackFX.strike(self,room,"king",{"at":Vector2(100,100),"shape":"circle","radius":48},.05)
		check(effect!=null and HostileAttackFX._shader!=null and HostileAttackFX._strike_shader!=null,"both hostile shader caches exercised")
		await seconds(.1);room.free()
		await finish(mode);return
	if mode=="shell":await shell_path();await finish(mode);return
	if mode=="pending_read":
		var saved:=SaveService.run_info().duplicate(true);var id:=Outpost.active_id();var gold:=int(Outpost.data.gold)
		check(not saved.is_empty() and str(saved.get("sortie_id",""))==id,"unmarked committed departure survives restart")
		main=ProbeRoom.new();add_child(main);main._build_world();main._build_ui();main.set_process(false);await main._begin_run(saved);actor=main.player
		check(Outpost.active_id()==id and int(Outpost.data.gold)==gold and is_instance_valid(actor),"resuming first room does not submit/charge departure twice")
		await settle_actor();await finish(mode);return
	if mode.begins_with("disk_read"):
		await disk_read(int(mode.get_slice(":",1)));await settle_actor();await finish(mode.replace(":","-"));return
	await begin(&"sylphiette");main.process_mode=Node.PROCESS_MODE_PAUSABLE;await clean()
	if mode=="pending_write":
		Outpost.data.active={};SaveService.data.run={};SaveService.data.rondo_core_migration=0
		check(Outpost.start_sortie([],0,0,1,1,ChapterCatalog.FIRST),"real departure commits before first room")
		await settle_actor();await finish(mode);return
	if mode.begins_with("disk_write"):
		await disk_write(int(mode.get_slice(":",1)));await settle_actor();await finish(mode.replace(":","-"));return
	if mode=="cycles":await cycles();await finish(mode);return
	if mode=="achievements":await achievements();await settle_actor();await finish(mode);return
	if mode=="migration":await migration_checks();await settle_actor();await finish(mode);return
	if mode=="backup_failure":await backup_failure();await settle_actor();await finish(mode);return
	EventBus.player_damaged.connect(_hurt)
	await live_combat();await matrix();await settle_actor();await finish(mode)
func clean()->void:
	main.dialogue.cancel();main.boss_intro.cancel();main.director.boss=null
	for root in [main.enemies_root,main.fx_root]:
		for node in root.get_children():root.remove_child(node);node.queue_free()
	for node in get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(node):node.queue_free()
	await frames()
func spawn(kind:StringName,at:Vector2)->RoomEnemy:
	var unit:=RoomEnemy.new();unit.configure(kind);unit.room=main.level;unit.director=main.director;unit.fx_root=main.fx_root;unit.setup(actor,main.level,1,1,1);unit.position=at
	main.enemies_root.add_child(unit);unit._action_cd=.05;return unit
func free_line()->Vector2:
	var bounds:=main.level.bounds().grow(-48)
	for y in range(int(bounds.position.y),int(bounds.end.y),24):
		for x in range(int(bounds.position.x),int(bounds.end.x)-200,24):
			var point:=Vector2(x,y);var good:=true
			for offset in range(0,201,20):good=good and main.level.body_clear(point+Vector2(offset,0),14,false)
			if good and main.level.sight(point,point+Vector2(200,0)):return point
	return Vector2(INF,INF)
func windup(unit:RoomEnemy,limit:=3.0)->bool:
	var start:=Time.get_ticks_msec()
	while is_instance_valid(unit) and unit._windup<=0 and Time.get_ticks_msec()-start<limit*1000:await get_tree().physics_frame
	return is_instance_valid(unit) and unit._windup>0
func live_combat()->void:
	var point:=free_line();check(point.is_finite(),"authored room contains clear test lane")
	if not point.is_finite():return
	actor.set_physics_process(true);actor.caster.set_physics_process(false);actor.hp=actor.max_hp;actor._invuln=0
	for evade in [false,true]:
		await clean();actor.position=point;actor.hp=actor.max_hp;actor._invuln=0
		var unit:=spawn(&"goblin_scout",point+Vector2(105,0));var before:=hurt_count
		check(await windup(unit),"scout approaches and enters real windup")
		check(unit.global_position.distance_to(actor.global_position)<=64 and unit._warning.visible,"scout telegraph occurs near its target")
		if evade:actor.position=main.level.nearest_clear(unit.position+Vector2(75,0),12,false)
		await seconds(.7)
		check((hurt_count>before)==(not evade),"real scout release respects moving target and facing "+str(evade))
		report.live.append({"kind":"goblin_scout","evaded":evade,"hurt_events":hurt_count-before,"windup":unit._windup,"position":str(unit.position)})
		if not evade:
			var prior:=hurt_count;await seconds(.25);check(hurt_count==prior,"no passive contact tick between knife releases")
		unit.queue_free();await frames()
	for kind in [&"goblin_spearman",&"goblin_mage"]:
		await clean();actor.position=point;actor.hp=actor.max_hp;actor._invuln=0
		var unit:=spawn(kind,point+Vector2(180,0));check(await windup(unit),"ranged AI selects legal firing line "+str(kind))
		var locked:=unit._locked_direction;check(unit._warning.visible,"ranged windup exposes warning")
		actor.position=main.level.nearest_clear(point+Vector2(0,65),12,false)
		var start:=Time.get_ticks_msec();var bullet:RoomProjectile
		while Time.get_ticks_msec()-start<1800 and not is_instance_valid(bullet):
			for node in get_tree().get_nodes_in_group("room_projectiles"):
				if node is RoomProjectile and node.hostile_fx==str(kind):bullet=node;break
			await get_tree().physics_frame
		check(is_instance_valid(bullet),"AI releases its visible projectile "+str(kind))
		if is_instance_valid(bullet):
			check(bullet.direction.dot(locked)>.98,"release respects locked telegraph direction")
			check(bullet.hostile_tracking==(kind==&"goblin_mage"),"straight javelin versus limited magic tracking")
			report.live.append({"kind":str(kind),"direction":str(bullet.direction),"speed":bullet.speed,"tracking":bullet.hostile_tracking})
		await clean();actor.position=point;unit=spawn(kind,point+Vector2(180,0));check(await windup(unit),"target loss fixture reaches real windup")
		actor.hp=0;await seconds(.85)
		var hostile:=0
		for node in get_tree().get_nodes_in_group("room_projectiles"):
			if node is RoomProjectile and node.hostile_fx==str(kind):hostile+=1
		check(hostile==0,"dead target cancels ranged release "+str(kind));actor.hp=actor.max_hp;await clean()
	# Existing authored walls must block the same AI sight test as the attack release.
	var blocked:=false;var bounds:=main.level.bounds().grow(-20)
	for y in range(int(bounds.position.y),int(bounds.end.y),24):
		if blocked:break
		for x in range(int(bounds.position.x),int(bounds.end.x)-80,24):
			var a:=Vector2(x,y);var b:=a+Vector2(80,0)
			if main.level.body_clear(a,12,false) and main.level.body_clear(b,12,false) and not main.level.sight(a,b):
				actor.position=a;var unit:=spawn(&"goblin_scout",b);var before:=hurt_count;await seconds(.35)
				check(hurt_count==before,"authored wall prevents a melee hit");unit.queue_free();blocked=true;break
	check(blocked,"actual wall scenario exercised")
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		await clean();get_window().size=extent;actor.position=point;actor._invuln=1000
		var units:Array[RoomEnemy]=[]
		for index in 3:units.append(spawn(EnemyCombatPolicy.GOBLINS[index],point+Vector2(80+index*50,0)))
		await seconds(1.1)
		for unit in units:
			var art:=unit.visual as AnimatedSprite2D;var foot:=art.position+Vector2(0,52)*art.scale
			check(unit.position.is_finite() and art.visible and is_equal_approx(foot.y,unit.body_size.y*.5),"live AI/model foot stable at "+str(extent))
	actor.set_physics_process(false);actor._invuln=0;report.coverage["live_physics"]=true
func matrix()->void:
	await clean()
	for difficulty in range(1,5):
		GameState.difficulty=difficulty
		var record:Dictionary=main.graph.rooms[main.graph.current];record.kind="normal";record.cleared=false;record.rewarded=false;record.strength=10;record.encounter=10;record.encounter_mode="spawned"
		main.director.enter_room(record);main.director.phase=WaveDirector.Phase.FIGHT
		for step in range(0,6):
			main.director.room_pressure_step=0;main.director.room_pressure_elapsed=0
			for kind in EnemyCombatPolicy.GOBLINS:
				var unit:=main.director._spawn_room_enemy(kind,main.level.nearest_clear(actor.position+Vector2(90,0),12,false)) as RoomEnemy;unit.set_physics_process(false)
				var damage:=unit.damage;var speed:=unit.move_speed;var health:=unit.max_hp
				main.director.advance_room_pressure(main.director.pressure_grace()+maxf(0,step-1)*20+.01 if step>0 else 0)
				check(unit.room_pressure_growth==step,"current difficulty/rage step "+str(difficulty)+str(step))
				check(is_equal_approx(unit.damage,damage*float(RoomDirector.PRESSURE_ATTACK[step])) and is_equal_approx(unit.move_speed,speed*float(RoomDirector.PRESSURE_SPEED[step])) and unit.max_hp==health,"rage applies attack/speed once, never health")
				var before:=unit.damage;main.director.advance_room_pressure(0);check(unit.damage==before,"reapplying same rage step is idempotent")
				for id:StringName in [EnemyAffixes.RANGED,EnemyAffixes.HUNTER_LOCK]:check((id in EnemyCombatPolicy.filtered_affixes(kind,[id]))==EnemyCombatPolicy.ranged_affix_allowed(kind),"weapon-compatible ranged affixes")
				unit.queue_free();await frames(1)
				main.director.room_pressure_step=0;main.director.room_pressure_elapsed=0
	GameState.difficulty=1;report.coverage["difficulty_rage"]=true
func achievements()->void:
	CampSession.active=false;GameState.run_active=true
	for kind in EnemyCombatPolicy.GOBLINS:
		for goal in [100,500,1000]:
			SaveService.data.achievements={};SaveService.data.achievement_stats={"migrated":true,"species_migrated":true};SaveService.data.achievement_stats["species:"+str(kind)]=goal-1
			var unit:=spawn(kind,main.level.nearest_clear(actor.position+Vector2(80,0),12,false));unit.set_physics_process(false)
			unit.take_damage(99999,false,unit.position,actor,false);unit.take_damage(99999,false,unit.position,actor,false);await frames()
			var id:="slayer_%s_%d"%[kind,goal]
			check(int(SaveService.data.achievement_stats.get("species:"+str(kind),0))==goal,"one real death increments exactly once "+id)
			check(AchievementCatalog.unlocked(id) and AchievementCatalog.progress(id)==goal and AchievementCatalog.icon(id)!=null,"kill unlock and visible emblem "+id)
			check(SaveService.save_data(),"achievement atomic save succeeds")
			var stored:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SaveService.SAVE_PATH));check(stored.achievements.has(id) and int(stored.achievement_stats["species:"+str(kind)])==goal,"achievement persists to disk")
			report.achievements.append({"id":id,"count":goal,"unlocked":AchievementCatalog.unlocked(id)})
		var previous:=int(SaveService.data.achievement_stats.get("species:"+str(kind),0))
		for excluded in ["training","summoned","split"]:
			var unit:=spawn(kind,main.level.nearest_clear(actor.position+Vector2(80,0),12,false));unit.set_physics_process(false);unit.training_target=excluded=="training";unit.loot_origin="normal" if excluded=="training" else excluded
			unit.take_damage(99999,false,unit.position,actor,false);await frames();check(int(SaveService.data.achievement_stats["species:"+str(kind)])==previous,"training/summoned/split kills excluded")
	SaveService.data.achievements={};SaveService.data.achievement_stats={"migrated":true,"species_migrated":true};SaveService.data.monster_kills={"moss_badger":9999,"bell_snail":9999};AchievementTracker._migrate()
	for kind in EnemyCombatPolicy.GOBLINS:check(int(SaveService.data.achievement_stats.get("species:"+str(kind),0))==0,"retired counters never migrate into goblin counters")
	check(AchievementCatalog.DATA.size()==125,"all nine goblin achievements present without duplicate IDs")
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(3)
		for entry:Dictionary in report.achievements:
			var toast:=AchievementToast.new();toast.achievement_id=str(entry.id);add_child(toast);toast.set_process(false);await frames(2);toast._fit()
			check(get_viewport().get_visible_rect().encloses(toast._panel.get_global_rect()),"goblin achievement toast fits "+str(entry.id)+str(extent))
			toast.queue_free();await frames(1)
	report.coverage["achievement_toasts"]=true
func disk_write(version:int)->void:
	if version<3:
		main.graph.begin(2901,ChapterCatalog.FIRST,false)
	# Preserve the staged graph's unique spawn node; save combat in a normal room.
	var destination:=""
	for candidate:Dictionary in main.graph.rooms.values():
		if str(candidate.kind)=="normal":destination=str(candidate.id);break
	if destination.is_empty():
		var cell:=RoomGraph.cell(main.graph.current)+Vector2i.RIGHT;destination=RoomGraph.key(cell)
		main.graph.rooms[destination]=main.graph._allocate(cell,"normal","");main.graph._connect(main.graph.current,destination)
	main.graph.current=destination
	await main.level.load_room_async(main.graph.rooms[destination],self);actor.position=main.level.nearest_clear(main.level.bounds().get_center(),12,false)
	var record:Dictionary=main.graph.rooms[main.graph.current];record.kind="normal";record.cleared=false;record.rewarded=false;record.encounter=10;record.strength=10
	main.director.enter_room(record);main.director.phase=WaveDirector.Phase.FIGHT;main.director._queue.clear()
	var unit:=spawn(&"goblin_scout",main.level.nearest_clear(actor.position+Vector2(75,0),12,false));unit.set_physics_process(false);unit.hp=17;unit.reward_uid="v29:disk:receipt";unit._windup=.3;unit._action_cd=1.7
	main.director.room_pending=[{"kind":&"bell_snail","at":actor.position+Vector2(110,0),"remaining":.5,"split":false,"origin":"normal","reinforcement":true}]
	var snapshot:=GameState.snapshot();snapshot.world_state=main.expedition.snapshot();snapshot.world_state.graph.version=version
	var room_id:String=main.graph.current
	for entity:Dictionary in snapshot.world_state.graph.rooms[room_id].delta.runtime.entities:
		if entity.fields.get("reward_uid","")=="v29:disk:receipt":entity.fields.kind={"$name":"moss_badger"};entity.fields.display_name="retired";entity.fields._rush=.2
	SaveService.data.achievement_stats["species:goblin_scout"]=100;SaveService.data.achievements.slayer_goblin_scout_100=1
	if version<3:SaveService.data.rondo_core_migration=0
	check(SaveService.save_run(snapshot),"old graph/checkpoint written to actual isolated save")
	report.coverage["disk_version"]=version
func migration_checks()->void:
	check(int(SaveService.data.rondo_core_migration)==SaveService.CORE_MIGRATION,"fresh profiles start with current migration marker")
	var legacy:Dictionary=SaveService.data.duplicate(true);legacy.run={"wave":12,"coins":30};legacy.rondo_core_migration=0;legacy.outpost=Outpost.data.duplicate(true)
	var stock:Dictionary=legacy.outpost.get("inventory",{}).duplicate(true);var gold:=int(legacy.outpost.get("gold",0))
	SaveService.data=legacy.duplicate(true);check(SaveService.save_data(),"legacy-format fixture committed")
	SaveService._migrate_room_only(legacy,SaveService.SAVE_PATH)
	check(SaveService.data.run.is_empty() and SaveService.data.outpost.active.is_empty() and SaveService.data.outpost.inventory==stock and int(SaveService.data.outpost.gold)==gold,"genuine legacy migration preserves permanent stock and retires unsupported run")
	check(FileAccess.file_exists(SaveService.SAVE_PATH+".pre_rondo_core.bak"),"legacy migration preserves original backup")
	var committed:Dictionary=SaveService.data.duplicate(true);SaveService._migrate_room_only(committed,SaveService.SAVE_PATH);check(SaveService.data==committed,"successful migration is idempotent")
	SaveService.take_migration_notice();SaveService.data=legacy.duplicate(true);check(SaveService.save_data(),"legacy failure fixture committed")
	var bytes:=FileAccess.get_file_as_bytes(SaveService.SAVE_PATH);var blocked:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp"
	check(blocked.replace("\\","/").begins_with(ROOT) and DirAccess.make_dir_absolute(blocked)==OK,"migration fault blocker isolated")
	SaveService._migrate_room_only(legacy,SaveService.SAVE_PATH)
	check(SaveService.data==legacy and FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)==bytes and SaveService.migration_notice.is_empty(),"failed migration preserves memory, disk and notice")
	check(DirAccess.remove_absolute(blocked)==OK,"migration blocker removed")
	for status:String in ["dead","extracted"]:
		var invalid:Dictionary=committed.duplicate(true);invalid.run={"combat_mode":"rooms","sortie_id":"matching","world_state":{"graph":{"version":3,"rooms":{"a":{}},"current":"a"}}};invalid.outpost.active={"id":"matching","status":status}
		check(not SaveService._has_room_checkpoint(invalid),"terminal departure cannot be preserved as active")
	SaveService.data=committed;Outpost.data.active={};GameState.run_active=false
func backup_failure()->void:
	var original:Dictionary=SaveService.data.duplicate(true);var legacy:Dictionary=original.duplicate(true)
	legacy.erase("rondo_core_migration");legacy.run={"wave":12,"coins":30}
	var target:=ProjectSettings.globalize_path(SaveService.SAVE_PATH);var backup:=target+".pre_rondo_core.bak";var held:=backup+".v29-held"
	check(backup.replace("\\","/").begins_with(ROOT),"backup fault remains inside isolated profile")
	var had_backup:=FileAccess.file_exists(backup)
	if had_backup:check(DirAccess.rename_absolute(backup,held)==OK,"original test backup held safely")
	check(DirAccess.make_dir_absolute(backup)==OK,"backup destination blocked by empty directory")
	SaveService.data=legacy;check(SaveService.save_data(),"unmarked legacy source committed")
	var bytes:=FileAccess.get_file_as_bytes(SaveService.SAVE_PATH);SaveService.data=original.duplicate(true)
	SaveService.load_data()
	print("BACKUP_FAULT_STATE ",JSON.stringify({"marker":SaveService.data.get("rondo_core_migration",-1),"run":SaveService.data.run,"expected_run":legacy.run,"bytes_equal":FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)==bytes}))
	var expected_run:Dictionary=JSON.parse_string(JSON.stringify(legacy.run))
	check(int(SaveService.data.get("rondo_core_migration",0))==0 and SaveService.data.run==expected_run and FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)==bytes,"failed backup must not mark an unmarked legacy profile migrated")
	check(DirAccess.remove_absolute(backup)==OK,"empty backup blocker removed")
	if had_backup:check(DirAccess.rename_absolute(held,backup)==OK,"original test backup restored")
	SaveService.data=original;check(SaveService.save_data(),"isolated profile restored after backup fault")
func disk_read(version:int)->void:
	var snapshot:=SaveService.run_info().duplicate(true);check(not snapshot.is_empty(),"previous process left a committed checkpoint")
	main=ProbeRoom.new();add_child(main);main._build_world();main._build_ui();main.set_process(false);await main._begin_run(snapshot);actor=main.player;main.director.set_process(false);actor.set_physics_process(false);GameState.set_process(false)
	check(main.graph.staged==(version==3),"graph version restores without regenerating")
	var found:=false
	for node in main.enemies_root.get_children():
		if not node is RoomEnemy:continue
		node.set_physics_process(false)
		if node.reward_uid=="v29:disk:receipt":
			found=true;check(node.kind==&"goblin_scout" and node.hp==17 and node._rush==0,"retired room actor remaps without healing/reward change")
			check(is_equal_approx(node._windup,.3) and is_equal_approx(node._action_cd,1.7),"windup and cooldown survive process restart")
	check(found,"saved actor exists after actual restart")
	check(AchievementCatalog.unlocked("slayer_goblin_scout_100"),"goblin achievement survives new process")
	main.director.set_process(true);await seconds(.8);main.director.set_process(false)
	for node in main.enemies_root.get_children():
		if node is EnemyBase:check(node.kind not in EnemyCombatPolicy.RETIRED,"restored pending queue never spawns retired species")
	var before:=main.expedition.snapshot();check(SaveService.save_run(GameState.snapshot().merged({"world_state":before},true)),"converted checkpoint resaves")
	var committed:Dictionary=SaveService.data.run.duplicate(true);var bytes:=FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)
	var blocked:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp";check(blocked.replace("\\","/").begins_with(ROOT),"fault blocker confined to isolated profile")
	check(DirAccess.make_dir_absolute(blocked)==OK,"actual save failure blocker created")
	var changed:Dictionary=committed.duplicate(true);changed["v29_fault_probe"]=true
	check(not SaveService.save_run(changed) and SaveService.data.run==committed and FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)==bytes,"save failure preserves committed run and disk bytes")
	check(DirAccess.remove_absolute(blocked)==OK,"isolated fault blocker removed")
	report.coverage["disk_version"]=version
func cycles()->void:
	var seed_snapshot:=GameState.snapshot();seed_snapshot.world_state=main.expedition.snapshot()
	await settle_actor()
	var reference_nodes:=-1;var reference_orphans:=-1;var reference_objects:=0;var reference_memory:=0.0;var reference_resources:=0
	# Scene/navigation LRUs need more than two visits to reach their bounded plateau.
	for index in 18:
		main=ProbeRoom.new();add_child(main);main._build_world();main._build_ui();main.set_process(false);await main._begin_run(seed_snapshot);actor=main.player;main.director.set_process(false);actor.set_physics_process(false);GameState.set_process(false)
		await settle_actor();await frames(12)
		var nodes:=get_tree().get_node_count();var orphans:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		var row:={"cycle":index,"nodes":nodes,"orphans":orphans,"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"memory":Performance.get_monitor(Performance.MEMORY_STATIC)};report.cycles.append(row)
		if index==7:
			reference_nodes=nodes;reference_orphans=orphans;reference_objects=int(row.objects);reference_memory=float(row.memory);reference_resources=int(row.resources)
		if index>7:
			check(nodes==reference_nodes and orphans==reference_orphans,"ten warmed lifecycle loops retain no live/orphan nodes "+str(index))
			check(int(row.resources)==reference_resources and int(row.objects)<=reference_objects+2 and float(row.memory)-reference_memory<=1048576,"warmed object/resource counts plateau; report overhead below 1MiB")
func shell_path()->void:
	SaveService.data.run={};Outpost.data.active={};SaveService.data.camp_tutorial.completed=true
	var shell:Node=load("res://src/main/game_shell.gd").new();shell._release_prompted=true;add_child(shell);await frames()
	await shell._open_camp("new");check(is_instance_valid(shell.camp) and shell.camp.initialization_success,"real shell enters camp")
	shell.camp.back_requested.emit();await frames(10);check(not is_instance_valid(shell.camp) and shell.menu.is_open(),"real shell returns to menu")
	shell.queue_free();await frames(8);report.coverage["shell_camp_menu"]=true
