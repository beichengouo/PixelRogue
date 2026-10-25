class_name CharacterArtbook
extends Control
signal picked(id: StringName)
signal back_requested()
signal start_requested(id: StringName)

const PAGE := "res://assets/ui_art/characters/sylphiette_artbook.png"
var selected: StringName = Characters.DEFAULT_ID
var _buttons: Array[Button] = []
var _page_art: TextureRect
var _page_surround: PageSurround
var _passive_summary: Label
var _committed := false
var _accent := Color("f3dda2")
const PROFILES := {
	&"sylphiette": ["圣云祈愿", "愿每一束光，都能照见归途。", "以祈光积累强化施法，用圣裁与领域掌控战场。"],
	&"xixifu": ["幽灯契约", "别害怕，我们一起回去。", "召唤近战与远程伙伴，以契约集火、护盾守护旅伴。"],
	&"ilyua": ["林间风语", "风会记得，我们走过的路。", "以连射和穿透寻找破绽，用荆棘与月影衔接游击。"],
}

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

func _skin_button(button: Button, chosen := false, primary := false) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		var lit: bool = chosen or primary or state == "hover"
		var bg := Color("253245") if lit else Color("182335")
		bg.a = .94 if lit else .80
		if state == "pressed": bg = Color("101b2c")
		var edge := _accent if lit else Color("65738a")
		if state == "disabled": edge = Color("576070")
		button.add_theme_stylebox_override(state, StarUi.style(bg, edge, 10, 6, 2 if chosen or primary else 1))
	button.add_theme_stylebox_override("focus", StarUi.style(Color.TRANSPARENT, Color("fff2cf"), 10, 0, 3))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("fff3d9"))

func _entrance() -> void:
	var order := 0
	for node in get_children():
		if not node is Control or node is TextureRect or node == _page_surround: continue
		var control := node as Control
		var destination := control.position
		control.modulate.a = 0
		if not ComicMotion.reduced(): control.position.x -= 10
		var tween := control.create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		var delay := 0.0 if ComicMotion.reduced() else minf(order * .012, .16)
		tween.tween_property(control,"modulate:a",1.0,.10 if ComicMotion.reduced() else .24).set_delay(delay)
		tween.tween_property(control,"position",destination,.10 if ComicMotion.reduced() else .28).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		order += 1

func _start() -> void:
	if _committed: return
	_committed = true
	start_requested.emit(selected)

