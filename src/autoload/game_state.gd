extends Node
## 一局游戏的全部运行时状态。
##
## 做成 autoload 的好处：重开一局只要调 new_run()，
## 所有系统读到的都是最新状态，不需要在节点之间传来传去。
##
## 三道「钱」：coins（金币，商店用）、keys（钥匙，开宝箱用）、
## items（背包里的东西，包含还没装备的装备）。

## 玩家基础属性。改这里就能改手感；道具是在这个基础上做加法 / 乘法。
const BASE_STATS := {
	&"attack": 11.2,
	&"max_hp": 100.0,
	&"move_speed": 160.0,
	&"dash_cooldown": 3.6,
	&"lifesteal": 0.0,
	&"thorns": 0.0,
	&"crit_chance": 0.0,
	&"crit_mult": 2.0,
	&"coin_gain": 1.0,
	&"attack_speed": 1.56,
	&"mp_regen": 3.0,
}

var stats: StatBlock
## 背包。可装备的东西也先放这里，装备之后会从这里移走。
var items: Array[Dictionary] = []
## 装备栏：槽位 -> 道具（空槽是 {}）
var equipment: Dictionary = {}
var run_loot: Dictionary = {}
var material_ledger:Dictionary={}
var build_stats:Dictionary=RunBuildMetrics.empty(false)
## An item counts when it is shown in any run reward pool, even if declined.
var run_refreshes: Dictionary = {}
var loot_history_complete := true
var coins: int = 0
var auto_coin_remainder:=0
var keys: int = 0
var wave: int = 0
var combat_mode := "rooms"
var chapter_id:StringName=ChapterCatalog.FIRST
var chapter_cleared := false
var endless_mode := false
var run_active: bool = false
## 有效游玩仅由波次调度累计，不按系统时间补算离线或菜单停留。
var active_play_seconds := 0.0
var first_chapter_seconds := -1.0
var wave_completed := false
var wave_exp_awarded := 0.0
var wave_exp_multiplier := 1.0
var altar_blessings:Dictionary={}
var fate:Dictionary=FateCatalog.empty()
var legendary_looks:Dictionary={}
var achievement_run:Dictionary={}
signal play_time_changed(seconds:int)
var player: Node2D = null
## 限时增益（药剂给的）。结构：{"stat": StringName, "value": float, "remaining": float, "label": String}
var temp_buffs: Array[Dictionary] = []

## ---------------- 等级 / 经验 ----------------
const MAX_LEVEL := 100
const HP_PER_LEVEL := 6.0      # 每级加的最大生命
const ATK_PER_LEVEL := 1.2     # 每级加的攻击力

var level := 1
var exp := 0.0
## 天赋加点：分支 id -> 等级
var talents: Dictionary = {}
var talent_points := 0

## ---------------- 魔法值 ----------------
const MAX_MP := 100.0
const MP_REGEN := 3.0          # 每秒自然恢复（调慢一点：技能要省着放）
var mp := MAX_MP

## ---------------- 药水快捷栏 ----------------
const HOTBAR_SIZE := 3
var potion_hotbar: Array = []

## ---------------- 技能（按等级解锁，不是天赋）----------------
const SKILL_SLOTS := 3       # 普通技能栏位
var unlocked_skills: Array[StringName] = []
var skill_cooldowns_by_id: Dictionary = {}
## 已配装的 Q / F / G，与永久保留的局内技能库分开。
var learned_skills: Array[StringName] = []
var ultimate_skill: StringName = &""
## 三个技能 + 一个大招的剩余冷却
var skill_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
## 学会但还没决定放哪的技能（栏位满了就等玩家决定替换谁）
var pending_skills: Array[StringName] = []

## 天赋分支（魔法师）：伤害 / 爆裂 / 多重投射
const MAGE_TALENTS := {
	&"nova_shot": {"name": "扩焰环", "max_rank": 2, "desc": "烬环每级半径增加半格。", "branch_name": "烬环震退", "branch": "hunt", "tier": 1, "icon": "res://assets/next_revision/talents/nova_shot.png", "requires": {}},
	&"nova_might": {"name": "炽心", "max_rank": 3, "desc": "烬环每级伤害 +10%。", "branch_name": "烬环震退", "branch": "hunt", "tier": 2, "icon": "res://assets/next_revision/talents/nova_might.png", "requires": {"nova_shot": 1}},
	&"nova_pierce": {"name": "震焰", "max_rank": 1, "desc": "推退距离增加25%。", "branch_name": "烬环震退", "branch": "hunt", "tier": 3, "icon": "res://assets/next_revision/talents/nova_pierce.png", "requires": {"nova_might": 2}},
	&"nova_ghost": {"name": "余温羁绊", "max_rank": 1, "desc": "命中额外减速20%，持续2秒。", "branch_name": "烬环震退", "branch": "hunt", "tier": 4, "icon": "res://assets/next_revision/talents/nova_ghost.png", "requires": {"nova_pierce": 1}},
	&"power": {"name": "焰心", "max_rank": 3, "desc": "每级基础攻击力 +6%，强化普攻与伤害技能。", "branch_name": "余烬爆破", "branch": "blast", "tier": 1, "icon": "res://assets/ui/painted/talent_power.tres", "requires": {}},
	&"blast": {"name": "爆裂余烬", "max_rank": 3, "desc": "火球命中产生溅射，不重复伤害直击目标。半径为 40＋每级 12，溅射伤害为直击伤害的每级 20%。", "branch_name": "余烬爆破", "branch": "blast", "tier": 2, "icon": "res://assets/ui/painted/talent_blast.tres", "requires": {"power": 1}},
	&"ignite": {"name": "引燃", "max_rank": 3, "desc": "火球命中附加 3 秒点燃，每级每秒造成 10% 攻击力伤害。重复命中刷新持续时间，伤害取较强值，不逐发叠加。", "branch_name": "余烬爆破", "branch": "blast", "tier": 3, "icon": "res://assets/ui/painted/talent_ignite.tres", "requires": {"blast": 1}},
	&"chain_blast": {"name": "余烬共振", "max_rank": 1, "desc": "火球爆炸范围 +25%；同样强化绯星坠落的范围。", "branch_name": "余烬爆破", "branch": "blast", "tier": 4, "icon": "res://assets/ui/painted/talent_chain_blast.tres", "requires": {"ignite": 2}},
	&"nature_attune": {"name": "自然亲和", "max_rank": 3, "desc": "每级自然技能治疗量 +6%，烬火护衣的护盾量 +10%。", "branch_name": "自然共鸣", "branch": "nature", "tier": 1, "icon": "res://assets/ui/painted/talent_nature_attune.tres", "requires": {}},
	&"thorn_bind": {"name": "深根", "max_rank": 2, "desc": "藤蔓缠绕每级持续时间 +0.5 秒。", "branch_name": "自然共鸣", "branch": "nature", "tier": 2, "icon": "res://assets/ui/painted/talent_thorn_bind.tres", "requires": {"nature_attune": 1}},
	&"sprout_return": {"name": "魔力新芽", "max_rank": 2, "desc": "每级：施放自然技能后返还 4 魔力。", "branch_name": "自然共鸣", "branch": "nature", "tier": 3, "icon": "res://assets/ui/painted/talent_sprout_return.tres", "requires": {"thorn_bind": 1}},
	&"living_bloom": {"name": "长生花园", "max_rank": 1, "desc": "森罗绽放的领域持续时间 +2 秒。", "branch_name": "自然共鸣", "branch": "nature", "tier": 4, "icon": "res://assets/ui/painted/talent_living_bloom.tres", "requires": {"sprout_return": 2}},
	&"arcane_reserve": {"name": "魔力流转", "max_rank": 3, "desc": "每级自然回蓝 +0.4/秒、普通技能冷却 -5%。", "branch_name": "星辉秘术", "branch": "star", "tier": 1, "icon": "res://assets/ui/painted/talent_arcane_reserve.tres", "requires": {}},
	&"star_step": {"name": "轻灵星步", "max_rank": 2, "desc": "星辉震荡每级范围 +20、冷却减少 0.7 秒。", "branch_name": "星辉秘术", "branch": "star", "tier": 2, "icon": "res://assets/ui/painted/talent_star_step.tres", "requires": {"arcane_reserve": 1}},
	&"quick_weave": {"name": "灵动编织", "max_rank": 2, "desc": "星辉震荡后 4 秒，每级攻击力 +8%。重复施放刷新持续时间。", "branch_name": "星辉秘术", "branch": "star", "tier": 3, "icon": "res://assets/ui/painted/talent_quick_weave.tres", "requires": {"star_step": 1}},
	&"celestial_focus": {"name": "秘术共鸣", "max_rank": 1, "desc": "大招冷却 -20%，大招魔力消耗 -10%。", "branch_name": "星辉秘术", "branch": "star", "tier": 4, "icon": "res://assets/ui/painted/talent_celestial_focus.tres", "requires": {"quick_weave": 2}},
}



