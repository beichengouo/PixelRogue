class_name WayfarerRelics
extends RefCounted
## Additional damage never re-enters primary attack/skill hooks.
var owner:EquipmentMechanics
var pendulum_until:=0.0
var standing:=0.0
var tide_targets:Dictionary={}
var river_targets:Dictionary={}
var root_targets:Dictionary={}
var sun_hits:=0
var sun_until:=0.0
var night_hits:=0
var night_until:=0.0
func has(id:StringName)->bool:return owner.has(id)
func scale(id:StringName)->float:return owner.scale(id)
func refresh()->void:
	if not has(&"amber_pendulum"):pendulum_until=0
	if not has(&"moss_heart"):standing=0
	if not has(&"tide_seals"):tide_targets.clear()
	if not has(&"riverledger"):river_targets.clear()
	if not has(&"rootcrown"):root_targets.clear()
	if not has(&"sunseal"):sun_hits=0;sun_until=0
	if not has(&"nightloom"):night_hits=0;night_until=0
func expire_chains()->void:
	for targets:Dictionary in [river_targets,root_targets]:
		for key in targets.keys():
			if float(targets[key])<=owner.clock:targets.erase(key)
	if sun_until<=owner.clock:sun_hits=0;sun_until=0
	if night_until<=owner.clock:night_hits=0;night_until=0
func tick(delta:float)->void:
	expire_chains()
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
	expire_chains()
	if has(&"spentmatch") and enemy._burn_time>0 and owner.ready(&"spentmatch"):
		owner.start(&"spentmatch",2);owner.extra_damage(enemy,owner.fixed_value(&"spentmatch",&"damage_flat"),owner.actor.global_position)
	if has(&"dryreed") and GameState.mp<GameState.MAX_MP*.5 and owner.ready(&"dryreed"):
		owner.start(&"dryreed",3);GameState.add_mp(scale(&"dryreed"))
	if has(&"amberbeetle") and owner.actor.shield_hp>0 and owner.ready(&"amberbeetle"):
		owner.start(&"amberbeetle",2);enemy.apply_slow(.15*scale(&"amberbeetle"),2)
		owner.extra_damage(enemy,owner.attack()*.18*scale(&"amberbeetle"),owner.actor.global_position)
		pulse(enemy.global_position,26,Color("e8be67"),1)
	if has(&"sunseal") and owner.ready(&"sunseal"):
		sun_hits=mini(3,sun_hits+1);sun_until=owner.clock+10
	if has(&"rootcrown") and owner.ready(&"rootcrown") and (enemy._burn_time>0 or enemy._slow_time>0):
		root_targets[enemy.get_instance_id()]=owner.clock+5
		if root_targets.size()>=3:
			root_targets.clear();owner.start(&"rootcrown",5);GameState.add_mp(6*scale(&"rootcrown"))
			owner.area_damage(enemy.global_position,108,owner.attack()*.75*scale(&"rootcrown"));pulse(enemy.global_position,108,Color("b5d58c"),3)
	if has(&"amber_pendulum") and receipt.critical and owner.ready(&"amber_pendulum"):
		pendulum_until=owner.clock+4;owner.start(&"amber_pendulum",6)
	if has(&"ash_compass") and enemy._burn_time>0 and owner.ready(&"ash_compass"):
		owner.start(&"ash_compass",1.5);enemy.apply_slow(.20*scale(&"ash_compass"),2);owner.extra_damage(enemy,owner.attack()*.14*scale(&"ash_compass"),owner.actor.global_position);CadenceProcFX.spawn(owner.actor.get_parent(),enemy.global_position,26,Color("ef9b6b"),1)
	if has(&"quartz_moth") and GameState.mp<GameState.MAX_MP*.3 and owner.ready(&"quartz_moth"):
		owner.start(&"quartz_moth",2);GameState.add_mp(scale(&"quartz_moth"));owner.extra_damage(enemy,owner.fixed_value(&"quartz_moth",&"damage_flat"),owner.actor.global_position);CadenceProcFX.spawn(owner.actor.get_parent(),enemy.global_position,24,Color("c2a3f0"),1)
func skill(id:StringName)->float:
	if id==&"" or Skills.is_ultimate(id) or not has(&"amber_pendulum") or pendulum_until<=owner.clock:return 0
	owner.consumed_status("amber_pendulum")
	pendulum_until=0;return .16*scale(&"amber_pendulum")
func skill_hit(enemy:EnemyBase)->void:
	expire_chains()
	if has(&"wornbutton") and owner.ready(&"wornbutton"):
		owner.start(&"wornbutton",8);owner.grant_player_shield(owner.fixed_value(&"wornbutton",&"shield_flat"),3)
	if has(&"smoothpebble") and owner.ready(&"smoothpebble"):
		owner.start(&"smoothpebble",4);enemy.apply_slow(.12*scale(&"smoothpebble"),1.5)
	if has(&"riverledger") and owner.ready(&"riverledger"):
		river_targets[enemy.get_instance_id()]=owner.clock+2
		if river_targets.size()>=3:
			river_targets.clear();owner.start(&"riverledger",5);GameState.add_mp(5*scale(&"riverledger"))
			owner.grant_player_shield(owner.actor.max_hp*.05*scale(&"riverledger"),4);pulse(owner.actor.global_position,32,Color("8cd5df"),2)
	if has(&"sunseal") and sun_hits>0 and owner.ready(&"sunseal"):
		var charges:=sun_hits;sun_hits=0;sun_until=0;owner.start(&"sunseal",4);owner.consumed_status("sunseal")
		GameState.add_mp(2*charges*scale(&"sunseal"));owner.area_damage(enemy.global_position,72,owner.attack()*.18*charges*scale(&"sunseal"))
		pulse(enemy.global_position,72,Color("ffe3a2"),3)
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
	if has(&"crackedchime") and owner.ready(&"crackedchime"):
		owner.start(&"crackedchime",6);owner.actor._dash_cd=maxf(0,owner.actor._dash_cd-.2*scale(&"crackedchime"))
	if not has(&"root_talisman") or not owner.ready(&"root_talisman"):return
	owner.start(&"root_talisman",6);owner.actor._dash_cd=maxf(0,owner.actor._dash_cd-.4*scale(&"root_talisman"))
	for enemy in owner.nearest_enemies(owner.actor.global_position,108,3):enemy.apply_slow(.2*scale(&"root_talisman"),2)
	CadenceProcFX.spawn(owner.actor.get_parent(),owner.actor.global_position,108,Color("79b99a"),2)
