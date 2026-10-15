class_name RedrawnHeroArt
extends RefCounted
## Shared clean character atlases. Gameplay collision/attack timing stays elsewhere.
const ROOT:="res://assets/heroes_v04/"
const CELL:=96
const ART_HEIGHT:=64.0
const FOOT:=Vector2(48,80)
const DIRECTIONS:=["s","sw","w","nw","n","ne","e","se"]
const SOURCE_ROWS:=[0,1,2,3,4,3,2,1]
## Standing body heights, excluding the staff tip. One scale per action/row
## avoids breathing/jitter between frames and preserves the shared foot anchor.
const HOLY_BODY_HEIGHTS:={
	"idle":[54,55,57,59,62],"walk":[64,62,62,64,66],
	"attack":[53,54,54,55,51],"move_attack":[54,56,58,56,60],
	"back_attack":[54,55,58,56,56]}
static var _cache:Dictionary={}
static var _material:ShaderMaterial

static func material()->ShaderMaterial:
	if _material!=null:return _material
	var shader:=Shader.new()
	# Generated soft matte pixels are discarded before tinting; preserve the
	# character's hit flash and invulnerability fade after the clean cutout.
	shader.code="shader_type canvas_item; varying vec4 actor_tint; void vertex(){actor_tint=COLOR;} void fragment(){vec4 pixel=texture(TEXTURE,UV); if(pixel.a<0.2){discard;} COLOR=vec4(pixel.rgb,1.0)*actor_tint;}"
	_material=ShaderMaterial.new();_material.shader=shader
	return _material

static func frames(id:StringName)->SpriteFrames:
	var set_form:=LegendarySets.form_unlocked(id) and ResourceLoader.exists(LegendarySets.ROOT+str(id)+"/core.png")
	var cache_key:=StringName(str(id)+"_set") if set_form else id
	if _cache.has(cache_key):return _cache[cache_key]
	var holy:=id==&"sylphiette"
	var custom_root:=LegendarySets.ROOT+str(id)+"/" if set_form else HolySkills.ROOT
	var core:=load(custom_root+"core.png" if holy or set_form else ROOT+str(id)+"-core.png") as Texture2D
	var utility:=load(custom_root+"utility.png" if holy or set_form else ROOT+str(id)+"-utility.png") as Texture2D
	var result:=SpriteFrames.new();result.remove_animation(&"default")
	result.set_meta("redrawn_character",id)
	result.set_meta("set_form",set_form)
	if holy or set_form:
		for kind in ["core","utility"]:
			var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(custom_root+kind+"-metadata.json"))
			result.set_meta(kind+"_height",float(metadata.get("height",64)))
	var separate:=holy and ResourceLoader.exists(custom_root+"actions_v02/idle.png")
	if separate:
		var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(custom_root+"actions_v02/metadata.json"))
		result.set_meta("separate_actions",true);result.set_meta("core_height",float(metadata.get("height",64)))
	for action in ["idle","walk","attack","move_attack","back_attack"]:
		var action_texture:Texture2D=load(custom_root+"actions_v02/"+action+".png") if separate else core
		for direction in 8:
			var row:int=SOURCE_ROWS[direction]
			if not separate and action in ["attack","move_attack","back_attack"]:row+=5
			var first:=4 if not separate and action in ["walk","move_attack","back_attack"] else 0
			var order:Array[int]=[0,1,2,3]
			# The final red-haired idle/cast source turns away from its facing.
			# Recover to the matching ready pose rather than showing that turn.
			if id==&"sylphiette" and not holy and action in ["idle","attack"]:order=[0,1,2,0]
			if action=="back_attack" and id!=&"ilyua" and not separate:order=[3,2,1,0]
			var bow_action:bool=id==&"ilyua" and action in ["attack","move_attack","back_attack"]
			# Backpedaling changes locomotion, never the nock/draw/release order.
			var casting:bool=action in ["attack","move_attack","back_attack"]
			var fps:=12.5 if separate and casting else 18.0 if action=="attack" or bow_action else 5.0 if action=="idle" else 7.5
			_add(result,StringName(action+"_"+DIRECTIONS[direction]),action_texture,row,first,order,fps,not casting if separate else action!="attack" and not bow_action)
	for spec in [[&"prayer",0,8.0,true],[&"hurt",1,12.0,false],[&"death",2,5.0,false],[&"jump",3,12.0,false],[&"land",4,20.0,false],[&"interact",5,12.5,false]]:
		_add(result,spec[0],utility,int(spec[1]),0,[0,1,2,3],float(spec[2]),bool(spec[3]))
	var aliases:={"idle":"idle_w","run":"walk_w","cast":"attack_w","attack":"attack_w","move_attack":"move_attack_w","move_cast":"move_attack_w","dash":"walk_w","fall":"idle_w","double_jump":"jump","brake":"land","victory":"interact","heal":"attack_w","shield":"attack_w","blink_in":"attack_w","blink_out":"attack_w","air_attack":"attack_w","air_cast":"attack_w","block":"hurt"}
	for name:String in aliases:
		var source:=StringName(aliases[name]);result.add_animation(name)
		result.set_animation_speed(name,result.get_animation_speed(source));result.set_animation_loop(name,result.get_animation_loop(source))
		for index in result.get_frame_count(source):result.add_frame(name,result.get_frame_texture(source,index))
	_cache[cache_key]=result
	return result

static func _add(result:SpriteFrames,name:StringName,texture:Texture2D,row:int,first:int,order:Array[int],fps:float,loop:bool)->void:
	result.add_animation(name);result.set_animation_speed(name,fps);result.set_animation_loop(name,loop)
	for index in order:
		var atlas:=AtlasTexture.new();atlas.atlas=texture
		atlas.region=Rect2((first+index)*CELL,row*CELL,CELL,CELL);atlas.filter_clip=true
		result.add_frame(name,atlas)

static func align(sprite:AnimatedSprite2D,height:=32.0,floor_y:=14.0)->void:
	var utility:=str(sprite.animation) in ["prayer","hurt","death","jump","land","interact","victory","double_jump","brake","block"]
	var source_height:=float(sprite.sprite_frames.get_meta("utility_height" if utility else "core_height",ART_HEIGHT))
	if bool(sprite.sprite_frames.get_meta("separate_actions",false)) and not utility:
		var animation:=str(sprite.animation)
		# Aliases use west-facing source frames, just like frames().
		var direction:=DIRECTIONS.find(animation.get_slice("_",animation.get_slice_count("_")-1))
		var action:=animation.left(animation.rfind("_")) if direction>=0 else str({"run":"walk","cast":"attack","move_cast":"move_attack","dash":"walk","fall":"idle","heal":"attack","shield":"attack","blink_in":"attack","blink_out":"attack","air_attack":"attack","air_cast":"attack"}.get(animation,animation))
		if HOLY_BODY_HEIGHTS.has(action):
			var row:int=SOURCE_ROWS[direction if direction>=0 else 2]
			source_height*=float(HOLY_BODY_HEIGHTS[action][row])/64.0
	var factor:=height/source_height
	sprite.scale=Vector2.ONE*factor
	sprite.position=Vector2(0,floor_y-(FOOT.y-CELL*.5)*factor)
	sprite.material=material()