func _ready() -> void:
	if "--room-editor" in OS.get_cmdline_user_args():return
	stats = StatBlock.new()
	_clear_equipment()
	_reset_stats()


var TALENT_BRANCHES: Dictionary:
	get:
		if Characters.current_id()==&"xixifu":return SummonerTalents.DATA
		if Characters.current_id()==&"ilyua":return IlyuaTalents.DATA
		return HolyTalents.DATA

func talent_groups()->Array:
	var result:Array=[];var seen:Dictionary={}
	for info:Dictionary in TALENT_BRANCHES.values():
		var branch:=StringName(info.get("branch",&""))
		if seen.has(branch):continue
		seen[branch]=true;result.append([branch,str(info.get("branch_name","天赋"))])
	return result

var sortie_id := ""
var difficulty := 1
var danger:int:
	get:return RunDifficulty.multiplier(difficulty)-1
	set(value):difficulty=RunDifficulty.from_legacy_danger(value)
var runtime_node: Node
var item_sequence := 0

var run_epoch := 0
var gm_pilot_used:=false
var gm_pilot_active:=false
var passive_id: StringName = &""
var passive_rng := RandomNumberGenerator.new()

func new_run(seed_value: int = 0) -> void:
	stats.status_owner = null
	combat_mode = "rooms"
	run_epoch += 1
	gm_pilot_used=false;gm_pilot_active=false
	passive_id = PassiveDefinitions.selected(Characters.current_id())
	sortie_id = ""
	difficulty = 1
	item_sequence = 0
	run_loot.clear();material_ledger.clear();build_stats=RunBuildMetrics.empty()
	run_refreshes.clear()
	loot_history_complete = true
	items.clear()
	hired.clear()
	temp_buffs.clear()
	altar_blessings.clear();fate=FateCatalog.empty();wave_exp_multiplier=1.0
	legendary_looks.clear()
	achievement_run.clear()
	talents.clear()
	level = 1
	exp = 0.0
	talent_points = 1
	mp = MAX_MP
	potion_hotbar = [{}, {}, {}]
	learned_skills.clear()
	unlocked_skills.clear()
	pending_skills.clear()
	skill_cooldowns_by_id.clear()
	ultimate_skill = &""
	skill_cooldowns = [0.0, 0.0, 0.0, 0.0]
	_clear_equipment()
	coins = 0
	auto_coin_remainder=0
	keys = 0
	wave = 0
	active_play_seconds = 0.0
	first_chapter_seconds = -1.0
	wave_completed = false
	wave_exp_awarded = 0.0
	play_time_changed.emit(0)
	chapter_id=ChapterCatalog.FIRST
	chapter_cleared = false
	endless_mode = false
	run_active = true
	_reset_stats()
	_learn_skill(Skills.order_for()[0])
	Rng.start_run(seed_value)
	passive_rng.seed = hash(str(Rng.run_seed)+":passive")
	EventBus.run_started.emit(int(SaveService.data.get("runs", 0)) + 1)
	EventBus.coins_changed.emit(coins)
	EventBus.keys_changed.emit(keys)
	EventBus.equipment_changed.emit()
	EventBus.player_stats_changed.emit()


## ---------------- 经验 / 升级 ----------------

func exp_needed(for_level: int) -> float:
	return WaveTable.experience_needed(for_level)

func advance_play_time(seconds:float)->void:
	if not run_active or get_tree().paused or seconds<=0.0:return
	var before := int(active_play_seconds)
	active_play_seconds += seconds
	if int(active_play_seconds)!=before:play_time_changed.emit(int(active_play_seconds))

func play_time_text(seconds:float = -1.0)->String:
	var total := int(maxf(0.0,active_play_seconds if seconds<0.0 else seconds))
	return "%02d:%02d:%02d" % [int(total/3600),int(total/60)%60,total%60]

func claim_wave_experience(clear:bool=false)->void:
	var pool := WaveTable.experience_pool(wave)*wave_exp_multiplier
	var plan := RoomLayout.encounter(wave) if combat_mode=="rooms" else WaveTable.build(wave)
	var ceiling := pool if clear else pool*0.7
	var portion := pool if clear else pool*0.7/maxf(1,float(plan.total if not plan.boss else 10))
	var amount := minf(portion,maxf(0.0,ceiling-wave_exp_awarded))
	wave_exp_awarded += amount
	gain_exp(amount)

func _saved_seconds(value:Variant,fallback:float=0.0)->float:
	if not (value is float or value is int):return fallback
	var seconds := float(value)
	return fallback if is_nan(seconds) or is_inf(seconds) else clampf(seconds,0.0,315360000.0)


func gain_exp(amount: float) -> void:
	if level >= MAX_LEVEL or amount <= 0.0:
		return
	exp += amount
	var levels_gained := 0
	while level < MAX_LEVEL and exp >= exp_needed(level):
		exp -= exp_needed(level)
		level += 1
		levels_gained += 1
	if levels_gained <= 0:
		EventBus.player_stats_changed.emit()
		return
	# 每级成长属性，每逢 3 的倍数等级获得天赋点
	talent_points += int(level / 3) - int((level - levels_gained) / 3)
	_reset_stats()
	if player != null and is_instance_valid(player):
		if player.has_method("on_level_up"):
			player.on_level_up(level)
	EventBus.level_changed.emit(level, levels_gained)
	EventBus.player_stats_changed.emit()
	# 技能按各自解锁等级进入法术库，满栏也保留
	for step in range(levels_gained):
		var reached := level - levels_gained + 1 + step
		var skill_id := Skills.next_skill_for_level(reached)
		if skill_id != &"":
			_learn_skill(skill_id)


