class_name StatBar
extends Control
## 自绘状态条（血条 / 蓝条 / 经验条）。
##
## 比 ProgressBar 多这几样东西，所以看起来不那么"朴素"：
##   1. 圆头跑道：深色凹槽 + 外描边，填充满的时候两头是圆的；
##   2. 玻璃高光：填充上半部一层白色高光、下半部压暗，有立体感；
##   3. 掉血残影：数值下降时留一条浅色"残影"慢慢缩回去，一眼看出掉了多少；
##   4. 亮头：填充最右侧一根小白条，像液面；
##   5. 低血预警：低于阈值时描边呼吸式闪烁（warn_ratio）。
##
## 用法：bar.setup(颜色, 高度) 之后每帧 set_value()，平滑在内部做。

## 数值跟随速度与残影回落速度
const FOLLOW_SPEED := 16.0
const GHOST_SPEED := 3.2

var fill_color := Palette.HP_OK
var track_color := Color("1c2334")
var border_color := Color("0d1119")
## 低于这个比例开始闪烁预警（负数表示不闪）
var warn_ratio := -1.0
## 两端金属端帽：加过一版金色菱形，战斗时看着像在血条外面镶了金饰，
## 用户反馈"属性部分要简洁"。默认关掉，需要时再单独打开。
var cap_color := Palette.GOLD
var show_caps := false
## 填充槽里每 25% 画一根刻度线。同样默认关掉，保持最朴素的色块。
var show_ticks := false

var _max_value := 1.0
var _value := 0.0
var _shown := 0.0
var _ghost := 0.0
var _radius := 8.0
var _started := false

var _track: StyleBoxFlat
var _border: StyleBoxFlat
var _fill: StyleBoxFlat
var _ghost_style: StyleBoxFlat
var _gloss: StyleBoxFlat
var _shade: StyleBoxFlat


func setup(color: Color, height := 20.0, radius := -1.0) -> StatBar:
	fill_color = color
	custom_minimum_size.y = height
	_radius = radius if radius >= 0.0 else height * 0.5
	_rebuild_styles()
	return self


func set_max_value(amount: float) -> void:
	_max_value = maxf(0.0001, amount)
	queue_redraw()


func set_value(amount: float, instant := false) -> void:
	_value = clampf(amount, 0.0, _max_value)
	if instant or not _started:
		_shown = _value
		_ghost = _value
		_started = true
	queue_redraw()


func _process(delta: float) -> void:
	var changed := false
	if not is_equal_approx(_shown, _value):
		_shown = lerpf(_shown, _value, 1.0 - exp(-FOLLOW_SPEED * delta))
		if absf(_shown - _value) < 0.01:
			_shown = _value
		changed = true
	if _ghost > _shown:
		_ghost = lerpf(_ghost, _shown, 1.0 - exp(-GHOST_SPEED * delta))
		if _ghost - _shown < 0.01:
			_ghost = _shown
		changed = true
	elif _ghost < _shown:
		_ghost = _shown
		changed = true
	if warn_ratio >= 0.0:
		changed = true
	if changed:
		queue_redraw()


func _rebuild_styles() -> void:
	_track = _box(track_color, _radius, border_color, 2.0)
	_border = _box(Color(0, 0, 0, 0), _radius, border_color, 2.0)
	_fill = _box(fill_color, 0.0 if _radius == 0 else maxf(2.0, _radius - 3.0), fill_color.darkened(0.28), 1.0)
	# 残影用暖白色：像"刚掉的血还留着痕迹"
	_ghost_style = _box(Color(1.0, 0.93, 0.86, 0.55), 0.0 if _radius == 0 else maxf(2.0, _radius - 3.0), Color(0, 0, 0, 0), 0.0)
	_gloss = _box(Color(1.0, 1.0, 1.0, 0.28), 0.0 if _radius == 0 else maxf(1.0, _radius - 5.0), Color(0, 0, 0, 0), 0.0)
	_shade = _box(Color(0.0, 0.0, 0.0, 0.16), 0.0 if _radius == 0 else maxf(1.0, _radius - 5.0), Color(0, 0, 0, 0), 0.0)
	queue_redraw()


