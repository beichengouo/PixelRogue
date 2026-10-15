class_name ItemDB
extends RefCounted
## 道具表。
##
## 道具分两种大类：
##   被动遗物 kind = "buff"      —— 拿到就立刻生效（三选一奖励、宝箱里的 buff）
##   可装备   kind = "weapon" / "armor" / "accessory"
##                                —— 进背包，要到「背包界面」里手动装备才生效。
##                                   每个槽位只能装一件，所以武器同时只能带一把。
##
## 字段说明：
##   id      唯一标识
##   name    显示名
##   desc    说明文字
##   cost    商店售价
##   rarity  0 普通 / 1 精良 / 2 稀有 / 3 传说（影响出率和颜色）
##   kind    见上
##   icon    图标：{"tex": 图集路径, "idx": 图集里的编号}；idx = -1 表示整张图直接当图标
##   flat    加法修正：{"attack": 5.0}（装备类要装上去才生效）
##   mult    乘法修正：{"attack": 0.15} 表示 +15%
##   weapon  只有武器有：手持武器的普攻表现参数（见下面 _gun 的说明）
##
## 图标来源（全部 CC0，可商用）：
##   res://assets/kenney/tiles_36px.png         Kenney Pixel Platformer，18px 瓦片放大 2 倍
##   res://assets/weapons/gun_*.png             Kenney Desert Shooter Pack，24px 放大 2 倍
## 想换某个道具的图标：改它 icon 里的 idx（图集编号）或换成别的贴图路径即可。

const ICON_SHEET := "res://assets/kenney/tiles_36px.png"
## 新的钥匙图标：Kenney Desert Shooter 的钥匙，比图集里那把更清楚
const UI_KEY_ICON_TEX := "res://assets/next_revision/loot/key.png"
const KEY_ICON_TEX := "res://assets/next_revision/loot/key.png"
## Cooked Pixel Icons（100 个带语义命名的图标，16/32/64 三种尺寸，这里用 64）
const ICON_DIR := "res://assets/icons/"
## 你自己维护的道具表。游戏启动优先读它；读不到才用代码里的内置定义。
## 想加/删道具、换图标、改效果和产出概率，编辑这个文件就行。
const ITEMS_JSON := "res://data/items.json"

## 图标覆盖表：道具 id -> 打包图标里的相对路径。
## 这样不用把上百行道具定义全部重写，只在这里集中维护「哪个道具用哪张图」；
## 没列进来的道具继续用它自带的 icon 字段。
const PACK_ICONS := {
	# 遗物
	&"iron_sword": "01_Weapons/0001_sword_steel.png",
	&"whetstone": "06_Materials/0050_stone.png",
	&"feather_boots": "02_Armor/0013_boots_iron.png",
	&"spring_shoes": "11_Monster_Drops/0084_slime_green.png",
	&"guardian_mail": "02_Armor/0014_round_shield_steel.png",
	&"giant_belt": "06_Materials/0052_leather.png",
	&"blood_charm": "03_Potions/0025_heart_bottle_love.png",
	&"thorn_cloak": "07_Plants_Nature/0057_leaf_autumn.png",
	&"assassin_mark": "01_Weapons/0006_dagger_iron.png",
	&"lucky_coin": "10_Loot_Currency/0074_coin_gold.png",
	&"gale_boots": "12_Status_UI/0093_lightning.png",
	&"double_jump_charm": "11_Monster_Drops/0083_feather_red.png",
	&"berserk_blood": "03_Potions/0020_bottle_poison.png",
	&"phoenix_heart": "04_Gems_Jewelry/0026_gem_ruby.png",
	&"executioner": "01_Weapons/0002_axe_steel.png",
	# 护甲
	&"plate_mail": "02_Armor/0012_chestplate_steel.png",
	&"reactive_plating": "02_Armor/0015_kite_shield_gold.png",
	&"mage_robe": "02_Armor/0017_robe_mage.png",
	# 饰品
	&"crystal_pendant": "04_Gems_Jewelry/0034_amulet_silver_sapphire.png",
	&"life_ampoule": "04_Gems_Jewelry/0031_heart_gem_rose_quartz.png",
	&"cursed_skull": "11_Monster_Drops/0082_skull.png",
	&"lucky_charm": "04_Gems_Jewelry/0030_square_gem_topaz.png",
	&"crit_ring": "04_Gems_Jewelry/0033_ring_gold_ruby.png",
	&"gem_crown": "04_Gems_Jewelry/0035_crown_gold.png",
	# 药剂
	&"potion_health": "03_Potions/0018_potion_health.png",
	&"potion_arcane": "03_Potions/0023_elixir_arcane.png",
	&"potion_energy": "03_Potions/0021_vial_energy.png",
	&"potion_frost": "03_Potions/0022_flask_frost.png",
}

## 图集里几个已确认的编号（识图 + 逐像素比对）
const ICON_HEART := 44        # 红心（满）
const ICON_HEART_HALF := 45   # 红心（半）
const ICON_GEM := 67          # 蓝宝石
const ICON_KEY := 118         # 钥匙
const ICON_COIN := 151        # 金币
const ICON_CHEST := 28        # 宝箱（关）
const ICON_CHEST_OPEN := 27   # 宝箱（开）
const ICON_SKULL := 145       # 骷髅
const ICON_SHARD := 144       # 碎片 / 闪光
const ICON_POTION := 148      # 药水瓶
const ICON_PILLAR := 115      # 蓝色柱体
const ICON_BAR := 146         # 长条
const ICON_BUTTON := 107      # 灰色台块

static var _cache: Array[Dictionary] = []

const STAT_NAMES := {
	&"attack": "攻击力",
	&"attack_speed": "攻击速度",
	&"max_hp": "最大生命",
	&"move_speed": "移动速度",
	&"dash_cooldown": "冲刺冷却",
	&"lifesteal": "普攻命中回复",
	&"thorns": "反伤",
	&"crit_chance": "暴击率",
	&"crit_mult": "暴击伤害",
	&"coin_gain": "金币收益",
	&"mp_regen": "魔法回复速度",
}

## 装备槽位（顺序就是界面上的显示顺序）
const SLOTS: Array[StringName] = [&"weapon", &"armor", &"accessory"]
const SLOT_NAMES := {
	&"weapon": "武器",
	&"armor": "护甲",
	&"accessory": "饰品",
}
const KIND_NAMES := {
	&"buff": "遗物",
	&"weapon": "武器",
	&"armor": "护甲",
	&"accessory": "饰品",
	&"potion": "药剂",
	&"material": "材料",
}


static func sheet_icon(index: int) -> Dictionary:
	if index==ICON_COIN and ResourceLoader.exists("res://assets/currency_v01/coin_icon.tres"):return sprite_icon("res://assets/currency_v01/coin_icon.tres")
	if index==ICON_COIN and ResourceLoader.exists("res://assets/camp_inventory/coin.tres"):
		return sprite_icon("res://assets/camp_inventory/coin.tres")
	return {"tex": ICON_SHEET, "idx": index}


static func sprite_icon(path: String) -> Dictionary:
	return {"tex": path, "idx": -1}


static func key_icon() -> Dictionary:
	## 给「钥匙」这个概念用的伪道具（HUD、商店、掉落物都用它取图标）
	return {"icon": {"tex": UI_KEY_ICON_TEX, "idx": -1}}


## ---------------- 发光蘑菇（采集材料）----------------
## 原创八种菌光蘑菇，这里给每种定：名字 / 稀有度 /
## 售价 / 长出概率权重 / 光的强度倍率。
## **越稀有 → 越贵、越长不出来、光也越亮**（最后一条是给玩家的"远处就看见"提示）。
## 这一条**不进 all()**：蘑菇只能靠在地图上采集，不该混进商店货架/宝箱掉落池。
const MUSHROOM_TEX := "res://assets/world_props_vnext/mushroom_icons.png"
const MUSHROOMS := [
	# 0 普通档：最常见，卖个零钱
	{"name": "焰光菇", "rarity": 0, "price": 12,   "weight": 30.0, "glow": 1.0, "desc":"橙红伞盖散着奶白菌斑，成熟时亮起暖色菌光。", "flavor":"像雨后留在草间的一盏小灯。"},
	{"name": "琥珀菇", "rarity": 0, "price": 15,  "weight": 26.0, "glow": 1.0, "desc":"金黄锥形菌盖透出蜜色光泽，生长在潮湿林地。", "flavor":"菌褶里凝着一滴不肯落下的黄昏。"},
	# 1 精良档
	{"name": "碧水菇", "rarity": 1, "price": 24,  "weight": 11.0, "glow": 1.15, "desc":"宽阔碧蓝菌盖下生着细密发光菌褶，细柄托起一圈水色。", "flavor":"靠近时仿佛能听见浅溪。"},
	{"name": "青苔菇", "rarity": 0, "price": 12,   "weight": 30.0, "glow": 1.0, "desc":"低矮绿伞带着叶片般的斑纹，波浪菌缘藏在苔丛里。", "flavor":"不仔细看，会把它当成一片新叶。"},
	# 2 稀有档
	{"name": "幽紫菇", "rarity": 2, "price": 62,  "weight": 4.5,  "glow": 1.45, "desc":"弯柄托着紫色钟形菌盖，淡紫光点沿垂落的菌缘闪烁。", "flavor":"深夜的风经过，它却始终没有摇响。"},
	# 3 精良档
	{"name": "赤岩菇", "rarity": 1, "price": 26,  "weight": 11.0, "glow": 1.15, "desc":"棱角分明的赤褐菌盖层层叠起，粗柄像一截温热岩柱。", "flavor":"雨水也没有洗掉它身上的暖意。"},
	{"name": "粉雾菇", "rarity": 1, "price": 22,  "weight": 12.0, "glow": 1.15, "desc":"粉色扇瓣舒展开柔软菌盖，白色短柄泛着微光。", "flavor":"一小片晨雾，被轻轻折成了花。"},
	# 4 传说档：一夜未必长出一朵
	{"name": "月华菇", "rarity": 3, "price": 145, "weight": 1.2,  "glow": 1.7, "desc":"珠白菌盖罩着冰蓝菌褶，银色细柄承住稀薄月光。", "flavor":"仿佛只有夜色愿意为它让路。"},
]


static func mushroom_count() -> int:
	return MUSHROOMS.size()


static func mushroom_def(kind: int) -> Dictionary:
	return MUSHROOMS[clampi(kind, 0, MUSHROOMS.size() - 1)]


static func roll_mushroom_kind(rng: RandomNumberGenerator) -> int:
	## 按权重抽一种蘑菇：普通档一堆，传说档只有约 1% 的机会
	var total := 0.0
	for entry: Dictionary in MUSHROOMS:
		total += float(entry["weight"])
	var pick := rng.randf() * total
	for i in MUSHROOMS.size():
		pick -= float((MUSHROOMS[i] as Dictionary)["weight"])
		if pick <= 0.0:
			return i
	return 0


static func mushroom_glow(kind: int) -> float:
	return float(mushroom_def(kind).get("glow", 1.0))


static func mushroom_item(kind: int) -> Dictionary:
	var k := clampi(kind, 0, MUSHROOMS.size() - 1)
	var def := mushroom_def(k)
	var rarity := int(def["rarity"])
	return {
		"id": StringName("glow_mushroom_%d" % k),
		"name": str(def["name"]),
		"desc": "%s\n雨天萌生，成熟后采集，撤回后入库。%s" % [str(def.desc),"普通品质：可在背包或仓库出售，也可提交委托。" if rarity==0 else "高品质：保留用于委托与营地兑换，不可出售。"],
		"flavor": str(def.flavor),
		"kind": &"material",
		"rarity": rarity,
		"cost": int(def["price"]),
		"icon": {"tex": MUSHROOM_TEX, "rect": Rect2(float(k * 64), 0.0, 64.0, 64.0)},
		"flat": {},
		"mult": {},
	}


