extends PlayerStatBar
## Separate XP art keeps the established HP and MP frames untouched.

func configure(_type: String) -> void:
	kind = "xp"
	_frame = preload("res://assets/ui_art/top_hud/xp_frame_v02.png")
	_liquid = preload("res://assets/ui_art/top_hud/xp_fill_v02.png")

func _draw() -> void:
	if _frame == null or _liquid == null:
		return
	draw_texture_rect(_frame, Rect2(Vector2.ZERO, size), false)
	var inset := Vector2(size.x * 0.085, size.y * 0.28)
	var inner := Rect2(inset, Vector2(maxf(0.0, size.x - inset.x * 2), maxf(0.0, size.y - inset.y * 2)))
	var shown := clampf(_shown / _max_value, 0.0, 1.0)
	var ghost := clampf(_ghost / _max_value, 0.0, 1.0)
	if ghost > shown:
		draw_texture_rect(_liquid, Rect2(inner.position, Vector2(inner.size.x * ghost, inner.size.y)), false, Color(1, 0.9, 0.7, 0.28))
	if shown <= 0.0:
		return
	var target := Rect2(inner.position, Vector2(inner.size.x * shown, inner.size.y))
	draw_texture_rect_region(_liquid, target, Rect2(0, 0, _liquid.get_width() * shown, _liquid.get_height()))
	if _gain_time > 0:
		var start := clampf(_delta_from, 0.0, shown)
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * start, 0), Vector2(inner.size.x * (shown - start), inner.size.y)), Color(1, 1, 0.85, 0.28 * minf(1.0, _gain_time / 0.25)))
	if not ComicMotion.reduced() and (_gain_time > 0 or _loss_time > 0):
		var edge := inner.position + Vector2(inner.size.x * shown, 0)
		draw_line(edge, edge + Vector2(0, inner.size.y), Color(1, 1, 1, 0.7), 1)
