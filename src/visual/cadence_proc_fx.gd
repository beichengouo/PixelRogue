class_name CadenceProcFX
extends Node2D
## Small procedural feedback shares no additive lighting and respects reduced FX.
var age:=0.0
var radius:=36.0
var tint:=Color.WHITE
var style:=0
static func spawn(parent:Node,at:Vector2,size_value:float,color:Color,shape:int)->void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():return
	if parent.get_tree().get_nodes_in_group("cadence_proc_fx").size()>=24:return
	var fx:=CadenceProcFX.new();fx.radius=size_value;fx.tint=color;fx.style=shape;fx.z_index=7
	parent.add_child(fx);fx.global_position=at;fx.add_to_group("cadence_proc_fx")
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;fx.material=ink
func _process(delta:float)->void:
	age+=delta
	if age>=.38:queue_free();return
	queue_redraw()
func _draw()->void:
	var p:=clampf(age/.38,0,1);var color:=tint;color.a=(1-p)*clampf(float(SaveService.data.get("spell_fx_strength",1)),0,1)
	var r:=radius*(.35+.65*p)
	draw_arc(Vector2.ZERO,r,0,TAU,32,color,2)
	if ComicMotion.reduced():return
	if style==0:
		for i in 4:
			var direction:=Vector2.RIGHT.rotated(i*TAU/4)
			draw_polyline(PackedVector2Array([direction*r*.25,direction.rotated(.18)*r*.48,direction.rotated(-.12)*r*.68,direction*r]),color,2)
	elif style==3:
		var points:=PackedVector2Array()
		for i in 7:points.append(Vector2.RIGHT.rotated(i*TAU/6+p)*r*.75)
		draw_polyline(points,color,2)
	else:draw_arc(Vector2.ZERO,r*.65,p,TAU+p,24,color,2)
