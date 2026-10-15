extends SceneTree
## 生成两个瓦片集（可以随时重复运行，**不会**影响你已经画好的地图）。
##
##   assets/kenney/terrain_tileset.tres    地形瓦片集，分四组：
##       source 0「实心」 四面都挡          —— 地面、墙
##       source 1「单向」 只能从上面踩      —— 悬空平台（能从下面跳穿，也能按 ↓+跳穿下去）
##       source 2「透明」 完全不挡          —— 纯装饰（树、草、石头……）
##       source 3「伤害」 不挡路、只扣血    —— 尖刺、仙人掌、危险液体……
##   assets/kenney/background_tileset.tres 背景装饰瓦片集（24 块，无碰撞）
##
## 图集里 180 块瓦片会全部放进四个组，你想用哪块就用哪块，区别只是碰撞行为。
## 全透明的空格会自动跳过（否则「实心」组里会出现看不见的墙）。
##
## 用法（在工程根目录执行）：
##   "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
##       --headless --path . --script res://tools/build_tilesets.gd

const TERRAIN_TILESET_PATH := "res://assets/kenney/terrain_tileset.tres"
const BACKGROUND_TILESET_PATH := "res://assets/kenney/background_tileset.tres"

const TILE := 36
const TERRAIN_ATLAS := "res://assets/kenney/tiles_36px.png"
const TERRAIN_COLUMNS := 20
const TERRAIN_ROWS := 9

const BG_TILE := 48
const BG_ATLAS := "res://assets/kenney/backgrounds_48px.png"
const BG_COLUMNS := 8
const BG_ROWS := 3

## 分组编号（这些数字也被游戏代码引用，改的话要一起改 Level 里的常量）
const SOURCE_SOLID := 0
const SOURCE_ONE_WAY := 1
const SOURCE_DECOR := 2
const SOURCE_HAZARD := 3

## 物理层编号（TileSet 里的第几个物理层）
const PHYS_SOLID := 0
const PHYS_ONE_WAY := 1
const PHYS_HAZARD := 2

## 每组的碰撞模式
const MODE_SOLID := 0
const MODE_ONE_WAY := 1
const MODE_NO_COLLISION := 2
const MODE_HAZARD := 3


func _initialize() -> void:
	ResourceSaver.save(_build_terrain_tileset(), TERRAIN_TILESET_PATH)
	print("已生成：%s" % TERRAIN_TILESET_PATH)
	ResourceSaver.save(_build_background_tileset(), BACKGROUND_TILESET_PATH)
	print("已生成：%s" % BACKGROUND_TILESET_PATH)
	quit(0)


func _build_terrain_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	# 三个物理层：实心 / 单向 / 伤害。
	# 单向单独占一层，玩家才能只关掉它来实现「按 ↓+跳 穿下去」，
	# 否则会把脚下的实心地面也一起穿掉。
	tileset.add_physics_layer(PHYS_SOLID)
	tileset.set_physics_layer_collision_layer(PHYS_SOLID, Layers.WORLD)
	tileset.set_physics_layer_collision_mask(PHYS_SOLID, 0)
	tileset.add_physics_layer(PHYS_ONE_WAY)
	tileset.set_physics_layer_collision_layer(PHYS_ONE_WAY, Layers.ONE_WAY)
	tileset.set_physics_layer_collision_mask(PHYS_ONE_WAY, 0)
	tileset.add_physics_layer(PHYS_HAZARD)
	tileset.set_physics_layer_collision_layer(PHYS_HAZARD, Layers.HAZARD)
	tileset.set_physics_layer_collision_mask(PHYS_HAZARD, 0)

	var used := _non_empty_terrain_tiles()
	print("地形图集里非空瓦片：%d / %d" % [used.size(), TERRAIN_COLUMNS * TERRAIN_ROWS])

	# 关键顺序：必须先把图集挂到 TileSet 上，再创建瓦片设碰撞，
	# 否则 TileData 看不到物理层，碰撞会静默设置失败（这里踩过坑）。
	_add_source(tileset, SOURCE_SOLID, "实心", used, MODE_SOLID, PHYS_SOLID)
	_add_source(tileset, SOURCE_ONE_WAY, "单向", used, MODE_ONE_WAY, PHYS_ONE_WAY)
	_add_source(tileset, SOURCE_DECOR, "透明", used, MODE_NO_COLLISION, -1)
	_add_source(tileset, SOURCE_HAZARD, "伤害", used, MODE_HAZARD, PHYS_HAZARD)
	return tileset


func _add_source(
	tileset: TileSet,
	source_id: int,
	source_name: String,
	used: Array[Vector2i],
	mode: int,
	phys_layer: int
) -> void:
	var source := TileSetAtlasSource.new()
	source.resource_name = source_name
	source.texture = load(TERRAIN_ATLAS)
	source.texture_region_size = Vector2i(TILE, TILE)
	tileset.add_source(source, source_id)

	var half := float(TILE) * 0.5
	var points := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	for coords: Vector2i in used:
		source.create_tile(coords)
		if mode == MODE_NO_COLLISION:
			continue
		var data := source.get_tile_data(coords, 0)
		data.add_collision_polygon(phys_layer)
		# 碰撞多边形以图块【中心】为原点（用探针脚本实测确认过），
		# 写成 (0,0)-(36,36) 会整体偏移 18 像素。
		data.set_collision_polygon_points(phys_layer, 0, points)
		if mode == MODE_ONE_WAY:
			data.set_collision_polygon_one_way(phys_layer, 0, true)
			data.set_collision_polygon_one_way_margin(phys_layer, 0, 4.0)


func _non_empty_terrain_tiles() -> Array[Vector2i]:
	## 排除全透明的空格，否则会变成「看不见的墙」
	var image := (load(TERRAIN_ATLAS) as Texture2D).get_image()
	var out: Array[Vector2i] = []
	for row in TERRAIN_ROWS:
		for col in TERRAIN_COLUMNS:
			if _tile_has_content(image, col * TILE, row * TILE, TILE):
				out.append(Vector2i(col, row))
	return out


func _tile_has_content(image: Image, ox: int, oy: int, size: int) -> bool:
	for y in size:
		for x in size:
			if image.get_pixel(ox + x, oy + y).a > 0.03:
				return true
	return false


func _build_background_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(BG_TILE, BG_TILE)
	var source := TileSetAtlasSource.new()
	source.resource_name = "背景"
	source.texture = load(BG_ATLAS)
	source.texture_region_size = Vector2i(BG_TILE, BG_TILE)
	tileset.add_source(source, 0)   # 背景只做装饰，不需要碰撞
	for row in BG_ROWS:
		for col in BG_COLUMNS:
			source.create_tile(Vector2i(col, row))
	return tileset
