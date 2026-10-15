class_name CharacterArtbook
extends Control
signal picked(id: StringName)
signal back_requested()
signal start_requested(id: StringName)

const PAGE := "res://assets/ui_art/characters/sylphiette_artbook.png"
const START_BUTTON_ART := "res://assets/ui_art/characters/adventure_bookmark_v1.png"
const CLOSE_BUTTON_ART := "res://assets/ui_art/characters/close_medallion_v1.png"
var selected: StringName = Characters.DEFAULT_ID
var _buttons: Array[Button] = []

func _ready() -> void:
	_build()

func _place(node: Control, rect: Rect2) -> void:
	add_child(node)
	node.position = rect.position
	node.size = rect.size

func _text(text: String, font_size: int, rect: Rect2, color := StarUi.INK) -> Label:
	var label := StarUi.label("", font_size, color)
	if font_size >= 30: label.add_theme_font_override("font", GameFonts.get_font("title"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = rect.size.x
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, rect)
	label.text = text
	label.set_deferred("size", rect.size)
	return label

func _drawn_button(text: String, path: String, font_size: int) -> Button:
	var button := StarUi.button(text, font_size)
	var texture: Texture2D = load(path)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(TexturePixels.image(texture).get_used_rect())
	for state in ["normal", "hover", "pressed", "disabled"]:
		var plate := StyleBoxTexture.new()
		plate.texture = atlas
		plate.modulate_color = Color("fff6df") if state == "hover" else Color("d9c5a1") if state == "pressed" else Color("788494") if state == "disabled" else Color.WHITE
		plate.content_margin_left = 16
		plate.content_margin_right = 16
		plate.content_margin_top = 5
		plate.content_margin_bottom = 5
		button.add_theme_stylebox_override(state, plate)
	button.add_theme_stylebox_override("focus", StarUi.style(Color.TRANSPARENT, StarUi.GOLD, 6, 0, 2))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button

func _build() -> void:
	theme = StarUi.theme()
	var art := TextureRect.new()
	art.texture = load(str(Characters.DATA[selected].get("artbook",PAGE)))
	if selected==&"sylphiette":
		# This source includes transparent page margins; the other two pages
		# reach their image edges. Fit the printed page to the same viewport.
		var page:=AtlasTexture.new()
		page.atlas=art.texture
		var extent:=art.texture.get_size()
		page.region=Rect2(extent*Vector2(.019,.030),extent*Vector2(.963,.945))
		page.filter_clip=true
		art.texture=page
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(art, Rect2(0, 0, 1280, 720))
	_text("人物设定集", 22, Rect2(177, 43, 320, 40), StarUi.GOLD)
	_text("CHARACTER ARCHIVE  /  " + ("03" if selected==&"ilyua" else ("02" if selected==&"xixifu" else "01")), 13, Rect2(178, 85, 340, 26), StarUi.MUTED)
	var character: Dictionary = Characters.DATA[selected]
	_text(str(character.name), 42, Rect2(177, 136, 365, 64))
	_text(str(character.job) + " · " + str(character.get("themes","火焰 / 自然 / 星辉")), 18, Rect2(180, 204, 348, 32), StarUi.MUTED)
	_text(str(character.get("intro","好奇而明快的魔法师。\n用火焰追逐未知，以自然守护旅伴，借星辉跨越危险。")), 20, Rect2(180, 259, 320, 115))
	_text("战斗风格", 17, Rect2(180, 388, 310, 30), StarUi.GOLD)
	_text(str(character.get("battle_style","远程追猎 · 范围爆发\n护盾与回复 · 自由配装")), 18, Rect2(180, 425, 325, 63))
	for index in 4:
		var id: StringName = character.get("preview_skills",[&"flame_nova", &"healing_light", &"blink", &"meteor"])[index]
		var skill := Skills.get_skill(id,"rooms")
		var slot:=StarUi.button("",16)
		slot.name="SkillPreview"+str(index)
		slot.custom_minimum_size=Vector2(54,54)
		for state in ["normal","hover","pressed","disabled"]:
			slot.add_theme_stylebox_override(state,StarUi.style(Color(0.08,0.13,0.20,0.25) if state=="hover" else Color.TRANSPARENT,StarUi.GOLD if state=="hover" else Color.TRANSPARENT,4,0,1))
		slot.tooltip_text="%s · %s\n%s\n消耗%d魔法 · 冷却%.1f秒" % [skill.name,skill.role,skill.desc,skill.mp,skill.cd]
		if MobileControls.enabled():slot.pressed.connect(func()->void:MobileControls.show_description(str(skill.name),str(skill.desc)+"\n消耗%d魔法 · 冷却%.1f秒"%[skill.mp,skill.cd]))
		_place(slot,Rect2(176+index*76,504,54,54))
		var icon:=UiFactory.texture_icon(str(skill.icon),46)
		# Trim atlas padding before fitting all four previews into identical squares.
		var image:=TexturePixels.image(icon.texture)
		var used:=image.get_used_rect()
		if used.has_area():
			var clipped:=AtlasTexture.new();clipped.atlas=icon.texture;clipped.region=used;clipped.filter_clip=true;icon.texture=clipped
		icon.stretch_mode=TextureRect.STRETCH_SCALE
		slot.add_child(icon);icon.position=Vector2(4,4);icon.size=Vector2(46,46)
		_buttons.append(slot)
		_text(str(skill.name), 13, Rect2(169 + index * 76, 552, 74, 24), StarUi.MUTED)
	_build_passives()
	var y := 118.0
	for entry in Characters.all():
		var id: StringName = entry.id
		var selector := StarUi.button("", 16)
		selector.tooltip_text = str(entry.name)
		selector.set_meta("character_id", id)
		selector.add_theme_stylebox_override("normal", StarUi.style(Color("27344b"), StarUi.GOLD if id == selected else Color("65738a"), 5, 0, 2))
		_place(selector, Rect2(20, y, 96, 132))
		var silhouette := TextureRect.new()
		silhouette.texture = load(str(entry.get("portraits", {}).get("stand", entry.portrait)))
		silhouette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		silhouette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; void fragment(){vec4 p=texture(TEXTURE,UV); COLOR=vec4(vec3(0.94,0.83,0.61),p.a);}"
		var material := ShaderMaterial.new()
		material.shader = shader
		silhouette.material = material
		selector.add_child(silhouette)
		silhouette.position = Vector2(9, 7)
		silhouette.size = Vector2(78, 96)
		var name_label := StarUi.label(str(entry.name), 14, Color("fff0d1"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selector.add_child(name_label)
		name_label.position = Vector2(3, 104)
		name_label.size = Vector2(90, 24)
		selector.pressed.connect(func() -> void:
			selected = id
			picked.emit(id)
		)
		_buttons.append(selector)
		y += 147
	var back := _drawn_button("", CLOSE_BUTTON_ART, 18)
	back.tooltip_text = "返回主菜单 (Esc)"
	back.set_meta("ui_action", "back")
	_place(back, Rect2(1205, 22, 50, 50))
	back.pressed.connect(func() -> void: back_requested.emit())
	_buttons.append(back)
	var start := _drawn_button("开始冒险", START_BUTTON_ART, 22)
	start.set_meta("ui_action", "start")
	_place(start, Rect2(178, 653, 340, 42))
	start.pressed.connect(func() -> void: start_requested.emit(selected))
	_buttons.append(start)
	for index in _buttons.size():
		var previous := _buttons[(index + _buttons.size() - 1) % _buttons.size()]
		var next := _buttons[(index + 1) % _buttons.size()]
		_buttons[index].focus_previous = _buttons[index].get_path_to(previous)
		_buttons[index].focus_next = _buttons[index].get_path_to(next)
		_buttons[index].focus_neighbor_top = _buttons[index].get_path_to(previous)
		_buttons[index].focus_neighbor_bottom = _buttons[index].get_path_to(next)

func focus_first() -> void:
	for button in _buttons:
		if button.has_meta("character_id"):button.grab_focus();return
	if not _buttons.is_empty():_buttons[0].grab_focus()

func _build_passives()->void:
	var choices:=PassiveDefinitions.for_character(selected)
	_text("同行之誓 · 出发后不可更改",16,Rect2(178,578,340,24),StarUi.GOLD)
	var width:=(340.0-6.0*(choices.size()-1))/choices.size()
	for i in choices.size():
		var passive:Dictionary=choices[i]
		var button:=StarUi.button("",17)
		button.name="Passive_"+str(passive.id)
		button.set_meta("passive_id",StringName(passive.id))
		button.tooltip_text=str(passive.desc)+"\n出发后锁定，继续旅途沿用原选择。"
		_place(button,Rect2(178+i*(width+6),604,width,45))
		var icon:=TextureRect.new()
		if ResourceLoader.exists(str(passive.icon)):icon.texture=load(str(passive.icon))
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(icon);icon.position=Vector2((width-24)/2,2);icon.size=Vector2(24,24)
		var label:=StarUi.label(str(passive.name),14,Color("f4e8ff"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(label);label.position=Vector2(2,26);label.size=Vector2(width-4,18);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(func()->void:
			PassiveDefinitions.select(selected,StringName(passive.id));_refresh_passive_buttons()
			if MobileControls.enabled():MobileControls.show_description(str(passive.name),str(passive.desc)))
		_buttons.append(button)
	_refresh_passive_buttons()

func _refresh_passive_buttons()->void:
	for button in _buttons:
		if not button.has_meta("passive_id"):continue
		var chosen:=StringName(button.get_meta("passive_id"))==PassiveDefinitions.selected(selected)
		button.add_theme_stylebox_override("normal",StarUi.style(Color(.06,.07,.15,.85),StarUi.GOLD if chosen else Color(.32,.32,.48,.75),5,0,2 if chosen else 1))
