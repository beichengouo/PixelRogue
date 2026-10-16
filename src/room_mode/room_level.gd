@tool
class_name RoomLevel
extends Level
## Dedicated ground plane. Original Level scene and collision indices stay intact.
signal door_requested(direction: Vector2i)
@export var use_editor_obstacles:=false:
	set(value):
		use_editor_obstacles=value
		if is_node_ready():load_room(record)
var record: Dictionary = {}
var tactics:=RoomTactics.new()
var obstacles: Dictionary = {}
var deep_water:Dictionary={}
var ground_materials:Dictionary={}
var water_root:Node2D
var shell_art:Node2D
var flying_navigation:=AStarGrid2D.new()
var props_root: Node2D
var navigation := AStarGrid2D.new()
var large_navigation:=AStarGrid2D.new()
var door_directions: Array[Vector2i] = []
var doors_open := true:
	set(value):
		doors_open=value
		if is_node_ready():queue_redraw()
var door_phase:=1.0
var _floors: Array[Texture2D] = []
var _doors:Dictionary={}
var _door_motion:Texture2D
var _service_floors:Dictionary={}
var decor_root:Node2D
var wall_texture:Texture2D
var shell_textures:Dictionary={}
var room_rect:=RoomLayout.RECT
var service_footprints:Array[Rect2]=[]
var service_building:RoomServiceProp
var boundary_root:Node2D
var scene_objects:Array=[]
var scene_polygons:Dictionary={}
var scene_water_polygons:Array[PackedVector2Array]=[]
var scene_water_collision_override:=false
var scene_occlusion:=RoomSceneOcclusion.new()
var scene_navigation:=preload("res://src/room_mode/room_scene_navigation.gd").new()
var illustration:RoomSceneArtwork
var _aspect:=-1.0
var _load_generation:=0
const SHELL_TOP:=54.0
const SHELL_BOTTOM:=54.0
const SHELL_SIDE:=42.0
func visual_frame()->Rect2:
	if illustration!=null and illustration.active():return illustration.frame_rect()
	return Rect2(room_rect.position-Vector2(SHELL_SIDE,SHELL_TOP),room_rect.size+Vector2(SHELL_SIDE*2,SHELL_TOP+SHELL_BOTTOM))
func fit_to_view(view:Vector2)->void:
	# A window resize never mutates collision, floor cells, ports or the save layout.
	_aspect=view.x/maxf(1,view.y)

func port_position(direction:Vector2i)->Vector2:
	var point:=room_rect.get_center()
	var side:String={Vector2i.UP:"north",Vector2i.RIGHT:"east",Vector2i.DOWN:"south",Vector2i.LEFT:"west"}.get(direction,"")
	for port in record.get("terrain_layout",{}).get("ports",[]):
		if str(port.side)!=side:continue
		if direction.y!=0:point.x=(float(port.at[0])+.5)*36
		else:point.y=(float(port.at[1])+.5)*36
	return point
func service_anchor()->Vector2:
	if is_instance_valid(service_building):return service_building.position
	return Vector2(216,170) if str(record.get("kind",""))=="shop" else Vector2(468,174)
func door_point(direction:Vector2i,inset:=20.0)->Vector2:
	var point:=port_position(direction)
	if direction.x!=0:point.x=room_rect.position.x+inset if direction.x<0 else room_rect.end.x-inset
	if direction.y!=0:point.y=room_rect.position.y+inset if direction.y<0 else room_rect.end.y-inset
	return point
func entry_point(direction:Vector2i)->Vector2:
	return door_point(-direction,58.0)
func door_rect(direction:Vector2i)->Rect2:
	var middle:=port_position(direction)
	if direction==Vector2i.UP:return Rect2(middle.x-64,room_rect.position.y-48,128,96)
	# The south sprite occupies only the top 64px of its atlas cell. Align its
	# lintel with the south wall instead of centering transparent padding on it.
	if direction==Vector2i.DOWN:return Rect2(middle.x-64,room_rect.end.y-10,128,64)
	# Side gates occupy the wall's 36px thickness; their atlas shoulders are
	# scenery for the old side-facing model, not a wall projecting into the room.
	if direction==Vector2i.LEFT:return Rect2(room_rect.position.x-36,middle.y-48,36,96)
	return Rect2(room_rect.end.x,middle.y-48,36,96)

func _ready() -> void:
	player_spawn = Vector2(342,198)
	shop_spawn = Vector2(180,90)
	tavern_spawn = Vector2(504,90)
	boundary_root=Node2D.new();boundary_root.name="Boundary";add_child(boundary_root)
	props_root = Node2D.new(); props_root.name = "Props"; props_root.y_sort_enabled = true; add_child(props_root)
	water_root=Node2D.new();water_root.name="DeepWater";add_child(water_root)
	var water:=RoomWater.new();water.room=self;water_root.add_child(water)
	shell_art=RoomShellArt.new();shell_art.room=self;add_child(shell_art)
	illustration=RoomSceneArtwork.new();illustration.room=self;illustration.name="IllustratedRoom";add_child(illustration)
	decor_root=Node2D.new();decor_root.name="ServiceDecor";decor_root.y_sort_enabled=true;add_child(decor_root)
	navigation.region = Rect2i(Vector2i.ZERO,RoomLayout.SIZE)
	navigation.cell_size = Vector2.ONE*36
	navigation.offset = Vector2.ONE*18
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	large_navigation.region=Rect2i(navigation.region.position*2,navigation.region.size*2)
	large_navigation.cell_size=Vector2.ONE*18;large_navigation.offset=Vector2.ONE*9
	large_navigation.diagonal_mode=navigation.diagonal_mode;large_navigation.update()
	flying_navigation.cell_size=navigation.cell_size;flying_navigation.offset=navigation.offset;flying_navigation.diagonal_mode=navigation.diagonal_mode
	for biome in ["forest","wetland","ruin"]:
		var path: String = "res://assets/room_mode/floor_"+biome+".png"
		_floors.append(load(path) if ResourceLoader.exists(path) else null)
	for direction_name in ["north","south","west","east"]:
		var path: String="res://assets/room_mode/door_"+direction_name+".png"
		if ResourceLoader.exists(path):_doors[direction_name]=load(path)
	if ResourceLoader.exists("res://assets/room_mode/wall.png"):wall_texture=load("res://assets/room_mode/wall.png")
	if ResourceLoader.exists("res://assets/room_mode/doors/door_motion.png"):_door_motion=load("res://assets/room_mode/doors/door_motion.png")
	for material in ["wood","cobble","garden","carpet"]:
		var path:String="res://assets/room_mode/services/floor_"+material+".png"
		if ResourceLoader.exists(path):_service_floors[material]=load(path)
	for material in ["grass","mud","stone","wood"]:
		var path:String="res://assets/room_mode/terrain_v3/floor_"+material+".png"
		if ResourceLoader.exists(path):_service_floors[material]=load(path)
	for side in ["north","south","west","east","nw","ne","sw","se"]:
		var path:String="res://assets/room_mode/structure/wall_"+str(side)+".png"
		if ResourceLoader.exists(path):shell_textures[side]=load(path)
	if ResourceLoader.exists("res://assets/room_mode/structure/doors.png"):_door_motion=load("res://assets/room_mode/structure/doors.png")
	fit_to_view(Vector2(1280,720) if Engine.is_editor_hint() else get_viewport_rect().size)
	_build_boundary();_refresh_navigation()
	if Engine.is_editor_hint():
		load_room({"seed":"1","kind":"normal","biome":"forest","doors":[],"delta":{}})
		for name_value in ["FloorTiles","ObstacleTiles"]:
			var layer:=get_node_or_null(name_value) as TileMapLayer
			if layer!=null:layer.changed.connect(_editor_changed)

