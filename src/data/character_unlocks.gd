class_name CharacterUnlocks
extends RefCounted
## Unlocks are derived from committed contracts and character achievements.
const COMMISSIONS:={"sylphiette":"camp_herbalist_travel","xixifu":"camp_minstrel_strap","ilyua":"camp_surveyor_rain"}
const SKILLS:={"sylphiette":["flame_shield","frost_nova","healing_light","starfall"],"xixifu":["night_shelter","gatekeeper","shadow_step","spirit_parade"],"ilyua":["ilyua_hunter_mark","ilyua_vine_trap","ilyua_moon_arrows","ilyua_ancient_tree"]}
const NAMES:={"sylphiette":"希露媞雅","xixifu":"希希芙","ilyua":"伊露雅"}
static func achievement_id(character:String,tier:String)->String:return "hero_mastery_"+character+"_"+tier
static func achievement_entries()->Dictionary:
	var result:Dictionary={}
	for character in NAMES:
		for tier in ["opening","middle","final"]:
			var difficulty:=2 if tier=="final" else 1
			var title:String={"opening":"破阵之证","middle":"进阶之证","final":"危境之誓"}[tier]
			var boss:String={"opening":"林之骸王或塞芙菈","middle":"晶化巨影或维蕾娜","final":"潮汐之根或无名录仪"}[tier]
			result[achievement_id(character,tier)]={"name":str(NAMES[character])+"·"+str(title),"description":"使用%s，在%s及以上难度击败%s，解锁该角色的进阶能力。"%[NAMES[character],"危险" if difficulty==2 else "普通",boss],"metric":"hero_mastery:"+character+":"+tier,"goal":difficulty,"category":"挑战","icon":"three_bosses" if tier=="final" else "first_boss"}
	return result
static func achieved(character:String,tier:String)->bool:return SaveService.data.get("achievements",{}).has(achievement_id(character,tier))
static func skill_available(id:StringName,character:StringName=&"")->bool:
	var owner:=Characters.current_id() if character==&"" else character;var index:int=SKILLS.get(str(owner),[]).find(str(id))
	if index<0:return Skills.order_for(owner).has(id)
	if index==0:return str(COMMISSIONS[str(owner)]) in Outpost.data.get("contracts",[])
	return achieved(str(owner),["","opening","middle","final"][index])
static func skill_condition(id:StringName,character:StringName=&"")->String:
	var owner:=Characters.current_id() if character==&"" else character;var index:int=SKILLS.get(str(owner),[]).find(str(id))
	if index<0:return "初始技能"
	if index==0:
		for contract:Dictionary in ExpeditionData.CONTRACTS:
			if str(contract.id)==str(COMMISSIONS[str(owner)]):return "完成委托「%s」"%str(contract.title)
	var boss:String=["","林之骸王或塞芙菈","晶化巨影或维蕾娜","潮汐之根或无名录仪"][index]
	return "使用%s，在%s及以上击败%s，完成对应角色成就。"%[NAMES[str(owner)],"危险" if index==3 else "普通",boss]
static func passive_available(id:StringName,character:StringName)->bool:
	if id==PassiveDefinitions.default_for(character):return true
	return achieved(str(character),"final" if id==&"xixifu_wisps" else "middle")
static func passive_condition(id:StringName,character:StringName)->String:
	if id==PassiveDefinitions.default_for(character):return "初始被动"
	return skill_condition(StringName(SKILLS[str(character)][3 if id==&"xixifu_wisps" else 2]),character)
static func available_skills(character:StringName=&"")->Array[StringName]:
	var result:Array[StringName]=[]
	for id:StringName in Skills.order_for(character):
		if skill_available(id,character):result.append(id)
	return result
static func valid_loadout(value:Variant,character:StringName=&"")->bool:
	if not Skills.valid_loadout(value,character):return false
	for id in value:
		if not skill_available(StringName(id),character):return false
	return true