func _learn_skill(id: StringName) -> void:
	if not Skills.order_for().has(id) or unlocked_skills.has(id):
		return
	unlocked_skills.append(id)
	if Skills.is_ultimate(id):
		if ultimate_skill == &"":
			ultimate_skill = id
	else:
		var empty := learned_skills.find(&"")
		if empty >= 0:
			learned_skills[empty] = id
		elif learned_skills.size() < SKILL_SLOTS:
			learned_skills.append(id)
	_sync_skill_cooldowns()
	EventBus.skills_changed.emit()

func equip_skill(id: StringName, slot: int) -> bool:
	if not unlocked_skills.has(id) or slot < 0 or slot > 3:
		return false
	if Skills.is_ultimate(id) != (slot == 3):
		return false
	if slot == 3:
		ultimate_skill = id
	else:
		while learned_skills.size() < SKILL_SLOTS:
			learned_skills.append(&"")
		var old := learned_skills.find(id)
		if old >= 0 and old != slot:
			learned_skills[old] = learned_skills[slot]
		learned_skills[slot] = id
	_sync_skill_cooldowns()
	EventBus.skills_changed.emit()
	return true

func _sync_skill_cooldowns() -> void:
	for slot in 4:
		skill_cooldowns[slot] = float(skill_cooldowns_by_id.get(skill_for_slot(slot), 0.0))

func skill_cost(id: StringName) -> float:
	var value := float(Skills.get_skill(id).get("mp", 0.0))
	if Skills.is_ultimate(id) and talent_rank(&"celestial_focus") > 0:
		value *= 1.0 - talent_effect(&"celestial_focus", "大招魔力减少%") / 100.0
	if passive_id == &"sylphiette_arcane": value *= 0.5
	if not Skills.is_ultimate(id) and FateCatalog.rank("magician")==2:value*=1.1
	return value

func skill_cooldown(id: StringName) -> float:
	var value := float(Skills.get_skill(id).get("cd", 1.0))
	if Skills.is_ultimate(id):
		if talent_rank(&"celestial_focus") > 0:
			value *= 1.0 - talent_effect(&"celestial_focus", "大招冷却减少%") / 100.0
	else:
		value *= 1.0 - talent_effect(&"arcane_reserve", "普通技能冷却减少%") / 100.0
	if id == &"shadow_step":value-=talent_effect(&"shadow_stride","影步冷却减少秒数")
	if id == &"blink":
		value -= talent_effect(&"star_step", "星跃冷却减少秒数")
	if passive_id == &"sylphiette_arcane": value *= 0.5
	if not Skills.is_ultimate(id) and is_instance_valid(player):value*=2.0-PlayerDebuffs.multiplier(player,&"skill_cooldown")
	return maxf(0.5, value)



func replace_skill_with_pending(slot: int) -> bool:
	if pending_skills.is_empty():
		return false
	var id: StringName = pending_skills.pop_front()
	_learn_skill(id)
	return equip_skill(id, slot)



func discard_pending_skill(index := 0) -> bool:
	if index < 0 or index >= pending_skills.size():
		return false
	pending_skills.remove_at(index)
	EventBus.skills_changed.emit()
	return true


func skill_for_slot(slot: int) -> StringName:
	## slot 0..2 = 技能栏（Q/F/G），slot 3 = 大招（V）
	if slot == 3:
		return ultimate_skill
	if slot < 0 or slot >= learned_skills.size():
		return &""
	return learned_skills[slot]


func skill_ready(slot: int) -> bool:
	var id := skill_for_slot(slot)
	if id == &"":
		return false
	# Slot timers are a presentation cache. Cast eligibility belongs to the
	# equipped skill ID, including immediately after a loadout change.
	if float(skill_cooldowns_by_id.get(id, 0.0)) > 0.0:
		return false
	return mp >= skill_cost(id)


func begin_skill_cast(slot: int) -> StringName:
	var id := skill_for_slot(slot)
	if id == &"" or not skill_ready(slot):
		return &""
	mp = maxf(0.0, mp - skill_cost(id))
	skill_cooldowns_by_id[id] = skill_cooldown(id)
	_sync_skill_cooldowns()
	EventBus.mp_changed.emit(mp, MAX_MP)
	FateRuntime.cast(id)
	EventBus.skill_cast.emit(id)
	return id



func talent_rank(branch: StringName) -> int:
	return int(talents.get(branch, 0))


func talent_effect(branch: StringName, key: String, ranks: Variant = null) -> float:
	var source: Dictionary = talents if ranks == null else ranks
	return float(_talent_effects(branch, int(source.get(branch, 0))).get(key, 0.0))

func _talent_effects(branch: StringName, rank: int) -> Dictionary:
	if HolyTalents.DATA.has(branch):return {"已解锁层级":clampi(rank,0,3)}
	var ilyua_effect:=IlyuaTalents.effects(branch,rank)
	if not ilyua_effect.is_empty():return ilyua_effect
	var contract_effect:=SummonerTalents.effects(branch,rank)
	if not contract_effect.is_empty():return contract_effect
	match branch:
		&"nova_shot": return {"烬环额外半径": rank * 18.0}
		&"nova_might": return {"烬环伤害加成%": rank * 10.0}
		&"nova_pierce": return {"烬环推力加成%": rank * 25.0}
		&"nova_ghost": return {"烬环减速%": rank*20.0}
		&"power": return {"攻击加成%": rank * 6.0}
		&"blast": return {"溅射半径": 40.0 + rank * 12.0 if rank > 0 else 0.0, "溅射伤害%": rank * 20.0}
		&"ignite": return {"点燃每秒攻击力%": rank * 10.0}
		&"chain_blast": return {"爆炸范围加成%": rank * 25.0}
		&"nature_attune": return {"自然治疗加成%": rank * 6.0, "护盾加成%": rank * 10.0}
		&"thorn_bind": return {"缠绕额外秒数": rank * 0.5}
		&"sprout_return": return {"自然施法返还魔力": rank * 4.0}
		&"living_bloom": return {"领域额外秒数": rank * 2.0}
		&"arcane_reserve": return {"每秒额外回蓝": rank * 0.4, "普通技能冷却减少%": rank * 5.0}
		&"star_step": return {"星跃额外距离": rank * 20.0, "星跃冷却减少秒数": rank * 0.7}
		&"quick_weave": return {"星跃后4秒攻击加成%": rank * 8.0}
		&"celestial_focus": return {"大招冷却减少%": rank * 20.0, "大招魔力减少%": rank * 10.0}
	return {}

