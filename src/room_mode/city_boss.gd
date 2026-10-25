class_name CityBoss
extends RoomBoss
## One main pattern at a time; all commands and targets survive snapshots.
var dash_left:=0.0
var dash_direction:=Vector2.RIGHT
var dash_destination:=Vector2.ZERO
var previous_pattern:=""
var recorded_pattern:=""
var recorded_target:=Vector2.ZERO
var recorded_aim:=Vector2.RIGHT
var recorded_circles:Array[Vector2]=[]
var phase_rotation_seen:=1
var pattern_last_time:=0.0
var construct_batch:=0
var construct_batch_left:=0
func phase_for_health()->int:return BossPhaseRules.phase_at(boss_id,hp/maxf(.001,max_hp))
func _advance_periodic_summons(_dt:float)->void:pass
func think(dt:float)->void:
	recovery=maxf(0,recovery-dt);vulnerability=maxf(0,vulnerability-dt);_advance_commands(dt)
	if dash_left>0:
		dash_left=maxf(0,dash_left-dt);velocity=dash_direction*300
		if dash_left<=0 or global_position.distance_to(dash_destination)<12 or not room.body_clear(global_position+dash_direction*12,24):
			dash_left=0;velocity=Vector2.ZERO
			_strike({"at":global_position,"dir":dash_direction,"shape":"fan","spread":1.25,"radius":72,"ratio":.9});recovery=maxf(recovery,1.2)
		return
	if recovery>0 or main_pending():velocity=Vector2.ZERO;return
	attack_id=&"";room_nav_cd-=dt
	if room_nav_cd<=0:
		room_nav_cd=.35;var target:=player.global_position
		if boss_id==&"verena" and global_position.distance_to(target)<180:target=_legal(global_position+(global_position-target).normalized()*100)
		room_move=room.path_direction(global_position,target,24) if boss_id!=&"nameless" else Vector2.ZERO
	velocity=room_move*effective_chase_speed()*(.6 if boss_id==&"sephra" else .4);_facing=1 if player.global_position.x>global_position.x else -1
	room_cooldown-=dt
	if room_cooldown>0:return
	room_target=_legal(player.global_position);room_aim=(room_target-global_position).normalized()
	var choices:=_available_patterns()
	if phase_rotation_seen!=phase:
		phase_rotation_seen=phase;room_action=3 if phase==2 else 5
	pattern=str(choices[room_action%choices.size()]);room_action+=1;attack_id=&"windup";velocity=Vector2.ZERO
	if boss_id==&"sephra" and pattern=="执印三连" and global_position.distance_to(room_target)>170:pattern="归城突进"
	_boss_fx("cast",global_position,96,.85);pattern_last_time=0
	plan_pattern(pattern)
	var rest:=2.2 if pattern in ["未署名出口","空白批注"] else 1.2
	_command("pattern_rest",pattern_last_time+.05,{"rest":rest});room_cooldown=rest
func _available_patterns()->Array:return BossPhaseRules.skills(boss_id,phase)
func _command(kind:String,delay:float,data:Dictionary={})->void:
	pattern_last_time=maxf(pattern_last_time,delay);super._command(kind,delay,data)