func _editor_changed()->void:
	if Engine.is_editor_hint():load_room.call_deferred(record)

func _build_boundary() -> void:
	for child in boundary_root.get_children():boundary_root.remove_child(child);child.queue_free()
	var center:=room_rect.get_center()
	for pair in [[Vector2(center.x,room_rect.position.y-18),Vector2(room_rect.size.x+72,36)],[Vector2(center.x,room_rect.end.y+18),Vector2(room_rect.size.x+72,36)],[Vector2(room_rect.position.x-18,center.y),Vector2(36,room_rect.size.y)],[Vector2(room_rect.end.x+18,center.y),Vector2(36,room_rect.size.y)]]:
		var body := StaticBody2D.new(); body.collision_layer = Layers.WORLD
		var shape := RectangleShape2D.new(); shape.size = pair[1]
		var collider := CollisionShape2D.new(); collider.shape = shape
		body.position = pair[0]; body.add_child(collider); boundary_root.add_child(body)

func load_room(data: Dictionary) -> void:
	var layout:=_load_room_begin(data)
	_load_room_props(data,layout)
	_load_room_water(layout)
	_load_room_decor(layout)
	_load_room_entities(layout)
	_load_room_finish(data,layout)

func load_room_async(data: Dictionary, request_owner: Node = null, transition_epoch: int = -1) -> bool:
	var owner_ref:WeakRef=weakref(request_owner) if request_owner!=null else null
	if _room_requires_template(data):
		_load_generation+=1
		var preparation_generation:=_load_generation
		var pool:=RoomTemplatePool.new()
		if not await pool.ensure_loaded_async(get_tree(),_load_room_request_valid.bind(preparation_generation,owner_ref,transition_epoch)):return false
		if not await _load_room_frame(preparation_generation,owner_ref,transition_epoch):return false
		_select_room_template(data,pool)
		if not await _load_room_frame(preparation_generation,owner_ref,transition_epoch):return false
	var layout:=_load_room_begin(data)
	var generation:=_load_generation
	if not await _load_room_frame(generation,owner_ref,transition_epoch):return false
	var props:Array=layout.get("props",[])
	for offset in range(0,props.size(),16):
		_load_room_props(data,layout,offset,offset+16)
		if not await _load_room_frame(generation,owner_ref,transition_epoch):return false
	var water:Array=layout.get("water",[])
	if water.is_empty():_load_room_water(layout)
	for offset in range(0,water.size(),24):
		_load_room_water(layout,offset,offset+24)
		if not await _load_room_frame(generation,owner_ref,transition_epoch):return false
	var decor:Array=layout.get("decor",[])
	for offset in range(0,decor.size(),16):
		_load_room_decor(layout,offset,offset+16)
		if not await _load_room_frame(generation,owner_ref,transition_epoch):return false
	var entities:Array=layout.get("entities",[])
	for offset in range(0,entities.size(),16):
		_load_room_entities(layout,offset,offset+16)
		if not await _load_room_frame(generation,owner_ref,transition_epoch):return false
	_load_room_finish_begin(data)
	if not await _load_room_frame(generation,owner_ref,transition_epoch):return false
	var scene_items:Array=layout.get("scene_objects",[])
	if scene_items.is_empty():load_scene_objects(scene_items,"")
	for offset in range(0,scene_items.size(),12):
		load_scene_objects(scene_items,"",offset,offset+12)
		if not await _load_room_frame(generation,owner_ref,transition_epoch):return false
	_load_room_finish_end()
	if not scene_polygons.is_empty() or not scene_water_polygons.is_empty():
		var radii:Array=[12.0] if str(data.get("kind",""))=="camp" else [12.0,14.0]
		if str(data.get("kind","")) in ["boss","boss_rush"]:radii.append(26.0)
		var valid:=_load_room_request_valid.bind(generation,owner_ref,transition_epoch)
		for radius:float in radii:
			if not await scene_navigation.prepare(self,radius,false,valid):return false
		if str(data.get("kind",""))!="camp" and not await scene_navigation.prepare(self,12.0,true,valid):return false
	return true

func _load_room_frame(generation:int, owner_ref:WeakRef, transition_epoch:int)->bool:
	await get_tree().process_frame
	return _load_room_request_valid(generation,owner_ref,transition_epoch)

func _load_room_request_valid(generation:int, owner_ref:WeakRef, transition_epoch:int)->bool:
	var owner:Variant=owner_ref.get_ref() if owner_ref!=null else null
	return generation==_load_generation and (owner_ref==null or is_instance_valid(owner) and owner.is_inside_tree()) and (transition_epoch<0 or TransitionLayer.busy and TransitionLayer._epoch==transition_epoch)

func _room_requires_template(data:Dictionary)->bool:
	if not data.has("terrain_layout"):return true
	var previous:Dictionary=data.get("terrain_layout",{})
	if not RoomTemplatePool.replacement_id(previous).is_empty():return true
	# This identifies the retired procedural fallback in old saved runs.
	return previous.has("motif") and previous.has("models") and str(previous.get("scene_art","")).is_empty() and str(previous.get("template_id","")).is_empty()

func _select_room_template(data:Dictionary,pool:RoomTemplatePool)->void:
	var chapter:=ChapterCatalog.normalize(data.get("chapter_id",ChapterCatalog.FIRST))
	var kind:=str(data.get("kind","normal"))
	var selection_kind:="boss:"+str(data.get("boss","king")) if kind=="boss" else ("boss:"+str(ChapterCatalog.bosses(chapter)[0]) if kind=="boss_rush" else ("normal" if kind in ["spawn","elite"] else kind))
	var seed_value:=int(data.get("seed",0))
	var theme:=str(data.get("biome","forest"))
	var template:=pool.select(seed_value,selection_kind,theme,chapter,false)
	if kind=="elite":
		var selection_rng:=RandomNumberGenerator.new();selection_rng.seed=seed_value^0x6813c
		if selection_rng.randf()<.5:
			var dedicated:=pool.select(seed_value,"elite",theme,chapter,false)
			if not dedicated.is_empty():template=dedicated
	var previous:Dictionary=data.get("terrain_layout",{})
	var preferred_id:=RoomTemplatePool.replacement_id(previous)
	var opening_tavern:bool=kind=="tavern" and (bool(data.get("starting_tavern",false)) or data.get("doors",[]).has("0,0"))
	if kind=="spawn":preferred_id=str(ChapterCatalog.config(chapter).start)
	elif opening_tavern:preferred_id="tavern_waterfront"
	if not preferred_id.is_empty():
		for item in pool.templates:
			if str(item.id)==preferred_id:template=item.duplicate(true);break
	if template.is_empty():template=pool.select(seed_value,"normal",theme,chapter,false)
	var decoded:=RoomTemplateCodec.to_layout(template) if not template.is_empty() else {}
	if decoded.is_empty() and selection_kind!="normal":
		template=pool.select(seed_value,"normal",theme,chapter)
		decoded=RoomTemplateCodec.to_layout(template) if not template.is_empty() else {}
	if decoded.is_empty():push_error("No valid authored room template for "+selection_kind)
	data.terrain_layout=decoded
	if not template.is_empty():data.biome=str(template.theme);data.indoor=bool(template.get("indoor",false))

