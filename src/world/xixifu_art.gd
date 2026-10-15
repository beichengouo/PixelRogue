class_name XixifuArt
extends RefCounted
const ROOT := "res://assets/characters/xixifu/"
const DIRECTIONS := ["s","sw","w","nw","n","ne","e","se"]
static var _frames:SpriteFrames
static func make_frames()->SpriteFrames:
	if _frames!=null:return _frames
	_frames=SpriteFrames.new();_frames.remove_animation(&"default")
	for action in ["idle","walk","attack","move_attack","back_attack"]:
		var moving:bool=action in ["walk","move_attack","back_attack"]
		for row in 8:
			_add(action+"_"+DIRECTIONS[row],action+("_v3" if moving else ""),[0,1,2,3,4,3,2,1][row],0,8 if action=="idle" or moving else 4,5 if action=="idle" else (18 if action=="attack" else 7.5),action!="attack")
	var aliases={"idle":"idle_w","run":"walk_w","cast":"attack_w","attack":"attack_w","move_attack":"move_attack_w","move_cast":"move_attack_w","dash":"walk_w","fall":"idle_w","double_jump":"idle_w","brake":"idle_w","interact":"idle_w","victory":"idle_w","heal":"attack_w","shield":"attack_w","blink_in":"attack_w","blink_out":"attack_w","air_attack":"attack_w","air_cast":"attack_w","block":"idle_w"}
	for name:String in aliases:
		var source:StringName=StringName(aliases[name]);_frames.add_animation(name)
		_frames.set_animation_speed(name,_frames.get_animation_speed(source));_frames.set_animation_loop(name,_frames.get_animation_loop(source))
		for i in _frames.get_frame_count(source):_frames.add_frame(name,_frames.get_frame_texture(source,i))
	_add("prayer","prayer",0,0,8,8,true)
	_add("hurt","hurt",0,0,4,12,false);_add("death","death",0,0,4,5,false)
	_add("jump","jump",0,0,4,12,false);_add("land","land",0,0,4,20,false)
	return _frames
static func _add(name:String,file:String,row:int,start:int,count:int,fps:float,loop:bool)->void:
	var texture:=load(ROOT+file+".png") as Texture2D
	_frames.add_animation(name);_frames.set_animation_speed(name,fps);_frames.set_animation_loop(name,loop)
	for i in count:
		var a:=AtlasTexture.new();a.atlas=texture;a.region=Rect2((start+i)*96,row*96,96,96);a.filter_clip=true;_frames.add_frame(name,a)
static func align(sprite:AnimatedSprite2D, rooms:=false)->void:
	var factor:=RoomHeroArt.WORLD_HEIGHT/RoomHeroArt.ART_HEIGHT if rooms else 0.80
	sprite.scale=Vector2.ONE*factor;sprite.position=Vector2(0,(14 if rooms else 21)-(80-48)*factor)
