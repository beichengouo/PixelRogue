class_name RoomEditorCanvas
extends Control
signal gesture(tool: String, start: Vector2i, end: Vector2i, cells: Array[Vector2i])
signal object_drag(layer: String, entry_id: String, offset: Vector2i)
signal collision_edit(target: String, action: String, index: int, point: Vector2)
var document: Dictionary = {}
var zoom := 1.0
var tool := "collision"
var preview := false
var visible_layers: Dictionary = {}
var _textures: Dictionary = {}
var _drawing := false
var _start := Vector2i.ZERO
var _current := Vector2i.ZERO
var _cells: Array[Vector2i] = []
var _clock := 0.0
var _water_art: GDScript
var _origin := Vector2(36,36)
var _drag_hit: Dictionary = {}
var _drag_offset := Vector2i.ZERO
var collision_target := ""
var collision_add_mode := false
var _collision_drag_index := -1
var _collision_drag_point := Vector2.ZERO

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists("res://src/room_mode/room_water_art.gd"):_water_art=load("res://src/room_mode/room_water_art.gd")

func set_document(value: Dictionary) -> void:
	document=value
	_origin=Vector2(36,36)
	for entry in value.layers.decor:
		if not RoomEditorCatalog.is_service(str(entry.asset_id)):continue
		var texture := _texture(str(entry.asset_id))
		if texture==null:continue
		var art := RoomEditorCatalog.service_art_rect(entry,texture.get_size())
		_origin.x=maxf(_origin.x,18-art.position.x);_origin.y=maxf(_origin.y,18-art.position.y)
	var scene := RoomEditorCollision.definition(value)
	if not scene.is_empty() and scene.has("floor_rect_px"):
		var floor: Array = scene.floor_rect_px
		var scale_value := Vector2(float(value.grid.size[0])*36/float(floor[2]),float(value.grid.size[1])*36/float(floor[3]))
		_origin.x=maxf(_origin.x,float(floor[0])*scale_value.x+18)
		_origin.y=maxf(_origin.y,float(floor[1])*scale_value.y+18)
	custom_minimum_size=(Vector2(value.grid.size[0],value.grid.size[1])*36+_origin+Vector2(36,36))*zoom
	queue_redraw()

func _process(dt: float) -> void:
	_clock+=dt
	if not document.is_empty() and (not document.layers.water.is_empty() or document.layers.decor.any(func(entry):return str(entry.asset_id).begins_with("supplied:"))):queue_redraw()

func _texture(asset_id: String) -> Texture2D:
	if asset_id.begins_with("supplied:"):return SuppliedMapAssets.texture(asset_id,_clock)
	if not _textures.has(asset_id):_textures[asset_id]=RoomEditorCatalog.texture(asset_id)
	return _textures[asset_id] as Texture2D

