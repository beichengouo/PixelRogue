extends SceneTree
## 把几套素材包的图集接进「地图编辑器的物块」里。
##
## 做法：把每个包的图集重排成干净的 36px 网格（去掉原图的 1px 间隔、放大到 36），
## 然后往 terrain_tileset.tres 里**追加 4 个来源**，命名成「<包名>·实心 / 单向 / 透明 / 伤害」，
## 和原有的四组行为完全一致（实心挡四面、单向只从上面踩、透明不挡、伤害扣血）。
##
## 需要的话可以重复运行：已经存在同名来源时会先删掉再重建，
## **不会碰你已经画好的地图**（地图数据在 level.tscn 里，这里只动瓦片集）。
##
## 注意：Kenney Pixel Platformer 就是现有「实心/单向/透明/伤害」四组用的那套图集，
## 已经在编辑器里了，所以这里不再重复添加。
##
## 用法：godot --headless --path . --script res://tools/build_pack_tilesets.gd

const TILESET_PATH := "res://assets/kenney/terrain_tileset.tres"
const OUT_DIR := "res://assets/tilesets/"
const TILE := 36

## 每个包：图集路径、原生瓦片边长、列数、行数、瓦片间距
const PACKS := [
	{
		"name": "地牢",
		"file": "dungeon",
		"src": "E:/素材/2D素材/1892ab477ce615ac/2D Pixel Dungeon Asset Pack/character and tileset/Dungeon_Tileset.png",
		"tile": 16, "cols": 10, "rows": 10, "pad": 0,
	},
	{
		"name": "微小地牢",
		"file": "tiny_dungeon",
		"src": "E:/素材/2D素材/kenney_tiny-dungeon/Tilemap/tilemap.png",
		"tile": 16, "cols": 12, "rows": 11, "pad": 1,
	},
	{
		"name": "沙漠",
		"file": "desert",
		"src": "E:/素材/2D素材/kenney_desert-shooter-pack_1.0/PNG/Tiles/Tilemap/tilemap.png",
		"tile": 16, "cols": 18, "rows": 13, "pad": 1,
	},
]

const GROUP_NAMES := ["实心", "单向", "透明", "伤害"]


var _added := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var tileset: TileSet = load(TILESET_PATH)
	if tileset == null:
		printerr("读不到瓦片集：%s" % TILESET_PATH)
		quit(1)
		return
	for pack: Dictionary in PACKS:
		_added += _add_pack(tileset, pack)
	if _added <= 0:
		# 一张来源都没加成（通常是图集刚生成、还没被 Godot 导入）：
		# 这时**不要**保存，免得把瓦片集写坏。跑一次 --import 再执行本脚本即可。
		print("没有新增来源（图集可能还没导入）。请先跑一次 --import 再执行本脚本。")
		quit(0)
		return
	var err := ResourceSaver.save(tileset, TILESET_PATH)
	print("已更新瓦片集：%s（%s），来源数 %d" % [TILESET_PATH, str(err), tileset.get_source_count()])
	quit(0)


func _add_pack(tileset: TileSet, pack: Dictionary) -> int:
	var pack_name := str(pack["name"])
	var sheet := Image.load_from_file(str(pack["src"]))
	if sheet == null:
		printerr("读不到图集：%s" % str(pack["src"]))
		return 0
	sheet.convert(Image.FORMAT_RGBA8)
	var tile: int = int(pack["tile"])
	var cols: int = int(pack["cols"])
	var rows: int = int(pack["rows"])
	var pad: int = int(pack["pad"])
	# 1) 重排成无间隔网格
	var grid := Image.create(cols * tile, rows * tile, false, Image.FORMAT_RGBA8)
	grid.fill(Color(0, 0, 0, 0))
	var used := 0
	for y in rows:
		for x in cols:
			var rect := Rect2i(x * (tile + pad), y * (tile + pad), tile, tile)
			if rect.end.x > sheet.get_width() or rect.end.y > sheet.get_height():
				continue
			var cell := sheet.get_region(rect)
			if _is_empty(cell):
				continue
			grid.blit_rect(cell, Rect2i(0, 0, tile, tile), Vector2i(x * tile, y * tile))
			used += 1
	# 2) 放大到游戏用的 36px
	var scale_factor := float(TILE) / float(tile)
	grid.resize(int(round(float(grid.get_width()) * scale_factor)),
		int(round(float(grid.get_height()) * scale_factor)), Image.INTERPOLATE_NEAREST)
	var out_path := OUT_DIR + "%s_36.png" % str(pack.get("file", pack_name))
	grid.save_png(ProjectSettings.globalize_path(out_path))
	var texture: Texture2D = load(out_path)
	if texture == null:
		printerr("图片没能导入：%s（先跑一次 --import）" % out_path)
		return 0
	# 3) 追加四个来源
	for group in 4:
		var source_name := "%s·%s" % [pack_name, GROUP_NAMES[group]]
		_remove_source_by_name(tileset, source_name)
		var source := TileSetAtlasSource.new()
		source.resource_name = source_name
		source.texture = texture
		source.texture_region_size = Vector2i(TILE, TILE)
		# 必须先挂进 tileset 再建瓦片：不然 TileData 里没有物理层，
		# 碰撞多边形就写不进去（这一步踩过一次坑）。
		var id := tileset.get_next_source_id()
		tileset.add_source(source, id)
		for y in rows:
			for x in cols:
				var rect := Rect2i(x * TILE, y * TILE, TILE, TILE)
				if rect.end.x > texture.get_width() or rect.end.y > texture.get_height():
					continue
				# 空瓦片不建：否则「实心」组里会出现看不见的墙
				if not _region_has_pixels(grid, rect):
					continue
				source.create_tile(Vector2i(x, y))
				if group == 2:
					continue      # 透明组不挡路
				var data := source.get_tile_data(Vector2i(x, y), 0)
				var layer: int = int([0, 1, 2, 2][group])
				var half := float(TILE) * 0.5
				var points := PackedVector2Array([
					Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
				])
				data.add_collision_polygon(layer)
				data.set_collision_polygon_points(layer, 0, points)
				if group == 1:
					# 单向：只从上面挡人（和原有「单向」组一致）
					data.set_collision_polygon_one_way(layer, 0, true)
					data.set_collision_polygon_one_way_margin(layer, 0, 4.0)
		print("  + %s（来源 id=%d，%d 格）" % [source_name, id, used])
		_added += 1
	return 1


func _remove_source_by_name(tileset: TileSet, source_name: String) -> void:
	for i in tileset.get_source_count():
		var id := tileset.get_source_id(i)
		var source := tileset.get_source(id)
		if source != null and source.resource_name == source_name:
			tileset.remove_source(id)
			return
			return


func _is_empty(img: Image) -> bool:
	return not _region_has_pixels(img, Rect2i(0, 0, img.get_width(), img.get_height()))


func _region_has_pixels(img: Image, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if img.get_pixel(x, y).a > 0.08:
				return true
	return false



