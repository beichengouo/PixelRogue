@tool
class_name CampTerrain
extends StaticBody2D
## Edit the outline in the inspector; art and collision use the same profile.
@export var top_line=PackedVector2Array([Vector2(0,0),Vector2(400,0)]):
	set(value):top_line=value;_rebuild()
@export var depth=500.0:
	set(value):depth=value;_rebuild()
@export var grass=true:
	set(value):grass=value;queue_redraw()
const CAP=preload("res://assets/environment/grass_terrain.png")
var _soil:Texture2D
func _ready() -> void:
	collision_layer=1<<19
	collision_mask=0
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var path="res://assets/camp_refine/soil.png"
	_soil=load(path) if ResourceLoader.exists(path) else load("res://assets/art_phase4/terrain_materials_v1.png")
	_rebuild()
func outline() -> PackedVector2Array:
	var shape=top_line.duplicate()
	if shape.size()<2:return shape
	shape.append(Vector2(top_line[-1].x,depth))
	shape.append(Vector2(top_line[0].x,depth))
	return shape
func height_at(x:float) -> float:
	for i in range(top_line.size()-1):
		var a=top_line[i];var b=top_line[i+1]
		if x>=a.x and x<=b.x:return lerpf(a.y,b.y,inverse_lerp(a.x,b.x,x))
	return INF
func _rebuild() -> void:
	if not is_inside_tree() or top_line.size()<2:return
	var body=get_node_or_null("Collision") as CollisionPolygon2D
	if body==null:body=CollisionPolygon2D.new();body.name="Collision";add_child(body)
	body.polygon=outline()
	queue_redraw()
func _draw() -> void:
	if top_line.size()<2:return
	var shape=outline()
	var uv=PackedVector2Array()
	for p in shape:uv.append(p/256.0)
	if _soil!=null:draw_polygon(shape,PackedColorArray([Color(0.68,0.77,0.75)]),uv,_soil)
	else:draw_colored_polygon(shape,Color("243732"))
	# Follow slopes with textured caps; no exposed rectangular seams between regions.
	if grass:
		for i in range(top_line.size()-1):
			var a=top_line[i];var b=top_line[i+1]
			var length=a.distance_to(b)
			var direction=(b-a).normalized()
			for n in range(ceili(length/36.0)):
				var offset=n*36.0;var width=minf(36,length-offset)
				draw_set_transform(a+direction*offset,direction.angle())
				draw_texture_rect_region(CAP,Rect2(0,-3,width,17),Rect2(36,0,width,17),Color(0.78,0.93,0.83))
		draw_set_transform(Vector2.ZERO)
