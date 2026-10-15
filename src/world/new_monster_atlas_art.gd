class_name NewMonsterAtlasArt
extends RefCounted
const ROOT:="res://assets/monsters_vnext/"
const KINDS:Array[StringName]=[&"moss_badger",&"bog_crab",&"ruin_sentinel",&"thorn_mantis",&"lantern_toad",&"dusk_acolyte"]
const CELL:=128.0
## Planted paw/body edge measured in each of the 24 authored source frames.
## Charge and spawn derive their anchors from the source texture region below.
const BADGER_FEET:=[114,114,114,114,114,114,114,114,114,114,114,114,112,114,114,114,114,114,114,114,114,114,114,114]
static var _cache:Dictionary={}
static var _metadata:Dictionary={}
static func metadata(id:StringName)->Dictionary:
	if id in [&"bell_snail",&"glimmer_spider"]:
		if not _metadata.has(str(id)):
			var parsed:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/content_v05/monsters/"+str(id)+"-metadata.json"));_metadata[str(id)]=parsed
		return _metadata[str(id)]
	if not _metadata.has("_base_loaded"):
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"atlas_metadata.json"))
		if parsed is Dictionary:_metadata.merge(parsed);_metadata["_base_loaded"]=true
	return _metadata.get(str(id),{"extents":[112,106]})
static func frames(id:StringName)->SpriteFrames:
	if _cache.has(id):return _cache[id]
	var source_root:="res://assets/content_v05/monsters/" if id in [&"bell_snail",&"glimmer_spider"] else ROOT
	var texture:=load(source_root+str(id)+".png") as Texture2D
	var result:=SpriteFrames.new();result.remove_animation(&"default")
	if texture==null or texture.get_size()!=Vector2(512,768):return result
	var specs:Dictionary={&"idle":[0,6.0,true],&"walk":[1,8.0,true],&"windup":[2,8.0,false],&"attack":[3,16.0,false],&"hurt":[4,16.0,false],&"death":[5,8.0,false]}
	for action in specs:
		result.add_animation(action);result.set_animation_speed(action,float(specs[action][1]));result.set_animation_loop(action,bool(specs[action][2]))
		for index in 4:
			var frame:=AtlasTexture.new();frame.atlas=texture;frame.region=Rect2(index*CELL,int(specs[action][0])*CELL,CELL,CELL);frame.filter_clip=true
			result.add_frame(action,frame)
	result.add_animation(&"spawn");result.set_animation_speed(&"spawn",14);result.set_animation_loop(&"spawn",false)
	for index in [3,2,1,0]:result.add_frame(&"spawn",result.get_frame_texture(&"death",index))
	for index in 4:result.add_frame(&"spawn",result.get_frame_texture(&"idle",index))
	result.add_animation(&"charge");result.set_animation_loop(&"charge",true);result.set_animation_speed(&"charge",16)
	for index in [1,2,3]:result.add_frame(&"charge",result.get_frame_texture(&"attack",index))
	_cache[id]=result;return result
static func align(sprite:AnimatedSprite2D,id:StringName,body:Vector2)->void:
	var extents:Array=metadata(id).get("extents",[112,106])
	var factor:=minf(38.0/maxf(1,float(extents[0])),32.0/maxf(1,float(extents[1])))
	sprite.scale=Vector2.ONE*factor
	var foot:=116.0
	if id==&"moss_badger" and sprite.sprite_frames.has_animation(sprite.animation):
		var texture:=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame) as AtlasTexture
		if texture!=null:
			var index:=int(texture.region.position.y/CELL)*4+int(texture.region.position.x/CELL)
			foot=float(BADGER_FEET[clampi(index,0,23)])
	sprite.position=Vector2(0,(body.y*.5 if id!=&"moss_badger" else 10.0)-(foot-CELL*.5)*factor)