func _load_room_begin(data:Dictionary)->Dictionary:
	_load_generation+=1
	record = data
	var floor_layer:=get_node_or_null("FloorTiles") as TileMapLayer
	if floor_layer!=null:floor_layer.visible=Engine.is_editor_hint()
	for child in props_root.get_children(): props_root.remove_child(child); child.queue_free()
	for child in decor_root.get_children():decor_root.remove_child(child);child.queue_free()
	obstacles.clear();deep_water.clear();ground_materials.clear();service_footprints.clear();service_building=null
	scene_objects.clear();scene_polygons.clear();scene_water_polygons.clear();scene_occlusion.clear()
	for child in water_root.get_children():
		if child is StaticBody2D:water_root.remove_child(child);child.queue_free()
	_refresh_navigation()
	if _room_requires_template(data):
		var pool:=RoomTemplatePool.new()
		_select_room_template(data,pool)
	var layout:Dictionary=data.terrain_layout
	data.biome=EnemyCombatPolicy.record_biome(data)
	scene_water_collision_override=bool(layout.get("scene_water_collision_override",false))
	if layout.has("room_rect"):
		var box:Array=layout.room_rect
		room_rect=Rect2(float(box[0]),float(box[1]),float(box[2]),float(box[3]))
	else:room_rect=Rect2(-72,-36,828,468)
	player_spawn=room_rect.get_center()
	var scene_id:=str(layout.get("scene_art",""))
	illustration.configure(scene_id)
	if not layout.has("scene_objects") and not scene_id.is_empty():
		# Freeze authored geometry once so future asset/template changes cannot move saved objects.
		layout.scene_objects=RoomSceneArtCatalog.definition(scene_id).get("objects",[]).duplicate(true)
		for item in layout.scene_objects:
			if not str(item.get("texture","")).begins_with("res://"):item.texture=RoomSceneArtCatalog.ROOT+scene_id+"/"+str(item.get("texture",""))
	if not layout.has("scene_water_polygons_px") and not scene_id.is_empty():
		layout.scene_water_polygons_px=RoomSceneArtCatalog.definition(scene_id).get("surface_water_polygons_px",[]).duplicate(true)
	for shape:Array in layout.get("scene_water_polygons_px",[]):
		var polygon:=RoomSceneGeometry.polygon(shape)
		if polygon.size()>=3:scene_water_polygons.append(polygon)
	shell_art.visible=not illustration.active()
	for child in water_root.get_children():
		if child is RoomWater:child.visible=not illustration.active()
	if floor_layer!=null:floor_layer.visible=Engine.is_editor_hint()
	_build_boundary();_refresh_navigation()
	var painted:=get_node_or_null("ObstacleTiles") as TileMapLayer
	if painted!=null:
		painted.visible=Engine.is_editor_hint() and use_editor_obstacles
		props_root.visible=not painted.visible
		decor_root.visible=not painted.visible
		if use_editor_obstacles and RoomGraph.is_combat(str(data.get("kind","normal"))):
			layout={"crates":[],"stones":[],"water":[],"props":[],"decor":[]}
			for at in painted.get_used_cells():
				if not navigation.region.has_point(at):continue
				var source:=painted.get_cell_source_id(at)
				if source in [4,5]:layout.props.append({"at":[at.x,at.y],"size":[1,1],"kind":"crate" if source==4 else "stone","model":""})
				elif source>=100 and source<164:
					var model:String=RoomTerrainCatalog.MODELS[int((source-100)/4)]
					var size:Vector2i=RoomTerrainCatalog.SIZES[(source-100)%4]
					var entry:Dictionary={"at":[at.x,at.y],"size":[size.x,size.y],"kind":"crate" if model=="crate_iron" else "stone","model":model}
					if model in RoomLayout.DECOR:layout.decor.append(entry)
					else:layout.props.append(entry)
				elif source>=200 and source<204:
					var size:Vector2i=RoomTerrainCatalog.SIZES[source-200]
					for y in size.y:
						for x in size.x:layout.water.append([at.x+x,at.y+y])
	return layout

func _load_room_props(data:Dictionary,layout:Dictionary,start:int=0,stop:int=-1)->void:
	var broken: Array = data.get("delta",{}).get("broken",[])
	var entries:Array=layout.get("props",[])
	for index in range(start,entries.size() if stop<0 else mini(stop,entries.size())):
		var entry:Dictionary=entries[index]
		var at:=Vector2i(entry.at[0],entry.at[1]);var size:=Vector2i(entry.size[0],entry.size[1])
		if str(entry.kind)=="crate" and broken.has(RoomGraph.key(at)):continue
		for y in size.y:
			for x in size.x:obstacles[at+Vector2i(x,y)]=str(entry.kind)
		var prop:=RoomProp.new();prop.prop_kind=str(entry.kind);prop.cell=at;prop.room=self;prop.model=str(entry.model);prop.footprint=size
		prop.asset_id=str(entry.get("asset_id",""))
		prop.hp=float(data.get("delta",{}).get("prop_hp",{}).get(RoomGraph.key(at),30))
		prop.position=RoomLayout.center(at)+Vector2(size-Vector2i.ONE)*18;props_root.add_child(prop)

func _load_room_water(layout:Dictionary,start:int=0,stop:int=-1)->void:
	var entries:Array=layout.get("water",[])
	for index in range(start,entries.size() if stop<0 else mini(stop,entries.size())):
		var pair:Array=entries[index]
		var at:=Vector2i(pair[0],pair[1]);deep_water[at]=true
		if scene_water_collision_override or not scene_water_polygons.is_empty():continue
		var body:=StaticBody2D.new();body.collision_layer=Layers.DEEP_WATER;body.collision_mask=0;body.position=RoomLayout.center(at)
		var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2.ONE*36;collider.shape=shape;body.add_child(collider);water_root.add_child(body)
	if stop>=0 and stop<entries.size():return
	for polygon:PackedVector2Array in scene_water_polygons:
		var body:=StaticBody2D.new();body.collision_layer=Layers.DEEP_WATER;body.collision_mask=0
		var collider:=CollisionPolygon2D.new();collider.polygon=polygon;body.add_child(collider);water_root.add_child(body)
	for entry in layout.get("ground",[]):ground_materials[Vector2i(entry.at[0],entry.at[1])]=str(entry.kind)

