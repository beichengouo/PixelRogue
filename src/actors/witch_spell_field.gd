class_name WitchSpellField
extends Node2D
## 自然领域 / 陨星落点。使用局内时间，暂停与重新开局均正确终止。
var radius := 220.0
var attack := 14.0
var ratio := 0.45
var duration := 5.0
var interval := 0.75
var heal_ratio := 0.02
var meteor := false
var caster: WeakRef
var _age := 0.0
var _next_tick := 0.0
var _meteor_art: Sprite2D
var _wreath: Sprite2D

func _ready() -> void:
	z_index = 3
	add_to_group("spell_fields")
	if not meteor:
		PixelSpellFX.spawn(get_parent(), global_position, "nature", "impact", radius * 1.7, 0.85, 0, true)
		_wreath = Sprite2D.new()
		_wreath.texture = PixelSpellArt.frames("nature")[12]
		_wreath.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_wreath.scale = Vector2.ONE * radius * 2.0 / PixelSpellArt.LOGICAL_SIZE
		_wreath.modulate.a = 0.32 * PixelSpellArt.strength()
		_wreath.material = PixelSpellArt.material()
		add_child(_wreath)
	else:
		_meteor_art = Sprite2D.new()
		_meteor_art.texture = PixelSpellArt.frames("fire")[12]
		_meteor_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_meteor_art.scale = Vector2.ONE * 125.0 / PixelSpellArt.LOGICAL_SIZE
		_meteor_art.rotation = Vector2(-120, 280).angle()
		_meteor_art.material = PixelSpellArt.material()
		add_child(_meteor_art)
		_meteor_art.position = Vector2(120, -280)

func _process(delta: float) -> void:
	_age += delta
	if meteor:
		_meteor_art.texture = PixelSpellArt.frames("fire")[12 + int(_age * 20) % 4]
		_meteor_art.position = Vector2(120, -280) * (1.0 - clampf(_age / duration, 0, 1))
		if _age >= duration:
			_strike()
			queue_free()
	else:
		_wreath.texture = PixelSpellArt.frames("nature")[12 + int(_age * 6) % 4]
		_wreath.modulate.a = 0.32 * PixelSpellArt.strength() * minf(_age / 0.25, 1) * clampf((duration - _age) / 0.6, 0, 1)
		# 低帧率时补齐有效时段的脉冲；结束边界不再多结算一次。
		while _next_tick < duration and _next_tick <= minf(_age,duration):
			_next_tick += maxf(interval,0.01)
			_strike()
		if _age >= duration:queue_free()
	queue_redraw()

func _strike() -> void:
	var owner_node := caster.get_ref() as Player if caster != null else null
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyBase
		if not is_instance_valid(enemy) or enemy.global_position.distance_to(global_position) > radius:
			continue
		enemy.take_damage(attack * ratio, false, global_position, owner_node, meteor)
		if not meteor and is_instance_valid(enemy):
			enemy.apply_slow(0.3, 1.0)
	if meteor:
		PixelSpellFX.spawn(get_parent(), global_position, "fire", "impact", radius * 1.9, 0.85, 0, true)
		PixelSpellFX.spawn(get_parent(), global_position, "star", "aura", radius * 1.4, 0.65, 0, true)
		EventBus.request_screen_shake.emit(8.0)
	else:
		PixelSpellFX.spawn(get_parent(), global_position, "nature", "aura", radius * 1.2, 0.45)
		if is_instance_valid(owner_node) and owner_node.hp > 0 and owner_node.global_position.distance_to(global_position) <= radius:
			owner_node.heal_player(owner_node.max_hp * heal_ratio)

func _draw() -> void:
	var color := Color("e9af74") if meteor else Color("91d5a0")
	var fade := 1.0 if meteor else minf(_age / 0.25, 1.0) * minf((duration - _age) / 0.6, 1.0)
	color.a = 0.11 * fade
	draw_circle(Vector2.ZERO, radius, color)
	color.a = 0.55 * fade
	draw_arc(Vector2.ZERO, radius, 0, TAU, 96, color, 2, false)
	if meteor:
		draw_arc(Vector2.ZERO, radius * clampf(_age / duration, 0, 1), 0, TAU, 72, color, 3, false)
	else:
		for i in 12:
			var at := Vector2.from_angle(float(i) / 12 * TAU + _age * 0.12) * (radius - 8)
			var leaf := PackedVector2Array([at + Vector2(-6, 0), at + Vector2(0, -3), at + Vector2(6, 0), at + Vector2(0, 3)])
			draw_colored_polygon(leaf, color)
