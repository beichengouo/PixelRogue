class_name RoomPlayer
extends Player
var room: RoomLevel
var caster: RoomSkillCaster
var passive_runtime:PassiveRuntime
var equipment_mechanics: EquipmentMechanics
var ilyua_runtime: IlyuaRuntime
var holy_runtime:HolyRuntime
var firing := false
var movement_override := Vector2.ZERO
var _dash_vector := Vector2.RIGHT
var _dash_spell_active:=false
var _dash_collision_mask:=-1
var _dash_collision_layer:=-1
var _normal_dash_phase:=false
var _dash_origin:=Vector2.ZERO
var _mouse_attack_blocked := true
var _holy_animation_seen:=-1
var _holy_pose_left:=0.0

func set_extraction_pose(pose: StringName, hide_model := false) -> void:
	super.set_extraction_pose(pose, hide_model)
	if pose != &"":
		_dash_spell_active = false
		_restore_dash_collision()

func _build_sprite() -> void:
	_sprite=AnimatedSprite2D.new();_sprite.name="Sprite"
	_sprite.sprite_frames=RoomHeroArt.make_frames();_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite);visual=_sprite
	_sprite.frame_changed.connect(func()->void:RoomHeroArt.align(_sprite))
	_sprite.play(&"idle_e");RoomHeroArt.align(_sprite)

func _ready() -> void:
	RoomInput.install()
	super._ready()
	EventBus.equipment_changed.connect(_refresh_legendary_visual)
	collision_mask|=Layers.DEEP_WATER
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING; floor_snap_length=0
	var collider := get_node("BodyCollider") as CollisionShape2D
	(collider.shape as RectangleShape2D).size=Vector2(22,22)
	room.register_unit_body(self,12.0)
	caster=RoomSkillCaster.new(); caster.actor=self; caster.room=room; add_child(caster)
	add_to_group("room_player")
	MobileControls.bind_actor(self)
	var cursor:=RoomAimCursor.new();cursor.actor=self;cursor.name="AimCursor";add_child(cursor)
	UIFlow.stack_changed.connect(func() -> void:
		if UIFlow.has_screen():_mouse_attack_blocked=true)
	passive_runtime=PassiveRuntime.new();passive_runtime.actor=self;passive_runtime.z_index=0;add_child(passive_runtime)
	equipment_mechanics=EquipmentMechanics.new();equipment_mechanics.name="EquipmentMechanics";equipment_mechanics.actor=self;add_child(equipment_mechanics)
	if Characters.current_id()==&"ilyua":
		ilyua_runtime=IlyuaRuntime.new();ilyua_runtime.name="IlyuaRuntime";ilyua_runtime.actor=self;add_child(ilyua_runtime)
	elif Characters.current_id()==&"sylphiette":
		holy_runtime=HolyRuntime.new();holy_runtime.name="HolyRuntime";holy_runtime.actor=self;add_child(holy_runtime)

func _refresh_legendary_visual()->void:
	if _sprite==null:return
	var frames:=RoomHeroArt.make_frames()
	if _sprite.sprite_frames==frames:return
	var animation:=_sprite.animation;var frame:=_sprite.frame;var progress:=_sprite.frame_progress
	_sprite.sprite_frames=frames;_sprite.play(animation if frames.has_animation(animation) else &"idle_s");_sprite.set_frame_and_progress(frame%frames.get_frame_count(_sprite.animation),progress);RoomHeroArt.align(_sprite)

