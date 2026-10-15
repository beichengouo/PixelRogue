class_name RoomDropMark
extends Node2D
var age:=0.0
func _ready()->void:
	z_index=3;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func _process(dt:float)->void:
	if TransitionLayer.busy or UIFlow.has_screen():return
	age+=dt;queue_redraw()
func _draw()->void:
	var atlas:=RoomExpansionRules.field_texture("amber")
	if atlas==null:return
	var cell:=Vector2(atlas.get_width()/4.0,atlas.get_height());var frame:=1 if ComicMotion.reduced() else int(age*8)%4
	draw_texture_rect_region(atlas,Rect2(-36,-18,72,36),Rect2(Vector2(frame*cell.x,0),cell),Color(1,1,1,.65))
