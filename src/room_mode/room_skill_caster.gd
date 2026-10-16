class_name RoomSkillCaster
extends Node
var actor: RoomPlayer
var room: RoomLevel
const INPUT_BUFFER_SECONDS:=.15
var _buffer_slot:=-1
var _buffer_skill:StringName=&""
var _buffer_left:=0.0
var _buffer_frame:=-1
func _ready()->void:
	UIFlow.stack_changed.connect(func()->void:
		if UIFlow.has_screen():clear_input_buffer())
func clear_input_buffer()->void:
	_buffer_slot=-1;_buffer_skill=&"";_buffer_left=0
func request(slot:int)->bool:
	if not _input_allowed():clear_input_buffer();return false
	if slot<0 or slot>=4:return false
	var id:=GameState.skill_for_slot(slot)
	if id==&"" or GameState.mp<GameState.skill_cost(id):_notice("魔力不足" if id!=&"" else "技能槽尚未装配");return false
	var left:=float(GameState.skill_cooldowns_by_id.get(id,0))
	if left>INPUT_BUFFER_SECONDS:_notice("技能尚未就绪");return false
	clear_input_buffer()
	if left<=0:return cast(slot)
	_buffer_slot=slot;_buffer_skill=id;_buffer_left=INPUT_BUFFER_SECONDS;_buffer_frame=Engine.get_physics_frames();return true
func _input_allowed()->bool:
	return is_instance_valid(actor) and actor.hp>0 and not UIFlow.has_screen() and (GameState.run_active or CampSession.active) and actor.extraction_pose==&""
func _physics_process(delta:float)->void:
	if _buffer_slot<0:return
	if not _input_allowed() or GameState.skill_for_slot(_buffer_slot)!=_buffer_skill:clear_input_buffer();return
	if _buffer_frame==Engine.get_physics_frames():return
	if GameState.skill_ready(_buffer_slot) and _buffer_left>0:
		var slot:=_buffer_slot;clear_input_buffer();cast(slot);return
	_buffer_left-=delta
	if _buffer_left<=0:clear_input_buffer()
var _notice_until:=0
func _notice(message:String)->void:
	var now:=Time.get_ticks_msec()
	if now<_notice_until:return
	_notice_until=now+700;AudioManager.play(&"skill_unavailable",-12,0)
	Effects.text(actor.get_parent(),actor.global_position-Vector2(0,54),message,PixelUi.MUTED,14)

func target(distance: float) -> Vector2:
	var goal := actor.global_position+actor.aim_direction*distance
	var best := distance*distance
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy._dead: continue
		var offset: Vector2 = enemy.global_position-actor.global_position
		if offset.length_squared()<best and actor.aim_direction.dot(offset.normalized())>=cos(PI/4) and room.sight(actor.global_position,enemy.global_position):
			best=offset.length_squared(); goal=enemy.global_position
	return room.bounds().get_center() if not room.bounds().has_point(actor.global_position) else goal.clamp(room.bounds().position+Vector2(18,18),room.bounds().end-Vector2(18,18))

func cast(slot: int) -> bool:
	if UIFlow.has_screen() or (not GameState.run_active and not CampSession.active) or actor.hp<=0:return false
	if is_instance_valid(actor.ilyua_runtime):return actor.ilyua_runtime.cast(slot)
	if is_instance_valid(actor.holy_runtime):return actor.holy_runtime.cast(slot)
	if is_instance_valid(actor.summons):return actor.summons.cast(slot)
	var id := GameState.skill_for_slot(slot)
	if id == &"" or not GameState.skill_ready(slot): return false
	var skill := Skills.get_skill(id,"rooms")
	var effect: Dictionary = skill.effect
	var field_target:=actor.global_position
	if id in [&"meteor",&"starfall"]:
		field_target=target(216) if id==&"meteor" else (actor.global_position+actor.aim_direction*108).clamp(room.bounds().position+Vector2(18,18),room.bounds().end-Vector2(18,18))
		if not room.body_clear(field_target,1) or not room.sight(actor.global_position,field_target):
			Effects.text(actor.get_parent(),actor.global_position-Vector2(0,54),"目标被障碍遮挡",PixelUi.MUTED,14);return false
	if GameState.begin_skill_cast(slot)==&"": return false
	var cast_bonus:=actor.equipment_mechanics.on_skill_cast(id==&"flame_shield",id)
	var perform:=func()->void:_release(id,skill,field_target,cast_bonus)
	if not UltimateCutin.present(actor,id,perform):perform.call()
	return true

