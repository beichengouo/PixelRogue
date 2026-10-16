class_name RoomEnemy
extends EnemyBase
var room: RoomLevel
var _action_cd := 1.0
var _windup := 0.0
var _locked_direction := Vector2.RIGHT
var _rush := 0.0
var _nav_cd := 0.0
var _travel := Vector2.ZERO
var _detour:=Vector2.ZERO
var _detour_left:=0.0
var _blocked_time:=0.0
var _firing_goal:=Vector2.ZERO
var _firing_target:=Vector2.ZERO
var _locked_target:=Vector2.ZERO
var room_push:=Vector2.ZERO
var _visual_spawn_left:=0.0
var affix_runtime:AffixRuntime
var _sickle_followup := 0.0
var royal_command_left:=0.0
var boss_wave_tag := ""
var flame_pending:Array[Dictionary]=[]
var _summon_interrupted:=false
var _teleport_cd := 5.0
var _teleport_left := 0.0
var _teleport_destination := Vector2.ZERO
func player_debuffs() -> Array[Dictionary]: return PlayerDebuffs.effects_for(self)
func plays_entry_animation()->bool:return true

func _ready()->void:
	super._ready();motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	if plays_entry_animation() and visual is AnimatedSprite2D and visual.sprite_frames.has_animation(&"spawn"):
		_visual_spawn_left=.55;visual.play(&"spawn")
	if not is_flying():collision_mask|=Layers.DEEP_WATER
	room.register_unit_body(self,body_radius(),is_flying())
	_nav_cd=float(get_instance_id()%13)*0.013
func is_flying()->bool:return kind==&"flyer"
func body_radius()->float:return 12.0

func configure(enemy_kind: StringName) -> void:
	var sample := WaveDirector.create_enemy(enemy_kind)
	kind=enemy_kind; display_name=sample.display_name; base_hp=sample.base_hp; base_damage=sample.base_damage
	base_speed=sample.base_speed; base_coins=sample.base_coins; body_color=sample.body_color; body_size=sample.body_size; sprite_name=sample.sprite_name
	sample.free(); uses_gravity=false; collides_with_world=true

func apply_affixes(list:Array[StringName])->void:
	super.apply_affixes(list)
	if affixes.any(func(id:StringName)->bool:return id in EnemyAffixes.NEW_POOL):
		if not is_instance_valid(affix_runtime):
			affix_runtime=AffixRuntime.new();affix_runtime.enemy=self;add_child(affix_runtime)

func _build_body_collider() -> void:
	var shape := CircleShape2D.new(); shape.radius=body_radius()
	var node:=CollisionShape2D.new(); node.shape=shape; add_child(node)

func _physics_process(dt: float) -> void:
	if _dead or not is_instance_valid(player): return
	ilyua_root_left=maxf(0.0,ilyua_root_left-dt)
	_visual_spawn_left=maxf(0,_visual_spawn_left-dt)
	advance_slow(dt); _flash=maxf(0,_flash-dt); _contact_cd=maxf(0,_contact_cd-dt)
	_visual_release_left=maxf(0,_visual_release_left-dt)
	advance_damage_status(dt)
	if _dead:return
	_update_aggro(dt)
	_affix_timer+=dt
	if has_affix(EnemyAffixes.REGEN) and _affix_timer>=1:
		var healed := hp<max_hp
		hp=minf(max_hp,hp+max_hp*0.025);_affix_timer=0
		if healed:HostileAttackFX.pulse(_fx(),global_position,"affix","regen",44,.45,0,room)
	if has_affix(EnemyAffixes.TELEPORT):_advance_teleport(dt)
	if royal_command_left>0:
		royal_command_left=maxf(0,royal_command_left-dt)
		if royal_command_left<=0:move_speed/=1.2;_attack_scale/=1.2
	_advance_flames(dt)
	think(dt)
	if ilyua_root_left>0.0: velocity=Vector2.ZERO; _rush=0.0
	if _slow_time>0: velocity*=1-_slow_strength
	if _rush<=0 and _windup<=0 and ilyua_root_left<=0:
		var spread:=room.tactics.separation(room,self)
		var speed:=move_speed*(1-_slow_strength if _slow_time>0 else 1.0)
		var candidate:Vector2=velocity+spread*speed*.65
		if room.segment_clear(global_position,global_position+candidate.normalized()*18,body_radius(),is_flying()):velocity=candidate.limit_length(speed)
	velocity+=room_push;room_push=room_push.move_toward(Vector2.ZERO,900*dt)
	var before:=global_position
	var commanded:=velocity
	move_and_slide(); _track_blockage(dt,before,commanded); _check_contact(); _update_visual()
	queue_redraw()

