class_name BuildInsight
extends RefCounted
## Configuration facts, never inferred from flavor text or shared build tags.
const NAMES:={"burn":"燃烧","slow":"减速","shield":"自身护盾","ally":"同行伙伴","contract":"主动契约物","star_mark":"星痕","wind_fan":"冲刺强化扇射","counter":"棘月反击波","shield_skill":"护盾技能","basic":"主普攻","skill":"主动技能","direct_skill":"主动技能直击","small_skill":"小技能","crit":"普攻暴击"}
const PROVIDES:={"ember_flower":["burn"],"copper_metre":["slow"],"ash_compass":["slow"],"frost_petal":["slow"],"root_talisman":["slow"],"thorn_shard":["slow"],"swallow_return":["shield"],"oath_guard":["shield"],"afterglow_note":["shield"],"moss_heart":["shield"],"tide_seals":["shield"],"broken_verse":["shield"],"last_flame":["shield"],"orbit_guard":["shield"],"dusk_mantle":["shield"],"farewell":["shield"],"cloud_vestment":["shield"],"cloud_staff":["shield"],"star_weave":["star_mark"],"wind_branch":["wind_fan"],"thorn_moon":["counter"]}
const NEEDS:={"scorch_bloom":["burn","direct_skill"],"ember_seed":["burn"],"ash_compass":["burn"],"hunt_needle":["slow"],"aftertone":["slow","direct_skill"],"frost_petal":["slow","direct_skill"],"thorn_moon":["shield"],"thorn_shard":["counter"],"sentinel_thread":["shield"],"root_talisman":["shield"],"soul_command":["ally"],"contract_chorus":["ally","skill"],"companion_knot":["ally"],"orbit_guard":["ally"],"wayfarer_score":["ally"],"dusk_lantern":["contract"],"echo_wick":["contract","dusk_wave"],"farewell":["contract","dusk_wave"],"dusk_mantle":["contract"],"watch_button":["shield_skill","ally"],"star_mirror":["star_mark"],"wind_chime":["wind_fan"],"refraction":["crit"],"amber_pendulum":["crit","skill"],"broken_verse":["crit"],"oath_guard":["direct_skill"],"tide_seals":["direct_skill"],"cloud_vestment":["small_skill"],"cloud_staff":["small_skill"]}
static func profiles(item:Dictionary)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for effect in item.get("mechanics",[]):
		var id:=str(effect.get("id",""))
		if not PROVIDES.has(id) and not NEEDS.has(id):continue
		var provided:Array=PROVIDES.get(id,[]).duplicate()
		if id=="dusk_lantern":provided.append("dusk_wave")
		result.append({"name":str(item.get("name",id)),"needs":NEEDS.get(id,[]),"provides":provided})
	var etch:=str(item.get("enchant",""))
	if not MaterialWorkshopCatalog.enchant(item).is_empty():
		result.append({"name":str(MaterialWorkshopCatalog.ENCHANTS[etch].name),"needs":[],"provides":["burn"] if etch=="ember" else ["shield","slow"] if etch=="gate" else ["shield"] if etch in ["moss","bone"] else []})
	return result
static func items(candidate:Dictionary={})->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for owned in GameState.items:
		if ItemDB.is_relic(owned):result.append(owned)
	for slot in ItemDB.SLOTS:
		var item:=candidate if not candidate.is_empty() and ItemDB.is_equippable(candidate) and ItemDB.can_equip(candidate) and ItemDB.slot_of(candidate)==slot else GameState.equipped(slot)
		if not item.is_empty():result.append(item)
	if ItemDB.is_relic(candidate) and not candidate in result:result.append(candidate)
	return result
