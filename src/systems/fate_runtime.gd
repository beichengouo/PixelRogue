class_name FateRuntime
extends RefCounted
var owner:EquipmentMechanics
func tick(delta:float)->void:
	if not FateCatalog.active():return
	for category in ["cooldowns","pending"]:
		for key in GameState.fate[category].keys():
			GameState.fate[category][key]=maxf(0.0,float(GameState.fate[category][key])-delta)
			if GameState.fate[category][key]<=0:GameState.fate[category].erase(key)
	if FateCatalog.rank("priestess")>0:
		GameState.fate.still=float(GameState.fate.get("still",0))+delta if owner.actor.velocity.length_squared()<1 else 0.0
		if float(GameState.fate.still)>=.8 and ready("priestess"):
			GameState.fate.pending.priestess=3.0;GameState.fate.cooldowns.priestess=6.0
static func cast(id:StringName)->void:
	GameState.fate.cast_factor=1.0
	if not FateCatalog.active() or Skills.is_ultimate(id):return
	if FateCatalog.rank("priestess")>0 and float(GameState.fate.pending.get("priestess",0))>0:
		GameState.fate.cast_factor=1.12 if FateCatalog.rank("priestess")==1 else 1.20
		GameState.fate.pending.erase("priestess")
	if FateCatalog.rank("magician")>0 and float(GameState.fate.cooldowns.get("magician",0))<=0:
		GameState.fate.pending.magician=4.0;GameState.fate.cooldowns.magician=3.0
static func cast_factor()->float:return float(GameState.fate.get("cast_factor",1.0)) if FateCatalog.active() else 1.0
func ready(id:String)->bool:return float(GameState.fate.get("cooldowns",{}).get(id,0))<=0
func basic_hit(enemy:EnemyBase,receipt:BasicAttackReceipt)->void:
	if not FateCatalog.active() or receipt==null or not receipt.claim_effect(&"fate_first"):return
	var ratio:=0.0
	for entry in [["magician",.18,.30],["chariot",.18,.32]]:
		var id:=str(entry[0]);var rank:=FateCatalog.rank(id)
		if rank>0 and float(GameState.fate.pending.get(id,0))>0:
			ratio+=float(entry[rank]);GameState.fate.pending.erase(id)
	var moon:=FateCatalog.rank("moon")
	if moon>0 and is_instance_valid(enemy) and enemy._slow_time>0 and enemy._slow_strength>0 and ready("moon"):
		ratio+=.12 if moon==1 else .22;GameState.fate.cooldowns.moon=1.0
	if ratio>0:damage(enemy,ratio)
func dash_end()->void:
	if FateCatalog.rank("chariot")>0:GameState.fate.pending.chariot=3.0
func shield_broken()->void:
	var rank:=FateCatalog.rank("emperor")
	if rank<=0 or not ready("emperor"):return
	GameState.fate.cooldowns.emperor=5.0
	Effects.slash_arc(owner.actor.get_parent(),owner.actor.global_position,0,72,Color("c7e7ff"),360,3,.3)
	for enemy in owner.actor.get_tree().get_nodes_in_group("enemies"):
		if enemy is EnemyBase and not enemy._dead and enemy.global_position.distance_squared_to(owner.actor.global_position)<=5184 and owner.actor.room.sight(owner.actor.global_position,enemy.global_position):damage(enemy,.35 if rank==1 else .60)
func damage(enemy:EnemyBase,ratio:float)->void:
	if not is_instance_valid(enemy) or enemy._dead:return
	enemy.take_damage(owner.actor.stats.get_value(&"attack")*ratio,false,owner.actor.global_position,DamageContext._context(owner.actor,&"fate"),false)
func room_enter(room_id:String)->void:
	if not FateCatalog.active():return
	var room:=FateService.record()
	if room.is_empty() or str(room.get("id",""))!=room_id or bool(room.get("cleared",true)) or not RoomGraph.is_combat(str(room.get("kind",""))):return
	if bool(room.delta.get("fate_entry",false)):return
	room.delta.fate_entry=true
	var rank:=FateCatalog.rank("star")
	if rank>0:
		GameState.mp=minf(GameState.MAX_MP,GameState.mp+GameState.MAX_MP*(.08 if rank==1 else .16));EventBus.mp_changed.emit(GameState.mp,GameState.MAX_MP)
	if FateCatalog.star()=="lantern":owner.grant_player_shield(owner.actor.max_hp*.06,6)
