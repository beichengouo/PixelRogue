extends "res://tests/inventory_v17.gd"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);SaveService.data.reduced_motion=true
	await begin(&"sylphiette")
	var used:=main.director._spawn_room_enemy(&"walker",actor.position+Vector2(80,0)) as RoomEnemy
	var fresh:=main.director._spawn_room_enemy(&"walker",actor.position+Vector2(120,0)) as RoomEnemy
	var affixes:Array[StringName]=[EnemyAffixes.GUARDIAN]
	for unit in [used,fresh]:unit.set_physics_process(false);unit.apply_affixes(affixes);unit.max_hp=100
	used.hp=30;used.affix_runtime.guardian_used=true;fresh.hp=100;fresh.affix_runtime.guardian_used=false
	check(main.gm_pilot._priority_summoner()==used,"finish wounded guardian summoner after escort release")
	used.hp=0;check(main.gm_pilot._priority_summoner()==fresh,"dead summoner does not retain priority")
	used.queue_free();fresh.queue_free();await frames()
	GameState.add_item(ItemDB.by_id(&"potion_health"));GameState.add_item(ItemDB.by_id(&"potion_energy"));GameState.difficulty=4;actor.hp=50;GameState.mp=0
	var size:=GameState.items.size();main.gm_pilot._use_potion("heal")
	check(GameState.items.size()==size and actor.hp==50,"bloodbath Bot does not waste ordinary healing")
	main.gm_pilot._use_potion("mana");check(GameState.items.size()==size-1 and GameState.mp==40,"Bot consumes actual energy potion")
	GameState.difficulty=1;GameState.items.clear()
	var probe:=preload("res://tests/v21_gm_campaign.gd").new()
	for hero:StringName in [&"sylphiette",&"xixifu",&"ilyua"]:
		probe.hero=hero
		for difficulty in [2,3,4]:
			probe.challenge=difficulty;var kit:Array=probe.prepared_kit();var potions:=0;var budget:=0
			for id in kit:
				var item:=ItemDB.by_id(StringName(id));check(not item.is_empty(),"fixture item exists")
				budget+=int(item.get("cost",0))+(62 if id=="potion_capacity" else 0)
				if ItemDB.is_usable(item):
					potions+=1;check(str(item.effect.kind) in ["mana","heal","repair_capacity"],"fixture does not confuse attack buff with mana")
			check(potions<=15 and budget<=580,"all prepared fixtures obey same budget ceiling")
			check(kit.count("potion_health")==0 if difficulty==4 else kit.count("potion_health")==5,"bloodbath has suitable supplies")
			check(kit.has("wind_ring") and not kit.has("life_ampoule") if difficulty==4 else kit.has("life_ampoule"),"bloodbath accessory has an effective non-healing benefit")
	probe.free()
	var hp:=GameState.stats.get_value(&"max_hp");var regen:=GameState.stats.get_value(&"mp_regen");var attack:=GameState.stats.get_value(&"attack")
	GameState.add_temp_buff(&"max_hp",.15,7200,"Bot测试容错","v25_bot_fixture");GameState.add_temp_buff(&"mp_regen",.10,7200,"Bot测试容错","v25_bot_fixture")
	check(is_equal_approx(GameState.stats.get_value(&"max_hp"),hp*1.15) and is_equal_approx(GameState.stats.get_value(&"mp_regen"),regen*1.1),"test assistance uses declared values")
	check(GameState.stats.get_value(&"attack")==attack,"assistance does not change attack")
	var snapshot:=GameState.snapshot();GameState.restore(snapshot)
	check(is_equal_approx(GameState.stats.get_value(&"max_hp"),hp*1.15),"fixture assistance survives ordinary checkpoint")
	GameState.new_run(4503);check(is_equal_approx(GameState.stats.get_value(&"max_hp"),hp),"new real run has no fixture assistance")
	await settle_actor();AudioManager.shutdown();await frames();print("BALANCE_BOT_V25 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