func _draw() -> void:
	if document.is_empty():return
	draw_set_transform(_origin*zoom,0,Vector2.ONE*zoom)
	var grid := Vector2i(int(document.grid.size[0]),int(document.grid.size[1]))
	var ground: Texture2D = _texture(str(document.base_ground))
	var scene := RoomEditorCollision.definition(document)
	if not scene.has("floor_rect_px") and visible_layers.get("background",true):
		for y in grid.y:
			for x in grid.x:
				if ground!=null:
					if str(document.base_ground).begins_with("supplied:"):draw_texture_rect(ground,Rect2(Vector2(x,y)*36,Vector2.ONE*36),false)
					else:draw_texture_rect_region(ground,Rect2(Vector2(x,y)*36,Vector2.ONE*36),Rect2(posmod(x,2)*36,posmod(y,2)*36,36,36),Color(0.96,1.0,0.96))
	elif scene.has("floor_rect_px"):
		var floor: Array = scene.floor_rect_px
		var scale_value := Vector2(float(grid.x)*36/float(floor[2]),float(grid.y)*36/float(floor[3]))
		var frame := Rect2(-Vector2(float(floor[0]),float(floor[1]))*scale_value,Vector2(float(scene.canvas[0]),float(scene.canvas[1]))*scale_value)
		for plane in scene.get("planes",[]):
			var plane_layer:String=str(plane.get("layer","background" if str(plane.path).get_file()=="background.png" else "water_bridge"))
			if not visible_layers.get(plane_layer,true):continue
			var path := RoomSceneArtCatalog.ROOT+str(document.scene_art)+"/"+str(plane.path)
			if ResourceLoader.exists(path):draw_texture_rect(load(path),frame,false)
	if visible_layers.get("background",true):
		for entry in document.layers.ground:
			var texture := _texture(str(entry.asset_id))
			if texture!=null:
				if str(entry.asset_id).begins_with("supplied:"):draw_texture_rect(texture,Rect2(Vector2(entry.at[0],entry.at[1])*36,Vector2.ONE*36),false)
				else:draw_texture_rect_region(texture,Rect2(Vector2(entry.at[0],entry.at[1])*36,Vector2.ONE*36),Rect2(posmod(int(entry.at[0]),2)*36,posmod(int(entry.at[1]),2)*36,36,36),Color(0.96,1.0,0.96))
	if visible_layers.get("water_bridge",true):
		var cells := {}
		for source in document.layers.water:
			var entry := _display_entry("water",source)
			cells[Vector2i(int(entry.at[0]),int(entry.at[1]))]=true
		if _water_art!=null and _water_art.has_method("draw_cells"):_water_art.call("draw_cells",self,cells,_clock)
		else:
			var water := _texture("water")
			if water!=null:
				for cell in cells:draw_texture_rect_region(water,Rect2(Vector2(cell)*36,Vector2.ONE*36),Rect2(36,36,36,36))
	if not scene.is_empty():
		for item in scene.get("objects",[]):
			if not visible_layers.get(str(item.get("layer","objects")),true):continue
			var path := str(item.get("texture",""))
			if not path.begins_with("res://"):path=RoomSceneArtCatalog.ROOT+str(document.scene_art)+"/"+path
			if not ResourceLoader.exists(path):continue
			var texture: Texture2D = load(path)
			var width := float(item.get("render_width_px",36))
			var art_size := Vector2(texture.get_size())*(width/float(texture.get_width()))
			var pair: Array = item.get("position_px",[0,0])
			draw_texture_rect(texture,Rect2(Vector2(float(pair[0]),float(pair[1]))-Vector2(art_size.x*0.5,art_size.y),art_size),false)
		var building: Dictionary = scene.get("service_building",{})
		if not building.is_empty() and visible_layers.get("buildings",true):
			var path := RoomSceneArtCatalog.ROOT+str(document.scene_art)+"/"+str(building.get("texture",""))
			if ResourceLoader.exists(path):
				var texture: Texture2D = load(path)
				var width := float(building.get("width_px",180))
				var art_size := Vector2(texture.get_size())*(width/float(texture.get_width()))
				var pair: Array = building.get("position_px",[0,0])
				draw_texture_rect(texture,Rect2(Vector2(float(pair[0]),float(pair[1]))-Vector2(art_size.x*0.5,art_size.y),art_size),false)
	var objects: Array[Dictionary] = []
	for layer in ["decor","obstacles","entities"]:
		for entry in document.layers[layer]:
			var view_layer := "buildings" if RoomEditorCatalog.is_service(str(entry.asset_id)) else "objects"
			if visible_layers.get(view_layer,true):objects.append(entry)
	objects.sort_custom(func(a,b):return (RoomEditorCatalog.service_position(a).y if RoomEditorCatalog.is_service(str(a.asset_id)) else int(a.at[1])*36+18)<(RoomEditorCatalog.service_position(b).y if RoomEditorCatalog.is_service(str(b.asset_id)) else int(b.at[1])*36+18))
	for entry in objects:
		var asset := RoomEditorCatalog.get_entry(str(entry.asset_id))
		var texture := _texture(str(entry.asset_id))
		if asset.is_empty() or texture==null:continue
		if RoomEditorCatalog.is_service(str(entry.asset_id)):
			draw_texture_rect(texture,RoomEditorCatalog.service_art_rect(entry,texture.get_size()),false)
			continue
		var footprint := Vector2(asset.size[0],asset.size[1])*36
		var art_size := Vector2(texture.get_size())*(footprint.x/maxf(1,texture.get_width()))
		var anchor := Vector2(entry.at[0],entry.at[1])*36+Vector2(0,footprint.y-art_size.y)
		draw_texture_rect(texture,Rect2(anchor,art_size),false)
	if preview:return
	if visible_layers.get("collision",true):
		var room_bounds := RoomEditorCollision.bounds(document)
		draw_rect(room_bounds,Color(1,0.38,0.2,0.82) if collision_target=="room_bounds" and tool=="collision" else Color(1,0.45,0.25,0.52),false,3.0)
		if tool=="collision":_draw_collisions()
	for x in range(grid.x+1):draw_line(Vector2(x*36,0),Vector2(x*36,grid.y*36),Color(1,1,1,0.16),1)
	for y in range(grid.y+1):draw_line(Vector2(0,y*36),Vector2(grid.x*36,y*36),Color(1,1,1,0.16),1)
	if visible_layers.get("spawns",true):
		for source in document.layers.markers:
			var entry := _display_entry("markers",source)
			var center := (Vector2(entry.at[0],entry.at[1])+Vector2.ONE*0.5)*36
			draw_circle(center,9,Color(1,0.75,0.25,0.8));draw_line(center-Vector2(14,0),center+Vector2(14,0),Color.WHITE,2);draw_line(center-Vector2(0,14),center+Vector2(0,14),Color.WHITE,2)
			draw_string(ThemeDB.fallback_font,center+Vector2(16,5),str(source.id) if str(source.asset_id).begins_with("camp:") else "刷怪点",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(1,0.84,0.4))
	if visible_layers.get("doors",true):
		var floor: Array = scene.get("floor_rect_px",[])
		if not floor.is_empty():
			var scale_value := Vector2(float(grid.x)*36/float(floor[2]),float(grid.y)*36/float(floor[3]))
			var frame := Rect2(-Vector2(float(floor[0]),float(floor[1]))*scale_value,Vector2(float(scene.canvas[0]),float(scene.canvas[1]))*scale_value)
			for side in scene.get("gates",{}):
				var gate: Dictionary = scene.gates[side]
				var path := RoomSceneArtCatalog.ROOT+str(document.scene_art)+"/"+str(gate.path)
				if not ResourceLoader.exists(path):continue
				var box: Array = gate.rect_px
				draw_texture_rect(load(path),Rect2(frame.position+Vector2(float(box[0]),float(box[1]))*scale_value+RoomSceneArtwork.gate_offset(side,document.ports,Vector2(float(scene.get("gate_origin",[11,5])[0]),float(scene.get("gate_origin",[11,5])[1]))),Vector2(float(box[2]),float(box[3]))*scale_value),false)
		for port in document.ports:
			var rect := Rect2(Vector2(port.at[0],port.at[1])*36,Vector2.ONE*36)
			draw_rect(rect,Color(0.25,1,0.88,0.75),false,3)
	for handle in _handles():
		var center: Vector2 = handle.center
		if _drag_hit.get("id","")==handle.id:center+=Vector2(_drag_offset)*36
		var color := Color(1,0.76,0.3)
		draw_circle(center,7,Color(0.04,0.07,0.12,0.92))
		draw_circle(center,6,color,false,1.5)
		draw_line(center-Vector2(4,0),center+Vector2(4,0),color,1.5)
		draw_line(center-Vector2(0,4),center+Vector2(0,4),color,1.5)
	if _drawing and tool=="port":
		var from := (Vector2(_start)+Vector2.ONE*0.5)*36
		var to := (Vector2(_current)+Vector2.ONE*0.5)*36
		draw_line(from,to,Color(0.25,1,0.88,0.95),3)
		draw_rect(Rect2(Vector2(_current)*36,Vector2.ONE*36),Color(0.25,1,0.88,0.95),false,3)

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(((point/zoom-_origin)/36).floor())

