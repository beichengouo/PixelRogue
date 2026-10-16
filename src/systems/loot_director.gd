class_name LootDirector
extends Node
var main
var rng = RandomNumberGenerator.new()
var _wave = -1
var dropped = 0
var gear_dropped = 0
var keys_dropped = 0
var receipts = {}
signal boss_loot

func _ready() -> void:
	rng.seed = Rng.run_seed ^ 0x31567

func reward(enemy: EnemyBase) -> void:
	if enemy.loot_origin != "normal" or receipts.has(enemy.reward_uid) or not GameState.run_active: return
	receipts[enemy.reward_uid] = true
	GameState.claim_wave_experience()
	if _wave != GameState.wave:
		_wave=GameState.wave
		dropped=0
		gear_dropped=0
		keys_dropped=0
	if enemy is BossBase:
		var bundle: Array[Dictionary] = []
		var multiplier:=2 if main is Node and main.get("graph") is RoomGraph and main.graph.rooms[main.graph.current].kind=="boss_rush" else 1
		for i in 3*multiplier: bundle.append(_combat_item(true))
		for i in rng.randi_range(5,8)*multiplier:
			var item = _material(enemy.global_position)
			for n in rng.randi_range(1,3): bundle.append(item.duplicate(true))
		var core:=_boss_material(enemy)
		if not core.is_empty():
			for index in multiplier:bundle.append(core.duplicate(true))
		_burst_items(bundle, enemy.global_position)
		boss_loot.emit()
		Outpost.request_checkpoint()
		return
	if _wave != GameState.wave:
		_wave = GameState.wave
		dropped = 0
		gear_dropped = 0
	var expected = maxi(6,int(main.director.total_this_wave))
	var chance = minf(0.35,2.5/expected)*(1.5 if not enemy.affixes.is_empty() else 1.0)
	if dropped >= 4 or rng.randf() > chance: return
	dropped += 1
	var item: Dictionary
	if gear_dropped == 0 and rng.randf()<0.18:
		item = _combat_item(false)
		gear_dropped += 1
	else: item = _material(enemy.global_position)
	drop([item],enemy.global_position)
	Outpost.request_checkpoint()

func _boss_material(_enemy:EnemyBase)->Dictionary:return {}

func _combat_item(boss:bool)->Dictionary:
	return BattleLootSelection.pick(rng,_equipment_weights(boss))

func _equipment(boss: bool) -> Dictionary:
	var pool: Array[Dictionary] = []
	for item in ItemDB.all():
		if ItemDB.is_equippable(item) and ItemDB.in_source(item,&"chest"): pool.append(item)
	return LootSelection.pick(pool,_equipment_weights(boss),rng)

func _equipment_weights(boss: bool) -> Array:
	var weights:Array=[55.0,30.0,12.0,3.0] if boss else [75.0,18.0,6.0,1.0]
	# Standard progression now reaches the former capped growth at room 30.
	for rarity in weights.size():
		weights[rarity]*=pow(1.0+GameState.danger*0.18+mini(GameState.wave,30)*0.01,rarity)
	return weights

func _material(at: Vector2) -> Dictionary:
	var rect: Rect2 = main.level.bounds()
	var part = clampf((at.x-rect.position.x)/rect.size.x,0,0.999)
	var id: String = "forest_sample" if part<0.35 else ("wetland_sample" if part<0.72 else "ruin_sample")
	if GameState.danger>=2 and GameState.wave>=20 and rng.randf()<0.35: id="echo_evidence"
	elif GameState.danger>=1 and GameState.wave>=10 and rng.randf()<0.35: id="deep_evidence"
	elif rng.randf()<0.08: id="memory_gift"
	elif rng.randf()<0.4: id="star_dust"
	elif rng.randf()<0.25:
		var regional: Array=["forest_resin","moss_cloth"] if part<0.35 else (["river_pearl"] if part<0.72 else ["ruin_ore"])
		if GameState.wave>=10:regional.append("storm_crystal")
		if GameState.wave>=20:regional.append("ancient_seal")
		id=regional[rng.randi_range(0,regional.size()-1)]
	var item = ExpeditionData.material(id)
	item["sale_value"] = int(round(float(item.cost)*RunDifficulty.material_value_multiplier(GameState.difficulty)*maxf(1.0,GameState.stats.get_value(&"coin_gain"))))
	return item

