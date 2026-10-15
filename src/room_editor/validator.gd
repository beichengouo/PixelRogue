class_name RoomTemplateValidator
extends RefCounted
const SIDES := {"north":Vector2i.DOWN,"east":Vector2i.LEFT,"south":Vector2i.UP,"west":Vector2i.RIGHT}

static func validate(data: Dictionary) -> Array[String]:
	var structural := load_errors(data)
	if not structural.is_empty():return structural
	var errors: Array[String] = []
	if data.get("format","")!=RoomTemplateCodec.FORMAT or int(data.get("schema_version",0))!=1:return ["格式或版本不受支持"]
	if not data.get("grid",{}) is Dictionary:return ["缺少网格定义"]
	var raw: Variant = data.grid.get("size",[])
	if not _pair(raw):return ["房间尺寸必须是两个整数"]
	var size := Vector2i(int(raw[0]),int(raw[1]))
	var is_camp:bool=data.get("room_kinds",[]) is Array and data.get("room_kinds",[]).has("camp")
	if is_camp:
		if size.x<19 or size.x>46 or size.y<11 or size.y>26:errors.append("营地尺寸须为 19～46 × 11～26")
	elif size.x<19 or size.x>31 or size.y<11 or size.y>19:errors.append("房间尺寸须为 19～31 × 11～19")
	var bounds_error := RoomEditorCollision.bounds_error(data)
	if not bounds_error.is_empty():errors.append(bounds_error)
	var bounds := RoomEditorCollision.bounds(data)
	var custom_bounds := data.has("room_bounds_override")
	if int(data.grid.get("cell_px",0))!=36:errors.append("网格必须为36像素")
	if str(data.get("id","")).is_empty():errors.append("缺少模板ID")
	if int(data.get("revision",0))<1:errors.append("revision必须为正整数")
	if not data.get("room_kinds",[]) is Array or data.get("room_kinds",[]).is_empty():errors.append("缺少房间类别")
	elif data.room_kinds.any(func(kind):return str(kind) not in ["normal","elite","reward","game","boss","boss_rush","shop","tavern","camp","altar","trial","event"]):errors.append("房间类别不受支持")
	if str(data.get("theme","")) not in ["forest","wetland","ruin"]:errors.append("主题不受支持")
	if not data.get("tags",[]) is Array:errors.append("tags须为数组")
	var weight: Variant = data.get("selection_weight",1)
	if not (weight is int or weight is float) or float(weight)<0:errors.append("抽取权重须为非负数")
	var base := RoomEditorCatalog.get_entry(str(data.get("base_ground","")))
	if base.get("layer","")!="ground" or not RoomEditorCatalog.available(base):errors.append("默认地面资源无效")
	if not data.get("layers",{}) is Dictionary:return errors+["缺少图层"]
	var blocked := {}
	var ids := {}
	var marker_cells: Array[Vector2i] = []
	var service_rects: Array[Rect2] = []
	var scene_polygons:Array[PackedVector2Array]=[]
	var buildings: Array[Dictionary] = []
	var collision_errors := RoomEditorCollision.override_errors(data)
	if not collision_errors.is_empty():return errors+collision_errors
	var scene_definition:=RoomEditorCollision.definition(data)
	var exact_water:bool=not scene_definition.get("surface_water_polygons_px",[]).is_empty() or data.get("scene_collision_overrides",{}).has("water")
	for item in scene_definition.get("objects",[]):
		var pair:Array=item.get("position_px",[])
		if pair.size()==2:
			var shape:=RoomSceneGeometry.polygon(item.get("collision_polygon_px",[]),Vector2(float(pair[0]),float(pair[1])))
			if shape.size()>=3:scene_polygons.append(shape)
	for shape in scene_definition.get("surface_water_polygons_px",[]):
		var polygon:=RoomSceneGeometry.polygon(shape)
		if polygon.size()>=3:scene_polygons.append(polygon)
	var authored_building:Dictionary=scene_definition.get("service_building",{})
	var building_at:Array=authored_building.get("position_px",[])
	if not authored_building.is_empty():
		var building_id:=str(authored_building.get("id",""))
		var building_asset:=str(authored_building.get("asset",""))
		var building_texture:=str(authored_building.get("texture",""))
		if building_id.is_empty():errors.append("场景建筑缺少ID")
		else:ids[building_id]=true
		for object in scene_definition.get("objects",[]):
			if str(object.get("id",""))==building_id or (not building_texture.is_empty() and str(object.get("texture",""))==building_texture):errors.append("场景建筑不能同时作为普通物件")
		if building_asset not in ["building_shop","building_tavern"]:errors.append("场景建筑资源无效")
		elif building_asset.trim_prefix("building_") not in data.get("room_kinds",[]):errors.append("建筑与房间类别不匹配："+building_id)
		if not _number_pair(building_at):errors.append("场景建筑坐标无效")
		else:buildings.append({"id":building_id,"position_px":building_at,"manifest":true})
	if _number_pair(building_at):
		var building_shape:=RoomSceneGeometry.polygon(authored_building.get("collision_polygon_px",[]),Vector2(float(building_at[0]),float(building_at[1])))
		if building_shape.size()>=3:scene_polygons.append(building_shape)
		elif not authored_building.is_empty() and not data.get("scene_collision_overrides",{}).has("service_building"):errors.append("场景建筑缺少精确碰撞")
	for layer in RoomTemplateCodec.LAYERS:
		if not data.layers.has(layer) or not data.layers.get(layer,[]) is Array:errors.append("图层必须是数组："+layer);continue
		var occupied := {}
		for entry in data.layers.get(layer,[]):
			if not entry is Dictionary or not _pair(entry.get("at",[])):errors.append("条目坐标无效："+layer);continue
			if not entry.get("config",{}) is Dictionary:errors.append("实体配置须为对象："+layer)
			var id := str(entry.get("id",""))
			if id.is_empty() or ids.has(id):errors.append("条目ID缺失或重复："+id)
			ids[id]=true
			var asset := RoomEditorCatalog.get_entry(str(entry.get("asset_id","")))
			if asset.is_empty() or not RoomEditorCatalog.available(asset):errors.append("未知或缺失资源："+str(entry.get("asset_id","")));continue
			if asset.layer!=layer:errors.append("资源图层不匹配："+str(entry.asset_id));continue
			var at := Vector2i(int(entry.at[0]),int(entry.at[1]))
			if str(entry.asset_id).begins_with("scene:") and asset.has("collision_polygon_px"):
				var offset:Array=entry.get("config",{}).get("offset_px",[0,0])
				if offset.size()!=2:errors.append("像素偏移无效："+id);continue
				var point:=RoomLayout.center(at)+Vector2(float(offset[0]),float(offset[1]))
				var polygon:=RoomSceneGeometry.polygon(RoomEditorCollision.shape(data,"placed:"+id),point)
				if polygon.size()>=3:scene_polygons.append(polygon)
				if str(asset.get("model","")).begins_with("building_"):
					buildings.append(entry)
					if str(asset.model).trim_prefix("building_") not in data.room_kinds:errors.append("建筑与房间类别不匹配："+id)
				continue
			if RoomEditorCatalog.is_service(str(entry.asset_id)):
				var service_errors := service_config_errors(entry)
				if not service_errors.is_empty():errors.append_array(service_errors);continue
				if data.get("scene_collision_overrides",{}).get("placed",{}).has(id):
					var polygon := RoomSceneGeometry.polygon(RoomEditorCollision.shape(data,"placed:"+id),RoomEditorCatalog.service_position(entry))
					if polygon.size()>=3:scene_polygons.append(polygon)
				else:
					var rect := RoomEditorCatalog.service_footprint(entry)
					if not Rect2(Vector2.ZERO,Vector2(size)*36).encloses(rect):errors.append("建筑或道具碰撞越界："+id)
					for existing in service_rects:
						if existing.intersects(rect):errors.append("建筑或道具碰撞重叠："+id)
					service_rects.append(rect)
				if str(asset.model).begins_with("building_"):
					buildings.append(entry)
					if str(asset.model).trim_prefix("building_") not in data.room_kinds:errors.append("建筑与房间类别不匹配："+id)
				continue
			var footprint := Vector2i(int(asset.size[0]),int(asset.size[1]))
			for y in footprint.y:
				for x in footprint.x:
					var cell := at+Vector2i(x,y)
					if not Rect2i(Vector2i.ZERO,size).has_point(cell):errors.append("物块越界："+id)
					if occupied.has(cell):errors.append("同层物块重叠："+id)
					occupied[cell]=true
					if layer=="obstacles" or (layer=="water" and not exact_water):blocked[cell]=true
			if layer in ["entities","markers"] and not str(entry.asset_id).begins_with("light:") and str(asset.get("collision",""))!="light":marker_cells.append(at)
	if data.room_kinds.has("camp"):
		var roles:Dictionary={}
		for marker in data.layers.markers:
			var role:=str(marker.get("asset_id","")).trim_prefix("camp:")
			if roles.has(role):errors.append("营地交互点重复："+role)
			roles[role]=true
		for role in ["player","shop","warehouse","contracts","prepare","relations","iris","result","training","dummy"]:
			if not roles.has(role):errors.append("缺少营地固定交互点："+role)
		if not data.layers.entities.is_empty() or roles.has("spawn"):errors.append("营地不允许随机敌人或刷怪点")
	var anchors: Array[Vector2i] = []
	var sides := {}
	if not data.get("ports",[]) is Array:return errors+["入口必须是数组"]
	for port in data.get("ports",[]):
		if not port is Dictionary or not _pair(port.get("at",[])):errors.append("入口坐标无效");continue
		var side := str(port.get("side",""))
		if not SIDES.has(side) or sides.has(side):errors.append("每侧必须且只能有一个入口");continue
		sides[side]=true
		var at := Vector2i(int(port.at[0]),int(port.at[1]))
		if not Rect2i(Vector2i.ZERO,size).has_point(at):errors.append("入口越界："+side);continue
		if (side=="north" and at.y!=0) or (side=="south" and at.y!=size.y-1) or (side=="west" and at.x!=0) or (side=="east" and at.x!=size.x-1):errors.append("入口必须位于对应边界："+side)
		var inward: Vector2i = SIDES[side]
		var cross := Vector2i(-inward.y,inward.x)
		if custom_bounds:
			var tangent := (float(at.x)+0.5)*36.0 if side in ["north","south"] else (float(at.y)+0.5)*36.0
			var within := tangent>=bounds.position.x+54.0 and tangent<=bounds.end.x-54.0 if side in ["north","south"] else tangent>=bounds.position.y+54.0 and tangent<=bounds.end.y-54.0
			if not within:errors.append("入口超出收紧后的边界或离角落过近："+side)
			var edge := Vector2(tangent,bounds.position.y if side=="north" else bounds.end.y) if side in ["north","south"] else Vector2(bounds.position.x if side=="west" else bounds.end.x,tangent)
			# Match the authored entrance check below: a player-sized center
			# passage, followed by the shared 14/26-radius connectivity check.
			# Requiring three laterally displaced 26px bodies rejected unchanged
			# illustrated rooms merely because their bounds were made explicit.
			for depth_px in [18.0,54.0,90.0]:
				var probe: Vector2 = edge+Vector2(inward)*depth_px
				if not _point_clear(probe,size,blocked,12.0,service_rects,scene_polygons,bounds):
					errors.append("收紧后的入口被碰撞遮挡："+side);break
			var anchor_world := edge+Vector2(inward)*72.0
			anchors.append(Vector2i((anchor_world/36.0).floor()))
		else:
			for depth in 4:
				for offset in range(-1,2):
					var cell := at+inward*depth+cross*offset
					if not Rect2i(Vector2i.ZERO,size).has_point(cell) or blocked.has(cell):errors.append("入口须保留三格宽通道："+side)
					if offset==0 and depth<=2:
						for polygon in scene_polygons:
							if RoomSceneGeometry.circle_overlaps(RoomLayout.center(cell),12.0,polygon):errors.append("入口被精确碰撞遮挡："+side)
					for rect in service_rects:
						if rect.intersects(Rect2(Vector2(cell)*36,Vector2.ONE*36)):errors.append("建筑或道具遮挡入口通道："+side)
			anchors.append(at+inward*2)
	if sides.size()!=4:errors.append("必须预留四边入口以兼容未来连边")
	if buildings.size()>1:errors.append("服务房只能有一个交互建筑")
	for building in buildings:
		var doorway:Vector2=Vector2(float(building.position_px[0]),float(building.position_px[1]))+Vector2(0,34) if building.get("manifest",false) else RoomEditorCatalog.service_position(building)+Vector2(0,34)
		if not _point_clear(doorway,size,blocked,26.0,service_rects,scene_polygons,bounds):errors.append("建筑门口必须为玩家和大型角色保留通路")
		marker_cells.append(Vector2i(((doorway+Vector2(0,26))/36).floor()))
	if not errors.is_empty():return errors
	for radius in [14.0,26.0]:
		var reached := _reachable_scene(anchors[0],size,blocked,radius,service_rects,scene_polygons,bounds) if not scene_polygons.is_empty() else _reachable(anchors[0],size,blocked,radius,service_rects,[],bounds)
		for at in anchors+marker_cells:
			if not reached.has(at):errors.append("入口或实体/出生点不可达（半径%d）：%s" % [int(radius),str(at)])
		var isolated := false
		for y in size.y:
			for x in size.x:
				var at := Vector2i(x,y)
				if _clear(at,size,blocked,radius,service_rects,scene_polygons,bounds) and not reached.has(at):isolated=true
		if isolated:errors.append("存在无法从入口抵达的可站立区域（半径%d），随机出生可能被困" % int(radius))
	return errors