func _physics_process(dt: float) -> void:
	_update_timers(dt)
	_holy_pose_left=maxf(0,_holy_pose_left-dt)
	_sync_spell_shield()
	if extraction_controls_locked(): velocity=Vector2.ZERO; _update_visual(dt); return
	var movement := movement_override if movement_override!=Vector2.ZERO else RoomInput.movement()
	if extraction_pose==&"prayer":
		if movement!=Vector2.ZERO: extraction_interrupted.emit()
		else: velocity=Vector2.ZERO; _update_visual(dt); return
	var mouse_mode := RoomInput.using_mouse()
	var auto_mode:=RoomInput.using_auto()
	var held := MobileControls.attacking() if MobileControls.enabled() else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not held:_mouse_attack_blocked=false
	var aim := RoomInput.auto_aim(self) if auto_mode else RoomInput.pointer_aim(self) if mouse_mode else RoomInput.aim()
	firing=(held and not _mouse_attack_blocked) if mouse_mode else aim!=Vector2.ZERO
	firing=firing or aim_override!=Vector2.ZERO
	if aim_override!=Vector2.ZERO: aim=RoomInput.quantize(aim_override)
	if aim!=Vector2.ZERO: aim_direction=aim
	elif movement!=Vector2.ZERO and not mouse_mode:aim_direction=RoomInput.quantize(movement)
	if absf(aim_direction.x)>0.1: facing=1 if aim_direction.x>0 else -1
	var forest_stepping:=is_instance_valid(ilyua_runtime) and ilyua_runtime.step_left>0
	if forest_stepping:velocity=ilyua_runtime.step_motion(dt)
	elif _dash_timer>0: velocity=_dash_vector*stats.get_value(&"move_speed")*2.7*movement_slow_multiplier()
	else:
		velocity=velocity.move_toward(movement*stats.get_value(&"move_speed")*movement_slow_multiplier(),2100*dt)
		if Input.is_action_just_pressed("dash") and _dash_cd<=0 and movement!=Vector2.ZERO:
			request_dash_direction(movement)
	if _dash_timer>0:
		if _dash_collision_mask<0:_dash_collision_mask=collision_mask
		if _dash_collision_layer<0:_dash_collision_layer=collision_layer
		_normal_dash_phase=true;collision_mask=0;collision_layer=0
	else:
		if _normal_dash_phase:_restore_dash_collision()
		if forest_stepping:
			if _dash_collision_mask<0:_dash_collision_mask=collision_mask
			collision_mask=(_dash_collision_mask&~Layers.UNIT_BODY)|Layers.ENEMY
		elif _dash_collision_mask>=0:_restore_dash_collision()
	# Launch from the resolved current position, including walls and dash travel.
	move_and_slide()
	if _normal_dash_phase:
		var bounds:=room.bounds().grow(-12)
		position=Vector2(clampf(position.x,bounds.position.x,bounds.end.x),clampf(position.y,bounds.position.y,bounds.end.y))
	if auto_mode and aim_override.is_zero_approx():
		var automatic:=RoomInput.auto_aim(self);firing=automatic!=Vector2.ZERO
		if firing:aim_direction=automatic
	if mouse_mode and aim_override.is_zero_approx():
		var pointer := RoomInput.pointer_aim(self)
		if not pointer.is_zero_approx():aim_direction=pointer
	if absf(aim_direction.x)>0.1:facing=1 if aim_direction.x>0 else -1
	if firing and _attack_cd<=0 and extraction_pose==&"":
		var receipt := BasicAttackReceipt.new(self)
		var roll := Combat.roll_attack(stats,Rng.stream())
		roll.damage=float(roll.damage)*1.5
		receipt.critical=bool(roll.crit)
		if is_instance_valid(ilyua_runtime):ilyua_runtime.fire_basic(aim_direction,roll,receipt)
		else:
			if not equipment_mechanics.fire_basic(aim_direction,roll,receipt):fire(aim_direction,float(roll.damage),430,true,receipt)
			equipment_mechanics.on_basic_fired(aim_direction,receipt)
		_attack_cd=(.44 if is_instance_valid(ilyua_runtime) and ilyua_runtime.ultimate_left>0 else .70)/maxf(0.1,stats.get_value(&"attack_speed"))
		_swing_timer=0.18
		if is_instance_valid(holy_runtime):_animation_request+=1
	for slot in 4:
		if Input.is_action_just_pressed(["skill_1","skill_2","skill_3","ultimate"][slot]): caster.cast(slot)
	_try_potions()
	if forest_stepping and ilyua_runtime.step_left<=0:velocity=movement*stats.get_value(&"move_speed")*movement_slow_multiplier()
	if _dash_spell_active and _dash_timer<=0:_dash_spell_fx();_dash_spell_active=false;equipment_mechanics.on_dash_end()
	_move_input_active=movement!=Vector2.ZERO
	_update_visual(dt)
	queue_redraw()

func request_dash() -> void:
	var movement := movement_override if movement_override != Vector2.ZERO else RoomInput.movement()
	request_dash_direction(movement if movement != Vector2.ZERO else aim_direction)

func stop_room_travel_motion()->void:
	# Transition screens pause physics, so a dash's remaining time otherwise
	# survives the entire load and resumes at the destination's entrance.
	_dash_timer=0;_dash_spell_active=false
	_restore_dash_collision()
	_dash_vector=Vector2.ZERO;_dash_origin=position
	velocity=Vector2.ZERO;_swing_timer=0;_cast_timer=0;_holy_pose_left=0
	if is_instance_valid(ilyua_runtime):
		ilyua_runtime.step_left=0;ilyua_runtime.step_direction=Vector2.ZERO
	# Dash/skill cooldowns and existing defensive buffs remain unchanged.