func drop(items: Array, at: Vector2, impulse = Vector2(0,-230), force_new := false) -> LootDrop:
	var existing = get_tree().get_nodes_in_group("expedition_loot").filter(func(n:Node)->bool:return not n.is_queued_for_deletion() and not n._collected)
	if not force_new and existing.size() >= 64:
		var near: LootDrop = existing[0]
		for node in existing:
			if node.global_position.distance_squared_to(at)<near.global_position.distance_squared_to(at): near=node
		for item in items: near.contents.append(item.duplicate(true))
		near.refresh_visual()
		return near
	var node = LootDrop.new()
	node.level = main.level
	node.player = main.player
	for item in items: node.contents.append(item.duplicate(true))
	node.velocity = impulse if impulse.x!=0 else Vector2(rng.randf_range(-95,95),impulse.y)
	main.fx_root.add_child(node)
	node.global_position = at
	return node

func burst_reward(loot: Dictionary, at: Vector2) -> void:
	match StringName(loot.get("kind", &"")):
		&"bundle":
			_burst_items(loot.get("items",[]),at)
			if int(loot.get("coins",0))>0:burst_reward({"kind":&"coins","amount":int(loot.coins),"coin_visual_scale":float(loot.get("coin_visual_scale",1.0))},at+Vector2(0,20))
		&"item", &"gear":
			var item: Variant = loot.get("item", {})
			if item is Dictionary and not item.is_empty(): _burst_items([item], at)
		&"coins":
			var amount := maxi(0, int(loot.get("amount", 0)))
			if amount <= 0: return
			var count := mini(amount, clampi(ceili(amount / 30.0), 2, 5))
			var occupied: Array[Vector2] = []
			for i in count:
				var landing := _scatter_landing(at, i, count, occupied)
				occupied.append(landing)
				var coin := Coin.new()
				coin.reward_visual_scale = float(loot.get("coin_visual_scale", 1.0))
				coin.setup(main.level, main.player, int(amount / count) + (1 if i < amount % count else 0))
				main.fx_root.add_child(coin)
				coin.launch_scatter(at, landing)

func _burst_items(items: Array, at: Vector2) -> void:
	var occupied: Array[Vector2] = []
	for i in items.size():
		var landing := _scatter_landing(at, i, items.size(), occupied)
		occupied.append(landing)
		var node := drop([items[i]], at, Vector2.ZERO, true)
		node.launch_scatter(at, landing)

func _scatter_landing(at: Vector2, index: int, count: int, occupied: Array[Vector2]) -> Vector2:
	var inner_count := mini(count, 12)
	var ring_index := index if index < 12 else index - 12
	var ring_count := inner_count if index < 12 else count - 12
	var radius := 78.0 if index < 12 else 132.0
	var angle := TAU * (float(ring_index) / maxf(1.0, float(ring_count))) + (0.0 if index < 12 else 0.18)
	for radius_scale in [1.0, 0.72, 1.28, 0.45, 1.55]:
		for turn in [0, 1, -1, 2, -2, 3, -3, 4, -4]:
			var candidate: Vector2 = at + Vector2.RIGHT.rotated(angle + float(turn) * TAU / 36.0) * radius * float(radius_scale)
			if not _landing_clear(candidate): continue
			var separated := true
			for point in occupied:
				if point.distance_squared_to(candidate) < 22.0 * 22.0: separated = false; break
			if separated: return candidate
	if main.level is RoomLevel:
		return (main.level as RoomLevel).nearest_clear(at + Vector2.RIGHT.rotated(angle) * radius, 8.0)
	return at

func _landing_clear(at: Vector2) -> bool:
	if main.level is RoomLevel: return (main.level as RoomLevel).body_clear(at, 8.0)
	var level: Level = main.level
	return level.bounds().grow(-10.0).has_point(at) and not level.is_solid_cell(level.world_to_cell(at))

func snapshot() -> Dictionary:
	return {"state":str(rng.state),"wave":_wave,"dropped":dropped,"gear":gear_dropped,"keys":keys_dropped,"receipts":receipts.duplicate()}

func restore(d: Dictionary) -> void:
	rng.state = int(d.get("state",rng.state))
	_wave = int(d.get("wave",-1))
	dropped = int(d.get("dropped",0))
	gear_dropped = int(d.get("gear",0))
	keys_dropped = int(d.get("keys",0))
	receipts = d.get("receipts",{}).duplicate()

