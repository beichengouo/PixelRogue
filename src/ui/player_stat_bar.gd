class_name PlayerStatBar
extends StatBar

## FreeButtons supplies the stepped pixel frame and light/dark fill pixels.
## HP / MP retain their semantic colours and the existing value interpolation.
var kind := "hp"
var _frame: Texture2D
var _liquid: Texture2D
var _frame_style: StyleBoxTexture
var _gain_time := 0.0
var _loss_time := 0.0
var _delta_from := 0.0
var _amount_label:Label
var capacity_loss:=0.0
func set_capacity_loss(amount:float)->void:
	var value:=maxf(0,amount) if kind=="hp" else 0.0
	if not is_equal_approx(value,capacity_loss):capacity_loss=value;queue_redraw()

func configure(type: String) -> void:
	kind = type
	_frame_style = preload("res://assets/quality_20261011/ui/bar_frame.tres").duplicate()
	_liquid = preload("res://assets/quality_20261011/ui/bar_fill.tres")
	if _amount_label==null:
		_amount_label=Label.new();_amount_label.name="Value";_amount_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_amount_label)
		_amount_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_amount_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_amount_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		_amount_label.add_theme_font_size_override("font_size",13);_amount_label.add_theme_color_override("font_color",Color.WHITE);_amount_label.add_theme_color_override("font_outline_color",Color("141b2b"));_amount_label.add_theme_constant_override("outline_size",3)
	_update_amount()
	queue_redraw()

func set_max_value(amount:float)->void:
	super.set_max_value(amount);_update_amount()
func _update_amount()->void:
	if _amount_label!=null:_amount_label.text="%d / %d"%[roundi(_value),roundi(_max_value)]

func set_value(amount: float, instant := false) -> void:
	if _started and not instant and not is_equal_approx(_value, amount):
		_delta_from = _value / maxf(1.0, _max_value+capacity_loss)
		if amount > _value:
			_gain_time = 0.12 if ComicMotion.reduced() else 0.4
		else:
			_loss_time = 0.12 if ComicMotion.reduced() else 0.45
	super.set_value(amount, instant)
	_update_amount()

func level_up() -> void:
	_ghost = _value
	_shown = _value
	_gain_time = 0.12 if ComicMotion.reduced() else 0.45

func _process(delta: float) -> void:
	super._process(delta)
	if _gain_time > 0.0 or _loss_time > 0.0:
		_gain_time = maxf(0.0, _gain_time - delta)
		_loss_time = maxf(0.0, _loss_time - delta)
		queue_redraw()

func _draw() -> void:
	if _frame_style == null or _liquid == null:
		return
	var outer := Rect2(Vector2.ZERO, size)
	var ratio := _value / maxf(0.0001, _max_value)
	var low_hp := kind == "hp" and ratio <= 0.32
	_frame_style.modulate_color = Color(2.4, 1.2, 1.3) if low_hp else Color(1.5, 1.7, 2.0)
	draw_style_box(_frame_style, outer)
	# Constant pixel margins keep the endcaps intact at each HUD bar width.
	var inset := Vector2(4.0, 3.0)
	var inner := Rect2(inset, Vector2(maxf(0.0, size.x - 8.0), maxf(0.0, size.y - 6.0)))
	var full:=maxf(.0001,_max_value+capacity_loss);var usable:=clampf(_max_value/full,0,1)
	var shown := clampf(_shown / full, 0.0, usable)
	var ghost := clampf(_ghost / full, 0.0, usable)
	if capacity_loss>0:
		draw_rect(Rect2(inner.position+Vector2(inner.size.x*usable,0),Vector2(inner.size.x*(1-usable),inner.size.y)),Color("737987"))
		draw_line(inner.position+Vector2(inner.size.x*usable,0),inner.position+Vector2(inner.size.x*usable,inner.size.y),Color("b9bdc6"),1)
	if ghost > shown:
		draw_texture_rect(_liquid, Rect2(inner.position, Vector2(inner.size.x * ghost, inner.size.y)), false, Color(2.0, 1.6, 1.44, 0.28))
	if shown <= 0.0:
		return
	var target := Rect2(inner.position, Vector2(inner.size.x * shown, inner.size.y))
	var tint := Color(fill_color.r * 2.05, fill_color.g * 2.05, fill_color.b * 2.05)
	draw_texture_rect_region(_liquid, target, Rect2(0.0, 0.0, _liquid.get_width() * shown, _liquid.get_height()), tint)
	if _gain_time > 0.0:
		var start := clampf(_delta_from, 0.0, shown)
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * start, 0.0), Vector2(inner.size.x * (shown - start), inner.size.y)), Color(1.0, 1.0, 0.85, 0.28 * minf(1.0, _gain_time / 0.25)))
	if not ComicMotion.reduced() and (_gain_time > 0.0 or _loss_time > 0.0):
		var edge := inner.position + Vector2(inner.size.x * shown, 0.0)
		draw_line(edge, edge + Vector2(0.0, inner.size.y), Color(1.0, 1.0, 1.0, 0.7), 1.0)
