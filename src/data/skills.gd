class_name Skills
extends RefCounted
## 希露媞雅的火焰 / 自然魔法；普通技能与大招分开配装。
## 原有 id 保留以兼容存档，名称和机制以本表为准。
const SKILL_ICON_DIR := "res://assets/skills/"
const UI_ICON_DIR := "res://assets/pixel_batch3/"
const FRAME_EMPTY := UI_ICON_DIR + "empty.tres"
const FRAME_LOCKED := UI_ICON_DIR + "lock.tres"
const ORDER: Array[StringName] = [&"flame_nova", &"fan_bolts", &"blink", &"meteor", &"flame_shield", &"frost_nova", &"healing_light", &"starfall"]
const MAGE_DATA := {
	&"flame_nova": {"id": &"flame_nova", "name": "烬环震退", "unlock_level": 1, "ultimate": false, "mp": 24.0, "cd": 6.0, "role": "烬火", "desc": "释放半径3格的烬火环，造成0.9×攻击并推退普通怪2格；首领推力为25%。", "icon": "res://assets/pixel_batch3/flame_nova.tres", "effect": {"kind": "repulse", "radius":108.0,"ratio":0.9,"push":72.0}},
	&"fan_bolts": {"id": &"fan_bolts", "name": "绯焰散射", "unlock_level": 5, "ultimate": false, "mp": 24.0, "cd": 7.0, "role": "爆破", "desc": "向瞄准方向散射五枚火球，每枚造成 0.65×攻击力；可附带爆裂与点燃。", "icon": "res://assets/pixel_batch3/fan_bolts.tres", "effect": {"kind": "fan", "shots": 5, "spread_deg": 46.0, "ratio": 0.65, "speed": 470.0}},
	&"blink": {"id": &"blink", "name": "星辉震荡", "unlock_level": 8, "ultimate": false, "mp": 18.0, "cd": 8.0, "role": "星辉", "desc": "周身半径3格星环对敌造成0.9×攻击并减速35%，持续2秒。", "icon": "res://assets/pixel_batch3/blink.tres", "effect": {"kind": "star_pulse", "radius": 108.0, "ratio": 0.9, "slow": 0.35, "slow_duration": 2.0}},
	&"meteor": {"id": &"meteor", "name": "绯星坠落", "unlock_level": 12, "ultimate": true, "mp": 55.0, "cd": 24.0, "role": "爆破", "desc": "短暂预告后，向最近敌人落下一颗炽焰陨星；半径 210 内造成 3.6×攻击力。", "icon": "res://assets/pixel_batch3/meteor.tres", "effect": {"kind": "meteor", "radius": 210.0, "ratio": 3.6, "max_distance": 900.0, "delay": 0.45}},
	&"flame_shield": {"id": &"flame_shield", "name": "烬火护衣", "unlock_level": 15, "ultimate": false, "mp": 26.0, "cd": 16.0, "role": "守护", "desc": "获得可吸收最大生命 18% 伤害的护衣，持续 6 秒；受到攻击时反伤。", "icon": "res://assets/pixel_batch3/flame_shield.tres", "effect": {"kind": "shield", "hp_ratio": 0.18, "duration": 6.0, "thorns": 8.0}},
	&"frost_nova": {"id": &"frost_nova", "name": "藤蔓缠绕", "unlock_level": 18, "ultimate": false, "mp": 28.0, "cd": 10.0, "role": "自然", "desc": "半径 180 内的藤蔓造成 0.9×攻击力，并使敌人减速 60%，持续 3 秒；首领减速较弱。", "icon": "res://assets/pixel_batch3/nature_bind.tres", "effect": {"kind": "snare", "radius": 180.0, "ratio": 0.9, "slow": 0.6, "duration": 3.0}},
	&"healing_light": {"id": &"healing_light", "name": "芽灵祝福", "unlock_level": 22, "ultimate": false, "mp": 32.0, "cd": 16.0, "role": "自然", "desc": "唤醒芽灵，立刻恢复最大生命的 22%；自然天赋可强化治疗并返还魔力。", "icon": "res://assets/pixel_batch3/healing_light.tres", "effect": {"kind": "heal", "hp_ratio": 0.22}},
	&"starfall": {"id": &"starfall", "name": "森罗绽放", "unlock_level": 25, "ultimate": true, "mp": 60.0, "cd": 28.0, "role": "自然", "desc": "展开半径 220、持续 5 秒的领域，立即生效并每 0.75 秒造成 0.45×攻击力伤害，使敌人减速 30%、持续 1 秒；每次脉冲为领域内的自己恢复最大生命的 2%。", "icon": "res://assets/pixel_batch3/nature_bloom.tres", "effect": {"kind": "bloom", "radius": 220.0, "ratio": 0.45, "duration": 5.0, "interval": 0.75, "heal_ratio": 0.02}},
}

