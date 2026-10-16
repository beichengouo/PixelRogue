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

const FALLBACK_CATALOGUE := '''[{"cost":40.0,"desc":"雇佣的怪物与佣兵：生命 +25%、攻击 +20%","flat":{},"flavor":"铃舌由两片相互追逐的银叶铸成，清响落下时，独行者的脚步便有了回声。它从不命令谁献出生命，只提醒契约两端的人：有些道路，原本可以一起走完。即使漫长岁月抹去了最初的铭文，守护的意义也仍会在新的相逢中被辨认。","icon":"tex:res://assets/round5/items/summoner_bell.png","id":"summoner_bell","kind":"buff","mult":{},"name":"召唤师的铃铛","rarity":2.0,"summon":{"hp":0.25,"attack":0.2}},{"cost":44.0,"desc":"雇佣的怪物与佣兵：攻击 +15%、移动速度 +20%","flat":{},"flavor":"指环内侧没有主人的姓名，只有一圈尚未合拢的誓文。立约者把最后一笔留给同行之人，因为忠诚不该是一道封死的门，而应是危难之际仍愿作出的选择。回廊保存着它走过的路，也为尚未抵达的明天留着一盏安静的灯。","icon":"tex:res://assets/round5/items/contract_ring.png","id":"contract_ring","kind":"accessory","mult":{},"name":"契约指环","rarity":2.0,"summon":{"attack":0.15,"speed":0.2}},{"cost":22.0,"desc":"攻击力 +6","flat":{"attack":6.0},"flavor":"缺口经过重新锻打，皮绳仍牢牢缠着剑柄。这是旅人踏上长路时最朴素的勇气。","icon":"tex:res://assets/round5/items/iron_sword.png","id":"iron_sword","kind":"buff","mult":{},"name":"铁剑","rarity":0.0},{"cost":26.0,"desc":"攻击力 +18%","flat":{},"flavor":"细密银砂封在不起眼的石面里，刃口擦过便有晨星般的碎光落下。守夜的人相信，值得托付性命的锋芒，不出自一次辉煌，而来自每次出发前不曾省略的准备。","icon":"tex:res://assets/round5/items/whetstone.png","id":"whetstone","kind":"buff","mult":{"attack":0.18},"name":"磨刀石","rarity":1.0},{"cost":20.0,"desc":"移动速度 +12%","flat":{},"flavor":"灰白羽绒藏在靴口，旧皮底轻贴地面。穿上它的人，学会让脚步先于恐惧启程。","icon":"tex:res://assets/round5/items/feather_boots.png","id":"feather_boots","kind":"buff","mult":{"move_speed":0.12},"name":"轻羽靴","rarity":0.0},{"cost":20.0,"desc":"已退役的旧旅途遗物，不再产出。","flat":{},"flavor":"古老工坊留下的奇巧旧物，铜簧已经沉寂，仍保存着旅人曾经跃过险境的记忆。","icon":"tex:res://assets/round5/items/spring_shoes.png","id":"spring_shoes","kind":"buff","mult":{},"name":"弹簧鞋","rarity":0.0,"sources":[],"retired":true},{"cost":22.0,"desc":"最大生命 +25","flat":{"max_hp":25.0},"flavor":"锤痕一层叠着一层，正中护片却平整如初。无名铁匠把最可靠的祝福留在心前。","icon":"tex:res://assets/round5/items/guardian_mail.png","id":"guardian_mail","kind":"buff","mult":{},"name":"护心甲","rarity":0.0},{"cost":30.0,"desc":"最大生命 +45，移动速度 -8%","flat":{"max_hp":45.0},"flavor":"厚革上刻着比人类文字更古老的山纹，铜扣被漫长岁月磨得温润。传承它的人未必拥有巨人的身形，却都懂得在风暴来到时，先替身后的人站稳。","icon":"tex:res://assets/round5/items/giant_belt.png","id":"giant_belt","kind":"buff","mult":{"move_speed":-0.08},"name":"巨人腰带","rarity":1.0},{"cost":32.0,"desc":"普攻命中回复 1 点生命（同名来源不重复叠加）","flat":{"lifesteal":1.0},"flavor":"暗红纹路蜿蜒穿过木牌，像树根寻回失落的泉水。它记得创伤，却不以创伤为荣耀；真正值得铭刻的，是受伤之后依然没有放下武器的那只手。","icon":"tex:res://assets/round5/items/blood_charm.png","id":"blood_charm","kind":"buff","mult":{},"name":"血纹护符","rarity":1.0},{"cost":28.0,"desc":"受击时反伤 10 点","flat":{"thorns":10.0},"flavor":"细棘沿着斗篷内衬生长，外侧反而柔软得像暮色。林地守望者把它披给归途上的伙伴，借此告诉黑暗：温柔从来不意味着毫无锋芒。","icon":"tex:res://assets/round5/items/thorn_cloak.png","id":"thorn_cloak","kind":"buff","mult":{},"name":"荆棘斗篷","rarity":1.0},{"cost":34.0,"desc":"暴击率 +15%，暴击伤害 +50%","flat":{"crit_chance":0.15,"crit_mult":0.5},"flavor":"银针划出的窄月几乎没有重量，唯有握在掌心时，才会显出冷冽的轮廓。它不赞美无谓的杀戮，而纪念那些在最短的一瞬里截断灾厄、让旁人得以看见下一个黎明的无名之人。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。","icon":"tex:res://assets/round5/items/assassin_mark.png","id":"assassin_mark","kind":"buff","mult":{},"name":"刺客印记","rarity":2.0},{"cost":18.0,"desc":"金币收益 +35%","flat":{},"flavor":"钱币两面都磨去了君王的面容，唯有掌心留下的温度，仍被旅人称作好运。","icon":"tex:res://assets/round5/items/lucky_coin.png","id":"lucky_coin","kind":"buff","mult":{"coin_gain":0.35},"name":"幸运币","rarity":0.0},{"cost":22.0,"desc":"冲刺冷却 -30%","flat":{},"flavor":"靴侧的青色缝线已经褪色，鞋尖却始终朝向前路，像一封尚未寄出的远行书。","icon":"tex:res://assets/round5/items/gale_boots.png","id":"gale_boots","kind":"buff","mult":{"dash_cooldown":-0.3},"name":"疾风之靴","rarity":0.0},{"cost":36.0,"desc":"已退役的旧旅途遗物，不再产出。","flat":{},"flavor":"断裂的风纹仍封存在这枚退役符片中，它属于另一段旅途。如今它安静躺在旧行囊底，见证曾有人不肯接受第一次坠落，也见证冒险终会学会用新的方式越过旧日的深渊。回廊保存着它走过的路，也为尚未抵达的明天留着一盏安静的灯。","icon":"tex:res://assets/round5/items/double_jump_charm.png","id":"double_jump_charm","kind":"buff","mult":{},"name":"二段跳符","rarity":2.0,"sources":[],"retired":true},{"cost":28.0,"desc":"攻击力 +25%，最大生命 -15","flat":{"max_hp":-15.0},"flavor":"赤色结晶里凝着一簇难以平息的火，连沉默都显得炽热。它并非献给莽撞者的颂歌，而是献给所有在退无可退之时，仍敢以自身回应命运的人。","icon":"tex:res://assets/round5/items/berserk_blood.png","id":"berserk_blood","kind":"buff","mult":{"attack":0.25},"name":"狂暴之血","rarity":1.0},{"cost":44.0,"desc":"最大生命 +30，普攻命中回复 1 点生命（同名来源不重复叠加）","flat":{"lifesteal":1.0,"max_hp":30.0},"flavor":"焰羽已经化作余灰，心石里却仍有一线赤金缓缓搏动。旧日的守望者曾把它举向无星的长夜，不求免于焚烧，只求被自己护在身后的人能够平安离开。火光最终熄灭，誓言却没有随之散去。如今每一位接过它的旅人，都能听见那份沉静而炽烈的回答：苦难不值得被赞颂，穿过苦难后仍愿守护的心，才值得被铭记。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。","icon":"tex:res://assets/round5/items/phoenix_heart.png","id":"phoenix_heart","kind":"buff","mult":{},"name":"不死鸟之心","rarity":3.0},{"cost":46.0,"desc":"攻击力 +40%，暴击率 +8%","flat":{"crit_chance":0.08},"flavor":"刃背没有王室的纹章，剑锷上也没有胜者的桂冠，只有一道被反复磨亮的旧刻痕。它曾被用来裁断无法停歇的守护命令，因而承受过许多畏惧与误解。持剑者没有为自己辩解，只把锋刃指向了真正囚禁众人的枷锁。世人记住了判决落下的瞬间，剑却记得那场判决之后，终于能够重新迈出的脚步。真正值得传承的力量，从不止于赢下一场战斗，更在于为何继续前行。","icon":"tex:res://assets/round5/items/executioner.png","id":"executioner","kind":"buff","mult":{"attack":0.4},"name":"处刑者之刃","rarity":3.0},{"cost":30.0,"desc":"攻击 +12%，攻击速度 +10% · 紫晶环刃弹","flat":{},"flavor":"杖心嵌着一枚略显浑浊的蓝晶，细碎星纹由握柄一路延伸到顶端。许多伟大的法术，都曾从这样一根朴素木杖开始；第一束微光，也有照亮长夜的资格。","icon":"tex:res://assets/round5/items/wand_arcane.png","id":"wand_arcane","kind":"weapon","mult":{"attack":0.12,"attack_speed":0.1},"name":"秘法魔杖","rarity":1.0,"weapon":{"family":"staff","fx":"wand_arcane","speed":460,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#c9a8ff"},"weapon_class":"mage"},{"cost":34.0,"desc":"攻击 +25%，暴击率 +3% · 烈焰彗星弹","flat":{"crit_chance":0.03},"flavor":"赤晶与焦木之间封着一圈安静的火，既不躁动，也不肯熄灭。它曾是守夜者引路的灯，后来才成为抵御侵袭的武器。火焰所照见的不是征服，而是黑暗退去后仍然完整的归途。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。","icon":"tex:res://assets/round5/items/staff_fire.png","id":"staff_fire","kind":"weapon","mult":{"attack":0.25},"name":"火焰法杖","rarity":2.0,"weapon":{"family":"staff","fx":"staff_fire","speed":430,"reach":560,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#ff9a3d"},"weapon_class":"mage"},{"cost":36.0,"desc":"攻击 +12%，暴击率 +4% · 翠羽箭","flat":{"crit_chance":0.04},"flavor":"弓身留着细致的手工刨痕，弦扣被林间露水洗成柔和的银色。它不会替猎手决定何时松弦，只把每一次稳健的呼吸，忠实地化作穿过枝叶的箭。","icon":"tex:res://assets/round5/items/bow_wood.png","id":"bow_wood","kind":"weapon","mult":{"attack":0.12},"name":"猎手长弓","rarity":1.0,"weapon":{"family":"bow","fx":"bow_wood","speed":560,"reach":700,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#a8ffb0"},"weapon_class":"archer"},{"cost":32.0,"desc":"攻击 +16%，攻击速度 +12% · 银蓝刃光","flat":{},"flavor":"短刃藏在沉默的鞘中，握柄纹路已被指掌磨平。它没有长兵器的声势，却能在最逼仄的险境里为旅人守住最后一点余地。真正精确的锋芒，总懂得等待值得出手的时刻。旧日的记载可以残缺，后来者却仍拥有亲手写下下一页的权利。","icon":"tex:res://assets/round5/items/dagger_iron.png","id":"dagger_iron","kind":"weapon","mult":{"attack":0.16,"attack_speed":0.12},"name":"铁匕首","rarity":2.0,"weapon":{"family":"sword","fx":"dagger_iron","speed":430,"reach":76,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#a2d4ff"},"weapon_class":"warrior"},{"cost":46.0,"desc":"攻击 +42%，生命上限 +25，暴击伤害 +20%，攻击速度 −8% · 秘金碎岩锤光","flat":{"max_hp":25,"crit_mult":0.2},"flavor":"秘金并不比星光更轻，这柄战锤却把沉重铸成了庄严。锤面刻着相互咬合的岩纹，仿佛大地把自己的脊骨交给了凡人。每一道裂痕都来自一次不得不接下的冲击，每一片金屑都曾照亮濒临崩塌的防线。它不要求持有者成为无坚不摧的英雄，只要求那只举起战锤的手，在该守住的地方不再后退。那份誓约没有被写在高塔之上，而被留在仍然愿意向前的凡人手中。愿持有它的人记得来路的重量，也记得自己始终可以选择怎样抵达远方。","icon":"tex:res://assets/round5/items/warhammer_gold.png","id":"warhammer_gold","kind":"weapon","mult":{"attack":0.42,"attack_speed":-0.08},"name":"秘金战锤","rarity":3.0,"weapon":{"family":"hammer","fx":"warhammer_gold","speed":430,"reach":98,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#ffe066"},"weapon_class":"warrior"},{"cost":32.0,"desc":"最大生命 +50，移动速度 -4%","flat":{"max_hp":50},"flavor":"深色铁片层层叠合，肩带上还留着手工缝补的痕迹。它没有华贵的纹章，却曾无数次把利刃挡在最重要的位置之外；平凡的坚固，也足以成为一段传奇的开端。","icon":"tex:res://assets/content_v07/legacy/plate_mail.png","id":"plate_mail","kind":"armor","mult":{"move_speed":-0.04},"name":"铁壁胸甲","rarity":1.0},{"cost":38.0,"desc":"受击反伤 +16，最大生命 +20","flat":{"max_hp":20.0,"thorns":16.0},"flavor":"胸甲夹层里的棱晶映着冷紫光，旧伤痕被重新纳入整齐的甲纹。锻造者没有试图抹去它经历过的冲击，而是让每一道伤痕都成为下一次抵御的凭据。守住自己，也是在为反击保留答案。愿持有它的人记得来路的重量，也记得自己始终可以选择怎样抵达远方。","icon":"tex:res://assets/content_v07/legacy/reactive_plating.png","id":"reactive_plating","kind":"armor","mult":{},"name":"反应装甲","rarity":2.0},{"cost":30.0,"desc":"最大生命 +25，移动速度 +8%，魔法回复速度 +8%","flat":{"max_hp":25},"flavor":"深蓝布面缀着稀疏银线，展开时仿佛一张仍未绘完的星图。流浪的施法者把家乡的夜空缝在衣角，走得再远，也不会忘记最初为何追逐光明。","icon":"tex:res://assets/round5/items/mage_robe.png","id":"mage_robe","kind":"armor","mult":{"move_speed":0.08,"mp_regen":0.08},"name":"游星法袍","rarity":1.0},{"cost":30.0,"desc":"暴击率 +12%","flat":{"crit_chance":0.12},"flavor":"一缕秘银托起澄澈的蓝晶，像掌心中尚未落下的星。它曾挂在无名学徒的胸前，陪伴过许多个没有成果的夜晚，也见证第一道被认真完成的咒文。","icon":"tex:res://assets/content_v07/legacy/crystal_pendant.png","id":"crystal_pendant","kind":"accessory","mult":{},"name":"秘银吊坠","rarity":1.0},{"cost":34.0,"desc":"普攻命中回复 1 点生命（同名来源不重复叠加）","flat":{"lifesteal":1.0},"flavor":"红色药液在温润的囊瓶里微微晃动，金属扣环始终保留着草木的清气。采药者从不把它称为奇迹，因为每一份及时递出的援手，都来自有人在平安之时认真准备过。回廊保存着它走过的路，也为尚未抵达的明天留着一盏安静的灯。","icon":"tex:res://assets/content_v07/legacy/life_ampoule.png","id":"life_ampoule","kind":"accessory","mult":{},"name":"生命药囊","rarity":2.0},{"cost":36.0,"desc":"攻击力 +30%，最大生命 -10","flat":{"max_hp":-10.0},"flavor":"骨面上残存的暗纹早已失去完整语句，眼窝却仍映出幽微的紫光。人们畏惧它承载的旧诅咒，也有人从那片沉默中读出了另一种警告：不要把无法理解的悲伤，轻易变成束缚后来者的律法。愿持有它的人记得来路的重量，也记得自己始终可以选择怎样抵达远方。","icon":"tex:res://assets/round5/items/cursed_skull.png","id":"cursed_skull","kind":"accessory","mult":{"attack":0.3},"name":"诅咒骷髅","rarity":2.0},{"cost":26.0,"desc":"金币收益 +40%","flat":{},"flavor":"磨圆的护符像一枚小小的路标，细链上系着来自不同旅途的旧结。它没有替谁选定结局，只提醒持有者：那些看似偶然的相逢，也值得被郑重珍藏。","icon":"tex:res://assets/round5/items/lucky_charm.png","id":"lucky_charm","kind":"accessory","mult":{"coin_gain":0.4},"name":"幸运护符","rarity":1.0},{"cost":34.0,"desc":"暴击率 +15%，暴击伤害 +40%","flat":{"crit_chance":0.15,"crit_mult":0.4},"flavor":"戒面是一枚不肯反射全貌的锐晶，唯有转到恰好的角度，才会亮起锋利的白芒。老练的旅人用它纪念一次准确的判断，而不是一次侥幸；机会从来短暂，准备却可以漫长。回廊保存着它走过的路，也为尚未抵达的明天留着一盏安静的灯。","icon":"tex:res://assets/round5/items/crit_ring.png","id":"crit_ring","kind":"accessory","mult":{},"name":"暴击指环","rarity":2.0},{"cost":44.0,"desc":"攻击力 +20%，最大生命 +20，暴击率 +6%，魔法回复速度 +10%","flat":{"max_hp":20,"crit_chance":0.06},"flavor":"诸色宝石围成一轮尚未沉落的星环，王冠内侧却没有刻下任何王者的名字。它曾被供奉在空无一人的高座上，象征无人能够拒绝的荣耀；后来，一个旅人把它带回了仍有笑声的灯下。华美因此有了新的意义：不再使众人向某个人俯首，而是提醒佩戴者，真正的尊荣，应当容得下每一颗不愿屈服的心。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。","icon":"tex:res://assets/round5/items/gem_crown.png","id":"gem_crown","kind":"accessory","mult":{"attack":0.2,"mp_regen":0.1},"name":"宝石王冠","rarity":3.0,"legendary_fx":"gem_crown"},{"cost":14.0,"desc":"立刻回复 45 点生命","effect":{"amount":45.0,"kind":"heal"},"flat":{},"flavor":"温热的红色药水，闻起来像草药糖。","icon":"tex:res://assets/round5/items/potion_health.png","id":"potion_health","kind":"potion","mult":{},"name":"治疗药剂","rarity":0.0},{"cost":18.0,"desc":"20 秒内攻击力 +35%","effect":{"duration":20.0,"kind":"buff","stat":"attack","value":0.35},"flat":{},"flavor":"紫色液体里有细小的光点在打转。","icon":"tex:res://assets/round5/items/potion_arcane.png","id":"potion_arcane","kind":"potion","mult":{},"name":"秘法药剂","rarity":1.0},{"cost":16.0,"desc":"立刻回复 40 点魔法值","effect":{"amount":40.0,"kind":"mana"},"flat":{},"flavor":"冰凉的青绿药水，喝下去脚步会变轻。","icon":"tex:res://assets/round5/items/potion_energy.png","id":"potion_energy","kind":"potion","mult":{},"name":"能量药剂","rarity":1.0},{"cost":16.0,"desc":"25 秒内反伤 +20","effect":{"duration":25.0,"kind":"buff","stat":"thorns","value":20.0},"flat":{},"flavor":"瓶壁结着一层薄霜，握久了指尖发麻。","icon":"tex:res://assets/round5/items/potion_frost.png","id":"potion_frost","kind":"potion","mult":{},"name":"冰霜药剂","rarity":1.0},{"id":"traveler_leather","name":"旅人皮甲","kind":"armor","rarity":0,"cost":24,"flat":{"max_hp":20},"mult":{"move_speed":0.05},"desc":"最大生命 +20，移动速度 +5%","flavor":"软革与旧布拼成轻便护衣，针脚并不齐整，却认真包住了每一处容易受伤的地方。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/traveler_leather.png"},{"id":"watcher_cloth","name":"守夜布衣","kind":"armor","rarity":0,"cost":24,"flat":{"max_hp":30},"mult":{},"desc":"最大生命 +30","flavor":"衣领染着淡淡灯烟，袖口经过仔细补缀。漫长守望里留下的暖意，比纹章更可靠。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/watcher_cloth.png"},{"id":"thorn_vest","name":"荆棘背心","kind":"armor","rarity":1,"cost":30,"flat":{"max_hp":15,"thorns":10},"mult":{},"desc":"最大生命 +15，反伤 +10","flavor":"硬韧藤丝织入内衬，细小棘纹藏在不起眼的接缝里。林地不总以鲜花回应来者，有时它递出的善意，是让善良的人也拥有保护自己的锋芒。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/thorn_vest.png"},{"id":"feather_coat","name":"轻羽外套","kind":"armor","rarity":1,"cost":28,"flat":{"max_hp":25},"mult":{"move_speed":0.09},"desc":"最大生命 +25，移动速度 +9%","flavor":"细羽缝在外套里层，动作间只露出一线轻柔银白。它曾陪伴信使穿过无数阴雨，衣角虽旧，带往远方的消息却从未因风暴而失约。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/feather_coat.png"},{"id":"wind_cloak","name":"风行斗篷","kind":"armor","rarity":2,"cost":36,"flat":{"max_hp":35},"mult":{"move_speed":0.1,"dash_cooldown":-0.15},"desc":"最大生命 +35，移动速度 +10%，冲刺冷却 -15%","flavor":"青灰披风的下摆留着水雾与长草的气息，暗纹仿佛一阵尚未散去的风。它属于始终知道自己为何启程的行者：路可以迂回，方向可以暂缓，前行的意志却不必因此交给他人。它所承载的光并不属于某个被选中的名字，而属于每一次自由而郑重的决定。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/wind_cloak.png"},{"id":"starlight_plate","name":"星辉战甲","kind":"armor","rarity":3,"cost":46,"flat":{"max_hp":50,"thorns":8},"mult":{"attack":0.15,"move_speed":-0.05,"mp_regen":0.15},"desc":"最大生命 +50，反伤 +8，攻击力 +15%，移动速度 -5%，魔法回复速度 +15%","flavor":"碎星被熔入银蓝甲片，光纹像一道道守在夜色之前的关隘。它没有经历过凯旋的检阅，却始终保存着战线最深处的温度。曾有旅人以这身沉重的铠甲接住崩落的石梁，待最后一个同伴穿过出口，才终于允许自己跪下喘息。后人赞颂那一夜的星辉，甲胄所记住的，却只是一个谁也不肯落下的承诺。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。真正值得传承的力量，从不止于赢下一场战斗，更在于为何继续前行。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/starlight_plate.png","legendary_fx":"starlight_plate"},{"id":"eagle_badge","name":"鹰眼徽章","kind":"accessory","rarity":0,"cost":24,"flat":{"crit_chance":0.08},"mult":{},"desc":"暴击率 +8%","flavor":"铜鹰的翅尖已被磨圆，眼中的细小亮点仍朝向远处，替谨慎的旅人守住视线。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/eagle_badge.png"},{"id":"journey_bell","name":"旅途铜铃","kind":"accessory","rarity":0,"cost":22,"flat":{},"mult":{"move_speed":0.06},"desc":"移动速度 +6%","flavor":"铃身刻着一截弯曲的小路，轻轻摇响时，仿佛有人在灯火另一端回应你的名字。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/journey_bell.png"},{"id":"merchant_purse","name":"行商钱袋","kind":"accessory","rarity":1,"cost":28,"flat":{"max_hp":10},"mult":{"coin_gain":0.25},"desc":"最大生命 +10，金币收益 +25%","flavor":"袋口的双重绳结保留着旧商路的习惯，内衬缝着一枚不起眼的铜星。它装过货币，也装过一次及时的相助；旅途的富足，从来不只取决于袋中的声响。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/merchant_purse.png"},{"id":"guardian_brooch","name":"守护胸针","kind":"accessory","rarity":1,"cost":30,"flat":{"max_hp":20,"thorns":6},"mult":{},"desc":"最大生命 +20，反伤 +6","flavor":"银枝把一片温润护石托在衣领前，细小裂纹像旧日潮痕。有人把它留给即将出发的友人，没有说出挽留的话，只认真替对方扣好了最后一道别针。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/guardian_brooch.png"},{"id":"wind_ring","name":"疾风指环","kind":"accessory","rarity":2,"cost":34,"flat":{},"mult":{"dash_cooldown":-0.2,"move_speed":0.05},"desc":"冲刺冷却 -20%，移动速度 +5%","flavor":"戒面上的风纹始终朝着同一个方向，内圈却被细心磨得十分圆润。它不催促任何人仓促离开，而纪念那些明知前路艰难，仍愿凭自己的意志向前迈出一步的人。它所承载的光并不属于某个被选中的名字，而属于每一次自由而郑重的决定。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/wind_ring.png"},{"id":"morningstar_pendant","name":"晨星坠饰","kind":"accessory","rarity":3,"cost":44,"flat":{"crit_mult":0.25,"crit_chance":0.1},"mult":{"attack":0.15,"mp_regen":0.1},"desc":"暴击伤害 +25%，暴击率 +10%，攻击力 +15%，魔法回复速度 +10%","flavor":"黎明之前最后一束星光，被古老秘银稳稳托在胸前。坠饰的光辉并不耀眼，却曾陪伴迷途者走过最漫长的一段夜路。人们后来为它编出许多宏伟的来历，它始终没有回应。也许真正值得流传的，不过是一次不被遗忘的指引：当群星逐一隐去，愿你仍能记得，天光正在看不见的地方缓缓到来。愿持有它的人记得来路的重量，也记得自己始终可以选择怎样抵达远方。","sources":["shop","chest","reward"],"icon":"tex:res://assets/round5/items/morningstar_pendant.png","legendary_fx":"morningstar_pendant"},{"id":"relic_moon_compass","name":"月弧罗盘","kind":"buff","rarity":0,"cost":20,"desc":"暴击率 +4%","flat":{"crit_chance":0.04},"mult":{},"flavor":"指针绕着一弯银月轻轻颤动，刻痕虽浅，仍为踏入陌路的人保存着出发时的方向。","icon":"tex:res://assets/camp_inventory/relic_moon_compass.tres"},{"id":"relic_leaf_brooch","name":"翠叶胸章","kind":"buff","rarity":0,"cost":22,"desc":"生命上限 +18，移动速度 +4%","flat":{"max_hp":18},"mult":{"move_speed":0.04},"flavor":"一片铜叶被旧丝带认真系在胸前，叶脉里残留的绿意，是林地最安静的祝愿。","icon":"tex:res://assets/camp_inventory/relic_leaf_brooch.tres"},{"id":"relic_rose_hourglass","name":"蔷薇沙漏","kind":"buff","rarity":1,"cost":26,"desc":"冲刺冷却 −12%","flat":{},"mult":{"dash_cooldown":-0.12},"flavor":"淡红细砂穿过收窄的琉璃，像花瓣在暮色中缓缓归根。它从不替人追回失去的时间，却让每一次重新准备，都多了一份不被慌乱夺走的从容。","icon":"tex:res://assets/camp_inventory/relic_rose_hourglass.tres"},{"id":"relic_star_lantern","name":"星灯遗物","kind":"buff","rarity":1,"cost":30,"desc":"攻击 +12%，生命上限 +12","flat":{"max_hp":12},"mult":{"attack":0.12},"flavor":"残缺灯罩护着一簇安静的星火，提环早已被无数掌心磨亮。它没有记录同行者的功业，只在每个停下歇息的夜里，替他们保留一处可以放心靠近的光。","icon":"tex:res://assets/camp_inventory/relic_star_lantern.tres"},{"id":"relic_swallow_quill","name":"青燕羽笔","kind":"buff","rarity":1,"cost":26,"desc":"移动速度 +6%","flat":{},"mult":{"move_speed":0.06},"flavor":"羽尖染着淡淡青墨，笔杆仍留着指节长久握持的温度。它写过许多没有抵达终点的旅行日记，却从未把中途停下，误写成一场没有意义的远行。","icon":"tex:res://assets/camp_inventory/relic_swallow_quill.tres"},{"id":"relic_arcane_stone","name":"秘纹符石","kind":"buff","rarity":2,"cost":36,"desc":"攻击 +20%，暴击率 +5%","flat":{"crit_chance":0.05},"mult":{"attack":0.2},"flavor":"碎裂石面上的纹路并不完整，连学者也无法逐字复原。有人试着把缺损处填满，却只让光辉变得沉重；后来，旅人学会保留那片空白，让尚未写下的明天也有自己的位置。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。","icon":"tex:res://assets/camp_inventory/relic_arcane_stone.tres"},{"id":"relic_guardian_feather","name":"守望双羽","kind":"buff","rarity":2,"cost":36,"desc":"生命上限 +40，反伤 +8","flat":{"max_hp":40,"thorns":8},"mult":{},"flavor":"两片银羽交错系在同一根细绳上，一片稍长，一片微微卷曲。它们不属于同一只飞鸟，却在长途之后拥有了相同的归向。守望并不是让所有人停留，而是使远行的人知道，身后仍有回应。即使漫长岁月抹去了最初的铭文，守护的意义也仍会在新的相逢中被辨认。","icon":"tex:res://assets/camp_inventory/relic_guardian_feather.tres"},{"id":"relic_dawn_bell","name":"曙光之铃","kind":"buff","rarity":3,"cost":46,"desc":"攻击 +24%，暴击率 +8%","flat":{"crit_chance":0.08},"mult":{"attack":0.24},"flavor":"铃口仿佛收着一线将要升起的天光，细密金纹绕过所有曾经裂开的地方。守灯人把它悬在最容易被风吹灭的门前，年复一年，没有为自己记录姓名。直到某个漫长寒夜结束，归来者才发现，那声音始终不是要求他们留下，而是在告诉每一个独行的灵魂：即使来路已被黑暗吞没，也还有一座门愿意为你开启。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。","icon":"tex:res://assets/camp_inventory/relic_dawn_bell.tres"},{"id":"potion_vital","name":"浓缩生命药剂","kind":"potion","rarity":0,"cost":24,"desc":"立刻回复80点生命","flat":{},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/potion_vital.tres","effect":{"kind":"heal","amount":80}},{"id":"potion_moon","name":"月泉药剂","kind":"potion","rarity":1,"cost":24,"desc":"立刻回复70点魔法","flat":{},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/potion_moon.tres","effect":{"kind":"mana","amount":70}},{"id":"potion_focus","name":"专注药剂","kind":"potion","rarity":1,"cost":24,"desc":"攻击速度 +25%，持续20秒","flat":{},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/potion_focus.tres","effect":{"kind":"buff","stat":"attack_speed","value":0.25,"duration":20}},{"id":"potion_wind","name":"风行药剂","kind":"potion","rarity":0,"cost":22,"desc":"移动速度 +25%，持续20秒","flat":{},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/potion_wind.tres","effect":{"kind":"buff","stat":"move_speed","value":0.25,"duration":20}},{"id":"potion_spring","name":"轻跃药剂","kind":"potion","rarity":0,"cost":22,"desc":"已退役的旧旅途药剂，不再产出。","flat":{},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/potion_spring.tres","effect":{},"sources":[],"retired":true},{"id":"potion_starlight","name":"星光圣露","kind":"potion","rarity":3,"cost":48,"desc":"立刻回复120点生命；营地以3个碧水菇兑换","flat":{},"mult":{},"flavor":"星辉回廊的旅人将它收入行囊。","icon":"tex:res://assets/camp_inventory/potion_starlight.tres","effect":{"kind":"heal","amount":120}},{"id":"camp_mooncoat","name":"月辉行衣","kind":"armor","rarity":2,"cost":44,"desc":"生命上限 +28，攻击 +12%，移动速度 +5%；仅营地随机商店兑换","flat":{"max_hp":28},"mult":{"attack":0.12,"move_speed":0.05},"flavor":"月色沿衣褶铺开，把磨损的织纹照得格外清楚。它曾属于星辉回廊一位常年远行的守望者，对方把最珍重的行衣留在仓库，却带走了最朴素的旧斗篷；她相信，被托付的善意总能走得更远。它所承载的光并不属于某个被选中的名字，而属于每一次自由而郑重的决定。","icon":"tex:res://assets/camp_inventory/camp_mooncoat.tres","sources":["camp_shop"]},{"id":"camp_thornplate","name":"翠棘守甲","kind":"armor","rarity":2,"cost":46,"desc":"生命上限 +28，反伤 +20；仅营地随机商店兑换","flat":{"max_hp":28,"thorns":20},"mult":{},"flavor":"翠色甲片之间生着细韧棘纹，既像屏障，也像尚未展开的枝芽。锻造者没有把森林的锋芒磨去，而让它们沿着守护的方向整齐排列。面对黑暗，温柔与坚决从不需要彼此舍弃。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。","icon":"tex:res://assets/camp_inventory/camp_thornplate.tres","sources":["camp_shop"]},{"id":"camp_stararmor","name":"星冕战甲","kind":"armor","rarity":3,"cost":56,"desc":"生命上限 +60，反伤 +14，攻击 +15%，移动速度 −5%，魔法回复速度 +15%；仅营地随机商店兑换","flat":{"max_hp":60,"thorns":14},"mult":{"attack":0.15,"move_speed":-0.05,"mp_regen":0.15},"flavor":"甲胄上的星冕并不高悬头顶，而被铸在紧贴心口的位置。它提醒每一任穿戴者，荣耀首先是一份应当承担的重量，然后才是可以被看见的光。回廊的旧档案没有留下这副战甲最初的主人，只记下许多人曾穿着它离开，又带着更多旅伴归来。也许一件传世之物最好的铭文，正是那些因此得以延续的名字。愿持有它的人记得来路的重量，也记得自己始终可以选择怎样抵达远方。","icon":"tex:res://assets/camp_inventory/camp_stararmor.tres","sources":["camp_shop"],"legendary_fx":"camp_stararmor"},{"id":"camp_windring","name":"苍风契戒","kind":"accessory","rarity":2,"cost":42,"desc":"冲刺冷却 −24%，移动速度 +6%；仅营地随机商店兑换","flat":{},"mult":{"dash_cooldown":-0.24,"move_speed":0.06},"flavor":"青银戒环中封着两道彼此追逐的气流，像远行者与故乡之间不断往返的消息。它并不保证任何约定都能轻易实现，却让立约者记住：真正的契约，需要在一次次困难中重新选择。真正值得传承的力量，从不止于赢下一场战斗，更在于为何继续前行。","icon":"tex:res://assets/camp_inventory/camp_windring.tres","sources":["camp_shop"]},{"id":"camp_sunpendant","name":"旭星坠饰","kind":"accessory","rarity":3,"cost":54,"desc":"攻击 +18%，暴击伤害 +30%，暴击率 +10%，魔法回复速度 +20%；仅营地随机商店兑换","flat":{"crit_mult":0.3,"crit_chance":0.1},"mult":{"attack":0.18,"mp_regen":0.2},"flavor":"金色星芒穿过温润晶面，落在胸前时像一盏不会夺目的灯。它原本没有名字，直到第一位平安归来的旅人把它称为旭星。从那以后，许多人带着自己的愿望接过它，又把它交给下一位启程者。坠饰从未留住某一段旅途，光辉却因此层层叠起，仿佛那些没有被黑暗改变的心，终于在同一处学会了相认。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。","icon":"tex:res://assets/camp_inventory/camp_sunpendant.tres","sources":["camp_shop"],"legendary_fx":"camp_sunpendant"},{"id":"camp_queenbrooch","name":"女王星章","kind":"accessory","rarity":3,"cost":54,"desc":"生命上限 +24，攻击 +24%，暴击率 +6%，魔法回复速度 +10%；仅营地随机商店兑换","flat":{"max_hp":24,"crit_chance":0.06},"mult":{"attack":0.24,"mp_regen":0.1},"flavor":"星章的边缘缀着庄严金叶，中央却只刻了一扇敞开的门。它所纪念的统治者早已从石碑上失去姓名，唯有一条旧誓仍被留在回廊：权柄不该使人无处可去。世人曾为这枚徽章争夺继承的资格，后来，守望者把它交给了愿意承担归途的人。王冠可以失落，国土可以崩塌，使他人仍有选择的荣耀，却不应一并被遗忘。回廊保存着它走过的路，也为尚未抵达的明天留着一盏安静的灯。","icon":"tex:res://assets/camp_inventory/camp_queenbrooch.tres","sources":["camp_shop"],"legendary_fx":"camp_queenbrooch"},{"id":"staff_apprentice","name":"学徒木杖","kind":"weapon","rarity":0,"cost":24,"icon":"tex:res://assets/weapons/reforged/staff_apprentice_icon.png","flavor":"杖身还带着温和的木纹，顶端的细小晶石，认真回应着施法者尚显生涩的呼唤。","weapon_class":"mage","mult":{"attack":0.06},"flat":{},"desc":"攻击 +6% · 翠叶微光弹","weapon":{"family":"staff","fx":"staff_apprentice","speed":430,"reach":470,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#a6e979"}},{"id":"staff_starorbit","name":"星轨王杖","kind":"weapon","rarity":3,"cost":46,"icon":"tex:res://assets/weapons/reforged/staff_starorbit_icon.png","flavor":"双环围绕蓝白彗核缓慢交错，杖身上的星路在岁月中愈加清晰。它曾被用来推算一座城市能够保存多久，却最终见证了所有推算之外的选择。举起它的人不再试图命令每一颗星沿同一轨道运行，而学会让不同的光拥有各自的前路。那片向外展开的星盘，因而既是力量，也是对自由最郑重的承认。即使漫长岁月抹去了最初的铭文，守护的意义也仍会在新的相逢中被辨认。","weapon_class":"mage","mult":{"attack":0.35,"mp_regen":0.2},"flat":{"crit_chance":0.06},"desc":"攻击 +35%，暴击率 +6%，魔法回复速度 +20% · 星轨彗光与星座绽放","weapon":{"family":"staff","fx":"staff_starorbit","speed":460,"reach":600,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#bbdfff"}},{"id":"staff_ember_flower","name":"烬花法杖","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/builds_vnext/icons/staff_ember_flower.png","flavor":"焦黑花芯包裹着赤金火种，杖端花瓣在每次举起时重新舒展。旧林地曾以烈焰隔绝一场不可挽回的灾厄，却也因此久久不敢再让新芽靠近。后来，有人从灰烬中拾起尚存温度的枝条，把守护与焚毁之间的界限重新握在掌中。花不为灾难盛开，只为证明，即使经历过最深的焦土，生命仍可以选择怎样回应明天。它所承载的光并不属于某个被选中的名字，而属于每一次自由而郑重的决定。","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击 +30%、攻击速度 +8%、魔法回复速度 +12%。火种绽放：普攻附加燃烧：每秒造成攻击力12%的伤害，持续3秒；普攻击中燃烧目标时，以其为中心对72范围内每个敌人造成攻击力65%的爆发伤害，每个目标冷却2秒。","mechanics":[{"id":"ember_flower"}],"build_tags":["burn","basic_attack","aoe"],"sources":["shop","chest","reward"],"weapon_class":"mage","legendary_fx":"staff_ember_flower","weapon":{"family":"staff","fx":"staff_ember_flower","speed":460,"reach":560,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#ff8959"}},{"id":"staff_star_weave","name":"星织法杖","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/builds_vnext/icons/staff_star_weave.png","flavor":"银蓝星线在杖首交错，彼此独立的光点由一段段短线连接成图。它来自失名星城尚未变得沉默的年代，那时，记录的意义仍是让远行者重新找到彼此。后来连线逐渐被误写成锁链，许多光因此失去了方向。如今新的持有者重新举起法杖，让联系回到最初的样子：能够彼此照见，也容许各自离开。旧日的记载可以残缺，后来者却仍拥有亲手写下下一页的权利。那份誓约没有被写在高塔之上，而被留在仍然愿意向前的凡人手中。","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击 +30%、攻击速度 +8%、魔法回复速度 +12%。三芒星痕：4秒内对同一目标普攻命中3次，触发星痕，命中该目标周围144范围内至多3个最近的其他敌人，每个造成攻击力35%的伤害；触发冷却0.6秒。","mechanics":[{"id":"star_weave"}],"build_tags":["basic_attack","mark","chain"],"sources":["shop","chest","reward"],"weapon_class":"mage","legendary_fx":"staff_star_weave","weapon":{"family":"staff","fx":"staff_star_weave","speed":460,"reach":560,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#b8caff"}},{"id":"staff_wind_branch","name":"逐风枝杖","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/builds_vnext/icons/staff_wind_branch.png","flavor":"翠枝弯成一轮轻薄的新月，两缕清风始终沿着枝梢相互追逐。它曾被挂在林间最狭窄的出口上，替迟疑的旅人保留一道可以穿过的缝隙。风没有替谁作出决定，也没有承诺前方没有危险，只在身后黑暗逐渐迫近时，轻轻推开了那片沉重的叶。愿每一次主动迈出的脚步，都能换来属于自己的辽阔。旧日的记载可以残缺，后来者却仍拥有亲手写下下一页的权利。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击 +30%、攻击速度 +8%、魔法回复速度 +12%。风枝散射：冲刺后3秒内的下一次普攻改为扇形发射3枚风刃，每枚造成攻击力55%的伤害，且可穿透1个目标。","mechanics":[{"id":"wind_branch"}],"build_tags":["dash","basic_attack","multishot"],"sources":["shop","chest","reward"],"weapon_class":"mage","legendary_fx":"staff_wind_branch","weapon":{"family":"staff","fx":"staff_wind_branch","speed":460,"reach":560,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#8be6c7"}},{"id":"armor_thorn_moon","name":"棘月守甲","kind":"armor","rarity":3,"cost":60,"icon":"tex:res://assets/builds_vnext/icons/armor_thorn_moon.png","flavor":"暗棘与银月共同铸成护甲的轮廓，柔和月纹包住了最锋利的部分。它记录过许多次防线被击穿的瞬间，却没有把那些失守写成耻辱。因为守护从来不是永不受伤，而是在最后一道屏障碎裂之后，仍肯为了身后之人再次起身。甲胄里响起的余鸣，正是那些未曾放弃的回答。愿持有它的人记得来路的重量，也记得自己始终可以选择怎样抵达远方。那份誓约没有被写在高塔之上，而被留在仍然愿意向前的凡人手中。","flat":{"max_hp":50},"mult":{"attack":0.1,"mp_regen":0.12},"desc":"最大生命 +50、攻击 +10%、魔法回复速度 +12%。月棘反击：护盾被伤害耗尽时，以自身为中心对108范围内敌人造成攻击力90%的反击伤害；冷却4秒。","mechanics":[{"id":"thorn_moon"}],"build_tags":["shield","retaliation","aoe"],"sources":["shop","chest","reward"]},{"id":"staff_soul_command","name":"御魂法杖","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/builds_vnext/icons/staff_soul_command.png","flavor":"紫金契印悬在杖端，细密誓文沿着握柄缓缓收束。它曾被误认为能够命令所有灵魂的权杖，直到第一位持有者主动抹去了誓文最末的所有权。此后，回应这柄法杖的声音都来自自由的选择。它指向的并非主宰者的高座，而是混乱战线里最需要彼此信任的位置；共同的目标，应当比永久的束缚更有力量。真正值得传承的力量，从不止于赢下一场战斗，更在于为何继续前行。","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击 +30%、攻击速度 +8%、魔法回复速度 +12%。魂印号令：普攻击中敌人后为其施加4秒魂印，附近友方单位优先集火魂印目标；友方单位对魂印目标造成的直接伤害提高15%。","mechanics":[{"id":"soul_command"}],"build_tags":["ally","mark","focus"],"sources":["shop","chest","reward"],"weapon_class":"mage","legendary_fx":"staff_soul_command","weapon":{"family":"staff","fx":"staff_soul_command","speed":460,"reach":560,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#b3a0ef"}},{"id":"staff_dusk_lantern","name":"暮灯法杖","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/builds_vnext/icons/staff_dusk_lantern.png","flavor":"青白光点安静伏在暗紫灯芯里，细小幽火总向天空缓缓飘散。希希芙曾以为只要灯仍亮着，所有同行者都能被留在身边。漫长旅途中，她终于听懂了沉默的另一面：有些相逢值得全力守护，也有些告别需要被温柔允许。如今暮灯既为战线中的伙伴照亮方向，也为走到尽头的契约留下一段没有枷锁的送别。即使漫长岁月抹去了最初的铭文，守护的意义也仍会在新的相逢中被辨认。","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击+30%、攻速+8%、MP回复+12%。普攻有效命中为最近一名主动契约物附加6秒暮灯印，冷却1秒；其被敌方伤害击杀时，对72范围敌人造成0.7倍攻击暮灯波，每秒最多三次。自然到期、切房或漂浮灵消失不触发。","mechanics":[{"id":"dusk_lantern"}],"build_tags":["contract","mark","death_burst"],"sources":["shop","chest","reward"],"requires_character":"xixifu","weapon_class":"mage","legendary_fx":"staff_dusk_lantern","weapon":{"family":"staff","fx":"staff_dusk_lantern","speed":460,"reach":560,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#efad78"}},{"id":"armor_scorch_bloom","name":"灼花护衣","kind":"armor","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/armor_scorch_bloom.png","flavor":"焦金花纹沿着护衣胸口盛开，针脚间仍有细小红光静静流转。裁衣者没有为它绣上胜利的场景，而留下了一片经过烈焰仍能重新长出的花。勇气不是与毁灭亲近，而是知道自己为何使用火焰。那份誓约没有被写在高塔之上，而被留在仍然愿意向前的凡人手中。","flat":{"max_hp":30},"mult":{"mp_regen":0.08},"desc":"最大生命 +30、魔法回复速度 +8%。灼花追击：技能直接命中燃烧目标时，对该目标额外造成攻击力25%的伤害；同一目标冷却1秒。","mechanics":[{"id":"scorch_bloom"}],"build_tags":["burn","skill","single_target"],"sources":["shop","chest","reward"]},{"id":"accessory_refraction","name":"折光棱镜","kind":"accessory","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/accessory_refraction.png","flavor":"不同角度的光在镜心相遇，又被分成各自清晰的方向。它曾挂在观测台的窗边，帮助守望者寻找几乎被夜色掩去的星。精准并不总意味着更强烈的光，有时只是终于看清，那条早已存在的裂隙。回廊保存着它走过的路，也为尚未抵达的明天留着一盏安静的灯。","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"desc":"攻击 +10%、魔法回复速度 +8%。折光弹：每次普攻首次有效直接暴击获得1层折光；达到3层后，下次普攻追加一发侧向弹，造成攻击力45%的伤害。","mechanics":[{"id":"refraction"}],"build_tags":["crit","basic_attack","projectile"],"sources":["shop","chest","reward"]},{"id":"armor_swallow_return","name":"归燕轻甲","kind":"armor","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/armor_swallow_return.png","flavor":"青燕的轮廓缝在甲衣里侧，外表只见轻盈而克制的银线。曾有信使把回巢的方向记在这里，穿过无数陌生的林道后仍不曾迷失。轻甲所守住的，不是迟迟不动的安稳，而是转身之后仍能向前的余地。即使漫长岁月抹去了最初的铭文，守护的意义也仍会在新的相逢中被辨认。","flat":{"max_hp":30},"mult":{"mp_regen":0.08},"desc":"最大生命 +30、魔法回复速度 +8%。归燕护幕：冲刺结束时获得相当于最大生命8%的护盾，持续2秒；冷却5秒。","mechanics":[{"id":"swallow_return"}],"build_tags":["dash","shield"],"sources":["shop","chest","reward"]},{"id":"accessory_oath_guard","name":"守誓徽记","kind":"accessory","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/accessory_oath_guard.png","flavor":"金属徽记被反复握过，中心护纹因此比边缘更加明亮。它不为从未遇见考验的誓言作证，只纪念那些已经见过代价，却仍然选择兑现承诺的人。真正坚固的守护，总在行动之后显现。即使漫长岁月抹去了最初的铭文，守护的意义也仍会在新的相逢中被辨认。","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"desc":"攻击 +10%、魔法回复速度 +8%。守誓之盾：技能直接命中敌人时获得相当于最大生命6%的护盾，持续4秒；冷却4秒。","mechanics":[{"id":"oath_guard"}],"build_tags":["skill","shield"],"sources":["shop","chest","reward"]},{"id":"accessory_contract_chorus","name":"契约合唱","kind":"accessory","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/accessory_contract_chorus.png","flavor":"数枚不同材质的小铃被系在同一段紫银链上，音色彼此不同，却能在风中找到相同节拍。它们没有试图覆盖对方的声音，只在最混乱的战线上一同响起。同行的意义，是让每个独立的回应都不再孤单。即使漫长岁月抹去了最初的铭文，守护的意义也仍会在新的相逢中被辨认。","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"desc":"攻击 +10%、魔法回复速度 +8%。契约齐鸣：施放技能时，所有友方单位的攻击速度提高15%，持续3秒；再次触发刷新持续时间。","mechanics":[{"id":"contract_chorus"}],"build_tags":["ally","cast","attack_speed"],"sources":["shop","chest","reward"]},{"id":"armor_farewell","name":"别离护衣","kind":"armor","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/armor_farewell.png","flavor":"幽暗丝线把一圈暖色灯纹绣在衣襟，像暮色中仍然亮着的窗口。它不是留住谁的网，而是离开之前可以认真披上的最后一层温度。能够好好告别的人，也会更懂得珍惜尚在身旁的伙伴。回廊保存着它走过的路，也为尚未抵达的明天留着一盏安静的灯。","flat":{"max_hp":30},"mult":{"mp_regen":0.08},"desc":"最大生命 +30、魔法回复速度 +8%。别离余护：暮灯标记的目标被命中时获得相当于最大生命5%的护盾，持续4秒；冷却3秒。","mechanics":[{"id":"farewell"}],"build_tags":["dusk","shield","mark"],"sources":["shop","chest","reward"],"requires_character":"xixifu"},{"id":"relic_ember_seed","name":"余烬种子","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_ember_seed.png","flavor":"小小种壳藏着一线温热，赤色纹路像尚未抵达地面的根。灰烬并不只意味着结束，也可能是另一株生命最初的土壤；它等待的，是有人愿意替那点余温留一条前路。","flat":{},"mult":{},"desc":"续燃：燃烧目标死亡时，将其剩余燃烧效果传给72范围内最近的至多2个敌人；传播所得的燃烧不会再次传播。","mechanics":[{"id":"ember_seed"}],"build_tags":["burn","spread"],"sources":["shop","chest","reward"]},{"id":"relic_star_mirror","name":"星痕镜片","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_star_mirror.png","flavor":"破碎镜面只映出一角星空，边缘却被仔细磨得不再伤手。旅人把它留在衣袋中，提醒自己不必拥有完整的过去，也能从尚存的微光里找到继续前行的理由。","flat":{},"mult":{},"desc":"星痕回响：命中带有星痕的目标时回复1点魔法值；全局冷却1秒。","mechanics":[{"id":"star_mirror"}],"build_tags":["mark","mp_restore"],"sources":["shop","chest","reward"]},{"id":"relic_wind_chime","name":"逐风铃","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_wind_chime.png","flavor":"铃身轻得近乎一片薄叶，唯有疾行时才会发出清晰的回响。它从不催促疲惫的人赶路，只把每一次已然作出的决心，交还给仍在前进的脚步。","flat":{},"mult":{},"desc":"风刃回旋：风枝散射命中敌人时，当前冲刺的剩余冷却缩短20%；每次冲刺最多触发1次。","mechanics":[{"id":"wind_chime"}],"build_tags":["dash","cooldown"],"sources":["shop","chest","reward"]},{"id":"relic_thorn_shard","name":"棘月碎片","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_thorn_shard.png","flavor":"一弯银白甲片被暗棘紧紧包住，裂面仍映着温柔月色。屏障碎裂的瞬间不必只留下恐惧；有人接住了它，也记住了受保护的生命为何值得继续守望。","flat":{},"mult":{},"desc":"棘刺滞缓：棘月反击命中的敌人减速25%，持续2秒；首领减速效果减半。","mechanics":[{"id":"thorn_shard"}],"build_tags":["retaliation","slow"],"sources":["shop","chest","reward"]},{"id":"relic_companion_knot","name":"同行结","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_companion_knot.png","flavor":"两条颜色不同的旧绳在这里打成牢靠的结，绳头却各自留出了余地。立约的人没有承诺永不分别，只约好在同行的时日里，认真回应身旁的脚步。","flat":{},"mult":{},"desc":"并肩流转：144范围内至少有2名友方单位时，魔法回复速度提高15%。","mechanics":[{"id":"companion_knot"}],"build_tags":["ally","mp_regen"],"sources":["shop","chest","reward"]},{"id":"relic_echo_wick","name":"回声灯芯","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_echo_wick.png","flavor":"灯芯早已烧短，纤维间却仍留着青白余光。它记得许多只响过一次的名字，也记得名字被温柔呼唤时，那片黑暗如何短暂地让出了位置。","flat":{},"mult":{},"desc":"灯焰回魔：暮灯标记的目标被命中时回复3点魔法值；冷却2秒。","mechanics":[{"id":"echo_wick"}],"build_tags":["dusk","mp_restore"],"sources":["shop","chest","reward"],"requires_character":"xixifu"},{"id":"relic_hunt_needle","name":"猎行针","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_hunt_needle.png","flavor":"银针细得像一线冬月，柄端系着不易察觉的青线。它纪念猎手耐心等待的时刻：枝叶可以摇动，风声可以嘈杂，真正重要的空隙终会出现。","flat":{},"mult":{},"desc":"追猎针：普攻击中减速目标时，对该目标额外造成攻击力12%的伤害；同一目标冷却1秒。","mechanics":[{"id":"hunt_needle"}],"build_tags":["slow","basic_attack"],"sources":["shop","chest","reward"]},{"id":"relic_tide_pearl","name":"潮汐珠","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_tide_pearl.png","flavor":"珠中有两道相互追逐的浅蓝水纹，掌心温暖时便缓缓交错。它不试图阻止潮落，只把潮起的方向保存下来，让每一次短暂的空缺都仍有被填满的可能。","flat":{},"mult":{},"desc":"潮汐回魔：施放技能后的4秒内，下一次有效普攻击中回复3点魔法值；冷却3秒。","mechanics":[{"id":"tide_pearl"}],"build_tags":["cast","basic_attack","mp_restore"],"sources":["shop","chest","reward"]},{"id":"relic_afterglow_note","name":"余辉手记","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/builds_vnext/icons/relic_afterglow_note.png","flavor":"纸页边缘染着灯烟，空白处挤满认真写下的提醒。那不是英雄的战报，而是一位普通旅人替后来者留下的准备；微小的经验，也能成为穿过陌路的庇护。","flat":{},"mult":{},"desc":"余辉之盾：首次进入每个尚未清理的普通房间时，获得相当于最大生命10%的护盾，持续8秒；每间房仅触发1次。","mechanics":[{"id":"afterglow_note"}],"build_tags":["room_enter","shield"],"sources":["shop","chest","reward"]},{"id":"relic_breaker_stone","name":"破甲石","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/relic_breaker_stone.png","flavor":"石心的金色细线恰好穿过最坚硬的一层岩壳，像一道被漫长观察找到的答案。它提醒旅人，面对压倒性的威势不必只懂得正面争强；再宏伟的屏障，也有必须由判断去辨认的接缝。即使漫长岁月抹去了最初的铭文，守护的意义也仍会在新的相逢中被辨认。","flat":{},"mult":{},"desc":"精英克星：技能直接命中精英敌人时，造成的伤害提高15%。","mechanics":[{"id":"breaker_stone"}],"build_tags":["elite","skill"],"sources":["shop","chest","reward"]},{"id":"relic_patrol_bell","name":"巡猎铃","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/relic_patrol_bell.png","flavor":"铜铃一侧刻着脚步，另一侧刻着张开的弓弦，细小风纹把两者连在一起。它属于懂得在移动与出手之间寻找秩序的巡行者。真正从容的战斗，从来不是站在原地等待命运靠近。那份誓约没有被写在高塔之上，而被留在仍然愿意向前的凡人手中。","flat":{},"mult":{},"desc":"疾行施法：冲刺后的3秒内，下一次施放技能的伤害提高12%，施放时消耗。","mechanics":[{"id":"patrol_bell"}],"build_tags":["dash","skill"],"sources":["shop","chest","reward"]},{"id":"relic_watch_button","name":"守望纽扣","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/builds_vnext/icons/relic_watch_button.png","flavor":"小小纽扣用温润铜线包住护石，看起来像旧外套上最不起眼的一处补缀。缝下它的人没有留下姓名，只在内侧写了一句话：如果你的灯仍有余光，请分给尚在黑暗里的伙伴。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。","flat":{},"mult":{},"desc":"守望之盾：施放技能时，为144范围内最近的至多3名没有护盾的友方单位各提供其自身最大生命8%的护盾，持续4秒。","mechanics":[{"id":"watch_button"}],"build_tags":["ally","cast","shield"],"sources":["shop","chest","reward"]},{"id":"bow_vine_short","name":"藤纹短弓","kind":"weapon","rarity":0,"cost":22,"icon":"tex:res://assets/characters/ilyua/items/bow_vine_short.png","flavor":"浅木弓身保留着细细藤纹，弦上还系着初次练习留下的小结，朴素而可信赖。","flat":{},"mult":{"attack":0.08},"desc":"攻击 +8%。伊露雅的轻便藤纹短弓。","weapon_class":"archer","requires_character":"ilyua","weapon":{"family":"bow","fx":"bow_vine_short","speed":560,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#a8dba2"},"sources":["shop","chest","reward"]},{"id":"bow_lake_light","name":"湖光猎弓","kind":"weapon","rarity":2,"cost":40,"icon":"tex:res://assets/characters/ilyua/items/bow_lake_light.png","flavor":"蓝色弓角像一弯落在水面的月，弦扣被露水磨得温润。它曾在无风的湖岸陪伴猎手练习，每一次松弦都以平静回应远处的动静。清晰的判断，往往出自不被恐惧扰乱的呼吸。旧日的记载可以残缺，后来者却仍拥有亲手写下下一页的权利。","flat":{},"mult":{"attack":0.22,"attack_speed":0.06,"mp_regen":0.06},"desc":"攻击 +22%、攻击速度 +6%、魔法回复速度 +6%。","weapon_class":"archer","requires_character":"ilyua","weapon":{"family":"bow","fx":"bow_lake_light","speed":560,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#b3e8ee"},"sources":["shop","chest","reward"]},{"id":"bow_spring_wind","name":"初春风弓","kind":"weapon","rarity":3,"cost":60,"icon":"tex:res://assets/characters/ilyua/items/bow_spring_wind.png","flavor":"新叶般的翠光缠绕着弓臂，湖蓝弓弦在静止时也像一阵将起的风。伊露雅不再把故乡只当作必须找回的旧名，而把它理解为愿意珍惜的每一段相逢。于是，弓上的藤纹第一次长出了记录之外的新芽。它们不会替她重写已经失去的过去，却陪她在每一次转身与放箭之间，亲手守住仍然能够抵达的明天。那份誓约没有被写在高塔之上，而被留在仍然愿意向前的凡人手中。","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击 +30%、攻击速度 +8%、魔法回复速度 +12%。主箭首次命中有15%概率产生0.15倍攻击的风刃，冷却0.8秒。\n春鸣循环：主普攻首个有效命中积累春鸣，最多四层、6秒。四层时基础闪避结束消耗，释放72范围、0.4倍攻击风环，并使4秒内接下来三次主普攻首次命中追加0.18倍攻击追击，向附近一敌扩散0.12倍攻击；用完回复3MP。循环冷却5秒，附加伤害不暴击、不吸血、不递归。","weapon_class":"archer","requires_character":"ilyua","legendary_fx":"bow_spring_wind","mechanics":[{"id":"spring_wind_bow"}],"weapon":{"family":"bow","fx":"bow_spring_wind","speed":560,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#c2f4b7"},"sources":["shop","chest","reward"]},{"id":"staff_cloud_radiance","name":"圣云流光杖","kind":"weapon","rarity":3,"cost":60,"requires_character":"sylphiette","icon":"tex:res://assets/legendary_sets_v01/icons/staff_cloud_radiance.png","flat":{},"mult":{"attack":0.3,"attack_speed":0.08,"mp_regen":0.12},"desc":"攻击+30%、攻速+8%、MP回复+12%。普攻首个有效命中积攒一枚6秒圣云律印，最多三枚；三枚时下一个小技能消耗律印，伤害+20%，释放108范围、0.75倍攻击圣云光环，并获得8%生命护盾4秒；冷却3秒。大招不消耗律印。","flavor":"柔和圣云围绕金纹杖首展开，澄蓝灵珠把不同方向的微光静静照亮。希露媞雅曾以为守护就是替所有人保存同一个完美答案，后来才明白，希望也需要拥有不同的声音。她让祈愿在掌中各自成形，不再以光辉覆盖悲伤，而以清明辨认每一份真实的呼唤。那束温暖的圣光，因此终于学会陪人前行，而非要求人永远留下。那份誓约没有被写在高塔之上，而被留在仍然愿意向前的凡人手中。","mechanics":[{"id":"cloud_staff"}],"sources":["shop","chest","reward"],"weapon_class":"mage","legendary_fx":"staff_cloud_radiance","weapon":{"family":"staff","fx":"staff_cloud_radiance","speed":430,"reach":540,"cd":0.35,"dmg":1,"shots":1,"sprite":"same","color":"#fff0ca"}},{"id":"armor_cloud_rites","name":"圣云礼衣","kind":"armor","rarity":3,"cost":60,"requires_character":"sylphiette","icon":"tex:res://assets/legendary_sets_v01/icons/armor_cloud_rites.png","flat":{"max_hp":60},"mult":{"attack":0.1,"mp_regen":0.18},"desc":"生命+60、攻击+10%、MP回复+18%。成功施放小技能获得最大生命12%的护盾，持续4秒、冷却6秒；护盾实际承伤回复2MP，冷却3秒。圣云护盾可辅助积累祈光，与云冕灵珠联动。","flavor":"纯白礼衣的衣褶间绣满细密圣云，金线从心前缓缓延伸向袖口。它不属于高台上的宣告，而属于俯身倾听的祭司。希露媞雅把许多没有被说完的祈愿留在这些针脚里，提醒自己守护不是替人拒绝所有伤痛，而是在屏障被触及时，仍能清楚地回应身旁的人。圣光的温暖，由此拥有了可以被依靠的形状。回廊保存着它走过的路，也为尚未抵达的明天留着一盏安静的灯。","mechanics":[{"id":"cloud_vestment"}],"sources":["shop","chest","reward"]},{"id":"accessory_eternal_ring","name":"永昼圣环","kind":"accessory","rarity":3,"cost":60,"requires_character":"sylphiette","icon":"tex:res://assets/legendary_sets_v01/icons/accessory_eternal_ring.png","flat":{"crit_chance":0.04},"mult":{"attack":0.14,"attack_speed":0.1,"mp_regen":0.18},"desc":"攻击+14%、攻速+10%、MP回复+18%、暴击+4%。普攻首个有效命中暴击回复2MP，冷却1.5秒；6秒内护盾实际承伤累计三次，释放半径72像素、0.45倍攻击的圣辉并回复2MP，冷却3秒；同一时刻承伤每0.25秒至多计一次。","flavor":"金色圣环没有被塑成闭合的牢笼，细密云纹间始终留着让光通过的空隙。澄蓝宝石映照着一份份不同的祈愿，既不彼此吞没，也不因破碎而被抛弃。希露媞雅把它佩在离心最近的地方，愿每一次承担伤害，都能转化为更清明的守望。所谓永昼，并非世间从此不再有黑夜，而是仍有人愿意在黑夜里认真举灯。它所承载的光并不属于某个被选中的名字，而属于每一次自由而郑重的决定。","mechanics":[{"id":"eternal_circlet"}],"sources":["shop","chest","reward"]},{"id":"armor_dusk_mantle","name":"归途影衣","kind":"armor","rarity":3,"cost":60,"requires_character":"xixifu","icon":"tex:res://assets/legendary_sets_v01/icons/armor_dusk_mantle.png","flat":{"max_hp":60},"mult":{"attack":0.12,"mp_regen":0.18},"desc":"生命+60、攻击+12%、MP回复+18%。成功施放小技能，为最近三名友军提供其最大生命8%的护盾，持续4秒、冷却5秒；主动契约物被敌方击杀时，自身获得最大生命8%的护盾4秒，冷却4秒；自然到期和切房不触发。","flavor":"紫黑衣料里藏着一圈青白灯火，展开时像一条安静延伸的归路。希希芙曾把影子织得很密，想要保护每一个不肯放手的名字；后来，她终于愿意让衣角随风敞开。它如今为同行者遮挡逼近的锋芒，也在契约结束时留下温柔的余温。守护与告别不再相互敌对，因为真正被珍重的相逢，从来不需要以囚禁证明重量。那份誓约没有被写在高塔之上，而被留在仍然愿意向前的凡人手中。","mechanics":[{"id":"dusk_mantle"}],"sources":["shop","chest","reward"]},{"id":"accessory_companion_bells","name":"同行契铃","kind":"accessory","rarity":3,"cost":60,"requires_character":"xixifu","icon":"tex:res://assets/legendary_sets_v01/icons/accessory_companion_bells.png","flat":{},"mult":{"attack":0.16,"attack_speed":0.12,"mp_regen":0.12},"desc":"攻击+16%、攻速+12%、MP回复+12%。普攻首个有效命中使当前友军攻速+12%，持续3秒、冷却3秒；友军有效直击在4秒内累计三拍，产生半径54像素、0.35倍角色攻击的幽灯共鸣，冷却2秒；范围攻击及齐射每0.25秒至多计一拍。","flavor":"五枚小铃各自保存着不同的音色，银链并未将它们固定在同一个方向。希希芙曾仔细聆听每一份契约的回应，才知道齐声并不意味着失去自己的旋律。铃声响起时，那些独立而自由的意志会在战线中短暂相认。它所赞颂的不是谁能召来更多追随者，而是谁愿意在最危险的瞬间，把伙伴的声音认真放在心上。旧日的记载可以残缺，后来者却仍拥有亲手写下下一页的权利。","mechanics":[{"id":"covenant_bells"}],"sources":["shop","chest","reward"]},{"id":"armor_lakeleaf_hunt","name":"湖叶游猎衣","kind":"armor","rarity":3,"cost":60,"requires_character":"ilyua","icon":"tex:res://assets/legendary_sets_v01/icons/armor_lakeleaf_hunt.png","flat":{"max_hp":55},"mult":{"attack_speed":0.1,"mp_regen":0.12,"move_speed":0.1},"desc":"生命+55、攻速+10%、MP回复+12%、移速+10%。闪避结束获得最大生命8%的护盾，持续2秒、冷却5秒；持盾时主普攻首个有效命中累计四次，产生半径54像素、0.45倍攻击的风环并回复2MP，冷却2秒，相邻命中间隔不超过5秒。","flavor":"白色轻衣上覆着湖蓝护片，金色叶脉顺着动作自然展开。伊露雅把远行后第一次采到的新叶缝在衣襟里，叶色渐淡，脚步却愈加坚定。她不再要求每一次回望都能看见故乡原来的模样，而学会在新的道路上保护自己，也保护愿意与她同行的人。那圈随身而起的风，既是猎手的判断，也是对未来从未松开的信任。旧日的记载可以残缺，后来者却仍拥有亲手写下下一页的权利。","mechanics":[{"id":"swallow_return"},{"id":"lakeleaf_guard"}],"sources":["shop","chest","reward"]},{"id":"accessory_moonwind_chime","name":"风铃月坠","kind":"accessory","rarity":3,"cost":60,"requires_character":"ilyua","icon":"tex:res://assets/legendary_sets_v01/icons/accessory_moonwind_chime.png","flat":{"crit_chance":0.08},"mult":{"attack":0.16,"mp_regen":0.18,"dash_cooldown":-0.12},"desc":"攻击+16%、MP回复+18%、暴击+8%、基础闪避冷却-12%。普攻首个有效命中暴击，返还当前闪避剩余冷却15%，冷却1秒；闪避结束使4秒内下两次主普攻首个命中追加0.22倍攻击的月风，并各返还0.2秒闪避冷却，冷却5秒。","flavor":"一弯湖蓝细月托着青银风铃，声响轻得像林叶彼此触碰。它曾被伊露雅藏在兜帽内侧，陪伴那些不愿暴露身份的沉默时刻；如今，她允许铃声在转身时清晰响起。真正的自由并不要求忘记来处，而是在记得一切之后，仍能以自己的名字选择方向。每一次离开原地，都可以是为了更认真地守住眼前的光。即使漫长岁月抹去了最初的铭文，守护的意义也仍会在新的相逢中被辨认。","mechanics":[{"id":"moonwind_chime"}],"sources":["shop","chest","reward"]},{"id":"staff_tide_prayer","name":"回澜祭杖","kind":"weapon","rarity":2,"cost":40,"icon":"tex:res://assets/content_v05/items/staff_tide_prayer.png","flat":{},"mult":{"attack":0.22,"attack_speed":0.06,"mp_regen":0.06},"mechanics":[{"id":"tide_staff"}],"build_tags":["走位联动"],"desc":"持有护盾时，三次主普攻首个有效命中释放42范围、0.2倍攻击澜环并回复2MP，冷却2秒。","flavor":"浅蓝杖身留着水纹，银色杖环如同收束的潮线。持杖者曾在被遗忘的渡口守候，反复确认每一位旅人都已登岸。后来潮水带走了路碑，祭杖仍记得那份把散乱力量重新引回秩序的耐心。那份誓约没有被写在高塔之上，而被留在仍然愿意向前的凡人手中。","sources":["shop","chest","reward"],"requires_character":"sylphiette","weapon_class":"mage","weapon":{"family":"staff","fx":"wand_arcane","dmg":1,"cd":0.35,"speed":430,"reach":540,"shots":1,"sprite":"same","color":"#fff0ca"}},{"id":"staff_shadow_stitch","name":"影缝枝杖","kind":"weapon","rarity":2,"cost":40,"icon":"tex:res://assets/content_v05/items/staff_shadow_stitch.png","flat":{},"mult":{"attack":0.22,"attack_speed":0.06,"mp_regen":0.06},"mechanics":[{"id":"shadow_stitch"}],"build_tags":["走位联动"],"desc":"主普攻首个有效命中时，若目标108范围有友军，追加0.18倍攻击影缝伤害，冷却1.5秒。","flavor":"一根深色枝条被细密幽光缝合，裂口处反而长出柔软的新芽。它并不否认曾经的断裂，而承认相互扶持也能成为完整的一种方式。灯影交错时，孤单的脚步便有了可以信赖的回应。旧日的记载可以残缺，后来者却仍拥有亲手写下下一页的权利。","sources":["shop","chest","reward"],"requires_character":"xixifu","weapon_class":"mage","weapon":{"family":"staff","fx":"wand_arcane","dmg":1,"cd":0.35,"speed":430,"reach":540,"shots":1,"sprite":"same","color":"#fff0ca"}},{"id":"bow_willow","name":"柳弦短弓","kind":"weapon","rarity":2,"cost":40,"icon":"tex:res://assets/content_v05/items/bow_willow.png","flat":{},"mult":{"attack":0.22,"attack_speed":0.06,"mp_regen":0.06},"mechanics":[{"id":"willow_bow"}],"build_tags":["走位联动"],"desc":"移动中主普攻首个有效命中回复2MP，冷却2秒。","flavor":"柳枝被仔细弯成弓臂，浅绿细线像一段尚未停歇的水流。它属于会沿着河岸反复练习的猎手，宁可花很长时间学会判断，也不肯让一次莽撞的松弦惊扰本可平安离开的生命。愿持有它的人记得来路的重量，也记得自己始终可以选择怎样抵达远方。","sources":["shop","chest","reward"],"requires_character":"ilyua","weapon_class":"archer","weapon":{"family":"bow","fx":"bow_willow","dmg":1,"cd":0.35,"speed":560,"reach":540,"shots":1,"sprite":"same","color":"#a8ebc9"}},{"id":"armor_oath_trace","name":"誓痕护衣","kind":"armor","rarity":2,"cost":40,"icon":"tex:res://assets/content_v05/items/armor_oath_trace.png","flat":{"max_hp":30},"mult":{"mp_regen":0.08},"mechanics":[{"id":"oath_cloak"}],"build_tags":["走位联动"],"desc":"自身护盾因实际承伤破裂时回复4MP，冷却5秒；自然到期不触发。","flavor":"褪色誓文贴着衣料一道道展开，最深的痕迹都留在容易承受冲击的位置。穿戴它的人没有把失守当作背弃，而从每一次破损中重新确认自己的选择。誓言的价值，在于再次起身时仍肯承担。回廊保存着它走过的路，也为尚未抵达的明天留着一盏安静的灯。","sources":["shop","chest","reward"]},{"id":"accessory_silver_return","name":"归航银坠","kind":"accessory","rarity":2,"cost":40,"icon":"tex:res://assets/content_v05/items/accessory_silver_return.png","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"mechanics":[{"id":"silver_return"}],"build_tags":["走位联动"],"desc":"基础闪避结束回复3MP，冷却5秒。","flavor":"银坠里藏着一段弯曲的旧航线，终点并不位于任何王城。它曾陪伴漂泊者回到一座普通的灯下，也曾被交给另一位即将离开的旅人。归来不是结束远行，而是让下次出发仍有可被信任的方向。即使漫长岁月抹去了最初的铭文，守护的意义也仍会在新的相逢中被辨认。","sources":["shop","chest","reward"]},{"id":"accessory_wind_listen","name":"听风护符","kind":"accessory","rarity":2,"cost":40,"icon":"tex:res://assets/content_v05/items/accessory_wind_listen.png","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"mechanics":[{"id":"wind_listen"}],"build_tags":["走位联动"],"desc":"主普攻首个有效命中距离自身超过144的目标，追加0.08倍攻击伤害，冷却1.25秒。","flavor":"细孔穿过青色护石，风经过时只留下一声极轻的回响。它不替猎手制造从未存在的机会，而教人听见嘈杂背后细小却真实的变化。看似漫长的距离，有时正是判断得以从容展开的地方。那份誓约没有被写在高塔之上，而被留在仍然愿意向前的凡人手中。","sources":["shop","chest","reward"]},{"id":"relic_late_clock","name":"迟钟碎片","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v05/items/relic_late_clock.png","flat":{},"mult":{},"mechanics":[{"id":"late_clock"}],"build_tags":["技能循环"],"desc":"主普攻首个有效命中，使剩余冷却最长的小技能缩短0.15秒，冷却1秒；不影响大招。","flavor":"铜片上只剩半个刻度，裂缝却被细心磨平。它提醒旅人，迟到的钟声仍然可以被听见；只要下一次行动仍由自己决定，失去的片刻就不必成为永远的停滞。","sources":["shop","chest","reward"]},{"id":"relic_mist_dew","name":"雾露瓶","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v05/items/relic_mist_dew.png","flat":{},"mult":{},"mechanics":[{"id":"mist_dew"}],"build_tags":["技能循环"],"desc":"自身生命低于50%时，小技能直接命中回复1%最大生命，冷却3秒；真实伤势仍无法恢复。","flavor":"窄瓶收着一滴安静的林间晨露，轻晃时仿佛又有清雾升起。采集它的人把最珍贵的露水留给后来者，愿那只疲惫的手，在重新举起武器前得到片刻温柔。","sources":["shop","chest","reward"]},{"id":"relic_half_star","name":"半枚航星","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v05/items/relic_half_star.png","flat":{},"mult":{},"mechanics":[{"id":"half_star"}],"build_tags":["技能循环"],"desc":"基础闪避后5秒内下一次主普攻首个有效命中，回复2MP并追加0.1倍攻击伤害；冷却3秒，不储存。","flavor":"旧星徽从中间折断，只剩一侧仍有银光。持有它的旅人没有急着寻找另一半，而让这片残缺陪自己继续赶路；未曾完整，也并不意味着不能指引归途。","sources":["shop","chest","reward"]},{"id":"relic_lamp_tassel","name":"绒灯穗","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v05/items/relic_lamp_tassel.png","flat":{},"mult":{},"mechanics":[{"id":"lamp_tassel"}],"build_tags":["技能循环"],"desc":"自身144范围内的友军有效直击敌人时回复1MP，全局冷却1秒。","flavor":"柔软灯穗上系着几段颜色不同的旧线，像许多旅途留下的小小回声。它不愿让最安静的同行者被战线遗忘，便把每一份认真回应，都织进身旁那点不肯熄灭的暖光。","sources":["shop","chest","reward"]},{"id":"relic_broken_verse","name":"断弦诗页","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v05/items/relic_broken_verse.png","flat":{},"mult":{},"mechanics":[{"id":"broken_verse"}],"build_tags":["技能循环"],"desc":"主普攻首个有效命中暴击时，获得3%最大生命护盾2秒，冷却5秒；护盾取较强值。","flavor":"纸页上记着一段尚未写完的旋律，断弦被折进了空白处。后来读到它的人没有补上终章，而把新的相逢写在旁边；失去的声音，也可以为尚未响起的歌留出位置。","sources":["shop","chest","reward"]},{"id":"relic_leaf_page","name":"游叶书签","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v05/items/relic_leaf_page.png","flat":{},"mult":{},"mechanics":[{"id":"leaf_page"}],"build_tags":["技能循环"],"desc":"6秒内成功施放三个不同小技能，强化4秒内下一次小技能直击，释放36范围、0.18倍攻击叶辉；冷却4秒。","flavor":"一片被压平的长叶守在旧书中间，叶脉像三条相互交错的小路。它记得旅人曾经反复翻阅的疑问，也记得那些答案最终如何在不同的行动之间慢慢连接成形。","sources":["shop","chest","reward"]},{"id":"armor_storm_conductor","name":"雷律战衣","kind":"armor","rarity":3,"cost":60,"icon":"tex:res://assets/content_v06/icons/armor_storm_conductor.png","desc":"最大生命+50、攻击+10%、MP回复速度+12%。每次普攻首次有效命中积累一拍；相邻命中间隔不超过4秒。第四拍在目标周围72像素引发攻击力55%的雷律波，冷却1.5秒。冷却期间不积拍。","flavor":"银蓝衣纹仿佛一段正在展开的雷霆乐章，沉重的力量被整齐收束在细密针脚之间。它曾被误认为只属于轰鸣与毁灭，直到持有者用准确的节拍护住了一条濒临崩溃的战线。雷光没有因此变得温顺，却第一次拥有了清晰的方向。每一次认真而持续的出手，都在为下一段足以照亮黑暗的回响积蓄重量。真正值得传承的力量，从不止于赢下一场战斗，更在于为何继续前行。","flat":{"max_hp":50},"mult":{"mp_regen":0.12,"attack":0.1},"mechanics":[{"id":"storm_conductor"}],"build_tags":["basic","rhythm","area"],"sources":["shop","chest","reward"]},{"id":"accessory_counterbeat","name":"逆拍银坠","kind":"accessory","rarity":2,"cost":40,"icon":"tex:res://assets/content_v06/icons/accessory_counterbeat.png","desc":"攻击+10%、MP回复速度+8%。成功施放小技能后，4秒内下一次普攻首次有效命中追加攻击力22%的装备伤害；重复施放刷新，不储存次数。","flavor":"银坠的两个摆臂从不同时抵达中央，却总能在交错时发出清亮共鸣。它纪念施法与松弦之间那段短暂空隙，也纪念旅人不肯被单一节奏束缚的意志。变化并非混乱，有时恰是重新掌握主动的开端。它所承载的光并不属于某个被选中的名字，而属于每一次自由而郑重的决定。","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"mechanics":[{"id":"counterbeat"}],"build_tags":["basic","skill","rhythm"],"sources":["shop","chest","reward"]},{"id":"armor_mana_reservoir","name":"深澜法袍","kind":"armor","rarity":3,"cost":60,"icon":"tex:res://assets/content_v06/icons/armor_mana_reservoir.png","desc":"最大生命+50、攻击+10%、MP回复速度+12%。成功施放小技能后，若剩余MP不少于50%，获得1层澜晶，最多3层，持续8秒。普攻首次有效命中消耗1层，追加攻击力30%的装备伤害并回复2MP，触发间隔0.8秒。","flavor":"衣料深处仿佛收着一片没有喧哗的海，浅蓝织纹在每次呼吸间缓缓明灭。旧日施法者曾不断追逐更浩大的声势，直到魔力枯竭的长夜教会她珍惜每一滴仍可调度的微光。于是这件法袍不再赞颂无止境的倾泻，而把充盈与回转织成同一段秩序。真正深沉的力量，既懂得施展，也懂得为下一次守望留下余地。即使漫长岁月抹去了最初的铭文，守护的意义也仍会在新的相逢中被辨认。","flat":{"max_hp":50},"mult":{"mp_regen":0.12,"attack":0.1},"mechanics":[{"id":"mana_reservoir"}],"build_tags":["mana","basic","skill"],"sources":["shop","chest","reward"]},{"id":"accessory_last_flame","name":"余烛护符","kind":"accessory","rarity":2,"cost":40,"icon":"tex:res://assets/content_v06/icons/accessory_last_flame.png","desc":"攻击+10%、MP回复速度+8%。成功施放小技能后，若剩余MP低于30%，获得最大生命8%的护盾，持续4秒，冷却8秒。","flavor":"一截细小蜡烛被包在旧铜框里，火舌映出温暖却并不安逸的颜色。它曾在最疲惫的时刻被交到旅人手中，没有宏大的承诺，只有一份清楚的心意：力量将尽时，也值得有人替你守住片刻。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。","flat":{},"mult":{"attack":0.1,"mp_regen":0.08},"mechanics":[{"id":"last_flame"}],"build_tags":["mana","shield","skill"],"sources":["shop","chest","reward"]},{"id":"armor_orbit_guard","name":"环星护衣","kind":"armor","rarity":2,"cost":40,"icon":"tex:res://assets/content_v06/icons/armor_orbit_guard.png","desc":"最大生命+30、MP回复速度+8%。角色144像素内的友军有效直击累计4拍，获得最大生命5%的护盾，持续4秒、冷却5秒。相邻拍间隔不超过4秒；同一时刻的范围攻击与齐射每0.2秒至多计一拍。","flavor":"数道细银环绕着衣襟交错展开，每一圈都留着不同的微光。它不把伙伴的贡献写成谁的附庸，而把那些彼此回应的出手织成一道共同的屏障。被守护的人，也正在以自己的方式参与守望。群星不会替旅人承担选择，却会照见那些在黑暗中仍未改变的心。","flat":{"max_hp":30},"mult":{"mp_regen":0.08},"mechanics":[{"id":"orbit_guard"}],"build_tags":["ally","rhythm","shield"],"sources":["shop","chest","reward"]},{"id":"accessory_cadence_prism","name":"交响棱心","kind":"accessory","rarity":3,"cost":60,"icon":"tex:res://assets/content_v06/icons/accessory_cadence_prism.png","desc":"攻击+20%、攻击速度+8%、MP回复速度+12%。普攻首次有效命中与主动技能直击交替发生时积累协鸣。首次命中确定声部，每次换声部积累1层；同声部连续命中不增加或刷新。3层后在目标周围72像素爆发攻击力65%的交响波，冷却2秒。每次有效换声部将宽限刷新为4秒。","flavor":"晶体内部没有居于中央的唯一光源，数道颜色不同的光在交替中共同托起了明亮的核心。它曾来自试图保存全部声音的观测装置，却在记录崩毁之后保留了另一种启示：完整不必意味着所有人同时奏出同一个音符。挥杖、放箭与祈愿可以各自展开，正因为保有不同的节奏，才有机会汇成真正超越孤身之力的交响。愿持有它的人记得来路的重量，也记得自己始终可以选择怎样抵达远方。","flat":{},"mult":{"attack":0.2,"mp_regen":0.12,"attack_speed":0.08},"mechanics":[{"id":"cadence_prism"}],"build_tags":["basic","skill","rhythm","area"],"sources":["shop","chest","reward"]},{"id":"relic_copper_metre","name":"铜律节拍器","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v06/icons/relic_copper_metre.png","desc":"普攻首次有效命中累计4拍后回复2MP，并使该目标减速20%、持续2秒，首领减半；相邻拍间隔不超过4秒，触发冷却1秒。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、层数、范围与冷却不变。","flavor":"细小铜摆在两道刻痕之间往返，像行军途中始终没有落下的脚步。它不会替谁奏出胜利的终章，只把一次次稳定的行动，累积成可以抵御慌乱的秩序。","flat":{},"mult":{},"mechanics":[{"id":"copper_metre"}],"build_tags":["basic","mana","slow"],"sources":["shop","chest","reward"]},{"id":"relic_aftertone","name":"返音石","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/content_v06/icons/relic_aftertone.png","desc":"主动技能直击减速目标时，追加攻击力14%的装备伤害，全局冷却1.5秒。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、层数、范围与冷却不变。","flavor":"石纹像被保存下来的声波，一圈圈向安静的中心收束。它属于懂得等待回响的施法者，愿意先看清敌阵的迟滞，再把下一段咒文送进真正重要的空隙。力量因此有了被认真听见的机会。即使漫长岁月抹去了最初的铭文，守护的意义也仍会在新的相逢中被辨认。","flat":{},"mult":{},"mechanics":[{"id":"aftertone"}],"build_tags":["skill","slow"],"sources":["shop","chest","reward"]},{"id":"relic_dew_battery","name":"露华蓄晶","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v06/icons/relic_dew_battery.png","desc":"成功施放小技能后，若剩余MP不少于50%，4秒内下一次普攻首次有效命中回复3MP，冷却3秒。强化不储存。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、层数、范围与冷却不变。","flavor":"淡青晶面上总留着露水般的微光，哪怕掌心已经不再充盈。旅人把它比作一只耐心的小杯，记下丰裕时得到的余泽，也在下一次需要出手时，替持有者留住一点从容。","flat":{},"mult":{},"mechanics":[{"id":"dew_battery"}],"build_tags":["mana","basic","skill"],"sources":["shop","chest","reward"]},{"id":"relic_dry_wick","name":"未熄灯芯","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v06/icons/relic_dry_wick.png","desc":"MP低于30%时，主动技能有效直击回复3MP，全局冷却3秒。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、层数、范围与冷却不变。","flavor":"焦黑纤维深处还藏着极细的一线暖光，仿佛一句没有说尽的鼓励。它不许诺漫长的夜会立刻结束，只提醒仍在战斗的人：微小的余力，也值得被认真接住。","flat":{},"mult":{},"mechanics":[{"id":"dry_wick"}],"build_tags":["mana","skill"],"sources":["shop","chest","reward"]},{"id":"relic_sentinel_thread","name":"守望纺线","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/content_v06/icons/relic_sentinel_thread.png","desc":"自身护盾因承伤耗尽后，4秒内下一次普攻首次有效命中追加攻击力18%的装备伤害，并为144像素内最近一名友军提供其最大生命8%的护盾、持续4秒。无友军时仍造成追加伤害，触发冷却4秒。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、层数、范围与冷却不变。","flavor":"纺线的一端染着自己的血色，另一端却仍是温和的青白。它被留给那些在屏障破碎之后，仍愿先看一眼同伴的人。真正的守望并不会因为一场失守而终止，只会寻找另一种能够抵达彼此的方式。它所承载的光并不属于某个被选中的名字，而属于每一次自由而郑重的决定。","flat":{},"mult":{},"mechanics":[{"id":"sentinel_thread"}],"build_tags":["shield","ally","basic"],"sources":["shop","chest","reward"]},{"id":"relic_wayfarer_score","name":"旅伴乐谱","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v06/icons/relic_wayfarer_score.png","desc":"角色144像素内友军的有效直击累计4拍后回复2MP，冷却2秒；相邻拍间隔不超过4秒，同一时刻的范围攻击与齐射每0.2秒至多计一拍。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、层数、范围与冷却不变。","flavor":"谱页上没有独奏者的姓名，空白声部被认真留在每一行末尾。旅人经过时可以写下一小段自己的旋律，离开时也不必把它抹去；相逢过的声音，总有再次被听见的资格。","flat":{},"mult":{},"mechanics":[{"id":"wayfarer_score"}],"build_tags":["ally","mana","rhythm"],"sources":["shop","chest","reward"]},{"id":"relic_ash_compass","name":"苍烬罗盘","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/content_v07/icons/relic_ash_compass.png","desc":"普攻首个有效命中燃烧目标，追加0.14倍攻击伤害并减速20%，持续2秒，冷却1.5秒。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、目标数、范围与冷却不变。","flavor":"罗盘不再追逐北方，而指向尚存余温的焦土。焦黑铜环曾被遗落在林火之后，新的持有者却在那里看见了仍未熄灭的生命。它所寻找的不是更盛大的焚毁，而是灰烬之间足以改变局面的那道缝隙。真正值得传承的力量，从不止于赢下一场战斗，更在于为何继续前行。","flat":{},"mult":{},"mechanics":[{"id":"ash_compass"}],"build_tags":["burn","slow","basic"],"sources":["shop","chest","reward"]},{"id":"relic_frost_petal","name":"霜枝花瓣","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v07/icons/relic_frost_petal.png","desc":"直接主动技能命中减速目标，将25%减速传递给其108像素内最近两名其他敌人，持续2秒，冷却3秒；传播不递归。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、目标数、范围与冷却不变。","flavor":"冰蓝花瓣抱着一截细小银枝，边缘的寒意格外安静。它像林地留给急行者的一次停顿，提醒所有追逐：越是紧迫的时刻，越需要看清彼此之间仍然相连的距离。","flat":{},"mult":{},"mechanics":[{"id":"frost_petal"}],"build_tags":["slow","skill","control"],"sources":["shop","chest","reward"]},{"id":"relic_amber_pendulum","name":"琥珀摆锤","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/content_v07/icons/relic_amber_pendulum.png","desc":"普攻首个有效命中暴击，使4秒内下一次小技能伤害增加16%，施放消耗，冷却6秒。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、目标数、范围与冷却不变。","flavor":"琥珀里封着一道尚未来得及散去的金芒，细银摆臂则始终保持着克制的弧度。它纪念一次准确出手之后的判断，而不把成功当作下一次莽撞的理由。短暂的优势，唯有被郑重接续，才有机会成为改变战局的力量。真正值得传承的力量，从不止于赢下一场战斗，更在于为何继续前行。","flat":{},"mult":{},"mechanics":[{"id":"amber_pendulum"}],"build_tags":["critical","skill","rhythm"],"sources":["shop","chest","reward"]},{"id":"relic_root_talisman","name":"归根护符","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v07/icons/relic_root_talisman.png","desc":"护盾因承伤耗尽时，减少当前闪避剩余冷却0.4秒，并使108像素内最近三名敌人减速20%，持续2秒，冷却6秒。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、目标数、范围与冷却不变。","flavor":"细根缠绕着一块已经裂开的护石，绿色新芽却从裂隙最深处伸出。它记得屏障曾经存在，也提醒旅人：失去庇护之后，仍然可以把脚步重新交还给自己。","flat":{},"mult":{},"mechanics":[{"id":"root_talisman"}],"build_tags":["shield","dash","slow"],"sources":["shop","chest","reward"]},{"id":"relic_empty_lamp_note","name":"空灯信笺","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v07/icons/relic_empty_lamp_note.png","desc":"角色144像素内的敌人死亡时回复2MP，冷却2秒；训练目标不触发。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、目标数、范围与冷却不变。","flavor":"没有署名的信被折成一盏小灯，封蜡里留着一缕青白余光。寄信人没有要求谁永远停留，只愿收到它的人，在战火稍歇时仍能想起，那些陪自己走过黑暗的名字。","flat":{},"mult":{},"mechanics":[{"id":"empty_lamp_note"}],"build_tags":["kill","mana","ally"],"sources":["shop","chest","reward"]},{"id":"relic_tide_seals","name":"潮汐双印","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/content_v07/icons/relic_tide_seals.png","desc":"直接主动技能在1秒内命中两名不同敌人，获得最大生命4%的护盾，持续3秒，冷却3秒；同一目标的多段命中只记一次。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、目标数、范围与冷却不变。","flavor":"一枚石印刻着潮起，另一枚刻着潮落，青银水纹把两者温柔连接。它们曾被分开放在失去联系的岸边，直到旅人重新走通那段被遗忘的路。如今这对印记提醒施法者，能够触及不同的声音，才能守住更完整的回应。回廊保存着它走过的路，也为尚未抵达的明天留着一盏安静的灯。","flat":{},"mult":{},"mechanics":[{"id":"tide_seals"}],"build_tags":["skill","shield","multi_target"],"sources":["shop","chest","reward"]},{"id":"relic_quartz_moth","name":"晶翼夜蛾","kind":"buff","rarity":1,"cost":28,"icon":"tex:res://assets/content_v07/icons/relic_quartz_moth.png","desc":"MP低于30%时，普攻首个有效命中追加0.20倍攻击伤害并回复1MP，冷却2秒。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、目标数、范围与冷却不变。","flavor":"紫晶翅膀像两片被夜色打磨过的星屑，最微弱的光也足以让它振翅。它不等太阳升起才寻找方向，愿这份小小的勇气，也能陪伴那些力量将尽却仍未停步的人。","flat":{},"mult":{},"mechanics":[{"id":"quartz_moth"}],"build_tags":["basic","mana","low_mana"],"sources":["shop","chest","reward"]},{"id":"relic_moss_heart","name":"苔庭心石","kind":"buff","rarity":2,"cost":40,"icon":"tex:res://assets/content_v07/icons/relic_moss_heart.png","desc":"连续站定1.5秒且360像素内存在可见敌人时，获得最大生命4%的护盾，持续3秒，冷却8秒；移动会重置站定计时。 同名遗物持有1／2／3件时，数值效果为100%/150%/175%；次数、目标数、范围与冷却不变。","flavor":"细苔把石心裂隙缓缓填满，藤根却没有因此掩去旧日的伤痕。它曾在荒废庭院里度过许多无人经过的季节，终于学会让安静也拥有力量。站稳并不总意味着迟疑，有时是在为下一次不得不面对的风暴认真扎根。旧日的记载可以残缺，后来者却仍拥有亲手写下下一页的权利。","flat":{},"mult":{},"mechanics":[{"id":"moss_heart"}],"build_tags":["stationary","shield","defense"],"sources":["shop","chest","reward"]}]'''

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
	## 只影响同品质、同部位内的相对概率，不再改变品质或部位概率。
	return LootSelection.item_weight(item)


static func in_source(item: Dictionary, source: StringName) -> bool:
	if weight_of(item)<=0:return false
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
		var chosen:=LootSelection.pick_for_source(pool,source,rng)
		if chosen.is_empty():break
		out.append(chosen)
		for i in range(pool.size()-1,-1,-1):
			if pool[i].id==chosen.id:pool.remove_at(i)
	if not out.is_empty() and equippable_chance > 0.0 and rng.randf() < equippable_chance:
		var equippable: Array[Dictionary] = []
		for item in all():
			if str(item.get("id","")) not in excluded_ids and is_equippable(item) and in_source(item, source) and not out.has(item):
				equippable.append(item)
		if not equippable.is_empty():
			out[0] = LootSelection.pick(equippable,LootSelection.GEAR_QUALITY,rng)
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
	var chosen:=LootSelection.pick_for_source(pool,source,rng)
	if chosen.is_empty():return {}
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


static func _state() -> Node:
	# Resolve runtime context without a compiled backedge to the GameState autoload.
	var loop=Engine.get_main_loop()
	return loop.root.get_node_or_null("GameState") if loop is SceneTree else null
