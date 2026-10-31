@tool
class_name RoomSceneArtwork
extends Node2D
var room:RoomLevel
var data:Dictionary={}
var gates:Dictionary={}
var ground_planes:Array[Sprite2D]=[]
var background_plane:Sprite2D
var background_planes:Array[Sprite2D]=[]
var _painted_light_materials:Array[ShaderMaterial]=[]
var _painted_light_age:=0.0
var _painted_light_frame:=-1
static var _painted_light_anchors:Dictionary={}
var scene_life:=RoomSceneLife.new()
var scene_whole:=RoomSceneWhole.new()
func active()->bool:return not data.is_empty()
func camera_bounds()->Rect2:
	# Use the actual rendered background texture, independent of editable
	# collision bounds, gates and foreground decoration.
	var bounds:=Rect2()
	var found:=false
	for plane in background_planes:
		if not is_instance_valid(plane):continue
		var rect:Rect2=plane.global_transform*plane.get_rect()
		bounds=bounds.merge(rect) if found else rect
		found=true
	if found:return bounds
	return global_transform*frame_rect()
static func plane_rect(plane:Dictionary,frame:Rect2,canvas:Vector2)->Rect2:
	# Partial native-resolution planes share the same authoring coordinate space.
	# Legacy full-canvas scenes intentionally need no rect_px metadata.
	var box:Array=plane.get("rect_px",[])
	if box.size()!=4 or canvas.x<=0 or canvas.y<=0:return frame
	var factor:=frame.size/canvas
	return Rect2(frame.position+Vector2(float(box[0]),float(box[1]))*factor,Vector2(float(box[2]),float(box[3]))*factor)
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
	scene_life=RoomSceneLife.new()
	scene_whole=RoomSceneWhole.new()
	gates.clear();ground_planes.clear();background_planes.clear();background_plane=null;_painted_light_materials.clear();_painted_light_age=0;_painted_light_frame=-1;data=RoomSceneArtCatalog.definition(id)
	if not active():return
	var root:=RoomSceneArtCatalog.ROOT+id+"/"
	var frame:=frame_rect()
	var layer_anchors:Dictionary={}
	var whole_active:=scene_whole.configure(self,id)
	for plane in ([] if whole_active else data.get("planes",[])):
		var sprite:=_sprite(root+str(plane.path),plane_rect(plane,frame,Vector2(float(data.canvas[0]),float(data.canvas[1]))))
		layer_anchors[str(plane.get("layer","background"))]=sprite
		if str(plane.get("layer",""))=="background" or str(plane.path).ends_with("background.png"):
			background_planes.append(sprite)
			if background_plane==null:background_plane=sprite
		_configure_painted_light(sprite,plane,id)
		if str(plane.path)!="water.png":ground_planes.append(sprite)
	if not whole_active:scene_life.configure(self,id,layer_anchors)
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
	if Engine.is_editor_hint():return
	var advance:=is_visible_in_tree() and is_instance_valid(room) and not room.prefetching and not ComicMotion.reduced() and not UIFlow.has_screen() and not TransitionLayer.busy and not get_tree().paused
	scene_life.update(_dt,advance,ComicMotion.reduced())
	scene_whole.update(_dt,advance,ComicMotion.reduced())
	if _painted_light_materials.is_empty():return
	if advance:_painted_light_age+=_dt
	var current:=0 if ComicMotion.reduced() else floori(_painted_light_age*2)%4
	if current==_painted_light_frame:return
	_painted_light_frame=current
	for material:ShaderMaterial in _painted_light_materials:material.set_shader_parameter("model_light_frame",float(current))
func apply_weather(snow:float,wet:float)->void:
	for plane in ground_planes:WeatherSurfaceArt.apply(plane,snow,wet,background_planes.has(plane))
	for gate in gates.values():WeatherSurfaceArt.apply(gate,snow,wet)
	scene_life.apply_weather(snow,wet)

func _configure_whole_lights(sprite:Sprite2D,id:String)->void:
	_configure_painted_light(sprite,{"path":""},id)
	var anchors:Array=[]
	for values:Array in _painted_light_anchors.get(id,{}).get("plane_centers",{}).values():
		for value:Array in values:
			if not anchors.has(value):anchors.append(value)
	_configure_painted_light(sprite,{"path":"__whole__"},id,anchors)

func _configure_painted_light(sprite:Sprite2D,plane:Dictionary,id:String,override_anchors:Array=[])->void:
	if Engine.is_editor_hint():return
	if _painted_light_anchors.is_empty():
		var path:="res://assets/light_models_v16/painted_anchors.json"
		if not FileAccess.file_exists(path):return
		_painted_light_anchors=JSON.parse_string(FileAccess.get_file_as_string(path))
	var profile:Dictionary=_painted_light_anchors.get(id,{})
	var anchors:Array=override_anchors if not override_anchors.is_empty() else profile.get("plane_centers",{}).get(str(plane.path),[])
	if anchors.is_empty():return
	var raw:Array=plane.get("rect_px",[0,0,data.canvas[0],data.canvas[1]])
	var source_rect:=Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
	var ellipses:=PackedVector4Array()
	for center:Array in anchors:
		var at:=Vector2(float(center[0]),float(center[1]));var radius:=Vector2(float(center[2]),float(center[3]))
		if not source_rect.intersects(Rect2(at-radius,radius*2)):continue
		var uv:Vector2=(at-source_rect.position)/source_rect.size
		var extent:Vector2=radius/source_rect.size
		ellipses.append(Vector4(uv.x,uv.y,extent.x,extent.y))
	if ellipses.is_empty():return
	var count:=mini(16,ellipses.size());ellipses.resize(16)
	var material:=WeatherSurfaceArt.make(true)
	material.set_shader_parameter("model_light_ellipses",ellipses)
	material.set_shader_parameter("model_light_count",count)
	sprite.material=material;_painted_light_materials.append(material)
