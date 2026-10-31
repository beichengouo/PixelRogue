class_name RoomPlayer
extends Player
var room: RoomLevel
var caster: RoomSkillCaster
var passive_runtime:PassiveRuntime
var equipment_mechanics: EquipmentMechanics
var ilyua_runtime: IlyuaRuntime
var emotes:HeroEmote
var holy_runtime:HolyRuntime
var basic_chain := XixifuBasicChain.new()
var _walk_phase := 0.0
var firing := false
var movement_override := Vector2.ZERO
var _dash_vector := Vector2.RIGHT
var _dash_spell_active:=false
var _dash_collision_mask:=-1
var _dash_collision_layer:=-1
var _normal_dash_phase:=false
var _dash_origin:=Vector2.ZERO
var _mouse_attack_blocked := true
var _skill_animation_serial := -1
var _holy_animation_seen:=-1
var _holy_pose_left:=0.0

func set_extraction_pose(pose: StringName, hide_model := false) -> void:
	if pose!=&"":cancel_basic_chain()
	if pose!=&"" and is_instance_valid(caster):caster.cancel_cast()
	if pose!=&"" and is_instance_valid(emotes):emotes.clear()
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
	emotes=HeroEmote.new();emotes.actor=self;add_child(emotes)
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
	cancel_basic_chain()
	basic_chain.restore_cooldown(_attack_cd,stats.get_value(&"attack_speed"))
	var animation:=_sprite.animation;var frame:=_sprite.frame;var progress:=_sprite.frame_progress
	_sprite.sprite_frames=frames;_sprite.play(animation if frames.has_animation(animation) else &"idle_s");_sprite.set_frame_and_progress(frame%frames.get_frame_count(_sprite.animation),progress);RoomHeroArt.align(_sprite)

func _physics_process(dt: float) -> void:
	if get_tree().paused or UIFlow.has_screen():return
	_update_timers(dt)
	if velocity.length()>20:_walk_phase=fposmod(_walk_phase+dt*7.5*clampf(velocity.length()/180.0,.75,1.15),4.0)
	_holy_pose_left=maxf(0,_holy_pose_left-dt)
	_sync_spell_shield()
	if extraction_controls_locked():
		if uses_basic_chain():advance_basic_chain(dt,false)
		velocity=Vector2.ZERO; _update_visual(dt); return
	var pilot:=GameState.gm_pilot_active and not CampSession.active
	var movement := movement_override if pilot or movement_override!=Vector2.ZERO else RoomInput.movement()
	if extraction_pose==&"prayer":
		if movement!=Vector2.ZERO: extraction_interrupted.emit()
		else:
			if uses_basic_chain():advance_basic_chain(dt,false)
			velocity=Vector2.ZERO; _update_visual(dt); return
	var mouse_mode := RoomInput.using_mouse()
	var auto_mode:=RoomInput.using_auto()
	var held := MobileControls.attacking() if MobileControls.enabled() else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not held:_mouse_attack_blocked=false
	var aim := RoomInput.auto_aim(self) if auto_mode else RoomInput.pointer_aim(self) if mouse_mode else RoomInput.aim()
	firing=(held and not _mouse_attack_blocked) if mouse_mode else aim!=Vector2.ZERO
	firing=firing or aim_override!=Vector2.ZERO
	if aim_override!=Vector2.ZERO: aim=RoomInput.quantize(aim_override)
	if pilot:aim=aim_override;firing=not aim.is_zero_approx()
	if aim!=Vector2.ZERO: aim_direction=aim
	elif movement!=Vector2.ZERO and not mouse_mode:aim_direction=RoomInput.quantize(movement)
	if absf(aim_direction.x)>0.1: facing=1 if aim_direction.x>0 else -1
	var forest_stepping:=is_instance_valid(ilyua_runtime) and ilyua_runtime.step_left>0
	if forest_stepping:velocity=ilyua_runtime.step_motion(dt)
	elif _dash_timer>0: velocity=_dash_vector*stats.get_value(&"move_speed")*2.7*movement_slow_multiplier()
	else:
		velocity=velocity.move_toward(movement*stats.get_value(&"move_speed")*movement_slow_multiplier(),2100*dt)
		if not pilot and Input.is_action_just_pressed("dash") and _dash_cd<=0 and movement!=Vector2.ZERO:
			request_dash_direction(movement)
	if _dash_timer>0:
		if _dash_collision_mask<0:_dash_collision_mask=collision_mask
		if _dash_collision_layer<0:_dash_collision_layer=collision_layer
		_normal_dash_phase=true;collision_mask=0;collision_layer=0
	else:
		if _normal_dash_phase:
			if is_instance_valid(equipment_mechanics):equipment_mechanics.fate_runtime.dash_end()
			_restore_dash_collision()
		if forest_stepping:
			if _dash_collision_mask<0:_dash_collision_mask=collision_mask
			collision_mask=(_dash_collision_mask&~Layers.UNIT_BODY)|Layers.ENEMY
		elif _dash_collision_mask>=0:_restore_dash_collision()
	# Launch from the resolved current position, including walls and dash travel.
	var fate_from:=global_position
	move_and_slide()
	if _normal_dash_phase:
		var bounds:=room.bounds().grow(-12)
		position=Vector2(clampf(position.x,bounds.position.x,bounds.end.x),clampf(position.y,bounds.position.y,bounds.end.y))
	if is_instance_valid(equipment_mechanics):equipment_mechanics.fate_runtime.record_motion(fate_from,global_position,not forest_stepping and not _normal_dash_phase and _hurt_timer<=0 and extraction_pose==&"",_normal_dash_phase)
	if not pilot and auto_mode and aim_override.is_zero_approx():
		var automatic:=RoomInput.auto_aim(self);firing=automatic!=Vector2.ZERO
		if firing:aim_direction=automatic
	if not pilot and mouse_mode and aim_override.is_zero_approx():
		var pointer := RoomInput.pointer_aim(self)
		if not pointer.is_zero_approx():aim_direction=pointer
	if absf(aim_direction.x)>0.1:facing=1 if aim_direction.x>0 else -1
	for slot in 4:
		if not pilot and Input.is_action_just_pressed(["skill_1","skill_2","skill_3","ultimate"][slot]): caster.request(slot)
	if uses_basic_chain():
		advance_basic_chain(dt,firing)
	elif firing:request_attack()
	if not pilot:_try_potions()
	if forest_stepping and ilyua_runtime.step_left<=0:velocity=movement*stats.get_value(&"move_speed")*movement_slow_multiplier()
	if _dash_spell_active and _dash_timer<=0:_dash_spell_fx();_dash_spell_active=false;equipment_mechanics.on_dash_end()
	_move_input_active=movement!=Vector2.ZERO
	_update_visual(dt)
	queue_redraw()

