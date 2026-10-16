class_name EquipmentMechanics
extends Node
## Room-combat equipment state. Timers use active scene time and travel with the run.
var actor: RoomPlayer
var clock := 0.0
var cooldowns: Dictionary = {}
var ember_burst: Dictionary = {}
var ember_hits: Dictionary = {}
var star_marks: Dictionary = {}
var dusk_marks: Dictionary = {}
var soul_mark: WeakRef
var soul_mark_until := 0.0
var wind_until := 0.0
var wind_dash_serial := 0
var wind_refunded_serial := -1
var refract_charges := 0
var refract_ready := false
var tide_until := 0.0
var patrol_until := 0.0
var dusk_deaths: Array[float] = []
var _counts: Dictionary = {}
var current_room_id:=""
var legendary:=LegendaryMechanics.new()
var expansion:=ExpansionEquipment.new()
var cadence:=CadenceEquipment.new()
var wayfarer:=WayfarerRelics.new()

func _ready() -> void:
	if actor == null: actor = get_parent() as RoomPlayer
	legendary.owner=self
	expansion.owner=self
	cadence.owner=self
	wayfarer.owner=self
	EventBus.equipment_changed.connect(refresh)
	EventBus.player_stats_changed.connect(refresh)
	refresh()

func _process(delta: float) -> void:
	clock += delta
	legendary.tick()
	cadence.tick()
	wayfarer.tick(delta)
	for key in cooldowns.keys():
		if float(cooldowns[key]) <= clock: cooldowns.erase(key)
	for key in ember_burst.keys():
		if float(ember_burst[key]) <= clock: ember_burst.erase(key)
	for key in ember_hits.keys():
		var mark: Dictionary = ember_hits[key]
		var marked_enemy: EnemyBase = mark.enemy.get_ref() as EnemyBase if mark.get("enemy") is WeakRef else null
		if not _live_enemy(marked_enemy) or marked_enemy._burn_time <= 0.0:
			_remove_marker(marked_enemy, "ember")
			ember_hits.erase(key)
	for key in star_marks.keys():
		var mark: Dictionary = star_marks[key]
		if float(mark.get("until", 0.0)) <= clock or not is_instance_valid(mark.get("enemy")):
			_remove_marker(mark.get("enemy"), "star")
			star_marks.erase(key)
	for key in dusk_marks.keys():
		var mark: Dictionary = dusk_marks[key]
		var marked_ally: Node = mark.ally.get_ref() if mark.get("ally") is WeakRef else null
		if float(mark.get("until", 0.0)) <= clock or not _live_ally(marked_ally):
			_remove_marker(marked_ally, "dusk")
			dusk_marks.erase(key)
	if soul_mark != null and soul_mark_until <= clock:
		_remove_marker(soul_mark.get_ref(), "soul")
		soul_mark = null
	while not dusk_deaths.is_empty() and dusk_deaths[0] <= clock - 1.0:
		dusk_deaths.pop_front()
	if has(&"companion_knot") and is_instance_valid(actor) and actor.hp > 0:
		var nearby := 0
		for unit in get_tree().get_nodes_in_group("allies"):
			if _live_ally(unit) and unit.global_position.distance_to(actor.global_position) <= 144.0: nearby += 1
		if nearby >= 2: GameState.add_mp(GameState.total_mp_regen(actor.stats) * 0.15 * scale(&"companion_knot") * delta)

func refresh() -> void:
	_counts.clear()
	for item in GameState.items:
		if item is Dictionary and not ItemDB.is_equippable(item): _count_item(item)
	for slot in ItemDB.SLOTS:
		var item: Dictionary = GameState.equipped(slot)
		if not item.is_empty(): _count_item(item)
	if not has(&"patrol_bell"): patrol_until = 0.0
	cadence.refresh()
	legendary.refresh()
	wayfarer.refresh()

func _count_item(item: Dictionary) -> void:
	for effect in item.get("mechanics", []):
		if not effect is Dictionary: continue
		var key := StringName(effect.get("id", ""))
		if key != &"": _counts[key] = int(_counts.get(key, 0)) + 1

func has(key: StringName) -> bool: return int(_counts.get(key, 0)) > 0
func scale(key: StringName) -> float:
	match int(_counts.get(key, 0)):
		0: return 0.0
		1: return 1.0
		2: return 1.5
		_: return 1.75
