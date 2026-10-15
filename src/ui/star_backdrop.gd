extends Control
## 立绘后的静态星轨。装饰不接收输入，不遮盖人物。
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := Vector2(138, 266)
	draw_circle(center, 125.0, Color(0.18, 0.24, 0.38, 0.18))
	draw_arc(center, 126.0, -1.3, 2.7, 72, Color(0.70, 0.60, 0.40, 0.40), 1.0, true)
	draw_arc(center, 143.0, 1.1, 4.6, 72, Color(0.56, 0.65, 0.85, 0.18), 1.0, true)
	for point in [Vector2(40, 154), Vector2(240, 354), Vector2(254, 176)]:
		var points := PackedVector2Array([point + Vector2(0, -6), point + Vector2(2, 0),
			point + Vector2(0, 6), point + Vector2(-2, 0)])
		draw_colored_polygon(points, Color(0.89, 0.78, 0.53, 0.6))
	draw_line(Vector2(78, 628), Vector2(198, 628), Color(0.70, 0.60, 0.40, 0.35), 1.0)
