class_name LegendaryMechanics
extends RefCounted
var owner:EquipmentMechanics
var cloud_charges:=0
var cloud_until:=0.0
var moon_until:=0.0
var moon_hits:=0
var dusk_hits:=0
var halo_orbs:=0
var halo_until:=0.0
var spring_charges:=0
var spring_until:=0.0
var spring_echoes:=0
var spring_echo_until:=0.0
func has(id:StringName)->bool:return owner.has(id)
func tick()->void:
	if owner.clock>=cloud_until:cloud_charges=0
	if owner.clock>=spring_until:spring_charges=0
	if owner.clock>=spring_echo_until:spring_echoes=0
	if halo_orbs>0 and halo_until>owner.clock and owner.ready(&"cloud_orb"):
		var targets:=owner.nearest_enemies(owner.actor.global_position,300,1)
		if not targets.is_empty():
			halo_orbs-=1;owner.start(&"cloud_orb",.65);owner.extra_damage(targets[0],owner.attack()*.35,owner.actor.global_position);HolyFX.spawn(owner.actor.get_parent(),targets[0].global_position,"cloud",32,.3)
func basic_hit(enemy:EnemyBase,receipt:BasicAttackReceipt)->void:
	if receipt==null or not receipt.claim_effect(&"legendary_identity"):return
	if has(&"spring_wind_bow"):
		spring_charges=mini(4,spring_charges+1);spring_until=owner.clock+6
		if spring_echoes>0 and spring_echo_until>owner.clock:
			spring_echoes-=1;owner.extra_damage(enemy,owner.attack()*.18,owner.actor.global_position)
			for other in owner.nearest_enemies(enemy.global_position,108,1,enemy):owner.extra_damage(other,owner.attack()*.12,enemy.global_position)
			if spring_echoes==0:GameState.add_mp(3)
	if has(&"cloud_staff"):cloud_charges=mini(3,cloud_charges+1);cloud_until=owner.clock+6
	if has(&"eternal_circlet") and receipt.critical and owner.ready(&"eternal_circlet"):owner.start(&"eternal_circlet",1.5);GameState.add_mp(2)
	if has(&"covenant_bells") and owner.ready(&"covenant_bells"):
		owner.start(&"covenant_bells",3)
		for ally in owner.actor.get_tree().get_nodes_in_group("allies"):
			if owner._live_ally(ally):ally.equipment_haste=maxf(ally.equipment_haste,.12);ally.equipment_haste_time=maxf(ally.equipment_haste_time,3)
	if has(&"moonwind_chime") and receipt.critical and owner.ready(&"moonwind_chime"):owner.start(&"moonwind_chime",1);owner.actor._dash_cd*=.85
	if Characters.current_id()==&"ilyua" and LegendarySets.complete() and moon_until>owner.clock and moon_hits>0:
		moon_hits-=1;owner.extra_damage(enemy,owner.attack()*.3,owner.actor.global_position)
		for target in owner.nearest_enemies(enemy.global_position,144,1,enemy):owner.extra_damage(target,owner.attack()*.2,enemy.global_position);HolyFX.spawn(owner.actor.get_parent(),target.global_position,"feather",20,.25)
		if moon_hits==0:GameState.add_mp(6);owner.actor._dash_cd=maxf(0,owner.actor._dash_cd-.5)
func skill_cast(id:StringName)->float:
	var bonus:=1.0
	if has(&"cloud_staff") and cloud_charges>=3 and not Skills.is_ultimate(id) and owner.ready(&"cloud_staff"):
		cloud_charges=0;owner.start(&"cloud_staff",3);bonus+=.2;owner.area_damage(owner.actor.global_position,108,owner.attack()*.75);owner.grant_player_shield(owner.actor.max_hp*.08,4);HolyFX.spawn(owner.actor.get_parent(),owner.actor.global_position,"cloud",108,.4)
	if Characters.current_id()==&"xixifu" and LegendarySets.complete() and not Skills.is_ultimate(id):
		for ally in owner.actor.get_tree().get_nodes_in_group("allies"):
			if owner._live_ally(ally):owner.grant_ally_shield(ally,ally.max_hp*.08,4);ally.equipment_haste=maxf(ally.equipment_haste,.20);ally.equipment_haste_time=maxf(ally.equipment_haste_time,4)
	return bonus
