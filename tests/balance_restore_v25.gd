extends "res://tests/inventory_v17.gd"
## Snapshot and phase fixtures; these do not count as combat victories.
func clean()->void:
	main.boss_intro.cancel();main.director.boss=null
	for root in [main.enemies_root,main.fx_root]:
		for node in root.get_children():root.remove_child(node);node.queue_free()
	await frames()

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);SaveService.data.reduced_motion=true;TransitionLayer.boot_played=true
	for hero:StringName in [&"sylphiette",&"xixifu",&"ilyua"]:
		await begin(hero)
		for difficulty in range(1,5):await old_snapshot(difficulty)
		await settle_actor()
	await begin(&"ilyua")
	for chapter:StringName in [ChapterCatalog.FIRST,ChapterCatalog.NEXT]:
		main.graph.chapter_id=chapter
		for difficulty in range(1,5):await rush_and_sources(difficulty)
	await settle_actor();AudioManager.shutdown();await frames()
	print("BALANCE_RESTORE_V25 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)

func old_snapshot(difficulty:int)->void:
	await clean();GameState.difficulty=difficulty;GameState.run_active=true
	var d:=main.director as RoomDirector;var record:Dictionary=main.graph.rooms[main.graph.current]
	record.kind="normal";record.cleared=false;record.rewarded=false;record.encounter=10;record.strength=10;record.boss="";record.boss_stats={};record.encounter_mode="spawned"
	d.enter_room(record);d.phase=WaveDirector.Phase.FIGHT
	var enemy:=d._spawn_room_enemy(&"walker",main.level.nearest_clear(main.level.bounds().get_center(),14));enemy.set_physics_process(false)
	d.advance_room_pressure(d.pressure_grace()+80);enemy.hp=enemy.max_hp*.4
	var damage:=enemy.damage;var health:=enemy.max_hp
	var shot:=RoomProjectile.new();shot.room=main.level;shot.level=main.level;shot.player=actor;shot.is_friendly=false;shot.damage_owner=&"enemy";shot.damage=damage*.5;main.fx_root.add_child(shot);shot.set_physics_process(false)
	var hazard:=AffixHazard.create(main.fx_root,main.level,&"grave",enemy.position,Vector2.RIGHT,damage*.3,enemy);hazard.set_physics_process(false);hazard.age=-.4;hazard.tick_left=.2
	var saved:Dictionary=JSON.parse_string(JSON.stringify(main.expedition.capture_room()))
	var attack_inverse:=float([1.0,1.25,1.5,2.0][difficulty-1])/RunDifficulty.attack_multiplier(difficulty)
	var hp_inverse:=float(RunDifficulty.multiplier(difficulty))/RunDifficulty.health_multiplier(difficulty)
	for entry:Dictionary in saved.entities:
		var f:Dictionary=entry.fields;f.erase("combat_balance_revision")
		if f.has("room_pressure_growth"):
			f.room_pressure_growth=9;f.damage=float(f.damage)*10/1.65*attack_inverse;f._damage_scale=float(f._damage_scale)*10/1.65*attack_inverse
			f.move_speed=float(f.move_speed)*1.3/1.2;f._speed_scale=float(f._speed_scale)*1.3/1.2;f.hp=float(f.hp)*hp_inverse;f.max_hp=float(f.max_hp)*hp_inverse;f._hp_scale=float(f._hp_scale)*hp_inverse
		elif f.has("damage"):f.damage=float(f.damage)*10/1.65*attack_inverse
	for entry:Dictionary in saved.hazards:entry.erase("combat_balance_revision");entry.damage=float(entry.damage)*10/1.65*attack_inverse
	saved.director.erase("combat_balance_revision");saved.director.room_pressure_step=9;saved.director._damage_scale=float(saved.director._damage_scale)*attack_inverse;saved.director._hp_scale=float(saved.director._hp_scale)*hp_inverse
	saved.player.fields.erase("stat_balance_revision");saved.player.fields.hp=40.0;saved.player.fields.max_hp=100.0;saved.player.fields.bloodbath_hp_loss=20.0;saved.player.fields.cruel_hp_loss=5.0;saved.player.fields._dash_cd=1.25
	GameState.skill_cooldowns_by_id[GameState.skill_for_slot(0)]=3.25
	main.expedition.restore_room(saved,true)
	check(is_equal_approx(actor.hp/actor.max_hp,.4) and actor.permanent_hp_loss()==25,"actual player restore preserves injured ratio and scars")
	check(actor._dash_cd==1.25 and GameState.skill_cooldowns_by_id[GameState.skill_for_slot(0)]==3.25,"actual restore keeps cooldowns")
	for node in main.enemies_root.get_children():
		if node is EnemyBase:
			node.set_physics_process(false);check(is_equal_approx(node.damage,damage) and is_equal_approx(node.max_hp,health) and is_equal_approx(node.hp/node.max_hp,.4),"actual old enemy stats converted")
	for node in main.fx_root.get_children():
		node.set_physics_process(false)
		if node is RoomProjectile:check(is_equal_approx(node.damage,damage*.5),"actual old projectile uses saved rage before director restore")
		if node is AffixHazard:check(is_equal_approx(node.damage,damage*.3) and node.age==-.4 and node.tick_left==.2,"actual old hazard converts without rewinding timers")
	var roundtrip:=JSON.parse_string(JSON.stringify(main.expedition.capture_room())) as Dictionary
	main.expedition.restore_room(roundtrip,true)
	check(is_equal_approx(actor.hp/actor.max_hp,.4) and d.room_pressure_step==5,"converted read-save-read stable")
	actor.bloodbath_hp_loss=0;actor.cruel_hp_loss=0;actor.hp=actor.max_hp

func rush_and_sources(difficulty:int)->void:
	await clean();GameState.difficulty=difficulty;GameState.run_active=true
	var d:=main.director as RoomDirector;var record:Dictionary=main.graph.rooms[main.graph.current]
	record.kind="boss_rush";record.cleared=false;record.rewarded=false;record.encounter=50;record.strength=50;record.boss_stats={};record.delta={};main.graph.stage_index=4
	d.enter_room(record);d.room_pressure_elapsed=d.pressure_grace()+40;d.room_pressure_step=3
	for index in 3:
		await BossEntranceArt.warm_async(get_tree(),str(record.boss))
		var boss:=d._spawn_room_enemy(StringName("boss_"+str(record.boss)),main.level.nearest_clear(main.level.bounds().get_center(),26)) as RoomBoss
		boss.set_physics_process(false);main.boss_intro.cancel();d.phase=WaveDirector.Phase.FIGHT;d._queue.clear();d.room_pending.clear()
		check(boss.room_pressure_growth==3 and is_equal_approx(boss.damage,boss.base_damage*d._damage_scale*1.35),"rush boss inherits damage once")
		var initial_damage:=boss.damage
		for fraction in [.99,.49,.1]:
			boss.hp=boss.max_hp*fraction;boss._physics_process(0)
			check(boss.phase==boss.phase_for_health() and boss.damage==initial_damage,"boss phase does not multiply damage again")
			if is_instance_valid(boss._phase_ui):boss._phase_ui.finish()
		for origin in ["normal","boss_minion","guardian","split"]:
			var unit:=d._spawn_room_enemy(&"walker",boss.position+Vector2(50,0),origin=="split",origin)
			unit.set_physics_process(false)
			check(unit.room_pressure_growth==3 and is_equal_approx(unit.damage,unit.base_damage*d._damage_scale*1.35*(.4 if origin=="guardian" else 1.0)),"spawn source inherits pressure once "+origin)
		await clean();d._queue.clear();d.room_pending.clear();d.phase=WaveDirector.Phase.FIGHT
		if index<2:
			var age:=d.room_pressure_elapsed;d._on_wave_cleared();check(d.phase==WaveDirector.Phase.REST and d.rush_index==index+1,"rush continues through all three bosses")
			d.advance_room_pressure(15);check(d.room_pressure_elapsed==age,"rush rest pauses pressure")
			d._begin_rush_boss();check(d.room_pressure_step==3 and d.room_pressure_elapsed==age,"next boss carries rage clock")