static func is_material(item: Dictionary) -> bool:
	return item.get("kind", &"buff") == &"material"


static func is_equippable(item: Dictionary) -> bool:
	return SLOTS.has(item.get("kind", &"buff"))


static func is_usable(item: Dictionary) -> bool:
	## 药剂这类「在背包里点一下就用掉」的东西
	return item.get("kind", &"buff") == &"potion"


static func effect_lines(item: Dictionary) -> Array[String]:
	var effect: Dictionary = item.get("effect", {})
	if effect.is_empty():
		return []
	if String(effect.get("kind", "")) == "heal":
		return ["立刻回复 %d 点生命" % int(effect.get("amount", 0.0))]
	if String(effect.get("kind", "")) == "mana":
		return ["立刻回复 %d 点魔法值" % int(effect.get("amount", 0.0))]
	if String(effect.get("kind", "")) == "buff":
		var stat := StringName(effect.get("stat", &"attack"))
		var value := float(effect.get("value", 0.0))
		var duration := int(effect.get("duration", 0.0))
		var text := ""
		if stat == &"thorns":
			text = "%s %+.0f" % [STAT_NAMES.get(stat, str(stat)), value]
		else:
			text = "%s %+.0f%%" % [STAT_NAMES.get(stat, str(stat)), value * 100.0]
		return ["%s，持续 %d 秒" % [text, duration]]
	return []


static func slot_of(item: Dictionary) -> StringName:
	var kind: StringName = item.get("kind", &"buff")
	return kind if SLOTS.has(kind) else &""


static func normalized_icon(item:Dictionary)->Dictionary:
	var raw:Variant=item.get("icon",{})
	if raw is Dictionary:return raw
	if raw is String:
		return sprite_icon(raw) if raw.begins_with("res://") else _icon_from_text(raw)
	return sheet_icon(ICON_GEM)

static func icon_texture(item: Dictionary) -> Texture2D:
	if bool(item.get("hire_token",false)) and not item.get("hire_entry",{}).is_empty():
		return HireOffers.portrait(item.hire_entry)
	var icon: Dictionary = normalized_icon(item)
	var path := str(icon.get("tex", ICON_SHEET))
	if not ResourceLoader.exists(path):
		return null
	return load(path)


static func icon_region(item: Dictionary) -> Rect2:
	if bool(item.get("hire_token",false)) and not item.get("hire_entry",{}).is_empty():
		var portrait:=icon_texture(item)
		return Rect2(Vector2.ZERO,portrait.get_size() if portrait!=null else Vector2(96,96))
	var icon: Dictionary = normalized_icon(item)
	# 代码里现造的道具（比如发光蘑菇）可以直接给一个矩形，取图集里的某一帧
	var rect: Variant = icon.get("rect", null)
	if rect is Rect2:
		return rect
	var index := int(icon.get("idx", -1))
	if index < 0:
		var tex := icon_texture(item)
		return Rect2(Vector2.ZERO, tex.get_size() if tex != null else Vector2(36.0, 36.0))
	return TileSetBuilder.region_for(index)


static func all() -> Array[Dictionary]:
	if _cache.is_empty():
		_cache = _build()
	return _cache


static func _build() -> Array[Dictionary]:
	# 优先读「你自己维护的」道具表；读不到才退回代码里的内置定义。
	## 想加/删道具、换图标、改效果和掉落概率 —— 编辑 res://data/items.json 即可，
	## 不用碰代码。字段说明见 data/items_README.txt。
	var from_file := _load_items_json()
	if not from_file.is_empty():
		return from_file
	return _defaults()


static func _defaults() -> Array[Dictionary]:
	var rows: Array = JSON.parse_string(FALLBACK_CATALOGUE)
	var result: Array[Dictionary] = []
	var problems: Array[String] = []
	for raw in rows: result.append(_item_from_json(raw, problems))
	return result

