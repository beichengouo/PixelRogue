class_name LargeSkillArt
extends RefCounted
const ROOT:="res://assets/combat_revision_v04/heroes/"
const ELF:={"wind_burst":"wind_burst","ultimate_end":"wind_burst","trap":"trap","spread_vine":"trap","zone":"trap","wild_zone":"trap","tree":"tree","tree_end":"tree_end","seed_burst":"tree_end"}
static var _cache:Dictionary={}
static func frames(id:String)->Array[Texture2D]:
	if _cache.has(id):return _cache[id]
	var result:Array[Texture2D]=[];var path:=ROOT+id+".png"
	if not ResourceLoader.exists(path):return result
	var sheet:=load(path) as Texture2D;var cell:=sheet.get_height()
	for index in 4:
		var frame:=AtlasTexture.new();frame.atlas=sheet;frame.region=Rect2(index*cell,0,cell,cell);frame.filter_clip=true;result.append(frame)
	_cache[id]=result;return result
