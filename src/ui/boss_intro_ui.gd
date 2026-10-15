class_name BossIntroUI
extends CanvasLayer
var _root: Control
var _card: Control
var _title: Label
var _subtitle: Label
var _icon: TextureRect
var _skip: Button
var _animation: Tween
var _epoch := 0
var _active := false
var _rift: Control
var _silhouette: TextureRect

func _ready() -> void:
	set_meta("blocking_screen", true)
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = UiFactory.full_rect()
	add_child(_root)
	_root.add_child(UiFactory.dim_layer(0.72))
	_rift = EncounterRift.new()
	_rift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_rift)
	_rift.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_silhouette = TextureRect.new()
	_silhouette.texture = load("res://assets/ui_art/transitions/goddess_profile_v1.png")
	_silhouette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_silhouette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rift.add_child(_silhouette)
	_silhouette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_silhouette.anchor_right = 0.45
	var ink := Shader.new()
	ink.code = "shader_type canvas_item; void fragment(){ float a=smoothstep(0.55,0.85,texture(TEXTURE,UV).a); COLOR=vec4(0.65,0.17,0.27,a*0.65); }"
	var material := ShaderMaterial.new()
	material.shader = ink
	_silhouette.material = material
	_card = StarUi.frame(_root, Vector2(980, 360))
	var panel := PixelUi.panel()
	_card.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := UiFactory.hbox(28)
	panel.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(230, 240)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(_icon)
	var column := UiFactory.vbox(16)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_child(PixelUi.label("强敌来袭  /  BOSS ENCOUNTER", 18, PixelUi.GOLD))
	_title = PixelUi.title("", 42)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	_subtitle = PixelUi.label("", 22)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_subtitle)
	_skip = PixelUi.compact_button("确认 / 返回 · 跳过演出", 16)
	_skip.pressed.connect(_skip_intro)
	_skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_skip)
	_root.hide()
	EventBus.boss_started.connect(play)
	EventBus.run_started.connect(func(_id: int) -> void: cancel())
	EventBus.player_died.connect(cancel)

func play(id: StringName) -> void:
	if is_instance_valid(GameState.runtime_node) and GameState.runtime_node._restoring: return
	cancel()
	_epoch += 1
	var ticket := _epoch
	var data := BossRoster.get_data(id)
	_title.text = str(data.title)
	_title.add_theme_color_override("font_color", Color(str(data.color)))
	_subtitle.text = str(data.subtitle)
	_icon.texture = PixelBossArt.icon(id)
	_root.show()
	_active = true
	UIFlow.push_screen(self)
	while ticket == _epoch and not UIFlow.is_top(self):
		await get_tree().process_frame
	if ticket != _epoch: return
	_skip.grab_focus()
	_card.modulate.a = 1.0
	# A short rupture, then the name, enemy portrait and combat hint.
	# Animate the wrapper opacity, never a Container-managed child's layout.
	_rift.modulate.a = 0.0
	_card.modulate.a = 0.0
	for part in [_title, _icon, _subtitle]: part.modulate.a = 0.0
	_animation = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var reduced := ComicMotion.reduced()
	_animation.tween_property(_rift, "modulate:a", 1.0, 0.04 if reduced else 0.12)
	_animation.tween_property(_card, "modulate:a", 1.0, 0.04 if reduced else 0.14)
	_animation.parallel().tween_property(_title, "modulate:a", 1.0, 0.04 if reduced else 0.18)
	_animation.tween_property(_icon, "modulate:a", 1.0, 0.04 if reduced else 0.18)
	_animation.tween_property(_subtitle, "modulate:a", 1.0, 0.04 if reduced else 0.16)
	await get_tree().create_timer(0.20 if ComicMotion.reduced() else 1.06, true).timeout
	if ticket == _epoch: _skip_intro()

func cancel() -> void:
	_epoch += 1
	if _animation != null and _animation.is_valid(): _animation.kill()
	if _card != null: ComicMotion.cancel(_card)
	if _rift != null: ComicMotion.cancel(_rift)
	if _root != null: _root.hide()
	_active = false
	UIFlow.pop_screen(self)

func _input(event: InputEvent) -> void:
	if not UIFlow.is_top(self): return
	if not _active:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		_skip_intro()
		get_viewport().set_input_as_handled()

func _skip_intro() -> void:
	if not _active: return
	_epoch += 1
	var ticket := _epoch
	_active = false
	if _animation != null and _animation.is_valid(): _animation.kill()
	ComicMotion.dismiss(_card, func() -> void: pass)
	ComicMotion.dismiss(_rift, func() -> void: pass)
	await get_tree().create_timer(0.08 if ComicMotion.reduced() else 0.14, true).timeout
	if ticket != _epoch: return
	_root.hide()
	# Let the confirm/cancel edge expire before simulation resumes.
	await get_tree().process_frame
	await get_tree().process_frame
	if ticket == _epoch: UIFlow.pop_screen(self)


class EncounterRift extends Control:
	func _ready() -> void:
		resized.connect(queue_redraw)
	func _draw() -> void:
		var top := size.y * 0.19
		var bottom := size.y * 0.81
		draw_colored_polygon(PackedVector2Array([Vector2(0,top), Vector2(size.x,top), Vector2(size.x,bottom), Vector2(0,bottom)]), Color("211521"))
		draw_line(Vector2(0,top),Vector2(size.x,top),Color("c46579"),3,true)
		draw_line(Vector2(0,bottom),Vector2(size.x,bottom),Color("7c394f"),3,true)
		for i in 12:
			var x := size.x * float(i) / 12.0
			draw_line(Vector2(x,top-20),Vector2(x+30,top-20),Color(0.8,0.4,0.5,0.25),2,true)
			var point := Vector2(x+24,bottom+20+(i%3)*7)
			draw_line(point-Vector2(4,0),point+Vector2(4,0),Color("e6ab9a"),1,true)
			draw_line(point-Vector2(0,4),point+Vector2(0,4),Color("e6ab9a"),1,true)
