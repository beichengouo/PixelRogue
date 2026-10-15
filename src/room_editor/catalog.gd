class_name RoomEditorCatalog
extends RefCounted
## Stable identifiers, explicit footprints and collision semantics shared by editor and importer.
const DECOR := ["fern","flowers","bones","jar","shrub","planks"]
const SERVICE_DEFAULTS := {"goods":[58,24],"barrels":[52,22],"planter":[54,20],"notice":[46,14],"lantern":[44,10],"shrub":[38,18],"brazier":[44,16],"table":[64,32],"building_shop":[180,66],"building_tavern":[204,76]}
const SERVICE_NAMES := {"goods":"木制储物柜","barrels":"木制收纳箱","planter":"盆栽组合","notice":"木制窗板","lantern":"灯笼","shrub":"灌木","brazier":"火盆","table":"桌子","building_shop":"商店建筑","building_tavern":"酒馆建筑"}
static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in RoomTerrainCatalog.MODELS.size():
		var model: String = RoomTerrainCatalog.MODELS[i]
		var decor: bool = model in DECOR
		for size: Vector2i in RoomTerrainCatalog.SIZES:
			var suffix := "%dx%d" % [size.x, size.y]
			result.append({"id":"terrain:%s:%s" % [model,suffix], "name":"%s %s" % [RoomTerrainCatalog.NAMES[i],suffix], "layer":"decor" if decor else "obstacles", "category":"装饰" if decor else "障碍", "model":model, "size":[size.x,size.y], "path":RoomTerrainCatalog.ROOT+"editor/"+model+"_"+suffix+".png", "collision":"none" if decor else "solid", "kind":"crate" if model=="crate_iron" else "stone"})
	for material in ["grass","mud","stone","wood"]:
		result.append({"id":"floor:"+material,"name":{"grass":"草地","mud":"亮土","stone":"石地","wood":"木板"}[material],"layer":"ground","category":"地面","model":material,"size":[1,1],"path":RoomTerrainCatalog.ROOT+"floor_"+material+".png","collision":"none"})
	result.append({"id":"water","name":"深水（自动岸形）","layer":"water","category":"水体","model":"water","size":[1,1],"path":RoomTerrainCatalog.ROOT+"deep_water.png","collision":"water"})
	result.append({"id":"chest","name":"宝箱","layer":"entities","category":"实体","model":"chest","size":[1,1],"path":"res://assets/world_props_vnext/chest_closed.png","collision":"none"})
	result.append({"id":"spawn","name":"敌人出生点","layer":"markers","category":"标记","model":"enemy_spawn","size":[1,1],"path":"res://assets/room_mode/fx/enemy_spawn.png","collision":"none"})
	for model in ["goods","barrels","planter","notice","table","shrub"]:
		result.append({"id":"terrain:service_"+model+":1x1","name":"服务房 · "+model,"layer":"decor","category":"服务装饰","model":"service_"+model,"size":[1,1],"path":"res://assets/room_mode/services/"+model+".png","collision":"none","legacy":true})
	for model in SERVICE_DEFAULTS:
		var path := "res://assets/room_mode/structure/"+str(model)+".png"
		if not ResourceLoader.exists(path):path="res://assets/room_mode/services/"+str(model)+".png"
		result.append({"id":"service:"+str(model),"name":str(SERVICE_NAMES[model]),"layer":"decor","category":"服务装饰","model":model,"size":[1,1],"path":path,"collision":"service","width_px":SERVICE_DEFAULTS[model][0],"depth_px":SERVICE_DEFAULTS[model][1]})
	for kind in ["torch","lamp","plant","crystal","fire"]:
		for size: Vector2i in RoomTerrainCatalog.SIZES:
			var suffix := "%dx%d" % [size.x,size.y]
			result.append({"id":"light:%s:%s" % [kind,suffix],"name":"光源 · %s %s" % [kind,suffix],"layer":"entities","category":"光源","model":kind,"size":[size.x,size.y],"path":"res://assets/room_mode/lights/"+kind+"_"+suffix+".png","collision":"none"})
	for role in ["player","shop","warehouse","contracts","prepare","relations","iris","result","training","dummy"]:
		result.append({"id":"camp:"+role,"name":"营地 · "+role,"layer":"markers","category":"营地交互点","model":role,"size":[1,1],"path":"res://assets/room_mode/fx/enemy_spawn.png","collision":"none"})
	result.append_array(SuppliedMapAssets.entries())
	result.append_array(RoomSceneArtCatalog.entries())
	return result

static func get_entry(asset_id: String) -> Dictionary:
	if asset_id.begins_with("scene:"):return RoomSceneArtCatalog.get_entry(asset_id)
	if asset_id.begins_with("supplied:"):return SuppliedMapAssets.get_entry(asset_id)
	for entry in entries():
		if entry.id==asset_id:return entry
	return {}

static func available(entry: Dictionary) -> bool:
	return not entry.is_empty() and ResourceLoader.exists(str(entry.get("path","")))

static func texture(asset_id: String) -> Texture2D:
	if asset_id.begins_with("supplied:"):return SuppliedMapAssets.texture(asset_id)
	var entry := get_entry(asset_id)
	if not available(entry):return null
	return load(str(entry.path)) as Texture2D

static func is_service(asset_id: String) -> bool:
	return asset_id.begins_with("service:") or (asset_id.begins_with("scene:") and str(get_entry(asset_id).get("collision",""))=="service")

static func service_config(entry: Dictionary) -> Dictionary:
	var asset := get_entry(str(entry.get("asset_id","")))
	var config: Dictionary = entry.get("config",{}) if entry.get("config",{}) is Dictionary else {}
	return {"offset_px":config.get("offset_px",[0,0]),"width_px":config.get("width_px",asset.get("width_px",36)),"depth_px":config.get("depth_px",asset.get("depth_px",18))}

static func service_position(entry: Dictionary) -> Vector2:
	var config := service_config(entry)
	return (Vector2(entry.at[0],entry.at[1])+Vector2.ONE*0.5)*36+Vector2(config.offset_px[0],config.offset_px[1])

static func service_footprint(entry: Dictionary) -> Rect2:
	var config := service_config(entry)
	var span := float(config.width_px)*0.78
	return Rect2(service_position(entry)-Vector2(span*0.5,float(config.depth_px)),Vector2(span,float(config.depth_px)))

static func service_art_rect(entry: Dictionary, image_size: Vector2) -> Rect2:
	var dimensions := image_size*(float(service_config(entry).width_px)/maxf(1,image_size.x))
	return Rect2(service_position(entry)-Vector2(dimensions.x*0.5,dimensions.y),dimensions)
