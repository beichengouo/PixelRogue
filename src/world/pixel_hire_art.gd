class_name PixelHireArt
extends RefCounted
const DIR:="res://assets/hired_allies_v02/"
const IDS := ["ranger","scout","knife","hunter"]
const WORLD_HEIGHT:=32.0
const COLORS:=[Color("8997a7"),Color("54b4a5"),Color("d7a353"),Color("9c78d1")]
static var _frames:Dictionary={}
static var _metadata:Dictionary={}
static func info(index:int)->Dictionary:
	index=clampi(index,0,3)
	if _metadata.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DIR+"metadata.json"))
		if parsed is Dictionary:_metadata=parsed
	var result:Dictionary=_metadata.get(IDS[index],{}).duplicate(true)
	result.accent=COLORS[index];result.upright_height=float(result.get("extents",[104,100])[1])
	return result
static func make_frames(index:int)->SpriteFrames:
	index=clampi(index,0,3)
	if _frames.has(index):return _frames[index]
	var source:=load(DIR+IDS[index]+".png") as Texture2D
	var frames:=SpriteFrames.new();frames.remove_animation(&"default")
	var specs:={&"idle":[[0],6.0,true],&"walk":[[1],8.0,true],&"attack":[[2,3],8.0/.42,false],&"hurt":[[4],16.0,false],&"death":[[5],8.0,false]}
	for action:StringName in specs:
		var spec:Array=specs[action];var positions:Array=[]
		for row:int in spec[0]:
			for col in 4:positions.append(Vector2(col,row))
		PixelEnemyArt._add(frames,action,source,Vector2(128,128),positions,float(spec[1]),bool(spec[2]))
	for action in [&"jump",&"fall"]:
		frames.add_animation(action);frames.set_animation_loop(action,false);frames.add_frame(action,frames.get_frame_texture(&"walk",1 if action==&"jump" else 3))
	frames.set_frame(&"death",3,frames.get_frame_texture(&"death",3),6.0)
	_frames[index]=frames;return frames
static func align(sprite:AnimatedSprite2D,index:int,body:Vector2)->void:
	var extents:Array=info(index).get("extents",[104,100])
	var factor:=minf(38.0/maxf(1,float(extents[0])),WORLD_HEIGHT/maxf(1,float(extents[1])))
	sprite.scale=Vector2.ONE*factor;sprite.position=Vector2(0,body.y*.5-(116.0-64.0)*factor)
static func attack_frame(index:int,clock:float,released:bool,windup:float,duration:float)->int:
	var count:=make_frames(index).get_frame_count(&"attack")
	# Show preparation before the existing damage tick, then the full release/recovery.
	var release_start:=4
	if not released:return clampi(int(clock/maxf(windup,.001)*release_start),0,release_start-1)
	var progress:=clampf((clock-windup)/maxf(duration-windup,.001),0,1)
	return mini(count-1,release_start+int(progress*(count-release_start)))

