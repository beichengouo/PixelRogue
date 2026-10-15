class_name SummonController
extends Node
## Contracts belong to the player, not the hire roster; their lifetime uses paused game time.
var actor:Player
var serial:=0

func companions(guardian_only:=false)->Array:
	var found:Array=[]
	for unit in get_tree().get_nodes_in_group("contracts"):
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp>0 and unit.player==actor and (not guardian_only or unit.guardian):found.append(unit)
	return found

func safe_positions(count:int, radius:float=12)->Array[Vector2]:
	var positions:Array[Vector2]=[]
	if count<=0:return positions
	var occupied:Array[Dictionary]=[]
	for unit in get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp>0:occupied.append({"at":unit.global_position,"radius":unit.body_radius() if unit.has_method("body_radius") else 12.0})
	for distance in [36.0,60.0,84.0,108.0]:
		for index in 12:
			var at:Vector2=actor.global_position+Vector2.RIGHT.rotated(index*TAU/12)*float(distance)
			var clear:=true
			for other in occupied:
				if at.distance_to(other.at)<radius+float(other.radius):clear=false;break
			if not clear:continue
			if not actor.room.body_clear(at,radius) or not actor.room.sight(actor.global_position,at):continue
			positions.append(at);occupied.append({"at":at,"radius":radius})
			if positions.size()==count:return positions
	return positions

func cast(slot:int)->bool:
	if UIFlow.has_screen() or (not GameState.run_active and not CampSession.active):return false
	if not is_instance_valid(actor) or actor.hp<=0 or actor.extraction_pose!=&"":return false
	var id:=GameState.skill_for_slot(slot)
	if not SummonerSkills.DATA.has(id) or not GameState.skill_ready(slot):return false
	var effect:Dictionary=Skills.get_skill(id).effect
	var positions:Array[Vector2]=[]
	var landing:=actor.global_position
	if effect.kind=="summon":
		positions=safe_positions(int(effect.count),18 if bool(effect.get("guardian",false)) else 12)
		if positions.size()<int(effect.count):
			Effects.text(actor.get_parent(),actor.global_position-Vector2(0,56),"附近没有召唤空间",PixelUi.MUTED,14);return false
	if effect.kind=="rally":
		positions=parade_positions()
		if positions.size()<8:
			Effects.text(actor.get_parent(),actor.global_position-Vector2(0,56),"附近没有召唤空间",PixelUi.MUTED,14);return false
	if GameState.begin_skill_cast(slot)==&"":return false
	var cast_bonus: float = (actor as RoomPlayer).equipment_mechanics.on_skill_cast(str(effect.kind)=="shelter",id) if actor is RoomPlayer else 1.0
	var base:Dictionary={}
	if id in [&"shadow_companions",&"ghost_lantern"]:
		base=SummonRules.hero_snapshot(actor,effect)
	var perform:=func()->void:_release(effect,positions,landing,base,cast_bonus)
	if not UltimateCutin.present(actor,id,perform):perform.call()
	return true

