class_name ForestUnitArt
extends RefCounted
## Goblins use compact pixel atlases; the original orc assets stay untouched.
const ROOT:="res://assets/forest_roster_v28/"
const KINDS:Array[StringName]=[&"goblin_scout",&"goblin_spearman",&"goblin_mage"]
static var _cache:Dictionary={}
static var _metadata:Dictionary={}
static func path(kind:StringName)->String:
	return ROOT+str(kind)+".png"
static func supports(kind:StringName)->bool:return kind in KINDS and ResourceLoader.exists(path(kind))
static func metadata(kind:StringName)->Dictionary:
	if _metadata.is_empty():
		var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"atlas_metadata.json"))
		if data is Dictionary:_metadata=data
	return _metadata.get(str(kind),{})
static func frames(kind:StringName)->SpriteFrames:
	if _cache.has(kind):return _cache[kind]
	var data:=metadata(kind);var texture:Texture2D=load(path(kind))
	var result:=SpriteFrames.new();result.remove_animation(&"default")
	var specs:Dictionary={&"idle":[0,[0,1,2,3],6.0,true],&"walk":[1,[0,1,2,3],8.0,true],&"windup":[2,[0,1,2,3],8.0,false],&"attack":[3,[0,1,2,3],16.0,false],&"hurt":[4,[0,1,2,3],16.0,false],&"death":[5,[0,1,2,3],8.0,false]}
	var cell:=Vector2(float(data.cell[0]),float(data.cell[1]))
	for action:StringName in specs:
		var spec:Array=specs[action];result.add_animation(action);result.set_animation_speed(action,float(spec[2]));result.set_animation_loop(action,bool(spec[3]))
		for column:int in spec[1]:
			var frame:=AtlasTexture.new();frame.atlas=texture;frame.region=Rect2(Vector2(column,int(spec[0]))*cell,cell);frame.filter_clip=true;result.add_frame(action,frame)
	result.add_animation(&"spawn");result.set_animation_speed(&"spawn",14);result.set_animation_loop(&"spawn",false)
	for index in [3,2,1,0]:result.add_frame(&"spawn",result.get_frame_texture(&"death",index))
	for index in 4:result.add_frame(&"spawn",result.get_frame_texture(&"idle",index))
	result.add_animation(&"charge");result.set_animation_speed(&"charge",16);result.set_animation_loop(&"charge",true)
	for index in [1,2,3]:result.add_frame(&"charge",result.get_frame_texture(&"attack",index))
	_cache[kind]=result;return result
static func align(sprite:AnimatedSprite2D,kind:StringName,body:Vector2)->void:
	var data:=metadata(kind);var cell:=Vector2(float(data.cell[0]),float(data.cell[1]));var foot:=Vector2(float(data.foot_anchor[0]),float(data.foot_anchor[1]))
	var scale:=body.y/maxf(1.0,float(data.core_height));sprite.scale=Vector2.ONE*scale
	sprite.position=Vector2(0,body.y*.5)-(foot-cell*.5)*scale
static func clear()->void:_cache.clear();_metadata.clear()
