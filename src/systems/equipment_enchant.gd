class_name EquipmentEnchant
extends RefCounted
var owner:EquipmentMechanics
var _accessory_mark:=""
func current(slot:StringName)->String:
	var row:=MaterialWorkshopCatalog.enchant(GameState.equipped(slot))
	return str(GameState.equipped(slot).get("enchant","")) if not row.is_empty() else ""
func refresh()->void:
	var item:=GameState.equipped(&"accessory");var mark:=str(item.get("uid",""))+":"+str(item.get("enchant",""))
	if mark!=_accessory_mark:owner.cooldowns.erase(&"material_accessory_pending")
	_accessory_mark=mark
func basic(enemy:EnemyBase,receipt:BasicAttackReceipt)->void:
	if receipt==null or not is_instance_valid(enemy) or not receipt.claim_effect(&"material_first_hit"):return
	var weapon:=current(&"weapon")
	if weapon=="ember" and owner._live_enemy(enemy):
		var time_before:=enemy._burn_time;var dps_before:=enemy._burn_dps
		enemy.apply_burn(owner.attack()*.08,3,DamageContext.dot(owner.actor))
		if enemy._burn_time>time_before or enemy._burn_dps>dps_before:RunBuildMetrics.trigger("etch:ember")
	if weapon=="crystal" and owner._live_enemy(enemy) and owner.ready(&"material_crystal"):
		owner.start(&"material_crystal",1);owner.extra_damage(enemy,owner.attack()*.16,owner.actor.global_position);Effects.hit_spark(owner.actor.get_parent(),enemy.global_position,Color("b7a8ff"),4)
		RunBuildMetrics.trigger("etch:crystal")
	var accessory:=current(&"accessory")
	if accessory in ["tide","memory"] and not owner.ready(&"material_accessory_pending") and receipt.claim_effect(&"material_tide"):
		RunBuildMetrics.trigger("etch:"+accessory,GameState.mp<GameState.MAX_MP)
		owner.cooldowns.erase(&"material_accessory_pending");GameState.add_mp(4 if accessory=="memory" else 2);Effects.cast_ring(owner.actor.get_parent(),owner.actor.global_position,Color("76d9ef"),18,.22)
func skill(id:StringName)->void:
	if Skills.is_ultimate(id) or current(&"accessory") not in ["tide","memory"] or not owner.ready(&"material_accessory_cd"):return
	owner.start(&"material_accessory_pending",4);owner.start(&"material_accessory_cd",6 if current(&"accessory")=="memory" else 4)
func hurt()->void:
	var armor:=current(&"armor")
	if armor not in ["moss","bone","gate"] or not owner.ready(&"material_armor"):return
	var hp_before:=owner.actor.shield_hp;var time_before:=owner.actor._shield_time;var other_effect:=false
	owner.start(&"material_armor",8)
	owner.grant_player_shield(owner.actor.max_hp*({"moss":.05,"bone":.07,"gate":.06}[armor]),4 if armor=="gate" else 3)
	Effects.cast_ring(owner.actor.get_parent(),owner.actor.global_position,Color("98d6ab"),24,.3)
	if armor=="bone":
		var nearest:Node2D;var best:=144.0*144.0
		for ally in owner.actor.room.tactics.allies(owner.actor.room):
			if not owner._live_ally(ally):continue
			var distance:=owner.actor.global_position.distance_squared_to(ally.global_position)
			if distance<best and owner.actor.room.sight(owner.actor.global_position,ally.global_position):nearest=ally;best=distance
		if nearest!=null:
			other_effect=nearest.max_hp*.04>=nearest.shield_hp
			owner.grant_ally_shield(nearest,nearest.max_hp*.04,3)
	elif armor=="gate":
		for enemy in owner.nearest_enemies(owner.actor.global_position,72,100):enemy.apply_slow(.2,2);other_effect=true
	if other_effect or owner.actor.shield_hp>hp_before or owner.actor._shield_time>time_before:RunBuildMetrics.trigger("etch:"+armor)
