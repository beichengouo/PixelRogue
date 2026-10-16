class_name PixelUi
extends RefCounted
## 统一像素组件，供已迁移的正式菜单与新旧对照样张使用。

const INK := Color("edf2e8")
const MUTED := Color("a7b6b4")
const GOLD := Color("edc881")
const NIGHT := Color("152c33")
const LINE := Color("567b85")
static var _theme: Theme
static var _art_shader: Shader

static func art_material() -> ShaderMaterial:
	if _art_shader == null:
		_art_shader = Shader.new()
		_art_shader.code = "shader_type canvas_item; void fragment(){ vec4 tex=texture(TEXTURE,UV); COLOR.rgb=tex.rgb*COLOR.rgb; COLOR.a*=tex.a*smoothstep(0.52,0.82,tex.a); }"
	var result := ShaderMaterial.new()
	result.shader = _art_shader
	return result

static func art_graphic(kind: String, extent: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	var texture: Texture2D = load("res://assets/ui_art/main_menu_star/" + ("title.png" if kind == "title" else "chapter.png"))
	if kind == "chapter":
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(164, 224, 1848, 251)
		rect.texture = atlas
	else: rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = extent
	rect.material = art_material()
	return rect

static func art_menu_button(text: String, kind: String, extent: Vector2) -> Button:
	var node := Button.new()
	node.add_theme_font_override("font", GameFonts.get_font("button"))
	node.text = text
	node.size = extent
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		node.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		node.add_theme_color_override(state, Color.TRANSPARENT)
	var regions := {
		"start": Rect2(223,66,570,169), "continue": Rect2(252,274,537,166),
		"codex": Rect2(250,485,543,169), "record": Rect2(260,707,547,179),
		"settings": Rect2(375,921,284,165), "gallery": Rect2(238,1121,548,169),
		"quit": Rect2(252,1329,541,163)}
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/ui_art/main_menu_star/menu-atlas.png")
	atlas.region = regions[kind]
	var glyph := TextureRect.new()
	glyph.texture = atlas
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var height := 38.0 if kind == "start" else 32.0
	glyph.size = Vector2(height * atlas.region.size.x / atlas.region.size.y, height)
	glyph.position = (extent - glyph.size) * 0.5
	glyph.material = art_material()
	node.add_child(glyph)
	var sparks := MenuLetterSpark.new()
	sparks.size = extent
	sparks.letter_width = glyph.size.x
	sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(sparks)
	var update := func() -> void:
		var active := node.is_hovered() if UIFlow.pointer_active else node.has_focus()
		var tint := Color.WHITE if active else Color("e4e7ef")
		if node.disabled: tint = Color("8c99a8")
		elif node.button_pressed: tint = Color("ffeac2")
		var old: Tween = glyph.get_meta("art_tween") if glyph.has_meta("art_tween") else null
		if old != null and old.is_valid(): old.kill()
		var tween := glyph.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(glyph, "modulate", tint, 0.10)
		glyph.set_meta("art_tween", tween)
	for event in [node.mouse_entered, node.mouse_exited, node.focus_entered, node.focus_exited, node.button_down, node.button_up]: event.connect(update)
	UIFlow.navigation_mode_changed.connect(update)
	node.tree_exiting.connect(func() -> void:
		if UIFlow.navigation_mode_changed.is_connected(update): UIFlow.navigation_mode_changed.disconnect(update))
	node.button_down.connect(func() -> void: if not node.disabled: sparks.fire())
	node.pressed.connect(func() -> void: if not node.disabled: sparks.fire())
	node.ready.connect(update)
	ComicMotion.bind_button(node)
	return node

class MenuLetterSpark extends Control:
	var letter_width := 120.0
	var age := 1.0
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(false)
	func fire() -> void:
		if ComicMotion.reduced(): return
		# 一次爆发期间重复信号不会重置效果。
		if age < 0.28: return
		age = 0.0
		set_process(true)
		queue_redraw()
	func _process(delta: float) -> void:
		age += delta
		queue_redraw()
		if age >= 0.28: set_process(false)
	func _draw() -> void:
		if age >= 0.28: return
		var progress := clampf(age / 0.28, 0.0, 1.0)
		var center := size * 0.5
		for index in 10:
			var angle := TAU * float(index) / 10.0
			var position := center + Vector2(cos(angle) * (letter_width * 0.52 + progress * 20), sin(angle) * (12 + progress * 15))
			var radius := (2.5 if index % 2 == 0 else 1.5) * (1.0 - progress)
			var ink := Color(1.0, 0.88, 0.60, (1.0 - progress) * 0.95)
			draw_line(position-Vector2(radius,0), position+Vector2(radius,0), ink, 1.0, true)
			draw_line(position-Vector2(0,radius*1.6), position+Vector2(0,radius*1.6), ink, 1.0, true)


static func plate(index: int, button_shape := false) -> StyleBoxTexture:
	var texture := PixelSampleArt.cell(PixelSampleArt.UI, index)
	var full_size := texture.region.size
	var rectangles: Array = PixelSampleArt.metadata().get("ui_sample_v1.png", {}).get("rects", [])
	if index < rectangles.size():
		var rect: Array = rectangles[index]
		texture.region.position += Vector2(float(rect[0]), float(rect[1]))
		texture.region.size = Vector2(float(rect[2]), float(rect[3]))
	else:
		texture.region.position += full_size * Vector2(0.0625, 0.375 if button_shape else 0.0625)
		texture.region.size = full_size * Vector2(0.875, 0.25 if button_shape else 0.875)
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, (60 if side in [SIDE_LEFT, SIDE_RIGHT] else 16) if button_shape else 64)
		style.set_content_margin(side, (36 if side in [SIDE_LEFT, SIDE_RIGHT] else 10) if button_shape else 32)
	return style