func plan_pattern(name:String,offset:=0.0,repeating:=false)->void:
	if not repeating and name in ["飞页扇射","延迟蜡印","书架投影"]:recorded_pattern=name;recorded_target=room_target;recorded_aim=room_aim;recorded_circles.clear()
	match name:
		"执印三连":
			for index in 3:_command("lock_slash",offset+index*1.0+.05,{"turn":[-.4,.4,0][index]})
			_command("wait",offset+3.0,{})
		"归城突进":
			_command("lock_dash",offset+.05,{"distance":320.0})
			if phase>=2:_command("lock_dash",offset+2.4,{"distance":280.0})
			_command("wait",offset+(4.6 if phase>=2 else 2.3),{})
		"分段门印":
			for index in 3:_wall(offset+1.2+index*1.5,false,room_target.x)
			_command("wait",offset+7.0,{})
		"交叉封街":
			_wall(offset+1.3,false,room_target.x);_wall(offset+3.7,true,room_target.y);_command("wait",offset+8.0,{})
		"巡卫点名":_command("city_guards",offset+1.3,{"shape":"circle","radius":65,"warning":1.3});_command("wait",offset+3.3,{})
		"飞页扇射":
			for index in 2:_command("fan",offset+1.0+index*.85,{"shape":"fan","radius":300,"warning":1.0,"dir":room_aim.rotated(index*.22-.11),"count":7,"spread":1.5,"speed":170,"ratio":.35})
			_command("wait",offset+4.6,{})
		"延迟蜡印":
			for index in 3:
				if repeating:_command("circle",offset+1.1+index*.8,{"at":recorded_circles[index] if index<recorded_circles.size() else room_target,"shape":"circle","radius":33,"ratio":.65,"warning":1.1})
				else:_command("lock_circle",offset+.05+index*.8,{})
			_command("wait",offset+2.8,{})
		"书架投影":
			var center:=room.bounds().get_center()
			for side in [-1,1]:
				var at:=_legal(center+Vector2(side*160,-100),20)
				for index in 3:_command("fan",offset+1.1+index*.85+(0 if side<0 else .42),{"at":at,"dir":Vector2.DOWN.rotated(side*(.5-index*.25)),"count":5,"spread":1.2,"speed":140,"ratio":.35,"shape":"fan","radius":240,"warning":1.0})
			_command("wait",offset+6.0,{})
		"昨日复写":
			var prior:=recorded_pattern if not recorded_pattern.is_empty() else "飞页扇射"
			var current_target:=room_target;var current_aim:=room_aim
			room_target=recorded_target if not recorded_pattern.is_empty() else room_target;room_aim=recorded_aim if not recorded_pattern.is_empty() else room_aim
			plan_pattern(prior,offset+1.0,true);room_target=current_target;room_aim=current_aim
		"空白批注":_command("city_constructs",offset+1.2,{"kind":"page","count":4,"shape":"circle","radius":65,"warning":1.2});_command("wait",offset+4.0,{})
		"交错星环":
			for index in 3:_command("city_ring",offset+1.2+index*1.1,{"at":global_position,"dir":room_aim.rotated((index-1)*.85),"shape":"ring","radius":180,"opening":1.3,"opposite_gap":true,"warning":1.2})
			_command("wait",offset+6.4,{})
		"星轨依次扫射":
			for index in 19:
				for side in [0,1]:
					var aim:=room_aim.rotated(deg_to_rad(-30+index*60.0/18)+side*PI)
					_command("city_beam",offset+1.3+index*.15,{"at":global_position,"dir":aim,"shape":"line","end":_beam_end(aim),"width":10,"ratio":.65,"warning":1.2,"visual_seconds":.18})
		"落印圆阵":
			for index in 3:
				var point:=_legal(room_target+Vector2.from_angle(index*TAU/3)*100,30)
				_command("circle",offset+1.2+index*.6,{"at":point,"shape":"circle","radius":30,"ratio":.65,"warning":1.2})
		"双轨逆行":
			for index in 8:
				for side in [-1,1]:_command("city_cross",offset+1.2+index*.4,{"at":_legal(global_position+Vector2(side*72,0)),"dir":Vector2.from_angle(side*index*.22),"shape":"ring","radius":100,"warning":1.2})
			_command("wait",offset+7.0,{})
		"校验卫星":_command("city_constructs",offset+1.2,{"kind":"satellite","count":2,"shape":"circle","radius":60,"warning":1.2});_command("wait",offset+3.5,{})
		"闭环回响":_command("city_return",offset+1.2,{"dir":room_aim,"shape":"ring","radius":180,"opening":1.3,"opposite_gap":true,"warning":1.2});_command("wait",offset+5.9,{})
		"未署名出口":
			_wall(offset+1.4,false,room_target.x);_wall(offset+3.9,true,room_target.y);_wall(offset+6.4,false,room_target.x);_command("wait",offset+10.8,{})
	previous_pattern=name
func _beam_end(direction:Vector2)->Vector2:
	# Clip a ray to the arena, retaining its exact aim. A fixed 360px beam
	# left wide rooms with permanently safe firing positions.
	var box:=room.bounds().grow(-8);var distance:=box.size.length()
	if absf(direction.x)>.0001:distance=minf(distance,((box.end.x if direction.x>0 else box.position.x)-global_position.x)/direction.x)
	if absf(direction.y)>.0001:distance=minf(distance,((box.end.y if direction.y>0 else box.position.y)-global_position.y)/direction.y)
	return global_position+direction*maxf(0,distance)
func _wall(delay:float,vertical:bool,safe:float)->void:
	var box:=room.bounds().grow(-28)
	var lower:float=box.position.y if vertical else box.position.x
	var upper:float=box.end.y if vertical else box.end.x
	safe=clampf(safe,lower+96,upper-96)
	var origin:=Vector2(box.position.x,safe) if vertical else Vector2(safe,box.position.y)
	var finish:=Vector2(box.end.x,safe) if vertical else Vector2(safe,box.end.y)
	_command("city_wall",delay,{"at":origin,"dir":Vector2.RIGHT if vertical else Vector2.DOWN,"end":finish,"vertical":vertical,"safe":safe,"shape":"line","width":48,"warning":1.2,"safe_corridor":true})
