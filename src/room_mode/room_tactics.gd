class_name RoomTactics
extends RefCounted
## Local crowd queries are shared per physics frame, never use the loot RNG.
var _frame:=-1
var _cells:Dictionary={}
func neighbors(room:RoomLevel,unit:Node2D)->Array[Node2D]:
	return _near_point(room,unit.global_position,unit)
func _near_point(room:RoomLevel,point:Vector2,ignore:Node2D)->Array[Node2D]:
	var frame:=Engine.get_physics_frames()
	if frame!=_frame:
		_frame=frame;_cells.clear()
		for other in room.get_tree().get_nodes_in_group("room_units"):
			if not is_instance_valid(other) or other.is_queued_for_deletion() or other.get("room")!=room or other.get("hp")<=0:continue
			var cell:=Vector2i((other.global_position/72).floor())
			if not _cells.has(cell):_cells[cell]=[]
			_cells[cell].append(other)
	var result:Array[Node2D]=[];var center:=Vector2i((point/72).floor())
	for y in range(center.y-1,center.y+2):
		for x in range(center.x-1,center.x+2):
			for other in _cells.get(Vector2i(x,y),[]):
				if is_instance_valid(other) and other!=ignore and not other.is_queued_for_deletion():result.append(other)
	return result
func occupied(room:RoomLevel,point:Vector2,radius:float,ignore:Node2D)->bool:
	for other in _near_point(room,point,ignore):
		var clearance:=radius+float(other.get_meta("unit_radius",12.0))+1
		if point.distance_squared_to(other.global_position)<clearance*clearance:return true
	return false
func separation(room:RoomLevel,unit:Node2D)->Vector2:
	var result:=Vector2.ZERO;var radius:=float(unit.get_meta("unit_radius",12.0))
	for other in neighbors(room,unit):
		var away:=unit.global_position-other.global_position;var desired:=radius+float(other.get_meta("unit_radius",12.0))+18
		var distance:=away.length()
		if distance>=desired:continue
		if distance<.01:away=Vector2.RIGHT.rotated(float(unit.get_instance_id()%32)*2.399);distance=.01
		result+=away.normalized()*(1-distance/desired)
	return result.limit_length(1)
func attack_position(room:RoomLevel,unit:Node2D,target:Node2D,ranged:bool,radius:float,flying:bool)->Vector2:
	var center:=target.global_position;var ring:=190.0 if ranged else radius+float(target.get_meta("unit_radius",12.0))+9.0
	var phase:=float(unit.get_instance_id()%32)*2.399963
	var best:=INF;var goal:=center
	for step in 16:
		var angle:=phase+step*TAU/16;var point:=center+Vector2.RIGHT.rotated(angle)*ring
		if not room.body_clear(point,radius,flying) or not room.sight(point,center):continue
		if ranged and not room.projectile_clear(point,center):continue
		var score:=unit.global_position.distance_squared_to(point)*.18+minf(step,16-step)*350.0
		if occupied(room,point,radius,unit):score+=12000
		if score<best:best=score;goal=point
	return goal
static func roam_goal(room:RoomLevel,unit:Node2D,rng:RandomNumberGenerator,radius:float,flying:bool)->Vector2:
	for attempt in 24:
		var bounds:=room.bounds().grow(-42)
		var point:=Vector2(rng.randf_range(bounds.position.x,bounds.end.x),rng.randf_range(bounds.position.y,bounds.end.y))
		if not room.body_clear(point,radius,flying) or not room.unit_position_clear(point,radius,unit):continue
		var near_gate:=false
		for direction in RoomGraph.DIRECTIONS:
			if room.door_point(direction).distance_to(point)<110:near_gate=true;break
		if near_gate:continue
		if room.path_direction(unit.global_position,point,radius,flying).is_zero_approx():continue
		return point
	return room.nearest_clear(room.bounds().get_center(),radius,flying)