## Only data that cannot be read/rendered is rejected. Navigation, overlap,
## gate clearance and authored geometry remain advisory developer checks.
static func load_errors(data: Dictionary) -> Array[String]:
	if data.get("format","")!=RoomTemplateCodec.FORMAT or int(data.get("schema_version",0))!=1:return ["格式或版本不受支持"]
	if not data.get("grid") is Dictionary or not _pair(data.grid.get("size")):return ["缺少可读取的网格尺寸"]
	var size: Array = data.grid.size
	if float(size[0])<1 or float(size[1])<1 or float(size[0])>128 or float(size[1])>128:return ["网格尺寸超出可读取范围"]
	if not _number(data.grid.get("cell_px")) or not _number(data.get("selection_weight",1)):return ["无法读取网格单位或抽取权重"]
	for key in ["id","name","theme","base_ground"]:
		if not data.get(key) is String:return ["缺少文本字段："+key]
	if data.id.is_empty() or not _number(data.get("revision")):return ["缺少模板ID或revision"]
	for key in ["room_kinds","tags","ports"]:
		if not data.get(key) is Array:return ["字段须为数组："+key]
	if data.room_kinds.is_empty():return ["缺少房间类别"]
	if not data.room_kinds.all(func(kind:Variant)->bool:return kind is String):return ["房间类别须为文本"]
	if not data.get("layers") is Dictionary:return ["缺少图层"]
	for layer in RoomTemplateCodec.LAYERS:
		if not data.layers.get(layer) is Array:return ["图层须为数组："+layer]
		for entry in data.layers[layer]:
			if not entry is Dictionary or not _pair(entry.get("at")) or not entry.get("id") is String or not entry.get("asset_id") is String:return ["无法读取图层条目："+layer]
			var asset := RoomEditorCatalog.get_entry(entry.asset_id)
			if asset.is_empty():return ["无法读取资源："+entry.asset_id]
			var config: Variant = entry.get("config",{})
			if not config is Dictionary or not _number_pair(config.get("offset_px",[0,0])):return ["无法读取实体配置："+entry.id]
			for key in ["width_px","depth_px"]:
				if config.has(key) and (not _number(config[key]) or float(config[key])<=0):return ["无法读取物件尺寸："+entry.id]
	for port in data.ports:
		if not port is Dictionary or not _pair(port.get("at")) or not SIDES.has(str(port.get("side",""))):return ["无法读取进出口"]
		if not _number(port.get("approach_width",3)):return ["无法读取进出口宽度"]
	if data.has("room_bounds_override"):
		var bounds: Variant = data.room_bounds_override
		if not bounds is Array or bounds.size()!=4 or not bounds.all(_number):return ["无法读取外边界坐标"]
		if float(bounds[2])<=0 or float(bounds[3])<=0:return ["外边界宽高必须为正数"]
	var overrides: Variant = data.get("scene_collision_overrides",{})
	if not overrides is Dictionary:return ["碰撞覆盖须为对象"]
	for group in ["objects","placed"]:
		if not overrides.get(group,{}) is Dictionary:return ["碰撞覆盖分组须为对象"]
		for polygon in overrides.get(group,{}).values():
			if not _readable_polygon(polygon):return ["无法读取碰撞坐标"]
	if overrides.has("service_building") and not _readable_polygon(overrides.service_building):return ["无法读取建筑碰撞坐标"]
	if overrides.has("water"):
		if not overrides.water is Array:return ["水面碰撞须为数组"]
		for polygon in overrides.water:
			if not _readable_polygon(polygon):return ["无法读取水面碰撞坐标"]
	return []

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _readable_polygon(value: Variant) -> bool:
	return value is Array and value.all(_number_pair)

