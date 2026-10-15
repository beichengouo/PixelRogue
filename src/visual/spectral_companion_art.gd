class_name SpectralCompanionArt
extends RefCounted
const VARIANTS:=["gate_guardian","parade_guardian","ghost_lantern"]
static var _cache:Dictionary={}
static func frames(variant:String)->SpriteFrames:
	if not variant in VARIANTS:return null
	if _cache.has(variant):return _cache[variant]
	var texture:Texture2D=load("res://assets/companions_v04/"+variant+".png")
	if texture==null:return null
	var result:=SpriteFrames.new();result.remove_animation(&"default")
	var actions:=[&"idle",&"walk",&"attack",&"hurt",&"death",&"spawn"]
	for row in actions.size():
		var action:StringName=actions[row];result.add_animation(action);result.set_animation_loop(action,action in [&"idle",&"walk"])
		result.set_animation_speed(action,4 if action==&"idle" else (10 if action==&"attack" else 8))
		for column in 4:
			var cell:=AtlasTexture.new();cell.atlas=texture;cell.region=Rect2(column*96,row*96,96,96);result.add_frame(action,cell)
	_cache[variant]=result;return result
static func align(sprite:AnimatedSprite2D)->void:
	# All 24 frames are packed to the same ground baseline; idle body is 32 world pixels.
	sprite.scale=Vector2.ONE*.5;sprite.position=Vector2(0,-1)
