class_name RoomAlly
extends HiredAlly
var room:RoomLevel
var nav_timer:=0.0
var travel:=Vector2.ZERO
var attack_clock:=-1.0
var attack_direction:=Vector2.RIGHT
var attack_released:=false
var _unit_spawn_left:=0.0
var attack_target:WeakRef
var _room_target_timer:=0.0
var _cached_target:WeakRef
var _detour:=Vector2.ZERO
var _detour_left:=0.0
var _blocked_time:=0.0
var _firing_goal:=Vector2.ZERO
var _firing_target:=Vector2.ZERO
var _roam_goal:=Vector2.ZERO
var _roam_left:=0.0
var _roam_rest:=0.0
var _roam_arrived:=false
var _roam_initialized:=false
var _roam_rng:=RandomNumberGenerator.new()
func body_radius()->float:return 12.0
func attack_is_melee()->bool:return HireOffers.merc_is_melee(_merc_index) if is_merc else HireOffers.monster_is_melee(enemy_kind)
func attack_windup()->float:return .16
func attack_duration()->float:return .42
func attack_cooldown()->float:return 1.1
func _ready()->void:
	_roam_rng.seed=int(get_instance_id())^(GameState.run_epoch<<16)
	_uses_gravity=false;super._ready()
	collision_mask=Layers.WORLD|(0 if is_flying() else Layers.DEEP_WATER);motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	for child in get_children():
		if child is CollisionShape2D:
			var shape:=CircleShape2D.new();shape.radius=body_radius();child.shape=shape
	room.register_unit_body(self,body_radius(),is_flying())
	nav_timer=float(get_instance_id()%13)*0.011
func is_flying()->bool:return not is_merc and enemy_kind==&"flyer"
func place_near_player()->void:
	for offset in [Vector2(-30,0),Vector2(30,0),Vector2(0,30),Vector2(0,-30),Vector2.ZERO]:
		var at:Vector2=player.global_position+offset
		if room.body_clear(at,body_radius(),is_flying()):global_position=at;return
	global_position=room.spawn_point(GameState.passive_rng,Vector2(-1000,-1000),body_radius())
func _physics_process(dt:float)->void:
	if not is_instance_valid(player) or hp<=0 or is_queued_for_deletion():return
	_cooldown=maxf(0,_cooldown-dt*(1.0+equipment_haste));_hurt_left=maxf(0,_hurt_left-dt);_unit_spawn_left=maxf(0,_unit_spawn_left-dt)
	_room_target_timer-=dt;_roam_left-=dt;_roam_rest=maxf(0,_roam_rest-dt)
	var target:EnemyBase=_choose_target()
	var goal:Vector2=target.global_position if is_instance_valid(target) else follow_goal()
	var dist:=global_position.distance_to(goal)
	var melee:=attack_is_melee()
	var reach:=60.0 if melee else 300.0
	var visible:=target!=null and (room.sight(global_position,goal) if melee else room.projectile_clear(global_position,goal))
	var corridor:=target!=null and (not melee or room.segment_clear(global_position,goal,body_radius(),is_flying()))
	var firing_here:=target!=null and not melee and visible and dist>=112 and dist<=reach
	nav_timer-=dt
	if nav_timer<=0:
		nav_timer=0.18
		var destination:=goal
		if firing_here:
			_firing_goal=global_position;_firing_target=goal;destination=global_position
		elif target!=null and not melee:
			if _firing_goal.is_zero_approx() or goal.distance_to(_firing_target)>48 or not room.body_clear(_firing_goal,body_radius(),is_flying()) or not room.projectile_clear(_firing_goal,goal) or global_position.distance_to(_firing_goal)<12:
				_firing_goal=room.tactics.attack_position(room,self,target,true,body_radius(),is_flying());_firing_target=goal
			destination=_firing_goal
		elif target!=null:destination=room.tactics.attack_position(room,self,target,false,body_radius(),is_flying())
		else:_firing_goal=Vector2.ZERO
		travel=room.path_direction(global_position,destination,body_radius(),is_flying())
	var moving:=dist>(48 if melee else 190) or (not melee and target!=null and dist<112) or not visible or not corridor
	if firing_here:moving=false
	if target==null:moving=dist>=24
	velocity=travel*move_speed*movement_slow_multiplier() if moving else Vector2.ZERO
	if target!=null and visible and dist<112 and not melee and travel.is_zero_approx():velocity=_retreat_direction(goal)*move_speed*movement_slow_multiplier()
	_detour_left=maxf(0,_detour_left-dt)
	if _detour_left>0 and moving:velocity=_detour*move_speed*movement_slow_multiplier()
	if target!=null and visible and corridor and dist<=reach and _cooldown<=0 and attack_clock<0:
		attack_clock=0;attack_released=false;attack_direction=(goal-global_position).normalized();attack_target=weakref(target)
		_cooldown=attack_cooldown()
	if attack_clock>=0:
		attack_clock+=dt
		if melee:velocity*=0.35
		if not attack_released and attack_clock>=attack_windup():
			attack_released=true
			if _attack_still_valid(melee):_release_attack(melee)
			else:nav_timer=0;_cooldown=minf(_cooldown,0.2)
		if attack_clock>=attack_duration():attack_clock=-1;attack_target=null
	velocity=combat_movement(target,velocity)
	var spread:=room.tactics.separation(room,self)
	if attack_clock<0 and not spread.is_zero_approx():
		var speed:=move_speed*movement_slow_multiplier()
		var candidate:Vector2=velocity+spread*speed*.75
		if room.segment_clear(global_position,global_position+candidate.normalized()*18,body_radius(),is_flying()):velocity=candidate.limit_length(speed)
	var before:=global_position
	var commanded:=velocity
	move_and_slide();_track_blockage(dt,before,commanded)
	var facing_direction:Vector2=attack_direction if attack_clock>=0 else ((goal-global_position) if target!=null else travel)
	var pose:StringName=&"hurt" if _hurt_left>0 else (&"attack" if attack_clock>=0 else (&"walk" if velocity.length()>10 else &"idle"))
	_play_pose(pose,facing_direction)
	queue_redraw()
