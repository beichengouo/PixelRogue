@tool
class_name RoomSceneArtwork
extends Node2D
var room:RoomLevel
var data:Dictionary={}
var gates:Dictionary={}
var ground_planes:Array[Sprite2D]=[]
var background_plane:Sprite2D
func active()->bool:return not data.is_empty()
func camera_bounds()->Rect2:
	# Use the actual rendered background texture, independent of editable
	# collision bounds, gates and foreground decoration.
	if is_instance_valid(background_plane):
		return background_plane.global_transform*background_plane.get_rect()
	return global_transform*frame_rect()
func visual_room_rect()->Rect2:
	var layout:Dictionary=room.record.get("terrain_layout",{})
	var box:Array=layout.get("visual_room_rect",layout.get("room_rect",[]))
	if box.size()==4:return Rect2(float(box[0]),float(box[1]),float(box[2]),float(box[3]))
	return room.room_rect
func frame_rect()->Rect2:
	var floor:Array=data.floor_rect_px
	var scale_value:=visual_room_rect().size/Vector2(float(floor[2]),float(floor[3]))
	return Rect2(visual_room_rect().position-Vector2(float(floor[0]),float(floor[1]))*scale_value,Vector2(float(data.canvas[0]),float(data.canvas[1]))*scale_value)
static func gate_offset(side:String,ports:Array,origin:=Vector2(11,5))->Vector2:
	# Illustrated source gates are authored for the common 23x13 template ports.
	# Slide only along the wall; the canvas, size, and collision bounds stay fixed.
	for port in ports:
		if str(port.get("side",""))!=side:continue
		var at:Array=port.get("at",[])
		if at.size()!=2:return Vector2.ZERO
		if side in ["north","south"]:return Vector2((float(at[0])-origin.x)*36.0,0.0)
		if side in ["east","west"]:return Vector2(0.0,(float(at[1])-origin.y)*36.0)
	return Vector2.ZERO
func configure(id:String)->void:
	for child in get_children():remove_child(child);child.queue_free()
	gates.clear();ground_planes.clear();background_plane=null;data=RoomSceneArtCatalog.definition(id)
	if not active():return
	var root:=RoomSceneArtCatalog.ROOT+id+"/"
	var frame:=frame_rect()
	for plane in data.get("planes",[]):
		var sprite:=_sprite(root+str(plane.path),frame)
		if str(plane.path).ends_with("background.png"):background_plane=sprite
		if str(plane.path)!="water.png":ground_planes.append(sprite)
	var floor:Array=data.floor_rect_px
	var scale_value:=visual_room_rect().size/Vector2(float(floor[2]),float(floor[3]))
	for side in data.get("gates",{}):
		var gate:Dictionary=data.gates[side];var box:Array=gate.rect_px
		var rect:=Rect2(frame.position+Vector2(float(box[0]),float(box[1]))*scale_value+gate_offset(side,room.record.get("terrain_layout",{}).get("ports",[]),Vector2(float(data.get("gate_origin",[11,5])[0]),float(data.get("gate_origin",[11,5])[1]))),Vector2(float(box[2]),float(box[3]))*scale_value)
		gates[side]=_sprite(root+str(gate.path),rect)
	refresh_gates()
func _sprite(path:String,rect:Rect2)->Sprite2D:
	var texture:=load(path) as Texture2D
	var sprite:=Sprite2D.new();sprite.texture=texture;sprite.centered=false
	sprite.position=rect.position;sprite.scale=rect.size/texture.get_size()
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(sprite)
	return sprite
func refresh_gates()->void:
	var directions:={"north":Vector2i.UP,"east":Vector2i.RIGHT,"south":Vector2i.DOWN,"west":Vector2i.LEFT}
	for side in gates:
		var sprite:Sprite2D=gates[side]
		sprite.modulate.a=1.0-room.door_phase if room.door_directions.has(directions[side]) else 1.0
func _process(_dt:float)->void:
	if active():refresh_gates()
func apply_weather(snow:float,wet:float)->void:
	for plane in ground_planes:WeatherSurfaceArt.apply(plane,snow,wet,str(plane.texture.resource_path).ends_with("background.png"))
	for gate in gates.values():WeatherSurfaceArt.apply(gate,snow,wet)
