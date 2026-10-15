class_name PixelBossArt
extends RefCounted
## 原创 Boss PNG 原图保持不变；由元数据裁帧、统一脚底和显示尺寸。
const DIR := "res://assets/pixel_batch8/"
const HEIGHTS := {&"king":88.0,&"mage":90.0,&"tide":96.0,&"sephra":88.0,&"verena":90.0,&"nameless":96.0}
const CITY_ROOT:="res://assets/chapter2/bosses/"
static func city_boss(id:StringName)->bool:return id in [&"sephra",&"verena",&"nameless"]
const ANIMS := {&"idle":[0,6.0,true],&"move":[4,8.0,true],&"windup":[8,7.0,false],&"release":[12,12.0,false]}
static var _metadata:Dictionary={}
static var _cache:Dictionary={}
static var _scale:Dictionary={}
static var _action_scale:Dictionary={}

static func info(id:StringName) -> Dictionary:
	if _metadata.is_empty():
		_metadata=JSON.parse_string(FileAccess.get_file_as_string(DIR+"atlas_metadata.json"))
	return _metadata[str(id)]

static func make_frames(id:StringName) -> SpriteFrames:
	if _cache.has(id):return _cache[id]
	if city_boss(id):return _city_frames(id)
	var data:=info(id)
	var source:=load(DIR+str(data.file)) as Texture2D
	var ratio:=float(source.get_width())/float(data.source_size[0])
	_scale[id]=float(HEIGHTS[id])/(float(data.upright_height)*ratio)
	var frames:=SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim:StringName in ANIMS:
		var spec:Array=ANIMS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim,float(spec[1]))
		frames.set_animation_loop(anim,bool(spec[2]))
		for i in 4:
			var rect:Array=data.rects[int(spec[0])+i]
			var atlas:=AtlasTexture.new()
			atlas.atlas=source
			var start:=Vector2(floorf(rect[0]*ratio),floorf(rect[1]*ratio))
			var end:=Vector2(ceilf((rect[0]+rect[2])*ratio),ceilf((rect[1]+rect[3])*ratio))
			atlas.region=Rect2(start,end-start)
			var anchor:=float(data.anchors[int(spec[0])+i])*ratio
			var padding:=clampf(64-(anchor-start.x),0,128-atlas.region.size.x)
			atlas.margin=Rect2(Vector2(roundf(padding),126-atlas.region.size.y),Vector2(128,128)-atlas.region.size)
			atlas.filter_clip=true
			frames.add_frame(anim,atlas)
	var action_path:="res://assets/combat_revision_v04/bosses/%s_actions.png"%id
	if ResourceLoader.exists(action_path):
		var action_sheet:=load(action_path) as Texture2D
		for row in 2:
			var name_value:=&"windup" if row==0 else &"release";frames.clear(name_value);frames.set_animation_speed(name_value,6)
			for column in 4:
				var cell:=AtlasTexture.new();cell.atlas=action_sheet;cell.region=Rect2(column*384,row*384,384,384);cell.filter_clip=true;frames.add_frame(name_value,cell)
	_cache[id]=frames
	return frames

static func align(sprite:AnimatedSprite2D,id:StringName,body:Vector2) -> void:
	var factor:=float(_scale[id])
	if city_boss(id):
		sprite.scale=Vector2.ONE*factor;sprite.position=Vector2(0,roundf(body.y*.5-(240-128)*factor));return
	if sprite.animation in [&"windup",&"release"]:
		var path:="res://assets/combat_revision_v04/bosses/%s_actions.json"%id
		if not _action_scale.has(id) and FileAccess.file_exists(path):
			var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));_action_scale[id]=float(HEIGHTS[id])/float(data.body_height)
		if _action_scale.has(id):factor=float(_action_scale[id]);sprite.scale=Vector2.ONE*factor;sprite.position=Vector2(0,roundf(body.y/2-(350-192)*factor));return
	sprite.scale=Vector2.ONE*factor
	sprite.position=Vector2(0,roundf(body.y/2-(126-64)*factor))

static func icon(id:StringName) -> Texture2D:
	# 图标使用完整第一帧，避免把武器或王冠切断。
	return make_frames(id).get_frame_texture(&"idle",0)

static func _city_frames(id:StringName)->SpriteFrames:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CITY_ROOT+str(id)+"_actions.json"))
	var source:=load(CITY_ROOT+str(id)+"_actions.png") as Texture2D
	_scale[id]=float(HEIGHTS[id])/float(data.body_height)
	var frames:=SpriteFrames.new();frames.remove_animation(&"default")
	var names:Array[StringName]=[&"idle",&"move",&"windup",&"release"]
	for row in names.size():
		frames.add_animation(names[row]);frames.set_animation_speed(names[row],[5.0,7.0,5.5,7.0][row]);frames.set_animation_loop(names[row],row<2)
		for col in 4:
			var cell:=AtlasTexture.new();cell.atlas=source;cell.region=Rect2(col*256,row*256,256,256);cell.filter_clip=true;frames.add_frame(names[row],cell)
	_cache[id]=frames;return frames