static func capabilities(loadout:Array[Dictionary])->Dictionary:
	var caps:Dictionary={"basic":"主普攻"}
	if GameState.stats.get_value(&"crit_chance")>0:caps.crit="当前暴击属性"
	var skills:Array=GameState.learned_skills.duplicate();skills.append(GameState.ultimate_skill)
	for id in skills:
		if str(id).is_empty():continue
		var skill:=Skills.get_skill(StringName(id));var kind:=str(skill.get("effect",{}).get("kind",""));caps.skill="已装配主动技能"
		if not Skills.is_ultimate(StringName(id)):caps.small_skill=str(skill.name)
		if kind in ["summon","rally"]:caps.ally=str(skill.name);caps.contract=str(skill.name)
		if kind in ["shelter","holy_shield","holy_sanctuary"]:caps.shield=str(skill.name);caps.shield_skill=str(skill.name)
		if kind in ["shadow_echo","ilyua_vine_trap","ilyua_ancient_tree","holy_bell"]:caps.slow=str(skill.name)
		if kind in ["holy_dawn","holy_bell","holy_court","holy_step","shadow_echo","ilyua_thorn_seed","ilyua_vine_trap","ilyua_ancient_tree"]:caps.direct_skill=str(skill.name)
		if kind in ["holy_dawn","holy_bell","holy_step","shadow_echo","ilyua_thorn_seed"]:caps.fate_skill=str(skill.name)
	if not GameState.hired.is_empty():caps.ally="雇佣伙伴（需存活并在范围内）"
	if GameState.passive_id in [&"xixifu_revival",&"xixifu_wisps"]:caps.ally=str(PassiveDefinitions.DATA[GameState.passive_id].name)
	if int(GameState.talents.get(&"ilyua_forest_will",0))>0:caps.shield="森灵意志（低生命触发）"
	if int(GameState.talents.get(&"ilyua_forest_will",0))>=2:caps.slow="森灵意志（低生命触发）"
	if int(GameState.talents.get(&"holy_dew",0))>=3:caps.shield="晨露天赋（低生命触发）"
	if int(GameState.talents.get(&"holy_veil",0))>0 and caps.has("small_skill"):caps.shield="辉云纱幕（战斗中每三次小技能）"
	if int(GameState.talents.get(&"holy_word",0))>=2 and caps.has("direct_skill"):caps.slow="圣言天赋（须有效触发）"
	if FateCatalog.star()=="lantern":caps.shield="守灯座（每房首次入战）"
	var entries:Array[Dictionary]=[]
	for item in loadout:
		entries.append_array(profiles(item))
		if float(item.get("flat",{}).get("crit_chance",0))+float(item.get("mult",{}).get("crit_chance",0))>0:caps.crit=str(item.name)
	# Conditional providers cannot bootstrap themselves or a closed dependency cycle.
	for step in entries.size():
		var changed:=false
		for entry in entries:
			if not entry.needs.all(func(key:String)->bool:return caps.has(key)):continue
			for key in entry.provides:
				if not caps.has(key):caps[key]=entry.name;changed=true
		if not changed:break
	return caps
static func _condition(entry:Dictionary,caps:Dictionary)->String:
	var missing:PackedStringArray=[]
	for key in entry.needs:
		if not caps.has(key):missing.append(str(NAMES.get(key,"暮灯波" if key=="dusk_wave" else key)))
	if not missing.is_empty():return "尚缺触发条件 · %s：未配置%s来源。"%[entry.name,"、".join(missing)]
	var sources:PackedStringArray=[]
	for key in entry.needs:
		var text:=str(caps.get(key,""))
		if not text in sources:sources.append(text)
	return "当前可以衔接 · %s ← %s；仍须满足其命中、范围与冷却条件。"%[entry.name,"、".join(sources)] if not sources.is_empty() else ""
static func describe(candidate:Dictionary)->String:
	if not ItemDB.is_equippable(candidate) and not ItemDB.is_relic(candidate):return ""
	if ItemDB.is_equippable(candidate) and not ItemDB.can_equip(candidate):return ""
	var before:=capabilities(items());var after_items:=items(candidate);var after:=capabilities(after_items);var lines:PackedStringArray=[]
	if ItemDB.is_equippable(candidate) and not GameState.is_equipped(candidate):
		for item in after_items:
			for entry in profiles(item):
				if not entry.needs.is_empty() and entry.needs.all(func(key:String)->bool:return before.has(key)) and not entry.needs.all(func(key:String)->bool:return after.has(key)):
					lines.append("替换后失去联动 · "+_condition(entry,after))
	for entry in profiles(candidate):
		var line:=_condition(entry,after)
		if not line.is_empty() and not line in lines:lines.append(line)
	# A source item can enable an already held consumer, including fate cards.
	for item in after_items:
		for entry in profiles(item):
			if entry.needs.any(func(key:String)->bool:return not before.has(key)) and entry.needs.all(func(key:String)->bool:return after.has(key)):lines.append(_condition(entry,after))
	for card in GameState.fate.get("cards",[]):
		var need:=fate_needs(str(card.id))
		if not need.is_empty() and before.has(need)!=after.has(need):lines.append(("新增联动 · " if after.has(need) else "替换后失去联动 · ")+fate(str(card.id),bool(card.reverse),after))
	return "\n".join(lines.slice(0,2))
static func fate_needs(id:String)->String:return {"empress":"ally","emperor":"shield","moon":"slow"}.get(id,"")
static func fate(id:String,reverse:bool,caps:Dictionary={})->String:
	if caps.is_empty():caps=capabilities(items())
	var needs:=fate_needs(id);var title:=str(FateCatalog.CARDS.get(id,{}).get("name",id))
	if not needs.is_empty():return _condition({"name":title,"needs":[needs]},caps)
	if id=="hermit":return "条件提醒 · 隐者仅在四格内没有友军时强化自身直击。"+("当前配置了伙伴来源，需留意站位。" if caps.has("ally") else "当前未配置伙伴来源。")
	if id=="priestess" and not caps.has("fate_skill"):return "尚缺触发条件 · 女祭司：未配置可受启示强化的小技能直伤；召唤与持续领域不受强化。"
	return {"magician":"衔接方式 · 小技能后接主普攻；强化不能储存次数。","priestess":"衔接方式 · 静止取得启示后施放小技能；不强化持续领域或召唤伤害。","chariot":"衔接方式 · 基础闪避后接主普攻；技能闪避不触发。","star":"衔接方式 · 首次进入未清战斗房回复MP；每房一次。"}.get(id,"")+("逆位收益与代价同时生效，见上方说明。" if reverse else "")