func attack() -> float: return actor.stats.get_value(&"attack") if is_instance_valid(actor) else 0.0
func ready(key: StringName) -> bool: return clock >= float(cooldowns.get(key, 0.0))
func start(key: StringName, duration: float) -> void: cooldowns[key] = clock + duration

func on_room_enter(room_id: String, uncleared_normal: bool) -> void:
	if current_room_id!="" and current_room_id!=room_id:
		for mark in star_marks.values():_remove_marker(mark.get("enemy"),"star")
		for mark in dusk_marks.values():_remove_marker(mark.ally.get_ref(),"dusk")
		if soul_mark!=null:_remove_marker(soul_mark.get_ref(),"soul")
		star_marks.clear();dusk_marks.clear();ember_hits.clear();soul_mark=null
		wind_until=0;tide_until=0;patrol_until=0;refract_charges=0;refract_ready=false
		wayfarer.room_changed()
	current_room_id=room_id
	if not has(&"afterglow_note") or not uncleared_normal or not is_instance_valid(actor.room): return
	var room_record: Dictionary = actor.room.record
	if not room_record.has("delta"): room_record["delta"] = {}
	if bool(room_record.delta.get("afterglow_note_used", false)): return
	room_record.delta["afterglow_note_used"] = true
	grant_player_shield(actor.max_hp * 0.10 * scale(&"afterglow_note"), 8.0)

func on_dash_end() -> void:
	legendary.dash_end()
	expansion.dash()
	wind_dash_serial += 1
	if has(&"wind_branch"): wind_until = clock + 3.0
	if has(&"swallow_return") and ready(&"swallow_return"):
		grant_player_shield(actor.max_hp * 0.08 * scale(&"swallow_return"), 2.0)
		start(&"swallow_return", 5.0)
	patrol_until = clock + 3.0 if has(&"patrol_bell") else 0.0

func fire_basic(direction: Vector2, roll: Dictionary, receipt: BasicAttackReceipt) -> bool:
	## Returns true when the dash empowered attack replaces the ordinary shot.
	if wind_until <= clock or not has(&"wind_branch"): return false
	wind_until = 0.0
	WeaponBuildFX.pulse(actor.get_parent(), actor.global_position, "wind_branch", "cast", 88.0, direction.angle())
	for index in 3:
		var angle := (index - 1) * deg_to_rad(16.0)
		var bullet := actor.fire(direction.rotated(angle), float(roll.damage) * 0.55 * scale(&"wind_branch"), 430.0, true, receipt)
		bullet.pierce = 1
		bullet.mechanic_tag = &"wind_fan"
	return true

