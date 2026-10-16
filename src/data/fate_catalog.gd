class_name FateCatalog
extends RefCounted
## Expedition-only cards. Timers are remaining active seconds, never wall time.
const IDS := ["magician","priestess","empress","emperor","chariot","hermit","star","moon"]
const STARS := {
	"torch":{"name":"明炬座","description":"主普攻直接伤害增加8%。"},
	"spring":{"name":"涌泉座","description":"自然MP回复增加12%。"},
	"lantern":{"name":"守灯座","description":"首次进入未清战斗房，获得最大生命6%的护盾，持续6秒；每房一次。"}}
const CARDS := {
	"magician":{"name":"魔术师","upright":"成功施放小技能后，4秒内下一次主普攻首个有效命中追加0.18倍攻击力伤害；冷却3秒。","reverse":"追加伤害提高至0.30倍攻击力；小技能MP消耗增加10%。"},
	"priestess":{"name":"女祭司","upright":"静止0.8秒获得3秒启示，下一次成功施放的小技能直接伤害增加12%；获得启示冷却6秒。持续领域、召唤与持续伤害不受强化。","reverse":"直接伤害加成提高至20%；基础移动速度降低8%。"},
	"empress":{"name":"女皇","upright":"四格内雇佣与召唤友军的直接伤害增加10%。","reverse":"友军加成提高至18%；自身受到的普通生命伤害增加10%，不影响真实伤害与永久生命损失。"},
	"emperor":{"name":"皇帝","upright":"自身护盾因承伤耗尽时释放两格反击波，造成0.35倍攻击力伤害；冷却5秒。","reverse":"反击波提高至0.60倍攻击力；自身获得的护盾量降低20%。"},
	"chariot":{"name":"战车","upright":"基础闪避结束后，3秒内下一次主普攻首个有效命中追加0.18倍攻击力伤害；每次闪避一次。技能闪避不触发。","reverse":"追加伤害提高至0.32倍攻击力；基础闪避冷却增加15%。"},
	"hermit":{"name":"隐者","upright":"四格内没有友军时，自身主普攻与主动技能直接伤害增加10%。","reverse":"直接伤害加成提高至18%；自身获得的护盾量降低15%。"},
	"star":{"name":"星星","upright":"首次进入未清战斗房，回复最大MP的8%；每房一次。","reverse":"回复提高至16%；自然MP回复降低15%。"},
	"moon":{"name":"月亮","upright":"主普攻首个有效命中减速目标时，追加0.12倍攻击力伤害；全局冷却1秒。","reverse":"追加伤害提高至0.22倍攻击力；主普攻直接伤害降低8%。"}}
static func empty()->Dictionary:
	return {"cards":[],"readings":0,"star":"","cooldowns":{},"pending":{},"still":0.0,"cast_factor":1.0}
static func normalize(raw:Variant)->Dictionary:
	var result:=empty()
	if not raw is Dictionary:return result
	result.readings=clampi(int(raw.get("readings",0)),0,3)
	result.star=str(raw.get("star","")) if STARS.has(str(raw.get("star",""))) else ""
	for card in raw.get("cards",[]):
		if not card is Dictionary or not CARDS.has(str(card.get("id",""))):continue
		var id:=str(card.id);var exists:=false
		for owned in result.cards:
			if owned.id==id:exists=true
		if not exists:result.cards.append({"id":id,"reverse":bool(card.get("reverse",false))})
	for key in ["cooldowns","pending"]:
		if raw.get(key) is Dictionary:
			for id in raw[key]:
				var value:Variant=raw[key][id]
				if (value is float or value is int) and is_finite(float(value)) and float(value)>0:result[key][str(id)]=minf(float(value),3600)
	return result
static func active()->bool:return GameState.run_active and not CampSession.active
static func rank(id:String)->int:
	if not active():return 0
	for card in GameState.fate.get("cards",[]):
		if str(card.id)==id:return 2 if bool(card.reverse) else 1
	return 0
static func star()->String:
	var id:=str(GameState.fate.get("star","")) if active() else ""
	return id if STARS.has(id) else ""
static func art(id:String,reverse:=false)->String:return "res://assets/fate_v01/cards/"+id+("_reverse" if reverse and CARDS.has(id) else "")+".png"
static func icon(id:String)->String:return "res://assets/fate_v01/icons/"+id+".png"
static func description(id:String,reverse:=false)->String:
	if not CARDS.has(id):return ""
	var repair:=""
	if id=="star":repair="\n伤痕修复：每间战斗房清理后，修复完整生命上限的%s%%；每房一次。"%("4" if reverse else "2")
	elif id=="empress":repair="\n伤痕修复：四格内友军累计12次有效直击，修复完整生命上限的%s%%；冷却8秒，每房至多3次。"%("2" if reverse else "1")
	if not repair.is_empty():repair+="只返还实际修复的上限与等量生命，不补满生命；浴血中也生效。"
	return str(CARDS[id].upright)+( "\n逆位代价与变化："+str(CARDS[id].reverse) if reverse else "")+repair+"\n命运附加伤害不暴击、不吸血，不触发其他装备或命运牌。"
static func apply_stats(block:StatBlock)->void:
	if rank("priestess")==2:block.add_flat(&"move_speed",-float(GameState.BASE_STATS.move_speed)*.08)
	if rank("chariot")==2:block.add_mult(&"dash_cooldown",.15)
static func regen_factor()->float:return 1.0+(.12 if star()=="spring" else 0.0)-(.15 if rank("star")==2 else 0.0)
static func shield_factor()->float:return (0.8 if rank("emperor")==2 else 1.0)*(0.85 if rank("hermit")==2 else 1.0)
static func allies_near(actor:Node2D)->bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree():return false
	for unit in actor.get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(unit) and unit is Node2D and not unit.is_queued_for_deletion() and unit.global_position.distance_squared_to(actor.global_position)<=20736 and (not "hp" in unit or float(unit.hp)>0):return true
	return false
static func direct_factor(kind:StringName,source:Node)->float:
	if not active():return 1.0
	var factor:=1.0
	if source is DamageContext and source.owner_kind==&"skill_field":return 1.0
	if kind==&"ally" and source is DamageContext:source=source.get_parent()
	if kind==&"basic":
		if star()=="torch":factor+=.08
		if rank("moon")==2:factor-=.08
	if kind in [&"basic",&"skill"] and rank("hermit")>0 and not allies_near(GameState.player):factor+=.10 if rank("hermit")==1 else .18
	if kind==&"ally" and rank("empress")>0 and is_instance_valid(source) and source is HiredAlly and is_instance_valid(GameState.player) and source.global_position.distance_squared_to(GameState.player.global_position)<=20736:factor+=.10 if rank("empress")==1 else .18
	return factor
