class_name RevisedMonsterArt
extends RefCounted
const ROOT:="res://assets/combat_revision_v04/monsters/"
const TYPES:={&"flyer":"ghost",&"bomber":"ember"}
static var _cache:Dictionary={}
static func frames(kind:StringName)->SpriteFrames:
	if _cache.has(kind):return _cache[kind]
	var source:=load(ROOT+TYPES[kind]+".png") as Texture2D
	var result:=SpriteFrames.new();result.remove_animation(&"default")
	var specs:={&"idle":[0,6,true],&"walk":[1,8,true],&"fly":[1,8,true],&"windup":[2,5,false],&"attack":[3,8,false],&"hurt":[4,10,false],&"death":[5,6,false],&"spawn":[0,6,false]}
	for action in specs:
		var spec:Array=specs[action];result.add_animation(action);result.set_animation_speed(action,spec[1]);result.set_animation_loop(action,spec[2])
		for col in 4:
			var cell:=AtlasTexture.new();cell.atlas=source;cell.region=Rect2(col*128,int(spec[0])*128,128,128);cell.filter_clip=true;result.add_frame(action,cell)
	_cache[kind]=result;return result
static func align(sprite:AnimatedSprite2D,body:Vector2)->void:
	var ratio:=body.y/80.0;sprite.scale=Vector2.ONE*ratio;sprite.position=Vector2(0,body.y*.5-48*ratio)
