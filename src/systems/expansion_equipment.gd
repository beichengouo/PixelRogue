class_name ExpansionEquipment
extends RefCounted
## Extra attacks always use EquipmentMechanics.extra_damage; never enter hit hooks again.
var owner:EquipmentMechanics
var tide_hits:=0
var verse_skills:Dictionary={}
var verse_until:=0.0
var dash_until:=0.0
func has(id:StringName)->bool:return owner.has(id)
func strength(id:StringName)->float:return owner.scale(id)
func basic(enemy:EnemyBase,receipt:BasicAttackReceipt)->void:
	if receipt==null or not receipt.claim_effect(&"expansion_equipment"):return
	if has(&"tide_staff") and owner.actor.shield_hp>0:
		tide_hits+=1
		if tide_hits>=3 and owner.ready(&"tide_staff"):
			tide_hits=0;owner.start(&"tide_staff",2);GameState.add_mp(2);owner.area_damage(enemy.global_position,42,owner.attack()*.2);HolyFX.spawn(owner.actor.get_parent(),enemy.global_position,"ring",42,.3)
	if has(&"shadow_stitch") and owner.ready(&"shadow_stitch"):
		for ally in owner.actor.get_tree().get_nodes_in_group("allies"):
			if owner._live_ally(ally) and ally.global_position.distance_to(enemy.global_position)<=108:
				owner.start(&"shadow_stitch",1.5);owner.extra_damage(enemy,owner.attack()*.18,owner.actor.global_position);WeaponBuildFX.pulse(owner.actor.get_parent(),enemy.global_position,"dusk_lantern","impact",32);break
	if has(&"willow_bow") and owner.actor.velocity.length()>20 and owner.ready(&"willow_bow"):owner.start(&"willow_bow",2);GameState.add_mp(2)
	if has(&"wind_listen") and enemy.global_position.distance_to(owner.actor.global_position)>144 and owner.ready(&"wind_listen"):owner.start(&"wind_listen",1.25);owner.extra_damage(enemy,owner.attack()*.08,owner.actor.global_position)
	if has(&"late_clock") and owner.ready(&"late_clock"):
		var selected:StringName=&"";var longest:=0.0
		for id in GameState.learned_skills:
			var remaining:=float(GameState.skill_cooldowns_by_id.get(id,0))
			if id!=&"" and not Skills.is_ultimate(id) and remaining>longest:selected=id;longest=remaining
		if selected!=&"":GameState.skill_cooldowns_by_id[selected]=maxf(0,longest-.15*strength(&"late_clock"));GameState._sync_skill_cooldowns();owner.start(&"late_clock",1)
	if has(&"half_star") and dash_until>owner.clock:
		dash_until=0;GameState.add_mp(2*strength(&"half_star"));owner.extra_damage(enemy,owner.attack()*.1*strength(&"half_star"),owner.actor.global_position)
	if has(&"broken_verse") and receipt.critical and owner.ready(&"broken_verse"):owner.start(&"broken_verse",5);owner.grant_player_shield(owner.actor.max_hp*.03*strength(&"broken_verse"),2)
func skill(id:StringName)->void:
	if id==&"" or Skills.is_ultimate(id):return
	for key in verse_skills.keys():
		if float(verse_skills[key])<owner.clock-6:verse_skills.erase(key)
	if has(&"leaf_page") and owner.ready(&"leaf_page"):
		verse_skills[str(id)]=owner.clock
		if verse_skills.size()>=3:verse_skills.clear();verse_until=owner.clock+4;owner.start(&"leaf_page",4)
func skill_hit(enemy:EnemyBase)->void:
	if has(&"mist_dew") and owner.actor.hp<owner.actor.max_hp*.5 and owner.ready(&"mist_dew"):
		owner.start(&"mist_dew",3);owner.actor.heal_player(owner.actor.max_hp*.01*strength(&"mist_dew"))
	if has(&"leaf_page") and verse_until>owner.clock:
		verse_until=0;owner.area_damage(enemy.global_position,36,owner.attack()*.18*strength(&"leaf_page"));HolyFX.spawn(owner.actor.get_parent(),enemy.global_position,"ring",36,.3)
func ally_hit(ally:Node2D)->void:
	if has(&"lamp_tassel") and owner.actor.global_position.distance_to(ally.global_position)<=144 and owner.ready(&"lamp_tassel"):owner.start(&"lamp_tassel",1);GameState.add_mp(strength(&"lamp_tassel"))
func dash()->void:
	if has(&"silver_return") and owner.ready(&"silver_return"):owner.start(&"silver_return",5);GameState.add_mp(3)
	if has(&"half_star") and owner.ready(&"half_star"):dash_until=owner.clock+5;owner.start(&"half_star",3)
func shield_broken()->void:
	if has(&"oath_cloak") and owner.ready(&"oath_cloak"):owner.start(&"oath_cloak",5);GameState.add_mp(4)
func snapshot()->Dictionary:
	var recent:Dictionary={}
	for id in verse_skills:recent[id]=maxf(0,6-(owner.clock-float(verse_skills[id])))
	return {"tide_hits":tide_hits,"verse":recent,"verse_left":maxf(0,verse_until-owner.clock),"dash_left":maxf(0,dash_until-owner.clock)}
func restore(data:Dictionary)->void:
	tide_hits=clampi(int(data.get("tide_hits",0)),0,3);verse_until=owner.clock+float(data.get("verse_left",0));dash_until=owner.clock+float(data.get("dash_left",0));verse_skills.clear()
	for id in data.get("verse",{}):verse_skills[id]=owner.clock-6+float(data.verse[id])
