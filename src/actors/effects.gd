class_name Effects
extends RefCounted
## 特效工厂：粒子、飘字。
## 粒子与原创像素动画统一从此创建。

## 特效用的独立随机源：刻意和玩法随机分开，
## 这样改特效不会影响「同一个种子跑出同一局」的复现性。
static var _rng := RandomNumberGenerator.new()

static func damage_number(parent: Node, where: Vector2, amount: float, crit := false, color := Color.WHITE) -> void:
	var text := str(int(round(amount)))
	if crit:
		text += "!"
	var node := FloatingText.new()
	node.setup(text, color, 26 if crit else 21, Vector2(_rng.randf() * 40.0 - 20.0, -92.0))
	_attach(parent, node, where)


static func text(parent: Node, where: Vector2, content: String, color := Color.WHITE, font_size := 20) -> void:
	var node := FloatingText.new()
	node.setup(content, color, font_size)
	node.life = 1.1
	node.max_life = 1.1
	_attach(parent, node, where)


static func hit_spark(parent: Node, where: Vector2, color: Color, count := 6) -> void:
	_burst(parent, where, color, count, 60.0, 200.0, 0.28, 2.0, 4.0)


static func death_burst(parent: Node, where: Vector2, color: Color, count := 14) -> void:
	_burst(parent, where, color, count, 90.0, 300.0, 0.5, 3.0, 6.0)


static func dust(parent: Node, where: Vector2, color: Color, count := 5) -> void:
	_burst(parent, where, color, count, 20.0, 90.0, 0.35, 2.0, 4.0)


static func spawn_marker(parent: Node, where: Vector2, color: Color) -> void:
	_burst(parent, where, color, 12, 40.0, 150.0, 0.45, 2.0, 5.0)


static func slash_arc(
	parent: Node, where: Vector2, angle: float, radius: float, color: Color,
	arc_deg := 120.0, width := 10.0, life := 0.22
) -> void:
	## 近战使用原创像素斩击；圆形震波保留完整范围轮廓。
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	if arc_deg<300.0 and ResourceLoader.exists(PixelMeleeFX.SOURCE):
		var pixel:=PixelMeleeFX.new()
		pixel.setup(radius,color,life)
		_attach(parent,pixel,where)
		pixel.rotation=angle
		return
	var fx := FxArc.new()
	fx.setup_arc(radius, arc_deg, color, width, life, 1.22)
	_attach(parent, fx, where)
	fx.rotation = angle


static func cast_ring(parent: Node, where: Vector2, color: Color, radius := 20.0, life := 0.30) -> void:
	## 施法光环：一整圈光，向外扩散淡出
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var fx := FxArc.new()
	fx.setup_arc(radius, 360.0, color, 3.0, life, 2.0)
	_attach(parent, fx, where)


static func muzzle_flash(parent: Node, where: Vector2, dir: Vector2, color: Color, length := 26.0) -> void:
	## 枪口闪光：一条短亮线 + 几点火星
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var line := Line2D.new()
	line.add_point(Vector2.ZERO)
	line.add_point(dir.normalized() * length)
	line.width = 4.0
	line.default_color = color
	line.z_index = 2
	_attach(parent, line, where)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.09)
	tween.tween_callback(line.queue_free)
	hit_spark(parent, where, color, 3)


static func trail_dot(parent: Node, where: Vector2, color: Color, size := 3.0) -> void:
	## 弹道拖尾：一颗不带重力的小亮点，很快消失
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var dot := CPUParticles2D.new()
	dot.emitting = false
	dot.one_shot = true
	dot.amount = 1
	dot.lifetime = 0.20
	dot.explosiveness = 1.0
	dot.local_coords = false
	dot.direction = Vector2.ZERO
	dot.spread = 180.0
	dot.initial_velocity_min = 0.0
	dot.initial_velocity_max = 12.0
	dot.gravity = Vector2.ZERO
	dot.scale_amount_min = size
	dot.scale_amount_max = size * 1.6
	dot.color = color
	_attach(parent, dot, where)
	dot.emitting = true


static func _burst(
	parent: Node,
	where: Vector2,
	color: Color,
	count: int,
	speed_min: float,
	speed_max: float,
	lifetime: float,
	scale_min: float,
	scale_max: float
) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = lifetime
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max
	particles.gravity = Vector2(0.0, 900.0)
	particles.scale_amount_min = scale_min
	particles.scale_amount_max = scale_max
	particles.color = color
	parent.add_child(particles)
	particles.global_position = where
	particles.emitting = true
	# one_shot 的粒子放完会发 finished，节点自己回收即可
	particles.finished.connect(particles.queue_free)


static func _attach(parent: Node, node: Node2D, where: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	parent.add_child(node)
	node.global_position = where