func teleport_landing() -> Vector2:
	var start := Rng.stream().randf()*TAU
	for radius in [108.0,144.0,180.0]:
		for index in 24:
			var point: Vector2 = player.global_position+Vector2.from_angle(start+index*TAU/24)*radius
			if room.body_clear(point,body_radius(),is_flying()) and room.unit_position_clear(point,body_radius(),self) and room.sight(point,player.global_position):return point
	return Vector2(INF,INF)

func _advance_teleport(dt: float) -> void:
	if _teleport_left>0:
		_teleport_left=maxf(0,_teleport_left-dt)
		if _teleport_left>0:return
		# A moving player or newly occupied landing cancels this jump. Never
		# fall back to a distant spawn point or overlap the player's body.
		var distance := _teleport_destination.distance_to(player.global_position)
		if distance<96 or distance>192 or not room.body_clear(_teleport_destination,body_radius(),is_flying()) or not room.unit_position_clear(_teleport_destination,body_radius(),self):_teleport_cd=1;return
		HostileAttackFX.pulse(_fx(),global_position,"affix","departure",64,.3,0,room)
		global_position=_teleport_destination;velocity=Vector2.ZERO;_rush=0;_windup=0;_nav_cd=0;_action_cd=maxf(.5,_action_cd)
		reset_path();HostileAttackFX.pulse(_fx(),global_position,"affix","arrival",72,.4,0,room)
		AudioManager.play(&"dash",-8,.2);return
	_teleport_cd=maxf(0,_teleport_cd-dt)
	if _teleport_cd>0 or _windup>0 or _rush>0 or _sickle_followup>0:return
	if is_instance_valid(affix_runtime) and affix_runtime.blocks_action():return
	var landing := teleport_landing()
	if not landing.is_finite():_teleport_cd=1;return
	_teleport_destination=landing;_teleport_cd=5;_teleport_left=.45
	HostileAttackFX.pulse(_fx(),global_position,"affix","departure",48,.45,0,room)
	HostileAttackFX.pulse(_fx(),landing,"affix","arrival",72,.45,0,room)

