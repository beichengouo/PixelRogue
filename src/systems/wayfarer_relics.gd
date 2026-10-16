class_name WayfarerRelics
extends RefCounted
## Additional damage never re-enters primary attack/skill hooks.
var owner:EquipmentMechanics
var pendulum_until:=0.0
var standing:=0.0
var tide_targets:Dictionary={}
func has(id:StringName)->bool:return owner.has(id)
func scale(id:StringName)->float:return owner.scale(id)
func refresh()->void:
	if not has(&"amber_pendulum"):pendulum_until=0
	if not has(&"moss_heart"):standing=0
	if not has(&"tide_seals"):tide_targets.clear()
func tick(delta:float)->void:
	for key in tide_targets.keys():
		if float(tide_targets[key])<=owner.clock:tide_targets.erase(key)
	if not has(&"moss_heart"):return
	if owner.actor.velocity.length_squared()>64:standing=0;return
	standing=minf(1.5,standing+delta)
	if standing>=1.5 and owner.ready(&"moss_heart") and owner.ready(&"moss_probe"):
		owner.start(&"moss_probe",.25)
		if not owner.nearest_enemies(owner.actor.global_position,360,1).is_empty():
			standing=0;owner.start(&"moss_heart",8);owner.grant_player_shield(owner.actor.max_hp*.04*scale(&"moss_heart"),3);CadenceProcFX.spawn(owner.actor.get_parent(),owner.actor.global_position,30,Color("a4d2a1"),2)
func basic(enemy:EnemyBase,receipt:BasicAttackReceipt)->void:
	if receipt==null or not receipt.claim_effect(&"wayfarer_relics"):return
	if has(&"amber_pendulum") and receipt.critical and owner.ready(&"amber_pendulum"):
		pendulum_until=owner.clock+4;owner.start(&"amber_pendulum",6)
	if has(&"ash_compass") and enemy._burn_time>0 and owner.ready(&"ash_compass"):
		owner.start(&"ash_compass",1.5);enemy.apply_slow(.20*scale(&"ash_compass"),2);owner.extra_damage(enemy,owner.attack()*.14*scale(&"ash_compass"),owner.actor.global_position);CadenceProcFX.spawn(owner.actor.get_parent(),enemy.global_position,26,Color("ef9b6b"),1)
	if has(&"quartz_moth") and GameState.mp<GameState.MAX_MP*.3 and owner.ready(&"quartz_moth"):
		owner.start(&"quartz_moth",2);GameState.add_mp(scale(&"quartz_moth"));owner.extra_damage(enemy,owner.attack()*.20*scale(&"quartz_moth"),owner.actor.global_position);CadenceProcFX.spawn(owner.actor.get_parent(),enemy.global_position,24,Color("c2a3f0"),1)
func skill(id:StringName)->float:
	if id==&"" or Skills.is_ultimate(id) or not has(&"amber_pendulum") or pendulum_until<=owner.clock:return 0
	owner.consumed_status("amber_pendulum")
	pendulum_until=0;return .16*scale(&"amber_pendulum")
func skill_hit(enemy:EnemyBase)->void:
	if has(&"frost_petal") and enemy._slow_time>0 and owner.ready(&"frost_petal"):
		var targets:=owner.nearest_enemies(enemy.global_position,108,2,enemy)
		if not targets.is_empty():
			owner.start(&"frost_petal",3)
			for target in targets:target.apply_slow(.25*scale(&"frost_petal"),2);CadenceProcFX.spawn(owner.actor.get_parent(),target.global_position,24,Color("9ddbf2"),1)
	if has(&"tide_seals") and owner.ready(&"tide_seals"):
		tide_targets[enemy.get_instance_id()]=owner.clock+1
		if tide_targets.size()>=2:
			tide_targets.clear();owner.start(&"tide_seals",3);owner.grant_player_shield(owner.actor.max_hp*.04*scale(&"tide_seals"),3)
func shield_broken()->void:
	if not has(&"root_talisman") or not owner.ready(&"root_talisman"):return
	owner.start(&"root_talisman",6);owner.actor._dash_cd=maxf(0,owner.actor._dash_cd-.4*scale(&"root_talisman"))
	for enemy in owner.nearest_enemies(owner.actor.global_position,108,3):enemy.apply_slow(.2*scale(&"root_talisman"),2)
	CadenceProcFX.spawn(owner.actor.get_parent(),owner.actor.global_position,108,Color("79b99a"),2)
func enemy_died(enemy:EnemyBase)->void:
	if enemy.training_target or not has(&"empty_lamp_note") or not owner.ready(&"empty_lamp_note"):return
	if enemy.global_position.distance_squared_to(owner.actor.global_position)>144*144:return
	owner.start(&"empty_lamp_note",2);GameState.add_mp(2*scale(&"empty_lamp_note"))
func room_changed()->void:standing=0;tide_targets.clear()
func snapshot()->Dictionary:
	var targets:Dictionary={}
	for key in tide_targets:targets[str(key)]=maxf(0,float(tide_targets[key])-owner.clock)
	return {"pendulum_left":maxf(0,pendulum_until-owner.clock),"standing":standing,"tide_targets":targets}
func restore(data:Dictionary,ids:Dictionary)->void:
	pendulum_until=owner.clock+clampf(float(data.get("pendulum_left",0)),0,4);standing=clampf(float(data.get("standing",0)),0,1.5);tide_targets.clear()
	for key in data.get("tide_targets",{}):
		var enemy:EnemyBase=ids.get(str(key)) as EnemyBase
		if owner._live_enemy(enemy):tide_targets[enemy.get_instance_id()]=owner.clock+clampf(float(data.tide_targets[key]),0,1)
	refresh()