func request_dash() -> void:
	var movement := movement_override if movement_override != Vector2.ZERO else RoomInput.movement()
	request_dash_direction(movement if movement != Vector2.ZERO else aim_direction)

func stop_room_travel_motion()->void:
	cancel_basic_chain()
	firing=false
	if is_instance_valid(equipment_mechanics):equipment_mechanics.fate_runtime.motion_reset()
	if is_instance_valid(emotes):emotes.clear()
	if is_instance_valid(caster):caster.cancel_cast()
	# Transition screens pause physics, so a dash's remaining time otherwise
	# survives the entire load and resumes at the destination's entrance.
	_dash_timer=0;_dash_spell_active=false
	_restore_dash_collision()
	_dash_vector=Vector2.ZERO;_dash_origin=position
	velocity=Vector2.ZERO;_swing_timer=0;_cast_timer=0;_holy_pose_left=0
	if is_instance_valid(ilyua_runtime):
		ilyua_runtime.step_left=0;ilyua_runtime.step_direction=Vector2.ZERO
	# Dash/skill cooldowns and existing defensive buffs remain unchanged.

func uses_basic_chain()->bool:
	return _sprite!=null and bool(_sprite.sprite_frames.get_meta("xixifu_chain",false))

func _basic_input_allowed()->bool:
	return hp>0 and extraction_pose==&"" and not get_tree().paused and not UIFlow.has_screen() and (GameState.run_active or CampSession.active) and not caster.busy() and _dash_timer<=0

func cancel_basic_chain()->void:
	if uses_basic_chain():_attack_cd=basic_chain.remaining()/maxf(.1,stats.get_value(&"attack_speed"))
	basic_chain.cancel()

func reset_basic_after_restore()->void:
	basic_chain.restore_cooldown(_attack_cd,stats.get_value(&"attack_speed"))
	firing=false;aim_override=Vector2.ZERO;_mouse_attack_blocked=true;_swing_timer=0
	caster.cancel_cast()

func advance_basic_chain(dt:float,held:bool)->void:
	if get_tree().paused or UIFlow.has_screen():return
	if not _basic_input_allowed():basic_chain.cancel()
	basic_chain.advance(dt,stats.get_value(&"attack_speed"),held and _basic_input_allowed(),aim_direction,_emit_basic)
	_attack_cd=basic_chain.remaining()/maxf(.1,stats.get_value(&"attack_speed"))