func _world(point: Vector2) -> Vector2:
	return point/zoom-_origin

func _draw_collisions() -> void:
	for target in RoomEditorCollision.targets(document):
		var key: String = target.key
		if key=="room_bounds":
			if collision_target==key:
				var rect := RoomEditorCollision.bounds(document)
				if _collision_drag_index>=0:
					var raw := RoomEditorCollision.moved_bounds(document,_collision_drag_index,_collision_drag_point)
					rect=Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
				draw_rect(rect,Color(1,0.28,0.3,0.95),false,3.0)
				var temp := document.duplicate(true)
				temp.room_bounds_override=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
				for handle in RoomEditorCollision.bounds_handles(temp):
					draw_circle(handle,6.0,Color(1,0.9,0.25));draw_circle(handle,6.0,Color(0.1,0.07,0.06),false,1)
			continue
		var raw := RoomEditorCollision.shape(document,key)
		var origin := RoomEditorCollision.origin(document,key)
		var active := key==collision_target
		var color := Color(1,0.28,0.3,0.95) if active else (Color(0.25,0.8,1,0.55) if not key.begins_with("water:") else Color(0.25,0.5,1,0.55))
		for index in raw.size():
			var a := origin+Vector2(float(raw[index][0]),float(raw[index][1]))
			var next := (index+1)%raw.size()
			var b := origin+Vector2(float(raw[next][0]),float(raw[next][1]))
			if index==_collision_drag_index and active:a=_collision_drag_point
			if next==_collision_drag_index and active:b=_collision_drag_point
			if raw.size()>2 or index+1<raw.size():draw_line(a,b,color,2.5 if active else 1.5)
			if active:draw_circle(a,5.5,Color(1,0.9,0.25));draw_circle(a,5.5,Color(0.1,0.07,0.06),false,1)
		if active and raw.is_empty():
			draw_circle(origin,5,Color(1,0.3,0.3,0.85),false,2)