func enemy_died(enemy:EnemyBase)->void:
	if enemy.training_target or not has(&"empty_lamp_note") or not owner.ready(&"empty_lamp_note"):return
	if enemy.global_position.distance_squared_to(owner.actor.global_position)>144*144:return
	owner.start(&"empty_lamp_note",2);GameState.add_mp(2*scale(&"empty_lamp_note"))
func ally_hit(enemy:EnemyBase,ally:Node2D)->void:
	expire_chains()
	var distance:=ally.global_position.distance_squared_to(owner.actor.global_position)
	if distance<=144*144:
		if has(&"twinebobbin") and owner.ready(&"twinebobbin"):
			owner.start(&"twinebobbin",4);GameState.add_mp(scale(&"twinebobbin"))
		if has(&"pactspindle") and owner.ready(&"pactspindle"):
			owner.start(&"pactspindle",4);GameState.add_mp(2*scale(&"pactspindle"))
			owner.extra_damage(enemy,owner.attack()*.25*scale(&"pactspindle"),ally.global_position);pulse(enemy.global_position,28,Color("b7a4f2"),1)
	if distance>216*216 or not has(&"nightloom") or not owner.ready(&"nightloom") or not owner.ready(&"nightloom_beat"):return
	owner.start(&"nightloom_beat",.2);night_hits+=1;night_until=owner.clock+6
	if night_hits<5:return
	night_hits=0;night_until=0;owner.start(&"nightloom",5);owner.consumed_status("nightloom")
	owner.grant_player_shield(owner.actor.max_hp*.08*scale(&"nightloom"),4)
	for target in owner.nearest_enemies(owner.actor.global_position,216,2):
		owner.extra_damage(target,owner.attack()*.35*scale(&"nightloom"),owner.actor.global_position);pulse(target.global_position,28,Color("aab9ed"),1)
func pulse(at:Vector2,radius:float,color:Color,style:int)->void:
	CadenceProcFX.spawn(owner.actor.get_parent(),at,radius,color,style)
func room_changed()->void:
	standing=0;tide_targets.clear();river_targets.clear();root_targets.clear()
	sun_hits=0;sun_until=0;night_hits=0;night_until=0
func save_targets(targets:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key in targets:
		var left:=float(targets[key])-owner.clock
		if left>0:result[str(key)]=left
	return result
func restore_targets(saved:Dictionary,ids:Dictionary,window:float)->Dictionary:
	var result:Dictionary={}
	for key in saved:
		var left:=clampf(float(saved[key]),0,window)
		if left<=0:continue
		var enemy:EnemyBase=ids.get(str(key)) as EnemyBase
		var mapped:Variant=enemy.get_instance_id() if is_instance_valid(enemy) else str(key) if str(key).begins_with("past_") else "past_"+str(key)
		result[mapped]=owner.clock+left
	return result
func snapshot()->Dictionary:
	expire_chains()
	var targets:Dictionary={}
	for key in tide_targets:targets[str(key)]=maxf(0,float(tide_targets[key])-owner.clock)
	return {"pendulum_left":maxf(0,pendulum_until-owner.clock),"standing":standing,"tide_targets":targets,
		"river_targets":save_targets(river_targets),"root_targets":save_targets(root_targets),
		"sun_hits":sun_hits,"sun_left":maxf(0,sun_until-owner.clock),"night_hits":night_hits,"night_left":maxf(0,night_until-owner.clock)}
func restore(data:Dictionary,ids:Dictionary)->void:
	pendulum_until=owner.clock+clampf(float(data.get("pendulum_left",0)),0,4);standing=clampf(float(data.get("standing",0)),0,1.5);tide_targets.clear()
	for key in data.get("tide_targets",{}):
		var enemy:EnemyBase=ids.get(str(key)) as EnemyBase
		if owner._live_enemy(enemy):tide_targets[enemy.get_instance_id()]=owner.clock+clampf(float(data.tide_targets[key]),0,1)
	river_targets=restore_targets(data.get("river_targets",{}),ids,2);root_targets=restore_targets(data.get("root_targets",{}),ids,5)
	sun_until=owner.clock+clampf(float(data.get("sun_left",0)),0,10);sun_hits=clampi(int(data.get("sun_hits",0)),0,3)
	night_until=owner.clock+clampf(float(data.get("night_left",0)),0,6);night_hits=clampi(int(data.get("night_hits",0)),0,4)
	expire_chains()
	refresh()
