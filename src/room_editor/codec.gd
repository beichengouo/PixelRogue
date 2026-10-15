class_name RoomTemplateCodec
extends RefCounted
const FORMAT := "pixelrogue.room"
const VERSION := 1
const LAYERS := ["ground","decor","obstacles","entities","markers","water"]
static var _layout_cache:Dictionary={}
static var _layout_cache_hits:=0
static var _layout_cache_misses:=0

static func is_player_save(path: String) -> bool:
	var filename := path.get_file().to_lower()
	for reserved in ["pixel_rogue_save.json","pixel_rogue_story.json"]:
		if filename==reserved or filename.begins_with(reserved+"."):return true
	return false

static func blank(size := Vector2i(23,13), kind := "normal", theme := "forest") -> Dictionary:
	var layers := {}
	for name_value in LAYERS:layers[name_value]=[]
	var data := {"format":FORMAT,"schema_version":VERSION,"id":"room_custom","revision":1,"name":"新房间","room_kinds":[kind],"theme":theme,"tags":[],"selection_weight":1.0,"grid":{"cell_px":36,"size":[size.x,size.y]},"base_ground":"floor:grass","layers":layers,"ports":[{"id":"north","side":"north","at":[int(size.x/2),0],"approach_width":3},{"id":"east","side":"east","at":[size.x-1,int(size.y/2)],"approach_width":3},{"id":"south","side":"south","at":[int(size.x/2),size.y-1],"approach_width":3},{"id":"west","side":"west","at":[0,int(size.y/2)],"approach_width":3}]}
	if kind in ["shop","tavern"]:data.service_layout=true
	return data

static func read_file(path: String) -> Dictionary:
	if is_player_save(path):return {}
	if not FileAccess.file_exists(path):return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

static func write_file(path: String, data: Dictionary) -> Error:
	if is_player_save(path):return ERR_UNAUTHORIZED
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data,"\t"));file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK:return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))

static func to_layout(template: Dictionary) -> Dictionary:
	if template.is_empty():return {}
	# Only pure template data is cached. Room deltas and live nodes remain per room.
	var scene_id:=str(template.get("scene_art",""))
	var scene_path:=RoomSceneArtCatalog.ROOT+scene_id+"/scene.json"
	var scene_signature:=FileAccess.get_md5(scene_path) if not scene_id.is_empty() and FileAccess.file_exists(scene_path) else ""
	var key:=(JSON.stringify(template)+scene_signature).md5_text()
	if _layout_cache.has(key):
		_layout_cache_hits+=1
		return _layout_cache[key].duplicate(true)
	_layout_cache_misses+=1
	var result:=_build_layout(template)
	if not result.is_empty():
		if _layout_cache.size()>=64:_layout_cache.clear()
		_layout_cache[key]=result.duplicate(true)
	return result