func think(dt: float) -> void:
	if _teleport_left>0:velocity=Vector2.ZERO;return
	if _sickle_followup>0.0:
		_sickle_followup=maxf(0.0,_sickle_followup-dt);velocity=Vector2.ZERO
		if _sickle_followup<=0.0:_sickle_sweep()
		return
	if not is_instance_valid(attack_target()):velocity=Vector2.ZERO;return
	var target := aggro_position()
	var distance := global_position.distance_to(target)
	if kind in [&"bomber",&"caster"]:_think_backline(dt);return
	var ranged := EnemyCombatPolicy.ranged_affix_allowed(kind)
	var charging := kind in [&"charger",&"treant",&"moss_badger"]
	_facing=1 if target.x>=global_position.x else -1
	if is_instance_valid(affix_runtime) and affix_runtime.blocks_action():
		velocity=Vector2.ZERO;return
	if _rush>0:
		_rush-=dt; velocity=_locked_direction*move_speed*3.0; return
	if _windup>0:
		_windup-=dt; velocity=Vector2.ZERO
		if _windup<=0: _release()
		return
	_nav_cd-=dt
	if _nav_cd<=0:
		_nav_cd=0.22
		var goal:=target
		if ranged:
			if _firing_goal.is_zero_approx() or target.distance_to(_firing_target)>48 or not room.body_clear(_firing_goal,body_radius(),is_flying()) or not room.projectile_clear(_firing_goal,target) or global_position.distance_to(_firing_goal)<12:
				_firing_goal=room.tactics.attack_position(room,self,attack_target(),true,body_radius(),is_flying());_firing_target=target
			goal=_firing_goal
		else:
			_firing_goal=Vector2.ZERO
			if is_instance_valid(attack_target()):goal=room.tactics.attack_position(room,self,attack_target(),false,body_radius(),is_flying())
		_travel=room.path_direction(global_position,goal,body_radius(),is_flying())
	_action_cd-=dt
	var visible:=room.projectile_clear(global_position,target) if ranged else room.sight(global_position,target)
	# A regular melee windup freezes movement. Begin it only when the first
	# 0.12s rush can enter the 20px contact area around an 11px player body.
	var melee_reach:=64.0 if kind==&"thorn_mantis" else (150.0 if charging else (100.0 if kind==&"bomber" else minf(150.0,31.0+move_speed*0.30)))
	var can_strike:=distance<(300.0 if ranged else melee_reach) and visible and (ranged or room.segment_clear(global_position,target,body_radius(),is_flying()))
	velocity=Vector2.ZERO if can_strike and ((ranged and distance>=125) or (not ranged and not charging and kind!=&"bomber" and distance<=31.0)) else _travel*move_speed
	_detour_left=maxf(0,_detour_left-dt)
	if _detour_left>0 and not can_strike:velocity=_detour*move_speed
	if _action_cd<=0 and can_strike:
		_action_cd=attack_cd(3.1 if kind==&"bell_snail" else 2.8 if kind==&"lantern_toad" else (2.6 if kind==&"dusk_acolyte" else (2.4 if ranged else 1.6)))
		_locked_target=target;_locked_direction=(target-global_position).normalized(); _windup=.8 if kind==&"bell_snail" else .6 if kind==&"glimmer_spider" else 0.65 if charging or kind==&"bomber" else 0.45
		warn_attack("circle" if kind==&"bomber" else "arrow",_windup,100)
		if kind==&"thorn_mantis":HostileAttackFX.pulse(_fx(),global_position+_locked_direction*18,"thorn_mantis","cast",32,_windup,_locked_direction.angle(),room)
		if kind==&"glimmer_spider":HostileAttackFX.pulse(_fx(),global_position+_locked_direction*16,"glimmer_spider","cast",32,_windup,_locked_direction.angle(),room)

func _track_blockage(dt:float,before:Vector2,commanded:Vector2)->void:
	if _rush>0 or _windup>0 or commanded.length()<20:
		_blocked_time=0;return
	if before.distance_to(global_position)<move_speed*dt*0.12:_blocked_time+=dt
	else:_blocked_time=0
	if _blocked_time<0.4:return
	_blocked_time=0;_nav_cd=0
	_detour=room.crowd_detour(global_position,_travel,body_radius(),self,is_flying())
	_detour_left=0.4 if not _detour.is_zero_approx() else 0.0

func _check_contact()->void:
	# New creatures deal damage in their authored attack windows, not by walking into a body.
	if kind in EnemyCombatPolicy.EXPANSION_KINDS or kind in [&"caster",&"bomber",&"flyer",&"lantern_toad",&"dusk_acolyte"]:return
	if is_instance_valid(affix_runtime) and affix_runtime.blocks_action():return
	if _contact_cd>0:return
	for body in contact_area.get_overlapping_bodies():
		if not (body is Player or body is HiredAlly or body is IlyuaDecoy):continue
		if not room.segment_clear(global_position,body.global_position,body_radius(),is_flying()):continue
		if body is Player:
			body.take_damage(attack_damage(),global_position,self)
		else:
			body.take_damage(attack_damage()*0.8,global_position,self)
		_contact_cd=CONTACT_INTERVAL
		return

