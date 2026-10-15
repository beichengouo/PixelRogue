extends Node
## 剧情状态：分支线、女神好感、看过的剧情、累计死亡次数、第一次轮回选的职业。
##
## 和「本局存档」分开存（user://pixel_rogue_story.json）—— 本局死了重开，
## 剧情进度要留着，所以不能跟着 run 一起清空。

const PATH := "user://pixel_rogue_story.json"

var flags: Dictionary = {}          # 任意标记：解锁、选择记录…（Key 统一用 String）
var affinity: int:
	get: return int(get_flag(&"affinity", 0))
	set(value): flags[_personal_key(&"affinity")] = value
var deaths: int = 0                 # 累计死亡次数（第一次死亡要演剧情）
var player_class: String:
	get: return str(get_flag(&"class", ""))
	set(value): flags[_personal_key(&"class")] = value
var story_line: String:
	get: return str(get_flag(&"line", ""))
	set(value): flags[_personal_key(&"line")] = value

const PERSONAL_FLAGS := ["intro_rude", "intro_silent", "secret_route", "start_weapon", "skipped_story", "affinity", "class", "line"]

func _personal_key(key: StringName, character_id: StringName = &"") -> String:
	var id := Characters.current_id() if character_id == &"" else character_id
	return "character:%s:%s" % [id, key]


func _ready() -> void:
	if "--room-editor" in OS.get_cmdline_user_args():return
	load_story()


## ---------------- 读写标记 ----------------

func get_flag(key: StringName, default_value: Variant = false) -> Variant:
	if String(key) in PERSONAL_FLAGS:
		if flags.has(_personal_key(key)): return flags[_personal_key(key)]
		if Characters.current_id() != Characters.DEFAULT_ID: return default_value
	return flags.get(String(key), default_value)


func set_flag(key: StringName, value: Variant = true) -> void:
	flags[_personal_key(key) if String(key) in PERSONAL_FLAGS else String(key)] = value
	save_story()


func has_flag(key: StringName) -> bool:
	return bool(get_flag(key, false))


func seen(scene_id: StringName, character_id: StringName = &"") -> bool:
	var id := Characters.current_id() if character_id == &"" else character_id
	var scoped := _personal_key(StringName("seen:" + String(scene_id)), id)
	if flags.has(scoped): return bool(flags[scoped])
	return id == Characters.DEFAULT_ID and bool(flags.get("seen:" + String(scene_id), false))


func mark_seen(scene_id: StringName, character_id: StringName = &"") -> void:
	flags[_personal_key(StringName("seen:" + String(scene_id)), character_id)] = true
	save_story()


func completed(scene_id: StringName, character_id: StringName = &"") -> bool:
	# Legacy seen entries are completed; new in-progress scenes remain resumable.
	return seen(scene_id, character_id) and not bool(flags.get(_personal_key(StringName("pending:" + String(scene_id)), character_id), false))


func begin_scene(scene_id: StringName) -> void:
	if scene_id == &"" or completed(scene_id): return
	flags[_personal_key(StringName("pending:" + String(scene_id)))] = true
	mark_seen(scene_id)


func complete_scene(scene_id: StringName, next_id: StringName = &"") -> void:
	if scene_id == &"": return
	flags.erase(_personal_key(StringName("pending:" + String(scene_id))))
	flags[_personal_key(StringName("next:" + String(scene_id)))] = String(next_id)
	mark_seen(scene_id)


func scene_next(scene_id: StringName, fallback: StringName = &"") -> StringName:
	return StringName(flags.get(_personal_key(StringName("next:" + String(scene_id))), fallback))


func add_affinity(amount: int) -> void:
	affinity += amount
	save_story()


func register_death() -> int:
	## 返回「这是第几次死亡」——1 表示第一次，要走星辉回廊那段
	deaths += 1
	save_story()
	return deaths


func apply_choice(option: Dictionary) -> void:
	## 选项效果统一在这里落地：好感 / 标记 / 分支线 / 给道具 / 解锁 / 职业
	if option.has("affinity"):
		add_affinity(int(option["affinity"]))
	var new_flags: Dictionary = option.get("flags", {})
	for key: StringName in new_flags:
		flags[_personal_key(key) if String(key) in PERSONAL_FLAGS else String(key)] = new_flags[key]
	if option.has("line"):
		story_line = str(option["line"])
	if option.has("class"):
		player_class = str(option["class"])
	var give := str(option.get("give", ""))
	if give != "" and GameState.run_active:
		var item := ItemDB.by_id(give)
		if not item.is_empty():
			if not GameState.add_item(item) and is_instance_valid(GameState.runtime_node):
				GameState.runtime_node.drop_inventory_item(item)
	save_story()


## ---------------- 存档 ----------------

func snapshot() -> Dictionary:
	return {
		"story_version": 2,
		"flags": flags.duplicate(true),
		"affinity": affinity,
		"deaths": deaths,
		"class": player_class,
		"line": story_line,
	}


func restore(data: Dictionary) -> void:
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	deaths = int(data.get("deaths", 0))
	# 旧版个人状态只属于首发角色，不随当前选择误迁移到未来角色。
	if int(data.get("story_version", 0)) < 2:
		for key in ["affinity", "class", "line"]:
			flags[_personal_key(StringName(key), Characters.DEFAULT_ID)] = data.get(key, 0 if key == "affinity" else "")


func save_story() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(snapshot()))
	file.close()


func load_story() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		restore(parsed)


func reset_story() -> void:
	## 调试用：把剧情进度清空（重新走一遍序章）
	flags.clear()
	affinity = 0
	deaths = 0
	player_class = ""
	story_line = ""
	save_story()
