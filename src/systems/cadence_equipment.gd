class_name CadenceEquipment
extends RefCounted
## Item state belongs to the player, not individual rooms. Damage uses the
## equipment context so these procs cannot recursively feed any hit hook.
var owner:EquipmentMechanics
var storm_hits:=0
var storm_until:=0.0
var counter_until:=0.0
var reservoir_charges:=0
var reservoir_until:=0.0
var ally_hits:=0
var ally_until:=0.0
var cadence_stacks:=0
var cadence_kind:=0
var cadence_until:=0.0
var metre_hits:=0
var metre_until:=0.0
var battery_until:=0.0
var sentinel_until:=0.0
var score_hits:=0
var score_until:=0.0

func has(id:StringName)->bool:return owner.has(id)
func scale(id:StringName)->float:return owner.scale(id)
func tick()->void:
	if storm_until<=owner.clock:storm_hits=0
	if reservoir_until<=owner.clock:reservoir_charges=0
	if ally_until<=owner.clock:ally_hits=0
	if cadence_until<=owner.clock:cadence_stacks=0;cadence_kind=0
	if metre_until<=owner.clock:metre_hits=0
	if score_until<=owner.clock:score_hits=0

func refresh()->void:
	# Selling/unequipping removes its pending benefit; cooldowns stay on owner.
	if not has(&"storm_conductor"):storm_hits=0;storm_until=0
	if not has(&"counterbeat"):counter_until=0
	if not has(&"mana_reservoir"):reservoir_charges=0;reservoir_until=0
	if not has(&"orbit_guard"):ally_hits=0;ally_until=0
	if not has(&"cadence_prism"):cadence_stacks=0;cadence_kind=0;cadence_until=0
	if not has(&"copper_metre"):metre_hits=0;metre_until=0
	if not has(&"dew_battery"):battery_until=0
	if not has(&"sentinel_thread"):sentinel_until=0
	if not has(&"wayfarer_score"):score_hits=0;score_until=0

func basic(enemy:EnemyBase,receipt:BasicAttackReceipt)->void:
	if receipt==null or not receipt.claim_effect(&"cadence_equipment"):return
	tick()
	var a:=owner.attack()
	if has(&"storm_conductor") and owner.ready(&"storm_conductor"):
		storm_hits+=1;storm_until=owner.clock+4
		if storm_hits>=4:
			storm_hits=0;storm_until=0;owner.start(&"storm_conductor",1.5)
			owner.area_damage(enemy.global_position,72,a*.55);pulse(enemy.global_position,72,Color("79dfff"),0)
	if has(&"counterbeat") and counter_until>owner.clock:
		owner.consumed_status("counterbeat")
		counter_until=0;owner.extra_damage(enemy,a*.22,owner.actor.global_position);pulse(enemy.global_position,25,Color("ffd383"),1)
	if has(&"mana_reservoir") and reservoir_charges>0 and owner.ready(&"mana_reservoir_hit"):
		owner.consumed_status("mana_reservoir")
		reservoir_charges-=1;owner.start(&"mana_reservoir_hit",.8);GameState.add_mp(2)
		owner.extra_damage(enemy,a*.3,owner.actor.global_position);pulse(enemy.global_position,32,Color("60d4de"),2)
	if has(&"copper_metre") and owner.ready(&"copper_metre"):
		metre_hits+=1;metre_until=owner.clock+4
		if metre_hits>=4:
			metre_hits=0;metre_until=0;owner.start(&"copper_metre",1);GameState.add_mp(2*scale(&"copper_metre"))
			# EnemyBase applies the boss control reduction once.
			enemy.apply_slow(.2*scale(&"copper_metre"),2)
	if has(&"dew_battery") and battery_until>owner.clock:
		owner.consumed_status("dew_battery")
		battery_until=0;GameState.add_mp(3*scale(&"dew_battery"))
	if has(&"sentinel_thread") and sentinel_until>owner.clock:
		owner.consumed_status("sentinel_thread")
		sentinel_until=0;owner.extra_damage(enemy,a*.18*scale(&"sentinel_thread"),owner.actor.global_position)
		var nearest:HiredAlly;var distance:=144.0*144.0
		for ally in owner.get_tree().get_nodes_in_group("allies"):
			if not owner._live_ally(ally):continue
			var candidate:=owner.actor.global_position.distance_squared_to(ally.global_position)
			if candidate<distance:distance=candidate;nearest=ally as HiredAlly
		if nearest!=null:owner.grant_ally_shield(nearest,nearest.max_hp*.08*scale(&"sentinel_thread"),4)
		pulse(enemy.global_position,30,Color("91d9ac"),1)
	advance_cadence(enemy,1)