func request_attack()->void:
	if not _basic_input_allowed():return
	if uses_basic_chain():basic_chain.request();return
	if _attack_cd>0:return
	_emit_basic(1,aim_direction)
	_attack_cd=(.44 if is_instance_valid(ilyua_runtime) and ilyua_runtime.ultimate_left>0 else .70)/maxf(.1,stats.get_value(&"attack_speed"))

func _emit_basic(stage:int,direction:Vector2)->bool:
	if not _basic_input_allowed():return false
	var receipt:=BasicAttackReceipt.new(self)
	var roll:=Combat.roll_attack(stats,Rng.stream());roll.damage=float(roll.damage)*1.5;receipt.critical=bool(roll.crit)
	if is_instance_valid(ilyua_runtime):ilyua_runtime.fire_basic(direction,roll,receipt)
	else:
		var finisher:=uses_basic_chain() and stage==5
		var equipment_roll:=roll.duplicate()
		if finisher:equipment_roll.damage=float(roll.damage)*1.5
		if not equipment_mechanics.fire_basic(direction,equipment_roll,receipt):
			if finisher:
				for angle:float in [-10.0,0.0,10.0]:fire(direction.rotated(deg_to_rad(angle)),float(roll.damage)*.5,430,true,receipt)
			else:fire(direction,float(roll.damage),430,true,receipt)
		equipment_mechanics.on_basic_fired(direction,receipt)
	_swing_timer=.18
	if is_instance_valid(holy_runtime) or bool(_sprite.sprite_frames.get_meta("handdrawn",false)):_animation_request+=1
	return true

func request_dash_direction(direction: Vector2) -> void:
	if hp <= 0.0 or _dash_cd > 0.0 or direction.is_zero_approx(): return
	cancel_basic_chain()
	_dash_origin=position;_dash_vector=direction.normalized();_dash_timer=0.16;_dash_cd=stats.get_value(&"dash_cooldown")
	_invuln=maxf(_invuln,0.16);_dash_spell_active=true;_dash_spell_fx()
	if is_instance_valid(ilyua_runtime):ilyua_runtime.on_dash_started()

func take_damage(amount: float, from: Vector2, source: Node = null, direct_hit := true) -> void:
	if is_instance_valid(ilyua_runtime) and _invuln>0.0 and (_dash_timer>0.0 or ilyua_runtime.step_left>0) and amount>0.0:
		ilyua_runtime.on_damage_refused(source)
	if CampSession.active:return
	var before_hp:=hp
	var before_shield:=shield_hp
	if is_instance_valid(holy_runtime) and _invuln<=0:amount=holy_runtime.protect(amount,source)
	super.take_damage(amount,from,source,direct_hit)
	if hp<before_hp and hp>0 and is_instance_valid(equipment_mechanics):equipment_mechanics.etching.hurt()
	if shield_hp<before_shield:
		AudioManager.play(&"shield_break" if shield_hp<=0 else &"shield_hit",-9 if shield_hp<=0 else -16,0)
		if shield_hp<=0:CombatContactFX.spawn(get_parent(),global_position,&"shield",true)
		if is_instance_valid(equipment_mechanics):equipment_mechanics.legendary.shield_absorbed()
		if is_instance_valid(summons):summons.transfer_shelter()
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
		if is_instance_valid(equipment_aura) and (receipt==null or receipt.claim_effect(&"weapon_aura")):equipment_aura.on_attack()
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
	if uses_basic_chain() and _update_chain_animation():return
	if is_instance_valid(caster) and caster.busy() and hp>0 and extraction_pose==&"":
		var cast_direction := RoomHeroArt.direction_name(caster._cast_direction)
		var cast_animation := StringName("skill_cast_" + cast_direction)
		if _sprite.sprite_frames.has_animation(cast_animation):
			if _sprite.animation != cast_animation or caster._pending_slot>=0 and _skill_animation_serial<0:
				_sprite.play(cast_animation); _sprite.set_frame_and_progress(0,0); _skill_animation_serial=maxi(0,caster._pending_slot)
			_sprite.speed_scale = 1.0; _sprite.flip_h = RoomHeroArt.flip_for("skill_cast",cast_direction)
			RoomHeroArt.align(_sprite); return
	if hp>0 and extraction_pose==&"" and _hurt_timer>0 and _flash>.14 and _sprite.sprite_frames.has_animation(&"hurt"):
		if _sprite.animation!=&"hurt":_sprite.play(&"hurt");_sprite.set_frame_and_progress(0,0)
		_sprite.speed_scale=1;_sprite.flip_h=RoomHeroArt.utility_flip(_sprite.sprite_frames,facing);RoomHeroArt.align(_sprite);return
	# Painted spellcasters have finite prepare/release/recover clips. Restart
	# them on an actual shot, including moving shots, rather than looping or
	# leaving a non-looping movement cast frozen on its final frame.
	var holy:=is_instance_valid(holy_runtime) or (bool(_sprite.sprite_frames.get_meta("handdrawn",false)) and not is_instance_valid(ilyua_runtime))
	if holy and _holy_animation_seen!=_animation_request and (_swing_timer>0 or _cast_timer>0):
		_holy_pose_left=.32/minf(2.5,maxf(1,stats.get_value(&"attack_speed")*.55))
	var moving:=velocity.length()>20
	var action:="walk" if moving else "idle"
	if (firing and not holy) or _swing_timer>0 or _cast_timer>0 or _holy_pose_left>0:
		action=("back_attack" if velocity.normalized().dot(aim_direction)<-0.45 else "move_attack") if moving else "attack"
	var wanted:=StringName(action+"_"+RoomHeroArt.direction_name(aim_direction))
	var bow_action:bool=is_instance_valid(ilyua_runtime) and action in ["attack","move_attack","back_attack"]
	var holy_action:bool=holy and action in ["attack","move_attack","back_attack"]
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
	_sprite.flip_h=RoomHeroArt.utility_flip(_sprite.sprite_frames,facing) if wanted in [&"death",&"interact",&"prayer"] else RoomHeroArt.flip_for(action,RoomHeroArt.direction_name(aim_direction))
	RoomHeroArt.align(_sprite)

