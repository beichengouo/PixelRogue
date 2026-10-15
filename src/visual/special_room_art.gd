class_name SpecialRoomArt
extends RefCounted
const ROOT:="res://assets/special_rooms_v01/"
static var _icons:Dictionary={}
static var _chests:Array[Texture2D]=[]
static func room_icon(kind:String)->Texture2D:
	if kind in ["altar","trial","event"]:return RoomExpansionRules.icon(kind)
	if not _icons.has(kind):
		var path:=ROOT+kind+".png"
		_icons[kind]=load(path) if ResourceLoader.exists(path) else null
	return _icons[kind]
static func chest_frame(frame:int)->Texture2D:
	if _chests.is_empty():
		var path:=ROOT+"luxury_chest.png"
		if not ResourceLoader.exists(path):return null
		var sheet:=load(path) as Texture2D
		for index in 5:
			var part:=AtlasTexture.new();part.atlas=sheet;part.region=Rect2(index*128,0,128,128);part.filter_clip=true;_chests.append(part)
	return _chests[clampi(frame,0,4)]