func on_basic_hit(enemy: EnemyBase, receipt: BasicAttackReceipt, projectile: RoomProjectile) -> void:
	if not is_instance_valid(enemy): return
	if is_instance_valid(actor.holy_runtime):actor.holy_runtime.on_direct_hit(enemy,0,receipt)
	legendary.basic_hit(enemy,receipt)
	expansion.basic(enemy,receipt)
	cadence.basic(enemy,receipt)
	wayfarer.basic(enemy,receipt)
	if has(&"tide_pearl") and tide_until > clock and receipt != null and receipt.claim_effect(&"tide_pearl") and ready(&"tide_pearl"):
		GameState.add_mp(3.0 * scale(&"tide_pearl")); tide_until = 0.0; start(&"tide_pearl", 3.0)
	if has(&"refraction") and receipt != null and receipt.critical and receipt.claim_effect(&"refract_charge"):
		refract_charges = mini(3, refract_charges + 1)
		if refract_charges >= 3: refract_ready = true
	if projectile.mechanic_tag == &"wind_fan" and has(&"wind_chime") and wind_refunded_serial != wind_dash_serial:
		wind_refunded_serial = wind_dash_serial
		actor._dash_cd = maxf(0.0, actor._dash_cd * (1.0 - 0.20 * scale(&"wind_chime")))
	if not _live_enemy(enemy): return
	var a := attack()
	if has(&"ember_flower"):
		var key := enemy.get_instance_id()
		var burning := enemy._burn_time > 0.0
		enemy.apply_burn(a * 0.12 * scale(&"ember_flower"), 3.0, DamageContext.dot(actor))
		if not burning:
			ember_hits.erase(key)
			_remove_marker(enemy, "ember")
		else:
			var ember: Dictionary = ember_hits.get(key, {"enemy": weakref(enemy), "count": 0})
			ember["enemy"] = weakref(enemy)
			ember["count"] = mini(3, int(ember.get("count", 0)) + 1)
			ember_hits[key] = ember
			_update_ember_petals(enemy, int(ember.count))
			if int(ember.count) >= 3 and clock >= float(ember_burst.get(key, 0.0)):
				ember_burst[key] = clock + 2.0
				ember_hits.erase(key)
				_remove_marker(enemy, "ember")
				WeaponBuildFX.pulse(actor.get_parent(), enemy.global_position, "ember_flower", "proc", 144.0)
				area_damage(enemy.global_position, 72.0, a * 0.65 * scale(&"ember_flower"))
	if has(&"star_weave"):
		var key := enemy.get_instance_id()
		var mark: Dictionary = star_marks.get(key, {"enemy": enemy, "count": 0, "until": 0.0})
		mark["enemy"] = enemy
		mark["count"] = (int(mark.get("count", 0)) if float(mark.get("until", 0.0)) > clock else 0) + 1
		mark["until"] = clock + 4.0
		star_marks[key] = mark
		_ensure_marker(enemy, "star", "star_weave", Color("a7cfff"))
		WeaponBuildFX.pulse(actor.get_parent(), enemy.global_position, "star_weave", "proc", 40.0)
		if has(&"star_mirror"): on_star_mark_hit()
		if int(mark["count"]) >= 3 and ready(&"star_chain"):
			star_marks.erase(key)
			_remove_marker(enemy, "star")
			start(&"star_chain", 0.6)
			var targets := nearest_enemies(enemy.global_position, 144.0, 3, enemy)
			for target in targets:
				_visual_link(enemy.global_position, target.global_position)
				WeaponBuildFX.pulse(actor.get_parent(), target.global_position, "star_weave", "impact", 64.0)
				extra_damage(target, a * 0.35 * scale(&"star_weave"), enemy.global_position)
	if has(&"soul_command"):
		if soul_mark != null: _remove_marker(soul_mark.get_ref(), "soul")
		soul_mark = weakref(enemy)
		soul_mark_until = clock + 4.0
		_ensure_marker(enemy, "soul", "soul_command", Color("bd9cff"))
		WeaponBuildFX.pulse(actor.get_parent(), enemy.global_position, "soul_command", "proc", 44.0)
	if has(&"dusk_lantern") and ready(&"dusk_mark"):
		var nearest: HiredAlly
		var best := INF
		for ally in get_tree().get_nodes_in_group("contracts"):
			if not _live_ally(ally): continue
			var distance := actor.global_position.distance_squared_to(ally.global_position)
			if distance < best: best = distance; nearest = ally as HiredAlly
		if nearest != null:
			dusk_marks[nearest.get_instance_id()] = {"ally": weakref(nearest), "uid": nearest.uid, "until": clock + 6.0}
			_ensure_marker(nearest, "dusk", "dusk_lantern", Color("f1d49b"))
			WeaponBuildFX.pulse(actor.get_parent(), nearest.global_position, "dusk_lantern", "proc", 44.0)
			start(&"dusk_mark", 1.0)
	if has(&"hunt_needle") and enemy._slow_time > 0.0 and ready(StringName("hunter_%d" % enemy.get_instance_id())):
		extra_damage(enemy, a * 0.12 * scale(&"hunt_needle"), projectile.global_position)
		start(StringName("hunter_%d" % enemy.get_instance_id()), 1.0)

func on_basic_fired(direction: Vector2, receipt: BasicAttackReceipt) -> void:
	if not refract_ready or not has(&"refraction"): return
	refract_ready = false; refract_charges = 0
	var side := direction.rotated(deg_to_rad(18.0))
	var bullet := actor.fire(side, attack() * 0.45 * scale(&"refraction"), 430.0, false, null)
	bullet.mechanic_tag = &"equipment"
	bullet.burn_dps = 0.0
	bullet.explosion_radius = 0.0
	bullet.explosion_ratio = 0.0

