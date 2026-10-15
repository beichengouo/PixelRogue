@tool
class_name GrassPatch
extends Node2D
## An authored patch replaces automatic grass at the same ground line.
@export_group("草地外观")
@export_range(12,720,1) var width := 144.0:
	set(value): width = value; queue_redraw()
@export_range(0,2,0.25) var density := 1.0:
	set(value): density = value; queue_redraw()
@export_range(8,64,1) var blade_height := 24.0:
	set(value): blade_height = value; queue_redraw()
@export_enum("短草", "野草", "芦苇") var style := 0:
	set(value): style = value; queue_redraw()
@export_group("环境反馈")
@export_range(0,2,0.1) var wind_strength := 1.0
@export var touch_response := true
@export var preview_animation := false:
	set(value): preview_animation = value; set_process(value and Engine.is_editor_hint())
var _preview_clock := 0.0
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -1
	set_process(preview_animation and Engine.is_editor_hint())
func tuft_count() -> int:
	return maxi(0,int(width*density/36.0))
func tuft_variant(index: int) -> int:
	return index%4 if style==0 else 4+index%2 if style==1 else 6+index%2
func _process(delta: float) -> void:
	_preview_clock += delta
	queue_redraw()
func _draw() -> void:
	if not Engine.is_editor_hint(): return
	for i in tuft_count():
		var x := width*(i+0.5)/tuft_count()
		EnvironmentSprites.draw_grass(self,Vector2(x,0),blade_height,sin(_preview_clock+i*1.7)*0.08*wind_strength,tuft_variant(i))