static func _pair(value: Variant) -> bool:
	return value is Array and value.size()==2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float) and float(value[0])==floorf(float(value[0])) and float(value[1])==floorf(float(value[1]))

static func _number_pair(value:Variant)->bool:
	return value is Array and value.size()==2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float) and is_finite(float(value[0])) and is_finite(float(value[1]))

static func service_config_errors(entry: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var config := RoomEditorCatalog.service_config(entry)
	var offset: Variant = config.offset_px
	if not offset is Array or offset.size()!=2:errors.append("offset_px 必须为两个像素数值")
	else:
		for value in offset:
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>36:errors.append("像素偏移须为 -36～36；大幅移动请拖动物块")
	var limit:=2048.0 if str(entry.get("asset_id","")).begins_with("scene:") else 288.0
	for key in ["width_px","depth_px"]:
		var value: Variant = config[key]
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)<=0 or float(value)>limit:errors.append("建筑/道具尺寸超出范围："+key)
	return errors

static func _clear(at: Vector2i, size: Vector2i, blocked: Dictionary, radius: float, service_rects: Array[Rect2] = [],polygons:Array[PackedVector2Array]=[],bounds:Rect2=Rect2()) -> bool:
	var point := (Vector2(at)+Vector2.ONE*0.5)*36
	return _point_clear(point,size,blocked,radius,service_rects,polygons,bounds)