const FALLBACK_CATALOGUE := '''[{"cost":40.0,"desc":"雇佣的怪物与佣兵：生命 +25%、攻击 +20%","flat":{},"flavor":"系在腰上的小铜铃，摇一下，队伍里的人都会回头。","icon":"tex:res://assets/round5/items/summoner_bell.png","id":"summoner_bell","kind":"buff","mult":{},"name":"召唤师的铃铛","rarity":2.0,"summon":{"hp":0.25,"attack":0.2}},{"cost":44.0,"desc":"雇佣的怪物与佣兵：攻击 +15%、移动速度 +20%","flat":{},"flavor":"戒指内侧刻着一行小字：契约生效期间，别让他们白死。","icon":"tex:res://assets/round5/items/contract_ring.png","id":"contract_ring","kind":"accessory","mult":{},"name":"契约指环","rarity":2.0,"summon":{"attack":0.15,"speed":0.2}},{"cost":22.0,"desc":"攻击力 +6","flat":{"attack":6.0},"flavor":"剑身有细密的使用痕迹，握把缠着旧布条。","icon":"tex:res://assets/round5/items/iron_sword.png","id":"iron_sword","kind":"buff","mult":{},"name":"铁剑","rarity":0.0},{"cost":26.0,"desc":"攻击力 +18%","flat":{},"flavor":"带着铁屑的粗石，蹭几下就能让钝刃回锋。","icon":"tex:res://assets/round5/items/whetstone.png","id":"whetstone","kind":"buff","mult":{"attack":0.18},"name":"磨刀石","rarity":1.0},{"cost":20.0,"desc":"移动速度 +12%","flat":{},"flavor":"靴筒里缝着一根飞鸟的尾羽，走路几乎听不见声音。","icon":"tex:res://assets/round5/items/feather_boots.png","id":"feather_boots","kind":"buff","mult":{"move_speed":0.12},"name":"轻羽靴","rarity":0.0},{"cost":20.0,"desc":"已退役的旧旅途遗物，不再产出。","flat":{},"flavor":"鞋底嵌着弹力魔石，落地会轻轻回弹。","icon":"tex:res://assets/round5/items/spring_shoes.png","id":"spring_shoes","kind":"buff","mult":{},"name":"弹簧鞋","rarity":0.0,"sources":[],"retired":true},{"cost":22.0,"desc":"最大生命 +25","flat":{"max_hp":25.0},"flavor":"胸口一块磨得发亮的护片，挡得住最直接的一击。","icon":"tex:res://assets/round5/items/guardian_mail.png","id":"guardian_mail","kind":"buff","mult":{},"name":"护心甲","rarity":0.0},{"cost":30.0,"desc":"最大生命 +45，移动速度 -8%","flat":{"max_hp":45.0},"flavor":"宽厚的皮革腰带，扣环上刻着巨人的符文。","icon":"tex:res://assets/round5/items/giant_belt.png","id":"giant_belt","kind":"buff","mult":{"move_speed":-0.08},"name":"巨人腰带","rarity":1.0},{"cost":32.0,"desc":"普攻命中回复 1 点生命（同名来源不重复叠加）","flat":{"lifesteal":1.0},"flavor":"暗红的纹路像血管一样在木牌上蔓延。","icon":"tex:res://assets/round5/items/blood_charm.png","id":"blood_charm","kind":"buff","mult":{},"name":"血纹护符","rarity":1.0},{"cost":28.0,"desc":"受击时反伤 10 点","flat":{"thorns":10.0},"flavor":"布料里编进了干枯的荆棘，碰它会扎手。","icon":"tex:res://assets/round5/items/thorn_cloak.png","id":"thorn_cloak","kind":"buff","mult":{},"name":"荆棘斗篷","rarity":1.0},{"cost":34.0,"desc":"暴击率 +15%，暴击伤害 +50%","flat":{"crit_chance":0.15,"crit_mult":0.5},"flavor":"一枚刻着眼纹的铜章，贴在皮肤上微微发凉。","icon":"tex:res://assets/round5/items/assassin_mark.png","id":"assassin_mark","kind":"buff","mult":{},"name":"刺客印记","rarity":2.0},{"cost":18.0,"desc":"金币收益 +35%","flat":{},"flavor":"边缘被咬出一个小缺口的老金币。","icon":"tex:res://assets/round5/items/lucky_coin.png","id":"lucky_coin","kind":"buff","mult":{"coin_gain":0.35},"name":"幸运币","rarity":0.0},{"cost":22.0,"desc":"冲刺冷却 -30%","flat":{},"flavor":"靴面缝着风精灵的鳞片，起步比思考更快。","icon":"tex:res://assets/round5/items/gale_boots.png","id":"gale_boots","kind":"buff","mult":{"dash_cooldown":-0.3},"name":"疾风之靴","rarity":0.0},{"cost":36.0,"desc":"已退役的旧旅途遗物，不再产出。","flat":{},"flavor":"画着两片羽毛的纸符，据说踩着空气也能再起跳。","icon":"tex:res://assets/round5/items/double_jump_charm.png","id":"double_jump_charm","kind":"buff","mult":{},"name":"二段跳符","rarity":2.0,"sources":[],"retired":true},{"cost":28.0,"desc":"攻击力 +25%，最大生命 -15","flat":{"max_hp":-15.0},"flavor":"瓶里是不安分的红色液滴，一直在轻轻翻涌。","icon":"tex:res://assets/round5/items/berserk_blood.png","id":"berserk_blood","kind":"buff","mult":{"attack":0.25},"name":"狂暴之血","rarity":1.0},{"cost":44.0,"desc":"最大生命 +30，普攻命中回复 1 点生命（同名来源不重复叠加）","flat":{"lifesteal":1.0,"max_hp":30.0},"flavor":"温热的小小结晶，贴近能听见极轻的搏动声。","icon":"tex:res://assets/round5/items/phoenix_heart.png","id":"phoenix_heart","kind":"buff","mult":{},"name":"不死鸟之心","rarity":3.0},{"cost":46.0,"desc":"攻击力 +40%，暴击率 +8%","flat":{"crit_chance":0.08},"flavor":"刃口有一道洗不掉的暗色，谁都不想细看。","icon":"tex:res://assets/round5/items/executioner.png","id":"executioner","kind":"buff","mult":{"attack":0.4},"name":"处刑者之刃","rarity":3.0},{"cost":30.0,"desc":"攻击 +12%，攻击速度 +10% · 紫晶环刃弹","flat":{},"flavor":"杖尖嵌着一颗跳动的紫色晶体。","icon":"tex:res://assets/round5/items/wand_arcane.png","id":"wand_arcane","kind":"weapon","mult":{"attack":0.12,"attack_speed":0.1},"name":"秘法魔杖","rarity":1.0,"weapon":{"family":"staff","fx":"wand_arcane","speed":460,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#c9a8ff"},"weapon_class":"mage"},{"cost":34.0,"desc":"攻击 +25%，暴击率 +3% · 烈焰彗星弹","flat":{"crit_chance":0.03},"flavor":"杖身温热，靠近能闻到淡淡的硫磺味。","icon":"tex:res://assets/round5/items/staff_fire.png","id":"staff_fire","kind":"weapon","mult":{"attack":0.25},"name":"火焰法杖","rarity":2.0,"weapon":{"family":"staff","fx":"staff_fire","speed":430,"reach":560,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#ff9a3d"},"weapon_class":"mage"},{"cost":36.0,"desc":"攻击 +12%，暴击率 +4% · 翠羽箭","flat":{"crit_chance":0.04},"flavor":"弓臂是整根老木弯成的，弦上过蜂蜡。","icon":"tex:res://assets/round5/items/bow_wood.png","id":"bow_wood","kind":"weapon","mult":{"attack":0.12},"name":"猎手长弓","rarity":1.0,"weapon":{"family":"bow","fx":"bow_wood","speed":560,"reach":700,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#a8ffb0"},"weapon_class":"archer"},{"cost":32.0,"desc":"攻击 +16%，攻击速度 +12% · 银蓝刃光","flat":{},"flavor":"短到几乎能藏进袖口，刃薄得透光。","icon":"tex:res://assets/round5/items/dagger_iron.png","id":"dagger_iron","kind":"weapon","mult":{"attack":0.16,"attack_speed":0.12},"name":"铁匕首","rarity":2.0,"weapon":{"family":"sword","fx":"dagger_iron","speed":430,"reach":76,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#a2d4ff"},"weapon_class":"warrior"},{"cost":46.0,"desc":"攻击 +42%，生命上限 +25，暴击伤害 +20%，攻击速度 −8% · 秘金碎岩锤光","flat":{"max_hp":25,"crit_mult":0.2},"flavor":"锤头刻着秘银纹路，抬手就知道它有多沉。","icon":"tex:res://assets/round5/items/warhammer_gold.png","id":"warhammer_gold","kind":"weapon","mult":{"attack":0.42,"attack_speed":-0.08},"name":"秘金战锤","rarity":3.0,"weapon":{"family":"hammer","fx":"warhammer_gold","speed":430,"reach":98,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#ffe066"},"weapon_class":"warrior"},{"cost":32.0,"desc":"最大生命 +50，移动速度 -4%","flat":{"max_hp":50},"flavor":"拼接严密的钢片，扣上时会发出清脆的一声。","icon":"tex:res://assets/round5/items/plate_mail.png","id":"plate_mail","kind":"armor","mult":{"move_speed":-0.04},"name":"铁壁胸甲","rarity":1.0},{"cost":38.0,"desc":"受击反伤 +16，最大生命 +20","flat":{"max_hp":20.0,"thorns":16.0},"flavor":"甲面上排着会自己收紧的金属鳞片。","icon":"tex:res://assets/round5/items/reactive_plating.png","id":"reactive_plating","kind":"armor","mult":{},"name":"反应装甲","rarity":2.0},{"cost":30.0,"desc":"最大生命 +25，移动速度 +8%，魔法回复速度 +8%","flat":{"max_hp":25},"flavor":"肩上绣着星轨，走路时会轻轻飘起来。","icon":"tex:res://assets/round5/items/mage_robe.png","id":"mage_robe","kind":"armor","mult":{"move_speed":0.08,"mp_regen":0.08},"name":"游星法袍","rarity":1.0},{"cost":30.0,"desc":"暴击率 +12%","flat":{"crit_chance":0.12},"flavor":"银链挂着的蓝宝石，会在危险前微微发暗。","icon":"tex:res://assets/round5/items/crystal_pendant.png","id":"crystal_pendant","kind":"accessory","mult":{},"name":"秘银吊坠","rarity":1.0},{"cost":34.0,"desc":"普攻命中回复 1 点生命（同名来源不重复叠加）","flat":{"lifesteal":1.0},"flavor":"小小的粉色晶石，掌心捂着会变暖。","icon":"tex:res://assets/round5/items/life_ampoule.png","id":"life_ampoule","kind":"accessory","mult":{},"name":"生命药囊","rarity":2.0},{"cost":36.0,"desc":"攻击力 +30%，最大生命 -10","flat":{"max_hp":-10.0},"flavor":"不知是谁的头骨，眼窝里点着一点幽火。","icon":"tex:res://assets/round5/items/cursed_skull.png","id":"cursed_skull","kind":"accessory","mult":{"attack":0.3},"name":"诅咒骷髅","rarity":2.0},{"cost":26.0,"desc":"金币收益 +40%","flat":{},"flavor":"黄玉打磨的方片，据说掉进过三次悬崖都没碎。","icon":"tex:res://assets/round5/items/lucky_charm.png","id":"lucky_charm","kind":"accessory","mult":{"coin_gain":0.4},"name":"幸运护符","rarity":1.0},{"cost":34.0,"desc":"暴击率 +15%，暴击伤害 +40%","flat":{"crit_chance":0.15,"crit_mult":0.4},"flavor":"戒指内圈刻着极小的准星。","icon":"tex:res://assets/round5/items/crit_ring.png","id":"crit_ring","kind":"accessory","mult":{},"name":"暴击指环","rarity":2.0},{"cost":44.0,"desc":"攻击力 +20%，最大生命 +20，暴击率 +6%，魔法回复速度 +10%","flat":{"max_hp":20,"crit_chance":0.06},"flavor":"用整块宝石雕成的冠，戴久了会有点压头。","icon":"tex:res://assets/round5/items/gem_crown.png","id":"gem_crown","kind":"accessory","mult":{"attack":0.2,"mp_regen":0.1},"name":"宝石王冠","rarity":3.0,"legendary_fx":"gem_crown"},{"cost":14.0,"desc":"立刻回复 45 点生命","effect":{"amount":45.0,"kind":"heal"},"flat":{},"flavor":"温热的红色药水，闻起来像草药糖。","icon":"tex:res://assets/round5/items/potion_health.png","id":"potion_health","kind":"potion","mult":{},"name":"治疗药剂","rarity":0.0},{"cost":18.0,"desc":"20 秒内攻击力 +35%","effect":{"duration":20.0,"kind":"buff","stat":"attack","value":0.35},"flat":{},"flavor":"紫色液体里有细小的光点在打转。","icon":"tex:res://assets/round5/items/potion_arcane.png","id":"potion_arcane","kind":"potion","mult":{},"name":"秘法药剂","rarity":1.0},{"cost":16.0,"desc":"立刻回复 40 点魔法值","effect":{"amount":40.0,"kind":"mana"},"flat":{},"flavor":"冰凉的青绿药水，喝下去脚步会变轻。","icon":"tex:res://assets/round5/items/potion_energy.png","id":"potion_energy","kind":"potion","mult":{},"name":"能量药剂","rarity":1.0},{"cost":16.0,"desc":"25 秒内反伤 +20","effect":{"duration":25.0,"kind":"buff","stat":"thorns","value":20.0},"flat":{},"flavor":"瓶壁结着一层薄霜，握久了指尖发麻。","icon":"tex:res://assets/round5/items/potion_frost.png","id":"potion_frost","kind":"potion","mult":{},"name":"冰霜药剂","rarity":1.0},{"id":"traveler_leather","name":"旅人皮甲","kind":"armor","rarity":0,"cost":24,"flat":{"max_hp":20},"mult":{"move_speed":0.05},"desc":"最大生命 +20，移动速度 +5%","flavor":"旅途中留下的星辉，守护下一段冒险。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/traveler_leather.png"},{"id":"watcher_cloth","name":"守夜布衣","kind":"armor","rarity":0,"cost":24,"flat":{"max_hp":30},"mult":{},"desc":"最大生命 +30","flavor":"旅途中留下的星辉，守护下一段冒险。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/watcher_cloth.png"},{"id":"thorn_vest","name":"荆棘背心","kind":"armor","rarity":1,"cost":30,"flat":{"max_hp":15,"thorns":10},"mult":{},"desc":"最大生命 +15，反伤 +10","flavor":"旅途中留下的星辉，守护下一段冒险。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/thorn_vest.png"},{"id":"feather_coat","name":"轻羽外套","kind":"armor","rarity":1,"cost":28,"flat":{"max_hp":25},"mult":{"move_speed":0.09},"desc":"最大生命 +25，移动速度 +9%","flavor":"旅途中留下的星辉，守护下一段冒险。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/feather_coat.png"},{"id":"wind_cloak","name":"风行斗篷","kind":"armor","rarity":2,"cost":36,"flat":{"max_hp":35},"mult":{"move_speed":0.1,"dash_cooldown":-0.15},"desc":"最大生命 +35，移动速度 +10%，冲刺冷却 -15%","flavor":"旅途中留下的星辉，守护下一段冒险。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/wind_cloak.png"},{"id":"starlight_plate","name":"星辉战甲","kind":"armor","rarity":3,"cost":46,"flat":{"max_hp":50,"thorns":8},"mult":{"attack":0.15,"move_speed":-0.05,"mp_regen":0.15},"desc":"最大生命 +50，反伤 +8，攻击力 +15%，移动速度 -5%，魔法回复速度 +15%","flavor":"旅途中留下的星辉，守护下一段冒险。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/starlight_plate.png","legendary_fx":"starlight_plate"},{"id":"eagle_badge","name":"鹰眼徽章","kind":"accessory","rarity":0,"cost":24,"flat":{"crit_chance":0.08},"mult":{},"desc":"暴击率 +8%","flavor":"旅途中留下的星辉，守护下一段冒险。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/eagle_badge.png"},{"id":"journey_bell","name":"旅途铜铃","kind":"accessory","rarity":0,"cost":22,"flat":{},"mult":{"move_speed":0.06},"desc":"移动速度 +6%","flavor":"旅途中留下的星辉，守护下一段冒险。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/journey_bell.png"},{"id":"merchant_purse","name":"行商钱袋","kind":"accessory","rarity":1,"cost":28,"flat":{"max_hp":10},"mult":{"coin_gain":0.25},"desc":"最大生命 +10，金币收益 +25%","flavor":"旅途中留下的星辉，守护下一段冒险。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/merchant_purse.png"},{"id":"guardian_brooch","name":"守护胸针","kind":"accessory","rarity":1,"cost":30,"flat":{"max_hp":20,"thorns":6},"mult":{},"desc":"最大生命 +20，反伤 +6","flavor":"旅途中留下的星辉，守护下一段冒险。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/guardian_brooch.png"},{"id":"wind_ring","name":"疾风指环","kind":"accessory","rarity":2,"cost":34,"flat":{},"mult":{"dash_cooldown":-0.2,"move_speed":0.05},"desc":"冲刺冷却 -20%，移动速度 +5%","flavor":"旅途中留下的星辉，守护下一段冒险。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/wind_ring.png"},{"id":"morningstar_pendant","name":"晨星坠饰","kind":"accessory","rarity":3,"cost":44,"flat":{"crit_mult":0.25,"crit_chance":0.1},"mult":{"attack":0.15,"mp_regen":0.1},"desc":"暴击伤害 +25%，暴击率 +10%，攻击力 +15%，魔法回复速度 +10%","flavor":"旅途中留下的星辉，守护下一段冒险。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/morningstar_pendant.png","legendary_fx":"morningstar_pendant"},{"id":"relic_moon_compass","name":"月弧罗盘","kind":"buff","rarity":0,"cost":20,"desc":"暴击率 +4%","flat":{"crit_chance":0.04},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/relic_moon_compass.tres"},{"id":"relic_leaf_brooch","name":"翠叶胸章","kind":"buff","rarity":0,"cost":22,"desc":"生命上限 +18，移动速度 +4%","flat":{"max_hp":18},"mult":{"move_speed":0.04},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/relic_leaf_brooch.tres"},{"id":"relic_rose_hourglass","name":"蔷薇沙漏","kind":"buff","rarity":1,"cost":26,"desc":"冲刺冷却 −12%","flat":{},"mult":{"dash_cooldown":-0.12},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/relic_rose_hourglass.tres"},{"id":"relic_star_lantern","name":"星灯遗物","kind":"buff","rarity":1,"cost":30,"desc":"攻击 +12%，生命上限 +12","flat":{"max_hp":12},"mult":{"attack":0.12},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/relic_star_lantern.tres"},{"id":"relic_swallow_quill","name":"青燕羽笔","kind":"buff","rarity":1,"cost":26,"desc":"移动速度 +6%","flat":{},"mult":{"move_speed":0.06},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/relic_swallow_quill.tres"},{"id":"relic_arcane_stone","name":"秘纹符石","kind":"buff","rarity":2,"cost":36,"desc":"攻击 +20%，暴击率 +5%","flat":{"crit_chance":0.05},"mult":{"attack":0.2},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/relic_arcane_stone.tres"},{"id":"relic_guardian_feather","name":"守望双羽","kind":"buff","rarity":2,"cost":36,"desc":"生命上限 +40，反伤 +8","flat":{"max_hp":40,"thorns":8},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/relic_guardian_feather.tres"},{"id":"relic_dawn_bell","name":"曙光之铃","kind":"buff","rarity":3,"cost":46,"desc":"攻击 +24%，暴击率 +8%","flat":{"crit_chance":0.08},"mult":{"attack":0.24},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/relic_dawn_bell.tres"},{"id":"potion_vital","name":"浓缩生命药剂","kind":"potion","rarity":0,"cost":24,"desc":"立刻回复80点生命","flat":{},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/potion_vital.tres","effect":{"kind":"heal","amount":80}},{"id":"potion_moon","name":"月泉药剂","kind":"potion","rarity":1,"cost":24,"desc":"立刻回复70点魔法","flat":{},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/potion_moon.tres","effect":{"kind":"mana","amount":70}},{"id":"potion_focus","name":"专注药剂","kind":"potion","rarity":1,"cost":24,"desc":"攻击速度 +25%，持续20秒","flat":{},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/potion_focus.tres","effect":{"kind":"buff","stat":"attack_speed","value":0.25,"duration":20}},{"id":"potion_wind","name":"风行药剂","kind":"potion","rarity":0,"cost":22,"desc":"移动速度 +25%，持续20秒","flat":{},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/potion_wind.tres","effect":{"kind":"buff","stat":"move_speed","value":0.25,"duration":20}},{"id":"potion_spring","name":"轻跃药剂","kind":"potion","rarity":0,"cost":22,"desc":"已退役的旧旅途药剂，不再产出。","flat":{},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/potion_spring.tres","effect":{},"sources":[],"retired":true},{"id":"potion_starlight","name":"星光圣露","kind":"potion","rarity":3,"cost":48,"desc":"立刻回复120点生命；营地以3个碧水菇兑换","flat":{},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/potion_starlight.tres","effect":{"kind":"heal","amount":120}},{"id":"camp_mooncoat","name":"月辉行衣","kind":"armor","rarity":2,"cost":44,"desc":"生命上限 +28，攻击 +12%，移动速度 +5%；仅营地随机商店兑换","flat":{"max_hp":28},"mult":{"attack":0.12,"move_speed":0.05},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/camp_mooncoat.tres","sources":["camp_shop"]},{"id":"camp_thornplate","name":"翠棘守甲","kind":"armor","rarity":2,"cost":46,"desc":"生命上限 +28，反伤 +20；仅营地随机商店兑换","flat":{"max_hp":28,"thorns":20},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/camp_thornplate.tres","sources":["camp_shop"]},{"id":"camp_stararmor","name":"星冕战甲","kind":"armor","rarity":3,"cost":56,"desc":"生命上限 +60，反伤 +14，攻击 +15%，移动速度 −5%，魔法回复速度 +15%；仅营地随机商店兑换","flat":{"max_hp":60,"thorns":14},"mult":{"attack":0.15,"move_speed":-0.05,"mp_regen":0.15},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/camp_stararmor.tres","sources":["camp_shop"],"legendary_fx":"camp_stararmor"},{"id":"camp_windring","name":"苍风契戒","kind":"accessory","rarity":2,"cost":42,"desc":"冲刺冷却 −24%，移动速度 +6%；仅营地随机商店兑换","flat":{},"mult":{"dash_cooldown":-0.24,"move_speed":0.06},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/camp_windring.tres","sources":["camp_shop"]},{"id":"camp_sunpendant","name":"旭星坠饰","kind":"accessory","rarity":3,"cost":54,"desc":"攻击 +18%，暴击伤害 +30%，暴击率 +10%，魔法回复速度 +20%；仅营地随机商店兑换","flat":{"crit_mult":0.3,"crit_chance":0.1},"mult":{"attack":0.18,"mp_regen":0.2},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/camp_sunpendant.tres","sources":["camp_shop"],"legendary_fx":"camp_sunpendant"},{"id":"camp_queenbrooch","name":"女王星章","kind":"accessory","rarity":3,"cost":54,"desc":"生命上限 +24，攻击 +24%，暴击率 +6%，魔法回复速度 +10%；仅营地随机商店兑换","flat":{"max_hp":24,"crit_chance":0.06},"mult":{"attack":0.24,"mp_regen":0.1},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/camp_queenbrooch.tres","sources":["camp_shop"],"legendary_fx":"camp_queenbrooch"},{"id":"staff_apprentice","name":"学徒木杖","kind":"weapon","rarity":0,"cost":24,"icon":"tex:res://assets/weapons/reforged/staff_apprentice_icon.png","flavor":"以手中法杖引导星辉，照亮前行的路。","weapon_class":"mage","mult":{"attack":0.06},"flat":{},"desc":"攻击 +6% · 翠叶微光弹","weapon":{"family":"staff","fx":"staff_apprentice","speed":430,"reach":470,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#a6e979"}},{"id":"staff_starorbit","name":"星轨王杖","kind":"weapon","rarity":3,"cost":46,"icon":"tex:res://assets/weapons/reforged/staff_starorbit_icon.png","flavor":"以手中法杖引导星辉，照亮前行的路。","weapon_class":"mage","mult":{"attack":0.35,"mp_regen":0.2},"flat":{"crit_chance":0.06},"desc":"攻击 +35%，暴击率 +6%，魔法回复速度 +20% · 星轨彗光与星座绽放","weapon":{"family":"staff","fx":"staff_starorbit","speed":460,"reach":600,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#bbdfff"}},{"id":"staff_ember_flower","name":"烬花法杖","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/builds_vnext/icons/staff_ember_flower.png","flavor":"火种绽放在旅途中留下了一道可辨认的光。","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击 +30%、攻击速度 +8%、魔法回复速度 +12%。火种绽放：普攻附加燃烧：每秒造成攻击力12%的伤害，持续3秒；普攻击中燃烧目标时，以其为中心对72范围内每个敌人造成攻击力65%的爆发伤害，每个目标冷却2秒。","mechanics":[{"id":"ember_flower"}],"build_tags":["burn","basic_attack","aoe"],"sources":["shop","chest","reward"],"weapon_class":"mage","legendary_fx":"staff_ember_flower","weapon":{"family":"staff","fx":"staff_ember_flower","speed":460,"reach":560,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#ff8959"}},{"id":"staff_star_weave","name":"星织法杖","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/builds_vnext/icons/staff_star_weave.png","flavor":"三芒星痕在旅途中留下了一道可辨认的光。","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击 +30%、攻击速度 +8%、魔法回复速度 +12%。三芒星痕：4秒内对同一目标普攻命中3次，触发星痕，命中该目标周围144范围内至多3个最近的其他敌人，每个造成攻击力35%的伤害；触发冷却0.6秒。","mechanics":[{"id":"star_weave"}],"build_tags":["basic_attack","mark","chain"],"sources":["shop","chest","reward"],"weapon_class":"mage","legendary_fx":"staff_star_weave","weapon":{"family":"staff","fx":"staff_star_weave","speed":460,"reach":560,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#b8caff"}},{"id":"staff_wind_branch","name":"逐风枝杖","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/builds_vnext/icons/staff_wind_branch.png","flavor":"风枝散射在旅途中留下了一道可辨认的光。","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击 +30%、攻击速度 +8%、魔法回复速度 +12%。风枝散射：冲刺后3秒内的下一次普攻改为扇形发射3枚风刃，每枚造成攻击力55%的伤害，且可穿透1个目标。","mechanics":[{"id":"wind_branch"}],"build_tags":["dash","basic_attack","multishot"],"sources":["shop","chest","reward"],"weapon_class":"mage","legendary_fx":"staff_wind_branch","weapon":{"family":"staff","fx":"staff_wind_branch","speed":460,"reach":560,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#8be6c7"}},{"id":"armor_thorn_moon","name":"棘月守甲","kind":"armor","rarity":3,"cost":60,"icon":"tex:res://assets/builds_vnext/icons/armor_thorn_moon.png","flavor":"月棘反击在旅途中留下了一道可辨认的光。","flat":{"max_hp":50},"mult":{"attack":0.1,"mp_regen":0.12},"desc":"最大生命 +50、攻击 +10%、魔法回复速度 +12%。月棘反击：护盾被伤害耗尽时，以自身为中心对108范围内敌人造成攻击力90%的反击伤害；冷却4秒。","mechanics":[{"id":"thorn_moon"}],"build_tags":["shield","retaliation","aoe"],"sources":["shop","chest","reward"]},{"id":"staff_soul_command","name":"御魂法杖","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/builds_vnext/icons/staff_soul_command.png","flavor":"魂印号令在旅途中留下了一道可辨认的光。","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击 +30%、攻击速度 +8%、魔法回复速度 +12%。魂印号令：普攻击中敌人后为其施加4秒魂印，附近友方单位优先集火魂印目标；友方单位对魂印目标造成的直接伤害提高15%。","mechanics":[{"id":"soul_command"}],"build_tags":["ally","mark","focus"],"sources":["shop","chest","reward"],"weapon_class":"mage","legendary_fx":"staff_soul_command","weapon":{"family":"staff","fx":"staff_soul_command","speed":460,"reach":560,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#b3a0ef"}},{"id":"staff_dusk_lantern","name":"暮灯法杖","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/builds_vnext/icons/staff_dusk_lantern.png","flavor":"暮灯契印在旅途中留下了一道可辨认的光。","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击+30%、攻速+8%、MP回复+12%。普攻有效命中为最近一名主动契约物附加6秒暮灯印，冷却1秒；其被敌方伤害击杀时，对72范围敌人造成0.7倍攻击暮灯波，每秒最多三次。自然到期、切房或漂浮灵消失不触发。","mechanics":[{"id":"dusk_lantern"}],"build_tags":["contract","mark","death_burst"],"sources":["shop","chest","reward"],"requires_character":"xixifu","weapon_class":"mage","legendary_fx":"staff_dusk_lantern","weapon":{"family":"staff","fx":"staff_dusk_lantern","speed":460,"reach":560,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#efad78"}},{"id":"armor_scorch_bloom","name":"灼花护衣","kind":"armor","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/armor_scorch_bloom.png","flavor":"灼花追击是一件被反复使用过的战斗器物。","flat":{"max_hp":30},"mult":{"mp_regen":0.08},"desc":"最大生命 +30、魔法回复速度 +8%。灼花追击：技能直接命中燃烧目标时，对该目标额外造成攻击力25%的伤害；同一目标冷却1秒。","mechanics":[{"id":"scorch_bloom"}],"build_tags":["burn","skill","single_target"],"sources":["shop","chest","reward"]},{"id":"accessory_refraction","name":"折光棱镜","kind":"accessory","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/accessory_refraction.png","flavor":"折光弹是一件被反复使用过的战斗器物。","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"desc":"攻击 +10%、魔法回复速度 +8%。折光弹：每次普攻首次有效直接暴击获得1层折光；达到3层后，下次普攻追加一发侧向弹，造成攻击力45%的伤害。","mechanics":[{"id":"refraction"}],"build_tags":["crit","basic_attack","projectile"],"sources":["shop","chest","reward"]},{"id":"armor_swallow_return","name":"归燕轻甲","kind":"armor","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/armor_swallow_return.png","flavor":"归燕护幕是一件被反复使用过的战斗器物。","flat":{"max_hp":30},"mult":{"mp_regen":0.08},"desc":"最大生命 +30、魔法回复速度 +8%。归燕护幕：冲刺结束时获得相当于最大生命8%的护盾，持续2秒；冷却5秒。","mechanics":[{"id":"swallow_return"}],"build_tags":["dash","shield"],"sources":["shop","chest","reward"]},{"id":"accessory_oath_guard","name":"守誓徽记","kind":"accessory","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/accessory_oath_guard.png","flavor":"守誓之盾是一件被反复使用过的战斗器物。","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"desc":"攻击 +10%、魔法回复速度 +8%。守誓之盾：技能直接命中敌人时获得相当于最大生命6%的护盾，持续4秒；冷却4秒。","mechanics":[{"id":"oath_guard"}],"build_tags":["skill","shield"],"sources":["shop","chest","reward"]},{"id":"accessory_contract_chorus","name":"契约合唱","kind":"accessory","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/accessory_contract_chorus.png","flavor":"契约齐鸣是一件被反复使用过的战斗器物。","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"desc":"攻击 +10%、魔法回复速度 +8%。契约齐鸣：施放技能时，所有友方单位的攻击速度提高15%，持续3秒；再次触发刷新持续时间。","mechanics":[{"id":"contract_chorus"}],"build_tags":["ally","cast","attack_speed"],"sources":["shop","chest","reward"]},{"id":"armor_farewell","name":"别离护衣","kind":"armor","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/armor_farewell.png","flavor":"别离余护是一件被反复使用过的战斗器物。","flat":{"max_hp":30},"mult":{"mp_regen":0.08},"desc":"最大生命 +30、魔法回复速度 +8%。别离余护：暮灯标记的目标被命中时获得相当于最大生命5%的护盾，持续4秒；冷却3秒。","mechanics":[{"id":"farewell"}],"build_tags":["dusk","shield","mark"],"sources":["shop","chest","reward"],"requires_character":"xixifu"},{"id":"relic_ember_seed","name":"余烬种子","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_ember_seed.png","flavor":"续燃在冒险途中悄然回应持有者。","flat":{},"mult":{},"desc":"续燃：燃烧目标死亡时，将其剩余燃烧效果传给72范围内最近的至多2个敌人；传播所得的燃烧不会再次传播。","mechanics":[{"id":"ember_seed"}],"build_tags":["burn","spread"],"sources":["shop","chest","reward"]},{"id":"relic_star_mirror","name":"星痕镜片","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_star_mirror.png","flavor":"星痕回响在冒险途中悄然回应持有者。","flat":{},"mult":{},"desc":"星痕回响：命中带有星痕的目标时回复1点魔法值；全局冷却1秒。","mechanics":[{"id":"star_mirror"}],"build_tags":["mark","mp_restore"],"sources":["shop","chest","reward"]},{"id":"relic_wind_chime","name":"逐风铃","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_wind_chime.png","flavor":"风刃回旋在冒险途中悄然回应持有者。","flat":{},"mult":{},"desc":"风刃回旋：风枝散射命中敌人时，当前冲刺的剩余冷却缩短20%；每次冲刺最多触发1次。","mechanics":[{"id":"wind_chime"}],"build_tags":["dash","cooldown"],"sources":["shop","chest","reward"]},{"id":"relic_thorn_shard","name":"棘月碎片","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_thorn_shard.png","flavor":"棘刺滞缓在冒险途中悄然回应持有者。","flat":{},"mult":{},"desc":"棘刺滞缓：棘月反击命中的敌人减速25%，持续2秒；首领减速效果减半。","mechanics":[{"id":"thorn_shard"}],"build_tags":["retaliation","slow"],"sources":["shop","chest","reward"]},{"id":"relic_companion_knot","name":"同行结","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_companion_knot.png","flavor":"并肩流转在冒险途中悄然回应持有者。","flat":{},"mult":{},"desc":"并肩流转：144范围内至少有2名友方单位时，魔法回复速度提高15%。","mechanics":[{"id":"companion_knot"}],"build_tags":["ally","mp_regen"],"sources":["shop","chest","reward"]},{"id":"relic_echo_wick","name":"回声灯芯","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_echo_wick.png","flavor":"灯焰回魔在冒险途中悄然回应持有者。","flat":{},"mult":{},"desc":"灯焰回魔：暮灯标记的目标被命中时回复3点魔法值；冷却2秒。","mechanics":[{"id":"echo_wick"}],"build_tags":["dusk","mp_restore"],"sources":["shop","chest","reward"],"requires_character":"xixifu"},{"id":"relic_hunt_needle","name":"猎行针","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_hunt_needle.png","flavor":"追猎针在冒险途中悄然回应持有者。","flat":{},"mult":{},"desc":"追猎针：普攻击中减速目标时，对该目标额外造成攻击力12%的伤害；同一目标冷却1秒。","mechanics":[{"id":"hunt_needle"}],"build_tags":["slow","basic_attack"],"sources":["shop","chest","reward"]},{"id":"relic_tide_pearl","name":"潮汐珠","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_tide_pearl.png","flavor":"潮汐回魔在冒险途中悄然回应持有者。","flat":{},"mult":{},"desc":"潮汐回魔：施放技能后的4秒内，下一次有效普攻击中回复3点魔法值；冷却3秒。","mechanics":[{"id":"tide_pearl"}],"build_tags":["cast","basic_attack","mp_restore"],"sources":["shop","chest","reward"]},{"id":"relic_afterglow_note","name":"余辉手记","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_afterglow_note.png","flavor":"余辉之盾在冒险途中悄然回应持有者。","flat":{},"mult":{},"desc":"余辉之盾：首次进入每个尚未清理的普通房间时，获得相当于最大生命10%的护盾，持续8秒；每间房仅触发1次。","mechanics":[{"id":"afterglow_note"}],"build_tags":["room_enter","shield"],"sources":["shop","chest","reward"]},{"id":"relic_breaker_stone","name":"破甲石","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/relic_breaker_stone.png","flavor":"精英克星在冒险途中悄然回应持有者。","flat":{},"mult":{},"desc":"精英克星：技能直接命中精英敌人时，造成的伤害提高15%。","mechanics":[{"id":"breaker_stone"}],"build_tags":["elite","skill"],"sources":["shop","chest","reward"]},{"id":"relic_patrol_bell","name":"巡猎铃","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/relic_patrol_bell.png","flavor":"疾行施法在冒险途中悄然回应持有者。","flat":{},"mult":{},"desc":"疾行施法：冲刺后的3秒内，下一次施放技能的伤害提高12%，施放时消耗。","mechanics":[{"id":"patrol_bell"}],"build_tags":["dash","skill"],"sources":["shop","chest","reward"]},{"id":"relic_watch_button","name":"守望纽扣","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/relic_watch_button.png","flavor":"守望之盾在冒险途中悄然回应持有者。","flat":{},"mult":{},"desc":"守望之盾：施放技能时，为144范围内最近的至多3名没有护盾的友方单位各提供其自身最大生命8%的护盾，持续4秒。","mechanics":[{"id":"watch_button"}],"build_tags":["ally","cast","shield"],"sources":["shop","chest","reward"]},{"id":"bow_vine_short","name":"藤纹短弓","kind":"weapon","rarity":0,"cost":22,"icon":"tex:res://assets/characters/ilyua/items/bow_vine_short.png","flavor":"藤金纹顺着弓臂生长，轻得像一截新枝。","flat":{},"mult":{"attack":0.08},"desc":"攻击 +8%。伊露雅的轻便藤纹短弓。","weapon_class":"archer","requires_character":"ilyua","weapon":{"family":"bow","fx":"bow_vine_short","speed":560,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#a8dba2"},"sources":["shop","chest","reward"]},{"id":"bow_lake_light","name":"湖光猎弓","kind":"weapon","rarity":2,"cost":40,"icon":"tex:res://assets/characters/ilyua/items/bow_lake_light.png","flavor":"拉弦时有湖水般的浅蓝光沿箭羽流过。","flat":{},"mult":{"attack":0.22,"attack_speed":0.06,"mp_regen":0.06},"desc":"攻击 +22%、攻击速度 +6%、魔法回复速度 +6%。","weapon_class":"archer","requires_character":"ilyua","weapon":{"family":"bow","fx":"bow_lake_light","speed":560,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#b3e8ee"},"sources":["shop","chest","reward"]},{"id":"bow_spring_wind","name":"初春风弓","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/characters/ilyua/items/bow_spring_wind.png","flavor":"箭离弦时，春风会替它再找一条路。","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击 +30%、攻击速度 +8%、魔法回复速度 +12%。主箭首次命中有15%概率产生0.15倍攻击的风刃，冷却0.8秒。\n春鸣循环：主普攻首个有效命中积累春鸣，最多四层、6秒。四层时基础闪避结束消耗，释放72范围、0.4倍攻击风环，并使4秒内接下来三次主普攻首次命中追加0.18倍攻击追击，向附近一敌扩散0.12倍攻击；用完回复3MP。循环冷却5秒，附加伤害不暴击、不吸血、不递归。","weapon_class":"archer","requires_character":"ilyua","legendary_fx":"bow_spring_wind","mechanics":[{"id":"spring_wind_bow"}],"weapon":{"family":"bow","fx":"bow_spring_wind","speed":560,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#c2f4b7"},"sources":["shop","chest","reward"]},{"id":"staff_cloud_radiance","name":"圣云流光杖","kind":"weapon","rarity":3,"cost":60,"weight":0.25,"requires_character":"sylphiette","icon":"tex:res://assets/legendary_sets_v01/icons/staff_cloud_radiance.png","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击+30%、攻速+8%、MP回复+12%。普攻首个有效命中积攒一枚6秒圣云律印，最多三枚；三枚时下一个小技能消耗律印，伤害+20%，释放108范围、0.75倍攻击圣云光环，并获得8%生命护盾4秒；冷却3秒。大招不消耗律印。","flavor":"圣云纹饰把祷光轻轻托在掌心。","mechanics":[{"id":"cloud_staff"}],"sources":["shop","chest","reward"],"weapon_class":"mage","legendary_fx":"staff_cloud_radiance","weapon":{"family":"staff","fx":"staff_cloud_radiance","speed":430,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#fff0ca"}},{"id":"armor_cloud_rites","name":"圣云礼衣","kind":"armor","rarity":3,"cost":60,"weight":0.25,"requires_character":"sylphiette","icon":"tex:res://assets/legendary_sets_v01/icons/armor_cloud_rites.png","flat":{"max_hp":60},"mult":{"attack":0.1,"mp_regen":0.18},"desc":"生命+60、攻击+10%、MP回复+18%。护盾实际抵挡伤害后回复2MP，冷却3秒。","flavor":"圣云纹饰把祷光轻轻托在掌心。","mechanics":[{"id":"cloud_vestment"}],"sources":["shop","chest","reward"]},{"id":"accessory_eternal_ring","name":"永昼圣环","kind":"accessory","rarity":3,"cost":60,"weight":0.25,"requires_character":"sylphiette","icon":"tex:res://assets/legendary_sets_v01/icons/accessory_eternal_ring.png","flat":{"crit_chance":0.04},"mult":{"attack":0.14,"attack_speed":0.1,"mp_regen":0.18},"desc":"攻击+14%、攻速+10%、MP回复+18%、暴击+4%。普攻首个有效命中暴击时回复2MP，冷却1.5秒。","flavor":"圣云纹饰把祷光轻轻托在掌心。","mechanics":[{"id":"eternal_circlet"}],"sources":["shop","chest","reward"]},{"id":"armor_dusk_mantle","name":"归途影衣","kind":"armor","rarity":3,"cost":60,"weight":0.25,"requires_character":"xixifu","icon":"tex:res://assets/legendary_sets_v01/icons/armor_dusk_mantle.png","flat":{"max_hp":60},"mult":{"attack":0.12,"mp_regen":0.18},"desc":"生命+60、攻击+12%、MP回复+18%。主动契约物被敌方击杀后获得8%生命护盾4秒，冷却4秒；自然到期和离房不触发。","flavor":"灯还亮着，同行的人就不会散。","mechanics":[{"id":"dusk_mantle"}],"sources":["shop","chest","reward"]},{"id":"accessory_companion_bells","name":"同行契铃","kind":"accessory","rarity":3,"cost":60,"weight":0.25,"requires_character":"xixifu","icon":"tex:res://assets/legendary_sets_v01/icons/accessory_companion_bells.png","flat":{},"mult":{"attack":0.16,"attack_speed":0.12,"mp_regen":0.12},"desc":"攻击+16%、攻速+12%、MP回复+12%。普攻首个有效命中使当前友军攻速+12%持续3秒，冷却3秒；与同类加速取较强值。","flavor":"灯还亮着，同行的人就不会散。","mechanics":[{"id":"covenant_bells"}],"sources":["shop","chest","reward"]},{"id":"armor_lakeleaf_hunt","name":"湖叶游猎衣","kind":"armor","rarity":3,"cost":60,"weight":0.25,"requires_character":"ilyua","icon":"tex:res://assets/legendary_sets_v01/icons/armor_lakeleaf_hunt.png","flat":{"max_hp":55},"mult":{"attack_speed":0.1,"mp_regen":0.12,"move_speed":0.1},"desc":"生命+55、攻速+10%、MP回复+12%、移速+10%。基础闪避结束获得8%生命护盾2秒，冷却5秒。","flavor":"风穿过月叶，也把归路藏在铃声里。","mechanics":[{"id":"swallow_return"}],"sources":["shop","chest","reward"]},{"id":"accessory_moonwind_chime","name":"风铃月坠","kind":"accessory","rarity":3,"cost":60,"weight":0.25,"requires_character":"ilyua","icon":"tex:res://assets/legendary_sets_v01/icons/accessory_moonwind_chime.png","flat":{"crit_chance":0.08},"mult":{"attack":0.16,"mp_regen":0.18,"dash_cooldown":-0.12},"desc":"攻击+16%、MP回复+18%、暴击+8%、基础闪避冷却-12%。普攻首个有效命中暴击时返还当前闪避剩余冷却15%，冷却1秒。","flavor":"风穿过月叶，也把归路藏在铃声里。","mechanics":[{"id":"moonwind_chime"}],"sources":["shop","chest","reward"]},{"id":"staff_tide_prayer","name":"回澜祭杖","kind":"weapon","rarity":2,"cost":40,"weight":0.6,"icon":"tex:res://assets/content_v05/items/staff_tide_prayer.png","flat":{},"mult":{"attack":0.22,"attack_speed":0.06,"mp_regen":0.06},"mechanics":[{"id":"tide_staff"}],"build_tags":["走位联动"],"desc":"持有护盾时，三次主普攻首个有效命中释放42范围、0.2倍攻击澜环并回复2MP，冷却2秒。","flavor":"祷光在潮线里打了个结。","sources":["shop","chest","reward"],"requires_character":"sylphiette","weapon_class":"mage","weapon":{"family":"staff","fx":"wand_arcane","dmg":1,"cd":0.35,"speed":430,"reach":540,"shots":1,"sprite":"same","color":"#fff0ca"}},{"id":"staff_shadow_stitch","name":"影缝枝杖","kind":"weapon","rarity":2,"cost":40,"weight":0.6,"icon":"tex:res://assets/content_v05/items/staff_shadow_stitch.png","flat":{},"mult":{"attack":0.22,"attack_speed":0.06,"mp_regen":0.06},"mechanics":[{"id":"shadow_stitch"}],"build_tags":["走位联动"],"desc":"主普攻首个有效命中时，若目标108范围有友军，追加0.18倍攻击影缝伤害，冷却1.5秒。","flavor":"把同行的影子缝进同一条归路。","sources":["shop","chest","reward"],"requires_character":"xixifu","weapon_class":"mage","weapon":{"family":"staff","fx":"wand_arcane","dmg":1,"cd":0.35,"speed":430,"reach":540,"shots":1,"sprite":"same","color":"#fff0ca"}},{"id":"bow_willow","name":"柳弦短弓","kind":"weapon","rarity":2,"cost":40,"weight":0.6,"icon":"tex:res://assets/content_v05/items/bow_willow.png","flat":{},"mult":{"attack":0.22,"attack_speed":0.06,"mp_regen":0.06},"mechanics":[{"id":"willow_bow"}],"build_tags":["走位联动"],"desc":"移动中主普攻首个有效命中回复2MP，冷却2秒。","flavor":"枝条会弯，弓弦仍记得方向。","sources":["shop","chest","reward"],"requires_character":"ilyua","weapon_class":"archer","weapon":{"family":"bow","fx":"bow_willow","dmg":1,"cd":0.35,"speed":560,"reach":540,"shots":1,"sprite":"same","color":"#a8ebc9"}},{"id":"armor_oath_trace","name":"誓痕护衣","kind":"armor","rarity":2,"cost":40,"weight":0.6,"icon":"tex:res://assets/content_v05/items/armor_oath_trace.png","flat":{"max_hp":30},"mult":{"mp_regen":0.08},"mechanics":[{"id":"oath_cloak"}],"build_tags":["走位联动"],"desc":"自身护盾因实际承伤破裂时回复4MP，冷却5秒；自然到期不触发。","flavor":"衣角的旧誓言，从不要求你独自承受。","sources":["shop","chest","reward"]},{"id":"accessory_silver_return","name":"归航银坠","kind":"accessory","rarity":2,"cost":40,"weight":0.6,"icon":"tex:res://assets/content_v05/items/accessory_silver_return.png","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"mechanics":[{"id":"silver_return"}],"build_tags":["走位联动"],"desc":"基础闪避结束回复3MP，冷却5秒。","flavor":"不必每一次都走到风停的地方。","sources":["shop","chest","reward"]},{"id":"accessory_wind_listen","name":"听风护符","kind":"accessory","rarity":2,"cost":40,"weight":0.6,"icon":"tex:res://assets/content_v05/items/accessory_wind_listen.png","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"mechanics":[{"id":"wind_listen"}],"build_tags":["走位联动"],"desc":"主普攻首个有效命中距离自身超过144的目标，追加0.08倍攻击伤害，冷却1.25秒。","flavor":"隔着四格，风也能听见弦响。","sources":["shop","chest","reward"]},{"id":"relic_late_clock","name":"迟钟碎片","kind":"buff","rarity":1,"cost":28,"weight":0.8,"icon":"tex:res://assets/content_v05/items/relic_late_clock.png","flat":{},"mult":{},"mechanics":[{"id":"late_clock"}],"build_tags":["技能循环"],"desc":"主普攻首个有效命中，使剩余冷却最长的小技能缩短0.15秒，冷却1秒；不影响大招。","flavor":"它慢了一点，你却可以快一点。","sources":["shop","chest","reward"]},{"id":"relic_mist_dew","name":"雾露瓶","kind":"buff","rarity":1,"cost":28,"weight":0.8,"icon":"tex:res://assets/content_v05/items/relic_mist_dew.png","flat":{},"mult":{},"mechanics":[{"id":"mist_dew"}],"build_tags":["技能循环"],"desc":"自身生命低于50%时，小技能直接命中回复1%最大生命，冷却3秒；真实伤势仍无法恢复。","flavor":"瓶子里盛着森林没有喝完的晨露。","sources":["shop","chest","reward"]},{"id":"relic_half_star","name":"半枚航星","kind":"buff","rarity":1,"cost":28,"weight":0.8,"icon":"tex:res://assets/content_v05/items/relic_half_star.png","flat":{},"mult":{},"mechanics":[{"id":"half_star"}],"build_tags":["技能循环"],"desc":"基础闪避后5秒内下一次主普攻首个有效命中，回复2MP并追加0.1倍攻击伤害；冷却3秒，不储存。","flavor":"缺了一半，仍然知道哪里是家。","sources":["shop","chest","reward"]},{"id":"relic_lamp_tassel","name":"绒灯穗","kind":"buff","rarity":1,"cost":28,"weight":0.8,"icon":"tex:res://assets/content_v05/items/relic_lamp_tassel.png","flat":{},"mult":{},"mechanics":[{"id":"lamp_tassel"}],"build_tags":["技能循环"],"desc":"自身144范围内的友军有效直击敌人时回复1MP，全局冷却1秒。","flavor":"灯穗摇晃的时候，说明身边还有人。","sources":["shop","chest","reward"]},{"id":"relic_broken_verse","name":"断弦诗页","kind":"buff","rarity":1,"cost":28,"weight":0.8,"icon":"tex:res://assets/content_v05/items/relic_broken_verse.png","flat":{},"mult":{},"mechanics":[{"id":"broken_verse"}],"build_tags":["技能循环"],"desc":"主普攻首个有效命中暴击时，获得3%最大生命护盾2秒，冷却5秒；护盾取较强值。","flavor":"缺一行的诗，反倒留下了回声。","sources":["shop","chest","reward"]},{"id":"relic_leaf_page","name":"游叶书签","kind":"buff","rarity":1,"cost":28,"weight":0.8,"icon":"tex:res://assets/content_v05/items/relic_leaf_page.png","flat":{},"mult":{},"mechanics":[{"id":"leaf_page"}],"build_tags":["技能循环"],"desc":"6秒内成功施放三个不同小技能，强化4秒内下一次小技能直击，释放36范围、0.18倍攻击叶辉；冷却4秒。","flavor":"翻过三页，才知道下一阵风想说什么。","sources":["shop","chest","reward"]},{"id":"armor_storm_conductor","name":"雷律战衣","kind":"armor","rarity":3,"cost":60,"icon":"tex:res://assets/content_v06/icons/armor_storm_conductor.png","desc":"最大生命+50、攻击+10%、MP回复速度+12%。每次普攻首次有效命中积累一拍；相邻命中间隔不超过4秒。第四拍在目标周围72像素引发攻击力55%的雷律波，冷却1.5秒。冷却期间不积拍。","flavor":"四枚铜律针将奔雷约束在胸甲之内。","flat":{"max_hp":50},"mult":{"mp_regen":0.12,"attack":0.1},"mechanics":[{"id":"storm_conductor"}],"build_tags":["basic","rhythm","area"],"sources":["shop","chest","reward"]},{"id":"accessory_counterbeat","name":"逆拍银坠","kind":"accessory","rarity":2,"cost":40,"icon":"tex:res://assets/content_v06/icons/accessory_counterbeat.png","desc":"攻击+10%、MP回复速度+8%。成功施放小技能后，4秒内下一次普攻首次有效命中追加攻击力22%的装备伤害；重复施放刷新，不储存次数。","flavor":"逆向振动的银叉，始终为下一记回响留着空隙。","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"mechanics":[{"id":"counterbeat"}],"build_tags":["basic","skill","rhythm"],"sources":["shop","chest","reward"]},{"id":"armor_mana_reservoir","name":"深澜法袍","kind":"armor","rarity":3,"cost":60,"icon":"tex:res://assets/content_v06/icons/armor_mana_reservoir.png","desc":"最大生命+50、攻击+10%、MP回复速度+12%。成功施放小技能后，若剩余MP不少于50%，获得1层澜晶，最多3层，持续8秒。普攻首次有效命中消耗1层，追加攻击力30%的装备伤害并回复2MP，触发间隔0.8秒。","flavor":"法袍腰际的深蓝晶囊，封存着潮汐回流。","flat":{"max_hp":50},"mult":{"mp_regen":0.12,"attack":0.1},"mechanics":[{"id":"mana_reservoir"}],"build_tags":["mana","basic","skill"],"sources":["shop","chest","reward"]},{"id":"accessory_last_flame","name":"余烛护符","kind":"accessory","rarity":2,"cost":40,"icon":"tex:res://assets/content_v06/icons/accessory_last_flame.png","desc":"攻击+10%、MP回复速度+8%。成功施放小技能后，若剩余MP低于30%，获得最大生命8%的护盾，持续4秒，冷却8秒。","flavor":"最后一线烛光，也足以守住未尽的旅程。","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"mechanics":[{"id":"last_flame"}],"build_tags":["mana","shield","skill"],"sources":["shop","chest","reward"]},{"id":"armor_orbit_guard","name":"环星护衣","kind":"armor","rarity":2,"cost":40,"icon":"tex:res://assets/content_v06/icons/armor_orbit_guard.png","desc":"最大生命+30、MP回复速度+8%。角色144像素内的友军有效直击累计4拍，获得最大生命5%的护盾，持续4秒、冷却5秒。相邻拍间隔不超过4秒；同一时刻的范围攻击与齐射每0.2秒至多计一拍。","flavor":"衣襟银星彼此牵引，把旅伴的应答织成防线。","flat":{"max_hp":30},"mult":{"mp_regen":0.08},"mechanics":[{"id":"orbit_guard"}],"build_tags":["ally","rhythm","shield"],"sources":["shop","chest","reward"]},{"id":"accessory_cadence_prism","name":"交响棱心","kind":"accessory","rarity":3,"cost":60,"icon":"tex:res://assets/content_v06/icons/accessory_cadence_prism.png","desc":"攻击+20%、攻击速度+8%、MP回复速度+12%。普攻首次有效命中与主动技能直击交替发生时积累协鸣。首次命中确定声部，每次换声部积累1层；同声部连续命中不增加或刷新。3层后在目标周围72像素爆发攻击力65%的交响波，冷却2秒。每次有效换声部将宽限刷新为4秒。","flavor":"两束原本相背的光，在第三次交汇时成为同一首歌。","flat":{},"mult":{"attack":0.2,"mp_regen":0.12,"attack_speed":0.08},"mechanics":[{"id":"cadence_prism"}],"build_tags":["basic","skill","rhythm","area"],"sources":["shop","chest","reward"]},{"id":"relic_copper_metre","name":"铜律节拍器","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v06/icons/relic_copper_metre.png","desc":"普攻首次有效命中累计4拍后回复2MP，并使该目标减速20%、持续2秒，首领减半；相邻拍间隔不超过4秒，触发冷却1秒。 同名遗物持有1/2/3件时，数值效果为100%/150%/175%；次数、层数、范围与冷却不变。","flavor":"铜摆锤不催促旅人，只记下没有落空的节拍。","flat":{},"mult":{},"mechanics":[{"id":"copper_metre"}],"build_tags":["basic","mana","slow"],"sources":["shop","chest","reward"]},{"id":"relic_aftertone","name":"返音石","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/content_v06/icons/relic_aftertone.png","desc":"主动技能直击减速目标时，追加攻击力14%的装备伤害，全局冷却1.5秒。 同名遗物持有1/2/3件时，数值效果为100%/150%/175%；次数、层数、范围与冷却不变。","flavor":"石中回音总比最后一记钟声更迟抵达。","flat":{},"mult":{},"mechanics":[{"id":"aftertone"}],"build_tags":["skill","slow"],"sources":["shop","chest","reward"]},{"id":"relic_dew_battery","name":"露华蓄晶","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v06/icons/relic_dew_battery.png","desc":"成功施放小技能后，若剩余MP不少于50%，4秒内下一次普攻首次有效命中回复3MP，冷却3秒。强化不储存。 同名遗物持有1/2/3件时，数值效果为100%/150%/175%；次数、层数、范围与冷却不变。","flavor":"晨露在晶体中凝而不散，等待下一次拉弦。","flat":{},"mult":{},"mechanics":[{"id":"dew_battery"}],"build_tags":["mana","basic","skill"],"sources":["shop","chest","reward"]},{"id":"relic_dry_wick","name":"未熄灯芯","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v06/icons/relic_dry_wick.png","desc":"MP低于30%时，主动技能有效直击回复3MP，全局冷却3秒。 同名遗物持有1/2/3件时，数值效果为100%/150%/175%；次数、层数、范围与冷却不变。","flavor":"灯油将尽之时，灯芯仍记得如何燃烧。","flat":{},"mult":{},"mechanics":[{"id":"dry_wick"}],"build_tags":["mana","skill"],"sources":["shop","chest","reward"]},{"id":"relic_sentinel_thread","name":"守望纺线","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/content_v06/icons/relic_sentinel_thread.png","desc":"自身护盾因承伤耗尽后，4秒内下一次普攻首次有效命中追加攻击力18%的装备伤害，并为144像素内最近一名友军提供其最大生命8%的护盾、持续4秒。无友军时仍造成追加伤害，触发冷却4秒。 同名遗物持有1/2/3件时，数值效果为100%/150%/175%；次数、层数、范围与冷却不变。","flavor":"断裂的护幕并未消失，只是换了一位守望者。","flat":{},"mult":{},"mechanics":[{"id":"sentinel_thread"}],"build_tags":["shield","ally","basic"],"sources":["shop","chest","reward"]},{"id":"relic_wayfarer_score","name":"旅伴乐谱","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v06/icons/relic_wayfarer_score.png","desc":"角色144像素内友军的有效直击累计4拍后回复2MP，冷却2秒；相邻拍间隔不超过4秒，同一时刻的范围攻击与齐射每0.2秒至多计一拍。 同名遗物持有1/2/3件时，数值效果为100%/150%/175%；次数、层数、范围与冷却不变。","flavor":"谱上的空白声部，始终留给身旁的同行者。","flat":{},"mult":{},"mechanics":[{"id":"wayfarer_score"}],"build_tags":["ally","mana","rhythm"],"sources":["shop","chest","reward"]}]'''

