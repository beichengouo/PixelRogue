class_name ComicMotion
extends RefCounted

static func reduced() -> bool:
	return bool(SaveService.data.get("reduced_motion", false))

static func reveal(node: Control, duration := 0.22) -> Tween:
	var previous: Variant = node.get_meta("comic_motion") if node.has_meta("comic_motion") else null
	if previous is Tween and previous.is_valid(): previous.kill()
	node.modulate.a = 0.0
	var tween := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(node, "modulate:a", 1.0, 0.10 if reduced() else duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	node.set_meta("comic_motion", tween)
	return tween

static func dismiss(node: Control, done: Callable) -> Tween:
	var previous: Variant = node.get_meta("comic_motion") if node.has_meta("comic_motion") else null
	if previous is Tween and previous.is_valid(): previous.kill()
	var tween := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(node, "modulate:a", 0.0, 0.08 if reduced() else 0.14)
	tween.tween_callback(done)
	node.set_meta("comic_motion", tween)
	return tween

static func cancel(node: Control) -> void:
	var old: Variant = node.get_meta("comic_motion") if node.has_meta("comic_motion") else null
	if old is Tween and old.is_valid(): old.kill()
	if node.has_meta("comic_motion"): node.remove_meta("comic_motion")

static func feedback(parent: Control, message: String) -> void:
	var old: Variant = parent.get_meta("comic_feedback") if parent.has_meta("comic_feedback") else null
	if is_instance_valid(old):
		cancel(old)
		old.free()
	# Keep animation independent of the component factory that calls it.
	var toast := Label.new()
	toast.text = message
	toast.add_theme_font_override("font", GameFonts.get_font("body"))
	toast.add_theme_font_size_override("font_size", 18)
	toast.add_theme_color_override("font_color", Color("edc881"))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_top = -52
	toast.offset_bottom = -12
	toast.z_index = 20
	parent.set_meta("comic_feedback", toast)
	var tween := reveal(toast, 0.12)
	tween.tween_interval(1.6)
	tween.tween_property(toast, "modulate:a", 0.0, 0.10 if reduced() else 0.14)
	tween.tween_callback(toast.queue_free)

static func emphasize(node: Control) -> void:
	cancel(node)
	node.modulate = Color(1.15, 1.12, 1.0)
	var tween := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(node, "modulate", Color.WHITE, 0.10 if reduced() else 0.28)
	node.set_meta("comic_motion", tween)

static func stage(nodes: Array[Control], owner: Control, done: Callable) -> Tween:
	cancel(owner)
	for node in nodes: node.modulate.a = 0.0
	var tween := owner.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for node in nodes:
		tween.tween_property(node, "modulate:a", 1.0, 0.025 if reduced() else 0.20)
	tween.tween_callback(done)
	owner.set_meta("comic_motion", tween)
	return tween

static func accent(parent: Control, tint := Color("e8bf79")) -> void:
	var ink := ComicEdge.new()
	ink.tint = tint
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ink)
	ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ink.resized.connect(ink.queue_redraw)

static func bind_button(button: Button) -> void:
	if button.has_meta("comic_bound"): return
	button.set_meta("comic_bound", true)
	var mark := ComicFocus.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(mark)
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var focus_style := button.get_theme_stylebox("focus").duplicate()
	var pointer_style := StyleBoxEmpty.new()
	var update := func() -> void:
		button.add_theme_stylebox_override("focus", pointer_style if UIFlow.pointer_active else focus_style)
		mark.active = not button.disabled and (button.is_hovered() if UIFlow.pointer_active else button.has_focus())
		mark.queue_redraw()
	for event in [button.focus_entered, button.focus_exited, button.mouse_entered, button.mouse_exited, button.button_down, button.button_up, button.resized]: event.connect(update)
	button.mouse_entered.connect(func() -> void: UIFlow.set_pointer_active(true))
	UIFlow.navigation_mode_changed.connect(update)
	button.tree_exiting.connect(func() -> void:
		if UIFlow.navigation_mode_changed.is_connected(update): UIFlow.navigation_mode_changed.disconnect(update))
	button.ready.connect(update)
	button.focus_entered.connect(func() -> void:
		if not UIFlow.pointer_active and button.is_inside_tree() and button.is_visible_in_tree(): AudioManager.play(&"ui_click", -22))

class ComicFocus extends Control:
	var active := false
	func _draw() -> void:
		if not active: return
		var gold := Color("ffe0a2")
		var y := size.y * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(3, y-5), Vector2(10, y), Vector2(3, y+5)]), gold)
		draw_line(Vector2(15, size.y-3), Vector2(size.x-12, size.y-3), Color(gold, 0.75), 2, true)

class ComicEdge extends Control:
	var tint := Color("e8bf79")
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(110, 0), Vector2(92, 5), Vector2(0, 5)]), tint)
		draw_colored_polygon(PackedVector2Array([Vector2(w, h), Vector2(w-110, h), Vector2(w-92, h-5), Vector2(w, h-5)]), tint)
		for i in 5:
			draw_line(Vector2(w-12-i*7, 5), Vector2(w-20-i*7, 16), Color(tint, 0.45), 2, true)
			for j in 3:
				draw_circle(Vector2(8+i*7, h-9-j*7), 1, Color(tint, 0.25))
