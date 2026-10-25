extends "res://tests/inventory_v17.gd"
## Instrumented performance fixture, never a legal-start GM completion claim.
const OUTPUT_ROOT := "E:/CodexWorkspace/PixelRogue/work/v30-boss-phases/"
var report:Dictionary={"segments":[],"rooms":[],"samples":[],"revisits":[],"rush_completed":0,"errors":0}
var gear:Node
var _clock_start:=0
var _last_frame_usec:=0
var _last_sample:=0
var observed_species:Dictionary={}
class SoakPilot:
	extends GMPilot
	func _go_to_next_room(_step:=.15)->void:pass
func percentile(values:Array,p:float)->float:
	if values.is_empty():return 0
	var sorted:=values.duplicate();sorted.sort();return float(sorted[mini(sorted.size()-1,int(sorted.size()*p))])
func revisit_previous()->void:
	var current:String=main.graph.current;var previous:=RoomGraph.key(RoomGraph.cell(current)+Vector2i.LEFT)
	if not main.graph.rooms.has(previous) or not bool(main.graph.rooms[previous].get("cleared",false)):return
	var start:=Time.get_ticks_usec();await main._change_room(Vector2i.LEFT);await main._change_room(Vector2i.RIGHT)
	check(main.graph.current==current,"backtracking restores the same cleared destination")
	report.revisits.append({"hero":str(Characters.current_id()),"id":current,"roundtrip_ms":(Time.get_ticks_usec()-start)/1000.0})
class RenderPilot:
	extends SoakPilot
	func _prepare_departure(step: float) -> bool:
		# Stay inside this timed rendering fixture after a terminal boss clear.
		# Real expedition extraction is validated by the separate legal GM runs.
		if main.graph.staged and main.graph.stage_boss_cleared and main.graph.current == main.graph.stage_terminal:
			return true
		return super._prepare_departure(step)
var label := "baseline"
var full_frames: Array[float] = []
var combat_frames: Array[float] = []
var frame_times: Array[float] = []
var _measure := false
var _segment_index := -1
var max_allies := 0
var boss_kills: Array = []
var _last_room_kind := "setup"

func _process(_dt: float) -> void:
	var now_usec := Time.get_ticks_usec()
	if not _measure: return
	if _last_frame_usec > 0:
		var frame_ms := (now_usec - _last_frame_usec) / 1000.0
		full_frames.append(frame_ms)
		frame_times.append((now_usec / 1000.0 - _clock_start) / 1000.0)
		if is_instance_valid(main) and not TransitionLayer.busy and not UIFlow.has_screen() and main.director.phase == WaveDirector.Phase.FIGHT:
			combat_frames.append(frame_ms)
	_last_frame_usec = now_usec
	if is_instance_valid(main) and is_instance_valid(main.player):
		main.player._invuln = 100000
		max_allies = maxi(max_allies, get_tree().get_nodes_in_group("allies").size())
	if Time.get_ticks_msec() - _last_sample >= 30000:
		_last_sample = Time.get_ticks_msec()
		capture_sample()