func _load_room_decor(layout:Dictionary,start:int=0,stop:int=-1)->void:
	var entries:Array=layout.get("decor",[])
	for index in range(start,entries.size() if stop<0 else mini(stop,entries.size())):
		var entry:Dictionary=entries[index]
		if not bool(layout.get("service_layout",false)) and str(layout.get("template_id","")) in ["shop_garden","shop_stone","tavern_veranda","tavern_waterfront"] and str(entry.get("asset_id","")).begins_with("terrain:service_"):continue
		var size:=Vector2i(entry.get("size",[1,1])[0],entry.get("size",[1,1])[1])
		var at:=Vector2i(entry.at[0],entry.at[1])
		if str(entry.get("asset_id","")).begins_with("supplied:"):
			var supplied := SuppliedMapProp.new()
			supplied.asset_id = str(entry.asset_id);supplied.footprint = size
			supplied.position = Vector2(at)*36+Vector2(size.x*18,size.y*36)
			decor_root.add_child(supplied)
			continue
		if str(entry.get("asset_id","")).begins_with("light:"):
			var lamp:=RoomLightProp.new();lamp.footprint=size
			lamp.configure({"kind":str(entry.asset_id).split(":")[1]})
			lamp.position=RoomLayout.center(at)+Vector2(size-Vector2i.ONE)*18;decor_root.add_child(lamp)
			continue
		var sprite:=Sprite2D.new();var path:=str(entry.get("path","res://assets/room_mode/terrain_v3/editor/%s_%dx%d.png"%[entry.model,size.x,size.y]))
		if not ResourceLoader.exists(path):continue
		sprite.texture=load(path);sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		# Same physical width and bottom anchor as the editor's art rectangle.
		sprite.scale=Vector2.ONE*(size.x*36.0/maxf(1,sprite.texture.get_width()))
		sprite.offset=Vector2(0,-sprite.texture.get_height()*.5)
		sprite.position=Vector2(at)*36+Vector2(size.x*18,size.y*36)
		if str(entry.get("asset_id","")).begins_with("scene:"):
			var scene_entry:=RoomEditorCatalog.get_entry(str(entry.asset_id))
			sprite.scale=Vector2.ONE*float(scene_entry.render_width_px)/sprite.texture.get_width()
			var config:Dictionary=entry.get("config",{});var offset:Array=config.get("offset_px",[0,0])
			sprite.position=RoomLayout.center(at)+Vector2(float(offset[0]),float(offset[1]))
		decor_root.add_child(sprite)

func _load_room_entities(layout:Dictionary,start:int=0,stop:int=-1)->void:
	var entries:Array=layout.get("entities",[])
	for index in range(start,entries.size() if stop<0 else mini(stop,entries.size())):
		var entry:Dictionary=entries[index]
		var asset_id:=str(entry.get("asset_id",""))
		var scene_asset:=RoomEditorCatalog.get_entry(asset_id) if asset_id.begins_with("scene:") else {}
		if not asset_id.begins_with("light:") and str(scene_asset.get("collision",""))!="light":continue
		var lamp:=RoomLightProp.new()
		if not scene_asset.is_empty():
			lamp.kind=str(scene_asset.model);lamp.scene_texture=RoomEditorCatalog.texture(asset_id);lamp.scene_width=float(scene_asset.render_width_px)
		else:
			var parts:=asset_id.split(":");lamp.kind=parts[1]
			var pair:=parts[2].split("x");lamp.footprint=Vector2i(int(pair[0]),int(pair[1]))
		var config:Dictionary=entry.get("config",{}).duplicate();config.kind=lamp.kind;lamp.configure(config)
		lamp.position=RoomLayout.center(Vector2i(entry.at[0],entry.at[1]))+Vector2(lamp.footprint-Vector2i.ONE)*18
		var offset:Array=config.get("offset_px",[0,0]);lamp.position+=Vector2(float(offset[0]),float(offset[1]))
		decor_root.add_child(lamp)

func _load_room_finish(data:Dictionary,layout:Dictionary)->void:
	_load_room_finish_begin(data)
	load_scene_objects(layout.get("scene_objects",[]),"")
	_load_room_finish_end()

func _load_room_finish_begin(data:Dictionary)->void:
	door_directions.clear()
	for id in data.get("doors",[]): door_directions.append(RoomGraph.cell(str(id))-RoomGraph.cell(str(data.get("id","0,0"))))
	doors_open = bool(data.get("cleared",false))
	door_phase=1.0 if doors_open else 0.0
	_build_service_decor(str(data.get("kind","normal")))

func _load_room_finish_end()->void:
	_refresh_navigation()
	queue_redraw()

	for child in water_root.get_children():
		if child is RoomWater:child.queue_redraw()

func _process(dt:float)->void:
	if Engine.is_editor_hint():return
	var units:Array=[]
	# Players, enemies, bosses and all friendly bodies share this registry.
	# Apply the same painted-pixel occlusion rule to every living room unit.
	for unit in get_tree().get_nodes_in_group("room_units"):
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.get("room")!=self or unit.get("hp")<=0:continue
		if unit is Node2D and unit.is_visible_in_tree():units.append(unit)
	scene_occlusion.update_for_units(units,dt)
	var target:=1.0 if doors_open else 0.0
	if not is_equal_approx(door_phase,target):
		door_phase=move_toward(door_phase,target,dt/(0.10 if ComicMotion.reduced() else 0.32));queue_redraw()

