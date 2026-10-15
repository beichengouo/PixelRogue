extends Node

class LootSpy:
	extends Node
	var calls: Array[Dictionary] = []
	func burst_reward(loot: Dictionary, at: Vector2) -> void:
		calls.append({"loot": loot.duplicate(true), "at": at})

class RuntimeSpy:
	extends Node
	var loot: Node

var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: ", label)

func run() -> void:
	var room_script := load("res://src/room_mode/room_main.gd")
	var combat := {"kind":"normal", "terrain_layout":{"entities":[]}}
	check(not room_script._chest_should_drop(combat, 0.20), "20 percent boundary excludes roll 0.20")
	check(room_script._chest_should_drop(combat, 0.199), "ordinary combat room drops below 20 percent")
	var authored := {"kind":"normal", "terrain_layout":{"entities":[
		{"asset_id":"chest", "at":[3, 4]}, {"asset_id":"chest", "at":[8, 7]}]}}
	check(room_script._chest_should_drop(authored, 0.99), "authored chest forces exactly one delivery")
	check(room_script._chest_template_position(authored) == RoomLayout.center(Vector2i(3, 4)), "first authored chest sets delivery position")
	check(not room_script._chest_should_drop({"kind":"shop", "terrain_layout":{"entities":[]}}, 0.0), "ordinary service room gets no random chest")
	var main: Variant = room_script.new()
	authored["delta"] = {}
	main.graph.rooms = {"0,0": authored}
	main.graph.current = "0,0"
	main._spawn_template_chests()
	var plan: Dictionary = authored.delta.chest_delivery
	check(plan.drop and not plan.delivered and plan.at == [126.0, 162.0], "authored chest creates one pending delivery")
	plan.delivered = true
	main._spawn_template_chests()
	check(authored.delta.chest_delivery.delivered, "revisiting room does not reset completed delivery")
	var legacy := {"kind":"normal", "terrain_layout":authored.terrain_layout, "delta":{"runtime":{"entities":[]}}}
	main.graph.rooms["0,0"] = legacy
	main._spawn_template_chests()
	check(not legacy.delta.chest_delivery.drop and legacy.delta.chest_delivery.delivered, "legacy room snapshot does not create another chest")
	main.free()
	var chest := RoomChest.new()
	add_child(chest)
	check(not chest.is_open and chest._landed, "new chest starts closed before delivery")
	chest.begin_delivery()
	check(not chest._landed and chest._fall_elapsed == 0.0, "delivery begins above ground")
	chest.in_range = true
	chest.try_interact()
	check(not chest.is_open, "airborne chest cannot open")
	var was_busy := TransitionLayer.busy
	TransitionLayer.busy = true
	chest._physics_process(Chest.FALL_DURATION)
	check(chest._fall_elapsed == 0.0, "covered room cannot consume delivery animation")
	TransitionLayer.busy = was_busy
	chest._physics_process(Chest.FALL_DURATION * 0.5)
	check(not chest._landed, "chest cannot land halfway through reveal")
	var runtime := ExpeditionRuntime.new()
	var saved := runtime._fields(chest)
	var restored := RoomChest.new()
	runtime._apply_fields(restored, saved)
	check(not restored._landed and is_equal_approx(restored._fall_elapsed, Chest.FALL_DURATION * 0.5), "flight progress survives room serialization")
	restored.free()
	runtime.free()
	chest._physics_process(Chest.FALL_DURATION * 0.5)
	check(chest._landed, "chest lands after full reveal")
	check(is_equal_approx(chest._sprite.scale.x * 64.0, 46.0), "64px source renders at 46px width")
	check(is_equal_approx(chest._art_origin.y + (60.0 - 32.0) * chest._sprite.scale.y, 12.0), "source baseline y60 meets room ground")
	chest.is_open = true
	chest._opening = true
	var seen: Array[Texture2D] = []
	for frame in 4:
		chest._opening_elapsed = frame * Chest.OPEN_STEP
		chest.set_art("open")
		var texture := WorldPropArt.chest_texture(frame)
		check(texture != null and chest._sprite.texture == texture and not seen.has(texture), "opening uses unique authored frame %d" % frame)
		seen.append(texture)
	chest._opening = false
	chest._open_timer = 0.5
	chest.set_art("empty")
	var empty_texture := WorldPropArt.chest_texture(4)
	check(empty_texture != null and chest._sprite.texture == empty_texture and not seen.has(empty_texture), "spent chest uses empty frame")
	var previous_runtime := GameState.runtime_node
	var fake_runtime := RuntimeSpy.new()
	var loot_spy := LootSpy.new()
	fake_runtime.loot = loot_spy
	add_child(fake_runtime)
	fake_runtime.add_child(loot_spy)
	GameState.runtime_node = fake_runtime
	chest._pending_loot = {"kind": &"coins", "amount": 75}
	chest._reward_dispatched = false
	chest._burst_reward()
	chest._burst_reward()
	check(loot_spy.calls.size() == 1 and int(loot_spy.calls[0].loot.amount) == 75, "opening bursts reward exactly once through loot director")
	check(chest._pending_loot.is_empty() and chest._reward_dispatched, "burst receipt survives subsequent opening ticks")
	GameState.runtime_node = previous_runtime
	fake_runtime.free()
	chest.free()
	await get_tree().create_timer(0.65).timeout
	if failures == 0:
		print("PASS chest_delivery_regression")
	get_tree().quit(0 if failures == 0 else 1)
