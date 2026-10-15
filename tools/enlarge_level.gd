extends SceneTree
## 把当前地图扩大一圈：**保留你画的每一个瓦片**，只在空白处补新地形。
##
## 为什么不用 reset_level_scene.gd：那个是「从头重画」，会覆盖你的地图。
## 这个脚本只做加法 —— 读一遍现有地图，然后在空白格子上补：
##   1. 一整条加厚的地面（免得从地图边缘掉下去）
##   2. 左右两端的封边墙
##   3. 两翼的高台、单向平台、浅坑尖刺（保持和你原来一样的手感）
##
## 用法：
##   "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
##       --headless --path . --script res://tools/enlarge_level.gd
##
## 会自动备份成 level_backup_<时间戳>.tscn，画坏了可以拿回来。
##
## 注意：这里刻意「不把场景加进场景树」。因为 Level._ready 会给 Decor 层
## 复制一份去掉碰撞的瓦片集，如果加进去了，保存出来的场景会把整份瓦片集
## 内嵌进 level.tscn（文件暴涨，而且以后换瓦片集不生效）。

const LEVEL_SCENE_PATH := "res://src/world/level.tscn"

const SOURCE_SOLID := 0
const SOURCE_ONE_WAY := 1
const SOURCE_HAZARD := 3

## ---- 新地图范围（格子坐标，可以负数）----
const MIN_X := -24
const MAX_X := 103
const MIN_Y := 4
const MAX_Y := 29
## 你原来地面的表层所在行（玩家就站在这一行上面）
const GROUND_ROW := 16

var _tiles: TileMapLayer
var _existing := {}
var _coords := {}


func _initialize() -> void:
	var packed := load(LEVEL_SCENE_PATH) as PackedScene
	if packed == null:
		printerr("[扩图] 读不到 %s" % LEVEL_SCENE_PATH)
		quit(1)
		return
	var root := packed.instantiate()
	_tiles = root.get_node_or_null("Tiles") as TileMapLayer
	if _tiles == null:
		printerr("[扩图] 场景里找不到 Tiles 层")
		quit(1)
		return

	for cell: Vector2i in _tiles.get_used_cells():
		_existing[cell] = true
	_load_tile_coords()
	var before := _existing.size()

	var plan := _make_plan()
	var added := _apply_plan(plan)
	_widen_sky(root)

	var out := PackedScene.new()
	if out.pack(root) != OK:
		printerr("[扩图] 打包失败")
		quit(1)
		return
	if not _backup():
		quit(1)
		return
	if ResourceSaver.save(out, LEVEL_SCENE_PATH) != OK:
		printerr("[扩图] 保存失败")
		quit(1)
		return
	print("[扩图] 完成：原 %d 格 -> 新 %d 格（新增 %d）" % [before, _existing.size(), added])
	print("[扩图] 新范围：列 %d..%d，行 %d..%d" % [MIN_X, MAX_X, MIN_Y, MAX_Y])
	root.free()
	quit(0)


func _load_tile_coords() -> void:
	## 从你画的地图里取样，保证新地形用的瓦片和你原来画的完全一样，
	## 而不是写死一个编号（写死的话换瓦片集就会变样）。
	_coords = {
		"surface": _sample(Vector2i(10, 16), SOURCE_SOLID, Vector2i(2, 1)),
		"fill": _sample(Vector2i(10, 17), SOURCE_SOLID, Vector2i(4, 0)),
		"one_way": _sample(Vector2i(25, 10), SOURCE_ONE_WAY, Vector2i(11, 4)),
		"hazard": _sample(Vector2i(23, 16), SOURCE_HAZARD, Vector2i(2, 6)),
	}
	print("[扩图] 取样瓦片：%s" % str(_coords))


func _sample(cell: Vector2i, want_source: int, fallback: Vector2i) -> Vector2i:
	if _tiles.get_cell_source_id(cell) != want_source:
		return fallback
	var atlas := _tiles.get_cell_atlas_coords(cell)
	return fallback if atlas.x < 0 else atlas


