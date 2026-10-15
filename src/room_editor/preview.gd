class_name RoomTemplatePreview
extends SubViewportContainer
## Uses the actual RoomLevel scene without RoomMain, combat actors or game flow.
var viewport: SubViewport
var level: RoomLevel
var camera: Camera2D
var document: Dictionary = {}
var light_field := RoomLightField.new()
var world_clock := RoomWorldClock.new()
var environment_material: ShaderMaterial
var environment_shade: ColorRect
var fog_density := 0.0
var _environment_clock := 0.0
var visible_layers: Dictionary = {}
var guides: GuideOverlay

class GuideOverlay extends Node2D:
	var data: Dictionary = {}
	var layers: Dictionary = {}
	func _draw() -> void:
		if data.is_empty():return
		if layers.get("collision",true):
			var bounds := RoomEditorCollision.bounds(data)
			draw_rect(bounds,Color(1,0.38,0.2,0.9),false,3.0)
			for target in RoomEditorCollision.targets(data):
				if str(target.key)=="room_bounds":continue
				var polygon := RoomEditorCollision.shape(data,str(target.key))
				if polygon.size()<2:continue
				var origin := RoomEditorCollision.origin(data,str(target.key))
				var color := Color(0.24,0.57,1.0,0.95) if str(target.key).begins_with("water:") else Color(0.96,0.72,0.18,0.9)
				for i in polygon.size():
					var a := origin+Vector2(float(polygon[i][0]),float(polygon[i][1]))
					var b := origin+Vector2(float(polygon[(i+1)%polygon.size()][0]),float(polygon[(i+1)%polygon.size()][1]))
					draw_line(a,b,color,2.5)
		if layers.get("spawns",true):
			for marker in data.layers.markers:
				if str(marker.asset_id)!="spawn" and not str(marker.asset_id).begins_with("camp:"):continue
				var center := (Vector2(marker.at[0],marker.at[1])+Vector2.ONE*0.5)*36
				draw_circle(center,8,Color(1,0.75,0.2,0.95))
				draw_line(center-Vector2(12,0),center+Vector2(12,0),Color.BLACK,2)
				draw_line(center-Vector2(0,12),center+Vector2(0,12),Color.BLACK,2)
		if layers.get("doors",true):
			for port in data.ports:
				draw_rect(Rect2(Vector2(port.at[0],port.at[1])*36,Vector2.ONE*36),Color(0.2,1,0.75,0.95),false,3.0)

func _ready() -> void:
	stretch=true;custom_minimum_size=Vector2(828,540)
	viewport=SubViewport.new();viewport.size=Vector2i(828,540);viewport.world_2d=World2D.new();viewport.disable_3d=true
	add_child(viewport)
	level=load("res://src/room_mode/room_level.tscn").instantiate() as RoomLevel
	viewport.add_child(level)
	guides=GuideOverlay.new();viewport.add_child(guides)
	camera=Camera2D.new();viewport.add_child(camera)
	var composite := CanvasLayer.new();composite.layer=5;viewport.add_child(composite)
	environment_shade=ColorRect.new();environment_shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	environment_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	environment_material=ShaderMaterial.new()
	environment_material.shader=load("res://src/room_mode/room_environment_visual.gdshader")
	environment_material.set_shader_parameter("fog_texture",load(WeatherSurfaceArt.QUALITY_WEATHER_DIR+"Fog.png"))
	environment_material.set_shader_parameter("cloud_texture",load(WeatherSurfaceArt.QUALITY_WEATHER_DIR+"Clouds.png"))
	environment_material.set_shader_parameter("max_obscurity",RoomEnvironmentConfig.MAX_OBSCURITY)
	environment_shade.material=environment_material;composite.add_child(environment_shade)
	resized.connect(_fit)
	if not document.is_empty():set_document(document)

