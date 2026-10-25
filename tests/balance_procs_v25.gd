extends "res://tests/inventory_v17.gd"
var mechanics:EquipmentMechanics
var target:EnemyBase
func select_relic(key:StringName)->void:
	GameState.items.clear();GameState.equipment.clear();GameState.add_item(ItemDB.by_id(key));mechanics.refresh();mechanics.cooldowns.clear()
	actor.shield_hp=0;actor._shield_time=0;target.hp=10000;target.max_hp=10000;target._burn_time=0;target._slow_time=0;GameState.mp=0
func receipt(critical:=false)->BasicAttackReceipt:
	var value:=BasicAttackReceipt.new(actor);value.critical=critical;return value
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);SaveService.data.reduced_motion=true
	await begin(&"sylphiette");GameState.talents.clear();GameState.fate=FateCatalog.empty();mechanics=actor.equipment_mechanics
	target=main.director._spawn_room_enemy(&"walker",actor.position+Vector2(50,0));target.set_physics_process(false)
	for lv in [1,100]:
		GameState.level=lv;GameState._reset_stats()
		select_relic(&"relic_spentmatch");target._burn_time=5;mechanics.wayfarer.basic(target,receipt());check(is_equal_approx(10000-target.hp,1.5),"spent match fixed damage level"+str(lv))
		select_relic(&"relic_quartz_moth");mechanics.wayfarer.basic(target,receipt());check(is_equal_approx(10000-target.hp,7) and GameState.mp==1,"quartz moth fixed damage and MP")
		select_relic(&"relic_half_star");mechanics.expansion.dash_until=mechanics.clock+5;mechanics.expansion.basic(target,receipt());check(is_equal_approx(10000-target.hp,3.5) and GameState.mp==2,"half star fixed damage and MP")
		select_relic(&"relic_leaf_page");mechanics.expansion.verse_until=mechanics.clock+4;mechanics.expansion.skill_hit(target);check(is_equal_approx(10000-target.hp,6),"leaf page fixed area damage")
		select_relic(&"relic_hunt_needle");target._slow_time=2
		var shot:=RoomProjectile.new();shot.position=target.position;mechanics.on_basic_hit(target,receipt(),shot);shot.free()
		check(is_equal_approx(10000-target.hp,4),"hunt needle fixed damage")
		select_relic(&"relic_wind_chime");actor._dash_cd=2;mechanics.wind_dash_serial+=1
		shot=RoomProjectile.new();shot.mechanic_tag=&"wind_fan";mechanics.on_basic_hit(target,receipt(),shot);shot.free()
		check(is_equal_approx(actor._dash_cd,1.3),"wind chime subtracts fixed seconds")
		select_relic(&"relic_broken_verse");mechanics.expansion.basic(target,receipt(true));check(is_equal_approx(actor.shield_hp,9),"broken verse fixed shield")
		select_relic(&"relic_wornbutton");mechanics.wayfarer.skill_hit(target);check(is_equal_approx(actor.shield_hp,5),"worn button fixed shield")
		select_relic(&"relic_afterglow_note");var room:Dictionary=main.graph.rooms[main.graph.current];room.delta.erase("afterglow_note_used");mechanics.on_room_enter(str(room.id),true)
		check(is_equal_approx(actor.shield_hp,30),"afterglow fixed shield")
		select_relic(&"relic_mist_dew");actor.hp=10;mechanics.expansion.skill_hit(target);check(is_equal_approx(actor.hp,13),"mist dew fixed healing")
		select_relic(&"relic_companion_knot")
		var allies:Array=[]
		for i in 2:
			var ally:=SummonedAlly.new();ally.player=actor;ally.room=main.level;ally.level=main.level;ally.fx_root=main.fx_root;ally.contract_epoch=GameState.run_epoch;ally.enemy_kind=&"walker";main.actors_root.add_child(ally);ally.position=actor.position;ally.set_physics_process(false);allies.append(ally)
		mechanics._process(1);check(is_equal_approx(GameState.mp,.5),"companion knot fixed MP per second")
		for ally in allies:ally.queue_free()
		await frames()
	await settle_actor();AudioManager.shutdown();await frames();print("BALANCE_PROCS_V25 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
