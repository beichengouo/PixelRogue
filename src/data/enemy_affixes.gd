class_name EnemyAffixes
extends RefCounted
## 精英怪词条：波次越高，怪物越可能带词条（带词条 = 精英）。
##
## 每条词条有「危险度」1~3，**危险度总和决定身上那圈光的颜色**：
##   1~2 白蓝 · 3~4 紫 · 5+ 金红
## 词条分三类，作用在 EnemyBase 的钩子里（见 _update_affixes / take_damage）：
##   攻击类：瞬移、远程、死亡爆炸
##   防御类：免疫普攻、护甲、再生
## 想加词条：往 POOL 里加一条，再在 EnemyBase 里加对应处理即可。

const TELEPORT := &"teleport"
const RANGED := &"ranged"
const DEATH_BOMB := &"death_bomb"
const IMMUNE_BASIC := &"immune_basic"
const ARMORED := &"armored"
const REGEN := &"regen"
const HASTE := &"haste"
const PERCENT_DAMAGE := &"percent_damage"
const SPLIT := &"split"
const PERCENT_TAKEN := &"percent_taken"
const FRONT_GUARD := &"front_guard"
const WAR_BANNER := &"war_banner"
const MEND_CHANT := &"mend_chant"
const HUNTER_LOCK := &"hunter_lock"
const SHOCK_RING := &"shock_ring"
const VINE_SNARE := &"vine_snare"
const ECHO_STRIKE := &"echo_strike"
const FIRE_TRAIL := &"fire_trail"
const ENRAGE := &"enrage"
const DEVOUR := &"devour"
const GUARDIAN := &"guardian"
const EMBER_GRAVE := &"ember_grave"
const VENOM_EDGE := &"venom_edge"
const EMBER_TOUCH := &"ember_touch"
const FROSTBITE := &"frostbite"
const HOLLOW_CURSE := &"hollow_curse"
const LEADEN_STRIKE := &"leaden_strike"
const MANA_DROUGHT := &"mana_drought"
const CRUEL := &"cruel"
const HEAL_SEAL:=&"heal_seal"
const MANA_LEECH:=&"mana_leech"
const SPELL_DELAY:=&"spell_delay"
const MIRROR_SHELL:=&"mirror_shell"
const DEBUFF_POOL: Array[StringName] = [VENOM_EDGE,EMBER_TOUCH,FROSTBITE,HOLLOW_CURSE,LEADEN_STRIKE,MANA_DROUGHT,HEAL_SEAL,MANA_LEECH,SPELL_DELAY]
const DEBUFF_UNLOCK := {VENOM_EDGE:6,EMBER_TOUCH:6,FROSTBITE:6,HOLLOW_CURSE:11,LEADEN_STRIKE:11,MANA_DROUGHT:11,HEAL_SEAL:11,MANA_LEECH:11,SPELL_DELAY:16}

const NEW_POOL: Array[StringName] = [FRONT_GUARD,WAR_BANNER,MEND_CHANT,HUNTER_LOCK,SHOCK_RING,VINE_SNARE,ECHO_STRIKE,FIRE_TRAIL,ENRAGE,DEVOUR,GUARDIAN,EMBER_GRAVE,MIRROR_SHELL]
const DEFENSE: Array[StringName] = [IMMUNE_BASIC,ARMORED,REGEN,PERCENT_TAKEN,FRONT_GUARD,DEVOUR,MIRROR_SHELL]
const SUPPORT: Array[StringName] = [WAR_BANNER,MEND_CHANT,DEVOUR,GUARDIAN]
const ACTIVE_WARNING: Array[StringName] = [MEND_CHANT,HUNTER_LOCK,SHOCK_RING,VINE_SNARE,ENRAGE,GUARDIAN]

const POOL: Array[StringName] = [
	TELEPORT, RANGED, DEATH_BOMB, IMMUNE_BASIC, ARMORED, REGEN, HASTE,
	PERCENT_DAMAGE, SPLIT, PERCENT_TAKEN,
	FRONT_GUARD,WAR_BANNER,MEND_CHANT,HUNTER_LOCK,SHOCK_RING,VINE_SNARE,
	ECHO_STRIKE,FIRE_TRAIL,ENRAGE,DEVOUR,GUARDIAN,EMBER_GRAVE,
	VENOM_EDGE,EMBER_TOUCH,FROSTBITE,HOLLOW_CURSE,LEADEN_STRIKE,MANA_DROUGHT,
	HEAL_SEAL,MANA_LEECH,SPELL_DELAY,MIRROR_SHELL,
]