func request_attack()->void:
	if hp<=0 or _attack_cd>0 or extraction_controls_locked():return
	var receipt:=BasicAttackReceipt.new(self);var roll:=Combat.roll_attack(stats,Rng.stream());roll.damage=float(roll.damage)*1.5;receipt.critical=bool(roll.crit)
	if is_instance_valid(ilyua_runtime):ilyua_runtime.fire_basic(aim_direction,roll,receipt)
	else:
		if not equipment_mechanics.fire_basic(aim_direction,roll,receipt):fire(aim_direction,float(roll.damage),430,true,receipt)
		equipment_mechanics.on_basic_fired(aim_direction,receipt)
	_attack_cd=(.44 if is_instance_valid(ilyua_runtime) and ilyua_runtime.ultimate_left>0 else .70)/maxf(.1,stats.get_value(&"attack_speed"));_swing_timer=.18
	if is_instance_valid(holy_runtime):_animation_request+=1

func request_dash_direction(direction: Vector2) -> void:
	if hp <= 0.0 or _dash_cd > 0.0 or direction.is_zero_approx(): return
	_dash_origin=position;_dash_vector=direction.normalized();_dash_timer=0.16;_dash_cd=stats.get_value(&"dash_cooldown")
	_invuln=maxf(_invuln,0.16);_dash_spell_active=true;_dash_spell_fx()
	if is_instance_valid(ilyua_runtime):ilyua_runtime.on_dash_started()

func take_damage(amount: float, from: Vector2, source: Node = null) -> void:
	if is_instance_valid(ilyua_runtime) and _invuln>0.0 and (_dash_timer>0.0 or ilyua_runtime.step_left>0) and amount>0.0:
		ilyua_runtime.on_damage_refused(source)
	if CampSession.active:return
	var before_hp:=hp
	var before_shield:=shield_hp
	if is_instance_valid(holy_runtime) and _invuln<=0:amount=holy_runtime.protect(amount,source)
	super.take_damage(amount,from,source)
	if is_instance_valid(holy_runtime):
		if shield_hp<before_shield:holy_runtime.on_shield_absorbed(before_shield-shield_hp)
		if hp<before_hp:holy_runtime.on_hurt()
	if is_instance_valid(ilyua_runtime) and hp<before_hp:ilyua_runtime.on_hp_damage(before_hp-hp)

func fire(dir: Vector2, amount: float, speed_value: float, basic: bool, receipt: BasicAttackReceipt=null) -> RoomProjectile:
	var bullet:RoomProjectile=HolyBolt.new() if is_instance_valid(holy_runtime) else RoomProjectile.new()
	bullet.room=room; bullet.damage_owner=&"player"; bullet.is_friendly=true; bullet.use_fireball_art=true; bullet.art_scale=1.25
	bullet.is_basic_attack=basic; bullet.attack_receipt=receipt
	if basic:
		var profile:=WeaponArt.profile()
		bullet.weapon_fx=str(profile.get("fx","wand_arcane"));speed_value=float(profile.get("speed",speed_value));bullet.range_limit=float(profile.get("reach",540))
		bullet.enable_basic_tracking(dir,global_position+dir*14)
		if is_instance_valid(equipment_aura):equipment_aura.on_attack()
	bullet.burn_dps=stats.get_value(&"attack")*GameState.talent_effect(&"ignite","点燃每秒攻击力%")/100
	if GameState.passive_id==&"sylphiette_aoe":
		bullet.explosion_radius=(72+GameState.talent_rank(&"blast")*12)*(1+GameState.talent_effect(&"chain_blast","爆炸范围加成%")/100)
		bullet.explosion_ratio=1+GameState.talent_rank(&"blast")*.2
	elif GameState.talent_rank(&"blast")>0:
		bullet.explosion_radius=GameState.talent_effect(&"blast","溅射半径")*(1+GameState.talent_effect(&"chain_blast","爆炸范围加成%")/100)
		bullet.explosion_ratio=GameState.talent_effect(&"blast","溅射伤害%")/100
	if is_instance_valid(holy_runtime):bullet.use_fireball_art=false;bullet.burn_dps=0;bullet.explosion_radius=0;bullet.explosion_ratio=0
	get_tree().get_first_node_in_group("room_fx").add_child(bullet)
	# Damage follows the floor plane; the visual launch is raised to the held staff.
	bullet.setup(global_position+dir*14,dir,amount,speed_value,room,null,Color("ffe4ac") if is_instance_valid(holy_runtime) else Color("ffb97d"))
	return bullet