func _collision_vertex(point: Vector2) -> int:
	if collision_target=="room_bounds":
		var bounds_handles := RoomEditorCollision.bounds_handles(document)
		var nearest := -1
		var best := 12.0/zoom
		for index in bounds_handles.size():
			var distance := point.distance_to(bounds_handles[index])
			if distance<best:nearest=index;best=distance
		return nearest
	var raw := RoomEditorCollision.shape(document,collision_target)
	var origin := RoomEditorCollision.origin(document,collision_target)
	var best := -1
	var distance := 11.0/zoom
	for index in raw.size():
		var at := origin+Vector2(float(raw[index][0]),float(raw[index][1]))
		if point.distance_to(at)<distance:best=index;distance=point.distance_to(at)
	return best

func _collision_edge(point: Vector2) -> int:
	if collision_target=="room_bounds":return -1
	var raw := RoomEditorCollision.shape(document,collision_target)
	if raw.size()<2:return -1
	var origin := RoomEditorCollision.origin(document,collision_target)
	var best := -1
	var distance := 10.0/zoom
	for index in raw.size():
		var a := origin+Vector2(float(raw[index][0]),float(raw[index][1]))
		var b := origin+Vector2(float(raw[(index+1)%raw.size()][0]),float(raw[(index+1)%raw.size()][1]))
		var t := clampf((point-a).dot(b-a)/maxf(0.001,(b-a).length_squared()),0.0,1.0)
		var gap := point.distance_to(a.lerp(b,t))
		if gap<distance:best=index;distance=gap
	return best

func _display_entry(layer: String, source: Dictionary) -> Dictionary:
	if _drag_hit.get("layer","")!=layer or _drag_hit.get("id","")!=str(source.id):return source
	var entry := source.duplicate(true)
	entry.at=[int(entry.at[0])+_drag_offset.x,int(entry.at[1])+_drag_offset.y]
	return entry