func combat_movement(_target:EnemyBase,current:Vector2)->Vector2:return current

func _attack_still_valid(melee:bool)->bool:
	var aimed:EnemyBase=attack_target.get_ref() as EnemyBase if attack_target!=null else null
	if not is_instance_valid(aimed) or aimed._dead:return false
	var distance:=global_position.distance_to(aimed.global_position)
	return distance<=(64.0 if melee else 300.0) and (room.sight(global_position,aimed.global_position) and room.segment_clear(global_position,aimed.global_position,body_radius(),is_flying()) if melee else room.projectile_clear(global_position,aimed.global_position))
func _track_blockage(dt:float,before:Vector2,commanded:Vector2)->void:
	if commanded.length()<20:_blocked_time=0;return
	if before.distance_to(global_position)<move_speed*dt*0.12:_blocked_time+=dt
	else:_blocked_time=0
	if _blocked_time<0.4:return
	_blocked_time=0;nav_timer=0
	_detour=room.crowd_detour(global_position,travel,body_radius(),self,is_flying())
	_detour_left=0.4 if not _detour.is_zero_approx() else 0.0
func _play_pose(pose:StringName,facing_direction:Vector2)->void:
	if absf(facing_direction.x)>0.05:_sprite.flip_h=facing_direction.x<0
	var wanted:=&"spawn" if _unit_spawn_left>0 and _sprite.sprite_frames.has_animation(&"spawn") else pose
	if not is_merc and _unit_spawn_left<=0:
		if pose==&"attack" and not attack_released and _sprite.sprite_frames.has_animation(&"windup"):wanted=&"windup"
		var directional:=PixelEnemyArt.directional_action(visual_art_kind(),wanted,facing_direction)
		if directional!=wanted and _sprite.sprite_frames.has_animation(directional):wanted=directional;_sprite.flip_h=false
	if _sprite.sprite_frames.has_animation(wanted) and _sprite.animation!=wanted:_sprite.play(wanted)
	if _unit_spawn_left>0 and wanted==&"spawn":
		_sprite.pause();_sprite.frame=clampi(int((1-_unit_spawn_left/.55)*_sprite.sprite_frames.get_frame_count(wanted)),0,_sprite.sprite_frames.get_frame_count(wanted)-1)
	elif is_merc and pose==&"attack":
		_sprite.pause();_sprite.frame=PixelHireArt.attack_frame(_merc_index,attack_clock,attack_released,attack_windup(),attack_duration())
	elif not is_merc and pose==&"attack" and _sprite.sprite_frames.has_animation(&"windup"):
		var progress:=clampf(attack_clock/maxf(attack_windup(),.001),0,1) if not attack_released else clampf((attack_clock-attack_windup())/maxf(attack_duration()-attack_windup(),.001),0,1)
		_sprite.pause();_sprite.frame=mini(_sprite.sprite_frames.get_frame_count(wanted)-1,int(progress*_sprite.sprite_frames.get_frame_count(wanted)))
	elif not _sprite.is_playing():_sprite.play()