func _sample_chain_pose(name_value:StringName,elapsed:float,durations:Array,flip:bool)->void:
	_sprite.play(name_value);_sprite.pause();_sprite.speed_scale=1.0;_sprite.flip_h=flip
	var left:=elapsed
	for index in durations.size():
		var duration:=float(durations[index])
		if left<duration or index==durations.size()-1:
			_sprite.set_frame_and_progress(index,clampf(left/duration,0,1));break
		left-=duration
	RoomHeroArt.align(_sprite)

func _update_chain_animation()->bool:
	# Utility clips retain the established animation and mirroring path.
	if hp<=0 or extraction_pose!=&"" or _hurt_timer>0 and _flash>.14:return false
	if caster.busy():
		var elapsed:=RoomSkillCaster.WINDUP_SECONDS-caster._windup_left if caster._pending_slot>=0 else RoomSkillCaster.WINDUP_SECONDS+RoomSkillCaster.RECOVERY_SECONDS-caster._recovery_left
		var direction:=RoomHeroArt.direction_name(caster._cast_direction)
		_sample_chain_pose(StringName("skill_cast_"+direction),elapsed,[.08,.24,.05,.05],RoomHeroArt.flip_for("skill_cast",direction));return true
	if basic_chain.active:
		var action:=("move_attack" if velocity.length()>20 else "attack")+str(basic_chain.stage+1)
		var direction:=RoomHeroArt.direction_name(basic_chain.visual_aim(aim_direction))
		var tail:=float(XixifuBasicChain.DURATIONS[basic_chain.stage])-XixifuBasicChain.RELEASE
		_sample_chain_pose(StringName(action+"_"+direction),basic_chain.elapsed(),[XixifuBasicChain.RELEASE,tail*.25,tail*.35,tail*.4],RoomHeroArt.flip_for(action,direction));return true
	var direction:=RoomHeroArt.direction_name(aim_direction)
	if velocity.length()>20:
		_sample_chain_pose(StringName("walk_"+direction),_walk_phase,[1,1,1,1],RoomHeroArt.flip_for("walk",direction))
	else:_sample_chain_pose(StringName("idle_"+direction),0,[1],RoomHeroArt.flip_for("idle",direction))
	return true

func _draw() -> void:
	draw_set_transform(Vector2(0,14),0,Vector2(1,0.35)); draw_circle(Vector2.ZERO,10.5,Color(0,0,0,0.25)); draw_set_transform(Vector2.ZERO)
	if extraction_pose==&"" and not RoomInput.using_mouse() and not RoomInput.using_auto():
		var at:=aim_direction*32
		draw_arc(at,5,0,TAU,12,Color("fce0a1"),1)
		draw_line(at-aim_direction*5,at+aim_direction*5,Color("fce0a1"),1)

func _die()->void:
	cancel_basic_chain()
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
