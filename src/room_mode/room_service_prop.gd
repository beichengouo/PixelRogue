@tool
class_name RoomServiceProp
extends StaticBody2D
## A ground footprint, shared by actual collision and the room navigation grid.
var art:Sprite2D
var footprint:=Rect2()
var asset_name:=""
var collision_polygon:=PackedVector2Array()
func setup(asset:String,at:Vector2,width:float,depth:float,texture_override:Texture2D=null,polygon_override:PackedVector2Array=PackedVector2Array(),collision_disabled:bool=false)->void:
	asset_name=asset;position=at
	var path:="res://assets/room_mode/structure/"+asset+".png"
	if not ResourceLoader.exists(path):path="res://assets/room_mode/services/"+asset+".png"
	var texture:=texture_override if texture_override!=null else load(path) as Texture2D
	art=Sprite2D.new();art.texture=texture;art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	art.scale=Vector2.ONE*width/texture.get_width();art.offset=Vector2(0,-texture.get_height()*0.5)
	add_child(art)
	collision_polygon=polygon_override
	if collision_polygon.size()>=3:
		footprint=Rect2(collision_polygon[0],Vector2.ZERO)
		for point in collision_polygon:footprint=footprint.expand(point)
		footprint.position+=at
		var collider:=CollisionPolygon2D.new();collider.polygon=collision_polygon;add_child(collider)
	elif collision_disabled:
		footprint=Rect2(at,Vector2.ZERO)
	else:
		var span:=width*0.78
		footprint=Rect2(at-Vector2(span*0.5,depth),Vector2(span,depth))
		var shape:=RectangleShape2D.new();shape.size=footprint.size
		var collider:=CollisionShape2D.new();collider.shape=shape;collider.position=Vector2(0,-depth*0.5)
		add_child(collider)
	collision_layer=Layers.WORLD;collision_mask=0