func _make_plan() -> Dictionary:
	## 先把要新增的格子全部列出来（后面的写法覆盖前面的，方便「先铺地面再挖坑」）
	var plan := {}

	# 1. 加厚地面：从原来的表层一直填到地图底部，从此不会掉出世界
	for x in range(MIN_X, MAX_X + 1):
		for y in range(GROUND_ROW, MAX_Y + 1):
			plan[Vector2i(x, y)] = "solid"

	# 2. 左右封边墙
	for y in range(MIN_Y, GROUND_ROW):
		plan[Vector2i(MIN_X, y)] = "solid"
		plan[Vector2i(MAX_X, y)] = "solid"

	# 3. 左翼：高台 + 两级单向平台 + 一处地刺
	_block(plan, -21, -15, 13, 15)
	_platform(plan, -17, -10, 10)
	_platform(plan, -8, -3, 13)
	_pit(plan, -12, -11)
	_block(plan, -6, -5, 12, 15)

	# 4. 右翼：商人（列 53）右边留出一段开阔地，再往右是高台和平台
	_platform(plan, 56, 62, 13)
	_block(plan, 63, 71, 13, 15)
	_platform(plan, 75, 83, 10)
	_pit(plan, 85, 86)
	_platform(plan, 88, 95, 13)
	_block(plan, 97, MAX_X, 13, 15)

	# 5. 上层浮空平台，让新地图有纵向探索空间
	_platform(plan, -14, -8, 7)
	_platform(plan, 20, 26, 7)
	_platform(plan, 44, 50, 6)
	_platform(plan, 66, 72, 7)
	_platform(plan, 90, 96, 6)

	# 「伤害」格最后写，保证不会被地面覆盖
	return plan


func _block(plan: Dictionary, x0: int, x1: int, y0: int, y1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			plan[Vector2i(x, y)] = "solid"


func _platform(plan: Dictionary, x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1 + 1):
		plan[Vector2i(x, y)] = "one_way"


func _pit(plan: Dictionary, x0: int, x1: int) -> void:
	## 地面表层挖两格换成地刺：下面是实心，掉进去只掉血不会掉出地图
	for x in range(x0, x1 + 1):
		plan[Vector2i(x, GROUND_ROW)] = "hazard"


func _apply_plan(plan: Dictionary) -> int:
	## 只画「原本是空白」的格子 —— 你画过的任何东西都不动
	var final := {}
	for cell: Vector2i in _existing:
		final[cell] = true
	for cell: Vector2i in plan:
		if not _existing.has(cell):
			final[cell] = true

	var added := 0
	for cell: Vector2i in plan:
		if _existing.has(cell):
			continue
		var kind: String = plan[cell]
		match kind:
			"hazard":
				_tiles.set_cell(cell, SOURCE_HAZARD, _coords["hazard"])
			"one_way":
				_tiles.set_cell(cell, SOURCE_ONE_WAY, _coords["one_way"])
			_:
				# 头顶是空的那种用草皮，被压住的用泥土
				var open_above := not final.has(cell + Vector2i(0, -1))
				_tiles.set_cell(cell, SOURCE_SOLID, _coords["surface"] if open_above else _coords["fill"])
		_existing[cell] = true
		added += 1
	return added


func _widen_sky(root: Node) -> void:
	## 天空是一张拉伸的图，地图变宽后要跟着放大，否则右端会露出背景底色
	var sky := root.get_node_or_null("Background/Sky/SkySprite") as Sprite2D
	if sky != null:
		sky.scale = Vector2(115.0, 46.0)
		sky.position = Vector2(-1300.0, -700.0)
		print("[扩图] 天空已放大以覆盖新地图")


func _backup() -> bool:
	var src := ProjectSettings.globalize_path(LEVEL_SCENE_PATH)
	var dir := src.get_base_dir()
	var stamp := "%d" % int(Time.get_unix_time_from_system())
	var dst := dir.path_join("level_backup_%s.tscn" % stamp)
	var err := DirAccess.copy_absolute(src, dst)
	if err != OK:
		printerr("[扩图] 备份失败（错误码 %d），已中止，地图没有被改动" % err)
		return false
	print("[扩图] 已备份原地图 -> %s" % dst)
	return true