static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = StarUi.font()
	_theme.default_font_size = 18
	_theme.set_color("font_color", "Label", INK)
	_theme.set_color("font_color", "CheckButton", INK)
	_theme.set_color("font_hover_color", "CheckButton", GOLD)
	for state in ["normal", "hover", "pressed", "disabled"]:
		_theme.set_stylebox(state, "CheckButton", StarUi.style(Color.TRANSPARENT if state == "normal" else NIGHT, GOLD if state == "hover" else Color.TRANSPARENT, 0, 6, 1))
	for state in ["normal", "hover", "pressed", "disabled"]:
		_theme.set_stylebox(state, "Button", plate(["normal", "hover", "pressed", "disabled"].find(state), true))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_theme.set_color(state, "Button", INK)
	_theme.set_color("font_disabled_color", "Button", MUTED)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	_theme.set_stylebox("focus", "Button", focus)
	_theme.set_stylebox("focus", "CheckButton", focus)
	_theme.set_stylebox("panel", "TooltipPanel", UiFactory.panel_style(Color(0.045,0.11,0.14,0.88),Color(0.34,0.49,0.52,0.55),5,1,12))
	_theme.set_font_size("font_size","TooltipLabel",17)
	_theme.set_color("font_color", "TooltipLabel", INK)
	for control in ["HSlider", "VSlider"]:
		for part in ["slider", "grabber_area", "grabber_area_highlight"]:
			var track := StarUi.style(NIGHT if part == "slider" else GOLD, MUTED if part == "slider" else GOLD, 0, 0, 1)
			track.set_content_margin(SIDE_TOP if control == "HSlider" else SIDE_LEFT, 3)
			track.set_content_margin(SIDE_BOTTOM if control == "HSlider" else SIDE_RIGHT, 3)
			_theme.set_stylebox(part, control, track)
		_theme.set_stylebox("focus", control, focus)
	for control in ["VScrollBar", "HScrollBar"]:
		_theme.set_stylebox("scroll", control, StarUi.style(NIGHT, MUTED, 0, 4))
		_theme.set_stylebox("grabber", control, StarUi.style(GOLD, GOLD, 0, 4))
		_theme.set_stylebox("grabber_highlight", control, StarUi.style(INK, GOLD, 0, 4))
	return _theme

static func button(text: String, size := 18, width := 560.0, height := 60.0) -> Button:
	var node := Button.new()
	node.add_theme_font_override("font", GameFonts.get_font("button"))
	node.text = text
	node.theme = theme()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.custom_minimum_size = Vector2(width, maxf(height,58.0) if MobileControls.enabled() else height)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width <= 0 else Control.SIZE_SHRINK_CENTER
	node.add_theme_font_size_override("font_size", size)
	ComicMotion.bind_button(node)
	return node