func on_skill_cast(shield_cast: bool = false,id:StringName=&"") -> float:
	var bonus := legendary.skill_cast(id)+wayfarer.skill(id)
	expansion.skill(id)
	cadence.skill(id)
	if patrol_until > clock:
		bonus += 0.12 * scale(&"patrol_bell")
		patrol_until = 0.0
	if has(&"tide_pearl") and ready(&"tide_pearl"): tide_until = clock + 4.0
	if shield_cast and has(&"watch_button"):
		var allies: Array = []
		for ally in get_tree().get_nodes_in_group("allies"):
			if _live_ally(ally) and ally.global_position.distance_to(actor.global_position) <= 144.0 and ally.shield_hp <= 0.0: allies.append(ally)
		allies.sort_custom(func(left: Node, right: Node) -> bool: return left.global_position.distance_squared_to(actor.global_position) < right.global_position.distance_squared_to(actor.global_position))
		for i in mini(3, allies.size()): grant_ally_shield(allies[i], allies[i].max_hp * 0.08 * scale(&"watch_button"), 4.0)
	if has(&"contract_chorus"):
		for ally in get_tree().get_nodes_in_group("allies"):
			if _live_ally(ally): ally.equipment_haste_time = 3.0; ally.equipment_haste = 0.15 * scale(&"contract_chorus")
	return bonus

func skill_multiplier(enemy: EnemyBase) -> float:
	var result := 1.0
	if has(&"breaker_stone") and enemy.is_elite(): result += 0.15 * scale(&"breaker_stone")
	return result

func on_skill_hit(enemy: EnemyBase, direct: bool = true) -> void:
	if direct and is_instance_valid(enemy):expansion.skill_hit(enemy)
	if not direct or not is_instance_valid(enemy): return
	cadence.skill_hit(enemy)
	wayfarer.skill_hit(enemy)
	if is_instance_valid(actor.holy_runtime):actor.holy_runtime.on_direct_hit(enemy,1)
	if has(&"scorch_bloom") and _live_enemy(enemy) and enemy._burn_time > 0.0 and ready(StringName("flower_%d" % enemy.get_instance_id())):
		extra_damage(enemy, attack() * 0.25 * scale(&"scorch_bloom"), actor.global_position)
		start(StringName("flower_%d" % enemy.get_instance_id()), 1.0)
	if has(&"oath_guard") and ready(&"oath_guard"):
		grant_player_shield(actor.max_hp * 0.06 * scale(&"oath_guard"), 4.0)
		start(&"oath_guard", 4.0)

func on_ally_hit(enemy: EnemyBase, ally: Node2D) -> void:
	if not _live_enemy(enemy) or not _live_ally(ally): return
	legendary.ally_hit(enemy)
	expansion.ally_hit(ally)
	cadence.ally_hit(ally)
	if has(&"soul_command") and soul_mark_until > clock and soul_mark != null and soul_mark.get_ref() == enemy and ally.global_position.distance_to(enemy.global_position) <= 144.0:
		extra_damage(enemy, ally.attack * 0.15 * scale(&"soul_command"), ally.global_position)

func preferred_enemy(ally: Node2D) -> EnemyBase:
	if not has(&"soul_command") or soul_mark_until <= clock or soul_mark == null: return null
	var target := soul_mark.get_ref() as EnemyBase
	if not _live_enemy(target) or ally.global_position.distance_to(target.global_position) > 520.0: return null
	if ally is RoomAlly and not (ally as RoomAlly).room.sight(ally.global_position, target.global_position): return null
	return target

func on_enemy_damaged(_enemy: EnemyBase, _amount: float, _source: Node, _damage_type: StringName = &"") -> void:
	pass

func on_enemy_died(enemy: EnemyBase, _source: Node, damage_type: StringName = &"") -> void:
	wayfarer.enemy_died(enemy)
	var burn_source: Node = enemy._burn_source.get_ref() if enemy._burn_source != null else null
	var propagated:bool = burn_source is DamageContext and burn_source.owner_kind==&"spread_burn"
	if has(&"ember_seed") and enemy._burn_time>0 and not propagated and damage_type!=&"equipment":
		for target in nearest_enemies(enemy.global_position,72,2,enemy):
			target.apply_burn(enemy._burn_dps*scale(&"ember_seed"),enemy._burn_time,DamageContext.spread_burn(actor))
	_remove_marker(enemy,"ember");_remove_marker(enemy,"star");_remove_marker(enemy,"soul")
	ember_hits.erase(enemy.get_instance_id());star_marks.erase(enemy.get_instance_id())

