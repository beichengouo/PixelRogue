class_name ExtractionSpriteArt
extends RefCounted
const ROOT := "res://assets/extraction/"
const LOGICAL_SIZE := Vector2(1024, 1024)
const FOOT := Vector2(384, 900)
# Authored protagonist height only: exclude Iris, light and transparent padding.
const SUCCESS_HEIGHT := {&"sylphiette":274.0,&"xixifu":77.0,&"ilyua":74.0}
const SUCCESS_GODDESS_HEIGHT := {&"sylphiette":452.0,&"xixifu":116.0,&"ilyua":127.0}
const SUCCESS_GODDESS_OFFSET := {&"sylphiette":335.0,&"xixifu":58.0,&"ilyua":76.0}
static var _cache: Dictionary = {}
static var _metadata: Dictionary = {}
static var _character_heights: Dictionary = {}

static func character_height(id:StringName)->float:
	var key:=str(id)+("_set" if LegendarySets.form_unlocked(id) else "_normal")
	if _character_heights.has(key):return float(_character_heights[key])
	var texture:=RedrawnHeroArt.frames(id).get_frame_texture(&"idle_s",0) as AtlasTexture
	var image:=TexturePixels.image(texture.atlas).get_region(Rect2i(texture.region))
	var first:=image.get_height();var last:=-1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a>=.2:
				first=mini(first,y);last=maxi(last,y);break
	_character_heights[key]=float(last-first+1) if last>=first else RedrawnHeroArt.ART_HEIGHT
	return float(_character_heights[key])

static func frames(kind: String) -> SpriteFrames:
	if kind=="prayer":return redrawn_frames(kind)
	if Characters.current_id() in [&"ilyua",&"sylphiette"] and kind=="success":return elven_frames()
	if Characters.current_id()==&"xixifu" and kind=="success":return contract_frames(kind)
	if _cache.has(kind): return _cache[kind]
	if _metadata.is_empty(): _metadata = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "metadata.json"))
	var spec: Dictionary = _metadata[kind]
	var source := load(ROOT + str(spec.file)) as Texture2D
	var result := SpriteFrames.new()
	result.set_animation_loop(&"default", false)
	result.set_animation_speed(&"default", 8)
	for raw in spec.frames:
		var region: Array = raw.region
		var pivot: Array = raw.anchor
		var texture := AtlasTexture.new()
		texture.atlas = source
		texture.region = Rect2(region[0],region[1],region[2],region[3])
		texture.margin = Rect2(FOOT - Vector2(pivot[0],pivot[1]), LOGICAL_SIZE - texture.region.size)
		texture.filter_clip = true
		result.add_frame(&"default", texture)
	_cache[kind] = result
	return result

static func scale_for(kind: String, height: float) -> float:
	if kind=="prayer":return height/float(RedrawnHeroArt.frames(Characters.current_id()).get_meta("utility_height",RedrawnHeroArt.ART_HEIGHT))
	if kind=="success" and Characters.current_id()==&"sylphiette":
		var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(HolySkills.ROOT+"success_metadata.json"))
		return height/float(data.height)
	if kind=="success":return height/float(SUCCESS_HEIGHT.get(Characters.current_id(),274.0))
	frames(kind)
	return height / float(_metadata[kind].reference_height)

static func redrawn_frames(kind:String)->SpriteFrames:
	var key:=str(Characters.current_id())+("_set_" if LegendarySets.form_unlocked(Characters.current_id()) else "_holy_")+kind
	if _cache.has(key):return _cache[key]
	var source:=RedrawnHeroArt.frames(Characters.current_id())
	var action:StringName=&"prayer" if kind=="prayer" else &"interact"
	var result:=SpriteFrames.new();result.set_animation_loop(&"default",false);result.set_animation_speed(&"default",8)
	for index in 8:
		var original:=source.get_frame_texture(action,index%4) as AtlasTexture
		var atlas:=AtlasTexture.new();atlas.atlas=original.atlas;atlas.region=original.region;atlas.filter_clip=true
		atlas.margin=Rect2(FOOT-RedrawnHeroArt.FOOT,LOGICAL_SIZE-Vector2.ONE*RedrawnHeroArt.CELL)
		result.add_frame(&"default",atlas)
	_cache[key]=result;return result

static func contract_frames(kind:String)->SpriteFrames:
	var key:="xixifu_"+kind
	if _cache.has(key):return _cache[key]
	var frames:=SpriteFrames.new();frames.set_animation_loop(&"default",false)
	var source:=load(XixifuArt.ROOT+kind+".png") as Texture2D
	var cell:=160 if kind=="success" else 96
	var anchor:=Vector2(42,132) if kind=="success" else Vector2(48,80)
	for i in 8:
		var tex:=AtlasTexture.new();tex.atlas=source;tex.region=Rect2(i*cell,0,cell,cell)
		tex.margin=Rect2(FOOT-anchor,LOGICAL_SIZE-Vector2(cell,cell));tex.filter_clip=true;frames.add_frame(&"default",tex)
	_cache[key]=frames;return frames

static func elven_frames()->SpriteFrames:
	var key:=str(Characters.current_id())+"_success"
	if _cache.has(key):return _cache[key]
	var root:=HolySkills.ROOT if Characters.current_id()==&"sylphiette" else "res://assets/characters/ilyua/"
	var source:=load(root+"success.png") as Texture2D
	var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root+"success_metadata.json"))
	var result:=SpriteFrames.new();result.set_animation_loop(&"default",false);result.set_animation_speed(&"default",8)
	for index in 8:
		var raw:Array=metadata.anchors[index];var anchor:=Vector2(float(raw[0]),float(raw[1]))
		var cell:=AtlasTexture.new();cell.atlas=source;cell.region=Rect2(index*160,0,160,160);cell.filter_clip=true
		cell.margin=Rect2(FOOT-anchor,LOGICAL_SIZE-Vector2(160,160));result.add_frame(&"default",cell)
	_cache[key]=result;return result