static func panel() -> PanelContainer:
	var node := PanelContainer.new()
	node.theme = theme()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.add_theme_stylebox_override("panel", plate(4))
	ComicMotion.accent(node)
	return node

static func label(text: String, size := 18, color := INK) -> Label:
	return StarUi.label(text, size, color)

static func title(text: String, size := 30, color := INK) -> Label:
	return StarUi.title(text, size, color)

static func inset_panel(margin := 10.0) -> PanelContainer:
	var node := PanelContainer.new()
	node.theme = theme()
	node.add_theme_stylebox_override("panel", StarUi.style(NIGHT, Color("567b85"), 0, margin, 2))
	return node

## 紧凑控件使用方角内框，避免装饰按钮的九宫格挤占内容。
static func style(fill: Color, border: Color, _radius := 0, margin := 8.0, thickness := 2) -> StyleBoxFlat:
	return StarUi.style(fill, border, 0, margin, thickness)

static func compact_button(text: String, size := 18) -> Button:
	var node := button(text, size, 0, 40)
	node.size_flags_horizontal = Control.SIZE_FILL
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := NIGHT.lightened(0.10) if state == "hover" else NIGHT
		var border := GOLD if state in ["hover", "pressed"] else LINE
		node.add_theme_stylebox_override(state, style(fill, border, 0, 8))
	return node

static func primary(text: String, size := 18) -> Button:
	return button(text, size, 0, 52)

static func slot_button(tint := LINE, size := 48.0) -> Button:
	if MobileControls.enabled():size=maxf(64,size)
	var node := compact_button("", 16)
	node.custom_minimum_size = Vector2(size, size)
	node.add_theme_constant_override("icon_max_width", int(size - 16))
	node.add_theme_stylebox_override("normal", style(NIGHT, tint, 0, 8))
	return node

static func tab_button(text: String, active: bool, size := 17) -> Button:
	var node := compact_button(text, size)
	apply_tab_style(node, active)
	if text in ["装备","遗物"]:RewardCategoryWordmark.decorate_button(node,text,30)
	elif text=="装备与遗物":RewardCategoryWordmark.decorate_pair(node)
	return node

static func apply_tab_style(node: Button, active: bool) -> void:
	node.add_theme_stylebox_override("normal", style(NIGHT.lightened(0.08) if active else NIGHT, GOLD if active else LINE, 0, 8))
	node.add_theme_color_override("font_color", GOLD if active else MUTED)

static func chip(text: String, color := GOLD, size := 14) -> PanelContainer:
	var node := inset_panel(4)
	node.add_theme_stylebox_override("panel", style(NIGHT, color.darkened(0.35), 0, 4, 1))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var caption := label(text, size, color)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(caption)
	return node

static func hud_slot(size: float, key: String, caption: String, ultimate := false) -> Control:
	var column := UiFactory.vbox(4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Control.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(size, size)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := Panel.new()
	panel.name = "Plate"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style(Color("111f2d"), GOLD if ultimate else LINE, 0, 0, 2))
	box.add_child(panel)
	column.add_child(box)
	var key_label := label(key, 15, GOLD if ultimate else INK)
	key_label.name = "Key"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(key_label)
	column.tooltip_text = caption
	return column

static func focus_button(root: Control, token := "") -> void:
	var first: Button
	for candidate in root.find_children("*", "Button", true, false):
		if candidate.disabled or not candidate.is_visible_in_tree():
			continue
		if first == null: first = candidate
		if token != "" and str(candidate.get_meta("focus_token", "")) == token:
			candidate.grab_focus()
			return
	if first != null: first.grab_focus()


static func list_button(caption: String, height := 56) -> Button:
	var node := button(caption, 19, 0, height)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var bg := Color("24364b") if state == "normal" else Color("314a60") if state == "hover" else Color("1c2b3c") if state == "pressed" else Color("1a2636")
		var border := GOLD if state == "hover" else Color("759caf") if state == "pressed" else Color("455f78")
		node.add_theme_stylebox_override(state, style(bg, border, 4, 12, 1))
	node.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, GOLD, 4, 12, 2))
	return node
