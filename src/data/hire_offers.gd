class_name HireOffers
extends RefCounted
## 酒馆的商品：雇佣怪物 / 特殊佣兵。
##
## 怪物 = 场上那几种怪的"被驯服"版：**不带词条**、属性随机（血量/攻击/速度各有浮动），
##        价格按属性总和算，越强越贵。
## 佣兵按人设分为持剑游侠、短弓斥候、飞刀镖师与双刃猎手。

## 可雇佣的怪物种类（不带词条）
const MONSTER_KINDS: Array[StringName] = [
	&"walker", &"flyer", &"charger", &"caster", &"bomber", &"guard", &"treant",
]

const MERC_ICONS := [
	"",
	"",
	"",
	"",
]
const MERC_NAMES := ["灰斗篷游侠", "短弓斥候", "铁面镖师", "夜行猎手"]
const MERC_ROLES:=["sword","bow","knife","dual_daggers"]
static func merc_role(index:int)->String:return MERC_ROLES[clampi(index,0,3)]
static func merc_is_melee(index:int)->bool:return merc_role(index) in ["sword","dual_daggers"]
static func merc_description(index:int)->String:
	return ["近战持剑 · 追近目标后挥斩","远程短弓 · 保持距离并瞄准射箭","远程飞刀 · 保持距离投掷回旋飞刀","近战双刃 · 贴近目标交错斩击"][clampi(index,0,3)]
static func monster_is_melee(kind:StringName)->bool:
	return not EnemyCombatPolicy.ranged_affix_allowed(kind)
static func is_melee(offer:Dictionary)->bool:
	return merc_is_melee(int(offer.get("merc_index",0))) if str(offer.get("kind","monster"))=="merc" else monster_is_melee(StringName(offer.get("enemy_kind",&"walker")))
static func combat_label(offer:Dictionary)->String:
	return ("近战" if is_melee(offer) else "远程")+("佣兵" if str(offer.get("kind","monster"))=="merc" else "怪物同行者")
static func description(offer:Dictionary)->String:
	if str(offer.get("kind","monster"))=="merc":return merc_description(int(offer.get("merc_index",0)))
	var kind:=StringName(offer.get("enemy_kind",&"walker"))
	var action:String
	if not monster_is_melee(kind):
		action="远程幽弹 · 悬浮移动，保持距离发射弹丸" if kind==&"flyer" else "远程攻击 · 保持距离发射弹丸"
	else:
		action={&"walker":"近战骨刃 · 靠近目标后挥击",&"charger":"近战战斧 · 逼近目标后挥斩",&"caster":"近战法杖 · 雇佣形态靠近目标后挥击",&"bomber":"近战法杖 · 雇佣形态靠近目标后挥击",&"guard":"近战盾卫 · 贴近目标后出击",&"treant":"近战重斧 · 靠近敌人后挥斩"}.get(kind,"近战攻击 · 靠近目标后出击")
	return action+"\n不带词条，属性随机；不继承敌方专属技能。"

static var _portraits:Dictionary={}
static func portrait(offer:Dictionary)->Texture2D:
	var merc:=str(offer.get("kind",&"monster"))=="merc"
	var index:=clampi(int(offer.get("merc_index",0)),0,3)
	var kind:=StringName(offer.get("enemy_kind",&"walker"))
	var key:="merc:%d"%index if merc else str(kind)
	if _portraits.has(key):return _portraits[key]
	var frames:SpriteFrames
	if merc:frames=PixelHireArt.make_frames(index)
	else:
		if not PixelEnemyArt.supports(kind):return null
		frames=PixelEnemyArt.make_frames(kind)
	var image:=TexturePixels.image(frames.get_frame_texture(&"idle",0))
	var used:=image.get_used_rect()
	var icon:Texture2D=ImageTexture.create_from_image(image.get_region(used)) if used.has_area() else frames.get_frame_texture(&"idle",0)
	_portraits[key]=icon;return icon
## 怪物"档次"：越高级的怪越贵（游荡者最便宜，林地兽人守卫这种肉盾最贵）
const MONSTER_TIER := {
	&"walker": 1,
	&"flyer": 2,
	&"charger": 2,
	&"bomber": 2,
	&"caster": 3,
	&"guard": 3,
	&"treant": 4,
}
## 每档的基础价（再乘属性随机带来的浮动）
const TIER_PRICE := {1: 22.0, 2: 38.0, 3: 58.0, 4: 82.0}


static func reward_token(rng: RandomNumberGenerator = null) -> Dictionary:
	## 「波次三选一」里那张免费雇佣券：选中后免费雇一只怪物 / 一名佣兵。
	## 抽券的时候就把"具体是谁、雇到手什么属性"定下来并写在卡面上，玩家能看明白再选。
	var hire := random_hire(rng if rng != null else Rng.stream())
	var who := str(hire.get("name", "随机单位"))
	var stats := final_stats(hire, GameState.wave, GameState.ally_bonus())
	return {
		"id": &"hire_token",
		"name": "雇佣契约：%s" % who,
		"desc": "免费雇佣「%s」　·　生命 %.0f　攻击 %.0f　速度 %.0f\n（本局有效，阵亡不复活）" % [
			who, float(stats["hp"]), float(stats["attack"]), float(stats["speed"])],
		"flavor": "温阮盖了个章：凭此券，队伍里可以多一个名字。",
		"kind": &"buff",
		"rarity": 2,
		"cost": 0,
		"hire_token": true,
		"icon": {},
		"hire_entry": hire,
		"flat": {},
		"mult": {},
	}


