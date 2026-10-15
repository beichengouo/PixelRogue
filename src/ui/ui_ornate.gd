class_name UiOrnate
extends PanelContainer
## 带装饰的面板容器：在面板自己的样式**之上**再画三层装饰。
##
## 为什么做成子类、而不是往面板里塞几个装饰节点：
## PanelContainer 会把**所有**子节点强行塞进内容矩形（fit_child_in_rect），
## 装饰节点自己设的锚点会被覆盖 —— 四角花角会被拉成巨大的 L 形。
## 直接在 _draw() 里画就绕开了这个问题，而且装饰不吃鼠标事件、不占布局。
##
## 画的三层（专业 UI 里成本最低、观感最明显的三件事）：
##   1. 内层细金线 —— 和外框凑成"双线"，比单线精致得多；
##   2. 四角花角   —— L 形小装饰，把矩形框住，视线有落点；
##   3. 上下渐变带 —— 顶部压暗、底部微亮，面板立刻有厚度，不再像贴纸。

var accent := Palette.GOLD
var inset := 7.0
var corner_arm := 24.0
## 内容本身很挤的小面板可以关掉花角，只留内线
var show_corners := true
var show_bands := true
## 内层细线：自绘 StyleBoxFlat 面板要靠它凑"双线"；
## 但换成画好的 9 宫格边框素材（本身就有 5 层线）之后，
## 再叠一条内线会被看成"多出来的一条亮线瑕疵"，所以要能关掉。
var show_inner := true

var _inner: StyleBoxFlat


func setup(tint := Palette.GOLD, line_inset := 7.0, arm := 24.0) -> UiOrnate:
	accent = tint
	inset = line_inset
	corner_arm = arm
	_inner = StyleBoxFlat.new()
	_inner.bg_color = Color(0, 0, 0, 0)
	_inner.border_color = Color(accent.r, accent.g, accent.b, 0.40)
	_inner.set_border_width_all(1)
	_inner.set_corner_radius_all(8)
	_inner.corner_detail = 6
	queue_redraw()
	return self


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < inset * 4.0 or rect.size.y < inset * 4.0:
		return
	if show_bands:
		_gradient_band(rect, true)
		_gradient_band(rect, false)
	if show_inner and _inner != null:
		draw_style_box(_inner, Rect2(
			rect.position + Vector2(inset, inset),
			rect.size - Vector2(inset, inset) * 2.0
		))
	if show_corners:
		_corner(rect, true, true)
		_corner(rect, true, false)
		_corner(rect, false, true)
		_corner(rect, false, false)


func _gradient_band(rect: Rect2, top: bool) -> void:
	## draw_polygon 支持逐顶点颜色，于是不用任何美术素材就能画出竖直渐变
	var h := minf(rect.size.y * 0.22, 64.0)
	var y0 := rect.position.y if top else rect.position.y + rect.size.y
	var y1 := y0 + h if top else y0 - h
	## 用中性深色而不是偏棕的深色：棕色调叠在深底板上会整体泛"土黄"，
	## 画面自查时被读成"土黄色底 + 浅米黄字"，观感脏。
	var dark := Color(0.03, 0.035, 0.05, 0.22 if top else 0.10)
	var clear := Color(0.03, 0.035, 0.05, 0.0)
	var pts := PackedVector2Array([
		Vector2(rect.position.x, y0), Vector2(rect.position.x + rect.size.x, y0),
		Vector2(rect.position.x + rect.size.x, y1), Vector2(rect.position.x, y1),
	])
	var cols := PackedColorArray([dark, dark, clear, clear])
	draw_polygon(pts, cols)


func _corner(rect: Rect2, top: bool, left: bool) -> void:
	var o := inset + 2.0
	var arm := corner_arm
	var origin := Vector2(
		rect.position.x + (o if left else rect.size.x - o),
		rect.position.y + (o if top else rect.size.y - o)
	)
	var dx := 1.0 if left else -1.0
	var dy := 1.0 if top else -1.0
	var end_x := origin + Vector2(arm * dx, 0.0)
	var end_y := origin + Vector2(0.0, arm * dy)
	# 深色底衬先画粗一点，亮金压在上面 —— 压在任何底色上都看得清
	var shade := Color(0.05, 0.04, 0.03, 0.55)
	draw_line(origin, end_x, shade, 4.0, true)
	draw_line(origin, end_y, shade, 4.0, true)
	draw_line(origin, end_x, accent, 2.0, true)
	draw_line(origin, end_y, accent, 2.0, true)
	# 角尖点一颗小方块，收口更利落
	draw_rect(Rect2(origin - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), accent.lightened(0.25), true)
