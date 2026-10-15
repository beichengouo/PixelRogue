class_name RoomEditorCollision
extends RefCounted

## Collision edits belong to a template, never to a shared scene.json.
## Polygon coordinates use the same local coordinates as runtime objects;
## water polygons are in room world pixels.
static func definition(data: Dictionary) -> Dictionary:
	var scene := RoomSceneArtCatalog.definition(str(data.get("scene_art", ""))).duplicate(true)
	var overrides: Dictionary = data.get("scene_collision_overrides", {}) if data.get("scene_collision_overrides", {}) is Dictionary else {}
	var objects: Dictionary = overrides.get("objects", {}) if overrides.get("objects", {}) is Dictionary else {}
	for item in scene.get("objects", []):
		if objects.has(str(item.get("id", ""))) and objects[str(item.id)] is Array:item.collision_polygon_px=objects[str(item.id)].duplicate(true)
	if scene.has("service_building") and overrides.has("service_building") and overrides.service_building is Array:
		scene.service_building.collision_polygon_px=overrides.service_building.duplicate(true)
	if overrides.has("water") and overrides.water is Array:scene.surface_water_polygons_px=overrides.water.duplicate(true)
	return scene

static func targets(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"key":"room_bounds","label":"地图外边界 · 四边 / 四角"}]
	var scene := definition(data)
	for item in scene.get("objects", []):
		var id := str(item.get("id", ""))
		if not id.is_empty():result.append({"key":"object:"+id,"label":"场景物件 · "+id})
	if not scene.get("service_building", {}).is_empty():result.append({"key":"service_building","label":"场景建筑"})
	for index in scene.get("surface_water_polygons_px", []).size():result.append({"key":"water:%d" % index,"label":"水面 %d" % (index+1)})
	for layer in ["decor", "obstacles", "entities"]:
		for entry in data.get("layers", {}).get(layer, []):
			if str(entry.get("asset_id", "")).begins_with("scene:") or RoomEditorCatalog.is_service(str(entry.get("asset_id", ""))):
				result.append({"key":"placed:"+str(entry.id),"label":"放置物件 · "+str(entry.asset_id)+" · "+str(entry.id)})
	return result

static func bounds(data: Dictionary) -> Rect2:
	var size: Array = data.get("grid", {}).get("size", [23,13])
	var original := Rect2(Vector2.ZERO,Vector2(float(size[0]),float(size[1]))*36.0)
	var raw: Variant = data.get("room_bounds_override", [])
	if raw is Array and raw.size()==4:
		var valid := true
		for value in raw:
			if not (value is int or value is float) or not is_finite(float(value)):valid=false
		if valid:return Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
	return original

static func bounds_error(data: Dictionary) -> String:
	if not data.has("room_bounds_override"):return ""
	var raw: Variant = data.room_bounds_override
	if not raw is Array or raw.size()!=4:return "地图外边界须为 [x,y,宽,高]"
	for value in raw:
		if not (value is int or value is float) or not is_finite(float(value)):return "地图外边界坐标无效"
	var original: Array = data.get("grid", {}).get("size", [23,13])
	var outer := Rect2(Vector2.ZERO,Vector2(float(original[0]),float(original[1]))*36.0)
	var candidate := bounds(data)
	if candidate.size.x<288.0 or candidate.size.y<216.0:return "地图外边界至少 288×216 像素"
	if not outer.encloses(candidate):return "地图外边界必须位于原地图范围内"
	return ""

static func bounds_handles(data: Dictionary) -> Array[Vector2]:
	var rect := bounds(data)
	var center := rect.get_center()
	return [rect.position,Vector2(center.x,rect.position.y),Vector2(rect.end.x,rect.position.y),Vector2(rect.end.x,center.y),rect.end,Vector2(center.x,rect.end.y),Vector2(rect.position.x,rect.end.y),Vector2(rect.position.x,center.y)]

