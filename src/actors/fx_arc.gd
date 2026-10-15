class_name FxArc
extends Node2D
## 挥砍弧光 / 法阵光环：一段发光弧，快速放大并淡出。
## 纯代码绘制（draw_arc），不需要任何美术素材；角度用节点旋转控制。

var radius := 60.0
var arc_deg := 110.0
var color := Color.WHITE
var width := 10.0
var life := 0.22
var grow := 1.25
## 想让弧光跟着某个东西走（比如挥砍时跟着角色）就把它塞进来
var follow: Node2D = null
var follow_offset := Vector2.ZERO

var _t := 0.0


func setup_arc(
	arc_radius: float, arc_degrees: float, tint: Color,
	thickness: float, duration: float, grow_scale := 1.25
) -> FxArc:
	radius = arc_radius
	arc_deg = arc_degrees
	color = tint
	width = thickness
	life = maxf(0.02, duration)
	grow = grow_scale
	return self


func _process(delta: float) -> void:
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position + follow_offset
	_t += delta
	var k := clampf(_t / life, 0.0, 1.0)
	modulate.a = 1.0 - k * k          # 前段亮、后段快速消失
	scale = Vector2.ONE * lerpf(1.0, grow, k)
	if _t >= life:
		queue_free()


func _draw() -> void:
	var half := deg_to_rad(arc_deg) * 0.5
	draw_arc(Vector2.ZERO, radius, -half, half, 26, color, width, true)
	# 内圈再描一道更亮的细弧，弧光看起来有层次
	draw_arc(Vector2.ZERO, radius, -half, half, 26, color.lightened(0.5), width * 0.34, true)
