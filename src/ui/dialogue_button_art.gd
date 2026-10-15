class_name DialogueButtonArt
extends RefCounted
## Generated lettering stays in the texture; option captions remain dynamic.
const DIR := "res://assets/ui_art/dialogue_star/"
static var _textures: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	if _textures.has(kind): return _textures[kind]
	var regions := {"continue": Rect2(30, 143, 2067, 421), "show_full": Rect2(6, 150, 2112, 400), "choice_blank": Rect2(2, 185, 2168, 322)}
	var source := load(DIR + kind + "_v1.png") as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	var ratio := float(source.get_width()) / 2172.0
	atlas.region = Rect2(regions[kind].position * ratio, regions[kind].size * ratio)
	atlas.filter_clip = true
	_textures[kind] = atlas
	return atlas

static func action_button() -> Button:
	var button := PixelUi.button("继续", 16, 188, 44)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	var art := TextureRect.new()
	art.name = "PaintedCaption"
	art.texture = texture("continue")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.material = PixelUi.art_material()
	button.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var update := func() -> void:
		var active := button.is_hovered() if UIFlow.pointer_active else button.has_focus()
		art.modulate = Color("ffe7ad") if button.button_pressed else (Color.WHITE if active else Color("d7e0ef"))
	for event in [button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited, button.button_down, button.button_up]: event.connect(update)
	UIFlow.navigation_mode_changed.connect(update)
	button.tree_exiting.connect(func() -> void:
		if UIFlow.navigation_mode_changed.is_connected(update): UIFlow.navigation_mode_changed.disconnect(update))
	button.ready.connect(update)
	return button

static func set_show_full(button: Button, full: bool) -> void:
	button.text = "显示全文" if full else "继续"
	button.tooltip_text = button.text
	(button.get_node("PaintedCaption") as TextureRect).texture = texture("show_full" if full else "continue")

static func choice_button(caption: String, font_size := 18, height := 52.0) -> Button:
	var button := PixelUi.button(caption, font_size, 0, height)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "disabled"]:
		var plate := StyleBoxTexture.new()
		plate.texture = texture("choice_blank")
		var ratio := plate.texture.get_width() / 2168.0
		for side in [SIDE_LEFT, SIDE_RIGHT]:
			plate.set_texture_margin(side, 220.0 * ratio)
			plate.set_content_margin(side, 48)
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			plate.set_texture_margin(side, 48.0 * ratio)
			plate.set_content_margin(side, 8 if height < 50 else 12)
		plate.modulate_color = {"normal": Color("d1d9e9"), "hover": Color("fff0cf"), "pressed": Color("b5cbe9"), "disabled": Color("78849a")}[state]
		button.add_theme_stylebox_override(state, plate)
	button.add_theme_color_override("font_color", Color("edf2fb"))
	button.add_theme_color_override("font_hover_color", Color("fff0cf"))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button