func _release() -> void:
	stop_warning(); begin_visual_release(0.25)
	if kind==&"thorn_mantis":
		begin_visual_release(.5);_sickle_sweep();_sickle_followup=.25
		if is_instance_valid(affix_runtime):affix_runtime.on_attack_released(kind,global_position,_locked_direction)
	elif kind in [&"charger",&"treant",&"moss_badger"]:
		_rush=0.22 if kind==&"moss_badger" else 0.45
		if is_instance_valid(affix_runtime):affix_runtime.on_attack_released(kind,global_position,_locked_direction)
	elif kind==&"bomber":_release_flames()
	elif kind==&"caster":
		if not _summon_interrupted and is_instance_valid(director):director.summon_necromancer(self)
	elif EnemyCombatPolicy.ranged_affix_allowed(kind):
		var current_target:=aggro_position()
		if attack_target()==null or global_position.distance_to(current_target)>=300.0 or not room.projectile_clear(global_position,_locked_target) or not room.projectile_clear(global_position,current_target):
			_nav_cd=0;_action_cd=minf(_action_cd,0.35);return
		shoot(_locked_direction)
		if is_instance_valid(affix_runtime):affix_runtime.on_attack_released(kind,global_position,_locked_direction)
	else:
		_rush=0.12
		if kind==&"glimmer_spider":HostileAttackFX.pulse(_fx(),global_position+_locked_direction*20,"glimmer_spider","impact",34,.3,_locked_direction.angle(),room)
		if is_instance_valid(affix_runtime):affix_runtime.on_attack_released(kind,global_position,_locked_direction)

func shoot(_aim:Vector2=Vector2.ZERO) -> void:
	var direction:=_locked_direction if _locked_direction.length_squared()>0 else (aggro_position()-global_position).normalized()
	var family:=str(kind)
	var count:=2 if kind==&"bell_snail" else 3 if kind in [&"flyer",&"lantern_toad"] else 1
	HostileAttackFX.pulse(_fx(),global_position+direction*18,family,"cast",46,.45,direction.angle(),room)
	for index in count:
		var aim:=direction.rotated((index-(count-1)*.5)*.17)
		var bullet:=RoomProjectile.new();bullet.room=room;bullet.is_friendly=false;bullet.damage_owner=&"enemy";bullet.hostile_fx=family;bullet.hostile_width=32;bullet.range_limit=600;bullet.hostile_effects=player_debuffs()
		bullet.enable_hostile_tracking(aim)
		bullet.cruel_damage=has_affix(EnemyAffixes.CRUEL)
		_fx().add_child(bullet);bullet.setup(global_position+aim*18,aim,attack_damage()*(.65 if kind in [&"lantern_toad",&"bell_snail"] else 1.0),230 if kind==&"flyer" else 260,room,player,Color("ff7189"))

func _think_backline(dt:float)->void:
	var target:=aggro_position();var distance:=global_position.distance_to(target)
	_facing=1 if target.x>=global_position.x else -1
	if _windup>0:
		_windup-=dt;velocity=Vector2.ZERO
		if _windup<=0:_release()
		return
	_action_cd-=dt;_nav_cd-=dt
	if _nav_cd<=0:
		_nav_cd=.3
		var goal:=room.tactics.attack_position(room,self,attack_target(),true,body_radius(),false)
		_travel=room.path_direction(global_position,goal,body_radius(),false)
	velocity=_travel*move_speed if distance<180 or distance>330 or not room.projectile_clear(global_position,target) else Vector2.ZERO
	if _action_cd>0 or distance>360 or not room.sight(global_position,target):return
	# Retreat before casting where terrain offers space; after three seconds
	# trapped casters still act rather than waiting forever against a wall.
	if distance<110 and _action_cd> -3.0:return
	_locked_target=target;_locked_direction=(target-global_position).normalized();_summon_interrupted=false
	_windup=1.0 if kind==&"caster" else .8;_action_cd=attack_cd(7.0 if kind==&"caster" else 4.5)
	warn_attack("circle",_windup,36)
	HostileAttackFX.pulse(_fx(),global_position,str(kind),"cast",52,_windup,0,room)