static func _build_layout(template:Dictionary)->Dictionary:
	if not RoomTemplateValidator.load_errors(template).is_empty():return {}
	var size: Array = template.grid.size
	var effective_bounds := RoomEditorCollision.bounds(template)
	var result := {"version":2,"crates":[],"stones":[],"props":[],"decor":[],"water":[],"ground":[],"models":{},"motif":0,"size":size.duplicate(),"ports":template.ports.duplicate(true),"markers":template.layers.markers.duplicate(true),"entities":template.layers.entities.duplicate(true),"template_id":template.id,"template_revision":template.revision,"room_rect":[effective_bounds.position.x,effective_bounds.position.y,effective_bounds.size.x,effective_bounds.size.y],"visual_room_rect":[0,0,int(size[0])*36,int(size[1])*36],"theme":template.theme,"base_ground":str(template.base_ground).trim_prefix("floor:")}
	var painted := {}
	var scene_definition:=RoomEditorCollision.definition(template)
	if not scene_definition.is_empty():
		result.scene_art=str(template.get("scene_art",""))
		result.scene_effects=scene_definition.get("effects",{}).duplicate(true)
		result.scene_objects=scene_definition.get("objects",[]).duplicate(true)
		result.scene_water_polygons_px=scene_definition.get("surface_water_polygons_px",[]).duplicate(true)
		if template.get("scene_collision_overrides",{}).has("water"):result.scene_water_collision_override=true
		for item in result.scene_objects:
			if not str(item.get("texture","")).begins_with("res://"):item.texture=RoomSceneArtCatalog.ROOT+result.scene_art+"/"+str(item.get("texture",""))
		var building:Dictionary=scene_definition.get("service_building",{})
		if not building.is_empty():
			result.service_layout=true
			result.service_props=[{"id":str(building.get("id","scene_building")),"asset":str(building.get("asset","")),"texture_path":RoomSceneArtCatalog.ROOT+result.scene_art+"/"+str(building.get("texture","")),"position_px":building.get("position_px",[]).duplicate(true),"width_px":float(building.get("width_px",180)),"depth_px":float(building.get("depth_px",66)),"collision_polygon_px":building.get("collision_polygon_px",[]).duplicate(true),"collision_disabled":template.get("scene_collision_overrides",{}).has("service_building") and building.get("collision_polygon_px",[]).is_empty(),"role":"building"}]
	if not result.has("scene_objects"):result.scene_objects=[]
	for entry in template.layers.ground:painted["%d,%d" % [int(entry.at[0]),int(entry.at[1])]]=entry
	for y in int(size[1]):
		for x in int(size[0]):
			var id := "%d,%d" % [x,y]
			var material: String = str(painted[id].asset_id if painted.has(id) else template.base_ground).trim_prefix("floor:")
			result.ground.append({"at":[x,y],"kind":material})
	for entry in template.layers.obstacles:
		var asset := RoomEditorCatalog.get_entry(str(entry.asset_id))
		if str(entry.asset_id).begins_with("scene:") and asset.has("collision_polygon_px"):
			result.scene_objects.append(_placed_scene_object(entry,asset,template))
			continue
		var prop := {"id":entry.id,"asset_id":entry.asset_id,"at":entry.at.duplicate(),"size":asset.size.duplicate(),"kind":asset.kind,"model":asset.model}
		result.props.append(prop)
		for y in int(asset.size[1]):
			for x in int(asset.size[0]):
				var at: Array = [int(entry.at[0])+x,int(entry.at[1])+y]
				if asset.kind=="crate":result.crates.append(at)
				else:result.stones.append(at)
				result.models["%d,%d" % [at[0],at[1]]]=asset.model
	for entry in template.layers.decor:
		var asset := RoomEditorCatalog.get_entry(str(entry.asset_id))
		if RoomEditorCatalog.is_service(str(entry.asset_id)):
			result.service_layout=true
			if not result.has("service_props"):result.service_props=[]
			var config := RoomEditorCatalog.service_config(entry)
			var position := RoomEditorCatalog.service_position(entry)
			var overridden: bool = template.get("scene_collision_overrides",{}).get("placed",{}).has(str(entry.id))
			result.service_props.append({"id":entry.id,"asset":asset.model,"asset_id":entry.asset_id,"position_px":[position.x,position.y],"width_px":config.width_px,"depth_px":config.depth_px,"collision_polygon_px":RoomEditorCollision.shape(template,"placed:"+str(entry.id)) if overridden or str(entry.asset_id).begins_with("scene:") else asset.get("collision_polygon_px",[]).duplicate(true),"collision_disabled":overridden and RoomEditorCollision.shape(template,"placed:"+str(entry.id)).is_empty(),"role":"building" if str(asset.model).begins_with("building_") else "prop"})
			continue
		if str(entry.asset_id).begins_with("scene:") and asset.has("collision_polygon_px"):
			result.scene_objects.append(_placed_scene_object(entry,asset,template))
			continue
		result.decor.append({"id":entry.id,"asset_id":entry.asset_id,"at":entry.at.duplicate(),"size":asset.size.duplicate(),"model":asset.model,"path":asset.path,"config":entry.get("config",{}).duplicate(true)})
	for entry in template.layers.entities:
		var asset:=RoomEditorCatalog.get_entry(str(entry.asset_id))
		if str(entry.asset_id).begins_with("scene:") and asset.has("collision_polygon_px"):
			result.scene_objects.append(_placed_scene_object(entry,asset,template))
			result.entities=result.entities.filter(func(item):return str(item.id)!=str(entry.id))
	if template.get("service_layout",false):
		result.service_layout=true
		if not result.has("service_props"):result.service_props=[]
	for entry in template.layers.water:result.water.append(entry.at.duplicate())
	return result

static func _placed_scene_object(entry:Dictionary,asset:Dictionary,template:Dictionary)->Dictionary:
	var config:Dictionary=entry.get("config",{})
	var offset:Array=config.get("offset_px",[0,0])
	var point:Vector2=RoomLayout.center(Vector2i(int(entry.at[0]),int(entry.at[1])))+Vector2(float(offset[0]),float(offset[1]))
	var collision:=str(asset.get("collision","none"))
	var kind:="crate" if collision=="crate" or str(asset.get("kind",""))=="crate" else ("stone" if collision in ["solid","stone"] else ("light" if collision=="light" else "decor"))
	var object:={"id":str(entry.id),"kind":kind,"position_px":[point.x,point.y],"texture":str(asset.path),"render_width_px":float(asset.get("render_width_px",asset.get("width_px",36))),"collision_polygon_px":RoomEditorCollision.shape(template,"placed:"+str(entry.id))}
	if kind=="light":
		var light:Dictionary=asset.get("light",{}).duplicate(true)
		light.merge(config,true)
		light.kind=str(config.get("kind",light.get("kind",asset.get("model","lamp"))))
		object.light=light
	return object
