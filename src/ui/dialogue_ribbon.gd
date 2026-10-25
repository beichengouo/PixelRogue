extends Control
## A lightweight wide visual-novel ribbon. Its fade leaves the scene visible.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var strips := 32
	for i in strips:
		var t := float(i) / strips
		var alpha := smoothstep(0.0, .42, t) * .82
		draw_rect(Rect2(0, size.y * t, size.x, size.y / strips + 1), Color(.045, .075, .13, alpha))
	var line_y := minf(50, size.y * .16)
	draw_line(Vector2(size.x * .05, line_y), Vector2(size.x * .95, line_y), Color(.70, .78, .91, .16), 1)
	for x in [size.x * .035, size.x * .965]:
		var center := Vector2(x, line_y)
		var points := PackedVector2Array([center + Vector2(0,-6), center + Vector2(3,0), center + Vector2(0,6), center + Vector2(-3,0)])
		draw_colored_polygon(points, Color(.91, .79, .57, .48))