func on_contract_killed(unit: SummonedAlly, source: Node) -> void:
	legendary.contract_killed(unit,source)
	var key:=unit.get_instance_id()
	if not dusk_marks.has(key):return
	var mark:Dictionary=dusk_marks[key];dusk_marks.erase(key);_remove_marker(unit,"dusk")
	var hostile:bool=is_instance_valid(source) and (source is EnemyBase or source is AffixHazard or source is Projectile and not source.is_friendly)
	if not hostile or not has(&"dusk_lantern") or float(mark.until)<=clock or unit.remaining<=0:return
	while not dusk_deaths.is_empty() and dusk_deaths[0]<=clock-1:dusk_deaths.pop_front()
	if dusk_deaths.size()>=3:return
	dusk_deaths.append(clock)
	WeaponBuildFX.pulse(actor.get_parent(),unit.global_position,"dusk_lantern","proc",144)
	var hit:=false
	for target in nearest_enemies(unit.global_position,72,100):
		var hp_before:=target.hp;var shield_before:=target.affix_shield
		extra_damage(target,attack()*.7,unit.global_position)
		if target.hp<hp_before or target.affix_shield<shield_before:hit=true
	if hit:on_dusk_hit()

func on_shield_broken() -> void:
	expansion.shield_broken()
	cadence.shield_broken()
	wayfarer.shield_broken()
	if not has(&"thorn_moon") or not ready(&"thorn_moon"): return
	start(&"thorn_moon", 4.0)
	area_damage(actor.global_position, 108.0, attack() * 0.9 * scale(&"thorn_moon"))
	if has(&"thorn_shard"):
		for enemy in nearest_enemies(actor.global_position, 108.0, 100): enemy.apply_slow(0.125 * scale(&"thorn_shard") if enemy is BossBase else 0.25 * scale(&"thorn_shard"), 2.0)

func on_dusk_hit() -> void:
	if has(&"farewell") and ready(&"farewell"):
		grant_player_shield(actor.max_hp * 0.05 * scale(&"farewell"), 4.0)
		start(&"farewell", 3.0)
	if has(&"echo_wick") and ready(&"echo_wick"):
		GameState.add_mp(3.0 * scale(&"echo_wick")); start(&"echo_wick", 2.0)

func on_star_mark_hit() -> void:
	if has(&"star_mirror") and ready(&"star_mirror"):
		GameState.add_mp(1.0 * scale(&"star_mirror")); start(&"star_mirror", 1.0)

func extra_damage(enemy: EnemyBase, amount: float, from: Vector2) -> void:
	if _live_enemy(enemy) and amount > 0.0: enemy.take_damage(amount, false, from, DamageContext.equipment(actor), false)

func area_damage(origin: Vector2, radius: float, amount: float, excluded: EnemyBase = null) -> void:
	for enemy in nearest_enemies(origin, radius, 100, excluded): extra_damage(enemy, amount, origin)

func nearest_enemies(origin: Vector2, radius: float, limit: int, excluded: EnemyBase = null) -> Array[EnemyBase]:
	var found:Array[EnemyBase]=[];var candidates:Array[EnemyBase]=[]
	if limit<=0:return found
	var roster:Array=actor.room.tactics.enemies(actor.room) if is_instance_valid(actor.room) else get_tree().get_nodes_in_group("enemies")
	for node in roster:
		var enemy:=node as EnemyBase
		if enemy!=excluded and _live_enemy(enemy) and origin.distance_squared_to(enemy.global_position)<=radius*radius:candidates.append(enemy)
	candidates.sort_custom(func(left:EnemyBase,right:EnemyBase)->bool:return left.global_position.distance_squared_to(origin)<right.global_position.distance_squared_to(origin))
	for enemy in candidates:
		if not is_instance_valid(actor.room) or actor.room.projectile_clear(origin,enemy.global_position):found.append(enemy)
		if found.size()>=limit:break
	return found

func grant_player_shield(amount: float, duration: float) -> void:
	if not is_instance_valid(actor) or actor.hp <= 0.0: return
	if amount>=actor.shield_hp:
		actor.shield_hp=amount;actor._shield_time=duration