func follow_goal()->Vector2:
	if _roam_initialized and not _roam_arrived and global_position.distance_to(_roam_goal)<24:
		_roam_arrived=true;_roam_rest=_roam_rng.randf_range(1,3)
	if _roam_rest>0:return global_position
	if not _roam_initialized or _roam_arrived or _roam_left<=0 or not room.body_clear(_roam_goal,body_radius(),is_flying()):
		_roam_goal=RoomTactics.roam_goal(room,self,_roam_rng,body_radius(),is_flying());_roam_left=global_position.distance_to(_roam_goal)/maxf(1,move_speed)+3
		_roam_initialized=true;_roam_arrived=false
	return _roam_goal
func _choose_target()->EnemyBase:
	if player is RoomPlayer and is_instance_valid((player as RoomPlayer).equipment_mechanics):
		var preferred: EnemyBase=(player as RoomPlayer).equipment_mechanics.preferred_enemy(self)
		if preferred!=null:return preferred
	if _room_target_timer>0 and _cached_target!=null:
		var cached:=_cached_target.get_ref() as EnemyBase
		if is_instance_valid(cached) and not cached._dead and cached.level==room and not cached.is_queued_for_deletion():return cached
	_room_target_timer=0.3
	var result:EnemyBase;var score:=INF
	for node in room.tactics.enemies(room):
		var enemy:=node as EnemyBase
		if not is_instance_valid(enemy) or enemy._dead or enemy.is_queued_for_deletion():continue
		var distance:=global_position.distance_squared_to(enemy.global_position)
		if enemy.level!=room or distance>=score:continue
		var visible:=room.sight(global_position,enemy.global_position)
		if not visible and room.path_direction(global_position,enemy.global_position,body_radius(),is_flying()).is_zero_approx():continue
		var weight:=distance
		if weight<score:score=weight;result=enemy
	var previous:EnemyBase=_cached_target.get_ref() as EnemyBase if _cached_target!=null else null
	if is_instance_valid(previous) and previous.level==room and not previous._dead and (room.sight(global_position,previous.global_position) or not room.path_direction(global_position,previous.global_position,body_radius(),is_flying()).is_zero_approx()):result=RoomTactics.stable_target(previous,result,global_position) as EnemyBase
	_cached_target=weakref(result) if result!=null else null
	return result
func _retreat_direction(enemy:Vector2)->Vector2:
	var away:=(global_position-enemy).normalized()
	for angle in [0.0,PI/4,-PI/4,PI/2,-PI/2]:
		var direction:=away.rotated(angle)
		var point:=global_position+direction*32
		if room.segment_clear(global_position,point,body_radius(),is_flying()) and room.unit_position_clear(point,body_radius(),self):return direction
	return Vector2.ZERO
func _release_attack(melee:bool)->void:
	var aimed:EnemyBase=attack_target.get_ref() as EnemyBase if attack_target!=null else null
	if not is_instance_valid(aimed) or aimed._dead or not (room.sight(global_position,aimed.global_position) if melee else room.projectile_clear(global_position,aimed.global_position)):
		nav_timer=0;return
	if melee:
		var target:EnemyBase=aimed
		if not is_instance_valid(target) or target._dead:return
		var offset:=target.global_position-global_position
		if offset.length()>64 or attack_direction.dot(offset.normalized())<0.5 or not room.sight(global_position,target.global_position):return
		var before:=target.hp
		target.take_damage(attack,false,global_position,self)
		if is_instance_valid(player) and player is RoomPlayer and target.hp<before:
			(player as RoomPlayer).equipment_mechanics.on_ally_hit(target,self)
		Effects.hit_spark(_fx(),target.global_position,Color("d9e4ef"),4)
		AudioManager.play(&"swing",-12,0.1)
	elif is_merc and HireOffers.merc_role(_merc_index)=="knife":
		_throw_knife(attack_direction)
	else:
		var ball:=RoomProjectile.new();ball.room=room;ball.damage_owner=&"ally";ball.is_friendly=true;ball.art_scale=0.7
		ball.damage_actor=self
		if is_merc:ball.weapon_fx="bow_wood"
		_fx().add_child(ball);ball.setup(global_position+attack_direction*16,attack_direction,attack,430 if is_merc else 330,room,null,Color("d7e7bc"))
func heal(amount:float)->void:
	hp=minf(max_hp,hp+maxf(0,amount));queue_redraw()




