class_name BoomerangKnife
extends Node2D
## 佣兵丢出去的飞刀：飞出去 → 停一下 → 飞回来（和玩家近战武器同一套"戳出去再收回"的思路）。
## 去程和回程都会割到敌人，落地/超时就消失。

const OUT_TIME := 0.26
const BACK_TIME := 0.34
const SPIN := 12.0

var damage := 10.0
var owner_ally: Node2D

var _dir := Vector2.RIGHT
var _from := Vector2.ZERO
var _dist := 210.0
var _t := 0.0
var _hit_ids: Dictionary = {}
var _sprite: Sprite2D
var _spin := 0.0


func setup(from: Vector2, dir: Vector2, dmg: float, ally: Node2D) -> void:
	_from = from
	_dir = dir.normalized()
	damage = dmg
	owner_ally = ally
	global_position = from
	var bonus: Dictionary = GameState.ally_bonus()
	_dist = 210.0 * (1.0 + (float(bonus.get("attack", 1.0)) - 1.0) * 0.4)


func _ready() -> void:
	z_index = 6
	_sprite = Sprite2D.new()
	# 五把小刀随机挑一把当贴图
	var index := Rng.stream().randi_range(1, 5)
	var path := "res://assets/characters/knife_%d.png" % index
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		_sprite.scale = Vector2.ONE * 0.85
	else:
		_sprite.texture = load("res://assets/fx/slash.png")
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_t += delta
	_spin += delta * SPIN
	var total := OUT_TIME + BACK_TIME
	if _t >= total:
		queue_free()
		return
	var u := 0.0
	if _t <= OUT_TIME:
		u = _t / OUT_TIME
	else:
		u = 1.0 - (_t - OUT_TIME) / BACK_TIME
	var next := _from + _dir * _dist * u
	if is_instance_valid(owner_ally) and owner_ally is HiredAlly:
		var map: Level = owner_ally.level
		if map != null and not map.clear_sight(global_position,next):
			queue_free()
			return
	global_position = next
	if _sprite != null:
		_sprite.rotation = _spin
	_check_hits()


func _check_hits() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var enemy := node as EnemyBase
		if enemy == null or not is_instance_valid(enemy):
			continue
		var key := enemy.get_instance_id()
		if _hit_ids.has(key):
			continue
		if enemy.global_position.distance_to(global_position) < 30.0:
			_hit_ids[key] = true
			# A thrown knife outlives its ally. Preserve ally attribution while alive,
			# otherwise this non-player projectile is the valid damage source.
			var source: Node = owner_ally if is_instance_valid(owner_ally) and not owner_ally.is_queued_for_deletion() else self
			var before: float = enemy.hp
			enemy.take_damage(damage, false, global_position, source)
			if enemy.hp<before and source is HiredAlly and GameState.player is RoomPlayer:
				(GameState.player as RoomPlayer).equipment_mechanics.on_ally_hit(enemy,source)
			Effects.hit_spark(get_parent(), global_position, Color("e0b64a"), 4)
