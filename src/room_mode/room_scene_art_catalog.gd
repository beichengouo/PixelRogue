class_name RoomSceneArtCatalog
extends RefCounted
## Stable, explicit room and sprite IDs; artwork never determines collision rules.
const ROOT:="res://assets/room_illustrated/"
const IDS:=["camp_starlight_corridor_v02","camp_starlight_corridor_v01","forest_v01","tavern_v01","bone_glade_v02","flower_bend_v02","forest_clearing_v03","forest_grove_v03","forest_timber_v03","boss_mage_garden_v03","boss_tide_shore_v03","wetland_twin_pools_v03","tavern_waterfront_v03","boss_king_court_v03","ruin_archive_v03","ruin_courtyard_v03","shop_garden_v03","shop_stone_v03","tavern_veranda_v03","reward_treasury_v01","game_hall_v01","altar_moonwell_v01","trial_seal_v01","event_waystation_v01","reward_glowcave_v01","reward_amber_v01","game_moonboat_v01","elite_boneflags_v01","elite_thorncourt_v01","normal_windbridge_v01","city_silent_gate_v01","city_star_canal_v01","city_wax_street_v01","city_eclipse_court_v01","city_name_archive_v01","city_observatory_v01","city_boss_sephra_v01","city_boss_verena_v01","city_boss_nameless_v01"]
static var _cache:Dictionary={}
static var _signatures:Dictionary={}
static func definition(id:String)->Dictionary:
	if id not in IDS:return {}
	var path:=ROOT+id+"/scene.json"
	var signature:=FileAccess.get_md5(path) if FileAccess.file_exists(path) else "missing"
	if not _cache.has(id) or str(_signatures.get(id,""))!=signature:
		_signatures[id]=signature
		var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_cache[id]=value if value is Dictionary and int(value.get("version",0))==1 else {}
	return _cache[id]
static func entries()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for id in IDS:
		for item in definition(id).get("pieces",[]):result.append(item.duplicate(true))
	return result
static func get_entry(id:String)->Dictionary:
	for entry in entries():
		if str(entry.id)==id:return entry
	return {}
