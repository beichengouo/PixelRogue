class_name RoomExpansionRules
extends RefCounted
const ART_ROOT:="res://assets/room_expansion_v01/"
const MAP_IDS:=["altar_moonwell_v01","trial_seal_v01","event_waystation_v01","reward_glowcave_v01","reward_amber_v01","game_moonboat_v01","elite_boneflags_v01","elite_thorncourt_v01","normal_windbridge_v01"]
const UNLOCK:={"altar":4,"trial":8,"event":1}
static var _textures:Dictionary={}
static func field_texture(id:String)->Texture2D:
	if not _textures.has(id):
		var path:=ART_ROOT+"fx/"+id+".png"
		_textures[id]=load(path) if ResourceLoader.exists(path) else null
	return _textures[id]
static func population(base:Dictionary,factor:float)->Dictionary:
	var result:=base.duplicate(true);var target:=ceili(int(base.total)*factor);var assigned:=0;var remainder:Array[float]=[]
	for kind in WaveTable.KINDS:
		var share:=int(base.get(kind,0))*factor;result[kind]=floori(share);assigned+=int(result[kind]);remainder.append(share-floorf(share))
	while assigned<target:
		var best:=remainder.find(remainder.max());result[WaveTable.KINDS[best]]+=1;assigned+=1;remainder[best]=-1
	result.total=assigned
	return result
static func safe_point(room:RoomLevel,at:Vector2,radius:float=12)->bool:
	if not room.bounds().grow(-radius).has_point(at) or not room.body_clear(at,radius):return false
	for direction in RoomGraph.DIRECTIONS:
		if at.distance_to(room.door_point(direction,30))<72:return false
	return room.scene_navigation.spawn_reachable(room,at,radius,false)
static func icon(id:String)->Texture2D:
	var path:=ART_ROOT+"icons/"+id+".png"
	return load(path) if ResourceLoader.exists(path) else null
