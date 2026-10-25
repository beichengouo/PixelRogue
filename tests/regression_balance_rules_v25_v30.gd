extends "res://tests/inventory_v17.gd"
class ProbeEnemy:
	extends EnemyBase
	func _ready()->void:pass
class ProbeDirector:
	extends RoomDirector
	func _ready()->void:pass

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);SaveService.data.reduced_motion=true
	await begin(&"sylphiette")
	await numerical_checks()
	await migration_checks()
	await relic_checks()
	await economy_checks()
	await settle_actor();AudioManager.shutdown();await frames()
	print("BALANCE_RULES_V25 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)

func numerical_checks()->void:
	var fallback:=ItemDB._defaults();var rows:=ItemDB.all()
	var matrix:=FileAccess.open("user://balance-stat-matrix.csv",FileAccess.WRITE)
	matrix.store_csv_line(PackedStringArray(["hero","level","item","rarity","kind","compatible","attack","max_hp","attack_speed","mp_regen","move_speed"]))
	check(rows.size()==196 and fallback.size()==rows.size(),"catalogue and fallback complete")
	for i in rows.size():
		var item:Dictionary=rows[i]
		check(item.id==fallback[i].id and item.flat==fallback[i].flat and item.mult==fallback[i].mult and item.mechanics==fallback[i].mechanics,"catalogue fallback parity "+str(item.id))
		if int(item.rarity)<2 and str(item.kind)!="potion":check(item.mult.is_empty(),"low tiers have no multiplicative stats "+str(item.id))
	for hero:StringName in [&"sylphiette",&"xixifu",&"ilyua"]:
		Characters.set_current(hero)
		for lv in [1,10,20,30,45,60,100]:
			GameState.level=lv;GameState.items.clear();GameState.equipment.clear();GameState._reset_stats()
			for item in rows:
				if str(item.kind)=="potion":continue
				var stats:=GameState.preview_with(item)
				check(is_finite(stats.get_value(&"attack")) and stats.get_value(&"max_hp")>0 and stats.get_value(&"attack_speed")>0,"finite positive projection "+str(hero)+str(lv)+str(item.id))
				var values:=PackedStringArray([str(hero),str(lv),str(item.id),str(item.rarity),str(item.kind),str(ItemDB.can_equip(item))])
				for key:StringName in [&"attack",&"max_hp",&"attack_speed",&"mp_regen",&"move_speed"]:values.append(str(stats.get_value(key)))
				matrix.store_csv_line(values)
				for difficulty in range(1,5):
					for rage in 6:
						var incoming:=10*RunDifficulty.attack_multiplier(difficulty)*float(RoomDirector.PRESSURE_ATTACK[rage])
						check(is_finite(incoming/stats.get_value(&"max_hp")) and incoming>0,"finite damage-to-health matrix")
	matrix.close()
	for d in range(1,5):
		GameState.difficulty=d
		var base:=RoomLayout.encounter(30,"tide");var plan:=RunDifficulty.encounter(base,d)
		check(is_equal_approx(float(plan.boss_hp_scale),float(base.boss_hp_scale)*RunDifficulty.health_multiplier(d)),"difficulty boss HP once "+str(d))
		check(is_equal_approx(float(plan.damage_scale),float(base.damage_scale)*RunDifficulty.attack_multiplier(d)),"difficulty attack once "+str(d))
		for boss_room in [false,true]:
			var root:=Node2D.new();add_child(root);var director:=ProbeDirector.new();add_child(director);director.set_process(false)
			var unit:=ProbeEnemy.new();root.add_child(unit);unit.hp=100;unit.damage=10;unit.move_speed=100;unit._damage_scale=1;unit._speed_scale=1
			director.enemies_root=root;director.phase=WaveDirector.Phase.FIGHT;director.room_record={"kind":"boss" if boss_room else "normal"}
			GameState.run_active=true
			director.advance_room_pressure(director.pressure_grace()-.01);check(director.room_pressure_step==0,"grace before exact boundary")
			director.advance_room_pressure(.01);check(director.room_pressure_step==1 and is_equal_approx(unit.damage,11),"first pressure is ten percent")
			for step in range(2,6):
				director.advance_room_pressure(20)
				check(director.room_pressure_step==step and is_equal_approx(unit.damage,10*float(RoomDirector.PRESSURE_ATTACK[step])) and is_equal_approx(unit.move_speed,100*float(RoomDirector.PRESSURE_SPEED[step])),"gradual attack speed pressure "+str(step))
			director.advance_room_pressure(999);check(is_equal_approx(unit.damage,16.5),"pressure hard cap")
			var elapsed:=director.room_pressure_elapsed;get_tree().paused=true;director.advance_room_pressure(10);get_tree().paused=false;check(director.room_pressure_elapsed==elapsed,"paused pressure clock")
			director.phase=WaveDirector.Phase.REST;director.advance_room_pressure(10);check(director.room_pressure_elapsed==elapsed,"rush and trial rest pause pressure")
			director.queue_free();root.queue_free();await frames()
	Characters.set_current(&"sylphiette");GameState.level=1;GameState.difficulty=1;GameState._reset_stats()

func migration_checks()->void:
	var runtime:=RoomRuntime.new()
	for d in range(1,5):
		GameState.difficulty=d
		for old_step in [0,1,3,5,9]:
			for old_speed in [false,true]:
				var step:=clampi(old_step,0,5);var old_attack:=minf(10,1+old_step)
				var unit:=ProbeEnemy.new()
				var saved:Dictionary={"balance_revision":4,"room_pressure_growth":old_step,"damage":10*old_attack,"_damage_scale":old_attack,"max_hp":100.0,"hp":40.0,"_hp_scale":1.0,"base_speed":100.0,"move_speed":100*([1.0,1.08,1.15,1.21,1.26,1.30][step] if old_speed else minf(2,1+old_step*.25)),"_speed_scale":([1.0,1.08,1.15,1.21,1.26,1.30][step] if old_speed else minf(2,1+old_step*.25))}
				if old_speed:saved.pressure_speed_revision=1
				runtime._apply_fields(unit,saved)
				check(is_equal_approx(unit.hp/unit.max_hp,.4),"enemy injured ratio retained")
				check(is_equal_approx(unit.damage,10*runtime._difficulty_attack_ratio()*float(RoomDirector.PRESSURE_ATTACK[step])) and is_equal_approx(unit.move_speed,100*float(RoomDirector.PRESSURE_SPEED[step])),"old multiplier converted once "+str(d)+str(old_step))
				var current:=runtime._fields(unit);var damage:=unit.damage;var hp:=unit.hp;runtime._apply_fields(unit,current)
				check(unit.damage==damage and unit.hp==hp and unit.combat_balance_revision==25,"repeat restore is idempotent")
				unit.free()
	GameState.difficulty=1;var old:Dictionary={"hp":50.0,"max_hp":100.0,"bloodbath_hp_loss":20.0,"cruel_hp_loss":5.0}
	for step in [0,1,3,5,9]:
		runtime._restored_pressure_step=step
		var shot:=RoomProjectile.new();var source:Dictionary={"damage":10.0*minf(10,1+step),"is_friendly":false}
		runtime._apply_fields(shot,source)
		check(is_equal_approx(shot.damage,10*float(RoomDirector.PRESSURE_ATTACK[clampi(step,0,5)])),"old hostile projectile uses saved room rage "+str(step))
		var current:=runtime._fields(shot);var damage:=shot.damage;runtime._apply_fields(shot,current)
		check(shot.damage==damage,"hostile projectile conversion once")
		shot.free()
	runtime._restored_pressure_step=-1
	var record:Dictionary={"id":"wand_arcane","uid":"v25-instance","bound":true,"enchant":"ember","sale_value":17,"base":30,"workshop_made":true}
	var resolved:=ExpeditionData.unpack(record)
	check(resolved.flat==ItemDB.by_id(&"wand_arcane").flat and resolved.mult.is_empty(),"old item ID resolves current stats")
	check(ExpeditionData.pack(resolved)==record,"old item metadata unchanged by balance")
	runtime._apply_fields(actor,old)
	check(is_equal_approx(actor.hp/actor.max_hp,.5) and actor.permanent_hp_loss()==25,"player wound amount and injured ratio retained")
	var fields:=runtime._fields(actor);var hp:=actor.hp;runtime._apply_fields(actor,fields);check(actor.hp==hp,"player repeated restore no heal")
	var overflow:=actor.stats.get_value(&"max_hp")+50
	runtime._apply_fields(actor,{"hp":50.0,"max_hp":100.0,"bloodbath_hp_loss":overflow,"cruel_hp_loss":0.0})
	check(actor.max_hp==1 and actor.hp==.5 and actor.permanent_hp_loss()==overflow,"legacy excess scars preserve living HP ratio without erasing wounds")
	actor._on_stats_changed();check(actor.hp==.5 and actor.max_hp==1,"stats refresh does not kill migrated survivor")
	fields=runtime._fields(actor);runtime._apply_fields(actor,fields);check(actor.hp==.5 and actor.balance_scar_overflow,"overflow compatibility persists through snapshot")
	actor.repair_capacity(1);check(actor.permanent_hp_loss()==overflow-1 and actor.hp>0,"partial repair retains excess scar amount")
	actor.repair_capacity(overflow);check(not actor.balance_scar_overflow and actor.permanent_hp_loss()==0,"sufficient repair ends legacy overflow compatibility")
	actor.bloodbath_hp_loss=0;actor.cruel_hp_loss=0;actor.hp=actor.max_hp
	runtime.free()

func relic_checks()->void:
	var mechanics:=actor.equipment_mechanics
	GameState.items.clear()
	for id in [&"relic_wornbutton",&"relic_spentmatch",&"relic_mist_dew",&"relic_half_star"]:GameState.add_item(ItemDB.by_id(id))
	mechanics.refresh()
	var shield:=mechanics.fixed_value(&"wornbutton",&"shield_flat");var damage:=mechanics.fixed_value(&"spentmatch",&"damage_flat")
	GameState.stats.add_flat(&"attack",1000);GameState.stats.add_flat(&"max_hp",1000)
	check(shield==5 and damage==1.5 and mechanics.fixed_value(&"wornbutton",&"shield_flat")==shield,"fixed effects independent of attack and HP")
	GameState.add_item(ItemDB.by_id(&"relic_wornbutton"));mechanics.refresh();check(is_equal_approx(mechanics.fixed_value(&"wornbutton",&"shield_flat"),7.5),"two relic copies scale quantity only")
	GameState.add_item(ItemDB.by_id(&"relic_wornbutton"));mechanics.refresh();check(is_equal_approx(mechanics.fixed_value(&"wornbutton",&"shield_flat"),8.75),"three relic copies capped quantity")
	actor.bloodbath_hp_loss=50;actor.max_hp=150;actor.hp=50;GameState.add_item(ItemDB.by_id(&"potion_capacity"))
	main.gm_pilot._use_capacity_potion(actor);check(actor.bloodbath_hp_loss<50,"bot consumes owned capacity potion via normal API")
	check(ItemDB.stat_lines({"flat":{&"attack_speed":.16},"mult":{}})[0].contains("0.16"),"fractional additive attack speed visible")
	GameState.items.clear();GameState._reset_stats();mechanics.refresh();actor.bloodbath_hp_loss=0

func economy_checks()->void:
	GameState.difficulty=1;GameState.add_item(ItemDB.by_id(&"lucky_coin"));GameState.coins=0
	var director:=main.director as RoomDirector;director.room_record.delta.erase("economy_bonus_paid")
	director._award_room_coins();var paid:=GameState.coins;director._award_room_coins()
	check(paid==2 and GameState.coins==paid,"fixed economic relic once per room")