func _execute(event:Dictionary)->void:
	match str(event.type):
		"lock_slash":
			var aim:Vector2=(player.global_position-global_position).normalized().rotated(float(event.turn))
			_command("slash",.9,{"at":global_position,"dir":aim,"shape":"fan","radius":112,"spread":1.3,"ratio":.9,"warning":.9})
		"lock_dash":
			var aim:Vector2=(player.global_position-global_position).normalized()
			if aim.is_zero_approx():aim=room_aim
			var travel:=minf(float(event.distance),maxf(0,global_position.distance_to(player.global_position)-40))
			var destination:=_legal(global_position+aim*travel,24)
			var dash_aim:Vector2=(destination-global_position).normalized() if destination.distance_to(global_position)>1 else aim
			# The warning covers both the approach and its finishing slash. Lock
			# once, stop before the target and leave the full second to dodge.
			_command("city_dash",1.0,{"at":global_position,"dir":dash_aim,"shape":"line","end":destination+dash_aim*72,"destination":destination,"width":48,"warning":1.0})
		"city_dash":dash_destination=event.get("destination",event.end);dash_direction=(dash_destination-global_position).normalized();dash_left=maxf(.017,minf(1.1,global_position.distance_to(dash_destination)/300));begin_visual_release(dash_left)
		"lock_circle":
			var point:=_legal(player.global_position,30);recorded_circles.append(point)
			_command("circle",1.1,{"at":point,"shape":"circle","radius":33,"ratio":.65,"warning":1.1})
		"city_wall":
			begin_visual_release(.5);var box:=room.bounds().grow(-28);var vertical:bool=event.vertical
			var lower:float=box.position.y if vertical else box.position.x
			var upper:float=box.end.y if vertical else box.end.x
			for point in range(int(lower),int(upper)+1,40):
				if absf(point-float(event.safe))<65:continue
				_bullet(Vector2(box.position.x,point) if vertical else Vector2(point,box.position.y),event.dir,150,.35,{"life":5.2})
		"city_ring","city_return":
			begin_visual_release(.6)
			for index in 24:
				var direction:=Vector2.from_angle(index*TAU/24)
				if absf(direction.angle_to(event.dir))<.65 or absf(direction.angle_to(-event.dir))<.65:continue
				_bullet(event.at,direction,140,.35,{"return":str(event.type)=="city_return","return_after":1.5,"pause":.8,"life":5.0})
		"city_cross":
			begin_visual_release(.4)
			for index in 4:_bullet(event.at,(event.dir as Vector2).rotated(index*TAU/4),130,.35,{"life":3.8})
		"city_beam":begin_visual_release(.35);_strike(event)
		"city_guards":_city_guards();begin_visual_release(.6)
		"city_constructs":_city_constructs(str(event.kind),int(event.count));begin_visual_release(.6)
		"pattern_rest":recovery=maxf(recovery,float(event.rest))
		"wait":pass
		_:super._execute(event)
func _city_guards()->void:
	if not is_instance_valid(director):return
	var living:=0
	for unit in get_tree().get_nodes_in_group("enemies"):
		if unit is RoomEnemy and not unit._dead and unit.boss_wave_tag.begins_with(owner_tag):living+=1
	for pending in director.room_pending:
		if str(pending.get("boss_wave_tag","")).begins_with(owner_tag):living+=1
	if living>0:return
	for index in mini(4,RunDifficulty.spawn_count(2,GameState.difficulty)):
		var point:=room.spawn_point(director.spawn_rng,player.global_position,14)
		if point.distance_to(player.global_position)<120:continue
		director.room_pending.append({"kind":"guard","at":point,"remaining":1.0+index*.15,"origin":"boss_minion","boss_wave_tag":owner_tag+":seal"});RoomSpawnFX.spawn(_fx(),point,1.0+index*.15)
func _city_constructs(kind_value:String,count:int)->void:
	if not _constructs().is_empty():return
	construct_batch+=1;construct_batch_left=0
	for index in count:
		var point:=_legal(global_position+Vector2.from_angle(index*TAU/count+PI/4)*150,20)
		if point.distance_to(player.global_position)<90:point=_legal(point+(point-player.global_position).normalized()*100,20)
		var construct:=_spawn_construct(kind_value,point,12,false)
		if construct!=null:construct.wave_tag=construct_batch;construct.shooting_left=1.5+index*.8;construct_batch_left+=1
func can_construct_fire(construct:BossConstruct)->bool:return not _dead and not phase_presenting and phase_guard_left<=0 and construct.lifetime>.9 and (not main_pending() or pattern in ["空白批注","校验卫星"])
func warn_construct_shot(construct:BossConstruct)->void:
	command_serial+=1;construct.shot_count=command_serial
	_command("core_shot",1.0,{"at":construct.global_position,"dir":(player.global_position-construct.global_position).normalized(),"construct":construct.shot_count,"shape":"fan","spread":.7,"radius":220,"count":3,"auxiliary":true,"warning":1.0})
func construct_destroyed(construct:BossConstruct)->void:
	if construct.wave_tag!=construct_batch:return
	construct_batch_left=maxi(0,construct_batch_left-1)
	if construct_batch_left==0:recovery=maxf(recovery,2);vulnerability=2;Effects.text(_fx(),global_position-Vector2(0,64),"记录中断 · 破绽",Color("e6ffca"),18)
func cancel_attacks(clear_bullets:=true)->void:
	dash_left=0;super.cancel_attacks(clear_bullets)
