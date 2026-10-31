class_name BossStageArt
extends RefCounted
const ROOT:="res://assets/boss_stages_v41/"
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
	if data.is_empty() or not bool(data.get("skill_transition_coverage",{}).get("complete",false)):
		push_error("Missing complete V41 boss stage: "+key)
		return SpriteFrames.new()
	var source:=load(ROOT+key+".png") as Texture2D
	if source==null:
		push_error("Missing V41 boss atlas: "+key)
		return SpriteFrames.new()
	var cell:=int(data.get("cell",256))
	var result:=SpriteFrames.new();result.remove_animation(&"default")
	# Four base key poses plus one independently drawn middle pose per skill.
	# Keep the original timing slots while reading each skill's explicit sequence.
	var pose_tiles:Dictionary={}
	for pose:String in data.poses:
		var pose_data:Dictionary=data.poses.get(pose,{})
		if pose_data.is_empty():
			push_error("Incomplete V41 boss pose: "+key+"/"+pose)
			return SpriteFrames.new()
		var tile:=AtlasTexture.new()
		tile.atlas=source
		tile.region=Rect2(int(pose_data.column)*cell,int(pose_data.row)*cell,cell,cell)
		tile.filter_clip=true
		var bounds:Array=pose_data.painted_bounds
		tile.set_meta("painted_bounds",Rect2(bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]))
		pose_tiles[pose]=tile
	for action:String in data.animations:
		var spec:Dictionary=data.animations[action];result.add_animation(action)
		result.set_animation_speed(action,float(spec.get("fps",8)));result.set_animation_loop(action,action in ["idle","move"])
		var sequence:Array=spec.get("pose_sequence",[])
		if sequence.size()!=int(spec.slots):
			push_error("Incomplete V41 boss sequence: "+key+"/"+action)
			return SpriteFrames.new()
		for pose:String in sequence:
			if not pose_tiles.has(pose):
				push_error("Missing V41 boss sequence pose: "+key+"/"+action+"/"+pose)
				return SpriteFrames.new()
			result.add_frame(action,pose_tiles[pose])
	result.set_meta("boss_stage_art",true);result.set_meta("body_height",float(data.body_height))
	result.set_meta("cell",cell);result.set_meta("foot",Vector2(data.foot[0],data.foot[1]))
	result.set_meta("source_pose_count",int(data.source_pose_count))
	result.set_meta("animation_kind",StringName(data.animation_kind))
	_frames[key]=result;return result
static func align(sprite:AnimatedSprite2D,id:StringName,body:Vector2)->void:
	PixelBossArt.align(sprite,id,body)
static func icon(id:StringName,phase:int)->Texture2D:
	# HUD portraits must show the face and shoulders. Stage thumbnails contain
	# the entire battle model, making the head tiny even in a larger Control.
	# Stage identity remains on the health segments and the arena model.
	var path:=BossRoster.icon_path(id)
	if not ResourceLoader.exists(path):return frames(id,phase).get_frame_texture(&"idle",0)
	if not _icons.has(path):
		var source:=load(path) as Texture2D
		var pixels:=TexturePixels.image(source)
		var bounds:=pixels.get_used_rect() if pixels!=null else Rect2i(Vector2i.ZERO,source.get_size())
		var portrait:=AtlasTexture.new();portrait.atlas=source
		portrait.region=Rect2(bounds.grow(2).intersection(Rect2i(Vector2i.ZERO,source.get_size())))
		portrait.filter_clip=true;_icons[path]=portrait
	return _icons[path]