func _build() -> void:
	theme = StarUi.theme()
	_accent = Color(str(Characters.DATA[selected].get("accent","f3dda2")))
	_page_surround = PageSurround.new()
	_page_surround.name = "PageSurround"
	_page_surround.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_page_surround, Rect2(0,0,1280,720))
	var art := TextureRect.new()
	_page_art = art
	art.name = "FullBleedPage"
	art.texture = load(str(Characters.DATA[selected].get("artbook",PAGE)))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(art, Rect2(0, 0, 1280, 720))
	var character: Dictionary = Characters.DATA[selected]
	var profile: Array = PROFILES[selected]
	_text("选择同行之人", 22, Rect2(177, 40, 340, 36), StarUi.GOLD)
	_text("旅人档案  /  %02d" % (Characters.DATA.keys().find(selected)+1), 14, Rect2(178, 79, 340, 26), StarUi.MUTED)
	_text(str(character.name), 44, Rect2(177, 118, 350, 65))
	_text(str(character.job) + "  /  " + str(profile[0]), 19, Rect2(180, 190, 340, 32), StarUi.MUTED)
	_text("「" + str(profile[1]) + "」", 19, Rect2(178, 237, 340, 57), StarUi.GOLD)
	_text(str(character.intro), 18, Rect2(180, 300, 330, 81))
	_text("战斗特长", 16, Rect2(180, 385, 330, 26), StarUi.GOLD)
	_text(str(profile[2]), 17, Rect2(180, 413, 330, 52))
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
		_place(slot,Rect2(178+index*84,468,60,58))
		var icon:=UiFactory.texture_icon(str(skill.icon),46)
		# Trim atlas padding before fitting all four previews into identical squares.
		var image:=TexturePixels.image(icon.texture)
		var used:=image.get_used_rect()
		if used.has_area():
			var clipped:=AtlasTexture.new();clipped.atlas=icon.texture;clipped.region=used;clipped.filter_clip=true;icon.texture=clipped
		icon.stretch_mode=TextureRect.STRETCH_SCALE
		slot.add_child(icon);icon.position=Vector2(7,6);icon.size=Vector2(46,46)
		_buttons.append(slot)
		_text(str(skill.name), 13, Rect2(171 + index * 84, 526, 78, 22), StarUi.MUTED)
	_build_passives()
	_text("旅 人", 16, Rect2(24, 61, 90, 32), Color("e4d2b2"))
	var y := 118.0
	for entry in Characters.all():
		var id: StringName = entry.id
		var selector := StarUi.button("", 16)
		selector.tooltip_text = str(entry.name)
		selector.set_meta("character_id", id)
		_skin_button(selector, id == selected)
		selector.name = "Character_" + str(id)
		_place(selector, Rect2(20, y, 96, 132))
		var silhouette := TextureRect.new()
		silhouette.name = "CharacterSilhouette"
		silhouette.texture = load(str(entry.get("portraits", {}).get("stand", entry.portrait)))
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; uniform vec4 ink : source_color = vec4(0.94,0.83,0.61,1.0); varying vec4 tint; void vertex(){tint=COLOR;} void fragment(){vec4 p=texture(TEXTURE,UV); COLOR=vec4(ink.rgb,p.a*ink.a)*tint;}"
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("ink", _accent if id == selected else Color("acb3c3"))
		silhouette.material = material
		silhouette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		silhouette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selector.add_child(silhouette)
		silhouette.position = Vector2(9, 5)
		silhouette.size = Vector2(78, 94)
		var name_label := StarUi.label(str(entry.name), 14, Color("fff0d1"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selector.add_child(name_label)
		name_label.position = Vector2(3, 99)
		name_label.size = Vector2(90, 24)
		selector.pressed.connect(func() -> void:
			if selected == id or _committed: return
			selected = id
			AudioManager.play(&"ui_click", -12.0)
			picked.emit(id)
		)
		_buttons.append(selector)
		y += 147
	var back := StarUi.button("返回", 18)
	_skin_button(back)
	back.tooltip_text = "返回主菜单"
	back.set_meta("ui_action", "back")
	_place(back, Rect2(1164, 24, 90, 58))
	back.pressed.connect(func() -> void: back_requested.emit())
	_buttons.append(back)
	var start := StarUi.button("与她同行  ·  前往营地", 22)
	_skin_button(start, false, true)
	start.set_meta("ui_action", "start")
	_place(start, Rect2(178, 652, 340, 58))
	start.pressed.connect(_start)
	_buttons.append(start)
	for index in _buttons.size():
		var previous := _buttons[(index + _buttons.size() - 1) % _buttons.size()]
		var next := _buttons[(index + 1) % _buttons.size()]
		_buttons[index].focus_previous = _buttons[index].get_path_to(previous)
		_buttons[index].focus_next = _buttons[index].get_path_to(next)
		_buttons[index].focus_neighbor_top = _buttons[index].get_path_to(previous)
		_buttons[index].focus_neighbor_bottom = _buttons[index].get_path_to(next)

	_entrance()

func fit_background(rect: Rect2) -> void:
	if not is_instance_valid(_page_art): return
	# Keep the source page intact. Extra aspect-ratio space is a separate,
	# code-drawn surface, never a stretched column of the source texture.
	_page_art.position = Vector2.ZERO
	_page_art.size = Vector2(1280,720)
	_page_surround.position = rect.position
	_page_surround.size = rect.size
	_page_surround.page_origin = -rect.position
	_page_surround.queue_redraw()


func focus_first() -> void:
	for button in _buttons:
		if button.get_meta("character_id", &"") == selected:button.grab_focus();return
	if not _buttons.is_empty():_buttons[0].grab_focus()

func _build_passives()->void:
	var choices:=PassiveDefinitions.for_character(selected)
	_text("同行之誓  /  选择一项被动",15,Rect2(178,554,340,23),StarUi.GOLD)
	_passive_summary = _text("",14,Rect2(178,629,340,22),StarUi.MUTED)
	_passive_summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	_passive_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var width:=(340.0-6.0*(choices.size()-1))/choices.size()
	for i in choices.size():
		var passive:Dictionary=choices[i]
		var button:=StarUi.button("",17)
		button.name="Passive_"+str(passive.id)
		button.custom_minimum_size.y = 48
		button.set_meta("passive_id",StringName(passive.id))
		button.tooltip_text=str(passive.desc)+"\n"+CharacterUnlocks.passive_condition(StringName(passive.id),selected)+"\n出发后锁定，继续旅途沿用原选择。"
		button.modulate=Color.WHITE if CharacterUnlocks.passive_available(StringName(passive.id),selected) else Color(.65,.65,.7)
		_place(button,Rect2(178+i*(width+6),578,width,48))
		var icon:=TextureRect.new()
		if ResourceLoader.exists(str(passive.icon)):icon.texture=load(str(passive.icon))
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(icon);icon.position=Vector2((width-24)/2,2);icon.size=Vector2(24,24)
		var label:=StarUi.label(str(passive.name),14,Color("f4e8ff"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(label);label.position=Vector2(2,26);label.size=Vector2(width-4,18);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(func()->void:
			PassiveDefinitions.select(selected,StringName(passive.id));_refresh_passive_buttons()
			if not CharacterUnlocks.passive_available(StringName(passive.id),selected):_passive_summary.text="未解锁 · "+CharacterUnlocks.passive_condition(StringName(passive.id),selected)
			if MobileControls.enabled():MobileControls.show_description(str(passive.name),str(passive.desc)+"\n"+CharacterUnlocks.passive_condition(StringName(passive.id),selected)))
		_buttons.append(button)
	_refresh_passive_buttons()

func _refresh_passive_buttons()->void:
	for button in _buttons:
		if not button.has_meta("passive_id"):continue
		var chosen:=StringName(button.get_meta("passive_id"))==PassiveDefinitions.selected(selected)
		_skin_button(button, chosen)
		if chosen and is_instance_valid(_passive_summary):
			for passive in PassiveDefinitions.for_character(selected):
				if StringName(passive.id) == PassiveDefinitions.selected(selected):
					_passive_summary.text = str(passive.desc)
					_passive_summary.tooltip_text = str(passive.desc)
					break


class PageSurround extends Control:
	var page_origin := Vector2.ZERO

	func _draw() -> void:
		var paper := Color("f6eedf")
		var navy := Color("19273e")
		var gold := Color("b99a64")
		draw_rect(Rect2(Vector2.ZERO,size),paper)
		var rail_width := clampf(page_origin.x+128.0,0.0,size.x)
		draw_rect(Rect2(0,0,rail_width,size.y),navy)
		# Crisp stars and rules belong to the margin itself; no texture resampling.
		var page_rect := Rect2(page_origin,Vector2(1280,720))
		for column in range(ceili(rail_width/72.0)):
			for row in range(ceili(size.y/96.0)):
				var at := Vector2(30.0+column*72.0,40.0+row*96.0+float(column%2)*24.0)
				if at.x>rail_width-12 or page_rect.has_point(at): continue
				var tint := Color(gold,.55 if (column+row)%3==0 else .24)
				var radius := 5.0 if (column+row)%3==0 else 2.0
				draw_line(at-Vector2(radius,0),at+Vector2(radius,0),tint,1.0,true)
				draw_line(at-Vector2(0,radius*1.6),at+Vector2(0,radius*1.6),tint,1.0,true)
		draw_line(Vector2(10,10),Vector2(size.x-10,10),Color(gold,.5),1.0,true)
		draw_line(Vector2(10,size.y-10),Vector2(size.x-10,size.y-10),Color(gold,.5),1.0,true)