func _handles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not visible_layers.get("spawns",true):return result
	for entry in document.layers.markers:
		if str(entry.asset_id)!="spawn" and not str(entry.asset_id).begins_with("camp:"):continue
		var center := (Vector2(entry.at[0],entry.at[1])+Vector2.ONE*0.5)*36
		result.append({"layer":"markers","id":str(entry.id),"center":center,"at":entry.at.duplicate()})
	return result

func _handle_at(point: Vector2) -> Dictionary:
	var world := point/zoom-_origin
	var nearest: Dictionary = {}
	var distance := 10.0/zoom
	var handles := _handles();handles.reverse()
	for handle in handles:
		var candidate := world.distance_to(handle.center)
		if candidate<distance:nearest=handle;distance=candidate
	return nearest

func _get_tooltip(at_position: Vector2) -> String:
	if preview or document.is_empty():return ""
	var handle := _handle_at(at_position)
	if handle.is_empty():return ""
	return "敌人出生点：拖动黄色标记调整，右键删除。"

func _gui_input(event: InputEvent) -> void:
	if document.is_empty() or preview:return
	if tool=="collision":
		if visible_layers.get("collision",true):_collision_input(event)
		return
	if tool not in ["spawn","port"]:return
	if tool=="spawn" and not visible_layers.get("spawns",true):return
	if tool=="port" and not visible_layers.get("doors",true):return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		if event.pressed:
			_drag_hit={};_drag_offset=Vector2i.ZERO
			if event.button_index==MOUSE_BUTTON_LEFT and tool=="spawn":_drag_hit=_handle_at(event.position)
			if not _drag_hit.is_empty():
				_start=_cell(event.position);_current=_start;accept_event();queue_redraw();return
			_drawing=true;_start=_cell(event.position);_current=_start;_cells=[_start]
		else:
			if not _drag_hit.is_empty():
				var hit := _drag_hit;var offset := _cell(event.position)-_start
				_drag_hit={};_drag_offset=Vector2i.ZERO
				object_drag.emit(str(hit.layer),str(hit.id),offset);accept_event();queue_redraw();return
			if _drawing:gesture.emit("erase" if event.button_index==MOUSE_BUTTON_RIGHT and tool=="spawn" else tool,_start,_cell(event.position),_cells.duplicate())
			_drawing=false
		accept_event();queue_redraw()
	elif event is InputEventMouseMotion and not _drag_hit.is_empty():
		_drag_offset=_cell(event.position)-_start;accept_event();queue_redraw()
	elif event is InputEventMouseMotion and _drawing:
		var next := _cell(event.position)
		# Rasterize drag segments so fast mouse movement never skips cells.
		var delta := next-_current
		var steps := maxi(absi(delta.x),absi(delta.y))
		for i in range(1,steps+1):
			var at := Vector2i((Vector2(_current).lerp(Vector2(next),float(i)/steps)).round())
			if not _cells.has(at):_cells.append(at)
		_current=next;accept_event();queue_redraw()

func _collision_input(event: InputEvent) -> void:
	if collision_target.is_empty():return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		var point := _world(event.position)
		if event.pressed:
			var index := _collision_vertex(point)
			if collision_target=="room_bounds":
				if event.button_index==MOUSE_BUTTON_LEFT and index>=0:_collision_drag_index=index;_collision_drag_point=point
			elif event.button_index==MOUSE_BUTTON_RIGHT:
				if index>=0:collision_edit.emit(collision_target,"delete",index,point)
			elif collision_add_mode:
				collision_edit.emit(collision_target,"add",-1,point)
			elif event.double_click:
				var edge := _collision_edge(point)
				if edge>=0:collision_edit.emit(collision_target,"insert",edge+1,point)
			elif index>=0:
				_collision_drag_index=index;_collision_drag_point=point
		else:
			if _collision_drag_index>=0:
				collision_edit.emit(collision_target,"move",_collision_drag_index,point)
				_collision_drag_index=-1
		accept_event();queue_redraw()
	elif event is InputEventMouseMotion and _collision_drag_index>=0:
		_collision_drag_point=_world(event.position);accept_event();queue_redraw()
