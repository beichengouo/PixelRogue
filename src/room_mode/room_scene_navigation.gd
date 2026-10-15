extends RefCounted
## Polygon navigation validates graph edges as well as node centers.
var graphs:Dictionary={}
const SHARED_GRAPH_LIMIT:=30
static var _shared:Dictionary={}
static var _lru:Array[String]=[]
static var shared_hits:=0
static var shared_builds:=0
func _geometry_key(room:Node,radius:float,flying:bool)->String:
	var doors:Array=[]
	for direction in room.door_directions:doors.append([direction,room.door_point(direction,90.0)])
	return var_to_bytes([radius,flying,room.room_rect,room.obstacles.keys(),room.deep_water.keys(),room.service_footprints,room.scene_polygons.values(),room.scene_water_polygons,room.scene_water_collision_override,doors]).hex_encode().sha256_text()
func _cached(room:Node,radius:float,flying:bool)->Dictionary:
	var key:=_geometry_key(room,radius,flying)
	if not _shared.has(key):return {}
	shared_hits+=1;_lru.erase(key);_lru.append(key)
	var result:Dictionary=_shared[key].duplicate(false)
	# Immutable graph topology is shared; potentially large route histories are
	# room-local and are never kept alive by this bounded cache.
	result.routes={};return result
func _remember(room:Node,radius:float,flying:bool,data:Dictionary)->Dictionary:
	var key:=_geometry_key(room,radius,flying)
	if not _shared.has(key):shared_builds+=1
	_lru.erase(key);_lru.append(key)
	var saved:=data.duplicate(false);saved.routes={};_shared[key]=saved
	while _lru.size()>SHARED_GRAPH_LIMIT:_shared.erase(_lru.pop_front())
	return data
func clear()->void:graphs.clear()
func spawn_reachable(room:Node,point:Vector2,radius:float,flying:bool)->bool:
	if not room.body_clear(point,radius,flying):return false
	var key:="%s:%s"%[radius,flying]
	if not graphs.has(key):graphs[key]=_build(room,radius,flying)
	var data:Dictionary=graphs[key]
	if int(data.main_component)<0:return false
	var cell:=Vector2i((point/18.0).floor())
	for y in range(cell.y-3,cell.y+4):
		for x in range(cell.x-3,cell.x+4):
			var neighbor:=Vector2i(x,y)
			if not data.cells.has(neighbor):continue
			var id:int=data.cells[neighbor]
			if data.components[id]!=data.main_component:continue
			if room.segment_clear(point,data.graph.get_point_position(id),radius,flying):return true
	return false
func main_spawn_point(room:Node,preferred:Vector2,avoid:Vector2,radius:float,flying:bool)->Vector2:
	var key:="%s:%s"%[radius,flying]
	if not graphs.has(key):graphs[key]=_build(room,radius,flying)
	var data:Dictionary=graphs[key]
	var best:=INF
	var result:=Vector2.ZERO
	for id in data.graph.get_point_ids():
		if data.components[id]!=data.main_component:continue
		var point:Vector2=data.graph.get_point_position(id)
		if point.distance_to(avoid)<=120:continue
		var distance:=point.distance_squared_to(preferred)
		if distance<best:best=distance;result=point
	if result!=Vector2.ZERO:return result
	for id in data.graph.get_point_ids():
		if data.components[id]!=data.main_component:continue
		var point:Vector2=data.graph.get_point_position(id)
		var distance:=point.distance_squared_to(preferred)
		if distance<best:best=distance;result=point
	return result