func preview_talent(branch: StringName) -> Dictionary:
	if not TALENT_BRANCHES.has(branch): return {}
	var current := talent_rank(branch)
	var next := mini(current + 1, int(TALENT_BRANCHES[branch].max_rank))
	var before := _talent_effects(branch, current)
	var after := _talent_effects(branch, next)
	var lines: Array[String] = []
	if HolyTalents.DATA.has(branch):
		var parts:=str(TALENT_BRANCHES[branch].desc).split("；")
		var active:PackedStringArray=[]
		for index in mini(current,parts.size()):active.append(parts[index])
		lines.append("当前%d级：%s"%[current,"；".join(active) if current>0 else "尚未激活"])
		if next>current:lines.append("下一级新增："+str(parts[mini(current,parts.size()-1)]))
	for key: String in before:
		var label := key.replace("星跃额外距离", "星辉震荡范围").replace("星跃冷却减少秒数", "星辉震荡冷却减少秒数").replace("星跃后4秒", "星辉震荡后4秒")
		lines.append("%s：%s%s → %s%s" % [label.replace("%", ""), str(before[key]), "%" if "%" in key else "", str(after[key]), "%" if "%" in key else ""])
	# Conditional damage stays a coefficient; it is never represented as raw combat power.
	if branch == &"ignite": lines.append("命中时点燃3秒；重复命中刷新时间")
	if branch == &"quick_weave": lines.append("仅在星辉震荡后生效；重复施放刷新时间")
	if branch == &"blast": lines.append("仅溅射周围敌人，不重复伤害直击目标")
	var ranks := talents.duplicate(true)
	ranks[branch] = next
	var projected := StatBlock.new()
	projected.status_owner = stats.status_owner
	for stat: StringName in BASE_STATS: projected.set_base(stat, UnitBalance.player_base(stat,float(BASE_STATS[stat])))
	for item in items:
		if not ItemDB.is_equippable(item): _apply_to(projected, item)
	for slot: StringName in ItemDB.SLOTS:
		if not equipment[slot].is_empty(): _apply_to(projected, equipment[slot])
	_apply_progression_to(projected, ranks)
	LegendarySets.apply_to(projected)
	_apply_lifesteal_sources(projected)
	return {"branch": branch, "current_rank": current, "next_rank": next,
		"before": before, "after": after, "stats": projected, "text": "\n".join(lines),
		"can_upgrade": talent_points > 0 and talent_unlocked(branch) and next > current}

func spend_talent_point(branch: StringName) -> bool:
	if talent_points <= 0 or not TALENT_BRANCHES.has(branch):
		return false
	if not talent_unlocked(branch):
		return false
	if talent_rank(branch) >= int(TALENT_BRANCHES[branch]["max_rank"]):
		return false
	talents[branch] = talent_rank(branch) + 1
	talent_points -= 1
	_reset_stats()
	EventBus.talents_changed.emit()
	EventBus.player_stats_changed.emit()
	return true


func talent_unlocked(branch: StringName) -> bool:
	## 天赋树的前置条件：requires 里每个分支都要达到指定等级
	if not TALENT_BRANCHES.has(branch):
		return false
	var requires: Dictionary = TALENT_BRANCHES[branch].get("requires", {})
	for need: StringName in requires:
		if talent_rank(need) < int(requires[need]):
			return false
	return true


const TALENT_RESET_COST := 100
func spent_talent_points() -> int:
	var count := 0
	for rank in talents.values(): count += int(rank)
	return count
func can_reset_talents() -> bool:
	return CampSession.active or spent_talent_points() == 0 or coins >= TALENT_RESET_COST
func reset_talents() -> bool:
	var spent := spent_talent_points()
	if spent == 0: return true
	if not CampSession.active:
		if coins < TALENT_RESET_COST:return false
		coins -= TALENT_RESET_COST
	talents.clear()
	talent_points += spent
	_reset_stats()
	EventBus.coins_changed.emit(coins)
	EventBus.talents_changed.emit()
	EventBus.player_stats_changed.emit()
	Outpost.request_checkpoint()
	return true


## ---------------- 魔法值 ----------------

func spend_mp(amount: float) -> bool:
	if mp < amount:
		return false
	mp -= amount
	EventBus.mp_changed.emit(mp, MAX_MP)
	return true


func add_mp(amount: float) -> void:
	mp = clampf(mp + amount, 0.0, MAX_MP)
	EventBus.mp_changed.emit(mp, MAX_MP)


## ---------------- 药水快捷栏 ----------------

func _normalize_hotbar() -> void:
	## 快捷栏长度必须是 HOTBAR_SIZE：老存档 / 旧版本存下来的可能只有 1~2 个槽，
	## 直接按 3 去索引就会 "Out of bounds get index '2'"，然后每帧报错像卡死。
	while potion_hotbar.size() < HOTBAR_SIZE:
		potion_hotbar.append({})
	if potion_hotbar.size() > HOTBAR_SIZE:
		potion_hotbar.resize(HOTBAR_SIZE)


func set_hotbar_slot(index: int, item: Dictionary) -> bool:
	if index < 0 or index >= HOTBAR_SIZE or not ItemDB.is_usable(item):
		return false
	_normalize_hotbar()
	# 同一件药剂不能占两个槽
	for i in HOTBAR_SIZE:
		if potion_hotbar[i].get("id", &"") == item["id"]:
			potion_hotbar[i] = {}
	potion_hotbar[index] = item
	EventBus.hotbar_changed.emit()
	return true


func clear_hotbar_slot(index: int) -> void:
	if index < 0 or index >= HOTBAR_SIZE:
		return
	_normalize_hotbar()
	potion_hotbar[index] = {}
	EventBus.hotbar_changed.emit()


func use_hotbar(index: int) -> bool:
	if index < 0 or index >= HOTBAR_SIZE:
		return false
	_normalize_hotbar()
	var item: Dictionary = potion_hotbar[index]
	if item.is_empty():
		return false
	if not use_item(item):
		# 药剂已经不在背包里（用掉了）→ 清掉快捷栏
		clear_hotbar_slot(index)
		return false
	if not has_item(item["id"]): clear_hotbar_slot(index)
	return true


func end_run() -> void:
	if not run_active: return
	if not sortie_id.is_empty():
		Outpost.mark_dead(wave,coins)
	else: SaveService.record_run(wave,coins)
	run_active=false
	EventBus.run_ended.emit(wave,coins)


func add_item(item: Dictionary) -> bool:
	if item.is_empty() or not can_add_item(item): return false
	var acquired := item.duplicate(true)
	if str(acquired.get("uid","")).is_empty():
		item_sequence+=1
		acquired["uid"] = sortie_id+":"+str(item_sequence)
	items.append(acquired)
	if ItemDB.is_material(acquired) and not CampSession.active:
		var collected:Dictionary=material_ledger.get("collected",{});var material_id:=str(acquired.id)
		collected[material_id]=int(collected.get(material_id,0))+1;material_ledger.collected=collected
	var loot_id := str(acquired.get("id",""))
	run_loot[loot_id] = int(run_loot.get(loot_id,0))+1
	if not ItemDB.is_equippable(acquired): _reset_stats()
	EventBus.item_acquired.emit(acquired)
	EventBus.item_received.emit(acquired)
	EventBus.player_stats_changed.emit()
	Outpost.request_checkpoint()
	return true

const BAG_CATEGORY_CAPACITY := 24
func bag_category(item: Dictionary) -> StringName:
	if ItemDB.is_equippable(item): return &"gear"
	if ItemDB.is_material(item): return &"material"
	if ItemDB.is_usable(item): return &"potion"
	return &"relic"
func bag_slots(candidate: Dictionary = {}, category: StringName = &"") -> int:
	var counts := {}
	var used := 0
	var all: Array = items.duplicate()
	if not candidate.is_empty(): all.append(candidate)
	for item: Dictionary in all:
		var kind := bag_category(item)
		if kind == &"relic" or (category != &"" and kind != category): continue
		if kind == &"gear": used += 1
		else:
			var id := str(item.id)
			if not counts.has(id): counts[id] = {"count":0,"limit":20 if kind == &"material" else 5}
			counts[id].count += 1
	for entry: Dictionary in counts.values(): used += ceili(float(entry.count)/int(entry.limit))
	return used
