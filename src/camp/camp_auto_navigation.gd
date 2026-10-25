extends Node
## Temporary camp movement only; destinations come from live interaction geometry.
var world:Node
var active:=false
var goal:=Vector2.ZERO
var kind:=""
var target_id:=""
var title:=""
var _repath:=0.0
var _stalled:=0.0
var _last:=Vector2.INF
var _direction:=Vector2.ZERO
var _target_last:=Vector2.INF
const RADIUS:=16.0
func _ready()->void:process_physics_priority=-10
func start(value:String,id:String)->bool:
	cancel();kind=value;target_id=id
	var point:=target_position()
	if not point.is_finite():return false
	goal=_approach(point)
	if not goal.is_finite():return false
	title=world.FACILITY_NAMES.get(id,id) if value=="facility" else "训练稻草人" if value=="dummy" else "营地旅人" if value=="resident" else "营地大门"
	active=true;_repath=0;_stalled=0;_last=world.player.global_position;_target_last=point
	return true
func cancel()->void:
	active=false;_direction=Vector2.ZERO
	if is_instance_valid(world) and is_instance_valid(world.player):world.player.movement_override=Vector2.ZERO
func target_position()->Vector2:
	if kind=="facility" and world.facilities.has(target_id):return world.facility_guide_center(target_id)
	if kind=="dummy" and is_instance_valid(world.dummy):return world.dummy.position
	if kind=="door":
		var direction:=RoomGraph.cell(target_id)
		if direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:return world.level.door_point(direction,60)
	if kind=="resident" and is_instance_valid(world.residents_root):
		for npc in world.residents_root.get_children():
			if str(npc.resident_id)==target_id:return world.level.to_local(npc.global_position)
	return Vector2.INF
func _approach(point:Vector2)->Vector2:
	var level:RoomLevel=world.level
	var origin:Vector2=world.player.position
	var candidates:Array[Vector2]=[]
	var polygon:PackedVector2Array=level.scene_polygons.get(target_id,PackedVector2Array()) if kind=="facility" else PackedVector2Array()
	if polygon.size()>=3:
		var edge:=RoomSceneGeometry.closest_boundary_point(origin,polygon)
		candidates.append(edge+(edge-point).normalized()*34)
		for i in polygon.size():
			for weight in [.2,.5,.8]:
				var at:=polygon[i].lerp(polygon[(i+1)%polygon.size()],weight)
				candidates.append(at+(at-point).normalized()*34)
	else:
		if kind=="door":candidates.append(point)
		for i in 16:candidates.append(point+Vector2.RIGHT.rotated(i*TAU/16)*44)
	var best:=INF;var result:=Vector2.INF
	for at in candidates:
		var score:=origin.distance_squared_to(at)
		if score>=best or not level.body_clear(at,RADIUS,false) or not level.scene_navigation.spawn_reachable(level,at,RADIUS,false):continue
		if origin.distance_to(at)>3 and level.path_direction(origin,at,RADIUS,false).is_zero_approx():continue
		best=score;result=at
	return result
func _physics_process(dt:float)->void:
	if not active:return
	if not is_instance_valid(world.player) or world._departing:cancel();return
	var actor:RoomPlayer=world.player
	if UIFlow.has_screen() or TransitionLayer.busy:
		actor.movement_override=Vector2.ZERO;return
	var target:=target_position()
	if not target.is_finite():cancel();return
	var arrived:bool=world.facility_interaction_distance(target_id)<=60 if kind=="facility" else actor.position.distance_to(target)<=60 and world.level.sight(actor.position,target)
	if arrived:cancel();return
	_stalled=_stalled+dt if actor.position.distance_to(_last)<.15 else 0.0
	_last=actor.position;_repath-=dt
	if _stalled>3:cancel();return
	if _repath<=0:
		_repath=.25
		# Keep a stable approach side around a building. Only a moving resident
		# or changed geometry requires another destination search.
		if target.distance_to(_target_last)>28 or not world.level.body_clear(goal,RADIUS,false):
			goal=_approach(target);_target_last=target
		if not goal.is_finite():cancel();return
		_direction=world.level.path_direction(actor.position,goal,RADIUS,false)
		if actor.test_move(actor.global_transform,_direction*18):
			var desired:=_direction;_direction=Vector2.ZERO
			for turn in [PI/4,-PI/4,PI/2,-PI/2,PI]:
				var candidate:=desired.rotated(turn)
				if not actor.test_move(actor.global_transform,candidate*20) and world.level.segment_clear(actor.position,actor.position+candidate*20,RADIUS,false):_direction=candidate;break
	actor.movement_override=_direction
func _input(event:InputEvent)->void:
	if not active or UIFlow.has_screen():return
	for action in [&"room_left",&"room_right",&"room_up",&"room_down",&"dash"]:
		if InputMap.has_action(action) and event.is_action_pressed(action):cancel();return
	if event is InputEventScreenDrag and MobileControls.enabled():cancel()
	if event is InputEventJoypadMotion and absf(event.axis_value)>.25:cancel()
func _exit_tree()->void:cancel()
