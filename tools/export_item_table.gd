extends SceneTree
## 把 ItemDB 里内置的道具定义导出成一份可编辑的 JSON（res://data/items.json）。
##
## 之后游戏启动会优先读这份 JSON —— 你想加/删道具、换图标、改效果和掉落概率，
## 直接编辑那个文件就行，不用碰代码。
##
## 什么时候需要重跑这个工具：
##   · 你在代码里改了内置道具，想同步到 JSON（会覆盖 JSON，先备份）
##   · items.json 被删了/写坏了，想要一份干净的
##
## 用法：
##   "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
##       --headless --path . --script res://tools/export_item_table.gd

const OUT_PATH := "res://data/items.json"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/"))
	# 先读一遍现有文件：你在里面手写的 flavor / weight / sources 要保留下来，
	# 否则「重新导出」会把你的维护成果冲掉。
	var keep := _load_keep_fields()
	var items: Array = []
	for item in ItemDB.all():
		var entry := _item_to_json(item)
		var id := str(entry.get("id", ""))
		if keep.has(id):
			for field in ["flavor", "weight", "sources"]:
				if (keep[id] as Dictionary).has(field):
					entry[field] = keep[id][field]
		items.append(entry)
	var doc := {
		"version": 1,
		"_说明": "道具表。改完保存，重开游戏生效。字段说明见 data/items_README.txt",
		"items": items,
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if file == null:
		printerr("[导出道具表] 写入失败：%s" % OUT_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(doc, "  "))
	file.close()
	print("[导出道具表] 已写出 %d 件道具 -> %s" % [items.size(), OUT_PATH])
	quit(0)


func _load_keep_fields() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(OUT_PATH):
		return out
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT_PATH))
	if typeof(doc) != TYPE_DICTIONARY:
		return out
	for raw in (doc as Dictionary).get("items", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw
		var fields := {}
		for field in ["flavor", "weight", "sources"]:
			if entry.has(field):
				fields[field] = entry[field]
		if not fields.is_empty():
			out[str(entry.get("id", ""))] = fields
	return out


func _item_to_json(item: Dictionary) -> Dictionary:
	var out := {
		"id": String(item["id"]),
		"name": str(item["name"]),
		"desc": str(item["desc"]),
		"kind": String(item.get("kind", &"buff")),
		"rarity": int(item["rarity"]),
		"cost": int(item["cost"]),
		"icon": _icon_text(item),
		"flat": _stats_text(item.get("flat", {})),
		"mult": _stats_text(item.get("mult", {})),
	}
	if item.has("weapon"):
		out["weapon"] = item["weapon"].duplicate(true)
		var weapon: Dictionary = out["weapon"]
		# 悬浮武器用哪张图：和图标同一张就写 "same"
		weapon["sprite"] = "same"
		if weapon.has("spread"):
			weapon["spread_deg"] = rad_to_deg(float(weapon["spread"]))
			weapon.erase("spread")
		if weapon.has("color"):
			weapon["color"] = "#" + (weapon["color"] as Color).to_html(false)
	if item.has("effect"):
		var effect: Dictionary = (item["effect"] as Dictionary).duplicate(true)
		if effect.has("stat"):
			effect["stat"] = String(effect["stat"])
		effect["kind"] = String(effect["kind"])
		out["effect"] = effect
	return out


func _stats_text(stats: Dictionary) -> Dictionary:
	var out := {}
	for key: StringName in stats:
		out[String(key)] = float(stats[key])
	return out


func _icon_text(item: Dictionary) -> String:
	var icon: Dictionary = item.get("icon", {})
	var tex := str(icon.get("tex", ""))
	var idx := int(icon.get("idx", -1))
	if idx >= 0:
		return "sheet:%d" % idx
	if tex.begins_with(ItemDB.ICON_DIR):
		return "icons:" + tex.substr(ItemDB.ICON_DIR.length())
	return "tex:" + tex
