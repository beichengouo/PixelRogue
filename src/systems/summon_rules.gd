class_name SummonRules
extends RefCounted
static func ready(unit:HiredAlly)->void:
	unit.add_to_group("contracts")
	unit.body_color=Color("c3a0ff")
	refresh(unit,true)
	unit._cooldown=0.4
static func tick(unit:HiredAlly,dt:float)->bool:
	if not is_instance_valid(unit.player) or unit.player.hp<=0 or unit.contract_epoch!=GameState.run_epoch or (not GameState.run_active and not CampSession.active):
		dismiss(unit);return false
	unit.remaining=maxf(0,unit.remaining-dt)
	if unit.remaining<=0 or unit.hp<=0:dismiss(unit);return false
	if unit.rally_time>0:
		unit.rally_time=maxf(0,unit.rally_time-dt);unit._cooldown=maxf(0,unit._cooldown-dt*unit.rally_haste)
		if unit.rally_time==0:refresh(unit)
	return true
static func refresh(unit:HiredAlly,full:=false)->void:
	if not is_instance_valid(unit.player):return
	var ratio:=1.0 if full else clampf(unit.hp/maxf(1,unit.max_hp),0,1)
	var bonus:Dictionary=GameState.ally_bonus()
	var base_hp:float=unit.monster_base_hp if unit.monster_base_hp>0 else unit.player.max_hp*unit.hp_ratio_base
	var base_attack:float=unit.monster_base_attack if unit.monster_base_attack>0 else unit.player.stats.get_value(&"attack")*unit.attack_ratio
	unit.max_hp=base_hp*float(bonus.hp)*(1+GameState.talent_effect(&"contract_vitality","契约物生命加成%")/100)
	unit.hp=unit.max_hp*ratio
	unit.attack=base_attack*float(bonus.attack)*(1+GameState.talent_effect(&"contract_might","契约物攻击加成%")/100)*(1+unit.rally_attack if unit.rally_time>0 else 1)
	unit.move_speed=unit.speed_base*float(bonus.speed)*(1+unit.rally_haste if unit.rally_time>0 else 1)
	unit.queue_redraw()

static func hero_snapshot(actor:Player,effect:Dictionary)->Dictionary:
	# Final player stats are captured once; contract-only bonuses are applied in refresh.
	return {"attack":actor.stats.get_value(&"attack")*float(effect.attack),"hp":actor.max_hp*float(effect.hp)}

static func dismiss(unit:HiredAlly)->void:
	if unit.is_queued_for_deletion():return
	# Returning spirits generate no enemy loot, experience, hire-death notification or remains.
	if unit.has_method("_show_departure"):unit._show_departure()
	Effects.death_burst(unit._fx(),unit.global_position,Color("b895ed"),6)
	unit.hp=0;unit.queue_free()

static func guardian_pulse(unit:HiredAlly,kind:String,at:Vector2)->void:
	var radius:=90.0 if kind=="roots" else 108.0
	var row:=0 if kind=="roots" else 1
	ContractSpellFX.spawn(unit._fx(),at,row,radius*2,.52)
	for enemy in unit.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy._dead:continue
		if at.distance_to(enemy.global_position)>radius:continue
		var clear:bool=unit.room.sight(at,enemy.global_position) if unit is SummonedAlly else (not is_instance_valid(unit.level) or unit.level.clear_sight(at,enemy.global_position))
		if not clear:continue
		var before: float = enemy.hp
		enemy.take_damage(unit.attack*(.8 if kind=="roots" else 1.6),false,at,unit)
		if is_instance_valid(unit.player) and unit.player is RoomPlayer and enemy.hp<before:(unit.player as RoomPlayer).equipment_mechanics.on_ally_hit(enemy,unit)
		if kind=="roots" and not enemy.is_queued_for_deletion():enemy.apply_slow(.25 if enemy is BossBase else .5,2.0)
static func draw_marker(unit:HiredAlly)->void:
	unit.draw_set_transform(Vector2(0,14),0,Vector2(1,0.35))
	unit.draw_arc(Vector2.ZERO,16,0,TAU,24,Color(0.68,0.48,1,0.65),1.5)
	unit.draw_set_transform(Vector2.ZERO)
	unit.draw_rect(Rect2(-17,-5,34*clampf(unit.remaining/maxf(1,unit.total_duration),0,1),2),Color("b798e5"))