func grant_ally_shield(ally: HiredAlly, amount: float, duration: float) -> void:
	if amount>=ally.shield_hp:
		ally.shield_hp=amount;ally.shield_time=duration

func _ensure_marker(enemy: Node2D, tag: String, effect: String, tint: Color) -> void:
	if not is_instance_valid(enemy): return
	var name_value := "EquipmentMark_" + tag
	var existing := enemy.get_node_or_null(name_value) as Sprite2D
	if existing != null: return
	var frames := WeaponBuildFX.frames(str(WeaponBuildFX.EFFECT_WEAPONS.get(effect, effect)), "proc")
	if frames.is_empty(): return
	var marker := Sprite2D.new()
	marker.name = name_value
	marker.texture = frames[0]
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.modulate = tint
	marker.modulate.a = 0.6
	marker.scale = Vector2.ONE * 0.3
	marker.position = Vector2(0.0, -maxf(24.0, enemy.body_size.y * 0.7 if enemy is EnemyBase else 36.0))
	marker.z_index = 8
	enemy.add_child(marker)

func _remove_marker(enemy: Node, tag: String) -> void:
	if not is_instance_valid(enemy): return
	var marker := enemy.get_node_or_null("EquipmentMark_" + tag)
	if marker != null:
		enemy.remove_child(marker);marker.queue_free()

func _visual_link(from: Vector2, to: Vector2) -> void:
	var parent := actor.get_parent()
	if not is_instance_valid(parent): return
	var link := Line2D.new()
	link.width = 3.0
	link.default_color = Color("9bcaff")
	parent.add_child(link)
	link.add_point(link.to_local(from))
	link.add_point(link.to_local(to))
	var tween := link.create_tween()
	tween.tween_property(link, "modulate:a", 0.0, 0.22)
	tween.tween_callback(link.queue_free)

func _live_enemy(enemy: EnemyBase) -> bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy._dead
func _live_ally(ally: Node) -> bool:
	return is_instance_valid(ally) and not ally.is_queued_for_deletion() and ally is HiredAlly and ally.hp > 0.0 and ally.player==actor and (not ally is RoomAlly or ally.room==actor.room)

func snapshot() -> Dictionary:
	var saved_hits:Array=[]
	for key in ember_hits:
		var enemy:EnemyBase=ember_hits[key].enemy.get_ref() as EnemyBase
		if _live_enemy(enemy):saved_hits.append({"enemy":str(key),"count":int(ember_hits[key].count)})
	var saved_cooldowns: Dictionary = {}
	for key in cooldowns: saved_cooldowns[str(key)] = maxf(0.0, float(cooldowns[key]) - clock)
	var saved_ember: Dictionary = {}
	for key in ember_burst: saved_ember[str(key)] = maxf(0.0, float(ember_burst[key]) - clock)
	var saved_star: Array = []
	for mark in star_marks.values():
		if is_instance_valid(mark.get("enemy")): saved_star.append({"enemy": str(mark.enemy.get_instance_id()), "count": int(mark.count), "left": maxf(0.0, float(mark.until) - clock)})
	var saved_dusk: Array = []
	for mark in dusk_marks.values():
		var ally:Node=mark.ally.get_ref() if mark.get("ally") is WeakRef else null
		if _live_ally(ally):saved_dusk.append({"ally_uid":str(ally.uid),"left":maxf(0,float(mark.until)-clock)})
	var soul_id := str(soul_mark.get_ref().get_instance_id()) if soul_mark != null and is_instance_valid(soul_mark.get_ref()) else ""
	var death_left: Array = []
	for death_time in dusk_deaths: death_left.append(maxf(0.0, float(death_time) + 1.0 - clock))
	return {"wayfarer":wayfarer.snapshot(),"cadence":cadence.snapshot(),"expansion":expansion.snapshot(),"legendary":legendary.snapshot(),"ember_hits":saved_hits,"cooldowns": saved_cooldowns, "ember_burst": saved_ember, "star_marks": saved_star, "dusk_marks": saved_dusk, "soul_id": soul_id, "soul_left": maxf(0.0, soul_mark_until - clock), "dusk_deaths": death_left, "wind_left": maxf(0.0, wind_until - clock), "wind_dash_serial": wind_dash_serial, "wind_refunded_serial": wind_refunded_serial, "refract_charges": refract_charges, "refract_ready": refract_ready, "tide_left": maxf(0.0, tide_until - clock), "patrol_left": maxf(0.0, patrol_until - clock)}