func _build_service_decor(kind:String)->void:
	var authored:Dictionary=record.get("terrain_layout",{})
	if bool(authored.get("service_layout",false)):
		for entry in authored.get("service_props",[]):
			var asset:=str(entry.get("asset",""))
			if asset not in ["goods","barrels","planter","notice","lantern","shrub","brazier","table","building_shop","building_tavern"]:continue
			var point:Array=entry.get("position_px",[])
			if point.size()!=2:continue
			var prop:=RoomServiceProp.new()
			var texture:Texture2D=RoomEditorCatalog.texture(str(entry.get("asset_id",""))) if str(entry.get("asset_id","")).begins_with("scene:") else null
			var texture_path:=str(entry.get("texture_path",""))
			if texture==null and ResourceLoader.exists(texture_path):texture=load(texture_path)
			var polygon:=RoomSceneGeometry.polygon(entry.get("collision_polygon_px",[]))
			var disabled:=bool(entry.get("collision_disabled",false))
			prop.setup(asset,Vector2(float(point[0]),float(point[1])),float(entry.width_px),float(entry.depth_px),texture,polygon,disabled)
			prop.name=str(entry.get("id","ServiceProp"));decor_root.add_child(prop)
			if polygon.size()<3 and not disabled:service_footprints.append(prop.footprint)
			if str(entry.get("role",""))=="building" and asset=="building_"+kind:
				service_building=prop
		return
	var layout:Array=[]
	if kind=="shop":
		layout=[["goods",Vector2(110,146),58,24],["goods",Vector2(538,146),58,24],["planter",Vector2(162,308),54,20],["planter",Vector2(510,308),54,20],["notice",Vector2(496,88),46,14],["lantern",Vector2(288,82),44,10],["shrub",Vector2(92,310),38,18],["shrub",Vector2(592,84),38,18]]
	elif kind=="tavern":
		layout=[["barrels",Vector2(552,276),52,22],["brazier",Vector2(568,90),44,16],["table",Vector2(156,138),64,32],["table",Vector2(162,290),64,32],["lantern",Vector2(96,82),44,10],["lantern",Vector2(402,310),44,10],["shrub",Vector2(94,310),38,18],["barrels",Vector2(576,150),48,22]]
	for entry in layout:
		var prop:=RoomServiceProp.new();prop.setup(str(entry[0]),entry[1],float(entry[2]),float(entry[3]))
		decor_root.add_child(prop);service_footprints.append(prop.footprint)
	if kind in ["shop","tavern"]:
		service_building=RoomServiceProp.new()
		service_building.setup("building_"+kind,service_anchor(),180 if kind=="shop" else 204,66 if kind=="shop" else 76)
		service_building.name="ServiceBuilding";decor_root.add_child(service_building)
		service_footprints.append(service_building.footprint)
func _refresh_navigation()->void:
	scene_navigation.clear()
	var left:=floori(room_rect.position.x/36)
	var right:=ceili(room_rect.end.x/36)
	var top:=floori(room_rect.position.y/36)
	var bottom:=ceili(room_rect.end.y/36)
	navigation.region=Rect2i(left,top,right-left,bottom-top);navigation.update()
	large_navigation.region=Rect2i(navigation.region.position*2,navigation.region.size*2);large_navigation.update()
	flying_navigation.region=navigation.region;flying_navigation.update()
	for y in range(navigation.region.position.y,navigation.region.end.y):
		for x in range(navigation.region.position.x,navigation.region.end.x):
			var at:=Vector2i(x,y)
			var blocked:=obstacles.has(at) or not room_rect.grow(-12).has_point(RoomLayout.center(at))
			for footprint in service_footprints:
				if footprint.grow(10).has_point(RoomLayout.center(at)):blocked=true;break
			for polygon:PackedVector2Array in scene_polygons.values():
				if RoomSceneGeometry.circle_overlaps(RoomLayout.center(at),12,polygon):blocked=true;break
			navigation.set_point_solid(at,blocked)
			flying_navigation.set_point_solid(at,blocked)
			if not scene_water_collision_override and scene_water_polygons.is_empty():
				if deep_water.has(at):navigation.set_point_solid(at,true)
			else:
				for polygon:PackedVector2Array in scene_water_polygons:
					if RoomSceneGeometry.circle_overlaps(RoomLayout.center(at),12,polygon):navigation.set_point_solid(at,true);break
	_refresh_large_navigation()

func service_material(at:Vector2i)->String:
	if record.get("terrain_layout",{}).has("template_id"):return str(ground_materials.get(at,record.terrain_layout.get("base_ground","grass")))
	if str(record.get("kind","normal")) not in ["shop","tavern"]:
		return str(record.get("terrain_layout",{}).get("base_ground","grass"))
	var painted:=get_node_or_null("FloorTiles") as TileMapLayer
	if painted!=null:
		var source:=painted.get_cell_source_id(at)
		if source>=300 and source<304:return ["grass","mud","stone","wood"][source-300]
	var kind:=str(record.get("kind","normal"))
	if kind=="shop":return "cobble" if at.x in [8,9,10] or at.y in [4,5,6] else "garden"
	if kind=="tavern":return "carpet" if at.x in [8,9,10] and at.y in [3,4,5,6,7,8] else "wood"
	return str(ground_materials.get(at,""))

func water_surface_at(at:Vector2)->bool:
	if scene_water_collision_override or not scene_water_polygons.is_empty():
		for polygon:PackedVector2Array in scene_water_polygons:
			if Geometry2D.is_point_in_polygon(at,polygon):return true
		return false
	return deep_water.has(world_to_cell(at))

func break_prop(at: Vector2i) -> void:
	if not record.delta.has("broken"): record.delta.broken = []
	var size:=Vector2i.ONE
	for prop in props_root.get_children():
		if prop is RoomProp and prop.cell==at:size=prop.footprint;break
	for y in size.y:
		for x in size.x:
			var cell:=at+Vector2i(x,y);obstacles.erase(cell);navigation.set_point_solid(cell,false);flying_navigation.set_point_solid(cell,false)
			record.delta.broken.append(RoomGraph.key(cell))
	scene_navigation.clear()
	_refresh_large_navigation()

func _refresh_large_navigation()->void:
	for y in range(large_navigation.region.position.y,large_navigation.region.end.y):
		for x in range(large_navigation.region.position.x,large_navigation.region.end.x):
			var at:=Vector2i(x,y);large_navigation.set_point_solid(at,not body_clear((Vector2(at)+Vector2.ONE*.5)*18,26))

func path_direction(from:Vector2,to:Vector2,radius:=12.0,flying:=false)->Vector2:
	if from.distance_to(to)<3:return Vector2.ZERO
	if segment_clear(from,to,radius,flying):return (to-from).normalized()
	if not scene_polygons.is_empty() or not scene_water_polygons.is_empty():return scene_navigation.direction(self,from,to,radius,flying)
	var grid:=flying_navigation if flying else (large_navigation if radius>18 else navigation)
	var start := Vector2i((from/grid.cell_size).floor()); var goal := Vector2i((to/grid.cell_size).floor())
	if not grid.is_in_boundsv(start):return Vector2.ZERO
	if grid.is_point_solid(start):
		# A clear body can occupy the edge of a cell whose center is blocked.
		# Recover to a reachable grid center instead of nearest_clear(from),
		# which returns the same point and leaves the unit permanently still.
		var best:=INF
		var recovery:=from
		for y in range(start.y-3,start.y+4):
			for x in range(start.x-3,start.x+4):
				var candidate:=Vector2i(x,y)
				if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate):continue
				var center:=grid.get_point_position(candidate)
				if not segment_clear(from,center,radius,flying):continue
				var score:=from.distance_squared_to(center)+center.distance_to(to)
				if score<best:best=score;recovery=center
		return (recovery-from).normalized()
	if not grid.is_in_boundsv(goal) or grid.is_point_solid(goal):goal=Vector2i((nearest_clear(to,radius,flying)/grid.cell_size).floor())
	var path := grid.get_point_path(start,goal,true)
	if path.size()<2:return Vector2.ZERO
	# Skip only waypoints whose entire body corridor is clear; never cut a corner.
	for index in range(mini(3,path.size()-1),0,-1):
		if segment_clear(from,path[index],radius,flying):return (path[index]-from).normalized()
	var center:Vector2=path[0]
	return (center-from).normalized() if segment_clear(from,center,radius,flying) else Vector2.ZERO