static func _point_clear(point: Vector2, size: Vector2i, blocked: Dictionary, radius: float, service_rects: Array[Rect2],polygons:Array[PackedVector2Array]=[],bounds:Rect2=Rect2()) -> bool:
	if not _effective_rect(size,bounds).grow(-radius).has_point(point):return false
	for polygon in polygons:
		if RoomSceneGeometry.circle_overlaps(point,radius,polygon):return false
	for rect in service_rects:
		if rect.grow(radius).has_point(point):return false
	var at := Vector2i((point/36).floor())
	for y in range(at.y-1,at.y+2):
		for x in range(at.x-1,at.x+2):
			if not blocked.has(Vector2i(x,y)):continue
			var nearest := Vector2(clampf(point.x,x*36,(x+1)*36),clampf(point.y,y*36,(y+1)*36))
			if nearest.distance_squared_to(point)<=radius*radius:return false
	return true

static func _reachable(start: Vector2i, size: Vector2i, blocked: Dictionary, radius: float, service_rects: Array[Rect2] = [],polygons:Array[PackedVector2Array]=[],bounds:Rect2=Rect2()) -> Dictionary:
	var result := {}
	if not _clear(start,size,blocked,radius,service_rects,polygons,bounds):return result
	var pending: Array[Vector2i] = [start]
	result[start]=true
	var index := 0
	while index<pending.size():
		var at := pending[index];index+=1
		for direction: Vector2i in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next := at+direction
			if result.has(next) or not _clear(next,size,blocked,radius,service_rects,polygons,bounds):continue
			var crossing:=false
			for polygon in polygons:
				if RoomSceneGeometry.swept_circle_overlaps(RoomLayout.center(at),RoomLayout.center(next),radius,polygon):crossing=true;break
			if crossing:continue
			result[next]=true;pending.append(next)
	return result

