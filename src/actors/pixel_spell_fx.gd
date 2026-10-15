class_name PixelSpellFX
extends Sprite2D
## 纯表现节点：不写伤害、冷却和时间缩放。大招额外绘制像素冲击环与余光。
const MAX_ACTIVE := 96
var _age := 0.0
var _duration := 0.48
var _frames: Array[Texture2D] = []
var _first := 4
var _count := 8
var _light: PointLight2D
var _strength := 1.0
var _family := "fire"
var _dramatic := false
var _width := 96.0

static func spawn(parent: Node, where: Vector2, family := "fire", kind := "impact", width := 96.0, duration := 0.48, angle := 0.0, dramatic := false) -> PixelSpellFX:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var strength := PixelSpellArt.strength()
	if strength <= 0 or parent.get_tree().get_nodes_in_group("pixel_spell_fx").size() >= MAX_ACTIVE:
		return null
	var fx := PixelSpellFX.new()
	fx._frames = PixelSpellArt.frames(family)
	fx._family = family
	fx._dramatic = dramatic
	fx._strength = strength
	fx._width = width
	fx._duration = maxf(0.05, duration)
	fx._first = 0 if kind == "cast" else (12 if kind == "aura" and family != "fire" else 4)
	fx._count = 4 if kind == "cast" or (kind == "aura" and family != "fire") else 8
	fx.texture = fx._frames[fx._first]
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.scale = Vector2.ONE * width / PixelSpellArt.LOGICAL_SIZE
	fx.rotation = angle
	fx.z_index = 5
	fx.modulate.a = strength * (0.55 if width > 200 else 0.9)
	fx.material = PixelSpellArt.material()
	# 高频小命中不创建额外灯，避免几十枚火球同时增加光源。
	if width >= 90:
		fx._light = LightUtil.make_point_light(PixelSpellArt.tint(family), 0.6 * strength, width * 0.75 / fx.scale.x, false)
		fx.add_child(fx._light)
	parent.add_child(fx)
	fx.add_to_group("pixel_spell_fx")
	fx.global_position = where
	return fx

func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()
		return
	var progress := clampf(_age / _duration, 0, 0.999)
	texture = _frames[_first + mini(_count - 1, int(progress * _count))]
	var fade := minf(1, (1 - progress) / 0.32)
	modulate.a = _strength * (0.55 if _width > 200 else 0.9) * fade
	if _light != null:
		_light.energy = 0.6 * _strength * fade
	if _dramatic:
		queue_redraw()

func _draw() -> void:
	if not _dramatic:
		return
	var progress := clampf(_age / _duration, 0, 1)
	var tint := PixelSpellArt.tint(_family)
	tint.a = 0.7 * (1 - progress)
	var radius := 18 + 62 * sqrt(progress)
	# 方形像素粒子沿冲击环散开；环中心保持透空。
	for i in 28:
		var angle := TAU * float(i) / 28
		var at := (Vector2.from_angle(angle) * radius).round()
		draw_rect(Rect2(at, Vector2.ONE * (3 if i % 4 == 0 else 2)), tint)
	for i in 12:
		var angle := TAU * float(i) / 12 + 0.15
		var at := (Vector2.from_angle(angle) * (12 + 58 * progress)).round()
		draw_rect(Rect2(at, Vector2(2, 5)), tint.lightened(0.25))
