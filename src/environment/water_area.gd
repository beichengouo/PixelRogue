@tool
class_name WaterArea
extends Node2D
@export var size := Vector2(180,12):
	set(value):
		size = Vector2(maxf(1,value.x),maxf(1,value.y))
		queue_redraw()
@export_group("水体表现")
@export_range(-24,24,0.5) var flow_speed := 6.0
@export_range(0,2,0.1) var ripple_strength := 1.0
@export var color_tint := Color.WHITE:
	set(value): color_tint = value; queue_redraw()
@export var preview_animation := true:
	set(value): preview_animation = value; set_process(value and Engine.is_editor_hint())
var _preview_clock := 0.0
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -1
	set_process(preview_animation and Engine.is_editor_hint())
func _process(delta: float) -> void:
	_preview_clock += delta
	queue_redraw()
func _draw() -> void:
	if not Engine.is_editor_hint(): return
	EnvironmentSprites.draw_water(self,Rect2(Vector2.ZERO,size),PackedFloat32Array(),_preview_clock,flow_speed,color_tint)
