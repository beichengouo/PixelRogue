class_name WeatherSurfaceArt
extends RefCounted
# Ninja Adventure CC0: verified 8x8 strips (3 rain, 3 contact, 7 snow).
# Whole-sheet dimensions are intentionally explicit; Cloud/Fog are single images.
const QUALITY_WEATHER_DIR := "res://assets/quality_20261011/weather/"
const PARTICLE_FRAMES := {"Rain":3,"RainOnFloor":3,"Snow":7}
static var _particle_frames:Dictionary={}
static func particle_frames(kind:String)->Array[AtlasTexture]:
	if _particle_frames.has(kind):return _particle_frames[kind]
	var frames:Array[AtlasTexture]=[]
	if not PARTICLE_FRAMES.has(kind):return frames
	var atlas:=load(QUALITY_WEATHER_DIR+kind+".png") as Texture2D
	var count:int=PARTICLE_FRAMES[kind]
	if atlas==null or atlas.get_size()!=Vector2(count*8,8):return frames
	for index in count:
		var frame:=AtlasTexture.new()
		frame.atlas=atlas
		frame.region=Rect2(index*8,0,8,8)
		frame.filter_clip=true
		frames.append(frame)
	_particle_frames[kind]=frames
	return frames
static func make(ground:=false)->ShaderMaterial:
	var value:=ShaderMaterial.new()
	value.shader=load("res://src/room_mode/weather_surface.gdshader")
	value.set_shader_parameter("snow_sprite",load("res://assets/room_mode/terrain_v3/snow_cover.png"))
	value.set_shader_parameter("ground_plane",ground)
	return value
static func apply(node:CanvasItem,snow:float,wet:float,ground:=false)->void:
	if node.material==null:node.material=make(ground)
	if node.material is ShaderMaterial and node.material.shader.resource_path.ends_with("weather_surface.gdshader"):
		node.material.set_shader_parameter("snow_amount",snow if RoomEnvironmentConfig.SNOW_ACCUMULATION_ENABLED else 0.0)
		node.material.set_shader_parameter("wet_amount",wet)