func capture_sample() -> void:
	var row := {"seconds":(Time.get_ticks_msec()-_clock_start)/1000.0, "segment":_segment_index,
		"memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC), "objects":Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes":get_tree().get_node_count(), "resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"frame_count":full_frames.size(), "allies":get_tree().get_nodes_in_group("allies").size()}
	if is_instance_valid(main) and is_instance_valid(main.player):
		row.merge({"hero":str(Characters.current_id()), "chapter":str(GameState.chapter_id), "room":main.graph.current,
			"kind":str(main.graph.rooms[main.graph.current].kind), "enemies":main.director._living_enemy_count(),
			"rush_index":main.director.rush_index, "level":GameState.level, "pressure":main.director.room_pressure_step})
	report.samples.append(row)
	write_report()
	print("V29_RENDER_PROGRESS ", JSON.stringify(row))

func write_report() -> void:
	var file := FileAccess.open(OUTPUT_ROOT + label + "-render.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report))
		file.close()

func begin_segment(index: int) -> void:
	SaveService.data.control_setup_done = true
	SaveService.data.replay_seen_dialogue = false
	SaveService.data.run = {}
	Outpost.data.active = {}
	Outpost.data.gold = 0
	var hero: StringName = [&"xixifu", &"sylphiette", &"ilyua"][index]
	var chapter: StringName = ChapterCatalog.NEXT if index == 1 else ChapterCatalog.FIRST
	var seed_value: int = [4502, 4503, 4501][index]
	Characters.set_current(hero)
	var fixture_id := "v21-render-%s-%d" % [hero, seed_value]
	var loadout: Array = [&"shadow_companions", &"ghost_lantern", &"gatekeeper", &"spirit_parade"] if hero == &"xixifu" else Skills.default_loadout(hero)
	check(Skills.valid_loadout(loadout, hero), "performance uses legal 3+1 skill loadout " + str(hero))
	var departure := {"id":fixture_id, "status":"active", "initial_level":1, "loadout":[], "carried":0, "difficulty":1, "chapter_id":str(chapter), "skill_loadout":loadout}
	Outpost.data.active = departure.duplicate(true)
	SaveService.data.run = {"sortie_id":fixture_id, "departure":departure.duplicate(true)}
	main = ProbeRoom.new()
	main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(main)
	main._build_world()
	main._build_ui()
	main._connect_events()
	await main._begin_run(SaveService.run_info().duplicate(true))
	actor = main.player
	gear = actor.equipment_mechanics
	actor._invuln = 100000
	GameState.fate.star_pending = false
	Rng.start_run(seed_value)
	while GameState.level < 50: GameState.gain_exp(GameState.exp_needed(GameState.level))
	var point_budget := GameState.talent_points + GameState.spent_talent_points()
	while GameState.talent_points > 0:
		var changed := false
		for talent in GameState.TALENT_BRANCHES:
			if GameState.spend_talent_point(talent): changed = true
		if not changed: break
	check(GameState.spent_talent_points() <= point_budget, "performance talents stay within earned level-50 budget")
	GameState._reset_stats()
	for slot: String in ["weapon", "armor", "accessory"]:
		var item := ItemDB.by_id(StringName(LegendarySets.DATA[hero][slot])).duplicate(true)
		GameState.items.append(item)
		GameState.equip(item)
	# Deterministic late-run arena fixture; progression semantics are tested elsewhere.
	main.graph.begin(seed_value, chapter, false)
	main.graph.staged = true
	main.graph.stage_index = 4
	main.graph.optional_stage_entered = true
	main.graph.normal_clear_eligible = true
	main.graph.defeated.assign(ChapterCatalog.bosses(chapter))
	main.graph.encounters = 51
	main.graph.completed_encounter = 51
	GameState.chapter_cleared = true
	GameState.endless_mode = true
	main.room_weather.setup(seed_value, {}, 51)
	main.world_clock.setup(seed_value, {})
	main._story_queue.clear()
	main._story_context = ""
	main.dialogue.cancel()
	main.chapter_end_ui.close()
	main.gm_pilot.queue_free()
	main.gm_pilot = RenderPilot.new()
	main.gm_pilot.main = main
	main.add_child(main.gm_pilot)
	main.gm_pilot.activate()
	report.segments.append({"hero":str(hero), "chapter":str(chapter), "seed":seed_value, "difficulty":1,
		"level":GameState.level, "skills":loadout, "invulnerable_QA_fixture":true,
		"talents_spent":GameState.spent_talent_points(), "talents_budget":point_budget,
		"attack":actor.stats.get_value(&"attack"), "max_hp":actor.max_hp})

func enter_arena(index: int) -> void:
	var graph: RoomGraph = main.graph
	var location := RoomGraph.cell(graph.current) + Vector2i.RIGHT
	var id := RoomGraph.key(location)
	var kind: String = ["boss_rush", "normal", "elite", "normal"][index % 4]
	graph.rooms[id] = graph._allocate(location, kind, "")
	graph.rooms[id]["strength"] = 50
	graph._connect(graph.current, id)
	if kind == "boss_rush": graph.stage_terminal = id
	var start := Time.get_ticks_usec()
	await main._change_room(Vector2i.RIGHT)
	report.rooms.append({"kind":kind, "hero":str(Characters.current_id()), "chapter":str(GameState.chapter_id),
		"load_ms":(Time.get_ticks_usec()-start)/1000.0, "id":id, "strength":main.director.strength})
	main.player.stop_room_travel_motion()

func run() -> void:
	EventBus.enemy_spawned.connect(func(unit:Node)->void:
		if unit is EnemyBase:observed_species[str(unit.kind)]=int(observed_species.get(str(unit.kind),0))+1)
	var args := OS.get_cmdline_user_args()
	label = str(args[0]) if args.size() > 0 else "baseline"
	var duration := int(args[1]) if args.size() > 1 else 600
	check(OS.get_user_data_dir().replace("\\", "/").begins_with("E:/CodexWorkspace/PixelRogue/work/v30-boss-phases/"), "isolated rendered profile")
	check(DisplayServer.get_name() != "headless", "real display renderer required")
	check(RenderingServer.get_current_rendering_method() == "gl_compatibility", "GL Compatibility required")
	if failures: get_tree().quit(1); return
	get_window().size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	Engine.time_scale = 1.0
	AchievementTracker.set_process(false)
	SaveService.data.reduced_motion = false
	SaveService.data.environment_quality = 2
	SaveService.data.spell_fx_strength = 1.0
	TransitionLayer.boot_played = true
	report["configuration"] = {"duration_seconds":duration, "viewport":"1280x720", "renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(), "display":DisplayServer.get_name(), "max_fps":120,
		"environment_quality":2, "spell_fx_strength":1.0, "reduced_motion":false,
		"sampling":"All process-frame wall-clock intervals, including room loads, menus and transitions. Combat subset separate. No screenshots or video.",
		"scope":"Level50 equipped invulnerable rendering fixture; not GM progression acceptance."}
	EventBus.boss_defeated.connect(func(id: StringName) -> void:
		boss_kills.append({"id":str(id), "seconds":(Time.get_ticks_msec()-_clock_start)/1000.0,
			"hero":str(Characters.current_id()), "kind":str(main.graph.rooms[main.graph.current].kind), "round":main.director.rush_index}))
	_clock_start = Time.get_ticks_msec()
	_last_sample = _clock_start
	_last_frame_usec = Time.get_ticks_usec()
	_measure = true
	var entered := false
	var arena := 0
	var settled := 0
	while Time.get_ticks_msec()-_clock_start < duration*1000:
		var fraction := float(Time.get_ticks_msec()-_clock_start) / float(duration*1000)
		var expected := 0 if fraction < .6 else 1 if fraction < .8 else 2
		if expected != _segment_index:
			if is_instance_valid(main):
				GameState.gm_pilot_active = false
				GameState.run_active = false
				main.queue_free()
				await get_tree().process_frame
				await get_tree().process_frame
			_segment_index = expected
			await begin_segment(expected)
			entered = false
			arena = 0
		if not entered:
			await enter_arena(arena)
			arena += 1
			entered = true
			settled = 0
		if main.chapter_end_ui.is_open(): main._continue_endless()
		if UIFlow.has_screen(): main.gm_pilot._advance_screen()
		if not TransitionLayer.busy and not main._navigation_pending and main.safe_room():
			if settled == 0:
				settled = Time.get_ticks_msec()
				if str(main.graph.rooms[main.graph.current].kind) == "boss_rush" and main.director.rush_index == 2:
					report.rush_completed = int(report.rush_completed) + 1
			if Time.get_ticks_msec()-settled > 5000:
				await revisit_previous()
				entered = false
		await get_tree().create_timer(.2, true, false, true).timeout
	_measure = false
	report["elapsed_seconds"] = (Time.get_ticks_msec()-_clock_start)/1000.0
	report["full_frame_count"] = full_frames.size()
	report["full_p95_ms"] = percentile(full_frames, .95)
	report["full_p99_ms"] = percentile(full_frames, .99)
	report["combat_frame_count"] = combat_frames.size()
	report["combat_p95_ms"] = percentile(combat_frames, .95)
	report["combat_p99_ms"] = percentile(combat_frames, .99)
	report["max_legal_allies"] = max_allies
	report["observed_species"]=observed_species.duplicate()
	report["boss_kills"] = boss_kills
	capture_sample()
	check(duration < 600 or int(report.rush_completed) > 0, "complete actual three-boss Rush required")
	check(duration < 600 or max_allies >= 6, "dense legal summons observed")
	for kind in EnemyCombatPolicy.GOBLINS:check(duration<600 or observed_species.has(str(kind)),"actual goblin coverage "+str(kind))
	check(duration < 600 or not report.revisits.is_empty(), "actual room roundtrip observed")
	GameState.gm_pilot_active = false
	GameState.run_active = false
	if is_instance_valid(main): main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	report["cleanup_objects"] = Performance.get_monitor(Performance.OBJECT_COUNT)
	report["cleanup_nodes"] = get_tree().get_node_count()
	report["cleanup_memory_bytes"] = Performance.get_monitor(Performance.MEMORY_STATIC)
	report["checks"] = checks
	report["failures"] = failures
	write_report()
	var raw := FileAccess.open(OUTPUT_ROOT + label + "-frames.json", FileAccess.WRITE)
	raw.store_string(JSON.stringify({"wall_seconds":frame_times, "all_frames_ms":full_frames, "combat_frames_ms":combat_frames}))
	raw.close()
	AudioManager.shutdown()
	await get_tree().create_timer(.25, true, false, true).timeout
	print("V29_RENDER_RESULT ", JSON.stringify({"label":label, "seconds":report.elapsed_seconds, "checks":checks, "failures":failures,
		"full_p95_ms":report.full_p95_ms, "full_p99_ms":report.full_p99_ms, "rush_completed":report.rush_completed, "max_allies":max_allies}))
	get_tree().quit(1 if failures else 0)
