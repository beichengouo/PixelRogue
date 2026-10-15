class_name SmallSpiritArt
extends RefCounted
static var _frames:SpriteFrames
static func frames()->SpriteFrames:
	if _frames!=null:return _frames
	_frames=SpriteFrames.new();_frames.remove_animation(&"default")
	var atlas:Texture2D=load("res://assets/companions_v03/bone_spirit.png")
	var names:=[&"idle",&"walk",&"attack",&"hurt",&"death",&"spawn"]
	for row in names.size():
		var pose:StringName=names[row];_frames.add_animation(pose)
		_frames.set_animation_loop(pose,pose in [&"idle",&"walk"])
		_frames.set_animation_speed(pose,10 if pose==&"walk" else 12)
		for col in 4:
			var frame:=AtlasTexture.new();frame.atlas=atlas;frame.region=Rect2(col*96,row*96,96,96)
			_frames.add_frame(pose,frame)
	return _frames
static func align(sprite:AnimatedSprite2D)->void:
	sprite.scale=Vector2.ONE*.5;sprite.position=Vector2(0,-2)