func set_document(data: Dictionary) -> void:
	document=data
	if level==null or not visible:return
	var layout := RoomTemplateCodec.to_layout(data)
	if layout.is_empty():return
	var kind := str(data.room_kinds[0])
	var boss := ""
	for tag in data.get("tags",[]):
		if str(tag).begins_with("boss:"):boss=str(tag).trim_prefix("boss:")
	level.load_room({"id":"0,0","seed":"1","kind":kind,"boss":boss,"biome":data.theme,"doors":["0,-1","1,0","0,1","-1,0"],"cleared":true,"rewarded":true,"delta":{},"terrain_layout":layout})
	# Chests normally belong to RoomMain. Render the same chest class with
	# processing disabled so inspecting a template cannot open it or roll loot.
	for entry in layout.get("entities",[]):
		if str(entry.get("asset_id",""))!="chest":continue
		var chest := RoomChest.new();chest.setup(level,null)
		chest.process_mode=Node.PROCESS_MODE_DISABLED
		chest.position=RoomLayout.center(Vector2i(entry.at[0],entry.at[1]));level.decor_root.add_child(chest)
	light_field.clear()
	guides.data=data;guides.layers=visible_layers;guides.queue_redraw()
	_apply_layers()
	_fit()
	_update_environment(1.0)

func set_layer_visible(layer_name: String, enabled: bool) -> void:
	visible_layers[layer_name]=enabled
	if guides!=null:guides.layers=visible_layers;guides.queue_redraw()
	_apply_layers()

func _apply_layers() -> void:
	if level==null:return
	for sprite in level.illustration.get_children():
		if not sprite is Sprite2D:continue
		var path := str(sprite.texture.resource_path).get_file()
		var layer_name := "background" if path=="background.png" else ("doors" if path.begins_with("door_") else "water_bridge")
		for plane in level.illustration.data.get("planes",[]):
			if str(plane.path)==path:layer_name=str(plane.get("layer",layer_name))
		sprite.visible=visible_layers.get(layer_name,true)
	level.shell_art.visible=visible_layers.get("background",true) and not level.illustration.active()
	level.props_root.visible=visible_layers.get("objects",true)
	level.water_root.visible=visible_layers.get("water_bridge",true)
	for child in level.decor_root.get_children():
		var layer_name:="buildings" if child is RoomServiceProp else "objects"
		for item in level.scene_objects:
			if str(item.id)==str(child.get_meta("scene_object_id","")):layer_name=str(item.get("layer",layer_name))
		child.visible=visible_layers.get(layer_name,true)

func set_environment(preset: int) -> void:
	world_clock.minutes=[720.0,1110.0,1380.0,720.0][clampi(preset,0,3)]
	fog_density=0.75 if preset==3 else 0.0
	_update_environment(1.0)

func _process(delta: float) -> void:
	if visible:
		_environment_clock+=delta
		_update_environment(delta)

func _update_environment(delta: float) -> void:
	if level==null or environment_material==null:return
	# The game's shader and descriptor registry run in this isolated viewport;
	# no player, GameState run or SaveService is required to inspect placed lights.
	light_field.refresh(level,delta)
	var lights := light_field.sources(level,world_clock,fog_density)
	var transform := viewport.get_canvas_transform()
	var scale_factor := maxf(absf(transform.get_scale().x),absf(transform.get_scale().y))
	environment_material.set_shader_parameter("fog_origin",transform.affine_inverse()*Vector2.ZERO)
	environment_material.set_shader_parameter("fog_world_scale",1.0/maxf(.001,scale_factor))
	environment_material.set_shader_parameter("weather_time",_environment_clock)
	var positions := PackedVector4Array();var colors := PackedVector4Array()
	positions.resize(RoomEnvironmentConfig.MAX_LIGHTS);colors.resize(RoomEnvironmentConfig.MAX_LIGHTS)
	for index in lights.size():
		var light := lights[index];var at: Vector2 = transform*light.position
		positions[index]=Vector4(at.x,at.y,float(light.radius)*scale_factor,float(light.strength))
		var color: Color = light.color
		colors[index]=Vector4(color.r,color.g,color.b,1.0 if bool(light.dispels_fog) else 0.0)
	environment_material.set_shader_parameter("lights",positions)
	environment_material.set_shader_parameter("light_colors",colors)
	environment_material.set_shader_parameter("light_count",lights.size())
	environment_material.set_shader_parameter("viewport_size",Vector2(viewport.size))
	environment_material.set_shader_parameter("darkness",world_clock.darkness())
	environment_material.set_shader_parameter("fog_density",smoothstep(0,1,fog_density))
	environment_shade.visible=world_clock.darkness()>0 or fog_density>0

func _exit_tree() -> void:
	light_field.clear()

func _fit() -> void:
	if camera==null or level==null:return
	var frame := level.visual_frame()
	var factor := minf(maxf(1,size.x)/frame.size.x,maxf(1,size.y)/frame.size.y)
	camera.zoom=Vector2.ONE*factor;camera.position=frame.get_center()