func holy_empowered()->void:
	if Characters.current_id()!=&"sylphiette" or not LegendarySets.complete() or not owner.ready(&"cloud_set"):return
	owner.start(&"cloud_set",6);GameState.add_mp(10);owner.grant_player_shield(owner.actor.max_hp*.10,4);halo_orbs=3;halo_until=owner.clock+6
func dash_end()->void:
	if Characters.current_id()==&"ilyua" and LegendarySets.complete():moon_until=owner.clock+5;moon_hits=4
	if has(&"spring_wind_bow") and spring_charges>=4 and spring_until>owner.clock and owner.ready(&"spring_cycle"):
		spring_charges=0;owner.start(&"spring_cycle",5);spring_echoes=3;spring_echo_until=owner.clock+4;owner.area_damage(owner.actor.global_position,72,owner.attack()*.4);IlyuaFX.spawn(owner.actor.get_parent(),owner.actor.global_position,"wind_burst",144,.4)
func ally_hit(enemy:EnemyBase)->void:
	if Characters.current_id()!=&"xixifu" or not LegendarySets.complete() or not owner.ready(&"dusk_set_hit"):return
	owner.start(&"dusk_set_hit",1);owner.extra_damage(enemy,owner.attack()*.25,owner.actor.global_position);dusk_hits+=1
	if dusk_hits%3==0 and owner.ready(&"dusk_set_burst"):owner.start(&"dusk_set_burst",4);owner.area_damage(enemy.global_position,72,owner.attack()*.6);WeaponBuildFX.pulse(owner.actor.get_parent(),enemy.global_position,"dusk_lantern","proc",144)
func shield_absorbed()->void:
	if has(&"cloud_vestment") and owner.ready(&"cloud_vestment"):owner.start(&"cloud_vestment",3);GameState.add_mp(2)
func contract_killed(unit:SummonedAlly,source:Node)->void:
	if not has(&"dusk_mantle") or not owner.ready(&"dusk_mantle") or unit.remaining<=0:return
	var hostile:bool=is_instance_valid(source) and (source is EnemyBase or source is AffixHazard or source is Projectile and not source.is_friendly)
	if hostile:owner.start(&"dusk_mantle",4);owner.grant_player_shield(owner.actor.max_hp*.08,4)
func snapshot()->Dictionary:return {"spring_charges":spring_charges,"spring_left":maxf(0,spring_until-owner.clock),"spring_echoes":spring_echoes,"spring_echo_left":maxf(0,spring_echo_until-owner.clock),"cloud_charges":cloud_charges,"cloud_until":maxf(0,cloud_until-owner.clock),"moon_until":maxf(0,moon_until-owner.clock),"moon_hits":moon_hits,"dusk_hits":dusk_hits,"halo_orbs":halo_orbs,"halo_until":maxf(0,halo_until-owner.clock)}
func restore(data:Dictionary)->void:
	spring_charges=clampi(int(data.get("spring_charges",0)),0,4);spring_until=owner.clock+float(data.get("spring_left",0));spring_echoes=clampi(int(data.get("spring_echoes",0)),0,3);spring_echo_until=owner.clock+float(data.get("spring_echo_left",0))
	cloud_charges=clampi(int(data.get("cloud_charges",0)),0,3);cloud_until=owner.clock+float(data.get("cloud_until",0));moon_until=owner.clock+float(data.get("moon_until",0));moon_hits=clampi(int(data.get("moon_hits",0)),0,4);dusk_hits=maxi(0,int(data.get("dusk_hits",0)));halo_orbs=clampi(int(data.get("halo_orbs",0)),0,3);halo_until=owner.clock+float(data.get("halo_until",0))
