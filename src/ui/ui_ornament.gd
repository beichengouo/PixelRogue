class_name UiOrnament
extends Control
## 界面小装饰：菱形 / 箭头 / 角标。
## 全部用 draw_* 画出来，不需要任何美术素材，想换颜色改一个参数就行。

enum Shape { DIAMOND, CHEVRON, CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT }

var shape: Shape = Shape.DIAMOND
var color := Palette.GOLD
var thickness := 2.0


func setup(target: Shape, tint: Color, box := 12.0, line := 2.0) -> UiOrnament:
	shape = target
	color = tint
	thickness = line
	custom_minimum_size = Vector2(box, box)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	return self


func _draw() -> void:
	var w := size.x
	var h := size.y
	match shape:
		Shape.DIAMOND:
			var mid := Vector2(w * 0.5, h * 0.5)
			var pts := PackedVector2Array([
				Vector2(mid.x, 0.0), Vector2(w, mid.y), Vector2(mid.x, h), Vector2(0.0, mid.y),
			])
			draw_colored_polygon(pts, color)
			# 中心再点一颗亮色，看着像宝石
			draw_colored_polygon(PackedVector2Array([
				Vector2(mid.x, h * 0.22), Vector2(w * 0.78, mid.y),
				Vector2(mid.x, h * 0.78), Vector2(w * 0.22, mid.y),
			]), color.lightened(0.45))
		Shape.CHEVRON:
			draw_line(Vector2(w * 0.28, h * 0.18), Vector2(w * 0.74, h * 0.5), color, thickness, true)
			draw_line(Vector2(w * 0.74, h * 0.5), Vector2(w * 0.28, h * 0.82), color, thickness, true)
		_:
			var sx := 0.0 if shape in [Shape.CORNER_TOP_LEFT, Shape.CORNER_BOTTOM_LEFT] else w
			var sy := 0.0 if shape in [Shape.CORNER_TOP_LEFT, Shape.CORNER_TOP_RIGHT] else h
			var dx := 1.0 if sx == 0.0 else -1.0
			var dy := 1.0 if sy == 0.0 else -1.0
			var arm := Vector2(w * 0.78, h * 0.78)
			draw_line(Vector2(sx, sy), Vector2(sx + arm.x * dx, sy), color, thickness, true)
			draw_line(Vector2(sx, sy), Vector2(sx, sy + arm.y * dy), color, thickness, true)