func can_add_item(item: Dictionary) -> bool:
	if item.is_empty(): return false
	var category := bag_category(item)
	if category == &"relic": return true
	var id := str(item.get("id",""))
	if id.begins_with("glow_mushroom_"):
		var total := int(Outpost.data.get("inventory",{}).get(id,0))
		for held: Dictionary in items:
			if str(held.get("id","")) == id: total += 1
		if total >= 999: return false
	return bag_slots(item,category) <= BAG_CATEGORY_CAPACITY

func sell_item(item: Dictionary) -> bool:
	var value := ExpeditionData.sale_value(item)
	var index := items.find(item)
	var equipped_slot: StringName = &""
	for slot: StringName in ItemDB.SLOTS:
		var current: Dictionary = equipment.get(slot, {})
		if not current.is_empty() and current == item:
			equipped_slot = slot
			break
	if value<=0 or (index<0 and equipped_slot==&""): return false
	if equipped_slot!=&"":
		equipment[equipped_slot] = {}
	else:
		items.remove_at(index)
	for i in potion_hotbar.size():
		if potion_hotbar[i].get("uid","")==item.get("uid",""): potion_hotbar[i]={}
	if ItemDB.is_relic(item):
		var relic_id:=str(item.get("id",""))
		run_refreshes[relic_id]=maxi(0,int(run_refreshes.get(relic_id,0))-1)
	add_coins(value)
	_after_equipment_change()
	EventBus.hotbar_changed.emit()
	Outpost.request_checkpoint()
	return true

func drop_item(item: Dictionary) -> bool:
	if not items.has(item) or not is_instance_valid(runtime_node): return false
	items.erase(item)
	for i in potion_hotbar.size():
		if potion_hotbar[i].get("uid","")==item.get("uid",""): potion_hotbar[i]={}
	runtime_node.drop_inventory_item(item)
	_after_equipment_change()
	EventBus.hotbar_changed.emit()
	Outpost.request_checkpoint()
	return true


func has_item(id: StringName) -> bool:
	for item in items:
		if item["id"] == id:
			return true
	return false

func bind_inventory_equipment(item:Dictionary)->bool:
	if CampSession.active or not run_active:return false
	var actual:Dictionary={}
	for candidate in items:
		if candidate==item:actual=candidate;break
	var fee:=BoundEquipment.binding_price(actual)
	if actual.is_empty() or fee<=0 or coins<fee:return false
	var had_flag:=actual.has("bound");var old_flag:Variant=actual.get("bound",false);var money:=coins
	actual.bound=true;coins-=fee
	if not SaveService.save_run(snapshot()):
		if had_flag:actual.bound=old_flag
		else:actual.erase("bound")
		coins=money;return false
	EventBus.coins_changed.emit(coins);Outpost.request_checkpoint();return true


## ---------------- 雇佣单位（酒馆） ----------------
## 只在"本局"存在：死亡即消失，不能复活。
var hired: Array[Dictionary] = []


