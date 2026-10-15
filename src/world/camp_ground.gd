@tool
class_name CampGround
extends StaticBody2D
@export var extent=Vector2(300,140):
	set(value):extent=value;_rebuild()
@export_enum("stone","wood","grass") var surface="stone":
	set(value):surface=value;queue_redraw()
@export var paint=true:
	set(value):paint=value;queue_redraw()
@export var one_way=false:
	set(value):one_way=value;_rebuild()
const TEXTURES={"grass":preload("res://assets/environment/grass_terrain.png"),"wood":preload("res://assets/environment/wood_terrain.png"),"stone":preload("res://assets/environment/stone_terrain.png")}
var _material:Texture2D
func _ready() -> void:
	collision_layer=1<<18 if one_way else 1<<19
	collision_mask=0
	_rebuild()
	_material=load("res://assets/art_phase4/terrain_materials_v1.png")
func _rebuild() -> void:
	if not is_inside_tree():return
	collision_layer=1<<18 if one_way else 1<<19
	collision_mask=0
	var body=get_node_or_null("Collision") as CollisionShape2D
	if body==null:body=CollisionShape2D.new();body.name="Collision";add_child(body)
	var shape=RectangleShape2D.new()
	shape.size=extent
	body.shape=shape
	body.position=extent*0.5
	body.one_way_collision=one_way
	queue_redraw()
func _draw() -> void:
	if not paint:return
	var texture:Texture2D=TEXTURES.get(surface,TEXTURES.stone)
	if surface!="wood":draw_rect(Rect2(Vector2.ZERO,extent),Color("263937"))
	if surface!="wood" and _material!=null:
		var half=_material.get_size()*0.5
		var source=Rect2(Vector2(0,half.y) if surface=="grass" else half,half)
		var tile=256 if surface=="grass" else 144
		for x in range(0,int(extent.x),tile):
			for y in range(0,int(extent.y),tile):
				var size=Vector2(minf(tile,extent.x-x),minf(tile,extent.y-y))
				var region=Rect2(source.position,source.size*size/float(tile))
				draw_texture_rect_region(_material,Rect2(Vector2(x,y),size),region,Color(0.57,0.68,0.67))
		if surface=="grass" and texture!=null:
			for x in range(0,int(extent.x),36):draw_texture_rect_region(texture,Rect2(x,0,minf(36,extent.x-x),14),Rect2(36,0,minf(36,extent.x-x),14))
		return
	if texture!=null:
		for x in range(0,int(extent.x),36):
			for y in range(0,int(extent.y),36):
				var size=Vector2(minf(36,extent.x-x),minf(36,extent.y-y))
				var source=Vector2(36,0) if surface=="wood" else (Vector2(144+(x/36%3)*36,108) if y>0 and surface=="grass" else Vector2(36,0))
				draw_texture_rect_region(texture,Rect2(Vector2(x,y),size),Rect2(source,size))
	if surface!="wood":draw_line(Vector2.ZERO,Vector2(extent.x,0),Color("a4bb91") if surface=="grass" else Color("8d9990"),2)