const ILYUA_FALLBACK := '''[{"id":"bow_vine_short","name":"藤纹短弓","kind":"weapon","rarity":0,"cost":22,"icon":"tex:res://assets/characters/ilyua/items/bow_vine_short.png","flavor":"藤金纹顺着弓臂生长，轻得像一截新枝。","flat":{},"mult":{"attack":0.08},"desc":"攻击 +8%。伊露雅的轻便藤纹短弓。","weapon_class":"archer","requires_character":"ilyua","weapon":{"family":"bow","fx":"bow_vine_short","speed":560,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#a8dba2"},"sources":["shop","chest","reward"]},{"id":"bow_lake_light","name":"湖光猎弓","kind":"weapon","rarity":2,"cost":40,"icon":"tex:res://assets/characters/ilyua/items/bow_lake_light.png","flavor":"拉弦时有湖水般的浅蓝光沿箭羽流过。","flat":{},"mult":{"attack":0.22,"attack_speed":0.06,"mp_regen":0.06},"desc":"攻击 +22%、攻击速度 +6%、魔法回复速度 +6%。","weapon_class":"archer","requires_character":"ilyua","weapon":{"family":"bow","fx":"bow_lake_light","speed":560,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#b3e8ee"},"sources":["shop","chest","reward"]},{"id":"bow_spring_wind","name":"初春风弓","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/characters/ilyua/items/bow_spring_wind.png","flavor":"箭离弦时，春风会替它再找一条路。","flat":{},"mult":{"attack":0.30,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击 +30%、攻击速度 +8%、魔法回复速度 +12%。主箭首次命中有15%概率产生0.15倍攻击的风刃，冷却0.8秒。","weapon_class":"archer","requires_character":"ilyua","legendary_fx":"bow_spring_wind","mechanics":[{"id":"spring_wind_bow"}],"weapon":{"family":"bow","fx":"bow_spring_wind","speed":560,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#c2f4b7"},"sources":["shop","chest","reward"]}]'''

