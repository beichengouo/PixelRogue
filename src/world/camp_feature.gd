@tool
class_name CampFeature
extends Node2D
@export_enum("bridge","terrace","stair") var art="bridge":
	set(value):art=value;_texture=null;queue_redraw()
@export var size=Vector2(540,180):
	set(value):size=value;queue_redraw()
@export var deck_offset=40.0:
	set(value):deck_offset=value;queue_redraw()
var _texture:Texture2D
@export var mirrored=false:
	set(value):mirrored=value;queue_redraw()
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	_texture=CampArt.texture(art)
	queue_redraw()
func _draw() -> void:
	if _texture==null:_texture=CampArt.texture(art)
	if _texture!=null:
		if mirrored:draw_set_transform(Vector2(size.x,0),0,Vector2(-1,1))
		draw_texture_rect(_texture,Rect2(0,-deck_offset,size.x,size.y),false)
		draw_set_transform(Vector2.ZERO)
