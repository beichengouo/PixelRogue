class_name TalentTreeView
extends Control
## 四条独立流派从下往上成长；竖直连线直接呈现前置关系。
signal node_selected(branch: StringName)
signal node_activated(branch: StringName)
const NODE_SIZE := 112.0
const ICON_SIZE := 72.0
var selected: StringName = &""
var _centers: Dictionary = {}
var _path_pulses: Dictionary = {}
var _built_character:StringName=&""
var _last_click_branch:StringName=&""
var _last_click_msec:=0

func build() -> void:
	if _built_character!=Characters.current_id():
		_centers.clear();_path_pulses.clear();_built_character=Characters.current_id()
	if not _centers.is_empty():
		_refresh_nodes()
		return
	var focus := get_viewport().gui_get_focus_owner()
	var restore: StringName = focus.name if focus != null and is_ancestor_of(focus) else &""
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_centers.clear()
	var groups:Array=[];var names:Array=[]
	for entry in GameState.talent_groups():groups.append(str(entry[0]));names.append(str(entry[1]))
	var colors := [Color("edab88"), Color("e5c382"), Color("a7d9b1"), Color("c8b9ee")]
	for i in groups.size():
		var title := PixelUi.label(names[i], 26, colors[i])
		title.position = Vector2(56 + i * 240, 12)
		title.size = Vector2(208, 38)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title)
	for branch: StringName in GameState.TALENT_BRANCHES:
		var info: Dictionary = GameState.TALENT_BRANCHES[branch]
		var index := groups.find(str(info.branch))
		var center := Vector2(160 + index * 240, 612 - (int(info.tier) - 1) * 160)
		_centers[branch] = center
		add_child(_build_node(branch, center - Vector2.ONE * NODE_SIZE * 0.5))
	custom_minimum_size = Vector2(1060, 716)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wire_focus()
	if restore != &"":
		var node := get_node_or_null(NodePath(str(restore))) as Button
		if node != null:
			node.grab_focus()
	queue_redraw()

func _refresh_nodes() -> void:
	for child in get_children():
		if not child is Button: continue
		var branch := StringName(child.name)
		var info: Dictionary = GameState.TALENT_BRANCHES[branch]
		var rank := GameState.talent_rank(branch)
		var unlocked := GameState.talent_unlocked(branch)
		var previous_rank := int(child.get_meta("rank", rank))
		var previous_unlock := bool(child.get_meta("unlocked", unlocked))
		child.set_meta("rank", rank)
		child.set_meta("unlocked", unlocked)
		_style_node(child, branch)
		child.tooltip_text = "%s · %d/%d\n%s" % [info.name, rank, info.max_rank, info.desc]
		child.get_node("RankBadge").text = "%d / %d" % [rank, info.max_rank]
		child.get_node("TalentIcon").modulate = Color.WHITE if unlocked else Color(0.54, 0.62, 0.73, 0.76)
		var lock := child.get_node_or_null("LockIcon") as Control
		if lock != null: lock.visible = not unlocked
		if rank > previous_rank or (unlocked and not previous_unlock): ComicMotion.emphasize(child)
		if unlocked and not previous_unlock and not ComicMotion.reduced():
			_path_pulses[branch] = 0.35
			set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	for branch in _path_pulses.keys():
		_path_pulses[branch] = float(_path_pulses[branch]) - delta
		if float(_path_pulses[branch]) <= 0.0: _path_pulses.erase(branch)
	queue_redraw()
	if _path_pulses.is_empty(): set_process(false)