const INFO := {
	HEAL_SEAL:{"name":"封疗","danger":2,"desc":"实际伤及玩家生命后，使其受到的治疗降低40%，持续4秒；护盾挡住时不施加"},
	MANA_LEECH:{"name":"噬魔","danger":2,"desc":"实际伤及玩家生命后，3秒内每秒吸走2MP；同类刷新时长，不叠层"},
	SPELL_DELAY:{"name":"迟咒","danger":2,"desc":"实际伤及玩家生命后，4秒内新施放小技能的冷却增加15%；不影响大招及已开始的冷却"},
	MIRROR_SHELL:{"name":"镜壳","danger":2,"desc":"承受三次有效普攻或小技能直击后，获得10%最大生命护盾3秒，冷却6秒；持续及衍生伤害不计数"},
	CRUEL: {"name":"残忍","danger":3,"desc":"仅特殊敌人持有：对玩家造成无视护盾与分担的真实伤害，并永久削减本次出征的生命上限"},
	TELEPORT: {"name": "瞬移", "danger": 2, "desc": "每5秒预告裂隙，0.45秒后闪现至玩家附近3～5格的合法地面；落点受阻时取消"},
	RANGED: {"name": "远程", "danger": 2, "desc": "会朝你发射弹丸"},
	DEATH_BOMB: {"name": "死亡爆炸", "danger": 2, "desc": "倒下时会炸开一圈"},
	IMMUNE_BASIC: {"name": "免疫普攻", "danger": 3, "desc": "有概率免疫普通攻击，技能能稳定打伤它"},
	ARMORED: {"name": "护甲", "danger": 2, "desc": "受到的伤害降低三成"},
	REGEN: {"name": "再生", "danger": 1, "desc": "会缓慢回血"},
	HASTE: {"name": "迅捷", "danger": 1, "desc": "移动更快"},
	PERCENT_DAMAGE: {"name": "重创", "danger": 3, "desc": "攻击附带你最大生命值百分比的伤害，堆血也扛不住"},
	SPLIT: {"name": "分裂", "danger": 3, "desc": "倒下时分裂出两只小怪（小怪不会再分裂）"},
	PERCENT_TAKEN: {"name": "百分比承受", "danger": 3, "desc": "受到的伤害改成按它自身最大生命值的百分比结算，堆输出也磨得慢"},
	FRONT_GUARD: {"name":"迎锋","danger":2,"desc":"正面直击减伤，出手后短暂破绽"},
	WAR_BANNER: {"name":"战旗","danger":2,"desc":"增强周围其他敌人的攻击"},
	MEND_CHANT: {"name":"疗祷","danger":2,"desc":"吟唱治疗附近受伤最重的同伴"},
	HUNTER_LOCK: {"name":"锁猎","danger":2,"desc":"锁定目标后射出三发窄弹"},
	SHOCK_RING: {"name":"震环","danger":2,"desc":"预警后震击环形区域"},
	VINE_SNARE: {"name":"藤缚","danger":2,"desc":"直线藤蔓伤害并减速"},
	ECHO_STRIKE: {"name":"残影","danger":2,"desc":"在原位置重复上一次攻击"},
	FIRE_TRAIL: {"name":"炎径","danger":2,"desc":"移动时留下短暂火径"},
	ENRAGE: {"name":"蓄怒","danger":1,"desc":"低血量时短暂加速后力竭"},
	DEVOUR: {"name":"吞骸","danger":2,"desc":"附近同伴死亡时获得护盾"},
	GUARDIAN: {"name":"护卫","danger":3,"desc":"召唤两名弱化护卫"},
	EMBER_GRAVE: {"name":"余烬墓","danger":2,"desc":"死亡后留下短暂燃烧区域"},
	VENOM_EDGE: {"name":"毒牙","danger":2,"desc":"穿过护盾的攻击施加4秒中毒，每秒造成攻击力8%的伤害；同类刷新不叠层"},
	EMBER_TOUCH: {"name":"烙痕","danger":2,"desc":"穿过护盾的攻击施加3秒灼伤，每秒造成攻击力10%的伤害"},
	FROSTBITE: {"name":"霜痕","danger":1,"desc":"穿过护盾的攻击使目标移动速度降低20%，持续3秒"},
	HOLLOW_CURSE: {"name":"蚀锋","danger":2,"desc":"穿过护盾的攻击使目标攻击力降低15%，持续3秒"},
	LEADEN_STRIKE: {"name":"沉腕","danger":2,"desc":"穿过护盾的攻击使目标攻击速度降低20%，持续3秒"},
	MANA_DROUGHT: {"name":"枯魔","danger":2,"desc":"穿过护盾的攻击使目标MP回复速度降低35%，持续4秒"},
}


