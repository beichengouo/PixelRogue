extends SceneTree
## Read-only entrypoint/input/catalogue smoke check; use an isolated user-data directory.
const EXPECTED_ACTIONS:=["dash","interact","inventory","talents","pause_menu","skill_1","skill_2","skill_3","ultimate","call_goddess"]
func _initialize()->void:call_deferred("_verify")
func _verify()->void:
	var failed:=0
	for action in EXPECTED_ACTIONS:
		if not InputMap.has_action(action):printerr("缺少输入动作：",action);failed+=1
	for path in ["res://src/main/game_shell.tscn","res://src/room_mode/room_main.tscn","res://tools/room_editor/room_editor.tscn","res://assets/room_templates/camp_starlight_corridor.json","res://data/items.json"]:
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):printerr("缺少当前工程入口或数据：",path);failed+=1
	var camp:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/room_templates/camp_starlight_corridor.json"))
	if not camp is Dictionary or str(camp.get("id",""))!="camp_starlight_corridor":printerr("营地模板格式错误");failed+=1
	var items:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	if items is Dictionary:items=items.get("items",[])
	if not items is Array or items.is_empty():printerr("物品目录为空或格式错误");failed+=1
	if failed==0:print("[verify_project] 当前俯视工程入口、输入动作、营地模板与物品目录检查通过")
	quit(1 if failed else 0)