## ---------------- 从 data/items.json 读取 ----------------

static func _load_items_json() -> Array[Dictionary]:
	if not FileAccess.file_exists(ITEMS_JSON):
		print("[道具表] 没有 %s，用代码里的内置定义" % ITEMS_JSON)
		return []
	var text := FileAccess.get_file_as_string(ITEMS_JSON)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("[道具表] %s 解析失败（JSON 格式有错？），改用内置定义" % ITEMS_JSON)
		return []
	var out: Array[Dictionary] = []
	var problems: Array[String] = []
	for raw in (parsed as Dictionary).get("items", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item := _item_from_json(raw as Dictionary, problems)
		if not item.is_empty():
			out.append(item)
	print("[道具表] 从 %s 读取了 %d 件道具" % [ITEMS_JSON, out.size()])
	for message in problems:
		printerr("[道具表] ⚠ " + message)
	return out


static func _item_from_json(raw: Dictionary, problems: Array[String]) -> Dictionary:
	var id := str(raw.get("id", ""))
	if id.is_empty():
		problems.append("有一条道具没写 id，已跳过")
		return {}
	var kind := StringName(str(raw.get("kind", "buff")))
	if not KIND_NAMES.has(kind):
		problems.append("道具 %s 的 kind「%s」不认识（可用：buff/weapon/armor/accessory/potion）" % [id, kind])
		kind = &"buff"
	var icon := _icon_from_text(str(raw.get("icon", "")))
	if not ResourceLoader.exists(str(icon.get("tex", ""))):
		problems.append("道具 %s 的图标找不到：%s" % [id, raw.get("icon", "")])
	var item := {
		"id": StringName(id),
		"name": str(raw.get("name", id)),
		"desc": str(raw.get("desc", "")),
		"flavor": str(raw.get("flavor", "")),
		"kind": kind,
		"rarity": clampi(int(raw.get("rarity", 0)), 0, 3),
		"cost": maxi(0, int(raw.get("cost", 10))),
		"icon": icon,
		"flat": _stats_from_json(raw.get("flat", {})),
		"mult": _stats_from_json(raw.get("mult", {})),
	}
	# Keep build logic as data so saved IDs can resolve into the current catalogue.
	var mechanics: Array[Dictionary] = []
	for entry in raw.get("mechanics", []):
		if entry is Dictionary and not str(entry.get("id", "")).is_empty():
			mechanics.append((entry as Dictionary).duplicate(true))
	item["mechanics"] = mechanics
	var build_tags: Array[String] = []
	for tag in raw.get("build_tags", []):
		build_tags.append(str(tag))
	item["build_tags"] = build_tags
	for field in ["weapon_class","legendary_fx","requires_character"]:
		if raw.has(field):item[field]=str(raw[field])
	if raw.has("weight"):
		item["weight"] = maxf(0.0, float(raw["weight"]))
	# 召唤师装备：summon 段加成雇佣单位的属性（hp / attack / speed，按加法百分比叠加）
	if raw.has("summon"):
		var summon := {}
		for key in (raw["summon"] as Dictionary):
			summon[String(key)] = float((raw["summon"] as Dictionary)[key])
		item["summon"] = summon
	if raw.has("sources"):
		var sources: Array[StringName] = []
		for s in raw["sources"]:
			sources.append(StringName(str(s)))
		item["sources"] = sources
	if raw.has("weapon") and kind == &"weapon":
		item["weapon"] = _weapon_from_json(raw["weapon"], icon)
	if raw.has("effect") and kind == &"potion":
		var effect: Dictionary = (raw["effect"] as Dictionary).duplicate(true)
		effect["kind"] = StringName(str(effect.get("kind", "heal")))
		if effect.has("stat"):
			effect["stat"] = StringName(str(effect["stat"]))
		item["effect"] = effect
	return item


static func _stats_from_json(stats: Variant) -> Dictionary:
	var out := {}
	if typeof(stats) != TYPE_DICTIONARY:
		return out
	for key in (stats as Dictionary):
		out[StringName(str(key))] = float((stats as Dictionary)[key])
	return out


static func _icon_from_text(text: String) -> Dictionary:
	if text.begins_with("icons:"):
		return sprite_icon(ICON_DIR + text.substr("icons:".length()))
	if text.begins_with("sheet:"):
		return sheet_icon(int(text.substr("sheet:".length())))
	if text.begins_with("tex:"):
		return sprite_icon(text.substr("tex:".length()))
	return sheet_icon(ICON_GEM)


static func _weapon_from_json(raw: Variant, icon: Dictionary) -> Dictionary:
	var weapon: Dictionary = (raw as Dictionary).duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}
	# sprite = "same" 表示「用图标那张图作为装备素材」
	var sprite := str(weapon.get("sprite", "same"))
	weapon["sprite"] = str(icon.get("tex", "")) if sprite == "same" else sprite
	weapon["cd"] = maxf(0.05, float(weapon.get("cd", 1.0)))
	weapon["dmg"] = maxf(0.0, float(weapon.get("dmg", 0.5)))
	weapon["reach"] = maxf(50.0, float(weapon.get("reach", 500.0)))
	weapon["shots"] = maxi(1, int(weapon.get("shots", 1)))
	weapon["spread"] = deg_to_rad(float(weapon.get("spread_deg", 0.0)))
	weapon["speed"] = maxf(50.0, float(weapon.get("speed", 430.0)))
	weapon["color"] = Color(str(weapon.get("color", "ffffff")))
	weapon.erase("spread_deg")
	return weapon


