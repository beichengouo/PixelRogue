class_name RoomSceneWhole
extends RefCounted
## Trial whole-map animation. Static walls stay separate for weather and ordering.
const ROOT:="res://assets/room_whole_v45/"
var textures:Array[Texture2D]=[]
var sprite:Sprite2D
var age:=0.0
var fps:=6.0

static func definition(id:String)->Dictionary:
	var path:=ROOT+id+"/animation.json"
	if not FileAccess.file_exists(path):return {}
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary and int(parsed.get("version",0))==1 and bool(parsed.get("enabled",true)) else {}

static func texture_paths(id:String)->Array[String]:
	var result:Array[String]=[]
	var data:=definition(id)
	for name:Variant in data.get("frames",[]):result.append(ROOT+id+"/"+str(name))
	if data.has("walls"):result.append(ROOT+id+"/"+str(data.walls))
	return result

func configure(host:RoomSceneArtwork,id:String)->bool:
	var config:=definition(id)
	if config.get("canvas",[])!=host.data.get("canvas",[]):return false
	var paths:=texture_paths(id)
	if paths.size()!=9 or config.get("frame_size",[]).size()!=2:return false
	var size:=Vector2(float(config.frame_size[0]),float(config.frame_size[1]))
	var loaded:Array[Texture2D]=[]
	for path:String in paths:
		if not ResourceLoader.exists(path):return false
		var texture:=load(path) as Texture2D
		if texture==null or texture.get_size()!=size:return false
		loaded.append(texture)
	fps=float(config.get("fps",6.0))
	if not is_finite(fps) or fps<=0 or fps>24:return false
	for index in 8:textures.append(loaded[index])
	var rect:=host.frame_rect()
	sprite=host._sprite(paths[0],rect);sprite.name="WholeMapGround"
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	host.background_plane=sprite;host.background_planes.append(sprite);host.ground_planes.append(sprite)
	var walls:=host._sprite(paths[8],rect);walls.name="WholeMapWalls"
	walls.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;host.ground_planes.append(walls)
	host._configure_whole_lights(sprite,id);host._configure_whole_lights(walls,id)
	WeatherSurfaceArt.apply(sprite,0,0,true);WeatherSurfaceArt.apply(walls,0,0,false)
	walls.material.set_shader_parameter("ground_plane",false)
	return true

func update(delta:float,advance:bool,reduced:bool)->void:
	if not is_instance_valid(sprite):return
	if advance and not reduced:age+=delta
	sprite.texture=textures[0 if reduced else posmod(floori(age*fps),textures.size())]
