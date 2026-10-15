class_name BossPatternProjectile
extends RoomProjectile
var pattern_family:="king"
var boss_tag:=""
var split_count:=0
var split_after:=1.2
var bounces:=0
var returning:=false
var return_after:=1.5
var pause_left:=0.0
var returned:=false
var age:=0.0
func _boss()->RoomBoss:
	for node in get_tree().get_nodes_in_group("bosses"):
		if node is RoomBoss and node.owner_tag==boss_tag and not node._dead:return node
	return null
func _physics_process(dt:float)->void:
	if not is_instance_valid(room):queue_free();return
	age+=dt
	if pause_left>0:
		pause_left=maxf(0,pause_left-dt)
		if pause_left<=0:direction=-direction;rotation=direction.angle();returned=true
		return
	var ahead:=global_position+direction*(speed*dt+8)
	var wall:=not room.projectile_clear(global_position,ahead)
	if returning and not returned and (age>=return_after or wall):
		pause_left=.65;BossPatternWarning.create(get_parent(),room,{"at":global_position,"shape":"line","end":_start,"width":9},.65,Color("ff8cb2"));return
	if wall and bounces>0:
		var query:=PhysicsRayQueryParameters2D.create(global_position,ahead,collision_mask,[get_rid()])
		var hit:=get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and not hit.collider is Player and not hit.collider is HiredAlly:
			direction=direction.bounce(hit.normal).normalized();rotation=direction.angle();bounces-=1
			HostileAttackFX.pulse(get_parent(),global_position,pattern_family,"impact",40,.4,0,room)
	if split_count>0 and age>=split_after:_split();return
	super._physics_process(dt)
func _split()->void:
	var boss:=_boss()
	if is_instance_valid(boss):
		for index in split_count:boss._bullet(global_position,direction.rotated((float(index)/maxi(1,split_count-1)-.5)*1.2),190,damage/maxf(1,boss.attack_damage())*.6,{})
	split_count=0;_hit_effect(false)
func _hit_effect(hit_target:bool)->void:
	if not hit_target and split_count>0:
		var count:=split_count;split_count=0;var boss:=_boss()
		if is_instance_valid(boss):
			for index in count:boss._bullet(global_position-direction*10,direction.rotated((float(index)/maxi(1,count-1)-.5)*1.4),180,damage/maxf(1,boss.attack_damage())*.5,{})
	super._hit_effect(hit_target)
