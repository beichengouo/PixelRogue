class_name PixelEnemyArt
extends RefCounted
## Supplied orc and skeleton atlases plus the new biome creatures.
const DIR := "res://assets/quality_20261011/units/"
const KINDS := [&"walker", &"guard", &"flyer", &"caster", &"charger", &"bomber", &"treant"]
const NEW_KINDS := [&"moss_badger", &"bog_crab", &"ruin_sentinel", &"thorn_mantis", &"lantern_toad", &"dusk_acolyte",&"bell_snail",&"glimmer_spider"]
# Measured across every action of the supplied atlases, including wide attacks.
const SOURCES := {&"walker":"skeleton_sword", &"guard":"skeleton_guard", &"bomber":"skeleton_necro", &"flyer":"skeleton_necro", &"caster":"skeleton_necro", &"charger":"orc", &"treant":"orc"}
const ACCENTS := {&"walker":Color.WHITE, &"guard":Color.WHITE, &"bomber":Color("ef6660"), &"flyer":Color(.45,1.65,1.85,.86), &"caster":Color.WHITE, &"charger":Color("c66553"), &"treant":Color("83b452")}
static var _frames:Dictionary={}
static var _textures:Dictionary={}
static var _generated_data:Dictionary={}
const GENERATED_CANVAS:=512.0
static func source_directory(id:StringName)->String:return DIR if SOURCES.get(id,"orc")=="orc" else DIR+"generated/"
static func supports(id:StringName)->bool:
	if id in NEW_KINDS:return true
	return id in KINDS and ResourceLoader.exists(source_directory(id)+str(SOURCES[id])+".png")
static func info(id:StringName)->Dictionary:
	if SOURCES.get(id,"orc")=="orc":return {"upright_height":15.0}
	if _generated_data.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DIR+"generated/atlas_metadata.json"))
		if parsed is Dictionary:_generated_data=parsed
	return _generated_data.get(str(SOURCES[id]),{})
static func _add_generated(result:SpriteFrames,name:StringName,source:Texture2D,data:Dictionary,row:int,columns:Array,speed:float,loop:bool)->void:
	result.add_animation(name);result.set_animation_speed(name,speed);result.set_animation_loop(name,loop)
	for column:int in columns:
		var index:=row*3+column;var box:Array=data.rects[index];var anchor:Array=data.anchors[index]
		var atlas:=AtlasTexture.new();atlas.atlas=source;atlas.filter_clip=true
		atlas.region=Rect2(box[0],box[1],box[2],box[3])
		atlas.margin=Rect2(Vector2(GENERATED_CANVAS*.5+float(box[0])-float(anchor[0]),GENERATED_CANVAS*.5+float(box[1])-float(anchor[1])),Vector2.ONE*GENERATED_CANVAS-atlas.region.size)
		result.add_frame(name,atlas)
static func recolored_texture(path:String,accent:Color,mode:String="bones")->Texture2D:
	var key:=path+accent.to_html()+mode
	if _textures.has(key):return _textures[key]
	var texture:=load(path) as Texture2D
	if accent==Color.WHITE:_textures[key]=texture;return texture
	var image:=TexturePixels.image(texture);image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var color:=image.get_pixel(x,y)
			if color.a==0:continue
			if mode=="soldier":
				# Recolor cloth and straps while keeping skin, steel and slash highlights.
				if color.r<=color.g*1.25 or color.r<=color.b*1.2 or color.s<.35:continue
				color=Color.from_hsv(accent.h,clampf(color.s*.85,.3,.8),color.v,color.a)
			elif mode=="orc":
				# Skin palette distinguishes the two axe attacks and the stump ambusher.
				if color.g<=color.r*1.05 or color.g<=color.b*1.12 or color.s<.25:continue
				color=Color.from_hsv(accent.h,color.s,color.v,color.a)
			else:
				var tinted:=color*accent
				color=color.lerp(tinted,.7);color.a=image.get_pixel(x,y).a
			image.set_pixel(x,y,color)
	var result:=ImageTexture.create_from_image(image);_textures[key]=result;return result
static func _add(result:SpriteFrames,name:StringName,source:Texture2D,cell:Vector2,positions:Array,speed:float,loop:bool)->void:
	result.add_animation(name);result.set_animation_speed(name,speed);result.set_animation_loop(name,loop)
	for position:Vector2 in positions:
		var atlas:=AtlasTexture.new();atlas.atlas=source;atlas.region=Rect2(position*cell,cell);atlas.filter_clip=true
		result.add_frame(name,atlas)