func _update_animation() -> void:
	if _sprite==null:return
	var holy:=is_instance_valid(holy_runtime)
	if holy and _holy_animation_seen!=_animation_request and (_swing_timer>0 or _cast_timer>0):
		_holy_pose_left=.32/minf(2.5,maxf(1,stats.get_value(&"attack_speed")*.55))
	var moving:=velocity.length()>20
	var action:="walk" if moving else "idle"
	if (firing and not holy) or _swing_timer>0 or _cast_timer>0 or _holy_pose_left>0:
		action=("back_attack" if velocity.normalized().dot(aim_direction)<-0.45 else "move_attack") if moving else "attack"
	var wanted:=StringName(action+"_"+RoomHeroArt.direction_name(aim_direction))
	var bow_action:bool=is_instance_valid(ilyua_runtime) and action in ["attack","move_attack","back_attack"]
	var holy_action:bool=is_instance_valid(holy_runtime) and action in ["attack","move_attack","back_attack"]
	if hp<=0: wanted=&"death"
	elif extraction_pose==&"prayer": wanted=&"prayer"
	elif extraction_pose!=&"": wanted=&"interact"
	if not _sprite.sprite_frames.has_animation(wanted):wanted=&"idle_s"
	if _sprite.animation!=wanted:
		var old:=str(_sprite.animation)
		var moving_before:=old.begins_with("walk_") or old.begins_with("move_attack_") or old.begins_with("back_attack_")
		var phase:=float(_sprite.frame)+_sprite.frame_progress
		var playing_before:=_sprite.is_playing()
		_sprite.play(wanted)
		var holy_carry:=not holy_action or (not old.begins_with("walk_") and _holy_animation_seen==_animation_request)
		var holy_cast_before:=old.begins_with("attack_") or old.begins_with("move_attack_") or old.begins_with("back_attack_")
		var same_holy_cast:=holy_action and holy_cast_before and _holy_animation_seen==_animation_request
		if same_holy_cast or (moving and moving_before and action in ["walk","move_attack","back_attack"] and holy_carry and (not bow_action or not old.begins_with("walk_") and playing_before and _swing_timer<=.15)):
			_sprite.set_frame_and_progress(int(phase)%_sprite.sprite_frames.get_frame_count(wanted),fposmod(phase,1.0))
	elif (action=="attack" or bow_action) and _swing_timer>0.15 and not _sprite.is_playing():
		if bow_action:_sprite.set_frame_and_progress(0,0)
		_sprite.play(wanted)
	if holy_action and extraction_pose==&"" and hp>0 and _holy_animation_seen!=_animation_request:
		_holy_animation_seen=_animation_request;_sprite.play(wanted);_sprite.set_frame_and_progress(0,0)
	_sprite.speed_scale=minf(2.5,maxf(1,stats.get_value(&"attack_speed")*.55)) if holy_action else maxf(.1,stats.get_value(&"attack_speed")*.5) if bow_action else clampf(velocity.length()/180.0,0.75,1.15) if moving else 1.0
	_sprite.flip_h=facing<0 if wanted in [&"death",&"interact",&"prayer"] else RoomHeroArt.flip_for(action,RoomHeroArt.direction_name(aim_direction))
	RoomHeroArt.align(_sprite)

func _draw() -> void:
	draw_set_transform(Vector2(0,14),0,Vector2(1,0.35)); draw_circle(Vector2.ZERO,10.5,Color(0,0,0,0.25)); draw_set_transform(Vector2.ZERO)
	if extraction_pose==&"" and not RoomInput.using_mouse() and not RoomInput.using_auto():
		var at:=aim_direction*32
		draw_arc(at,5,0,TAU,12,Color("fce0a1"),1)
		draw_line(at-aim_direction*5,at+aim_direction*5,Color("fce0a1"),1)

func _die()->void:
	_sprite.process_mode=Node.PROCESS_MODE_ALWAYS;_update_animation()
	Effects.death_burst(get_parent(),global_position,Palette.PLAYER_BODY,22)
	EventBus.player_died.emit();set_physics_process(false)
	var tween:=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(1.1);tween.tween_callback(hide)

func _sync_spell_shield()->void:
	if is_instance_valid(holy_runtime):return
	if Characters.current_id()!=&"sylphiette" or shield_hp<=0 or _shield_time<=0:return
	for child in get_children():
		if child is RoomSpellSpriteFX and child.shield_owner!=null:return
	var shield_fx:=RoomSpellSpriteFX.spawn(self,Vector2.ZERO,&"flame_shield",76,_shield_time,true)
	if shield_fx!=null:shield_fx.shield_owner=weakref(self)

func _dash_spell_fx()->void:
	if Characters.current_id()==&"xixifu":
		var glow:=PixelSpellFX.spawn(get_parent(),global_position-Vector2(0,12),"star","cast",70,.35)
		if is_instance_valid(glow):glow.modulate=Color("c3a0ff")
	elif Characters.current_id()==&"ilyua":
		IlyuaFX.spawn(get_parent(),global_position,"step",70,.35)
	else:
		HolyFX.spawn(get_parent(),global_position,"cloud",35,.35)

func _restore_dash_collision()->void:
	if _dash_collision_mask>=0:collision_mask=_dash_collision_mask;_dash_collision_mask=-1
	if _dash_collision_layer>=0:collision_layer=_dash_collision_layer;_dash_collision_layer=-1
	if _normal_dash_phase and is_instance_valid(room):
		var point:=room.nearest_clear(position,12)
		position=point if room.body_clear(point,12) else _dash_origin
	_normal_dash_phase=false
