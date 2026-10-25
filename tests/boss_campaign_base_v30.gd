extends Node
## Fixed-step headless simulation; progression and resources use production APIs.
const OUTPUT_ROOT := "E:/CodexWorkspace/PixelRogue/work/v30-boss-phases/"
class CampaignRoom:
	extends "res://src/room_mode/room_main.gd"
	var returned := false
	func _ready() -> void: pass
	func _autoplay_requested() -> bool: return true
	func _extracted_to_camp() -> void:
		# Settlement has already committed through the real extraction path.
		returned = true
var main: CampaignRoom
var seconds := 0.0
var last_report := 0.0
var started := false
var equipment_changes := 0
var trace: Array = []
var boss_kills: Array = []
var damage_total := 0.0
var seed_value := 4501
var hero: StringName = &"ilyua"
var chapter: StringName = ChapterCatalog.FIRST
var label := "gm"
var challenge:=1
var prepared:=false
var starting_kit:Array=[]
var starting_budget:=0
var bot_assist:=false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func _process(dt: float) -> void:
	if not started or not is_instance_valid(main): return
	if not get_tree().paused and not TransitionLayer.busy: seconds += dt
	if seconds-last_report >= 30:
		last_report = seconds
		var row := state()
		trace.append(row)
		print("V21_GM_PROGRESS ", JSON.stringify(row))

