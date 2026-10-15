extends SceneTree
## 把关卡场景按 level_data.gd 的字符模板重新生成。
##
## ⚠ 会覆盖你在 level.tscn 里画的一切 ⚠
## 平时不要跑它。只有「画坏了想从头来」时才用。
## 如果只是想改瓦片集，用 tools/build_tilesets.gd —— 那个不会动你的地图。
##
## 用法：
##   "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
##       --headless --path . --script res://tools/reset_level_scene.gd

const LEVEL_SCENE_PATH := "res://src/world/level.tscn"
const TERRAIN_TILESET_PATH := "res://assets/kenney/terrain_tileset.tres"
const BACKGROUND_TILESET_PATH := "res://assets/kenney/background_tileset.tres"

const TILE := 36
const TERRAIN_COLUMNS := 20
const BG_TILE := 48
const BG_COLUMNS := 8

## 瓦片分组编号（与 tools/build_tilesets.gd 保持一致）
const SOURCE_SOLID := 0
const SOURCE_ONE_WAY := 1
const SOURCE_DECOR := 2
const SOURCE_HAZARD := 3

## 地表和填充用的瓦片编号
const GRASS_TOP := 2
const DIRT_FILL := 4
## 尖刺外观用的瓦片编号（地形图集里的冰刺/地刺）
const HAZARD_TILE := 164

const SKY_TILE := 0


func _initialize() -> void:
	if not ResourceLoader.exists(TERRAIN_TILESET_PATH):
		printerr("找不到瓦片集，请先跑 tools/build_tilesets.gd")
		quit(1)
		return
	var terrain: TileSet = load(TERRAIN_TILESET_PATH)
	var background: TileSet = load(BACKGROUND_TILESET_PATH)
	_build(terrain, background)
	quit(0)


func _build(terrain: TileSet, background: TileSet) -> void:
	var rows: Array = LevelData.ROWS
	var width: int = String(rows[0]).length()
	var height: int = rows.size()

	var solid := {}
	var one_way := {}
	var hazard := {}
	var player_cell := Vector2i(2, height - 3)
	var shop_cell := Vector2i(width / 2, height - 5)

	for y in height:
		var row := String(rows[y])
		for x in width:
			match row[x]:
				"#":
					solid[Vector2i(x, y)] = true
				"=":
					one_way[Vector2i(x, y)] = true
				"^":
					hazard[Vector2i(x, y)] = true
				"P":
					player_cell = Vector2i(x, y)
				"S":
					shop_cell = Vector2i(x, y)

	var root := Node2D.new()
	root.name = "Level"
	root.set_script(load("res://src/world/level.gd"))

	_add_background(root, background)

	# 装饰层：和地形共用瓦片集但不带碰撞（level.gd 运行时会剥掉它的物理层）
	var decor := TileMapLayer.new()
	decor.name = "Decor"
	decor.tile_set = terrain
	root.add_child(decor)
	decor.owner = root

	var tiles := TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = terrain
	root.add_child(tiles)
	tiles.owner = root
	_paint(tiles, solid, one_way, hazard)

	var player_spawn := SpawnPoint.new()
	player_spawn.name = "PlayerSpawn"
	player_spawn.label_text = "玩家出生点"
	player_spawn.marker_color = Color(0.35, 0.85, 1.0)
	player_spawn.z_index = 100
	player_spawn.position = _cell_center(player_cell)
	root.add_child(player_spawn)
	player_spawn.owner = root

	var shop_spawn := SpawnPoint.new()
	shop_spawn.name = "ShopSpawn"
	shop_spawn.label_text = "商店位置"
	shop_spawn.marker_color = Color(1.0, 0.75, 0.25)
	shop_spawn.z_index = 100
	shop_spawn.position = _cell_center(shop_cell)
	root.add_child(shop_spawn)
	shop_spawn.owner = root

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		printerr("打包关卡场景失败")
		return
	if ResourceSaver.save(packed, LEVEL_SCENE_PATH) != OK:
		printerr("保存关卡场景失败")
		return
	print("已重置关卡：%s（%d x %d 格；实心 %d、单向 %d、伤害 %d）"
		% [LEVEL_SCENE_PATH, width, height, solid.size(), one_way.size(), hazard.size()])
	root.free()


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x * TILE) + TILE * 0.5, float(cell.y * TILE) + TILE * 0.5)


func _coords(index: int) -> Vector2i:
	return Vector2i(index % TERRAIN_COLUMNS, index / TERRAIN_COLUMNS)


func _paint(tiles: TileMapLayer, solid: Dictionary, one_way: Dictionary, hazard: Dictionary) -> void:
	var all := {}
	for cell: Vector2i in solid:
		all[cell] = SOURCE_SOLID
	for cell: Vector2i in one_way:
		all[cell] = SOURCE_ONE_WAY
	for cell: Vector2i in hazard:
		all[cell] = SOURCE_HAZARD
	for cell: Vector2i in all:
		var source: int = all[cell]
		if source == SOURCE_HAZARD:
			tiles.set_cell(cell, source, _coords(HAZARD_TILE))
			continue
		# 头顶没有东西的格子用草顶，其余用泥土填充
		var index := GRASS_TOP
		if all.has(cell + Vector2i(0, -1)) and all[cell + Vector2i(0, -1)] != SOURCE_HAZARD:
			index = DIRT_FILL
		tiles.set_cell(cell, source, _coords(index))


func _add_background(root: Node2D, background: TileSet) -> void:
	var parallax := ParallaxBackground.new()
	parallax.name = "Background"
	parallax.layer = -1
	root.add_child(parallax)
	parallax.owner = root

	var sky_layer := ParallaxLayer.new()
	sky_layer.name = "Sky"
	sky_layer.motion_scale = Vector2(0.12, 1.0)
	parallax.add_child(sky_layer)
	sky_layer.owner = root

	var sky := Sprite2D.new()
	sky.name = "SkySprite"
	sky.texture = load("res://assets/kenney/backgrounds_48px.png")
	sky.region_enabled = true
	sky.region_rect = Rect2(
		float((SKY_TILE % BG_COLUMNS) * BG_TILE),
		float((SKY_TILE / BG_COLUMNS) * BG_TILE),
		float(BG_TILE), float(BG_TILE)
	)
	sky.centered = false
	sky.scale = Vector2(95.0, 40.0)
	sky.position = Vector2(-1200.0, -600.0)
	sky_layer.add_child(sky)
	sky.owner = root

	# 远景装饰层：留给你自己摆（选中它，用 TileMap 面板画）
	var scenery_layer := ParallaxLayer.new()
	scenery_layer.name = "Scenery"
	scenery_layer.motion_scale = Vector2(0.45, 1.0)
	parallax.add_child(scenery_layer)
	scenery_layer.owner = root

	var scenery := TileMapLayer.new()
	scenery.name = "SceneryTiles"
	scenery.tile_set = background
	scenery_layer.add_child(scenery)
	scenery.owner = root