func direction(room:Node,from:Vector2,to:Vector2,radius:float,flying:bool)->Vector2:
	var key:="%s:%s"%[radius,flying]
	if not graphs.has(key):graphs[key]=_build(room,radius,flying)
	var graph:AStar2D=graphs[key].graph
	var cells:Dictionary=graphs[key].cells
	var routes:Dictionary=graphs[key].routes
	var components:Dictionary=graphs[key].components
	if graph.get_point_count()==0:return Vector2.ZERO
	var at:=Vector2i((from/18).floor())
	var starts:Array[int]=[]
	var reachable_components:Dictionary={}
	for y in range(at.y-3,at.y+4):
		for x in range(at.x-3,at.x+4):
			var cell:=Vector2i(x,y)
			if not cells.has(cell):continue
			var id:int=cells[cell]
			if not room.segment_clear(from,graph.get_point_position(id),radius,flying):continue
			starts.append(id)
			reachable_components[components[id]]=true
	if starts.is_empty():return Vector2.ZERO
	var goal_clear:bool=room.body_clear(to,radius,flying)
	var goal_id:=graph.get_closest_point(to)
	if not reachable_components.has(components[goal_id]) or (goal_clear and not room.segment_clear(graph.get_point_position(goal_id),to,radius,flying)):
		goal_id=-1
		var goal_distance:=INF
		for id in graph.get_point_ids():
			if not reachable_components.has(components[id]):continue
			var point:=graph.get_point_position(id)
			var distance:=point.distance_squared_to(to)
			if distance>=goal_distance or (goal_clear and not room.segment_clear(point,to,radius,flying)):continue
			goal_id=id;goal_distance=distance
	if goal_id<0:return Vector2.ZERO
	var best:=INF
	var route:=PackedVector2Array()
	for start_id in starts:
		if components[start_id]!=components[goal_id]:continue
		# Euclidean distance is a lower bound on every valid graph route.
		# Pruning cannot discard a shorter route, and avoids redundant A* work.
		var start:Vector2=graph.get_point_position(start_id)
		if from.distance_to(start)+start.distance_to(graph.get_point_position(goal_id))>=best:continue
		var route_key:=Vector2i(start_id,goal_id)
		if not routes.has(route_key):
			if routes.size()>=2048:routes.clear()
			var points:=graph.get_point_path(start_id,goal_id)
			var distance:=0.0
			for index in range(1,points.size()):distance+=points[index-1].distance_to(points[index])
			routes[route_key]={"points":points,"distance":distance}
		var path:PackedVector2Array=routes[route_key].points
		if path.is_empty():continue
		var cost:float=from.distance_to(path[0])+routes[route_key].distance
		if cost>=best:continue
		if cost<best:best=cost;route=path
	if route.is_empty():return Vector2.ZERO
	for index in range(mini(8,route.size()-1),-1,-1):
		if from.distance_to(route[index])<1:continue
		if room.segment_clear(from,route[index],radius,flying):return (route[index]-from).normalized()
	return Vector2.ZERO
func _build(room:Node,radius:float,flying:bool)->Dictionary:
	var cached:=_cached(room,radius,flying)
	if not cached.is_empty():return cached
	var graph:=AStar2D.new()
	var cells:Dictionary={}
	var rect:Rect2=room.room_rect
	var inner:=rect.grow(-radius-0.1)
	for y in range(floori(rect.position.y/18),ceili(rect.end.y/18)):
		for x in range(floori(rect.position.x/18),ceili(rect.end.x/18)):
			var center:=(Vector2(x,y)+Vector2.ONE*.5)*18
			var point:=Vector2(clampf(center.x,inner.position.x,inner.end.x),clampf(center.y,inner.position.y,inner.end.y))
			if not room.body_clear(point,radius,flying):continue
			var id:=graph.get_point_count();graph.add_point(id,point);cells[Vector2i(x,y)]=id
	for cell:Vector2i in cells:
		for offset in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i(1,1),Vector2i(-1,1)]:
			var neighbor:Vector2i=cell+offset
			if not cells.has(neighbor):continue
			if room.segment_clear(graph.get_point_position(cells[cell]),graph.get_point_position(cells[neighbor]),radius,flying):
				graph.connect_points(cells[cell],cells[neighbor])
	var components:Dictionary={}
	var component_id:=0
	for id in graph.get_point_ids():
		if components.has(id):continue
		var pending:Array[int]=[id]
		components[id]=component_id
		var index:=0
		while index<pending.size():
			var current:=pending[index];index+=1
			for neighbor in graph.get_point_connections(current):
				if components.has(neighbor):continue
				components[neighbor]=component_id;pending.append(neighbor)
		component_id+=1
	var component_sizes:Dictionary={}
	for id in components:component_sizes[components[id]]=int(component_sizes.get(components[id],0))+1
	var votes:Dictionary={}
	if room.has_method("door_point") and not room.door_directions.is_empty():
		for direction in room.door_directions:
			var anchor:Vector2=room.door_point(direction,90.0)
			if not room.body_clear(anchor,radius,flying):continue
			var at:=Vector2i((anchor/18.0).floor())
			var nearest:=INF
			var anchor_component:=-1
			for y in range(at.y-3,at.y+4):
				for x in range(at.x-3,at.x+4):
					var cell:=Vector2i(x,y)
					if not cells.has(cell):continue
					var id:int=cells[cell]
					var point:=graph.get_point_position(id)
					var distance:=anchor.distance_squared_to(point)
					if distance>=nearest or not room.segment_clear(anchor,point,radius,flying):continue
					nearest=distance;anchor_component=components[id]
			if anchor_component>=0:votes[anchor_component]=int(votes.get(anchor_component,0))+1
	var main_component:=-1
	var most_votes:=-1
	var largest:=-1
	for id in component_sizes:
		var count:int=votes.get(id,0)
		if count>most_votes or (count==most_votes and component_sizes[id]>largest):
			main_component=id;most_votes=count;largest=component_sizes[id]
	return _remember(room,radius,flying,{"graph":graph,"cells":cells,"routes":{},"components":components,"main_component":main_component})

