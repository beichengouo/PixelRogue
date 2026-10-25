class_name BuildPaths
extends RefCounted
const ROUTES:={
"sylphiette":[
{"id":"holy_judgment","name":"圣裁爆发","loop":"小技能圣裁命中积累祈光，衔接圣辉强化；大招覆盖敌群。","skills":["flame_nova","meteor"],"core":"staff_cloud_radiance","support":"armor_cloud_rites","relic":"relic_dew_battery","cards":["magician","priestess"],"note":"女祭司正位返还小技能MP并先见防护；逆位强化自身直击，不强化持续领域。"},
{"id":"holy_feathers","name":"圣羽连击","loop":"圣羽巡礼持续追击，普攻标定目标，交替施法维持回蓝。","skills":["fan_bolts"],"core":"staff_star_weave","support":"accessory_refraction","relic":"relic_star_mirror","cards":["magician","star"],"note":"星痕与折光由主普攻直击触发；圣羽不会代替主箭累计次数。"},
{"id":"holy_counter","name":"护盾反击","loop":"圣云庇佑吸收攻击，护盾因承伤耗尽时反击；主动技能继续输出。","skills":["blink"],"core":"armor_thorn_moon","support":"accessory_oath_guard","relic":"relic_thorn_shard","cards":["emperor"],"note":"棘月反击需要自身护盾被伤害耗尽；到期消失不等于破盾。"}],
"xixifu":[
{"id":"pact_melee","name":"近战契约","loop":"近战契约物接敌，普攻标记集火，夜幕庇护保护伙伴。","skills":["shadow_companions","gatekeeper"],"core":"staff_soul_command","support":"accessory_contract_chorus","relic":"relic_companion_knot","cards":["empress","star"],"note":"集火标记需要普攻有效命中；友军须存活并满足距离条件。"},
{"id":"pact_lantern","name":"远程幽灯","loop":"幽灯保持射线远程输出，普攻引导目标，施法刷新友军攻速。","skills":["ghost_lantern"],"core":"staff_soul_command","support":"accessory_companion_bells","relic":"relic_wayfarer_score","cards":["empress","magician"],"note":"幽灯与自身普通攻击分别结算，派生伤害不会递归触发装备。"},
{"id":"pact_farewell","name":"暮灯送别","loop":"为主动契约物附加灯印，伙伴被敌方击杀时释放暮灯波。","skills":["shadow_companions","ghost_lantern"],"core":"staff_dusk_lantern","support":"armor_farewell","relic":"relic_echo_wick","cards":["empress","star"],"note":"自然到期、切房和漂浮灵消失不触发暮灯波。"}],
"ilyua":[
{"id":"arrow_pierce","name":"穿透射击","loop":"追风箭强化主普攻，贯穿敌群，再以星痕直击连锁补充群伤。","skills":["ilyua_wind_arrow"],"core":"bow_spring_wind","support":"accessory_refraction","relic":"relic_star_lantern","cards":["magician","hermit"],"note":"主箭可以穿透多敌，但每发限次机制仍按原触发规则结算。"},
{"id":"arrow_seed","name":"荆棘寄生","loop":"荆棘之种持续伤害并恢复生命，藤蔓陷阱控制敌群，主箭补刀。","skills":["ilyua_thorn_seed","ilyua_vine_trap"],"core":"bow_spring_wind","support":"accessory_oath_guard","relic":"relic_hunt_needle","cards":["moon","star"],"note":"荆棘治疗受实际可恢复生命限制；命运牌伤痕修复另行结算。"},
{"id":"arrow_skirmish","name":"闪避游击","loop":"基础闪避衔接普攻，林间闪步制造叶影，利用月风回响继续输出。","skills":["ilyua_forest_step"],"core":"bow_spring_wind","support":"accessory_moonwind_chime","relic":"relic_patrol_bell","cards":["chariot","magician"],"note":"战车仅响应基础闪避；林间闪步属于技能闪避。"}]}
static func routes(hero:String="")->Array:return ROUTES.get(str(Characters.current_id()) if hero.is_empty() else hero,[])
static func selected(hero:String="")->String:
	return str(Outpost.data.get("workshop",{}).get("build_goals",{}).get(str(Characters.current_id()) if hero.is_empty() else hero,""))
static func set_goal(id:String)->String:
	if not CampSession.active:return "请在营地准备界面选择构筑目标。"
	if not id.is_empty() and not routes().any(func(row:Dictionary)->bool:return row.id==id):return "此角色没有该构筑路线。"
	var before:=Outpost.data.duplicate(true);var saved:=SaveService.data.duplicate(true)
	if not Outpost.data.has("workshop"):Outpost.data.workshop={}
	if not Outpost.data.workshop.has("build_goals"):Outpost.data.workshop.build_goals={}
	Outpost.data.workshop.build_goals[str(Characters.current_id())]=id
	return "" if Outpost._finish_mutation(before,saved) else "保存失败，构筑目标未改变。"