static func moved_bounds(data: Dictionary, handle: int, point: Vector2) -> Array:
	var rect := bounds(data)
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	var size: Array = data.get("grid", {}).get("size", [23,13])
	var limit := Vector2(float(size[0]),float(size[1]))*36.0
	var pixel := Vector2(roundf(point.x),roundf(point.y))
	if handle in [0,6,7]:left=clampf(pixel.x,0.0,right-288.0)
	if handle in [2,3,4]:right=clampf(pixel.x,left+288.0,limit.x)
	if handle in [0,1,2]:top=clampf(pixel.y,0.0,bottom-216.0)
	if handle in [4,5,6]:bottom=clampf(pixel.y,top+216.0,limit.y)
	return [left,top,right-left,bottom-top]

static func shape(data: Dictionary, key: String) -> Array:
	var scene := definition(data)
	if key.begins_with("object:"):
		for item in scene.get("objects", []):
			if str(item.get("id", ""))==key.trim_prefix("object:"):return item.get("collision_polygon_px", []).duplicate(true)
	elif key=="service_building":return scene.get("service_building", {}).get("collision_polygon_px", []).duplicate(true)
	elif key.begins_with("water:"):
		var index := int(key.trim_prefix("water:"))
		var shapes: Array = scene.get("surface_water_polygons_px", [])
		if index>=0 and index<shapes.size():return shapes[index].duplicate(true)
	elif key.begins_with("placed:"):
		var found := placed(data,key.trim_prefix("placed:"))
		if not found.is_empty():
			var overrides: Dictionary = data.get("scene_collision_overrides", {}).get("placed", {})
			if overrides.has(str(found.id)):return overrides[str(found.id)].duplicate(true)
			var asset := RoomEditorCatalog.get_entry(str(found.asset_id))
			if RoomEditorCatalog.is_service(str(found.asset_id)) and not asset.has("collision_polygon_px"):
				var config := RoomEditorCatalog.service_config(found)
				var half_width := float(config.width_px)*0.39
				var depth := float(config.depth_px)
				return [[-half_width,-depth],[half_width,-depth],[half_width,0],[-half_width,0]]
			return asset.get("collision_polygon_px", []).duplicate(true)
	return []

static func origin(data: Dictionary, key: String) -> Vector2:
	var scene := definition(data)
	if key.begins_with("object:"):
		for item in scene.get("objects", []):
			if str(item.get("id", ""))==key.trim_prefix("object:"):return _point(item.get("position_px", [0,0]))
	elif key=="service_building":return _point(scene.get("service_building", {}).get("position_px", [0,0]))
	elif key.begins_with("placed:"):
		var entry := placed(data,key.trim_prefix("placed:"))
		if not entry.is_empty():
			var offset: Array = entry.get("config", {}).get("offset_px", [0,0])
			return RoomLayout.center(Vector2i(int(entry.at[0]),int(entry.at[1])))+_point(offset)
	return Vector2.ZERO

static func placed(data: Dictionary, id: String) -> Dictionary:
	for layer in ["decor", "obstacles", "entities"]:
		for entry in data.get("layers", {}).get(layer, []):
			if str(entry.get("id", ""))==id:return entry
	return {}

static func assign(data: Dictionary, key: String, polygon: Array) -> void:
	if not data.has("scene_collision_overrides"):data.scene_collision_overrides={}
	var overrides: Dictionary = data.scene_collision_overrides
	if key.begins_with("object:"):
		if not overrides.has("objects"):overrides.objects={}
		overrides.objects[key.trim_prefix("object:")]=polygon.duplicate(true)
	elif key=="service_building":overrides.service_building=polygon.duplicate(true)
	elif key.begins_with("placed:"):
		if not overrides.has("placed"):overrides.placed={}
		overrides.placed[key.trim_prefix("placed:")]=polygon.duplicate(true)
	elif key.begins_with("water:"):
		if not overrides.has("water"):overrides.water=definition(data).get("surface_water_polygons_px", []).duplicate(true)
		var index := int(key.trim_prefix("water:"))
		if index>=0 and index<overrides.water.size():overrides.water[index]=polygon.duplicate(true)

