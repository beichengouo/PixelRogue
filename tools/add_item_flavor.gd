extends SceneTree
## 一次性工具：给 data/items.json 里每件道具补一句「简介」（flavor）。
## 已经写过 flavor 的道具不会被覆盖。
##
## 用法：
##   "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
##       --headless --path . --script res://tools/add_item_flavor.gd

const PATH := "res://data/items.json"

const FLAVORS := {
	"iron_sword": "剑身有细密的使用痕迹，握把缠着旧布条。",
	"whetstone": "带着铁屑的粗石，蹭几下就能让钝刃回锋。",
	"feather_boots": "靴筒里缝着一根飞鸟的尾羽，走路几乎听不见声音。",
	"spring_shoes": "鞋底嵌着弹力魔石，落地会轻轻回弹。",
	"guardian_mail": "胸口一块磨得发亮的护片，挡得住最直接的一击。",
	"giant_belt": "宽厚的皮革腰带，扣环上刻着巨人的符文。",
	"blood_charm": "暗红的纹路像血管一样在木牌上蔓延。",
	"thorn_cloak": "布料里编进了干枯的荆棘，碰它会扎手。",
	"assassin_mark": "一枚刻着眼纹的铜章，贴在皮肤上微微发凉。",
	"lucky_coin": "边缘被咬出一个小缺口的老金币。",
	"gale_boots": "靴面缝着风精灵的鳞片，起步比思考更快。",
	"double_jump_charm": "画着两片羽毛的纸符，据说踩着空气也能再起跳。",
	"berserk_blood": "瓶里是不安分的红色液滴，一直在轻轻翻涌。",
	"phoenix_heart": "温热的小小结晶，贴近能听见极轻的搏动声。",
	"executioner": "刃口有一道洗不掉的暗色，谁都不想细看。",
	"wand_arcane": "杖尖嵌着一颗跳动的紫色晶体。",
	"staff_fire": "杖身温热，靠近能闻到淡淡的硫磺味。",
	"bow_wood": "弓臂是整根老木弯成的，弦上过蜂蜡。",
	"dagger_iron": "短到几乎能藏进袖口，刃薄得透光。",
	"warhammer_gold": "锤头刻着秘银纹路，抬手就知道它有多沉。",
	"plate_mail": "拼接严密的钢片，扣上时会发出清脆的一声。",
	"reactive_plating": "甲面上排着会自己收紧的金属鳞片。",
	"mage_robe": "肩上绣着星轨，走路时会轻轻飘起来。",
	"crystal_pendant": "银链挂着的蓝宝石，会在危险前微微发暗。",
	"life_ampoule": "小小的粉色晶石，掌心捂着会变暖。",
	"cursed_skull": "不知是谁的头骨，眼窝里点着一点幽火。",
	"lucky_charm": "黄玉打磨的方片，据说掉进过三次悬崖都没碎。",
	"crit_ring": "戒指内圈刻着极小的准星。",
	"gem_crown": "用整块宝石雕成的冠，戴久了会有点压头。",
	"potion_health": "温热的红色药水，闻起来像草药糖。",
	"potion_arcane": "紫色液体里有细小的光点在打转。",
	"potion_energy": "冰凉的青绿药水，喝下去脚步会变轻。",
	"potion_frost": "瓶壁结着一层薄霜，握久了指尖发麻。",
}


func _initialize() -> void:
	if not FileAccess.file_exists(PATH):
		printerr("[简介] 找不到 %s，请先跑 tools/export_item_table.gd" % PATH)
		quit(1)
		return
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(doc) != TYPE_DICTIONARY:
		printerr("[简介] %s 解析失败" % PATH)
		quit(1)
		return
	var written := 0
	for raw in (doc as Dictionary).get("items", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw
		if entry.has("flavor") and not str(entry["flavor"]).is_empty():
			continue
		var id := str(entry.get("id", ""))
		if FLAVORS.has(id):
			entry["flavor"] = FLAVORS[id]
			written += 1
	var file := FileAccess.open(ProjectSettings.globalize_path(PATH), FileAccess.WRITE)
	if file == null:
		printerr("[简介] 写入失败")
		quit(1)
		return
	file.store_string(JSON.stringify(doc, "  "))
	file.close()
	print("[简介] 已为 %d 件道具写入简介 -> %s" % [written, PATH])
	quit(0)