static func goal_name(hero:String="")->String:
	for row in routes(hero):
		if str(row.id)==selected(hero):return str(row.name)
	return "尚未选择，可展开构筑思路追踪"
static func source(item:Dictionary)->String:
	if item.is_empty():return "无可用获取途径"
	if ItemDB.is_material(item):return WorkshopGoals.material_source(str(item.id))
	for recipe in MaterialWorkshopCatalog.CRAFT:
		if str(recipe.product)==str(item.id):return "营地工坊 · "+str(recipe.name)+"（研究解锁后制作绑定装备）"
	var channels:PackedStringArray=[]
	for id in item.get("sources",["shop","chest","reward"]):
		var label:=str({"shop":"商店","chest":"宝箱","reward":"清房三选一","enemy":"战斗掉落","drop":"战斗掉落"}.get(str(id),str(id)))
		if not label in channels:channels.append(label)
	return "、".join(channels) if not channels.is_empty() else "不在随机掉落池；查看现有配方、委托或专属来源"
static func facts(snapshot:Dictionary)->Dictionary:
	var ids:Dictionary={};var spells:Dictionary={};var cards:Dictionary={}
	for id in snapshot.get("equipment",{}).values():
		var key:=str(id.get("id","")) if id is Dictionary else str(id)
		if not key.is_empty():ids[key]=true
	for item in snapshot.get("items",[]):
		var data:Dictionary=item if item is Dictionary else ItemDB.by_id(StringName(item))
		if ItemDB.is_relic(data):ids[str(data.get("id",""))]=true
	for id in snapshot.get("learned_skills",[]):spells[str(id)]=true
	spells[str(snapshot.get("ultimate_skill",""))]=true
	for card in snapshot.get("fate",{}).get("cards",[]):cards[str(card.get("id",""))]=true
	return {"items":ids,"skills":spells,"cards":cards}
static func live_snapshot()->Dictionary:
	return {"character":str(Characters.current_id()),"equipment":GameState.equipment,"items":GameState.items,"learned_skills":GameState.learned_skills,"ultimate_skill":str(GameState.ultimate_skill),"fate":GameState.fate}
static func describe(row:Dictionary,snapshot:Dictionary={})->String:
	var state:=facts(live_snapshot() if snapshot.is_empty() else snapshot)
	var lines:PackedStringArray=[str(row.name)+" · "+str(row.loop)]
	for part in [["core","核心"],["support","联动装备"],["relic","联动遗物"]]:
		var id:=str(row[part[0]]);var item:=ItemDB.by_id(StringName(id))
		lines.append("%s · %s%s"%[part[1],str(item.get("name",id)),("（已持有）" if ItemDB.is_relic(item) else "（已装备）") if state.items.has(id) else "；"+source(item)])
	var spells:PackedStringArray=[]
	for id in row.skills:
		var skill:=Skills.get_skill(StringName(id))
		spells.append(str(skill.get("name",id))+(" ✓" if state.skills.has(id) else "（未装配）"))
	lines.append("技能衔接 · "+"、".join(spells))
	var cards:PackedStringArray=[]
	for id in row.cards:cards.append(str(FateCatalog.CARDS[id].name)+(" ✓" if state.cards.has(id) else ""))
	lines.append("命运联动 · "+"、".join(cards)+"；正逆位均需满足各自条件。")
	lines.append("触发限制 · "+str(row.note))
	return "\n".join(lines)
static func summary(snapshot:Dictionary)->String:
	var hero:=str(snapshot.get("character",Characters.current_id()));var state:=facts(snapshot)
	var lines:PackedStringArray=[]
	var goal:=str(snapshot.get("build_goal",""))
	for row in routes(hero):
		if str(row.id)==goal:lines.append("本局追踪 · "+str(row.name))
	for row in routes(hero):
		var parts:=0
		for key in ["core","support","relic"]:
			if state.items.has(str(row[key])):parts+=1
		if parts>0:lines.append("%s · 已配置%d／3项核心联动（仍须满足技能、距离和冷却条件）"%[str(row.name),parts])
	return "\n".join(lines) if not lines.is_empty() else "尚未配置上述路线的核心联动；可在营地准备页查看三条构筑思路。"
static func item_routes(id:String)->String:
	var names:PackedStringArray=[]
	for hero in ROUTES:
		for row in ROUTES[hero]:
			if id in [str(row.core),str(row.support),str(row.relic)]:names.append(str(row.name))
	return "构筑用途 · "+"、".join(names) if not names.is_empty() else ""