static func restore(data: Dictionary, key: String) -> void:
	var overrides: Dictionary = data.get("scene_collision_overrides", {})
	if key.begins_with("object:"):overrides.get("objects", {}).erase(key.trim_prefix("object:"))
	elif key=="service_building":overrides.erase("service_building")
	elif key.begins_with("placed:"):overrides.get("placed", {}).erase(key.trim_prefix("placed:"))
	elif key.begins_with("water:"):
		var defaults: Array = RoomSceneArtCatalog.definition(str(data.get("scene_art", ""))).get("surface_water_polygons_px", [])
		var index := int(key.trim_prefix("water:"))
		if index<defaults.size():assign(data,key,defaults[index])
		else:delete_water(data,index)

static func add_water(data: Dictionary) -> String:
	if not data.has("scene_collision_overrides"):data.scene_collision_overrides={}
	var overrides: Dictionary = data.scene_collision_overrides
	if not overrides.has("water"):overrides.water=definition(data).get("surface_water_polygons_px", []).duplicate(true)
	overrides.water.append([])
	return "water:%d" % (overrides.water.size()-1)

static func delete_water(data: Dictionary, index: int) -> void:
	var overrides: Dictionary = data.get("scene_collision_overrides", {})
	if not overrides.has("water"):overrides.water=definition(data).get("surface_water_polygons_px", []).duplicate(true)
	if index>=0 and index<overrides.water.size():overrides.water.remove_at(index)

static func valid_polygon(raw: Variant) -> String:
	if not raw is Array:return "碰撞轮廓必须是点数组"
	if raw.is_empty():return ""
	if raw.size()<3 or raw.size()>64:return "碰撞轮廓需要 3～64 个点；清空可禁用"
	var points := PackedVector2Array()
	for pair in raw:
		if not pair is Array or pair.size()!=2:return "碰撞点须为 [x,y]"
		for number in pair:
			if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number))>4096:return "碰撞点坐标无效"
		points.append(_point(pair))
	var twice_area := 0.0
	for index in points.size():twice_area+=points[index].cross(points[(index+1)%points.size()])
	if absf(twice_area)<2.0:return "碰撞轮廓面积过小"
	for a in points.size():
		var next_a := (a+1)%points.size()
		if points[a].distance_to(points[next_a])<1.0:return "碰撞点过近"
		for b in range(a+1,points.size()):
			var next_b := (b+1)%points.size()
			if a==b or next_a==b or next_b==a:continue
			if Geometry2D.segment_intersects_segment(points[a],points[next_a],points[b],points[next_b])!=null:return "碰撞轮廓不能自交"
	return ""

static func override_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var overrides: Variant = data.get("scene_collision_overrides", {})
	if not overrides is Dictionary:return ["scene_collision_overrides 必须为对象"]
	var scene := RoomSceneArtCatalog.definition(str(data.get("scene_art", "")))
	var known := {}
	for item in scene.get("objects", []):known[str(item.get("id", ""))]=true
	if not overrides.get("objects", {}) is Dictionary:errors.append("物件碰撞覆盖须为对象")
	else:
		for id in overrides.get("objects", {}):
			if not known.has(str(id)):errors.append("碰撞覆盖物件不存在："+str(id))
			var error := valid_polygon(overrides.objects[id])
			if not error.is_empty():errors.append(str(id)+"："+error)
	if overrides.has("service_building"):
		if scene.get("service_building", {}).is_empty():errors.append("碰撞覆盖建筑不存在")
		var error := valid_polygon(overrides.service_building)
		if not error.is_empty():errors.append("场景建筑："+error)
	if overrides.has("water"):
		if not overrides.water is Array:errors.append("水面碰撞须为多边形数组")
		else:
			for shape in overrides.water:
				var error := valid_polygon(shape)
				if not error.is_empty():errors.append("水面："+error)
	if not overrides.get("placed", {}) is Dictionary:errors.append("放置物件碰撞覆盖须为对象")
	else:
		for id in overrides.get("placed", {}):
			var entry := placed(data,str(id))
			if entry.is_empty() or (not str(entry.get("asset_id", "")).begins_with("scene:") and not RoomEditorCatalog.is_service(str(entry.get("asset_id", "")))):errors.append("放置物件碰撞覆盖目标不存在："+str(id))
			var error := valid_polygon(overrides.placed[id])
			if not error.is_empty():errors.append(str(id)+"："+error)
	return errors

static func _point(pair: Array) -> Vector2:
	return Vector2(float(pair[0]),float(pair[1]))
