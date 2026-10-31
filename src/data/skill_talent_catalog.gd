class_name SkillTalentCatalog
extends RefCounted
## Each route has three separately purchased nodes. Only equipped skills activate effects.
const VERSION := 3
const ROUTES := [&"power", &"shape", &"link"]
const ROUTE_NAMES := ["本体强化", "机制变化", "战斗联动"]
const ROMAN := ["Ⅰ", "Ⅱ", "Ⅲ"]
# Skill route definitions are loaded from data/permanent_talents.json.
static var _catalogs: Dictionary = {}
static var _legacy_owners: Dictionary = {}

static func definition(skill:StringName)->Array:
	var value:Variant=PermanentTalents.skill(skill).get("routes",[])
	return value if value is Array and value.size()==5 else []

static func capstone_icon(skill:StringName)->String:
	return "res://assets/talents_v39/icons/%s.png"%skill

static func legacy(character: StringName = &"") -> Dictionary:
	var hero := Characters.current_id() if character == &"" else character
	if hero == &"xixifu": return SummonerTalents.DATA
	if hero == &"ilyua": return IlyuaTalents.DATA
	return HolyTalents.DATA

static func route_id(skill: StringName, route: StringName) -> StringName:
	return StringName("skill_tree_%s_%s" % [skill, route])

static func data(character: StringName = &"") -> Dictionary:
	var hero := Characters.current_id() if character == &"" else character
	if _catalogs.has(hero): return _catalogs[hero]
	var result: Dictionary = {}
	var old := legacy(hero)
	for skill: StringName in Skills.order_for(hero):
		var definition: Array = definition(skill)
		var skill_info: Dictionary = Skills.get_skill(skill)
		for lane in 3:
			var route: StringName = ROUTES[lane]
			var id := route_id(skill, route)
			var name := str(definition[lane]) if lane < 2 else str(old[definition[4][0]].name)
			var icon := capstone_icon(skill) if lane < 2 else str(old[definition[4][0]].icon)
			var descriptions: PackedStringArray = []
			for rank in range(1, 4): descriptions.append(description(skill, route, rank, hero))
			result[id] = {"name":name, "max_rank":3, "desc":"\n".join(descriptions),
				"descriptions":descriptions, "branch":skill, "branch_name":str(skill_info.name),
				"skill":skill, "route":route, "route_name":ROUTE_NAMES[lane],
				"tier":lane+1, "icon":icon, "requires":{}}
		var terminal:=PermanentTalents.terminal_id(skill)
		result[terminal]={"name":str(skill_info.name)+"·终点", "max_rank":1,
			"desc":str(PermanentTalents.skill(skill).get("capstone","")),"descriptions":PackedStringArray([str(PermanentTalents.skill(skill).get("capstone",""))]),
			"branch":skill,"branch_name":str(skill_info.name),"skill":skill,"route":&"terminal","route_name":"满树强化",
			"tier":2,"icon":capstone_icon(skill),"requires":{},"terminal":true}
	_catalogs[hero] = result
	return result