func segment_clear(from:Vector2,to:Vector2,radius:=12.0,flying:=false)->bool:
	# Exact capsule/edge checks prevent sampled movement from missing a narrow
	# crossing or a grazing shoreline contact between the 8px samples.
	for polygon:PackedVector2Array in scene_polygons.values():
		if RoomSceneGeometry.swept_circle_overlaps(from,to,radius,polygon):return false
	if not flying:
		for polygon:PackedVector2Array in scene_water_polygons:
			if RoomSceneGeometry.swept_circle_overlaps(from,to,radius,polygon):return false
	var steps:=maxi(1,ceili(from.distance_to(to)/8.0))
	for i in range(1,steps+1):
		if not body_clear(from.lerp(to,float(i)/steps),radius,flying,false):return false
	return true

func firing_position(from:Vector2,target:Vector2,preferred:=190.0,radius:=12.0,flying:=false)->Vector2:
	var distance:=from.distance_to(target)
	if distance>=112 and distance<=preferred+30 and projectile_clear(from,target):return from
	var best:=INF
	var result:=from
	var outward:=(from-target).normalized()
	if outward==Vector2.ZERO:outward=Vector2.DOWN
	# Bounded candidates; verify the same body-sized route the actor will follow.
	for reach in [preferred,preferred*0.72,preferred*1.35]:
		for turn in [0.0,PI/4,-PI/4,PI/2,-PI/2,PI*0.75,-PI*0.75,PI]:
			var point:=RoomLayout.center(world_to_cell(target+outward.rotated(turn)*reach))
			if not body_clear(point,radius,flying) or not projectile_clear(point,target) or point.distance_to(target)>300:continue
			var score:=from.distance_squared_to(point)+absf(point.distance_to(target)-preferred)*100
			if score>=best:continue
			if from.distance_to(point)>3 and path_direction(from,point,radius,flying).is_zero_approx():continue
			best=score;result=point
	if result==from and not projectile_clear(from,target):
		var approach:=nearest_clear(target,radius,flying)
		if not path_direction(from,approach,radius,flying).is_zero_approx():return approach
	return result

func crowd_detour(at:Vector2,direction:Vector2,radius:float,unit:CharacterBody2D,flying:=false)->Vector2:
	if direction.is_zero_approx():return Vector2.ZERO
	var side:=1.0 if unit.get_instance_id()%2==0 else -1.0
	for angle in [PI/4,PI/2,PI*0.75,-PI/4,-PI/2,-PI*0.75]:
		var candidate:=direction.rotated(angle*side)
		var point:=at+candidate*maxf(32,radius*2.5)
		if segment_clear(at,point,radius,flying) and unit_position_clear(point,radius,unit):return candidate
	return Vector2.ZERO

func body_clear(at:Vector2,radius:=12.0,flying:=false,check_scene:=true)->bool:
	if not room_rect.grow(-radius).has_point(at): return false
	for footprint in service_footprints:
		if footprint.grow(radius).has_point(at):return false
	if check_scene:
		for polygon:PackedVector2Array in scene_polygons.values():
			if RoomSceneGeometry.circle_overlaps(at,radius,polygon):return false
		if not flying:
			for polygon:PackedVector2Array in scene_water_polygons:
				if RoomSceneGeometry.circle_overlaps(at,radius,polygon):return false
	# Circle/rectangle overlap also catches blocks fully inside a larger boss body.
	var low:=world_to_cell(at-Vector2.ONE*radius)
	var high:=world_to_cell(at+Vector2.ONE*radius)
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			if not obstacles.has(Vector2i(x,y)) and (flying or scene_water_collision_override or not scene_water_polygons.is_empty() or not deep_water.has(Vector2i(x,y))):continue
			var nearest:=Vector2(clampf(at.x,x*36,(x+1)*36),clampf(at.y,y*36,(y+1)*36))
			if nearest.distance_squared_to(at)<=radius*radius:return false
	return true

func sight(from: Vector2,to: Vector2,ghost_mode := false) -> bool:
	if not room_rect.has_point(to): return false
	if ghost_mode: return true
	for polygon:PackedVector2Array in scene_polygons.values():
		if RoomSceneGeometry.segment_intersects(from,to,polygon):return false
	var steps := maxi(1,ceili(from.distance_to(to)/6.0))
	for i in range(1,steps+1):
		var probe:=from.lerp(to,float(i)/steps)
		if obstacles.has(world_to_cell(probe)):return false
		for footprint in service_footprints:
			if footprint.has_point(probe):return false
	return true

func projectile_clear(from:Vector2,to:Vector2)->bool:
	if not sight(from,to):return false
	# RoomProjectile's physical collider has a 5px radius. A clear center line
	# can still graze scenery and fizzle before reaching its target. Water does
	# not block projectiles, so check only WORLD obstacles here.
	for polygon:PackedVector2Array in scene_polygons.values():
		if RoomSceneGeometry.swept_circle_overlaps(from,to,5.0,polygon):return false
	for footprint:Rect2 in service_footprints:
		if _projectile_hits_rect(from,to,footprint):return false
	for cell:Vector2i in obstacles:
		if _projectile_hits_rect(from,to,Rect2(Vector2(cell)*36.0,Vector2.ONE*36.0)):return false
	return true

func _projectile_hits_rect(from:Vector2,to:Vector2,rect:Rect2)->bool:
	var low:=from.min(to)-Vector2.ONE*5.0
	var high:=from.max(to)+Vector2.ONE*5.0
	if not Rect2(low,high-low).intersects(rect,true):return false
	var a:=rect.position
	var b:=rect.end
	return RoomSceneGeometry.swept_circle_overlaps(from,to,5.0,PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]))

func spawn_point(rng: RandomNumberGenerator, avoid: Vector2, radius := 14.0) -> Vector2:
	var markers:Array=record.get("terrain_layout",{}).get("markers",[])
	var candidates:Array[Vector2]=[]
	var scene_geometry:=not scene_polygons.is_empty() or not scene_water_polygons.is_empty()
	for marker in markers:
		if str(marker.get("asset_id",""))!="spawn" and str(marker.get("kind",""))!="spawn":continue
		var point:=RoomLayout.center(Vector2i(marker.at[0],marker.at[1]))
		if body_clear(point,radius) and point.distance_to(avoid)>120 and (not scene_geometry or scene_navigation.spawn_reachable(self,point,radius,false)):candidates.append(point)
	if not candidates.is_empty():return candidates[rng.randi_range(0,candidates.size()-1)]
	for i in 150:
		var at := RoomLayout.center(Vector2i(rng.randi_range(navigation.region.position.x+1,navigation.region.end.x-2),rng.randi_range(navigation.region.position.y+1,navigation.region.end.y-2)))
		if body_clear(at,radius) and at.distance_to(avoid)>120 and (not scene_geometry or scene_navigation.spawn_reachable(self,at,radius,false)): return at
	if scene_geometry:
		var main_point:=scene_navigation.main_spawn_point(self,room_rect.get_center(),avoid,radius,false)
		if main_point!=Vector2.ZERO:return main_point
	return nearest_clear(room_rect.get_center(),radius)

