@tool
class_name CampStream
## Reusable animated editor water, independent of obsolete camp gameplay.
extends Node2D
@export var size=Vector2(360,28):
	set(value):size=Vector2(maxf(36,value.x),maxf(4,value.y));queue_redraw()
@export var flow_speed=6.0
@export var color_tint=Color.WHITE:
	set(value):color_tint=value;queue_redraw()
@export var preview_animation=true:
	set(value):preview_animation=value;set_process(value if Engine.is_editor_hint() else true)
var _age=0.0
var _waves=PackedFloat32Array()
var _speeds=PackedFloat32Array()
func _ready() -> void:
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_waves.resize(25);_speeds.resize(25)
	set_process(preview_animation if Engine.is_editor_hint() else true)
func _process(delta:float) -> void:
	var reduced=false if Engine.is_editor_hint() else SaveService.data.get("reduced_motion",false)
	_age+=delta*(0.25 if reduced else 1.0)
	var old=_waves.duplicate()
	for i in _waves.size():
		var neighbors=(old[maxi(0,i-1)]+old[mini(24,i+1)])*0.5
		_speeds[i]+=(-old[i]*25+(neighbors-old[i])*100-_speeds[i]*5)*minf(delta,0.05)
		_waves[i]=clampf(_waves[i]+_speeds[i]*minf(delta,0.05),-4,4)
	queue_redraw()
func _draw() -> void:
	EnvironmentSprites.draw_water(self,Rect2(Vector2.ZERO,size),_waves,_age,flow_speed,color_tint)
