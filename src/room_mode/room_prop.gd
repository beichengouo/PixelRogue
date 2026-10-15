@tool
class_name RoomProp
extends StaticBody2D
@export_enum("crate", "stone") var prop_kind := "crate"
var cell := Vector2i.ZERO
var hp := 30.0
var room: RoomLevel
var art: Sprite2D
var asset_id:=""
var scene_object_id:=""
var scene_texture:Texture2D
var scene_width:=36.0
var collision_polygon:=PackedVector2Array()
@export var model:=""
@export var footprint:=Vector2i.ONE

func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	if not scene_object_id.is_empty():
		if collision_polygon.size()>=3:
			var collider:=CollisionPolygon2D.new();collider.polygon=collision_polygon;add_child(collider)
	else:
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new(); shape.size = Vector2(footprint)*36-Vector2.ONE*2
		collider.shape = shape; add_child(collider)
	art = Sprite2D.new(); art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := "res://assets/room_mode/refinement/"+prop_kind+".png"
	var variant:="res://assets/room_mode/terrain_v3/editor/%s_%dx%d.png"%[model,footprint.x,footprint.y]
	if not model.is_empty() and ResourceLoader.exists(variant):path=variant
	if scene_texture!=null:art.texture=scene_texture
	elif asset_id.begins_with("scene:"):art.texture=RoomEditorCatalog.texture(asset_id)
	elif asset_id.begins_with("supplied:"):art.texture=SuppliedMapAssets.texture(asset_id)
	elif ResourceLoader.exists(path): art.texture = load(path)
	else: art.texture = load("res://assets/environment/rocks.png")
	if art.texture != null: art.scale = Vector2.ONE*(footprint.x*36.0)/maxf(1,art.texture.get_width())
	if asset_id.begins_with("scene:") and art.texture!=null:
		art.scale=Vector2.ONE*float(RoomEditorCatalog.get_entry(asset_id).get("render_width_px",footprint.x*36))/art.texture.get_width()
	art.position.y = footprint.y*18.0-art.texture.get_height()*art.scale.y*.5
	if not scene_object_id.is_empty() and art.texture!=null:
		art.scale=Vector2.ONE*scene_width/art.texture.get_width();art.position.y=-art.texture.get_height()*art.scale.y*.5
	add_child(art)
	add_to_group("room_props")

func take_damage(amount: float, _crit := false, _from := Vector2.ZERO, _source: Node = null) -> void:
	if prop_kind != "crate" or hp <= 0: return
	hp -= amount
	if is_instance_valid(room):
		if not room.record.delta.has("prop_hp"):room.record.delta.prop_hp={}
		if not scene_object_id.is_empty():
			if not room.record.delta.has("scene_prop_hp"):room.record.delta.scene_prop_hp={}
			room.record.delta.scene_prop_hp[scene_object_id]=maxf(0,hp)
		else:room.record.delta.prop_hp[RoomGraph.key(cell)]=maxf(0,hp)
	Effects.hit_spark(get_parent(),global_position,Color("c79a65"),5)
	if hp <= 0:
		if is_instance_valid(room):
			if scene_object_id.is_empty():room.break_prop(cell)
			else:room.break_scene_prop(scene_object_id)
		collision_layer = 0; hide(); queue_free()
	else:
		art.modulate=Color("ffd8a3")
		var tween=create_tween();tween.tween_property(art,"modulate",Color.WHITE,0.12)