func prepare(room:Node,radius:float,flying:bool,valid:Callable)->bool:
	var key:="%s:%s"%[radius,flying]
	if graphs.has(key):return true
	if flying and room.deep_water.is_empty() and room.scene_water_polygons.is_empty() and graphs.has("%s:false"%radius):graphs[key]=graphs["%s:false"%radius];return true
	var cached:=_cached(room,radius,flying)
	if not cached.is_empty():graphs[key]=cached;return true
	var data:Dictionary=await _build_async(room,radius,flying,valid)
	if data.is_empty():return false
	graphs[key]=data;return true
func _build_async(room:Node,radius:float,flying:bool,valid:Callable)->Dictionary:
	var frame_start:=Time.get_ticks_usec()
	var graph:=AStar2D.new()
	var cells:Dictionary={}
	var rect:Rect2=room.room_rect
	var inner:=rect.grow(-radius-0.1)
	for y in range(floori(rect.position.y/18),ceili(rect.end.y/18)):
		for x in range(floori(rect.position.x/18),ceili(rect.end.x/18)):
			if Time.get_ticks_usec()-frame_start>=3000:
				await room.get_tree().process_frame;frame_start=Time.get_ticks_usec()
				if not valid.is_null() and (not valid.is_valid() or not bool(valid.call())):return {}
			var center:=(Vector2(x,y)+Vector2.ONE*.5)*18
			var point:=Vector2(clampf(center.x,inner.position.x,inner.end.x),clampf(center.y,inner.position.y,inner.end.y))
			if not room.body_clear(point,radius,flying):continue
			var id:=graph.get_point_count();graph.add_point(id,point);cells[Vector2i(x,y)]=id
	for cell:Vector2i in cells:
		if Time.get_ticks_usec()-frame_start>=3000:
			await room.get_tree().process_frame;frame_start=Time.get_ticks_usec()
			if not valid.is_null() and (not valid.is_valid() or not bool(valid.call())):return {}
		for offset in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i(1,1),Vector2i(-1,1)]:
			var neighbor:Vector2i=cell+offset
			if not cells.has(neighbor):continue
			if room.segment_clear(graph.get_point_position(cells[cell]),graph.get_point_position(cells[neighbor]),radius,flying):
				graph.connect_points(cells[cell],cells[neighbor])
	var components:Dictionary={}
	var component_id:=0
	for id in graph.get_point_ids():
		if Time.get_ticks_usec()-frame_start>=3000:
			await room.get_tree().process_frame;frame_start=Time.get_ticks_usec()
			if not valid.is_null() and (not valid.is_valid() or not bool(valid.call())):return {}
		if components.has(id):continue
		var pending:Array[int]=[id]
		components[id]=component_id
		var index:=0
		while index<pending.size():
			if Time.get_ticks_usec()-frame_start>=3000:
				await room.get_tree().process_frame;frame_start=Time.get_ticks_usec()
				if not valid.is_null() and (not valid.is_valid() or not bool(valid.call())):return {}
			var current:=pending[index];index+=1
			for neighbor in graph.get_point_connections(current):
				if components.has(neighbor):continue
				components[neighbor]=component_id;pending.append(neighbor)
		component_id+=1
	var component_sizes:Dictionary={}
	for id in components:component_sizes[components[id]]=int(component_sizes.get(components[id],0))+1
	var votes:Dictionary={}
	if room.has_method("door_point") and not room.door_directions.is_empty():
		for direction in room.door_directions:
			var anchor:Vector2=room.door_point(direction,90.0)
			if not room.body_clear(anchor,radius,flying):continue
			var at:=Vector2i((anchor/18.0).floor())
			var nearest:=INF
			var anchor_component:=-1
			for y in range(at.y-3,at.y+4):
				for x in range(at.x-3,at.x+4):
					var cell:=Vector2i(x,y)
					if not cells.has(cell):continue
					var id:int=cells[cell]
					var point:=graph.get_point_position(id)
					var distance:=anchor.distance_squared_to(point)
					if distance>=nearest or not room.segment_clear(anchor,point,radius,flying):continue
					nearest=distance;anchor_component=components[id]
			if anchor_component>=0:votes[anchor_component]=int(votes.get(anchor_component,0))+1
	var main_component:=-1
	var most_votes:=-1
	var largest:=-1
	for id in component_sizes:
		var count:int=votes.get(id,0)
		if count>most_votes or (count==most_votes and component_sizes[id]>largest):
			main_component=id;most_votes=count;largest=component_sizes[id]
	return _remember(room,radius,flying,{"graph":graph,"cells":cells,"routes":{},"components":components,"main_component":main_component})