func _release(id:StringName,skill:Dictionary,field_target:Vector2,cast_bonus:float=1.0)->void:
	var effect:Dictionary=skill.effect
	var attack := actor.stats.get_value(&"attack") * cast_bonus
	var heal_scale := 1+GameState.talent_effect(&"nature_attune","自然治疗加成%")/100
	actor._cast_timer = 0.28; actor._cast_pose = &"cast"; actor._animation_request+=1
	if not ResourceLoader.exists("res://assets/next_revision/fx/sylphiette_spells.png"):PixelSpellFX.spawn(actor.get_parent(),actor.global_position,"nature" if skill.role=="自然" else "fire","cast",55,0.35)
	match id:
		&"flame_nova":
			var radius:=108+GameState.talent_effect(&"nova_shot","烬环额外半径")
			var wave_fx:=RoomSpellSpriteFX.spawn(actor.get_parent(),actor.global_position,id,radius*2,.4)
			if wave_fx==null:PixelSpellFX.spawn(actor.get_parent(),actor.global_position,"fire","impact",radius*2,.4)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy._dead:continue
				if actor.global_position.distance_to(enemy.global_position)>radius or not room.sight(actor.global_position,enemy.global_position):continue
				var before: float = enemy.hp
				enemy.take_damage(attack*.9*(1+GameState.talent_effect(&"nova_might","烬环伤害加成%")/100)*actor.equipment_mechanics.skill_multiplier(enemy),false,actor.global_position,DamageContext.skill(actor),false)
				if enemy.hp<before:actor.equipment_mechanics.on_skill_hit(enemy,true)
				if enemy._dead:continue
				var distance:float=72*(1+GameState.talent_effect(&"nova_pierce","烬环推力加成%")/100)*(.25 if enemy is BossBase else 1)
				var body_radius:=_push_body_radius(enemy)
				var dir:Vector2=(enemy.global_position-actor.global_position).normalized()
				var destination:Vector2=enemy.global_position
				for i in range(1,ceili(distance/3)+1):
					var probe:Vector2=enemy.global_position+dir*minf(distance,i*3)
					if not room.body_clear(probe,body_radius,enemy.is_flying() if enemy.has_method("is_flying") else false):break
					destination=probe
				if not enemy.training_target:enemy.global_position=destination
				if GameState.talent_rank(&"nova_ghost")>0:enemy.apply_slow(.2,2.0)
		&"fan_bolts":
			var fan_fx:=RoomSpellSpriteFX.spawn(actor.get_parent(),actor.global_position,id,126,.4)
			if fan_fx!=null:fan_fx.rotation=actor.aim_direction.angle()+PI/2
			for i in int(effect.shots):
				var angle:=(float(i)/maxi(1,int(effect.shots)-1)-.5)*deg_to_rad(46)
				var bullet:=actor.fire(actor.aim_direction.rotated(angle),attack*float(effect.ratio),float(effect.speed),false)
				bullet.mechanic_tag=&"skill"
				bullet.range_limit=288
		&"blink":
			var radius:=float(effect.radius)+GameState.talent_effect(&"star_step","星跃额外距离")
			Effects.cast_ring(actor.get_parent(),actor.global_position,Color("c4aaff"),radius,.4)
			PixelSpellFX.spawn(actor.get_parent(),actor.global_position-Vector2(0,12),"star","impact",radius*2,.4)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy._dead or actor.global_position.distance_to(enemy.global_position)>radius or not room.sight(actor.global_position,enemy.global_position):continue
				var before: float = enemy.hp
				enemy.take_damage(attack*float(effect.ratio)*actor.equipment_mechanics.skill_multiplier(enemy),false,actor.global_position,DamageContext.skill(actor),false)
				if enemy.hp<before:actor.equipment_mechanics.on_skill_hit(enemy,true)
				if not enemy._dead:enemy.apply_slow(float(effect.slow),float(effect.slow_duration))
			if GameState.talent_rank(&"quick_weave")>0: GameState.add_temp_buff(&"attack",GameState.talent_effect(&"quick_weave","星跃后4秒攻击加成%")/100,4,"灵动编织")
		&"meteor",&"frost_nova",&"starfall":
			var field := RoomSkillField.new(); field.room=room; field.caster=weakref(actor)
			field.direction=actor.aim_direction; field.damage=attack*float(effect.ratio)
			field.skill_id=id
			field.kind=str(effect.kind)
			field.position=actor.global_position
			if id==&"meteor": field.position=field_target; field.radius=108*(1+GameState.talent_effect(&"chain_blast","爆炸范围加成%")/100); field.delay=0.65; field.kind="meteor"
			elif id==&"frost_nova": field.remaining=3+GameState.talent_effect(&"thorn_bind","缠绕额外秒数"); field.kind="snare"
			else:
				field.position=field_target; field.remaining=5+GameState.talent_effect(&"living_bloom","领域额外秒数"); field.kind="bloom"
			room.add_child(field)
		&"flame_shield":
			actor.equipment_mechanics.grant_player_shield(actor.max_hp*0.18*(1+GameState.talent_effect(&"nature_attune","护盾加成%")/100),6,&"extend");actor._shield_thorns=8
			for child in actor.get_children():
				if child is RoomSpellSpriteFX and child.shield_owner!=null:child.queue_free()
			var shield_fx:=RoomSpellSpriteFX.spawn(actor,Vector2.ZERO,id,76,6,true)
			if shield_fx!=null:shield_fx.shield_owner=weakref(actor)
		&"healing_light":
			RoomSpellSpriteFX.spawn(actor.get_parent(),actor.global_position,id,216,.6)
			actor.heal_player(actor.max_hp*0.22*heal_scale)
			for ally in get_tree().get_nodes_in_group("allies"):
				if is_instance_valid(ally) and actor.global_position.distance_to(ally.global_position)<=108 and room.sight(actor.global_position,ally.global_position): ally.heal(ally.max_hp*0.11*heal_scale)
	if skill.role=="自然": GameState.add_mp(GameState.talent_effect(&"sprout_return","自然施法返还魔力"))
	AudioManager.play(&"wave_clear",-10)

func _push_body_radius(body:Node2D)->float:
	# Include collider scaling and offsets so the whole pushed body remains on land.
	var radius:=0.0
	for child in body.get_children():
		if not child is CollisionShape2D or child.disabled or child.shape==null:continue
		var local_radius:float=child.shape.radius if child.shape is CircleShape2D else child.shape.get_rect().size.length()*.5
		var scale_factor:float=maxf(child.global_transform.x.length(),child.global_transform.y.length())
		radius=maxf(radius,local_radius*scale_factor+body.global_position.distance_to(child.global_position))
	return radius if radius>0 else (24.0 if body is BossBase else 12.0)


