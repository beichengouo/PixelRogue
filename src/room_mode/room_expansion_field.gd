class_name RoomExpansionField
extends Node2D
var controller:RoomExpansionController
var field:Dictionary={}
var _segments:Array[int]=[]
func _ready()->void:
	z_index=4;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var at:=Vector2(field.at[0],field.at[1]);var direction:=Vector2(float(field.direction[0]),float(field.direction[1])).normalized()
	for index in 18:
		var point:=at+direction*(index*8-72+4);var side:=direction.orthogonal()*18
		if controller._field_legal(field,point) and controller._field_legal(field,point+side) and controller._field_legal(field,point-side):_segments.append(index)
func _draw()->void:
	if field.is_empty() or not is_instance_valid(controller) or controller.state.is_empty():return
	var at:=Vector2(field.at[0],field.at[1]);var warning:=float(field.age)<0
	var color:=Color("bc8bff") if field.mode=="rune" else (Color("ff7761") if field.mode=="bone" else Color("bc74b9"))
	var reduced:=ComicMotion.reduced()
	var frame:=1 if reduced else clampi(int(maxf(0,float(field.age))*12),0,3)
	var atlas:=RoomExpansionRules.field_texture(str(field.mode))
	var direction:=Vector2(float(field.direction[0]),float(field.direction[1])).normalized()
	draw_set_transform(at,direction.angle())
	for index in _segments:
		var point:=Vector2(index*8-72+4,0)
		var rect:=Rect2(point-Vector2(4,18),Vector2(8,36))
		if warning:
			draw_rect(rect,Color(color,.18 if reduced else .10+.10*sin((field.age+1)*16)))
			draw_line(rect.position,rect.position+Vector2(8,0),color,2);draw_line(rect.end-Vector2(8,0),rect.end,color,2)
		elif atlas!=null:
			var cell:=Vector2(atlas.get_width()/4.0,atlas.get_height());var source:=Rect2(Vector2(frame*cell.x+index*cell.x/18,0),Vector2(cell.x/18,cell.y))
			draw_texture_rect_region(atlas,rect,source)