static func name_of(id: StringName) -> String:
	return str((INFO.get(id, {}) as Dictionary).get("name", str(id)))


static func danger_of(id: StringName) -> int:
	return int((INFO.get(id, {}) as Dictionary).get("danger", 1))


static func danger_color(danger: int) -> Color:
	if danger >= 5:
		return Color("ff7a4d")
	if danger >= 3:
		return Color("c07bff")
	return Color("8fd0ff")


static func roll_for_wave(wave: int, rng: RandomNumberGenerator, guaranteed:=false, excluded:Array[StringName]=[], difficulty:int=1) -> Array[StringName]:
	var policy := WaveTable.elite_policy(wave)
	var out: Array[StringName] = []
	if rng.randf() >= RunDifficulty.affix_chance(float(policy.chance),difficulty) and not guaranteed:return out
	var count := 1
	while count<int(policy.max) and rng.randf()<0.42:count+=1
	var pool := POOL.duplicate()
	for id in excluded:pool.erase(id)
	# 教学期间先学会处理机动与攻击词条；防御挑战在技能齐备后加入。
	if wave<=5:
		pool.erase(IMMUNE_BASIC)
		pool.erase(REGEN)
	if wave<=10:pool.erase(PERCENT_DAMAGE)
	# 百分比判定留给无尽变体；第一章保持常规伤害规则。
	if wave<=30:pool.erase(PERCENT_TAKEN)
	for id in NEW_POOL:
		if wave < 4 or (wave < 6 and id not in [ENRAGE,HUNTER_LOCK]) or (wave < 11 and id not in [ENRAGE,HUNTER_LOCK,FRONT_GUARD,WAR_BANNER,SHOCK_RING,FIRE_TRAIL]):pool.erase(id)
	for id in DEBUFF_POOL:
		if wave<int(DEBUFF_UNLOCK[id]):pool.erase(id)
	if wave<11:pool.erase(MIRROR_SHELL)
	while out.size()<count and not pool.is_empty():
		var pick := rng.randi_range(0,pool.size()-1)
		var id:StringName = pool[pick]
		if not compatible(out,id):
			pool.remove_at(pick)
			continue
		out.append(id)
		pool.remove_at(pick)
	return out

static func compatible(existing:Array[StringName],id:StringName)->bool:
	if id in DEBUFF_POOL and existing.any(func(item:StringName)->bool:return item in DEBUFF_POOL):return false
	if id in DEFENSE and existing.any(func(item:StringName)->bool:return item in DEFENSE):return false
	if id in SUPPORT and existing.any(func(item:StringName)->bool:return item in SUPPORT):return false
	if id in ACTIVE_WARNING and existing.any(func(item:StringName)->bool:return item in ACTIVE_WARNING):return false
	if id==HUNTER_LOCK and existing.has(RANGED) or id==RANGED and existing.has(HUNTER_LOCK):return false
	if id==EMBER_GRAVE and (existing.has(DEATH_BOMB) or existing.has(SPLIT)):return false
	if id in [DEATH_BOMB,SPLIT] and existing.has(EMBER_GRAVE):return false
	return true


static func describe(ids: Array[StringName]) -> String:
	var parts: Array[String] = []
	for id in ids:
		parts.append(name_of(id))
	return "·".join(parts)


static func total_danger(ids: Array[StringName]) -> int:
	var sum := 0
	for id in ids:
		sum += danger_of(id)
	return sum
