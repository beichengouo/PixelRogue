extends "res://tests/inventory_v17.gd"
## Production combat with a frozen loadout, no XP/drop collection or navigation.
## Full progression, loot, paid preparation and settlement are tested separately.
class FixedPilot:
	extends GMPilot
	func _equip_upgrades()->void:pass
	func _develop_character()->void:pass
	func _collect_room_loot(_delta:float)->bool:return false
	func _prepare_departure(_step:float)->bool:return true
	func _go_to_next_room(_step:=.15)->void:pass
	func _advance_screen()->void:pass
var elapsed:=0.0
var measuring:=false
var damage_taken:=0.0
var damage_kinds:Dictionary={}
var origins:Dictionary={}
var results:Array=[]
var max_rage:=0
var low_mana:=0.0

func _process(dt:float)->void:
	if not measuring or get_tree().paused or TransitionLayer.busy:return
	elapsed+=dt
	max_rage=maxi(max_rage,main.director.room_pressure_step)
	if GameState.mp<10:low_mana+=dt

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true
	SaveService.data.reduced_motion=true;Engine.max_fps=0
	EventBus.player_damaged.connect(func(amount:float,_hp:float,_max:float)->void:
		if measuring:damage_taken+=amount)
	EventBus.enemy_spawned.connect(func(enemy:EnemyBase)->void:
		if not measuring:return
		var key:=str(enemy.kind)+":"+enemy.loot_origin
		origins[key]=int(origins.get(key,0))+1
		enemy.damage_applied.connect(func(_a:EnemyBase,amount:float,_source:Node,kind:StringName)->void:
			if measuring:damage_kinds[str(kind)]=float(damage_kinds.get(str(kind),0))+amount))
	for hero:StringName in [&"sylphiette",&"xixifu",&"ilyua"]:
		for rarity in 4:await sample(hero,1,"normal",rarity,20)
		for difficulty in range(1,5):
			await sample(hero,difficulty,"elite",2,20)
		for chapter:StringName in [ChapterCatalog.FIRST,ChapterCatalog.NEXT]:
			for id in ChapterCatalog.bosses(chapter):
				await sample(hero,1,"boss",2,45,str(id),chapter)
				await sample(hero,4,"boss",3,45,str(id),chapter)
		await sample(hero,1,"boss_rush",3,45)
	var file:=FileAccess.open("E:/CodexWorkspace/PixelRogue/work/v25-balance/fixed-combat.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"));file.close()
	AudioManager.shutdown();await frames();print("BALANCE_COMBAT_V25 samples=",results.size()," checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

func sample(hero:StringName,difficulty:int,kind:String,rarity:int,lv:int,boss_id:="",chapter:StringName=ChapterCatalog.FIRST)->void:
	await begin(hero)
	main.gm_pilot.queue_free();main.gm_pilot=FixedPilot.new();main.gm_pilot.main=main;main.add_child(main.gm_pilot)
	if main.director.enemy_reward.is_connected(main.expedition.loot.reward):main.director.enemy_reward.disconnect(main.expedition.loot.reward)
	GameState.level=lv;GameState.talents.clear();GameState.talent_points=GameState.talent_budget(lv);GameState.difficulty=difficulty;GameState.chapter_id=chapter
	GameState.items.clear();GameState.equipment.clear();GameState._reset_stats()
	var fixture_seed:=int({"sylphiette":4503,"xixifu":4502,"ilyua":4501}[str(hero)])
	Rng.start_run(fixture_seed);GameState.passive_rng.seed=hash(str(fixture_seed)+":passive")
	main.graph.begin(fixture_seed,chapter)
	var weapons:Array
	if hero==&"ilyua":weapons=["bow_reed","bow_wood","bow_lake_light","bow_spring_wind"]
	elif hero==&"xixifu":weapons=["staff_apprentice","wand_arcane","staff_shadow_stitch","staff_dusk_lantern"]
	else:weapons=["staff_apprentice","wand_arcane","staff_tide_prayer","staff_cloud_radiance"]
	var set:Dictionary=LegendarySets.DATA[hero]
	var ids:Array=[weapons[rarity],["watcher_cloth","mage_robe","wind_cloak",str(set.armor)][rarity],["journey_bell","crystal_pendant","life_ampoule",str(set.accessory)][rarity]]
	for id in ids:
		var item:=ItemDB.by_id(StringName(id));check(not item.is_empty(),"fixed item exists "+str(id))
		if not item.is_empty():GameState.add_item(item);check(GameState.equip(GameState.items.back()),"fixed legal equipment "+str(id))
	actor.equipment_mechanics.refresh();actor.max_hp=GameState.stats.get_value(&"max_hp");actor.hp=actor.max_hp;GameState.mp=100
	main.graph.chapter_id=chapter;main.graph.stage_index=4 if kind=="boss_rush" else (3 if kind=="boss" else 2)
	var record:Dictionary={}
	for candidate:Dictionary in main.graph.rooms.values():
		if str(candidate.kind)==("boss" if kind in ["boss","boss_rush"] else "normal"):record=candidate;break
	check(not record.is_empty(),"fixture room exists")
	if record.is_empty():await settle_actor();return
	record.kind=kind;record.boss=boss_id;record.strength=20;record.encounter=20;record.cleared=false;record.rewarded=false;record.delta={};record.boss_stats={}
	main.graph.current=str(record.id);await main.level.load_room_async(record,self)
	actor.position=main.level.nearest_clear(main.level.room_rect.get_center()+Vector2(0,72))
	elapsed=0;damage_taken=0;damage_kinds={};origins={};max_rage=0;low_mana=0;measuring=true
	main.director.enter_room(record);main.director.set_process(true);actor.set_physics_process(true);actor.caster.set_physics_process(true);actor.equipment_mechanics.set_process(true);GameState.set_process(true)
	if is_instance_valid(actor.holy_runtime):actor.holy_runtime.set_process(true)
	if is_instance_valid(actor.ilyua_runtime):actor.ilyua_runtime.set_process(true)
	main.gm_pilot.activate()
	var wall:=Time.get_ticks_msec();var limit:=600.0 if kind=="boss_rush" else 180.0
	while elapsed<limit and actor.hp>0 and not bool(record.cleared) and Time.get_ticks_msec()-wall<180000:await get_tree().process_frame
	measuring=false;main.gm_pilot.stop();main.director.set_process(false);actor.set_physics_process(false)
	var row:Dictionary={"hero":str(hero),"seed":fixture_seed,"difficulty":difficulty,"kind":kind,"rarity":rarity,"level":lv,"final_level":GameState.level,"chapter":str(chapter),"boss":boss_id,"gear":ids,"cleared":bool(record.cleared),"alive":actor.hp>0,"seconds":elapsed,"damage_taken":damage_taken,"hp":actor.hp,"max_hp":actor.max_hp,"max_rage":max_rage,"damage_kinds":damage_kinds.duplicate(),"origins":origins.duplicate(),"low_mana_seconds":low_mana,"rush_index":main.director.rush_index}
	results.append(row);print("V25_FIXED ",JSON.stringify(row))
	check(GameState.level==lv,"fixed fixture does not gain XP")
	await settle_actor()