static func by_id(id: StringName) -> Dictionary:
	for item in all():
		if item["id"] == id:
			return item
	return {}


static func rarity_color(rarity: int) -> Color:
	return Palette.RARITY[clampi(rarity, 0, Palette.RARITY.size() - 1)]


static func rarity_name(rarity: int) -> String:
	match rarity:
		0: return "普通"
		1: return "精良"
		2: return "稀有"
		_: return "传说"


static func kind_label(item: Dictionary) -> String:
	## 装备 / 遗物 / 药水 —— 三选一卡片和背包详情都靠它区分
	if item.get("hire_token", false):
		return "雇佣"
	var kind: StringName = item.get("kind", &"buff")
	if kind == &"weapon":
		return {"staff":"法杖","bow":"弓箭","sword":"刀剑","hammer":"战锤"}.get(str(item.get("weapon",{}).get("family","staff")),"武器")
	if kind == &"potion":
		return "药水"
	if kind == &"material":
		return "材料"
	if SLOTS.has(kind):
		return "装备"
	return "遗物"


static func kind_color(item: Dictionary) -> Color:
	if item.get("hire_token", false):
		return Color("7fd6a0")
	var kind: StringName = item.get("kind", &"buff")
	if kind == &"potion":
		return Color("7fd6a0")
	if SLOTS.has(kind):
		return Color("6fb3ff")
	return Color("e0b64a")