static func random_hire(rng: RandomNumberGenerator) -> Dictionary:
	## 免费雇佣时随机给一只怪物或一名佣兵
	var offers := roll_offers(rng)
	if offers.is_empty():
		return {}
	return offers[rng.randi_range(0, offers.size() - 1)]


static func base_stats_of(enemy_kind: StringName, is_merc: bool, merc_index := 0) -> Dictionary:
	## 雇佣单位的基础属性：怪物直接照搬那种怪的基础值；佣兵用一套固定偏高的值
	if is_merc:
		var id:="merc:"+str(merc_index)
		return {"hp": UnitBalance.value(id,"hp",95), "attack": UnitBalance.value(id,"attack",15), "speed": UnitBalance.value(id,"speed",118),
			"color": Color("e0b64a"), "gravity": true}
	var probe := WaveDirector.create_enemy(enemy_kind)
	var out := {"hp": 50.0, "attack": 10.0, "speed": 90.0,
		"color": Color("8fd3ff"), "gravity": true}
	if probe != null:
		out["hp"] = probe.base_hp * 1.15
		out["attack"] = probe.base_damage * 0.8
		out["speed"] = maxf(70.0, probe.base_speed)
		out["color"] = probe.body_color
		out["gravity"] = probe.uses_gravity
		probe.free()
	var id:="ally:"+str(enemy_kind)
	for stat in ["hp","attack","speed"]:out[stat]=UnitBalance.value(id,stat,float(out[stat]))
	return out


static func final_stats(offer: Dictionary, wave: int, bonus: Dictionary) -> Dictionary:
	## 最终属性 = 怪物基础值 × **当前波次的敌人倍率** × 这次雇佣的品质倍率 × 召唤师装备加成。
	## 也就是：越晚雇佣的帮手越强，同一波里再按品质上下浮动。
	var is_merc := str(offer.get("kind", &"monster")) == "merc"
	var base := base_stats_of(StringName(offer.get("enemy_kind", &"walker")), is_merc,int(offer.get("merc_index",0)))
	var plan := WaveTable.build(maxi(1, wave))
	var hp := float(base["hp"]) * float(plan["hp_scale"]) \
		* float(offer.get("hp_mul", 1.0)) * float(bonus.get("hp", 1.0))
	var attack := float(base["attack"]) * float(plan["damage_scale"]) \
		* float(offer.get("atk_mul", 1.0)) * float(bonus.get("attack", 1.0))
	var speed := float(base["speed"]) * float(plan["speed_scale"]) \
		* float(offer.get("spd_mul", 1.0)) * float(bonus.get("speed", 1.0))
	return {"hp": hp, "attack": attack, "speed": speed, "color": base["color"], "gravity": base["gravity"]}


static func wave_price_factor(wave: int) -> float:
	## 晚雇的帮手更强，价格也要跟着涨，不然后期雇佣白送
	return WaveTable.hire_price_factor(wave)


static func roll_offers(rng: RandomNumberGenerator) -> Array:
	## 一次给 3 只随机怪物 + 2 名佣兵
	var out: Array = []
	var pool := MONSTER_KINDS.duplicate()
	for i in 3:
		if pool.is_empty():
			break
		var pick := rng.randi_range(0, pool.size() - 1)
		var kind: StringName = pool[pick]
		pool.remove_at(pick)
		out.append(_monster_offer(kind, rng))
	var merc_pool:=[0,1,2,3]
	for i in 2:
		var chosen:=rng.randi_range(0,merc_pool.size()-1)
		out.append(_merc_offer(merc_pool.pop_at(chosen), rng))
	return out


static func _monster_offer(kind: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var probe := WaveDirector.create_enemy(kind)
	var name_text := "怪物"
	var hp := 40.0
	var damage := 8.0
	var speed := 80.0
	if probe != null:
		name_text = probe.display_name
		hp = probe.base_hp
		damage = probe.base_damage
		speed = probe.base_speed
		probe.free()
	# 属性随机（0.85 ~ 1.30），不带任何词条
	var hp_mul := rng.randf_range(0.85, 1.30)
	var atk_mul := rng.randf_range(0.85, 1.30)
	var spd_mul := rng.randf_range(0.90, 1.20)
	var tier := int(MONSTER_TIER.get(kind, 1))
	# 价格 = 档次基础价 × 属性浮动（0.85~1.30 的三项平均），越高级的怪越贵
	var stat_factor := (hp_mul + atk_mul + spd_mul) / 3.0
	var price := int(round(float(TIER_PRICE.get(tier, 22.0)) * stat_factor
		* wave_price_factor(GameState.wave)))
	return {
		"kind": &"monster",
		"enemy_kind": kind,
		"name": "%s（雇佣）" % name_text,
		"hp_mul": hp_mul, "atk_mul": atk_mul, "spd_mul": spd_mul,
		"price": maxi(12, price),
		"tier": tier,
		"icon": "",
		"desc": description({"kind":"monster","enemy_kind":kind}),
	}


static func _merc_offer(index: int, rng: RandomNumberGenerator) -> Dictionary:
	var hp_mul := 1.0 + rng.randf_range(0.0, 0.15)
	var atk_mul := 1.0 + rng.randf_range(0.0, 0.15)
	var spd_mul := 1.0 + rng.randf_range(0.0, 0.10)
	return {
		"kind": &"merc",
		"merc_index": index,
		"name": MERC_NAMES[index],
		"hp_mul": hp_mul, "atk_mul": atk_mul, "spd_mul": spd_mul,
		"price": int(round(float(55 + index * 12) * wave_price_factor(GameState.wave))),
		"icon": MERC_ICONS[index],
		"desc": merc_description(index),
		"combat_role":merc_role(index),
	}

