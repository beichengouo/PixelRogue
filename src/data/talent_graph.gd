class_name TalentGraph
extends RefCounted
static var _cache: Dictionary = {}

static func source(character: StringName = &"") -> Dictionary:
	return SkillTalentCatalog.data(character)

static func id_for(effect: StringName, rank: int) -> StringName:
	return StringName("%s__%d" % [effect, rank])

static func nodes(character: StringName = &"") -> Dictionary:
	var hero := Characters.current_id() if character == &"" else character
	if _cache.has(hero): return _cache[hero]
	var result: Dictionary = {}
	for effect: StringName in source(hero):
		var info: Dictionary = source(hero)[effect]
		for rank in range(1, 4):
			var id := id_for(effect, rank)
			var parents: Array[StringName] = []
			if rank > 1: parents.append(id_for(effect, rank-1))
			result[id] = {"id":id, "effect":effect, "rank":rank, "max_rank":1,
				"name":"%s · %s" % [info.name, SkillTalentCatalog.ROMAN[rank-1]],
				"short_name":info.name, "icon":info.icon, "desc":info.descriptions[rank-1],
				"branch":info.skill, "skill":info.skill, "branch_name":info.branch_name,
				"route":info.route, "route_name":info.route_name,
				"tier":rank, "row":rank-1, "lane":int(info.tier)-1, "column":int(info.tier)-2,
				"requires_all":parents, "requires_any":[]}
	_cache[hero] = result
	return result

static func visible_nodes() -> Dictionary:
	var result: Dictionary = {}
	var visible := SkillTalentCatalog.visible_skills()
	for id: StringName in nodes():
		if visible.has(node(id).skill): result[id] = node(id)
	return result

static func node(id: StringName) -> Dictionary: return nodes().get(id, {})

static func resolve(id: StringName, ranks: Dictionary) -> StringName:
	if nodes().has(id): return id
	if not source().has(id): return &""
	return id_for(id, mini(int(ranks.get(id, 0))+1, 3))

static func owned(id: StringName, ranks: Dictionary) -> bool:
	var info := node(id)
	return not info.is_empty() and int(ranks.get(info.effect, 0)) >= int(info.rank)

static func available(id: StringName) -> bool:
	var info := node(id)
	return not info.is_empty() and (CampSession.active or SkillTalentCatalog.equipped(info.skill))

static func unlocked(id: StringName, ranks: Dictionary) -> bool:
	var info := node(id)
	if not available(id): return false
	if owned(id, ranks): return true
	if int(ranks.get(info.effect, 0)) != int(info.rank)-1: return false
	for need: StringName in info.requires_all:
		if not owned(need, ranks): return false
	return true

static func requirement_text(id: StringName, ranks: Dictionary, show_state := true) -> String:
	var info := node(id)
	if info.is_empty(): return "天赋不可用"
	if not available(id): return "需携带「%s」" % info.branch_name
	if info.requires_all.is_empty(): return "技能根节点已点亮，可投入1点"
	var parts: PackedStringArray = []
	for need: StringName in info.requires_all:
		parts.append(str(node(need).name) + ((" ✓" if owned(need, ranks) else " · 未点亮") if show_state else ""))
	return "；".join(parts)

static func rank_description(effect: StringName, rank: int, character: StringName) -> String:
	return str(source(character)[effect].descriptions[clampi(rank-1, 0, 2)])