static func stat_lines(item: Dictionary) -> Array[String]:
	## 把 flat / mult 翻译成人看的文字，背包详情面板用
	var out: Array[String] = []
	for key: StringName in item.get("flat", {}):
		var value := float(item["flat"][key])
		var text := "%+.0f" % value
		if key in [&"crit_chance", &"crit_mult"]: text = "%+.0f%%" % (value * 100.0)
		elif key == &"lifesteal": text = "%+.0f 点生命（同名来源不叠加）" % value
		elif key == &"dash_cooldown": text = "%+.2f 秒" % value
		elif key == &"mp_regen": text = "%+.1f/秒" % value
		out.append("%s %s" % [STAT_NAMES.get(key, str(key)), text])
	for key: StringName in item.get("mult", {}):
		out.append("%s %+.0f%%" % [STAT_NAMES.get(key, str(key)), float(item["mult"][key]) * 100.0])
	return out


static func flavor_text(item: Dictionary) -> String:
	## 道具的「简介」：和数值说明分开的一句话，纯风味文本。
	return str(item.get("flavor", ""))


static func weapon_dps_factor(item: Dictionary) -> float:
	# Compatibility API: weapon-only attribute factor, never a second attack stream.
	if item.get("kind",&"")!=&"weapon":return 0.0
	return (1.0+float(item.get("mult",{}).get(&"attack",0.0)))*(1.0+float(item.get("mult",{}).get(&"attack_speed",0.0)))