func _release(effect:Dictionary,positions:Array[Vector2],landing:Vector2,base:Dictionary,cast_bonus:float=1.0)->void:
	actor._cast_timer=0.28;actor._cast_pose=&"cast";actor._animation_request+=1
	var healing:=1+GameState.talent_effect(&"shadow_care","契约治疗加成%")/100
	match str(effect.kind):
		"summon":
			for at in positions:_summon(effect,at,base)
		"recall":
			var units:=companions()
			var spots:Array[Vector2]=safe_positions(units.size())
			for i in units.size():
				if i<spots.size():units[i].global_position=spots[i];units[i].velocity=Vector2.ZERO
				units[i].heal(units[i].max_hp*float(effect.heal)*healing)
			actor.heal_player(actor.max_hp*float(effect.self_heal)*healing)
		"shelter":
			actor.shield_hp=maxf(actor.shield_hp,actor.max_hp*float(effect.shield)*(1+GameState.talent_effect(&"shadow_care","夜幕护盾加成%")/100))
			actor._shield_time=float(effect.duration)+GameState.talent_effect(&"shelter_duration","护盾额外秒数");actor._shield_thorns=0
			for ally in get_tree().get_nodes_in_group("allies"):
				if not ally is HiredAlly or not is_instance_valid(ally) or ally.is_queued_for_deletion() or ally.hp<=0:continue
				if ally is RoomAlly and ally.room!=actor.room:continue
				ally.shield_hp=maxf(ally.shield_hp,ally.max_hp*float(effect.shield)*(1+GameState.talent_effect(&"shadow_care","夜幕护盾加成%")/100))
				ally.shield_time=float(effect.duration)+GameState.talent_effect(&"shelter_duration","护盾额外秒数")
				if ally is SummonedAlly and ally.player==actor:ally.heal(ally.max_hp*float(effect.heal)*healing)
		"shadow_echo":
			var radius:=float(effect.radius)+GameState.talent_effect(&"shadow_stride","影步额外距离")
			ContractSpellFX.spawn(actor.get_parent(),actor.global_position,0,radius*2,.4)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy._dead or actor.global_position.distance_to(enemy.global_position)>radius or not actor.room.sight(actor.global_position,enemy.global_position):continue
				var before: float = enemy.hp
				var mechanics: EquipmentMechanics=(actor as RoomPlayer).equipment_mechanics
				enemy.take_damage(actor.stats.get_value(&"attack")*float(effect.ratio)*cast_bonus*mechanics.skill_multiplier(enemy),false,actor.global_position,DamageContext.skill(actor),false)
				if enemy.hp<before:mechanics.on_skill_hit(enemy,true)
				if not enemy._dead:enemy.apply_slow(float(effect.slow),float(effect.slow_duration))
			for unit in companions():
				unit.remaining=minf(unit.remaining+float(effect.extend),unit.total_duration+float(effect.extend))
				var active_rally:bool=unit.rally_time>0
				unit.rally_time=maxf(unit.rally_time,float(effect.duration))
				unit.rally_attack=maxf(unit.rally_attack if active_rally else 0.0,float(effect.attack))
				unit.rally_haste=maxf(unit.rally_haste if active_rally else 0.0,float(effect.haste));unit._refresh_bonus()
		"rally":
			var guard_effect:Dictionary={"enemy":"guard","attack":effect.get("guard_attack",.65),"hp":effect.get("guard_hp",1.2),"speed":effect.get("guard_speed",150.0),"duration":effect.get("guard_duration",30.0),"art_variant":"parade_guardian"}
			for index in mini(5,positions.size()):_summon(guard_effect,positions[index],{})
			var lantern_effect:Dictionary=SummonerSkills.DATA[&"ghost_lantern"].effect.duplicate(true)
			var lantern_base:=SummonRules.hero_snapshot(actor,lantern_effect)
			for index in range(5,positions.size()):_summon(lantern_effect,positions[index],lantern_base)
			for unit in companions():
				unit.heal(unit.max_hp*float(effect.heal)*healing)
				unit.rally_time=float(effect.duration)+GameState.talent_effect(&"parade_duration","夜行额外秒数")
				unit.rally_attack=float(effect.attack)+GameState.talent_effect(&"parade_power","夜行额外攻击加成%")/100
				unit.rally_haste=float(effect.haste);unit._refresh_bonus()
	Effects.hit_spark(actor.get_parent(),actor.global_position-Vector2(0,24),Color("c3a0ff"),8)
	var glow:=PixelSpellFX.spawn(actor.get_parent(),actor.global_position-Vector2(0,12),"star","cast",64,0.35)
	if is_instance_valid(glow):glow.modulate=Color("c3a0ff")
	AudioManager.play(&"wave_clear",-10)

func _summon(effect:Dictionary,at:Vector2,base:Dictionary)->void:
	serial+=1
	var unit:SummonedAlly=SummonedAlly.new()
	unit.player=actor;unit.level=actor.level;unit.fx_root=actor.get_parent();unit.uid="contract_%d_%d_%d"%[GameState.run_epoch,actor.get_instance_id(),serial]
	unit.enemy_kind=StringName(effect.enemy);unit.body_color=Color("c3a0ff");unit.display_name={"walker":"骸灵伙伴","caster":"幽灯伙伴","guard":"骸甲守卫","treant":"树灵守望者"}.get(str(effect.enemy),"契约伙伴")
	unit.art_variant=str(effect.get("art_variant","ghost_lantern" if str(effect.enemy)=="caster" else ("gate_guardian" if str(effect.enemy)=="guard" else "")));unit.guardian=bool(effect.get("guardian",false));unit.attack_ratio=float(effect.attack);unit.hp_ratio_base=float(effect.hp);unit.speed_base=float(effect.speed)
	unit.monster_base_attack=float(base.get("attack",0));unit.monster_base_hp=float(base.get("hp",0))
	unit.remaining=float(effect.duration)+GameState.talent_effect(&"contract_duration","新契约额外秒数")+(GameState.talent_effect(&"guardian_duration","守望者额外秒数") if unit.guardian else 0)
	unit.total_duration=unit.remaining;unit.contract_epoch=GameState.run_epoch;unit.position=at;unit.room=actor.room
	actor.get_parent().add_child(unit)

func parade_positions()->Array[Vector2]:
	var result:Array[Vector2]=[];var occupied:Array[Vector2]=[]
	for unit in get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp>0:occupied.append(unit.global_position)
	for index in 8:
		var angle:float=-PI*.5+(float(index)*TAU/5 if index<5 else float(index-5)*TAU/3)
		var distance:=96.0 if index<5 else 150.0
		var ideal:=actor.global_position+Vector2.RIGHT.rotated(angle)*distance
		var found:=false
		for offset_radius in [0.0,24.0,48.0,72.0,96.0]:
			for step in (1 if offset_radius==0 else 12):
				var point:=ideal+Vector2.RIGHT.rotated(float(step)*TAU/12)*float(offset_radius)
				if point.distance_to(actor.global_position)<42 or not actor.room.body_clear(point,12) or not actor.room.sight(actor.global_position,point) or not actor.room.unit_position_clear(point,12,actor):continue
				var clear:=true
				for at in occupied:
					if point.distance_to(at)<40:clear=false;break
				if not clear:continue
				result.append(point);occupied.append(point);found=true;break
			if found:break
		if not found:return []
	return result
