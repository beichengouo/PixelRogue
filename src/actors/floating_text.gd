class_name FloatingText
extends Node2D
## 飘字：伤害数字、拾取提示、系统提示都用它。

var velocity := Vector2(0.0, -78.0)
var life := 0.9
var max_life := 0.9

var _label: Label

func _ready()->void:
	# Every world-space notice, including levels and pickups, sits above scenery.
	z_as_relative=false
	z_index=RenderingServer.CANVAS_ITEM_Z_MAX


func setup(text: String, color: Color, font_size: int, drift := Vector2(0.0, -78.0)) -> FloatingText:
	velocity = drift
	_label = Label.new()
	_label.text = text
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(180.0, 36.0)
	_label.position = Vector2(-90.0, -18.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	return self


func _process(delta: float) -> void:
	life -= delta
	position += velocity * delta
	velocity.y += 170.0 * delta
	modulate.a = clampf(life / max_life * 1.8, 0.0, 1.0)
	scale = Vector2.ONE * clampf(1.0 + (max_life - life) * 0.25, 1.0, 1.3)
	if life <= 0.0:
		queue_free()