func flame_positions(center:Vector2)->Array[Vector2]:
	var result:Array[Vector2]=[];var rng:=Rng.stream();var start:=rng.randf()*TAU
	for index in 3:
		for attempt in 28:
			var angle:=start+index*TAU/3+rng.randf_range(-.30,.30)
			var candidate:=room.nearest_clear(center+Vector2.from_angle(angle)*rng.randf_range(96,150),48)
			if not room.body_clear(candidate,48):continue
			if result.any(func(other:Vector2)->bool:return other.distance_to(candidate)<102):continue
			result.append(candidate);break
	return result

func _release_flames()->void:
	for at in flame_positions(_locked_target):
		flame_pending.append({"at":at,"left":1.15})
		BossPatternWarning.create(_fx(),room,{"at":at,"shape":"circle","radius":48},1.15,Color("ff7851"))
func _advance_flames(dt:float)->void:
	for event in flame_pending.duplicate():
		event.left=float(event.left)-dt
		if event.left>0:continue
		flame_pending.erase(event)
		HostileAttackFX.pulse(_fx(),event.at,"bomber","area",96,.65,0,room)
		for victim in [player]+get_tree().get_nodes_in_group("allies"):
			if is_instance_valid(victim) and victim.hp>0 and victim.global_position.distance_to(event.at)<=48 and room.sight(event.at,victim.global_position):victim.take_damage(attack_damage()*1.3,event.at,self)
func restore_flame_warnings()->void:
	for event in flame_pending:BossPatternWarning.create(_fx(),room,{"at":event.at,"shape":"circle","radius":48},float(event.left),Color("ff7851"))

func _sickle_sweep() -> void:
	HostileAttackFX.pulse(_fx(),global_position+_locked_direction*26,"thorn_mantis","impact",64,.25,_locked_direction.angle(),room)
	for target in [player]+get_tree().get_nodes_in_group("allies"):
		if not is_instance_valid(target) or target.is_queued_for_deletion() or target.hp<=0.0 or (target!=player and target.get("room")!=room):continue
		var offset:Vector2=target.global_position-global_position
		if offset.length()>58 or (offset.length()>1 and _locked_direction.dot(offset.normalized())<.5):continue
		if room.sight(global_position,target.global_position):target.take_damage(attack_damage()*.8,global_position,self)

func can_see_target() -> bool: return room.sight(global_position,aggro_position())
func warn_attack(style:String,seconds:float,reach:float)->void:
	if _warning!=null:_warning.begin(style,seconds,reach,_locked_direction,0)
func _update_visual()->void:
	super._update_visual()
	if _windup>0 and _warning!=null:_warning.direction=_locked_direction

func take_damage(amount:float,is_crit:=false,from:=Vector2.ZERO,source:Node=null,knockback:=true)->void:
	var before_hp:=hp;var before_shield:=affix_shield
	if kind in [&"guard",&"ruin_sentinel"] and from!=Vector2.ZERO:
		var facing_direction:=_travel if _travel!=Vector2.ZERO else Vector2(_facing,0)
		if facing_direction.dot((from-global_position).normalized())>0.5:amount*=0.7 if kind==&"ruin_sentinel" else 0.5
	if is_instance_valid(affix_runtime):
		amount*=affix_runtime.frontal_multiplier(from,source)
		affix_runtime.interrupt(_classify_damage(source)==&"skill",knockback)
	if kind==&"caster" and _windup>0 and (_classify_damage(source)==&"skill" or knockback):
		_summon_interrupted=true;_windup=0;stop_warning();begin_visual_release(.25)
	super.take_damage(amount,is_crit,from,source,false)
	if not _dead and is_instance_valid(affix_runtime) and (hp<before_hp or affix_shield<before_shield) and _classify_damage(source) in [&"basic",&"skill"]:affix_runtime.on_direct_damage()
	if knockback and not _dead:room_push+=(global_position-from).normalized()*160