static func weapon_lines(item: Dictionary) -> Array[String]:
	if item.get("kind",&"")!=&"weapon":return []
	var required_character:=str(item.get("requires_character",""))
	var role_text:="希希芙" if required_character=="xixifu" else ("伊露雅" if required_character=="ilyua" else ("魔法师 / 召唤师" if str(item.get("weapon_class","mage"))=="mage" else Characters.class_name_of(str(item.get("weapon_class","mage")))))
	var out:Array[String]=["适用角色："+role_text]
	out.append("手持武器 · 属性作用于普攻 · 独立攻击特效")
	if not can_equip(item):out.append("当前职业无法装备")
	return out

static func can_equip(item:Dictionary,class_id_value:="")->bool:
	var required_character := str(item.get("requires_character", ""))
	if not required_character.is_empty() and required_character != str(Characters.current_id()): return false
	if item.get("kind",&"")!=&"weapon":return true
	var wearer:=Characters.class_id() if class_id_value.is_empty() else class_id_value
	return str(item.get("weapon_class","mage"))==("mage" if wearer=="summoner" else wearer)

static func weight_of(item: Dictionary) -> float:
	## 产出权重：JSON 里写了 weight 就用它，没写就按稀有度算。
	## 想调「这件东西多常见」，改 weight 即可（越大越常出，0 = 不会自然产出）。
	if item.has("weight"):
		return maxf(0.0, float(item["weight"]))
	return _weight(int(item.get("rarity", 0)))


static func in_source(item: Dictionary, source: StringName) -> bool:
	if source==&"reward" and not (is_relic(item) or is_equippable(item)):return false
	if bool(item.get("retired",false)) or str(item.get("id","")) in ["spring_shoes","double_jump_charm","potion_spring"]:return false
	var required_character := str(item.get("requires_character", ""))
	if not required_character.is_empty() and required_character != str(Characters.current_id()): return false
	if not can_equip(item):return false
	if _state()!=null and _state().get("combat_mode")=="rooms" and source!=&"camp_shop" and not available_in_mode(item,"rooms"):return false
	## 产出渠道过滤：source 为 shop / chest / reward（空 = 不过滤）。
	## 想让某件道具只在宝箱出，就写 "sources": ["chest"]。
	if source == &"" or not item.has("sources"):
		return true
	for entry in item["sources"]:
		if StringName(entry) == source:
			return true
	return false

static func available_in_mode(item:Dictionary,_mode:String)->bool:
	return str(item.get("id","")) not in ["spring_shoes","double_jump_charm","potion_spring"]


static func roll_offers(
	count: int,
	rng: RandomNumberGenerator,
	equippable_chance := 0.0,
	source: StringName = &"",
	excluded_ids: Array[String] = []
) -> Array[Dictionary]:
	## 同种遗物跨商店、奖励和宝箱最多展示三次，未选择也计数。
	## equippable_chance：有多大概率把结果换成「可装备」类（宝箱用得上）
	var pool: Array[Dictionary] = []
	for item in all():
		if str(item.get("id","")) not in excluded_ids and in_source(item, source) and can_refresh(item) and (is_relic(item) or not owned(item)):
			pool.append(item)
	# 全都被拿过了：允许出重复（否则会抽空）
	if pool.size() < count:
		for item in all():
			if str(item.get("id","")) not in excluded_ids and in_source(item, source) and can_refresh(item) and not pool.has(item):
				pool.append(item)
	var out: Array[Dictionary] = []
	while out.size() < count and not pool.is_empty():
		var pick := _weighted_pick(pool, rng)
		out.append(pool[pick])
		pool.remove_at(pick)
	if not out.is_empty() and equippable_chance > 0.0 and rng.randf() < equippable_chance:
		var equippable: Array[Dictionary] = []
		for item in all():
			if str(item.get("id","")) not in excluded_ids and is_equippable(item) and in_source(item, source):
				equippable.append(item)
		if not equippable.is_empty():
			out[0] = equippable[rng.randi_range(0, equippable.size() - 1)]
	for item in out:
		record_refresh(item)
	return out


static func roll_random(
	rng: RandomNumberGenerator,
	only_equippable := false,
	source: StringName = &""
) -> Dictionary:
	var pool: Array[Dictionary] = []
	for item in all():
		if not in_source(item, source):
			continue
		if only_equippable and not is_equippable(item):
			continue
		if not only_equippable and is_equippable(item):
			continue
		if not can_refresh(item):
			continue
		# 遗物允许重复出现；装备优先给未持有的。
		if not is_relic(item) and owned(item):
			continue
		pool.append(item)
	if pool.is_empty():
		# 这一类全拿过了：退回"可以重复"的池子，至少还能给点东西
		for item in all():
			if not in_source(item, source):
				continue
			if only_equippable != is_equippable(item) or not can_refresh(item):
				continue
			pool.append(item)
	if pool.is_empty():
		return {}
	var chosen: Dictionary = pool[_weighted_pick(pool, rng)]
	record_refresh(chosen)
	return chosen


static func is_relic(item: Dictionary) -> bool:
	return item.get("kind", &"") == &"buff"


static func can_refresh(item: Dictionary) -> bool:
	if not is_relic(item): return true
	var state := _state()
	if state == null: return true
	var counts: Dictionary = state.get("run_refreshes")
	return int(counts.get(str(item.get("id", "")), 0)) < 3


static func record_refresh(item: Dictionary) -> void:
	if not is_relic(item): return
	var state := _state()
	if state == null: return
	var counts: Dictionary = state.get("run_refreshes")
	var id := str(item.get("id", ""))
	counts[id] = mini(3, int(counts.get(id, 0)) + 1)


static func owned(item: Dictionary) -> bool:
	## 背包里已有、或者正装在身上 —— 都算"已有"，抽奖时跳过
	var id: StringName = item.get("id", &"")
	if id == &"":
		return false
	if _state()==null:return false
	for have in _state().get("items"):
		if have.get("id", &"") == id:
			return true
	for slot in SLOTS:
		var equipped: Dictionary = _state().call("equipped",StringName(slot))
		if not equipped.is_empty() and equipped.get("id", &"") == id:
			return true
	return false


static func sell_price(item: Dictionary) -> int:
	## 售卖价：基础价的一半（越贵的东西卖得越多），最低 4 金
	return maxi(4, int(round(float(item.get("cost", 10)) * 0.5)))


static func _weighted_pick(pool: Array[Dictionary], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for item in pool:
		total += weight_of(item)
	if total <= 0.0:
		return rng.randi_range(0, pool.size() - 1)
	var roll := rng.randf() * total
	for i in pool.size():
		roll -= weight_of(pool[i])
		if roll <= 0.0:
			return i
	return pool.size() - 1


static func _weight(rarity: int) -> float:
	match rarity:
		0: return 6.0
		1: return 3.0
		2: return 1.4
		_: return 0.5

static func _state() -> Node:
	# Resolve runtime context without a compiled backedge to the GameState autoload.
	var loop=Engine.get_main_loop()
	return loop.root.get_node_or_null("GameState") if loop is SceneTree else null
