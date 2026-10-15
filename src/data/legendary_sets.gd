class_name LegendarySets
extends RefCounted
const ROOT:="res://assets/legendary_sets_v01/"
const DATA:={
&"sylphiette":{"name":"永昼云冕","weapon":"staff_cloud_radiance","armor":"armor_cloud_rites","accessory":"accessory_eternal_ring","effect":"攻击+20%、攻击速度+12%、魔法回复+25%。消耗祈光强化小技能后，回复10MP并唤出三枚云冕灵珠，自动追击造成0.35倍攻击；本次圣辉额外给予10%生命护盾4秒，冷却6秒。"},
&"xixifu":{"name":"同归夜行","weapon":"staff_dusk_lantern","armor":"armor_dusk_mantle","accessory":"accessory_companion_bells","effect":"攻击+20%、攻击速度+12%、魔法回复+25%。小技能给予友军8%生命护盾及20%攻速4秒。友军直击额外造成角色攻击25%的影灯伤害，冷却1秒；三次影灯命中引发72范围、0.6倍攻击交响，冷却4秒。"},
&"ilyua":{"name":"月叶猎誓","weapon":"bow_spring_wind","armor":"armor_lakeleaf_hunt","accessory":"accessory_moonwind_chime","effect":"攻击+20%、攻击速度+12%、魔法回复+25%。闪避后5秒内四次主普攻有效命中追加0.3倍攻击风刃，并追击一名邻敌0.2倍攻击；完成四次后回复6MP并返还0.5秒闪避冷却。"}}
static func count(equipment:Dictionary={}) -> int:
	var slots:=GameState.equipment if equipment.is_empty() else equipment
	var set:Dictionary=DATA.get(Characters.current_id(),{});var result:=0
	for slot in ["weapon","armor","accessory"]:
		if str(slots.get(StringName(slot),slots.get(slot,{})).get("id",""))==str(set.get(slot,"missing")):result+=1
	return result
static func complete()->bool:return count()==3
static func apply_to(stats:StatBlock,equipment:Dictionary={})->void:
	if count(equipment)!=3:return
	stats.add_mult(&"attack",.20);stats.add_mult(&"attack_speed",.12);stats.add_mult(&"mp_regen",.25)
static func observe()->void:
	var id:=Characters.current_id();var set:Dictionary=DATA.get(id,{})
	if set.is_empty():return
	var record:Dictionary=GameState.legendary_looks.get(str(id),{})
	if str(GameState.equipped(&"weapon").get("id",""))==str(set.weapon) and not bool(record.get("weapon",false)):record.weapon=true;record.selected="weapon"
	if complete() and not bool(record.get("set",false)):record.set=true;record.weapon=true;record.selected="set"
	GameState.legendary_looks[str(id)]=record
	AchievementTracker.set_equipped()
static func form_unlocked(id:StringName=&"")->bool:
	return bool(GameState.legendary_looks.get(str(Characters.current_id() if id==&"" else id),{}).get("set",false))
static func portraits()->Array[String]:
	var result:Array[String]=[]
	for path in Characters.current().get("portraits",{}).values():
		if str(path) not in result:result.append(str(path))
	if result.is_empty():result.append(Characters.portrait_path())
	var record:Dictionary=GameState.legendary_looks.get(str(Characters.current_id()),{})
	for kind in ["weapon","set"]:
		if bool(record.get(kind,false)):result.append(ROOT+str(Characters.current_id())+"/portrait_"+kind+".png")
	return result
static func portrait()->String:
	var record:Dictionary=GameState.legendary_looks.get(str(Characters.current_id()),{})
	var selected:=str(record.get("selected",""));var options:=portraits()
	var path:=ROOT+str(Characters.current_id())+"/portrait_"+selected+".png" if selected in ["weapon","set"] else selected
	return path if path in options else options[0]
static func next_portrait()->String:
	var options:=portraits();var path:=options[(options.find(portrait())+1)%options.size()]
	var record:Dictionary=GameState.legendary_looks.get(str(Characters.current_id()),{});record.selected=path;GameState.legendary_looks[str(Characters.current_id())]=record
	Outpost.request_checkpoint();return path
static func description(item:Dictionary)->String:
	var set:Dictionary=DATA.get(Characters.current_id(),{})
	if str(item.get("id","")) not in [str(set.get("weapon","")),str(set.get("armor","")),str(set.get("accessory",""))]:return ""
	return "%s · 已装备%d／3件\n套装效果：%s"%[str(set.name),count(),str(set.effect)]