func skill(id:StringName)->void:
	if id==&"" or Skills.is_ultimate(id):return
	var ratio:=GameState.mp/GameState.MAX_MP
	if has(&"counterbeat"):counter_until=owner.clock+4
	if has(&"mana_reservoir") and ratio>=.5:
		if reservoir_until<=owner.clock:reservoir_charges=0
		reservoir_charges=mini(3,reservoir_charges+1);reservoir_until=owner.clock+8
	if has(&"last_flame") and ratio<.3 and owner.ready(&"last_flame"):
		owner.start(&"last_flame",8);owner.grant_player_shield(owner.actor.max_hp*.08,4)
	if has(&"dew_battery") and ratio>=.5 and owner.ready(&"dew_battery"):
		owner.start(&"dew_battery",3);battery_until=owner.clock+4

func skill_hit(enemy:EnemyBase)->void:
	if has(&"aftertone") and enemy._slow_time>0 and owner.ready(&"aftertone"):
		owner.start(&"aftertone",1.5);owner.extra_damage(enemy,owner.attack()*.14*scale(&"aftertone"),owner.actor.global_position);pulse(enemy.global_position,28,Color("baaaed"),1)
	if has(&"dry_wick") and GameState.mp<GameState.MAX_MP*.3 and owner.ready(&"dry_wick"):
		owner.start(&"dry_wick",3);GameState.add_mp(3*scale(&"dry_wick"))
	advance_cadence(enemy,2)

func advance_cadence(enemy:EnemyBase,kind:int)->void:
	if not has(&"cadence_prism") or not owner.ready(&"cadence_prism"):return
	if cadence_until<=owner.clock:cadence_stacks=0;cadence_kind=0
	if cadence_kind==kind:return
	# First hit sets the instrument; only changes of damage source count.
	if cadence_kind!=0:cadence_stacks+=1
	cadence_kind=kind;cadence_until=owner.clock+4
	if cadence_stacks>=3:
		cadence_stacks=0;cadence_kind=0;cadence_until=0;owner.start(&"cadence_prism",2)
		owner.area_damage(enemy.global_position,72,owner.attack()*.65);pulse(enemy.global_position,72,Color("dfb0ff"),3)

func ally_hit(ally:Node2D)->void:
	if ally.global_position.distance_squared_to(owner.actor.global_position)>144*144:return
	tick()
	# Global receipt gate: an ally's cleave or simultaneous volley earns one beat.
	if not owner.ready(&"cadence_ally_receipt"):return
	owner.start(&"cadence_ally_receipt",.2)
	if has(&"orbit_guard") and owner.ready(&"orbit_guard"):
		ally_hits+=1;ally_until=owner.clock+4
		if ally_hits>=4:
			ally_hits=0;ally_until=0;owner.start(&"orbit_guard",5);owner.grant_player_shield(owner.actor.max_hp*.05,4)
	if has(&"wayfarer_score") and owner.ready(&"wayfarer_score"):
		score_hits+=1;score_until=owner.clock+4
		if score_hits>=4:score_hits=0;score_until=0;owner.start(&"wayfarer_score",2);GameState.add_mp(2*scale(&"wayfarer_score"))

func shield_broken()->void:
	if has(&"sentinel_thread") and owner.ready(&"sentinel_thread"):
		owner.start(&"sentinel_thread",4);sentinel_until=owner.clock+4

func pulse(at:Vector2,radius:float,color:Color,style:int)->void:
	CadenceProcFX.spawn(owner.actor.get_parent(),at,radius,color,style)

func snapshot()->Dictionary:
	tick()
	var data:Dictionary={}
	for key in ["storm_hits","reservoir_charges","ally_hits","cadence_stacks","cadence_kind","metre_hits","score_hits"]:data[key]=get(key)
	for key in ["storm_until","counter_until","reservoir_until","ally_until","cadence_until","metre_until","battery_until","sentinel_until","score_until"]:data[key]=maxf(0,float(get(key))-owner.clock)
	return data
func restore(data:Dictionary)->void:
	for entry in [["storm_hits",3],["reservoir_charges",3],["ally_hits",3],["cadence_stacks",2],["cadence_kind",2],["metre_hits",3],["score_hits",3]]:set(entry[0],clampi(int(data.get(entry[0],0)),0,int(entry[1])))
	for key in ["storm_until","counter_until","reservoir_until","ally_until","cadence_until","metre_until","battery_until","sentinel_until","score_until"]:set(key,owner.clock+clampf(float(data.get(key,0)),0,8))
	refresh()