func _die()->void:
	if _dead:return
	if is_instance_valid(affix_runtime):affix_runtime.on_death()
	super._die()
func visual_locomotion_state() -> StringName: return &"walk" if velocity.length()>8 else &"idle"
func _draw() -> void:
	# The quadruped's shadow covers the rear and front paws on the same floor.
	var shadow_at:=Vector2(1,6) if kind==&"moss_badger" else Vector2(0,body_size.y*.5)
	var shadow_scale:=Vector2(1.4,.45) if kind==&"moss_badger" else Vector2(1,.3)
	draw_set_transform(shadow_at,0,shadow_scale);draw_circle(Vector2.ZERO,14,Color(0,0,0,.22));draw_set_transform(Vector2.ZERO)
	super._draw()


func visual_art_kind()->StringName:return kind
var _art_direction:=Vector2.RIGHT
func _update_pixel_animation(sprite:AnimatedSprite2D)->void:
	var art_id:=visual_art_kind()
	var action:StringName=&"hurt" if _flash>0 else (&"spawn" if _visual_spawn_left>0 else (&"windup" if _windup>0 else (&"charge" if _rush>0 and kind in [&"charger",&"treant"] else (&"attack" if _visual_release_left>0 else visual_locomotion_state()))))
	if _windup>0 or _visual_release_left>0 or _rush>0:_art_direction=_locked_direction
	elif velocity.length_squared()>64:_art_direction=velocity
	var wanted:=PixelEnemyArt.directional_action(art_id,action,_art_direction)
	if not sprite.sprite_frames.has_animation(wanted):wanted=action
	sprite.flip_h=_art_direction.x<0 if wanted==action else false
	if sprite.animation!=wanted:sprite.play(wanted);sprite.set_frame_and_progress(0,0)
	if action==&"spawn":
		sprite.pause();sprite.frame=clampi(int((1-_visual_spawn_left/.55)*sprite.sprite_frames.get_frame_count(wanted)),0,sprite.sprite_frames.get_frame_count(wanted)-1)
	elif action in [&"windup",&"attack"]:
		var duration:=.65 if kind in [&"charger",&"treant",&"bomber"] else .45
		var progress:=clampf(1-_windup/duration,0,1) if action==&"windup" else clampf(1-_visual_release_left/_visual_release_duration,0,1)
		sprite.pause();sprite.frame=mini(sprite.sprite_frames.get_frame_count(wanted)-1,int(progress*sprite.sprite_frames.get_frame_count(wanted)))
	else:
		sprite.speed_scale=clampf(velocity.length()/maxf(base_speed,1),.55,2.5) if action==&"walk" else 1.0
		if not sprite.is_playing():sprite.play()


func advance_damage_status(dt:float)->void:
	if _burn_time>0:
		_burn_time=maxf(0,_burn_time-dt); _burn_tick+=dt
		if _burn_tick>=0.5:
			_burn_tick-=0.5
			var burn_owner:Node=_burn_source.get_ref() if _burn_source!=null else null
			var burn_context:Node=burn_owner if burn_owner is DamageContext and (burn_owner as DamageContext).owner_kind==&"spread_burn" else DamageContext.dot(burn_owner)
			take_damage(_burn_dps*0.5,false,global_position,burn_context,false)
			if _dead:return

func _affix_shoot()->void:shoot()