static func make_frames(id:StringName)->SpriteFrames:
	if RevisedMonsterArt.TYPES.has(id):return RevisedMonsterArt.frames(id)
	if id in NEW_KINDS:return NewMonsterAtlasArt.frames(id)
	if _frames.has(id):return _frames[id]
	var type:String=SOURCES[id]
	var source:Texture2D=recolored_texture(DIR+type+".png",ACCENTS[id],"orc") if type=="orc" else load(DIR+"generated/"+type+".png")
	var frames:=SpriteFrames.new();frames.remove_animation(&"default")
	if type=="orc":
		var attack_row:=3 if id==&"charger" else 2
		var specs:={&"idle":[0,[0,1,2,3,4,5],10.0,true],&"walk":[1,[0,1,2,3,4,5,6,7],10.0,true],&"windup":[attack_row,[0,1,2],8.0,false],&"attack":[attack_row,[2,3,4,5],16.0,false],&"hurt":[4,[0,1,2,3],16.0,false],&"death":[5,[0,1,2,3],10.0,false],&"jump":[1,[1],8.0,false],&"fall":[1,[5],8.0,false],&"charge":[3,[3,4,5],16.0,true],&"recover":[3,[5],8.0,false],&"root":[0,[0,1,2,3],6.0,true],&"spawn":[5,[3,2,1,0,0,0,0,0],8.0,false]}
		for name:StringName in specs:
			var spec:Array=specs[name];var positions:Array=[]
			for col:int in spec[1]:positions.append(Vector2(col,spec[0]))
			_add(frames,name,source,Vector2(100,100),positions,spec[2],spec[3])
	else:
		# Original three-pose rows, fixed atlas rectangles and fixed foot anchors.
		# PNG source pixels are never redrawn, resampled or rewritten.
		var data:=info(id)
		var specs:={&"idle":[0,[0,1,2,1],6.0,true],&"walk":[1,[0,1,2,1],8.0,true],&"fly":[1,[0,1,2,1],8.0,true],&"windup":[2,[0],8.0,false],&"attack":[2,[1,2],12.0,false],&"summon_cast":[2,[0,1,2],6.0,false],&"hurt":[3,[0,1,2],15.0,false],&"death":[4,[0,1,2],6.0,false],&"jump":[1,[0],8.0,false],&"fall":[1,[2],8.0,false],&"spawn":[5,[0,0,1,1,2,2,2,2],8.0,false]}
		for name:StringName in specs:
			var spec:Array=specs[name]
			_add_generated(frames,name,source,data,spec[0],spec[1],spec[2],spec[3])
		frames.set_frame(&"death",2,frames.get_frame_texture(&"death",2),3.0)
	if type=="orc":frames.set_frame(&"death",3,frames.get_frame_texture(&"death",3),6.0)
	_frames[id]=frames;return frames
static func directional_action(_id:StringName,action:StringName,_direction:Vector2)->StringName:return action
static func align(sprite:AnimatedSprite2D,id:StringName,body:Vector2)->void:
	if RevisedMonsterArt.TYPES.has(id):RevisedMonsterArt.align(sprite,body);return
	if id in NEW_KINDS:
		NewMonsterAtlasArt.align(sprite,id,body)
		return
	var orc:bool=SOURCES.get(id,"orc")=="orc"
	var factor:=body.y/float(info(id).upright_height)
	sprite.scale=Vector2.ONE*factor
	if orc:sprite.position=Vector2(0,roundf(body.y*.5-7.0*factor))
	else:
		sprite.position=Vector2(0,roundf(body.y*.5));sprite.self_modulate=ACCENTS.get(id,Color.WHITE)
static func spawn_remains(source:AnimatedSprite2D,parent:Node)->AnimatedSprite2D:
	if not is_instance_valid(parent):return null
	var sprite:=AnimatedSprite2D.new();sprite.name="EnemyRemains";sprite.sprite_frames=source.sprite_frames
	sprite.self_modulate=source.self_modulate
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.flip_h=source.flip_h;sprite.z_index=source.z_index;sprite.process_mode=Node.PROCESS_MODE_PAUSABLE
	parent.add_child(sprite);sprite.global_transform=source.global_transform;sprite.add_to_group("enemy_remains")
	sprite.animation_finished.connect(func()->void:
		var fade:=sprite.create_tween();fade.tween_property(sprite,"modulate:a",0.0,.18);fade.tween_callback(sprite.queue_free)
	,CONNECT_ONE_SHOT)
	var action:=&"death"
	if str(source.animation).contains("_d"):
		var direction:=str(source.animation).get_slice("_d",1);var directional:=StringName("death_d"+direction)
		if sprite.sprite_frames.has_animation(directional):action=directional
	sprite.play(action);return sprite


