class_name CityBoss
extends RoomBoss
## Chapter-two attacks reuse only the legal-hit and warning infrastructure.
var dash_left:=0.0
var dash_direction:=Vector2.RIGHT
var previous_pattern:=""
func phase_for_health()->int:
	if boss_id==&"nameless":return 3 if hp/max_hp<=.30 else 2 if hp/max_hp<=.65 else 1
	return 2 if hp/max_hp<=.5 else 1
func think(dt:float)->void:
	recovery=maxf(0,recovery-dt);vulnerability=maxf(0,vulnerability-dt);_advance_commands(dt)
	if dash_left>0:
		dash_left=maxf(0,dash_left-dt);velocity=dash_direction*300
		if dash_left<=0:_strike({"at":global_position,"dir":dash_direction,"shape":"fan","spread":1.25,"radius":72,"ratio":.9});recovery=1.2
		return
	if recovery>0 or main_pending():velocity=Vector2.ZERO;return
	attack_id=&"";room_nav_cd-=dt
	if room_nav_cd<=0:
		room_nav_cd=.35;var target:=player.global_position
		if boss_id==&"verena" and global_position.distance_to(target)<180:target=_legal(global_position+(global_position-target).normalized()*100)
		room_move=room.path_direction(global_position,target,24) if boss_id!=&"nameless" else Vector2.ZERO
	velocity=room_move*move_speed*(.6 if boss_id==&"sephra" else .4);_facing=1 if player.global_position.x>global_position.x else -1
	room_cooldown-=dt
	if room_cooldown>0:return
	room_target=_legal(player.global_position);room_aim=(room_target-global_position).normalized()
	pattern=str(_available_patterns()[room_action%3]);room_action+=1;attack_id=&"windup"
	_boss_fx("cast",global_position,96,.85)
	plan_pattern(pattern)
	room_cooldown=attack_cd(3.1 if phase==1 else 2.7)
func _available_patterns()->Array:
	if boss_id==&"sephra":return ["执印三连","归城突进","分段门印"]
	if boss_id==&"verena":return ["飞页扇射","延迟蜡印","书架投影"]
	return ["星轨依次扫射","落印圆阵","交错星环"]
func plan_pattern(name:String,offset:=0.0,repeating:=false)->void:
	if boss_id==&"sephra":
		match name:
			"执印三连":
				for index in 3:_command("slash",offset+.9+index*.95,{"at":global_position,"shape":"fan","dir":room_aim.rotated([-.45,.45,0][index]),"radius":112,"spread":1.3,"ratio":.65,"warning":.85})
			"归城突进":
				_command("city_dash",offset+.9,{"shape":"line","end":_legal(global_position+room_aim*210),"width":23,"warning":.9})
				if phase>=2:_command("retarget_dash",offset+2.5,{"auxiliary":false})
			"分段门印":
				var bounds:=room.bounds().grow(-40);var safe:=clampf(room_target.x,bounds.position.x+55,bounds.end.x-55)
				for index in 3:
					var y:=lerpf(bounds.position.y,bounds.end.y,(index+1)/4.0)
					_line(offset+1+index*.9,Vector2(bounds.position.x,y),Vector2(safe-48,y),16,.65)
					_line(offset+1+index*.9,Vector2(safe+48,y),Vector2(bounds.end.x,y),16,.65)
	elif boss_id==&"verena":
		match name:
			"飞页扇射":_command("fan",offset+.95,{"at":global_position,"shape":"fan","radius":320,"count":7,"spread":1.25,"speed":190,"ratio":.65,"warning":.95})
			"延迟蜡印":
				for index in 3:
					var point:=_legal(room_target+Vector2.from_angle(index*TAU/3)*90,30)
					if timeline.any(func(e:Dictionary)->bool:return str(e.type)=="circle" and (e.at as Vector2).distance_to(point)<72):continue
					_command("circle",offset+1.2+index*.3,{"at":point,"shape":"circle","radius":33,"ratio":.8,"warning":1.0})
			"书架投影":
				var bounds:=room.bounds().grow(-38)
				for index in 3:
					var x:=lerpf(bounds.position.x,bounds.end.x,(index+1)/4.0)
					_line(offset+1+index*.8,Vector2(x,bounds.position.y),Vector2(x,bounds.end.y),17,.7)
		if phase>=2 and not repeating:
			_command("repeat_pattern",offset+3.4,{"name":name})
	else:
		match name:
			"星轨依次扫射":
				for index in 3:
					var direction:=room_aim.rotated((index-1)*.55)
					_line(offset+.95+index*.9,global_position,global_position+direction*360,15,.8)
			"落印圆阵":
				for index in (3 if phase==1 else 4):_command("circle",offset+1.1+index*.35,{"at":_legal(room_target+Vector2.from_angle(index*TAU/4)*100,28),"shape":"circle","radius":30,"ratio":.7,"warning":1.0})
			"交错星环":
				for index in phase:_command("ring",offset+1.0+index*1.0,{"shape":"ring","radius":150,"count":24,"opening":1.5,"gap":room_aim.rotated(index*.2),"speed":135+phase*10,"ratio":.6,"warning":.9})
		if phase>=2 and name!="交错星环":_command("ring",offset+4,{"shape":"ring","radius":150,"count":20,"opening":1.7,"gap":room_aim,"speed":135,"ratio":.5,"warning":.9})
		if phase>=3 and name=="交错星环":_line(offset+4.2,global_position,global_position+room_aim.orthogonal()*320,14,.65)
	previous_pattern=name
func _execute(event:Dictionary)->void:
	match str(event.type):
		"city_dash":dash_direction=(event.end-global_position).normalized();dash_left=minf(.7,global_position.distance_to(event.end)/300);begin_visual_release(.7)
		"retarget_dash":
			var aim:Vector2=(player.global_position-global_position).normalized()
			_command("city_dash",.9,{"at":global_position,"dir":aim,"shape":"line","end":_legal(global_position+aim*180),"width":23,"warning":.9})
		"repeat_pattern":room_target=_legal(player.global_position);room_aim=(room_target-global_position).normalized();plan_pattern(str(event.name),0,true)
		_:super._execute(event)
func cancel_attacks(clear_bullets:=true)->void:
	dash_left=0;super.cancel_attacks(clear_bullets)
