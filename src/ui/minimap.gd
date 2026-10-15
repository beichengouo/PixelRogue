class_name Minimap
extends Control
## 右上角小地图：地形缩略图 + 怪物 / 宝箱 / 商人 / 玩家自己的位置。
##
## 地形不每帧重画：先把「一格 = 一像素」的缩略图烘焙进一张 ImageTexture，
## 每帧只画这张图 + 几个标记点，开销可以忽略。
## 视野以玩家为中心，并且夹住不让画面滑出地图边界。

const SIZE := Vector2(252.0, 130.0)
const WORLD_SCALE := 0.082        # 世界像素 -> 小地图像素
const MARGIN := 16.0

const BG := Color(0.05, 0.07, 0.11, 0.82)
const BORDER := Color("3a4560")
const TERRAIN := Color("46536f")
const TERRAIN_TOP := Color("7183ab")
const ENEMY := Color("e0576b")
## 雇佣单位（酒馆帮手）
const ALLY := Color("7ad86f")
const CHEST := Color("ffcc4d")
const SHOP := Color("ffd166")
const PLAYER := Color("7fe3a0")

var level: Level
var player: Node2D

var _terrain: ImageTexture
var _cells_origin := Vector2i.ZERO
var _cells_size := Vector2i.ZERO
var _accum := 0.0


func bind(level_node: Level, player_node: Node2D) -> void:
	level = level_node
	player = player_node
	_build_terrain()
	queue_redraw()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -SIZE.x - MARGIN
	offset_top = MARGIN
	offset_right = -MARGIN
	offset_bottom = MARGIN + SIZE.y
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 5


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	# 20fps 重画就够了，省一点性能
	_accum += delta
	if _accum >= 0.05:
		_accum = 0.0
		queue_redraw()


func _build_terrain() -> void:
	if level == null:
		return
	var rect := level.playable_cell_rect()
	_cells_origin = rect.position
	_cells_size = rect.size
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var img := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for cell: Vector2i in level.solid:
		var local := cell - _cells_origin
		if local.x < 0 or local.y < 0 or local.x >= rect.size.x or local.y >= rect.size.y:
			continue
		# 头顶没东西的是地表，用亮色，地形轮廓一眼能看出来
		var is_top := not level.solid.has(cell + Vector2i(0, -1))
		img.set_pixel(local.x, local.y, TERRAIN_TOP if is_top else TERRAIN)
	_terrain = ImageTexture.create_from_image(img)


func _to_map(world: Vector2, center: Vector2) -> Vector2:
	return (world - center) * WORLD_SCALE + SIZE * 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BG, true)
	draw_rect(Rect2(Vector2.ZERO, SIZE), BORDER, false, 2.0)
	if _terrain == null or player == null or not is_instance_valid(player):
		return

	var center := _clamped_center()
	_draw_terrain(center)
	_draw_markers(center)
	_draw_player(center)


func _clamped_center() -> Vector2:
	## 玩家靠近地图边缘时把视野往内推，别让小地图露出一大片空白
	var center := player.global_position
	if level == null:
		return center
	var bounds := level.bounds()
	var half := SIZE * 0.5 / WORLD_SCALE
	if bounds.size.x > half.x * 2.0:
		center.x = clampf(center.x, bounds.position.x + half.x, bounds.end.x - half.x)
	else:
		center.x = bounds.get_center().x
	if bounds.size.y > half.y * 2.0:
		center.y = clampf(center.y, bounds.position.y + half.y, bounds.end.y - half.y)
	else:
		center.y = bounds.get_center().y
	return center


func _draw_terrain(center: Vector2) -> void:
	var cell_px := float(Level.TILE) * WORLD_SCALE
	var top_left := _to_map(
		level.tile_origin() + Vector2(_cells_origin) * float(Level.TILE), center
	)
	var full := Rect2(top_left, Vector2(_cells_size) * cell_px)
	var clipped := Rect2(Vector2(2.0, 2.0), SIZE - Vector2(4.0, 4.0))
	var visible := full.intersection(clipped)
	if visible.size.x <= 0.0 or visible.size.y <= 0.0:
		return
	var src := Rect2((visible.position - full.position) / cell_px, visible.size / cell_px)
	draw_texture_rect_region(_terrain, visible, src)


func _draw_markers(center: Vector2) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		_dot(_to_map(enemy.global_position, center), 2.6, ENEMY)
	for node in get_tree().get_nodes_in_group("chests"):
		var chest := node as Node2D
		if chest == null or not is_instance_valid(chest):
			continue
		_dot(_to_map(chest.global_position, center), 3.4, CHEST)
	# 酒馆雇来的帮手：绿色小点，和玩家/怪区分开
	for node in get_tree().get_nodes_in_group("allies"):
		var ally := node as Node2D
		if ally == null or not is_instance_valid(ally):
			continue
		_dot(_to_map(ally.global_position, center), 2.4, ALLY)
	var runtime: Variant = GameState.runtime_node
	if is_instance_valid(runtime) and runtime.extraction.state == ExtractionDirector.WAITING:
		var at := _to_map(runtime.extraction.anchor, center)
		if Rect2(Vector2.ZERO,SIZE).has_point(at):
			draw_arc(at,4.0,0,TAU,12,Color("ffd166"),1.5)
	if level != null:
		_dot(_to_map(level.shop_spawn, center), 3.0, SHOP)
		_dot(_to_map(level.tavern_spawn, center), 3.0, Color("d9a5c7"))


func _draw_player(center: Vector2) -> void:
	var p := _to_map(player.global_position, center)
	if not Rect2(Vector2.ZERO, SIZE).grow(-1.0).has_point(p):
		return
	draw_circle(p, 3.8, Color(0.0, 0.0, 0.0, 0.85))
	draw_circle(p, 2.6, PLAYER)


func _dot(at: Vector2, radius: float, color: Color) -> void:
	if not Rect2(Vector2.ZERO, SIZE).grow(-1.0).has_point(at):
		return
	draw_rect(Rect2(at - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), color, true)