func add_hired(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	if not entry.has("hire_wave"):entry["hire_wave"]=maxi(1,wave)
	hired.append(entry)
	EventBus.hired_changed.emit()


func remove_hired(uid: String) -> void:
	for i in hired.size():
		if str(hired[i].get("uid", "")) == uid:
			hired.remove_at(i)
			EventBus.hired_changed.emit()
			return


func ally_bonus() -> Dictionary:
	## 召唤师饰品 / 遗物给的加成（为后续"召唤师"角色铺路）：hp / attack / speed 三个乘区
	var bonus := {"hp": 1.0, "attack": 1.0, "speed": 1.0}
	for item in items:
		if not ItemDB.is_equippable(item):
			_merge_summon_bonus(bonus, item)
	for slot: StringName in ItemDB.SLOTS:
		var equipped: Dictionary = equipment.get(slot, {})
		if not equipped.is_empty():
			_merge_summon_bonus(bonus, equipped)
	return bonus


func _merge_summon_bonus(bonus: Dictionary, item: Dictionary) -> void:
	var boost: Dictionary = item.get("summon", {})
	for key in boost:
		bonus[key] = float(bonus.get(key, 1.0)) + float(boost[key])


func remove_item(id: StringName) -> bool:
	## 卖掉 / 丢弃：从背包移除；遗物的被动属性会跟着重算掉
	for i in items.size():
		if items[i]["id"] != id:
			continue
		var item: Dictionary = items[i]
		if ItemDB.is_equippable(item) and is_equipped(item):
			equipment[ItemDB.slot_of(item)] = {}
		items.remove_at(i)
		_after_equipment_change()
		return true
	return false


func add_coins(amount: int) -> void:
	if amount == 0:
		return
	coins = maxi(0, coins + amount)
	EventBus.coins_changed.emit(coins)
	Outpost.request_checkpoint()

## Apply the expedition multiplier only to earned cash rewards. Carried
## money, item sales and refunds still use the exact transfer amount.
func add_reward_coins(amount:int)->int:
	var earned:=maxi(0,amount)*RunDifficulty.gold_multiplier(difficulty)
	if run_active and not CampSession.active and RoomInput.using_auto():
		var halves:=earned+auto_coin_remainder
		earned=floori(halves/2.0);auto_coin_remainder=posmod(halves,2)
	add_coins(earned)
	if GameState.run_active and not CampSession.active:AchievementTracker.add("gold",earned)
	return earned


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	EventBus.coins_changed.emit(coins)
	Outpost.request_checkpoint()
	return true


func add_keys(amount: int) -> void:
	if amount == 0:
		return
	keys = maxi(0, keys + amount)
	EventBus.keys_changed.emit(keys)


func spend_key() -> bool:
	if keys <= 0:
		return false
	keys -= 1
	EventBus.keys_changed.emit(keys)
	return true


## ---------------- 装备 ----------------

func equipped(slot: StringName) -> Dictionary:
	return equipment.get(slot, {})


func equip(item: Dictionary) -> bool:
	## 把背包里的东西装到对应槽位。
	## 每个槽位只有一件 —— 再装一件，旧的会自动退回背包（武器因此只能带一把）。
	var slot := ItemDB.slot_of(item)
	if slot == &"" or not ItemDB.can_equip(item):
		return false
	# 按 id 找背包里那一件（同名道具不会装错）
	var index := -1
	for i in items.size():
		if items[i] == item:
			index = i
			break
	if index < 0:
		return false
	var previous: Dictionary = equipment.get(slot, {})
	if not previous.is_empty():
		items.append(previous)
	items.remove_at(index)
	equipment[slot] = item
	_after_equipment_change()
	return true


func unequip(slot: StringName) -> bool:
	var item: Dictionary = equipment.get(slot,{})
	if item.is_empty() or not can_add_item(item): return false
	equipment[slot]={}
	items.append(item)
	_after_equipment_change()
	return true


func is_equipped(item: Dictionary) -> bool:
	for slot: StringName in ItemDB.SLOTS:
		var current: Dictionary = equipment.get(slot, {})
		if not current.is_empty() and current == item:
			return true
	return false


func _clear_equipment() -> void:
	equipment.clear()
	for slot: StringName in ItemDB.SLOTS:
		equipment[slot] = {}


func _after_equipment_change() -> void:
	# 重算属性；player_stats_changed 会让玩家自己同步最大生命、血条也会刷新
	LegendarySets.observe()
	_reset_stats()
	EventBus.equipment_changed.emit()
	EventBus.player_stats_changed.emit()
	Outpost.request_checkpoint()


func _reset_stats() -> void:
	stats.clear()
	for key: StringName in BASE_STATS:
		stats.set_base(key, UnitBalance.player_base(key,float(BASE_STATS[key])))
	# 被动遗物
	for item in items:
		if not ItemDB.is_equippable(item):
			_apply_item_to_stats(item)
	# 装备栏
	for slot: StringName in ItemDB.SLOTS:
		var item: Dictionary = equipment.get(slot, {})
		if not item.is_empty():
			_apply_item_to_stats(item)
	_apply_progression_to(stats)
	LegendarySets.apply_to(stats)
	_apply_lifesteal_sources(stats)


func _apply_progression_to(target: StatBlock, ranks: Variant = null) -> void:
	AltarBlessings.apply_to(target,altar_blessings)
	FateCatalog.apply_stats(target)
	# 等级成长
	var levels := float(maxi(0, level - 1))
	if levels > 0.0:
		target.add_flat(&"max_hp", HP_PER_LEVEL * levels)
		target.add_flat(&"attack", ATK_PER_LEVEL * levels)
	# 焰心：基础攻击力 +6%/级
	var power := talent_effect(&"power", "攻击加成%", ranks) / 6.0
	if power > 0:
		target.add_mult(&"attack", 0.06 * float(power))
	# 限时增益
	for buff in temp_buffs:
		if StringName(buff["stat"]) != &"lifesteal": target.add_mult(buff["stat"], buff["value"])


## ---------------- 药剂 / 限时增益 ----------------

func use_item(item: Dictionary) -> bool:
	## 在背包里点「使用」：一次性消耗品（目前只有药剂）
	if not ItemDB.is_usable(item):
		return false
	var index := -1
	for i in items.size():
		if items[i] == item:
			index = i
			break
	if index < 0:
		return false
	var effect: Dictionary = item.get("effect", {})
	var kind := String(effect.get("kind", ""))
	if kind == "heal":
		var player_node := player
		if player_node == null or not is_instance_valid(player_node):
			return false
		player_node.heal_player(float(effect.get("amount", 0.0)))
		Effects.text(player_node.get_parent(), player_node.global_position + Vector2(0.0, -50.0),
			"回复 %d" % int(effect.get("amount", 0.0)), Palette.UI_GOOD, 22)
	elif kind == "mana":
		add_mp(float(effect.get("amount", 0.0)))
		var node := player
		if node != null and is_instance_valid(node):
			Effects.text(node.get_parent(), node.global_position + Vector2(0.0, -50.0),
				"魔法 +%d" % int(effect.get("amount", 0.0)), Color("8fd3ff"), 22)
	elif kind == "buff":
		add_temp_buff(
			StringName(effect.get("stat", &"attack")),
			float(effect.get("value", 0.0)),
			float(effect.get("duration", 10.0)),
			str(item["name"])
		)
	else:
		return false
	items.remove_at(index)
	for hotbar_index in potion_hotbar.size():
		if potion_hotbar[hotbar_index] == item:
			potion_hotbar[hotbar_index] = {}
			for replacement in items:
				if replacement["id"] == item["id"]: potion_hotbar[hotbar_index] = replacement; break
	EventBus.hotbar_changed.emit()
	Outpost.request_checkpoint()
	if is_instance_valid(player):
		player.play_action_feedback(&"heal" if kind == "heal" else &"interact", 0.4)
	EventBus.item_acquired.emit(item)
	_reset_stats()
	EventBus.player_stats_changed.emit()
	return true


func add_temp_buff(stat: StringName, value: float, duration: float, label: String, source:String="") -> void:
	## 同一种属性的限时增益会被刷新（取更长的剩余时间），不会叠成一堆
	for buff in temp_buffs:
		if buff["stat"] == stat and str(buff.get("source",""))==source:
			buff["value"] = value
			buff["remaining"] = maxf(float(buff["remaining"]), duration)
			buff["label"] = label
			_reset_stats()
			EventBus.player_stats_changed.emit()
			return
	temp_buffs.append({"stat": stat, "value": value, "remaining": duration, "label": label,"source":source})
	_reset_stats()
	EventBus.player_stats_changed.emit()


func total_mp_regen(block: StatBlock = null) -> float:
	var target := stats if block == null else block
	var holder:Player=target.status_owner.get_ref() as Player if target.status_owner!=null else null
	var factor := PlayerDebuffs.multiplier(holder,&"mp_regen")
	return (target.get_value(&"mp_regen") + talent_effect(&"arcane_reserve", "每秒额外回蓝") * factor)*FateCatalog.regen_factor()

func _process(delta: float) -> void:
	# 基础回蓝 3/秒，由魔力流转增强。
	if (run_active or CampSession.active) and mp < MAX_MP:
		mp = minf(MAX_MP, mp + total_mp_regen() * delta)
		EventBus.mp_changed.emit(mp, MAX_MP)
	# 冷却跟随技能本身，换栏或换大招不会重置。
	for id in skill_cooldowns_by_id:
		skill_cooldowns_by_id[id] = maxf(0.0, float(skill_cooldowns_by_id[id]) - delta)
	_sync_skill_cooldowns()
	if temp_buffs.is_empty():
		return
	var expired := false
	for i in range(temp_buffs.size() - 1, -1, -1):
		temp_buffs[i]["remaining"] = float(temp_buffs[i]["remaining"]) - delta
		if float(temp_buffs[i]["remaining"]) <= 0.0:
			temp_buffs.remove_at(i)
			expired = true
	if expired:
		_reset_stats()
		EventBus.player_stats_changed.emit()


func _apply_item_to_stats(item: Dictionary) -> void:
	for key: StringName in item.get("flat", {}):
		if key != &"lifesteal": stats.add_flat(key, item["flat"][key])
	for key: StringName in item.get("mult", {}):
		if key != &"lifesteal": stats.add_mult(key, item["mult"][key])


func preview_with(item: Dictionary) -> StatBlock:
	## 预演：把 item 装上去之后各项属性会变成多少（背包详情面板拿来做对比）。
	## 同一槽位的旧装备会被顶掉，所以计算时跳过那个槽位，才是真实的替换结果。
	var slot := ItemDB.slot_of(item)
	var preview := StatBlock.new()
	preview.status_owner = stats.status_owner
	for key: StringName in BASE_STATS:
		preview.set_base(key, UnitBalance.player_base(key,float(BASE_STATS[key])))
	for owned in items:
		if not ItemDB.is_equippable(owned):
			_apply_to(preview, owned)
	for equip_slot: StringName in ItemDB.SLOTS:
		if equip_slot == slot:
			continue
		var current: Dictionary = equipment.get(equip_slot, {})
		if not current.is_empty():
			_apply_to(preview, current)
	_apply_to(preview, item)
	var preview_equipment:=equipment.duplicate(true);preview_equipment[slot]=item;LegendarySets.apply_to(preview,preview_equipment)
	_apply_progression_to(preview)
	_apply_lifesteal_sources(preview, item)
	return preview


## ---------------- 存档快照 ----------------

func snapshot() -> Dictionary:
	## 只存「读档后能接着玩」的必要信息。
	## 道具/装备按 id 存，读档时再从 ItemDB 取回完整定义 ——
	## 这样以后改了道具数值，老存档也不会带着过期数据。
	var item_ids: Array = []
	for item in items:
		item_ids.append(String(item["id"]))
	var equip_ids := {}
	for slot: StringName in ItemDB.SLOTS:
		var equipped_item: Dictionary = equipment.get(slot, {})
		equip_ids[String(slot)] = String(equipped_item["id"]) if not equipped_item.is_empty() else ""
	var hp_ratio := 1.0
	var player_node := player
	if player_node != null and is_instance_valid(player_node) and max_hp_value() > 0.0:
		hp_ratio = clampf(float(player_node.hp) / maxf(1.0, max_hp_value()), 0.0, 1.0)
	var live_hires:Dictionary={}
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally.has_method("hire_snapshot") and not ally.is_queued_for_deletion():
			live_hires[str(ally.get("uid"))]=ally.hire_snapshot()
	var hire_records:Array[Dictionary]=[]
	for entry in hired:
		var record:=entry.duplicate(true)
		var uid:=str(record.get("uid",""))
		if not uid.is_empty() and live_hires.has(uid):record.merge(live_hires[uid],true)
		if float(record.get("hp_ratio",1.0))>0:hire_records.append(record)
	return {
		"combat_mode":combat_mode,
		"passive_id":str(passive_id),"passive_rng_state":str(passive_rng.state),
		"sortie_id":sortie_id,"danger":danger,"difficulty":difficulty,"item_sequence":item_sequence,
		"expedition_items":items.map(func(i:Dictionary)->Dictionary:return ExpeditionData.pack(i)),
		"expedition_equipment":equipment.values().filter(func(i:Dictionary)->bool:return not i.is_empty()).map(func(i:Dictionary)->Dictionary:return ExpeditionData.pack(i)),
		"world_state":runtime_node.snapshot() if is_instance_valid(runtime_node) else {},
		"run_loot": run_loot.duplicate(),
		"material_ledger":material_ledger.duplicate(true),
		"build_stats":build_stats.duplicate(true),
		"run_refreshes": run_refreshes.duplicate(),
		"loot_history_complete": loot_history_complete,
		"kit_version": 2,
		"map_version": RoomGraph.VERSION,
		"environment": player.level.environment_snapshot() if is_instance_valid(player) and player.level != null else {},
		"level": level, "exp": exp, "talent_points": talent_points,
		"talents": talents.duplicate(), "mp": mp,
		"unlocked_skills": unlocked_skills.duplicate(), "learned_skills": learned_skills.duplicate(),
		"ultimate_skill": String(ultimate_skill), "skill_cooldowns": skill_cooldowns_by_id.duplicate(),
		"temp_buffs": temp_buffs.duplicate(true),
		"altar_blessings":altar_blessings.duplicate(true),
		"fate":fate.duplicate(true),
		"legendary_looks":legendary_looks.duplicate(true),
		"gm_pilot_used":gm_pilot_used,"gm_pilot_active":gm_pilot_active,
		"achievement_run":achievement_run.duplicate(true),
		"wave_exp_multiplier":wave_exp_multiplier,
		"hotbar": potion_hotbar.map(func(item: Dictionary) -> String: return str(item.get("id", ""))),
		"hired": hire_records,
		"character": String(Characters.current_id()),
		"wave": wave,
		"pacing_version": 1,
		"active_play_seconds": active_play_seconds,
		"first_chapter_seconds": first_chapter_seconds,
		"wave_completed": wave_completed,
		"wave_exp_awarded": wave_exp_awarded,
		"chapter_id":str(chapter_id),
		"chapter_cleared": chapter_cleared,
		"endless_mode": endless_mode,
		"coins": coins,
		"auto_coin_remainder":auto_coin_remainder,
		"keys": keys,
		"items": item_ids,
		"equipment": equip_ids,
		"hp_ratio": hp_ratio,
	}


func max_hp_value() -> float:
	return stats.get_value(&"max_hp") if stats != null else 100.0


func restore(snapshot_data: Dictionary) -> void:
	build_stats=RunBuildMetrics.normalize(snapshot_data.get("build_stats"))
	achievement_run=snapshot_data.get("achievement_run",{}).duplicate(true)
	legendary_looks=snapshot_data.get("legendary_looks",{}).duplicate(true)
	gm_pilot_used=bool(snapshot_data.get("gm_pilot_used",false));gm_pilot_active=gm_pilot_used and bool(snapshot_data.get("gm_pilot_active",false))
	altar_blessings=AltarBlessings.normalized(snapshot_data.get("altar_blessings",{}))
	fate=FateCatalog.normalize(snapshot_data.get("fate",{}))
	wave_exp_multiplier=clampf(float(snapshot_data.get("wave_exp_multiplier",1)),.6,1)
	Characters.set_current(StringName(snapshot_data.get("character", String(Characters.DEFAULT_ID))))
	combat_mode = "rooms"
	passive_id = PassiveDefinitions.migrate_id(StringName(snapshot_data.get("passive_id", PassiveDefinitions.default_for(Characters.current_id()))))
	var valid_passive:=false
	for definition:Dictionary in PassiveDefinitions.for_character(Characters.current_id()):
		if definition.id==passive_id:valid_passive=true
	if not valid_passive:passive_id=PassiveDefinitions.default_for(Characters.current_id())
	PassiveDefinitions.select(Characters.current_id(),passive_id,false)
	passive_rng.state = int(snapshot_data.get("passive_rng_state", hash(str(snapshot_data.get("sortie_id",""))+":passive")))
	sortie_id=str(snapshot_data.get("sortie_id",""))
	difficulty=RunDifficulty.from_record(snapshot_data)
	item_sequence=int(snapshot_data.get("item_sequence",0))
	run_epoch += 1
	run_loot.clear();material_ledger.clear()
	run_refreshes.clear()
	material_ledger=snapshot_data.get("material_ledger",{}).duplicate(true) if snapshot_data.get("material_ledger",{}) is Dictionary else {}
	var saved_loot: Variant = snapshot_data.get("run_loot", {})
	loot_history_complete = bool(snapshot_data.get("loot_history_complete", false)) and saved_loot is Dictionary
	if saved_loot is Dictionary:
		for key in saved_loot:
			run_loot[str(key)] = maxi(0, int(saved_loot[key]))
	var saved_refreshes: Variant = snapshot_data.get("run_refreshes", {})
	if saved_refreshes is Dictionary:
		for key in saved_refreshes:
			run_refreshes[str(key)] = clampi(int(saved_refreshes[key]), 0, 3)
	# Older saves know acquisitions but did not record declined offers.
	for key in run_loot:
		if not run_refreshes.has(str(key)):
			run_refreshes[str(key)] = mini(3, int(run_loot[key]))
	chapter_id=ChapterCatalog.normalize(snapshot_data.get("chapter_id",ChapterCatalog.FIRST))
	chapter_cleared = bool(snapshot_data.get("chapter_cleared", false))
	endless_mode = bool(snapshot_data.get("endless_mode", false))
	items.clear()
	level = clampi(int(snapshot_data.get("level", 1)), 1, MAX_LEVEL)
	exp = maxf(0.0, float(snapshot_data.get("exp", 0.0)))
	talent_points = maxi(0, int(snapshot_data.get("talent_points", 1 + int(level / 3))))
	talents.clear()
	var saved_talents: Dictionary = snapshot_data.get("talents", {})
	if Characters.current_id()==&"sylphiette":
		var migrated:=HolyTalents.migrate(saved_talents);saved_talents=migrated.talents;talent_points+=int(migrated.refund)
	for key in saved_talents:
		var id := StringName(key)
		var rank := maxi(0, int(saved_talents[key]))
		if TALENT_BRANCHES.has(id):
			var max_rank := int(TALENT_BRANCHES[id].max_rank)
			talents[id] = mini(rank, max_rank)
			talent_points += maxi(0, rank - max_rank)
		else:
			talent_points += rank
	mp = clampf(float(snapshot_data.get("mp", MAX_MP)), 0, MAX_MP)
	temp_buffs.clear()
	for buff in snapshot_data.get("temp_buffs", []):
		if buff is Dictionary and buff.has("stat") and float(buff.get("remaining", 0)) > 0:
			temp_buffs.append(buff.duplicate())
	learned_skills.clear()
	unlocked_skills.clear()
	pending_skills.clear()
	ultimate_skill = &""
	skill_cooldowns_by_id.clear()
	for id in Skills.order_for():
		if Skills.unlock_level(id) <= level:
			_learn_skill(id)
	for key in snapshot_data.get("unlocked_skills", []):
		_learn_skill(StringName(key))
	if snapshot_data.has("learned_skills"):
		learned_skills.clear()
		for key in (snapshot_data.get("learned_skills", []) as Array).slice(0, SKILL_SLOTS):
			var id := StringName(key)
			learned_skills.append(id if unlocked_skills.has(id) and not Skills.is_ultimate(id) and not learned_skills.has(id) else &"")
	var saved_ultimate := StringName(snapshot_data.get("ultimate_skill", str(ultimate_skill)))
	if unlocked_skills.has(saved_ultimate) and Skills.is_ultimate(saved_ultimate):
		ultimate_skill = saved_ultimate
	var saved_cd: Dictionary = snapshot_data.get("skill_cooldowns", {})
	for key in saved_cd:
		var id := StringName(key)
		if Skills.DATA.has(id):
			skill_cooldowns_by_id[id] = maxf(0, float(saved_cd[key]))
	_sync_skill_cooldowns()
	hired.clear()
	for ally in snapshot_data.get("hired", []):
		if ally is Dictionary and float(ally.get("hp_ratio",1.0))>0.0:
			hired.append(ally.duplicate(true))
	_clear_equipment()
	coins = int(snapshot_data.get("coins", 0))
	auto_coin_remainder=clampi(int(snapshot_data.get("auto_coin_remainder",0)),0,1)
	keys = int(snapshot_data.get("keys", 0))
	wave = maxi(1,int(snapshot_data.get("wave", 1)))
	active_play_seconds = _saved_seconds(snapshot_data.get("active_play_seconds",0.0))
	var saved_chapter:Variant = snapshot_data.get("first_chapter_seconds",-1.0)
	first_chapter_seconds = _saved_seconds(saved_chapter,-1.0) if (saved_chapter is float or saved_chapter is int) and float(saved_chapter)>=0.0 else -1.0
	# 旧版波间存档保持休整入口；新版手动保存未完成波次不会跳过敌人。
	wave_completed = bool(snapshot_data.get("wave_completed",wave<30 or endless_mode))
	if wave==30 and not chapter_cleared and not snapshot_data.has("world_state"):wave_completed=false
	wave_exp_awarded = clampf(_saved_seconds(snapshot_data.get("wave_exp_awarded",0.0)),0.0,WaveTable.experience_pool(wave))
	play_time_changed.emit(int(active_play_seconds))
	run_active = true
	Characters.set_current(StringName(snapshot_data.get("character", String(Characters.DEFAULT_ID))))
	for id in snapshot_data.get("items", []):
		var item := ItemDB.by_id(StringName(id))
		if not item.is_empty():
			items.append(item)
	var equip: Dictionary = snapshot_data.get("equipment", {})
	for slot: StringName in ItemDB.SLOTS:
		var id := String(equip.get(String(slot), ""))
		if id.is_empty():
			continue
		var item := ItemDB.by_id(StringName(id))
		if not item.is_empty():
			equipment[slot] = item
	if snapshot_data.has("expedition_items"):
		items.clear()
		for record in snapshot_data.expedition_items:
			var decoded := ExpeditionData.unpack(record)
			if not decoded.is_empty(): items.append(decoded)
		_clear_equipment()
		for record in snapshot_data.get("expedition_equipment",[]):
			var decoded := ExpeditionData.unpack(record)
			if not decoded.is_empty(): equipment[ItemDB.slot_of(decoded)]=decoded
	# Old saves without offer history still respect relics already in the bag.
	LegendarySets.observe()
	var held_relics: Dictionary = {}
	for held in items:
		if ItemDB.is_relic(held):
			var relic_id := str(held.get("id", ""))
			held_relics[relic_id] = int(held_relics.get(relic_id, 0)) + 1
	for relic_id in held_relics:
		run_refreshes[relic_id] = mini(3, maxi(int(run_refreshes.get(relic_id, 0)), int(held_relics[relic_id])))
	potion_hotbar = [{}, {}, {}]
	var bar: Array = snapshot_data.get("hotbar", [])
	for index in mini(HOTBAR_SIZE, bar.size()):
		for item in items:
			if str(item.get("id", "")) == str(bar[index]) and ItemDB.is_usable(item):
				potion_hotbar[index] = item
				break
	_reset_stats()
	EventBus.coins_changed.emit(coins)
	EventBus.keys_changed.emit(keys)
	EventBus.equipment_changed.emit()
	EventBus.player_stats_changed.emit()
	EventBus.skills_changed.emit()
	EventBus.talents_changed.emit()
	EventBus.level_changed.emit(level, 0)
	EventBus.mp_changed.emit(mp, MAX_MP)
	EventBus.hotbar_changed.emit()


func _apply_to(target: StatBlock, item: Dictionary) -> void:
	for key: StringName in item.get("flat", {}):
		if key != &"lifesteal": target.add_flat(key, item["flat"][key])
	for key: StringName in item.get("mult", {}):
		if key != &"lifesteal": target.add_mult(key, item["mult"][key])


func _apply_lifesteal_sources(target: StatBlock, candidate: Dictionary = {}) -> void:
	# Only these IDs grant healing. Duplicate relics retain all other effects.
	var sources: Dictionary = {}
	for item in items:
		if StringName(item.get("id", "")) in [&"blood_charm", &"phoenix_heart"]:
			sources[StringName(item.id)] = true
	if StringName(candidate.get("id", "")) in [&"blood_charm", &"phoenix_heart"]:
		sources[StringName(candidate.id)] = true
	var accessory: Dictionary = candidate if ItemDB.slot_of(candidate) == &"accessory" else equipped(&"accessory")
	if StringName(accessory.get("id", "")) == &"life_ampoule": sources[&"life_ampoule"] = true
	target.set_base(&"lifesteal", float(sources.size()))