func door_at(at: Vector2) -> Vector2i:
	if not doors_open or door_phase<0.99: return Vector2i.ZERO
	for direction in door_directions:
		var point := door_point(direction)
		if at.distance_to(point)<35: return direction
	return Vector2i.ZERO

func _draw() -> void:
	if illustration!=null and illustration.active():return
	var biome := str(record.get("biome","forest"))
	var index := ["forest","wetland","ruin"].find(biome)
	var floor_color := Color("29483c") if index == 0 else (Color("254a51") if index == 1 else Color("3c4548"))
	draw_rect(visual_frame(),Color("0b1820"))
	var painted:=get_node_or_null("FloorTiles") as TileMapLayer
	for y in range(floori(room_rect.position.y/36),ceili(room_rect.end.y/36)):
		for x in range(floori(room_rect.position.x/36),ceili(room_rect.end.x/36)):
			var material:=service_material(Vector2i(x,y))
			if material.is_empty() and painted!=null and painted.visible and painted.get_cell_source_id(Vector2i(x,y))>=0:continue
			var tile := Rect2(x*36,y*36,36,36).intersection(room_rect)
			if material.begins_with("supplied:"):
				var custom:=SuppliedMapAssets.texture(material)
				if custom!=null:draw_texture_rect(custom,tile,false)
			elif _service_floors.has(material):
				draw_texture_rect_region(_service_floors[material],tile,Rect2(posmod(x,2)*36,posmod(y,2)*36,36,36),Color(0.96,1.0,0.96))
			elif index>=0 and _floors.size()>index and _floors[index]!=null:
				var part:=Rect2(posmod(x,2)*36,posmod(y,2)*36,36,36)
				draw_texture_rect_region(_floors[index],tile,part,Color(0.94,1.0,0.96))
			else: draw_rect(tile,floor_color.lightened(float((x*7+y*11)%5)*0.015))
func _draw_shell(canvas:Node2D=null)->void:
	if canvas==null:canvas=self
	if shell_textures.is_empty():return
	var left:=room_rect.position.x;var right:=room_rect.end.x
	var middle:=room_rect.get_center()
	# Wall caps face the floor, and connected corners cover all four joints.
	for side in ["north","south"]:
		var direction:=Vector2i.UP if side=="north" else Vector2i.DOWN
		var ranges:Array=[Vector2(left+34,right-34)]
		# Cut only the passage. Wall stone must extend behind the sprite's jambs
		# because the frame includes transparent shoulders outside those jambs.
		if door_directions.has(direction):
			var gate:=port_position(direction)
			ranges=[Vector2(left+34,gate.x-24),Vector2(gate.x+24,right-34)]
		for interval in ranges:
			var x:float=interval.x
			while x<interval.y:
				var span:=minf(104,interval.y-x)
				canvas.draw_texture_rect_region(shell_textures[side],Rect2(x,room_rect.position.y-36 if side=="north" else room_rect.end.y,span,36),Rect2(2,0,span,36))
				x+=span
	for side in ["west","east"]:
		var direction:=Vector2i.LEFT if side=="west" else Vector2i.RIGHT
		var ranges:Array=[Vector2(room_rect.position.y+34,room_rect.end.y-34)]
		if door_directions.has(direction):
			var gate:=port_position(direction)
			ranges=[Vector2(room_rect.position.y+34,gate.y-22),Vector2(gate.y+22,room_rect.end.y-34)]
		for interval in ranges:
			var y:float=interval.x
			while y<interval.y:
				var span:=minf(104,interval.y-y)
				canvas.draw_texture_rect_region(shell_textures[side],Rect2(left-36 if side=="west" else right,y,36,span),Rect2(0,2,36,span))
				y+=span
	for corner in [["nw",Vector2(left-36,room_rect.position.y-36)],["ne",Vector2(right-36,room_rect.position.y-36)],["sw",Vector2(left-36,room_rect.end.y-36)],["se",Vector2(right-36,room_rect.end.y-36)]]:
		canvas.draw_texture_rect(shell_textures[corner[0]],Rect2(corner[1],Vector2(72,72)),false)
	for direction in door_directions:
		var row:=[Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT].find(direction)
		var frame:=clampi(roundi(door_phase*3),0,3)
		if _door_motion!=null:
			# Side gates use only the upright jamb and moving grille. Crop the
			# attached transverse wall out of the atlas rather than squeezing it.
			var source:=Rect2(frame*128,row*96,128,96)
			if direction==Vector2i.DOWN:source.size.y=64
			if direction==Vector2i.LEFT:source=Rect2(frame*128+33,row*96,36,96)
			elif direction==Vector2i.RIGHT:
				# Mirror the west opening so its jamb faces inward on the east wall.
				canvas.draw_set_transform(Vector2(2*right+36,0),0,Vector2(-1,1))
				canvas.draw_texture_rect_region(_door_motion,door_rect(Vector2i.RIGHT),Rect2(frame*128+33,192,36,96))
				canvas.draw_set_transform(Vector2.ZERO)
				continue
			canvas.draw_texture_rect_region(_door_motion,door_rect(direction),source)

func bounds() -> Rect2: return room_rect
func kill_floor_y() -> float: return 10000.0
func world_to_cell(at: Vector2) -> Vector2i: return Vector2i(floorf(at.x/36),floorf(at.y/36))
func cell_to_world(at: Vector2i) -> Vector2: return RoomLayout.center(at)
func is_solid_cell(at: Vector2i) -> bool: return not navigation.region.has_point(at) or navigation.is_point_solid(at)
func is_one_way_cell(_at: Vector2i) -> bool: return false
func set_background(_index: int,_fade := 0.9) -> void: pass
func start_environment(_data: Dictionary) -> void: pass
func stop_environment() -> void: pass
func environment_snapshot() -> Dictionary: return {}

func clear_sight(from:Vector2,to:Vector2)->bool:return sight(from,to)

func nearest_clear(at:Vector2,radius:=12.0,flying:=false)->Vector2:
	if body_clear(at,radius,flying):return at
	var result:=room_rect.get_center();var best:=INF
	var grid:=large_navigation if radius>18 and not flying else navigation
	for y in range(grid.region.position.y,grid.region.end.y):
		for x in range(grid.region.position.x,grid.region.end.x):
			var point:Vector2=(Vector2(x,y)+Vector2.ONE*.5)*grid.cell_size
			var distance:=point.distance_squared_to(at)
			if distance<best and body_clear(point,radius,flying):best=distance;result=point
	return result
func register_unit_body(unit:CharacterBody2D,radius:float,flying:=false)->void:
	unit.collision_layer|=Layers.UNIT_BODY
	unit.collision_mask|=Layers.UNIT_BODY
	unit.add_to_group("room_units")
	tactics.invalidate_roster()
	if not unit.tree_exiting.is_connected(tactics.invalidate_roster):unit.tree_exiting.connect(tactics.invalidate_roster)
	unit.set_meta("unit_radius",radius)
	_settle_registered_body.call_deferred(weakref(unit),radius,flying)

