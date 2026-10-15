class_name StarUi
extends RefCounted
## 第一阶段的星辉界面组件，独立于旧界面，便于逐页迁移。

const INK := Color("27344b")
const MUTED := Color("65738a")
const GOLD := Color("b28a40")
const PAPER := Color("f5f4ef")
const LINE := Color("d5dce4")
const NIGHT := Color("172235")
static var _font: Font
static var _theme: Theme

static func font() -> Font:
	if _font == null: _font = GameFonts.get_font()
	return _font

static func style(bg: Color, border := LINE, radius := 8, margin := 12.0, width := 1) -> StyleBoxFlat:
	return UiFactory.panel_style(bg, border, radius, width, margin)

static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = font()
	_theme.default_font_size = 17
	for state in ["normal", "hover", "pressed", "disabled"]:
		var bg := Color("ffffff")
		var border := LINE
		if state == "hover":
			bg = Color("eef3fa")
			border = GOLD
		elif state == "pressed":
			bg = Color("e2eaf5")
		elif state == "disabled":
			bg = Color("e9edf1")
		_theme.set_stylebox(state, "Button", style(bg, border, 7, 10.0))
	_theme.set_stylebox("focus", "Button", style(Color.TRANSPARENT, GOLD, 7, 0.0, 2))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_theme.set_color(state, "Button", INK)
	_theme.set_color("font_disabled_color", "Button", MUTED)
	_theme.set_stylebox("panel", "TooltipPanel", style(Color(0.09,0.13,0.21,0.88),Color(0.33,0.40,0.51,0.55),5,12.0))
	_theme.set_color("font_color", "TooltipLabel", Color("eef3fa"))
	return _theme

static func label(text: String, size := 17, color := INK) -> Label:
	var node := UiFactory.label(text, size, color)
	node.add_theme_font_override("font", font())
	return node

static func title(text: String, size := 28, color := INK) -> Label:
	var node := UiFactory.label(text, size, color)
	node.add_theme_font_override("font", GameFonts.get_font("title"))
	return node

static func button(text: String, size := 17) -> Button:
	var node := Button.new()
	node.add_theme_font_override("font", GameFonts.get_font("button"))
	node.theme = theme()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.custom_minimum_size.y = 58.0 if MobileControls.enabled() else 40.0
	ComicMotion.bind_button(node)
	return node

static func slot_button(tint := LINE, size := 48.0) -> Button:
	var node := button("")
	node.custom_minimum_size = Vector2(size, size)
	node.add_theme_constant_override("icon_max_width", int(size - 16.0))
	node.add_theme_stylebox_override("normal", style(Color("e8edf3"), tint, 7, 8.0))
	node.add_theme_stylebox_override("disabled", style(Color("edf0f4"), LINE, 7, 8.0))
	return node

static func tab_button(text: String, active: bool, size := 17) -> Button:
	var node := button(text, size)
	apply_tab_style(node, active)
	return node

static func apply_tab_style(node: Button, active: bool) -> void:
	node.add_theme_stylebox_override("normal", style(NIGHT if active else Color.TRANSPARENT,
		GOLD if active else Color.TRANSPARENT, 7, 10.0))
	node.add_theme_stylebox_override("hover", style(NIGHT if active else Color("e7ecf3"), GOLD, 7, 10.0))
	node.add_theme_stylebox_override("pressed", style(NIGHT, GOLD, 7, 10.0))
	node.add_theme_color_override("font_color", Color("fff6de") if active else MUTED)
	node.add_theme_color_override("font_hover_color", Color("fff6de") if active else INK)
	node.add_theme_color_override("font_pressed_color", Color("fff6de"))
	node.add_theme_color_override("font_focus_color", Color("fff6de") if active else INK)

static func panel(bg := PAPER, margin := 18.0) -> PanelContainer:
	var node := PanelContainer.new()
	node.theme = theme()
	node.add_theme_stylebox_override("panel", style(bg, LINE, 12, margin))
	return node

static func hud_slot(size: float, key: String, caption: String) -> Control:
	var column := UiFactory.vbox(3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Control.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(size, size)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := Panel.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", style(Color(0.065, 0.10, 0.17, 0.88), Color("64718a"), 8, 0.0))
	box.add_child(plate)
	column.add_child(box)
	var key_label := label(key, 15, Color("eaf0fc"))
	key_label.name = "Key"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_color_override("font_outline_color", Color("0b1322"))
	key_label.add_theme_constant_override("outline_size", 2)
	column.add_child(key_label)
	column.tooltip_text = caption
	return column


static func apply_painted_button(node: Button) -> void:
	var path := "res://assets/ui/painted/button_plate.png"
	if not ResourceLoader.exists(path):
		apply_tab_style(node, true)
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = Rect2(0, 152, 2172, 410)
	atlas.filter_clip = true
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxTexture.new()
		box.texture = atlas
		box.content_margin_left = 28
		box.content_margin_right = 28
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		box.modulate_color = Color.WHITE
		if state == "hover":
			box.modulate_color = Color(1.16, 1.16, 1.16)
		elif state == "pressed":
			box.modulate_color = Color(0.8, 0.8, 0.9)
		elif state == "disabled":
			box.modulate_color = Color(0.58, 0.62, 0.7, 0.7)
		node.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, Color("fff6de"))
	node.add_theme_color_override("font_disabled_color", Color("b4bac6"))
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, Color("f4d492"), 7, 0, 2))

static func primary(text: String, size := 18) -> Button:
	var node := button(text, size)
	apply_painted_button(node)
	return node

static func frame(root: Control, design := Vector2(1180, 640)) -> Control:
	var canvas := Control.new()
	canvas.size = design
	root.add_child(canvas)
	var fit := func() -> void:
		var viewport := root.size
		var area:=MobileControls.safe_rect() if MobileControls.enabled() and root.is_inside_tree() else Rect2(Vector2.ZERO,viewport)
		viewport=area.size
		var factor := minf(viewport.x / (design.x + 48), viewport.y / (design.y + 48))
		factor = clampf(factor, 0.1, 1.0)
		canvas.scale = Vector2.ONE * factor
		canvas.position = area.position+(viewport - design * factor) * 0.5
	root.resized.connect(fit)
	fit.call()
	return canvas

static func reveal(node: Control) -> Tween:
	return ComicMotion.reveal(node)
