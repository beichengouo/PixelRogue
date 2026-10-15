@tool
class_name SpawnPoint
extends Marker2D
## 地图上的坐标标记：在 Godot 编辑器里画成一个带文字的方框，一眼能看到、随手能拖。
##
## 为什么不用普通的 Marker2D：它默认只画一个 10 像素的小十字，
## 在缩放到整个关卡之后几乎是个看不见的点，很难选中（这就是「拖不动」的真实原因）。
##
## 运行时不会画出任何东西，只用来提供坐标，所以不影响游戏画面。

@export var label_text: String = "标记":
	set(value):
		label_text = value
		queue_redraw()

@export var marker_color: Color = Color(1.0, 0.85, 0.2):
	set(value):
		marker_color = value
		queue_redraw()

@export var marker_size: float = 32.0:
	set(value):
		marker_size = value
		queue_redraw()

@export var editor_preview_texture: Texture2D:
	set(value):
		editor_preview_texture = value
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# 只在编辑器里画，运行时保持干净
	if not Engine.is_editor_hint():
		return
	if editor_preview_texture != null:
		var extent := editor_preview_texture.get_size()
		draw_texture(editor_preview_texture,Vector2(-extent.x*0.5,21-extent.y))

	var half := marker_size * 0.5
	draw_rect(Rect2(-half, -half, marker_size, marker_size), marker_color, false, 2.0)
	draw_line(Vector2(-half - 12.0, 0.0), Vector2(half + 12.0, 0.0), marker_color, 2.0)
	draw_line(Vector2(0.0, -half - 12.0), Vector2(0.0, half + 12.0), marker_color, 2.0)
	draw_circle(Vector2.ZERO, 3.0, marker_color)

	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(
			font,
			Vector2(-half, -half - 10.0),
			label_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			16,
			marker_color
		)
