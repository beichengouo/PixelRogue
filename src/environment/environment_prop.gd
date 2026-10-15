@tool
class_name EnvironmentProp
extends Sprite2D
## Editable decoration. Transform belongs to the level designer; environment only animates it.
@export_group("环境反馈")
@export var wind_response := false
@export var touch_response := false
@export var weather_response := false
@export_enum("后景（平台之后）","前景（经过时淡化）") var visual_layer := 0:
	set(value):
		visual_layer = value
		z_index = -5 if value==0 else 2
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -5 if visual_layer==0 else 2