static var DATA: Dictionary = _all_data()

static func _all_data()->Dictionary:
	var data:=HolySkills.DATA.duplicate(true);data.merge(SummonerSkills.DATA,true);data.merge(IlyuaSkills.DATA,true);return data

static func order_for(character: StringName = &"")->Array[StringName]:
	var id:=Characters.current_id() if character==&"" else character
	if id==&"xixifu":return SummonerSkills.ORDER
	if id==&"ilyua":return IlyuaSkills.ORDER
	return ORDER

static func get_skill(id: StringName, mode: String = "rooms") -> Dictionary:
	if HolySkills.DATA.has(id):return HolySkills.DATA[id].duplicate(true)
	var original: Dictionary = DATA.get(id, {})
	var new_icon:="res://assets/next_revision/skills/"+str(id)+".png"
	if ResourceLoader.exists(new_icon):
		original=original.duplicate(true);original.icon=new_icon
	if mode != "rooms" or original.is_empty(): return original
	var result := original.duplicate(true)
	var changes := {
		&"flame_nova": {"desc":"释放半径3格的烬火环，造成0.9×攻击并弹开周围敌人；普通怪最多2格，首领四分之一。","effect":{}},
		&"fan_bolts": {"desc":"向瞄准方向46°扇形发射五枚火球，每枚0.65×攻击，射程8格；天赋可附带爆裂与点燃。","effect":{"range":288.0}},
		&"blink": {"desc":"周身半径3格星环对敌造成0.9×攻击并减速35%，持续2秒；轻灵星步可扩大范围。","effect":{}},
		&"meteor": {"desc":"锁定前方6格内地面，预告0.65秒后落下陨星；半径3格，造成3.6×攻击。","effect":{"radius":108.0,"delay":0.65,"max_distance":216.0}},
		&"frost_nova": {"desc":"前方4×2格藤蔓区域持续3秒；敌人首次进入受到0.9×攻击，区域内减速60%，离开后保留0.5秒；首领减速30%。","effect":{"length":144.0,"width":72.0}},
		&"healing_light": {"desc":"立即回复自己22%最大生命，并为3格内友方回复各自11%最大生命；自然天赋可强化并返还魔力。","effect":{"ally_radius":108.0,"ally_ratio":0.11}},
		&"starfall": {"desc":"前方3格生成半径3格、持续5秒的森罗领域；立即及每0.75秒造成0.45×攻击并减速30%，回复自己2%、友方1%最大生命。","effect":{"radius":108.0,"distance":108.0,"ally_ratio":0.01}},
	}
	if changes.has(id):
		result.desc = changes[id].desc
		result.effect.merge(changes[id].effect,true)
	return result

static func unlock_level(id: StringName) -> int:
	return int(get_skill(id).get("unlock_level", 999))

static func next_skill_for_level(level: int) -> StringName:
	for id in order_for():
		if unlock_level(id) == level:
			return id
	return &""

static func is_ultimate(id: StringName) -> bool:
	return bool(get_skill(id).get("ultimate", false))

static func fx_of(id: StringName) -> Dictionary:
	if HolySkills.DATA.has(id):return {"sheet":"","color":"ffe4a5","family":"holy"}
	if IlyuaSkills.DATA.has(id):
		return {"sheet":"res://assets/pixel_batch3/nature_vfx_v1.png","color":"a5ddb7","family":"nature"}
	if SummonerSkills.DATA.has(id):
		return {"sheet":"res://assets/pixel_batch3/star_vfx_v1.png","color":"c3a0ff","family":"star"}
	var family := "fire"
	var tint := "ffae65"
	if id in [&"frost_nova", &"healing_light", &"starfall"]:
		family = "nature"
		tint = "8fdb9b"
	elif id == &"blink":
		family = "star"
		tint = "c4aaff"
	var path := "res://assets/pixel_batch3/" + family + "_vfx_v1.png"
	return {"sheet": path, "color": tint, "family": family}