func _settle_registered_body(reference:WeakRef,radius:float,flying:bool)->void:
	# An AoE may kill a newly spawned unit before the deferred settle executes.
	var unit:=reference.get_ref() as CharacterBody2D
	if is_instance_valid(unit):settle_unit_body(unit,radius,flying)

func unit_position_clear(at:Vector2,radius:float,ignore:Node=null)->bool:
	for other in get_tree().get_nodes_in_group("room_units"):
		if not is_instance_valid(other) or other==ignore or other.is_queued_for_deletion():continue
		if other.get("room")!=self or other.get("hp")<=0 or (other.collision_layer&Layers.UNIT_BODY)==0:continue
		var clearance:=radius+float(other.get_meta("unit_radius",12.0))+1.0
		if at.distance_squared_to(other.global_position)<clearance*clearance:return false
	return true

func settle_unit_body(unit:CharacterBody2D,radius:float,flying:=false)->void:
	if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.get("room")!=self or unit.get("hp")<=0:return
	if unit is EnemyBase and unit.training_target:return
	var at:=unit.global_position
	if body_clear(at,radius,flying) and unit_position_clear(at,radius,unit):return
	# Only correct overlap/spawn positions, without consuming any gameplay RNG.
	for ring in range(1,21):
		for direction in 16:
			var candidate:=at+Vector2.RIGHT.rotated(direction*TAU/16)*ring*12.0
			if body_clear(candidate,radius,flying) and unit_position_clear(candidate,radius,unit):
				unit.global_position=candidate;unit.velocity=Vector2.ZERO;return

func ensure_clear_actors()->void:
	if Engine.is_editor_hint():return
	for group in ["room_player","enemies","allies"]:
		for unit in get_tree().get_nodes_in_group(group):
			if not unit is CharacterBody2D or unit.is_queued_for_deletion():continue
			if unit is EnemyBase and unit.training_target:continue
			if unit.get("room")!=self:continue
			var radius:float=26.0 if unit is RoomBoss else (float(unit.body_radius()) if unit.has_method("body_radius") else 12.0)
			var flying:bool=unit.is_flying() if unit.has_method("is_flying") else false
			if not body_clear(unit.global_position,radius,flying):
				unit.global_position=nearest_clear(unit.global_position,radius,flying);unit.velocity=Vector2.ZERO
			settle_unit_body(unit,float(unit.get_meta("unit_radius",radius)),flying)

func load_scene_objects(objects:Array,base_path:String,start:int=0,stop:int=-1)->void:
	if start==0:
		for root in [props_root,decor_root]:
			for child in root.get_children():
				if child.has_meta("scene_object_id"):
					root.remove_child(child);child.queue_free()
		scene_objects=objects.duplicate(true);scene_polygons.clear();scene_occlusion.clear()
	var broken:Array=record.get("delta",{}).get("scene_broken",[])
	for index in range(start,scene_objects.size() if stop<0 else mini(stop,scene_objects.size())):
		var item:Dictionary=scene_objects[index]
		var id:=str(item.get("id",""));var kind:=str(item.get("kind","decor"))
		if id.is_empty() or (kind=="crate" and broken.has(id)):continue
		var pair:Array=item.get("position_px",[0,0]);var point:=Vector2(float(pair[0]),float(pair[1]))
		var polygon:=RoomSceneGeometry.polygon(item.get("collision_polygon_px",[]))
		if polygon.size()>=3:scene_polygons[id]=RoomSceneGeometry.polygon(item.collision_polygon_px,point)
		var path:=str(item.get("texture",""))
		if not path.begins_with("res://"):path=base_path+path
		var texture:Texture2D=load(path) if ResourceLoader.exists(path) else null
		var width:=float(item.get("render_width_px",36))
		var node:Node2D
		var sprite:Sprite2D
		if kind in ["stone","crate"]:
			var prop:=RoomProp.new();prop.room=self;prop.prop_kind=kind;prop.scene_object_id=id
			prop.scene_texture=texture;prop.scene_width=width;prop.collision_polygon=polygon
			prop.hp=float(record.get("delta",{}).get("scene_prop_hp",{}).get(id,30))
			prop.position=point;prop.set_meta("scene_object_id",id);props_root.add_child(prop)
			node=prop;sprite=prop.art
		else:
			if kind=="light":
				var lamp:=RoomLightProp.new();lamp.scene_texture=texture;lamp.scene_width=width;lamp.scene_bottom_anchor=true
				lamp.configure(item.get("light",{"kind":"lamp"}));node=lamp
			else:node=Node2D.new()
			node.position=point;node.set_meta("scene_object_id",id);decor_root.add_child(node)
			if node is RoomLightProp:sprite=node.art
			else:
				sprite=Sprite2D.new();sprite.texture=texture;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				if texture!=null:sprite.scale=Vector2.ONE*width/texture.get_width();sprite.position.y=-texture.get_height()*sprite.scale.y*.5
				node.add_child(sprite)
			if polygon.size()>=3:
				var body:=StaticBody2D.new();body.collision_layer=Layers.WORLD;body.collision_mask=0
				var bounds:=Rect2(polygon[0],Vector2.ZERO)
				for vertex in polygon:bounds=bounds.expand(vertex)
				var rectangular:=polygon.size()==4
				for vertex in polygon:
					if not (is_equal_approx(vertex.x,bounds.position.x) or is_equal_approx(vertex.x,bounds.end.x)) or not (is_equal_approx(vertex.y,bounds.position.y) or is_equal_approx(vertex.y,bounds.end.y)):rectangular=false
				if rectangular:
					var shape:=RectangleShape2D.new();shape.size=bounds.size
					var collider:=CollisionShape2D.new();collider.shape=shape;collider.position=bounds.get_center();body.add_child(collider)
				else:
					var collider:=CollisionPolygon2D.new();collider.polygon=polygon;body.add_child(collider)
				node.add_child(body)
		if sprite!=null:scene_occlusion.register_sprite(sprite,node.global_position.y)
	if stop>=0 and stop<scene_objects.size():return
	for node in decor_root.get_children():
		if not node is RoomServiceProp:continue
		var service:RoomServiceProp=node
		if service.collision_polygon.size()<3:continue
		var global_polygon:=PackedVector2Array()
		for point in service.collision_polygon:global_polygon.append(service.position+point)
		scene_polygons["service:"+service.name]=global_polygon
		if is_instance_valid(service.art):scene_occlusion.register_sprite(service.art,service.global_position.y)
	_refresh_navigation()

func break_scene_prop(id:String)->void:
	if not record.has("delta"):record.delta={}
	if not record.delta.has("scene_broken"):record.delta.scene_broken=[]
	if not record.delta.scene_broken.has(id):record.delta.scene_broken.append(id)
	scene_polygons.erase(id)
	_refresh_navigation()