static func _reachable_scene(start:Vector2i,size:Vector2i,blocked:Dictionary,radius:float,service_rects:Array[Rect2],polygons:Array[PackedVector2Array],bounds:Rect2=Rect2())->Dictionary:
	var result:Dictionary={}
	var origin:=RoomLayout.center(start)
	if not _point_clear(origin,size,blocked,radius,service_rects,polygons,bounds):return result
	var nodes:Dictionary={}
	for y in size.y*2:
		for x in size.x*2:
			var cell:=Vector2i(x,y)
			var point:=_scene_graph_point(cell,size,radius,bounds)
			if _point_clear(point,size,blocked,radius,service_rects,polygons,bounds):nodes[cell]=true
	var pending:Array[Vector2i]=[]
	var visited:Dictionary={}
	var start_cell:=Vector2i((origin/18.0).floor())
	for y in range(start_cell.y-3,start_cell.y+4):
		for x in range(start_cell.x-3,start_cell.x+4):
			var cell:=Vector2i(x,y)
			if nodes.has(cell) and _segment_clear_scene(origin,_scene_graph_point(cell,size,radius,bounds),size,blocked,radius,service_rects,polygons,bounds):
				visited[cell]=true;pending.append(cell)
	var index:=0
	while index<pending.size():
		var at:=pending[index];index+=1
		var point:=_scene_graph_point(at,size,radius,bounds)
		for direction:Vector2i in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
			var next:=at+direction
			if visited.has(next) or not nodes.has(next):continue
			var next_point:=_scene_graph_point(next,size,radius,bounds)
			if not _segment_clear_scene(point,next_point,size,blocked,radius,service_rects,polygons,bounds):continue
			visited[next]=true;pending.append(next)
	# Runtime starts at a 36px cell center but navigates on the half-offset
	# 18px lattice. A cell counts as reachable only if its center can join a
	# visited runtime node through the same body-sized segment check.
	for y in size.y:
		for x in size.x:
			var cell:=Vector2i(x,y)
			var center:=RoomLayout.center(cell)
			if not _point_clear(center,size,blocked,radius,service_rects,polygons,bounds):continue
			var graph_cell:=Vector2i((center/18.0).floor())
			var connected:=false
			for gy in range(graph_cell.y-3,graph_cell.y+4):
				for gx in range(graph_cell.x-3,graph_cell.x+4):
					var neighbor:=Vector2i(gx,gy)
					if not visited.has(neighbor):continue
					if _segment_clear_scene(center,_scene_graph_point(neighbor,size,radius,bounds),size,blocked,radius,service_rects,polygons,bounds):connected=true;break
				if connected:break
			if connected:result[cell]=true
	return result

static func _scene_graph_point(cell:Vector2i,size:Vector2i,radius:float,bounds:Rect2=Rect2())->Vector2:
	var inner:=_effective_rect(size,bounds).grow(-radius-0.1)
	var center:=(Vector2(cell)+Vector2.ONE*0.5)*18.0
	return Vector2(clampf(center.x,inner.position.x,inner.end.x),clampf(center.y,inner.position.y,inner.end.y))

static func _segment_clear_scene(from:Vector2,to:Vector2,size:Vector2i,blocked:Dictionary,radius:float,service_rects:Array[Rect2],polygons:Array[PackedVector2Array],bounds:Rect2=Rect2())->bool:
	for polygon in polygons:
		if RoomSceneGeometry.swept_circle_overlaps(from,to,radius,polygon):return false
	var steps:=maxi(1,ceili(from.distance_to(to)/8.0))
	for index in range(1,steps+1):
		if not _point_clear(from.lerp(to,float(index)/steps),size,blocked,radius,service_rects,polygons,bounds):return false
	return true

static func _effective_rect(size:Vector2i,bounds:Rect2)->Rect2:
	return bounds if bounds.size.x>0 and bounds.size.y>0 else Rect2(Vector2.ZERO,Vector2(size)*36.0)
