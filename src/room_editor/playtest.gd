class_name RoomEditorPlaytest
extends Node2D

const SESSION_ROOT := "E:/CodexWorkspace/PixelRogue/temp/room-editor-playtests"
const SCENE := "res://src/room_editor/playtest.tscn"
const InvinciblePlayer := preload("res://src/room_editor/invincible_player.gd")

var room: RoomLevel
var player: RoomPlayer
var enemies_root: Node2D
var fx_root: Node2D
var spawn_enemies := false

static func launch(document: Dictionary, with_enemies: bool) -> int:
	if not RoomTemplateValidator.load_errors(document).is_empty():return ERR_INVALID_DATA
	if RoomTemplateCodec.to_layout(document).is_empty():return ERR_INVALID_DATA
	var token := "%d-%d-%d" % [Time.get_unix_time_from_system(), OS.get_process_id(), randi()]
	var session := SESSION_ROOT.path_join(token)
	var error := DirAccess.make_dir_recursive_absolute(session)
	if error != OK:return error
	var template_path := session.path_join("template.json")
	error = RoomTemplateCodec.write_file(template_path, document.duplicate(true))
	if error != OK:return error
	var isolated_appdata := session.path_join("appdata")
	error = DirAccess.make_dir_recursive_absolute(isolated_appdata)
	if error != OK:return error
	var project_path := ProjectSettings.globalize_path("res://")
	var executable := OS.get_executable_path()
	var arguments := PackedStringArray(["--path", project_path, "--scene", SCENE, "--log-file", session.path_join("godot.log"), "--", "--room-editor", "--room-editor-playtest", template_path, "1" if with_enemies else "0"])
	var previous_appdata := OS.get_environment("APPDATA")
	OS.set_environment("APPDATA", isolated_appdata)
	if OS.get_environment("APPDATA").replace("\\", "/") != isolated_appdata:
		OS.set_environment("APPDATA", previous_appdata)
		return ERR_CANT_CREATE
	var pid := OS.create_process(executable, arguments)
	OS.set_environment("APPDATA", previous_appdata)
	return OK if pid > 0 else ERR_CANT_CREATE

func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	var index := arguments.find("--room-editor-playtest")
	if index < 0 or index + 2 >= arguments.size():
		push_error("Missing room editor playtest arguments")
		get_tree().quit(1)
		return
	var template := RoomTemplateCodec.read_file(arguments[index + 1])
	if not RoomTemplateValidator.load_errors(template).is_empty():
		push_error("Invalid room editor playtest template")
		get_tree().quit(1)
		return
	if template.room_kinds.has("camp"):
		Outpost._ready()
		if Outpost.data.is_empty():
			Outpost.data={"version":4,"gold":0,"danger":0,"inventory":{},"capacity":30,"expansions":0,"shop":{},"shop_seed":1,"contracts":[],"bonds":{"sylphiette":0,"iris":0,"merchant":0,"tavern":0},"events":{},"best":{},"active":{},"last_result":{},"locks":{},"presets":{},"tracked_contract":"","contract_jobs":{},"contract_clock":0,"bond_daily":{}}
		var camp:=CampWorld.new();camp.editor_validation=true;camp.document_override=template;add_child(camp)
		camp.back_requested.connect(_quit_playtest);return
	spawn_enemies = arguments[index + 2] == "1"
	if GameState.stats == null: GameState.stats = StatBlock.new()
	GameState.new_run(20261011)
	_build_room(template)
	_build_overlay()
	if spawn_enemies:_spawn_enemies()

func _build_room(template: Dictionary) -> void:
	var background := ColorRect.new()
	background.color = Color("101922")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := CanvasLayer.new()
	backdrop.layer = -100
	add_child(backdrop)
	backdrop.add_child(background)
	room = load("res://src/room_mode/room_level.tscn").instantiate()
	add_child(room)
	var sorting := Node2D.new()
	sorting.y_sort_enabled = true
	add_child(sorting)
	room.props_root.reparent(sorting)
	room.decor_root.reparent(sorting)
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	sorting.add_child(actors)
	enemies_root = Node2D.new()
	enemies_root.y_sort_enabled = true
	sorting.add_child(enemies_root)
	fx_root = Node2D.new()
	fx_root.add_to_group("room_fx")
	add_child(fx_root)
	var layout := RoomTemplateCodec.to_layout(template)
	var kind := str(template.room_kinds[0])
	var record := {"id":"0,0", "seed":20261011, "kind":kind, "biome":str(template.theme), "doors":["0,-1","1,0","0,1","-1,0"], "cleared":true, "delta":{}, "terrain_layout":layout}
	room.load_room(record)
	player = InvinciblePlayer.new()
	player.room = room
	player.level = room
	player.position = room.nearest_clear(room.room_rect.get_center(), 12.0)
	actors.add_child(player)
	room.ensure_clear_actors()
	# A headless behavior check has no viewport to follow; the playable window
	# still uses the same RoomCamera as the main room mode.
	if DisplayServer.get_name() == "headless":return
	var camera := RoomCamera.new()
	camera.room = room
	add_child(camera)
	camera.setup(room.bounds())
	camera.target = player
	camera.snap_to_target()

func _spawn_enemies() -> void:
	var markers: Array = room.record.terrain_layout.get("markers", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261011
	var positions: Array[Vector2] = []
	for marker in markers:
		if str(marker.get("asset_id", "")) != "spawn":continue
		var at: Array = marker.get("at", [])
		if at.size() != 2:continue
		var point := RoomLayout.center(Vector2i(int(at[0]), int(at[1])))
		if room.body_clear(point, 12.0) and point.distance_to(player.position) > 36.0:positions.append(point)
	if positions.is_empty():
		for i in 3:positions.append(room.spawn_point(rng, player.position, 12.0))
	var kinds := [&"walker", &"charger", &"caster"]
	for i in positions.size():
		var enemy := RoomEnemy.new()
		enemy.configure(kinds[i % kinds.size()])
		enemy.room = room
		enemy.setup(player, room, 1.0, 1.0, 1.0)
		enemy.fx_root = fx_root
		enemy.position = positions[i]
		enemies_root.add_child(enemy)
	room.ensure_clear_actors()

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var label := Label.new()
	label.text = "地图游戏验证 · 玩家无敌 · %s · WASD 移动 / 方向键攻击 / Shift 冲刺" % ("刷怪开启" if spawn_enemies else "刷怪关闭")
	row.add_child(label)
	var button := Button.new()
	button.text = "返回编辑器  Esc"
	button.pressed.connect(_quit_playtest)
	row.add_child(button)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_quit_playtest()

func _quit_playtest() -> void:
	AudioManager.shutdown()
	get_tree().quit()
