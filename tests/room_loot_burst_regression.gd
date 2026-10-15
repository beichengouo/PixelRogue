extends Node2D

var level: RoomLevel
var player: Node2D
var fx_root: Node2D
var loot: RoomLootDirector
var graph := {"rooms": [{"biome": "forest"}], "current": 0}
var director := {"total_this_wave": 10}
var enemies_root: Node2D
var chests_root: Node2D
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	level = load("res://src/room_mode/room_level.tscn").instantiate()
	add_child(level)
	level.load_room({"id":"0,0","kind":"boss","biome":"forest","seed":17,"delta":{},"doors":[],"terrain_layout":{"room_rect":[0,0,684,396],"props":[],"water":[],"ground":[],"decor":[],"entities":[]}})
	fx_root = Node2D.new()
	add_child(fx_root)
	enemies_root = Node2D.new()
	add_child(enemies_root)
	chests_root = Node2D.new()
	add_child(chests_root)
	player = Node2D.new()
	player.position = Vector2(342,198)
	add_child(player)
	loot = RoomLootDirector.new()
	loot.main = self
	add_child(loot)
	level.load_scene_objects([{"id":"loot_wall","kind":"stone","texture":"res://assets/room_mode/refinement/stone.png","position_px":[420,198],"render_width_px":30,"collision_polygon_px":[[-12,-70],[12,-70],[12,70],[-12,70]]}], "res://")
	check(loot.has_method("burst_reward"), "public chest burst API exists")
	if loot.has_method("burst_reward"):
		loot.burst_reward({"kind": &"item", "item": ExpeditionData.material("forest_sample")}, player.position)
		var drops := fx_root.get_children().filter(func(n: Node) -> bool: return n is RoomLootDrop)
		check(drops.size() == 1, "chest item becomes physical room loot")
		if drops.size() == 1:
			check(drops[0].global_position.distance_to(player.global_position) > 28.0, "drop gets a separate world landing point")
			check(drops[0].flight_left > 0.0, "drop begins in flight")
			check(level.body_clear(drops[0].global_position, 8), "landing point avoids solid obstacles")
			player.global_position = drops[0].global_position
			check(not drops[0].try_pickup(), "loot cannot be picked up in flight")
			drops[0]._physics_process(drops[0].flight_left)
			check(drops[0].landing_wait > 0.0 and not drops[0].try_pickup(), "loot pauses after landing before pickup")
			player.global_position = Vector2(342,198)
		loot.burst_reward({"kind": &"coins", "amount": 73}, player.position)
		var coin_count := 0
		var total := 0
		for node in fx_root.get_children():
			if node is Coin and not node is LootDrop:
				coin_count += 1
				total += node.value
		check(coin_count >= 2 and coin_count <= 6 and total == 73, "chest coins split into few physical coins with preserved value")
		var original_coin: Coin
		for node in fx_root.get_children():
			if node is Coin and not node is LootDrop: original_coin = node; break
		if original_coin != null:
			var runtime := RoomRuntime.new()
			runtime.main = self
			var record := runtime._node_record(original_coin)
			var restored := runtime._restore_room_node(record) as Coin
			check(restored != null and restored.value == original_coin.value and restored.flight_left > 0.0 and restored.landing_wait > 0.0, "room restore preserves flying coin value and timing")
			check(runtime._restore_room_node({"script":"res://src/room_mode/room_key.gd"}) == null, "retired room key does not return from legacy save")
			check(runtime._restore_room_node({"script":"res://src/actors/coin.gd","fields":{"kind":{"$name":"key"}}}) == null, "legacy generic key drop also remains retired")
			if restored != null: restored.queue_free()
			runtime.free()
	var boss := BossBase.new()
	boss.reward_uid = "test_boss_key"
	boss.position = player.position
	var was_active := GameState.run_active
	GameState.run_active = true
	var before_boss := fx_root.get_child_count()
	loot.reward(boss)
	GameState.run_active = was_active
	check(loot.keys_dropped == 0, "boss death does not award a key")
	var boss_drops := 0
	var boss_positions: Array[Vector2] = []
	for child_index in range(before_boss, fx_root.get_child_count()):
		var node := fx_root.get_child(child_index)
		if node is RoomLootDrop and node.flight_left > 0.0:
			boss_drops += 1
			check(level.body_clear(node.global_position, 8), "boss loot landing avoids room obstacles")
			for prior in boss_positions:
				check(node.global_position.distance_to(prior) >= 20.0, "boss loot landings remain separated")
			boss_positions.append(node.global_position)
	check(boss_drops >= 8 and boss_drops <= 27, "boss keeps original three gear and five to eight material rolls")
	for node in fx_root.get_children():
		check(not (node is Coin and node.kind == &"key"), "boss death creates no key pickup")
	boss.free()
	var normal := EnemyBase.new()
	normal.reward_uid = "test_normal_key"
	normal.position = player.position
	var seed := 1
	while seed < 1000:
		var probe := RandomNumberGenerator.new()
		probe.seed = seed
		if probe.randf() < 0.14: break
		seed += 1
	loot.rng.seed = seed
	GameState.run_active = true
	loot.reward(normal)
	GameState.run_active = was_active
	for node in fx_root.get_children():
		check(not (node is Coin and node.kind == &"key"), "normal enemy creates no key pickup")
	normal.free()
	while get_tree().get_nodes_in_group("expedition_loot").size() < 64:
		var filler := RoomLootDrop.new()
		filler.level = level
		filler.player = player
		filler.contents.append(ExpeditionData.material("forest_sample"))
		fx_root.add_child(filler)
		filler.global_position = Vector2(100,100)
	var before_capped_burst := fx_root.get_child_count()
	loot.burst_reward({"kind": &"gear", "item": ExpeditionData.material("forest_sample")}, Vector2(342,198))
	check(fx_root.get_child_count() == before_capped_burst + 1, "burst remains a separate landing even when ordinary loot reaches the merge cap")
	var saved_coins := GameState.coins
	var saved_keys := GameState.keys
	GameState.coins = 200
	GameState.keys = 0
	var shop := ShopUI.new()
	add_child(shop)
	shop.open([])
	shop._opening_until = 0
	shop._action_until = 0
	var price := shop.key_price()
	shop.buy_key()
	check(GameState.keys == 1 and GameState.coins == 200 - price, "shop still sells key for coins")
	shop.close(true)
	shop.free()
	GameState.coins = saved_coins
	GameState.keys = saved_keys
	for node in fx_root.get_children():
		fx_root.remove_child(node)
		node.free()
	AudioManager.shutdown()
	await get_tree().create_timer(0.5, true, true).timeout
	print("ROOM_LOOT_BURST ", "FAIL" if failures else "PASS", " failures=", failures)
	get_tree().quit(1 if failures else 0)