func state() -> Dictionary:
	var player := main.player
	var row := {"hero":str(hero), "chapter":str(chapter), "seed":seed_value, "game_seconds":seconds,
		"stage":main.graph.stage_index, "room":main.graph.current, "wave":main.graph.encounters,
		"bosses":main.graph.defeated.duplicate(), "level":GameState.level, "mp":GameState.mp,
		"talent_points":GameState.talent_points, "spent_talents":GameState.spent_talent_points(),
		"equipment_changes":equipment_changes, "damage_total":damage_total, "returned":main.returned,
		"ui":str(UIFlow.top_screen().get_script().resource_path) if UIFlow.has_screen() else ""}
	if is_instance_valid(player):
		row.merge({"hp":player.hp, "max_hp":player.max_hp, "position":str(player.position),
			"motion":str(player.movement_override), "enemies":main.director._living_enemy_count(),
			"kind":str(main.graph.rooms[main.graph.current].kind), "safe":main.safe_room(),
			"cleared":bool(main.graph.rooms[main.graph.current].cleared), "rewarded":bool(main.graph.rooms[main.graph.current].rewarded),
			"navigation_pending":main._navigation_pending, "frontier":main.gm_pilot._frontier_exits(),
			"extraction_state":main.expedition.extraction.state})
	var equipment := {}
	for slot: StringName in ItemDB.SLOTS: equipment[str(slot)] = str(GameState.equipped(slot).get("id", ""))
	row["equipment"] = equipment
	return row

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").begins_with(OUTPUT_ROOT):
		printerr("Unsafe GM user directory"); get_tree().quit(1); return
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3:
		hero = StringName(args[0]); seed_value = int(args[1]); chapter = ChapterCatalog.normalize(args[2])
	label = "gm-%s-%s-%d" % [chapter, hero, seed_value]
	if args.size() >= 4: label = "%s-%s-%s-%d" % [str(args[3]).validate_filename(), chapter, hero, seed_value]
	if args.size()>=5:challenge=clampi(int(args[4]),1,4)
	prepared=args.size()>=6 and args[5]=="prepared"
	bot_assist=args.size()>=7 and args[6]=="assisted"
	print("V21_GM_USER_DIR=", OS.get_user_data_dir())
	Engine.max_fps = 0
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	AchievementTracker.set_process(false)
	ErrorReporter.interactive = false
	TransitionLayer.boot_played = true
	SaveService.data.control_setup_done = true
	SaveService.data.reduced_motion = true
	SaveService.data.run = {}
	Outpost.data.active = {}
	Outpost.data.gold = 0
	Outpost.data.inventory = {}
	Characters.set_current(hero)
	PassiveDefinitions.select(hero, PassiveDefinitions.default_for(hero), false)
	StoryState.flags["chapter_2_unlocked"] = true
	GameState.new_run(seed_value)
	GameState.difficulty=challenge
	GameState.chapter_id = chapter
	GameState.fate.star_pending = true
	var fixture_id := "v21-gm-%s-%s-%d" % [chapter, hero, seed_value]
	GameState.sortie_id = fixture_id
	var departure := {"id":fixture_id, "status":"active", "initial_level":1, "loadout":[], "carried":0,
		"difficulty":challenge, "chapter_id":str(chapter), "spent":0, "skill_loadout":Skills.default_loadout(hero)}
	if not prepared:
		if not Outpost.start_sortie([],0,0,challenge,1,chapter):printerr("FAIL real empty departure transaction");get_tree().quit(2);return
		departure=Outpost.data.active.duplicate(true);fixture_id=str(departure.id);GameState.sortie_id=fixture_id
	if prepared:
		starting_kit=prepared_kit()
		for id in starting_kit:
			Outpost.data.inventory[id]=int(Outpost.data.inventory.get(id,0))+1
			starting_budget+=int(ItemDB.by_id(StringName(id)).get("cost",0))
		if not Outpost.start_sortie(starting_kit,0,0,challenge,1,chapter):get_tree().quit(2);return
		departure=Outpost.data.active.duplicate(true);fixture_id=str(departure.id);GameState.sortie_id=fixture_id
		for id in starting_kit:
			GameState.add_item(Outpost.stored_item(str(id)))
			if ItemDB.is_equippable(GameState.items.back()):GameState.equip(GameState.items.back())
	Outpost.data.active = departure.duplicate(true)
	if bot_assist:
		GameState.add_temp_buff(&"max_hp",.15,7200,"Bot测试容错","v25_bot_fixture")
		GameState.add_temp_buff(&"mp_regen",.10,7200,"Bot测试容错","v25_bot_fixture")
	var graph := RoomGraph.new()
	graph.begin(seed_value, chapter)
	var fresh := GameState.snapshot()
	fresh.world_state = {"graph":graph.snapshot()}
	SaveService.data.run = fresh.duplicate(true)
	main = CampaignRoom.new()
	main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(main)
	main._build_world(); main._build_ui(); main._connect_events()
	await main._begin_run(fresh)
	if not is_instance_valid(main.player): printerr("FAIL GM fixture could not spawn player"); get_tree().quit(1); return
	var valid_start := GameState.level == 1 and GameState.coins == 0 and GameState.spent_talent_points() == 0
	if not prepared:
		valid_start=valid_start and GameState.items.is_empty()
		for slot: StringName in ItemDB.SLOTS: valid_start = valid_start and GameState.equipped(slot).is_empty()
	if not valid_start: printerr("FAIL GM fixture must be level1, empty gear/bag/coins and unspent initial talent"); get_tree().quit(1); return
	EventBus.equipment_changed.connect(func() -> void: equipment_changes += 1)
	EventBus.player_damaged.connect(func(amount: float, _hp: float, _max_hp: float) -> void: damage_total += amount)
	EventBus.boss_defeated.connect(func(id: StringName) -> void:
		boss_kills.append({"id":str(id), "game_seconds":seconds, "level":GameState.level, "stage":main.graph.stage_index}))
	main.gm_pilot.activate()
	started = true
	var wall := Time.get_ticks_msec()
	while seconds < 3600 and Time.get_ticks_msec()-wall < 1800000 and is_instance_valid(main.player) and main.player.hp > 0 and not main.returned:
		await get_tree().process_frame
	started = false
	var result := state()
	result["wall_seconds"] = (Time.get_ticks_msec()-wall)/1000.0
	result["starting_gear"] = "prepared" if prepared else "empty"
	result["starting_kit"]=starting_kit;result["starting_budget"]=starting_budget
	var capacity_count:=starting_kit.count("potion_capacity")
	result["starting_capacity_materials"]={"river_pearl":capacity_count,"forest_resin":capacity_count*2,"star_dust":capacity_count*4} if prepared else {}
	result["starting_budget_with_material_sale_values"]=starting_budget+capacity_count*62 if prepared else 0
	result["starting_budget_ceiling"]=580 if prepared else 0
	result["initial_level"] = 1
	result["real_departure_transaction"] = not fixture_id.begins_with("v21-gm-")
	result["difficulty"] = challenge
	result["invulnerability_override"] = false
	result["bot_attribute_assistance"]={"max_hp_add_mult":.15,"mp_regen_add_mult":.10,"source":"test_fixture_only"} if bot_assist else {}
	result["fixed_simulation_step"] = "60fps"
	result["gm_source_sha256"] = FileAccess.get_sha256("res://src/room_mode/gm_pilot.gd")
	result["boss_kills"] = boss_kills
	result["trace"] = trace
	result["talents"] = GameState.talents.duplicate(true)
	result["skills"] = GameState.skill_loadout()
	result["settlement"] = Outpost.data.get("last_result", {}).duplicate(true)
	result["passed"] = main.returned and boss_kills.size() >= 3 and str(result.settlement.get("outcome", "")) == "extracted" and str(result.settlement.get("clear_tier", "")) == "normal"
	var file := FileAccess.open(OUTPUT_ROOT + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t")); file.close()
	print("V21_GM_RESULT ", JSON.stringify({"label":label, "passed":result.passed, "game_seconds":seconds, "wall_seconds":result.wall_seconds, "bosses":boss_kills, "returned":main.returned, "damage_total":damage_total}))
	main.gm_pilot.stop()
	GameState.run_active = false
	main.queue_free()
	await get_tree().process_frame; await get_tree().process_frame
	AudioManager.shutdown()
	await get_tree().create_timer(.25, true, false, true).timeout
	get_tree().quit(0 if result.passed else 1)

func prepared_kit()->Array:
	var kit:Array=[{"ilyua":"bow_lake_light","xixifu":"staff_shadow_stitch","sylphiette":"staff_tide_prayer"}[str(hero)],"wind_cloak","wind_ring" if challenge==4 else "life_ampoule"]
	# Arcane is an attack buff. Energy is the actual mana restoration potion.
	for id in (["potion_energy","potion_capacity"] if challenge==4 else ["potion_health","potion_energy","potion_capacity"]):
		for i in (6 if challenge==4 else 5):kit.append(id)
	return kit
