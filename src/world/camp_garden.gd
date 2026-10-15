@tool
class_name CampGarden
## Reusable editor decoration; no map-camp movement or actor dependencies.
extends Node2D
@export_range(28,1440,1) var width=180.0:
	set(value):width=maxf(28,value);_resize();queue_redraw()
@export_range(8,96,1) var height=26.0:
	set(value):height=value;queue_redraw()
@export_enum("野草","芦苇") var style=0:
	set(value):style=value;queue_redraw()
var _age=0.0
var _angles=PackedFloat32Array()
var _speeds=PackedFloat32Array()
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_resize()
	set_process(not Engine.is_editor_hint())
func _resize() -> void:
	_angles.resize(maxi(1,int(width/28)))
	_speeds.resize(_angles.size())
func _process(delta:float) -> void:
	var reduced=SaveService.data.get("reduced_motion",false)
	_age+=delta
	for i in _angles.size():
		var x=width*(i+0.5)/_angles.size()
		var target=sin(_age*1.4+i*1.8+position.x)*0.08
		if reduced:target*=0.2
		_speeds[i]+=((target-_angles[i])*45-_speeds[i]*10)*minf(delta,0.05)
		_angles[i]+= _speeds[i]*minf(delta,0.05)
	queue_redraw()
func _draw() -> void:
	var count=maxi(1,int(width/28))
	for i in count:
		var angle=_angles[i] if i<_angles.size() else 0.0
		EnvironmentSprites.draw_grass(self,Vector2(width*(i+0.5)/count,0),height,angle,4+i%2 if style==0 else 6+i%2)
