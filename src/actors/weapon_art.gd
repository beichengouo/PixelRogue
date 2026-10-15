class_name WeaponArt
extends RefCounted
const ROOT:="res://assets/weapons/reforged/"
static var _cache:Dictionary={}
static func frames(id:String,cell:=96)->Array[Texture2D]:
	if _cache.has(id):return _cache[id]
	var result:Array[Texture2D]=[]
	var texture:=load(ROOT+id+".png") as Texture2D
	if texture==null:return result
	for frame in 4:
		var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2(frame*cell,0,cell,cell);atlas.filter_clip=true;result.append(atlas)
	_cache[id]=result
	return result
static func profile()->Dictionary:
	var weapon:=GameState.equipped(&"weapon")
	if weapon.is_empty():return {"fx":"wand_arcane","speed":430.0,"reach":540.0,"color":Color("c9a8ff")}
	return weapon.get("weapon",{})
