class_name BossStageArt
extends RefCounted
const ROOT:="res://assets/boss_stages_v34/"
static var _frames:Dictionary={}
static var _metadata:Dictionary={}
static var _icons:Dictionary={}
static func clear()->void:_frames.clear();_metadata.clear();_icons.clear()
static func info(id:StringName,phase:int)->Dictionary:
	var key:="%s_%d"%[id,phase]
	if not _metadata.has(key):
		var path:=ROOT+key+".json"
		_metadata[key]=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	return _metadata[key]
static func frames(id:StringName,phase:int)->SpriteFrames:
	var key:="%s_%d"%[id,phase]
	if _frames.has(key):return _frames[key]
	var data:=info(id,phase)
	if data.is_empty():return PixelBossArt.make_frames(id)
	var source:=load(ROOT+key+".png") as Texture2D
	var cell:=int(data.get("cell",256))
	var result:=SpriteFrames.new();result.remove_animation(&"default")
	for action:String in data.animations:
		var spec:Dictionary=data.animations[action];result.add_animation(action)
		result.set_animation_speed(action,float(spec.get("fps",8)));result.set_animation_loop(action,action in ["idle","move"])
		for frame:int in spec.frames:
			var tile:=AtlasTexture.new();tile.atlas=source;tile.region=Rect2((frame%8)*cell,(frame/8)*cell,cell,cell);tile.filter_clip=true
			if frame<data.get("bounds",[]).size():
				var bounds:Array=data.bounds[frame]
				tile.set_meta("painted_bounds",Rect2(bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]))
			result.add_frame(action,tile)
	result.set_meta("boss_stage_art",true);result.set_meta("body_height",float(data.body_height))
	result.set_meta("cell",cell);result.set_meta("foot",Vector2(data.foot[0],data.foot[1]))
	_frames[key]=result;return result
static func align(sprite:AnimatedSprite2D,id:StringName,body:Vector2)->void:
	PixelBossArt.align(sprite,id,body)
static func icon(id:StringName,phase:int)->Texture2D:
	# HUD portraits must show the face and shoulders. Stage thumbnails contain
	# the entire battle model, making the head tiny even in a larger Control.
	# Stage identity remains on the health segments and the arena model.
	var path:=BossRoster.icon_path(id)
	if not ResourceLoader.exists(path):path=ROOT+"%s_%d_icon.png"%[id,phase]
	if not ResourceLoader.exists(path):return PixelBossArt.icon(id)
	if not _icons.has(path):
		var source:=load(path) as Texture2D
		var pixels:=TexturePixels.image(source)
		var bounds:=pixels.get_used_rect() if pixels!=null else Rect2i(Vector2i.ZERO,source.get_size())
		var portrait:=AtlasTexture.new();portrait.atlas=source
		portrait.region=Rect2(bounds.grow(2).intersection(Rect2i(Vector2i.ZERO,source.get_size())))
		portrait.filter_clip=true;_icons[path]=portrait
	return _icons[path]
