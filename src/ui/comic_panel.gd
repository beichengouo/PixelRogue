class_name ComicPanel
extends Control
## 素材图集只是分镜来源，页面用不等大的四边形、斜框与叠压自由构图。
var _art: Polygon2D
var _index := 0
var _crop := Rect2(0, 0, 1, 1)

func setup(index: int, dimensions: Vector2, slant := 0.0, crop := Rect2(0, 0, 1, 1)) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_crop = crop
	size = dimensions
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var points := PackedVector2Array([Vector2(slant, 0), Vector2(size.x, 0), Vector2(size.x - slant, size.y), Vector2(0, size.y)])
	var shadow := Polygon2D.new()
	shadow.polygon = points
	shadow.color = Color(0.0, 0.0, 0.0, 0.5)
	shadow.position = Vector2(8, 9)
	add_child(shadow)
	var border := Polygon2D.new()
	border.polygon = points
	border.color = Color("fff6e2")
	add_child(border)
	_art = Polygon2D.new()
	_art.polygon = points
	_art.scale = Vector2((size.x - 10) / size.x, (size.y - 10) / size.y)
	_art.position = Vector2(5, 5)
	_art.texture = load("res://assets/art_phase4/comic_atlas_v1.png")
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_art)
	set_panel(index)

func set_panel(index: int) -> void:
	_index = index
	var texture := _art.texture
	var cell := Vector2(texture.get_width() / 2.0, texture.get_height() / 2.0)
	var origin := Vector2(index % 2, index / 2) * cell
	# 等比覆盖：竖框只裁画面两侧，不能把横幅整张压扁；留出素材分格的白边。
	var source_size := cell * _crop.size
	var source_origin := origin + cell * _crop.position
	var display_ratio := size.x / size.y
	if source_size.x / source_size.y > display_ratio:
		var width := source_size.y * display_ratio
		source_origin.x += (source_size.x - width) * 0.5
		source_size.x = width
	else:
		var height := source_size.x / display_ratio
		source_origin.y += (source_size.y - height) * 0.5
		source_size.y = height
	var local_bounds := Rect2(_art.polygon[0], Vector2.ZERO)
	for point in _art.polygon:
		local_bounds = local_bounds.expand(point)
	var uv := PackedVector2Array()
	for point in _art.polygon:
		var fraction := (point - local_bounds.position) / local_bounds.size
		uv.append(source_origin + Vector2(5, 5) + fraction * (source_size - Vector2(10, 10)))
	_art.uv = uv