func _build_node(branch: StringName, at: Vector2) -> Control:
	var info: Dictionary = GameState.TALENT_BRANCHES[branch]
	var rank := GameState.talent_rank(branch)
	var max_rank := int(info["max_rank"])
	var unlocked := GameState.talent_unlocked(branch)
	var button := PixelUi.slot_button(PixelUi.LINE, NODE_SIZE)
	button.name = str(branch)
	button.set_meta("rank", rank)
	button.set_meta("unlocked", unlocked)
	button.position = at
	button.size = Vector2(NODE_SIZE, NODE_SIZE)
	button.custom_minimum_size = button.size
	button.tooltip_text = "%s  ·  %d/%d\n%s" % [str(info.name), rank, max_rank, str(info.desc)]
	_style_node(button, branch)
	var icon := UiFactory.texture_icon(str(info.get("icon", "")), ICON_SIZE)
	icon.position = Vector2(20, 7)
	icon.size = Vector2(72, 72)
	icon.modulate = Color.WHITE if unlocked else Color(0.54, 0.62, 0.73, 0.76)
	icon.name = "TalentIcon"
	button.add_child(icon)
	var badge := PixelUi.label("%d / %d" % [rank, max_rank], 24,
		Color("efd49a") if rank > 0 else Color("b0c0d6"))
	badge.position = Vector2(0, 77)
	badge.size = Vector2(NODE_SIZE, 34)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.name = "RankBadge"
	button.add_child(badge)
	var caption := PixelUi.label(str(info.name), 17, PixelUi.INK)
	caption.position = Vector2(-14, NODE_SIZE + 3)
	caption.size = Vector2(NODE_SIZE + 28, 28)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)
	if not unlocked:
		var lock := UiFactory.texture_icon(Skills.FRAME_LOCKED, 26)
		lock.position = Vector2(82, 3)
		lock.name = "LockIcon"
		button.add_child(lock)
	button.gui_input.connect(func(event: InputEvent) -> void:
		var mouse := event as InputEventMouseButton
		if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed or not mouse.double_click: return
		if _last_click_branch != branch or Time.get_ticks_msec() - _last_click_msec > 450: return
		_last_click_branch = &""
		node_activated.emit(branch)
		get_viewport().set_input_as_handled()
	)
	button.pressed.connect(func() -> void:
		_last_click_branch = branch
		_last_click_msec = Time.get_ticks_msec()
		select(branch)
		node_selected.emit(branch)
	)
	return button

func select(branch: StringName) -> void:
	selected = branch
	for child in get_children():
		if child is Button:
			_style_node(child, StringName(child.name))

func _style_node(button: Button, branch: StringName) -> void:
	var rank := GameState.talent_rank(branch)
	var info: Dictionary = GameState.TALENT_BRANCHES[branch]
	var unlocked := GameState.talent_unlocked(branch)
	var full := rank >= int(info.max_rank)
	var can_add := unlocked and not full and GameState.talent_points > 0
	var border := Color("5b6b84")
	if full:
		border = Color("adc99c")
	elif can_add or rank > 0:
		border = Color("d7b875")
	if branch == selected:
		border = Color("b5e9ff")
	var bg := Color("293b54") if unlocked else Color("1e2b40")
	button.add_theme_stylebox_override("normal", PixelUi.style(bg, border, 0, 0, 3 if branch == selected else 2))
	button.add_theme_stylebox_override("hover", PixelUi.style(Color("354a66"), Color("b5e9ff"), 0, 0, 3))
	button.add_theme_stylebox_override("pressed", PixelUi.style(Color("172235"), Color("b5e9ff"), 0, 0, 3))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new() if UIFlow.pointer_active else PixelUi.style(Color.TRANSPARENT, Color("b5e9ff"), 0, 0, 3))



func _draw() -> void:
	## 连线：从前置节点画到当前节点，没解锁的用虚线感（暗色）表示
	for branch: StringName in GameState.TALENT_BRANCHES:
		if not _centers.has(branch):
			continue
		var info: Dictionary = GameState.TALENT_BRANCHES[branch]
		var requires: Dictionary = info.get("requires", {})
		var to: Vector2 = _centers[branch]
		for need: StringName in requires:
			if not _centers.has(need):
				continue
			var from: Vector2 = _centers[need]
			var color := Color("52647f")
			if GameState.talent_unlocked(branch):
				color = Color("c3a779")
			elif GameState.talent_rank(need) > 0:
				color = Color("74829a")
			if _path_pulses.has(branch): color = color.lerp(Color("fff0b9"), float(_path_pulses[branch]) / 0.35)
			# 根在下、子节点在上，所以连线要从两个节点的圆外沿出发（按实际方向缩进半个节点）
			var dir := (to - from).normalized()
			draw_line(from + dir * NODE_SIZE * 0.5, to - dir * NODE_SIZE * 0.5, color, 4.0, false)

func _wire_focus() -> void:
	# Directional neighbours keep navigation inside the four talent branches.
	for child in get_children():
		if not child is Button:
			continue
		var at: Vector2 = _centers[StringName(child.name)]
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var best: Button = child
			var distance := INF
			for candidate in get_children():
				if not candidate is Button or candidate == child:
					continue
				var offset: Vector2 = _centers[StringName(candidate.name)] - at
				if offset.dot(direction) <= 0 or absf(offset.cross(direction)) > 1:
					continue
				if offset.length_squared() < distance:
					distance = offset.length_squared()
					best = candidate
			var path: NodePath = child.get_path_to(best)
			if direction == Vector2.LEFT: child.focus_neighbor_left = path
			elif direction == Vector2.RIGHT: child.focus_neighbor_right = path
			elif direction == Vector2.UP: child.focus_neighbor_top = path
			else: child.focus_neighbor_bottom = path