static func description(skill: StringName, route: StringName, rank: int, character: StringName) -> String:
	var name := str(Skills.get_skill(skill).name)
	if route == &"power":
		var subject := "技能主要伤害"
		if skill in [&"shadow_companions", &"ghost_lantern", &"forest_guardian", &"gatekeeper"]: subject = "本技能召唤物的攻击"
		elif skill == &"homeward_light": subject = "本技能对自身与契约伙伴的治疗量"
		elif skill in [&"blink", &"night_shelter"]: subject = "本技能提供的护盾量"
		elif skill == &"spirit_parade": subject = "本技能的契约攻击强化比例"
		elif skill == &"ilyua_wind_arrow": subject = "贯风箭势期间发射的主普攻伤害"
		elif skill == &"ilyua_hunter_mark": subject = "本技能精准追射伤害"
		return "「%s」%s额外提高8%%，本路线累计提高%d%%。仅作用于对应技能，不提高角色基础属性。" % [name, subject, rank*8]
	if route == &"shape":
		var def: Array = definition(skill)
		var amount := float(def[3])
		var parameter := str(def[2])
		if parameter == "cooldown": return "「%s」基础冷却缩短%.1f秒，本路线累计缩短%.1f秒；遵守现有冷却下限。" % [name, amount, amount*rank]
		if parameter == "radius": return "「%s」作用半径增加%d像素，本路线累计增加%d像素；视觉范围同步扩大。" % [name, int(amount), int(amount*rank)]
		if parameter == "distance": return "「%s」最远移动距离增加%d像素，本路线累计增加%d像素；仍受实体地形阻挡。" % [name, int(amount), int(amount*rank)]
		var subject := "诱饵持续时间" if skill == &"ilyua_forest_step" else "寄生持续时间" if skill == &"ilyua_thorn_seed" else "强化持续时间" if skill == &"spirit_parade" else "持续时间"
		return "「%s」%s增加%.1f秒，本路线累计增加%.1f秒。" % [name, subject, amount, amount*rank]
	var lines: PackedStringArray = ["携带「%s」时启用以下联动：" % name]
	var old := legacy(character)
	for alias: StringName in definition(skill)[4]:
		var info: Dictionary = old[alias]
		if rank > int(info.max_rank): continue
		var text := str(info.desc)
		if character != &"xixifu":
			var parts := text.split("；")
			text = str(parts[mini(rank-1, parts.size()-1)])
			for prefix in ["1级", "2级", "3级", "一级", "二级", "三级"]: text = text.trim_prefix(prefix)
			if rank == int(info.max_rank) and parts.size() > rank:
				for index in range(rank, parts.size()): text += "；" + str(parts[index])
			if alias == &"holy_purity" and not text.contains("冷却"): text += " 冷却6秒。"
		else:
			text = text.replace("每级", "本节点")
			if alias in [&"contract_might",&"contract_vitality"]:text=text.replace("契约物","新召唤的契约物").replace("，保留当前生命比例", "；召唤时记录加成")
		lines.append("%s：%s" % [info.name, text])
	if rank == 3: lines.append("本技能魔力消耗降低10%%，只作用于「%s」。" % name)
	return "\n".join(lines)

static func equipped(skill: StringName) -> bool:
	return GameState.ultimate_skill==skill or GameState.learned_skills.has(skill)

static func route_rank(skill: StringName, route: StringName, ranks: Variant = null) -> int:
	if not equipped(skill): return 0
	var values: Dictionary = GameState.talents if ranks == null else ranks
	return clampi(int(values.get(route_id(skill, route), 0)), 0, 3)

static func legacy_rank(effect: StringName, ranks: Variant = null) -> int:
	var hero:=Characters.current_id()
	if not _legacy_owners.has(hero):
		var owners:Dictionary={}
		for skill:StringName in Skills.order_for(hero):
			for alias:StringName in definition(skill)[4]:owners[StringName(alias)]=skill
		_legacy_owners[hero]=owners
	var owner:StringName=_legacy_owners[hero].get(effect,&"")
	if owner==&"":return 0
	return mini(int(legacy(hero)[effect].max_rank),route_rank(owner,&"link",ranks))

static func power(skill: StringName) -> float:
	return 1.0 + .08 * route_rank(skill, &"power")

static func shape(skill: StringName, parameter: String) -> float:
	var def:=definition(skill)
	if def.is_empty() or str(def[2]) != parameter: return 0.0
	return float(def[3]) * route_rank(skill, &"shape")

static func visible_skills() -> Array[StringName]:
	return Skills.order_for().duplicate() if CampSession.active else GameState.skill_loadout()

static func tree_spent(skill: StringName) -> int:
	var total := 0
	for route: StringName in ROUTES: total += int(GameState.talents.get(route_id(skill, route), 0))
	return total