func restore(data: Dictionary, restored_ids: Dictionary = {}) -> void:
	expansion.restore(data.get("expansion",{}))
	cadence.restore(data.get("cadence",{}))
	wayfarer.restore(data.get("wayfarer",{}),restored_ids)
	legendary.restore(data.get("legendary",{}))
	current_room_id=str(data.get("current_room_id",actor.room.record.get("id","") if is_instance_valid(actor.room) else ""))
	cooldowns.clear()
	for key in data.get("cooldowns", {}):
		var mapped_key := str(key)
		for prefix in ["flower_", "hunter_"]:
			if mapped_key.begins_with(prefix):
				var old_id := mapped_key.trim_prefix(prefix)
				if restored_ids.has(old_id): mapped_key = prefix + str(restored_ids[old_id].get_instance_id())
		cooldowns[StringName(mapped_key)] = clock + maxf(0.0, float(data.cooldowns[key]))
	ember_burst.clear()
	for key in data.get("ember_burst", {}):
		if restored_ids.has(str(key)): ember_burst[restored_ids[str(key)].get_instance_id()] = clock + maxf(0.0, float(data.ember_burst[key]))
	star_marks.clear()
	for saved in data.get("star_marks", []):
		var enemy: EnemyBase = restored_ids.get(str(saved.get("enemy", ""))) as EnemyBase
		if is_instance_valid(enemy):
			star_marks[enemy.get_instance_id()] = {"enemy": enemy, "count": int(saved.get("count", 0)), "until": clock + maxf(0.0, float(saved.get("left", 0.0)))}
			_ensure_marker(enemy, "star", "star_weave", Color("a7cfff"))
	ember_hits.clear()
	for saved in data.get("ember_hits",[]):
		var enemy:EnemyBase=restored_ids.get(str(saved.get("enemy",""))) as EnemyBase
		if _live_enemy(enemy):
			ember_hits[enemy.get_instance_id()]={"enemy":weakref(enemy),"count":int(saved.count)}
			_update_ember_petals(enemy,int(saved.count))
	dusk_marks.clear()
	for saved in data.get("dusk_marks",[]):
		for ally in get_tree().get_nodes_in_group("contracts"):
			if _live_ally(ally) and str(ally.uid)==str(saved.get("ally_uid","")):
				dusk_marks[ally.get_instance_id()]={"ally":weakref(ally),"uid":ally.uid,"until":clock+maxf(0,float(saved.get("left",0)))}
				_ensure_marker(ally,"dusk","dusk_lantern",Color("e0c8ff"))
				break
	soul_mark = null
	var saved_soul: EnemyBase = restored_ids.get(str(data.get("soul_id", ""))) as EnemyBase
	if is_instance_valid(saved_soul):
		soul_mark = weakref(saved_soul)
		_ensure_marker(saved_soul, "soul", "soul_command", Color("bd9cff"))
	soul_mark_until = clock + maxf(0.0, float(data.get("soul_left", 0.0)))
	dusk_deaths.clear()
	for left in data.get("dusk_deaths", []): dusk_deaths.append(clock - 1.0 + clampf(float(left), 0.0, 1.0))
	wind_until = clock + maxf(0.0, float(data.get("wind_left", 0.0)))
	wind_dash_serial = int(data.get("wind_dash_serial", 0))
	wind_refunded_serial = int(data.get("wind_refunded_serial", -1))
	refract_charges = clampi(int(data.get("refract_charges", 0)), 0, 3)
	refract_ready = bool(data.get("refract_ready", false))
	tide_until = clock + maxf(0.0, float(data.get("tide_left", 0.0)))
	patrol_until = clock + maxf(0.0, float(data.get("patrol_left", 0.0)))

func _update_ember_petals(enemy:EnemyBase,count:int)->void:
	_ensure_marker(enemy,"ember","ember_flower",Color.WHITE)
	var marker:=enemy.get_node_or_null("EquipmentMark_ember") as Sprite2D
	if marker!=null:
		var selected:=WeaponBuildFX.frames("staff_ember_flower","proc")
		if not selected.is_empty():marker.texture=selected[clampi(count-1,0,2)]
