class_name CampArt
extends RefCounted
const ROOT="res://assets/camp_refine/"
static var _cache:Dictionary={}
static func texture(key: String) -> Texture2D:
	if _cache.has(key):return _cache[key]
	var path=ROOT+key+".png"
	if not ResourceLoader.exists(path):return null
	var image=load(path) as Texture2D
	var bounds:Dictionary={}
	if FileAccess.file_exists(ROOT+"bounds.json"):bounds=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"bounds.json"))
	if bounds.has(key):
		var rect:Array=bounds[key]
		var atlas=AtlasTexture.new()
		atlas.atlas=image
		atlas.region=Rect2(rect[0],rect[1],rect[2],rect[3])
		_cache[key]=atlas
	else:_cache[key]=image
	return _cache[key]