func _box(bg: Color, radius: float, border: Color, border_width: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(int(border_width))
	style.set_corner_radius_all(int(maxf(0.0, radius)))
	style.corner_detail = 6
	return style


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < 6.0 or rect.size.y < 6.0:
		return
	draw_style_box(_track, rect)
	var inner := rect.grow(-3.0)
	if inner.size.x <= 0.0:
		return
	var top := maxf(0.0001, _max_value)
	var ratio := clampf(_shown / top, 0.0, 1.0)
	var ghost_ratio := clampf(_ghost / top, 0.0, 1.0)
	var min_w := 0.0 if _radius == 0 else inner.size.y

	if ghost_ratio > ratio + 0.002:
		var g := inner
		g.size.x = maxf(min_w, floorf(inner.size.x * ghost_ratio))
		draw_style_box(_ghost_style, g)

	if ratio > 0.0 and (_radius != 0 or floorf(inner.size.x * ratio) >= 1):
		var f := inner
		f.size.x = maxf(min_w, floorf(inner.size.x * ratio))
		_fill.bg_color = fill_color
		_fill.border_color = fill_color.darkened(0.30)
		draw_style_box(_fill, f)
		if _radius == 0:
			if f.size.x >= 3 and f.size.y >= 3:
				draw_rect(Rect2(f.position + Vector2.ONE, Vector2(f.size.x - 2, 1)), Color(1, 1, 1, 0.28))
				draw_rect(Rect2(f.position + Vector2(1, f.size.y - 2), Vector2(f.size.x - 2, 1)), Color(0, 0, 0, 0.16))
		else:
			var gloss := f
			gloss.position += Vector2(1.0, 1.0)
			gloss.size = Vector2(maxf(2.0, f.size.x - 2.0), maxf(2.0, f.size.y * 0.42))
			draw_style_box(_gloss, gloss)
			# 下半部压暗一条，填充就有"厚度"
			var shade := Rect2(
				f.position + Vector2(1.5, f.size.y * 0.62),
				Vector2(maxf(2.0, f.size.x - 3.0), maxf(2.0, f.size.y * 0.30))
			)
			draw_style_box(_shade, shade)
			var cap_w := maxf(2.0, f.size.y * 0.16)
			var cap := Rect2(
				f.position + Vector2(f.size.x - cap_w - 1.0, 2.0),
				Vector2(cap_w, maxf(2.0, f.size.y - 4.0))
			)
			draw_rect(cap, Color(1.0, 1.0, 1.0, 0.42), true)

	# 量程刻度：画在填充之上、用暗色，读起来像"刻在槽里的线"
	if show_ticks:
		for i in range(1, 4):
			var tx := inner.position.x + inner.size.x * (float(i) / 4.0)
			draw_line(
				Vector2(tx, inner.position.y + 1.5),
				Vector2(tx, inner.position.y + inner.size.y - 1.5),
				Color(0.0, 0.0, 0.0, 0.26), 1.0
			)

	if show_caps:
		_end_cap(rect, true)
		_end_cap(rect, false)

	if warn_ratio >= 0.0 and ratio <= warn_ratio:
		var pulse := 0.45 + 0.55 * absf(sin(float(Time.get_ticks_msec()) * 0.005))
		_border.border_color = Color(1.0, 0.36, 0.40, pulse)
	elif _border.border_color != border_color:
		_border.border_color = border_color
	draw_style_box(_border, rect)


func _end_cap(rect: Rect2, left: bool) -> void:
	## 左右各一颗菱形金属帽：把色块"装"进一个仪表壳里，比纯圆角矩形精致
	var mid_y := rect.position.y + rect.size.y * 0.5
	var cx := rect.position.x + 1.0 if left else rect.position.x + rect.size.x - 1.0
	var rx := maxf(3.0, rect.size.y * 0.30)
	var ry := maxf(3.0, rect.size.y * 0.42)
	var pts := PackedVector2Array([
		Vector2(cx, mid_y - ry), Vector2(cx + rx, mid_y),
		Vector2(cx, mid_y + ry), Vector2(cx - rx, mid_y),
	])
	# 深色底衬 + 亮色主体 + 中心高光，三层就有金属感
	draw_colored_polygon(pts, Color(0.06, 0.05, 0.03, 0.9))
	var inner_pts := PackedVector2Array([
		Vector2(cx, mid_y - ry + 2.0), Vector2(cx + rx - 2.0, mid_y),
		Vector2(cx, mid_y + ry - 2.0), Vector2(cx - rx + 2.0, mid_y),
	])
	draw_colored_polygon(inner_pts, cap_color.darkened(0.12))
	var shine := PackedVector2Array([
		Vector2(cx, mid_y - ry + 4.0), Vector2(cx + rx * 0.45, mid_y - 1.0),
		Vector2(cx, mid_y + 1.0), Vector2(cx - rx * 0.45, mid_y - 1.0),
	])
	draw_colored_polygon(shine, cap_color.lightened(0.42))
