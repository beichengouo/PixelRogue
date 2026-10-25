class_name TalentTreeView
extends Control
signal node_selected(branch: StringName)
signal node_activated(branch: StringName)
const NODE_SIZE := 88.0
const ICON_SIZE := 62.0
const ROW_PITCH := 130.0
var selected: StringName = &""
var _centers: Dictionary = {}
var _buttons: Dictionary = {}
var _built_signature := ""
var _last_click_branch: StringName = &""
var _last_click_msec := 0
var _roots: Dictionary = {}
func build() -> void:
	var skills:=SkillTalentCatalog.visible_skills()
	var signature:=str(Characters.current_id())+str(skills)+str(CampSession.active)
	if _built_signature != signature:
		for child in get_children():remove_child(child);child.queue_free()
		_centers.clear();_buttons.clear();_roots.clear();_built_signature=signature
	if not _centers.is_empty():_refresh_nodes();return
	var graph:=TalentGraph.visible_nodes()
	for index in skills.size():
		var skill:StringName=skills[index]
		var origin:=Vector2((index%2)*700, floori(index/2.0)*660)
		var info:=Skills.get_skill(skill)
		var root_icon:=UiFactory.texture_icon(str(info.get("icon","")),88)
		root_icon.position=origin+Vector2(306,16);root_icon.size=Vector2(88,88)
		root_icon.mouse_filter=Control.MOUSE_FILTER_STOP;root_icon.tooltip_text=str(info.get("desc",""))+"\n技能根节点 · 无需投入天赋点"
		add_child(root_icon)
		var title:=PixelUi.label("",22,PixelUi.GOLD)
		title.position=origin+Vector2(30,112);title.size=Vector2(640,34);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(title);_roots[skill]={"title":title,"icon":root_icon,"at":origin+Vector2(350,60)}
		for lane in 3:
			var label:=PixelUi.label(SkillTalentCatalog.ROUTE_NAMES[lane],17,PixelUi.MUTED)
			label.position=origin+Vector2(30+lane*220,166);label.size=Vector2(200,28);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(label)
		for id:StringName in graph:
			var node:Dictionary=graph[id]
			if node.skill!=skill:continue
			var at:=origin+Vector2(130+int(node.lane)*220,245+int(node.row)*ROW_PITCH)
			_centers[id]=at
			var button:=_build_node(id,at-Vector2.ONE*NODE_SIZE*.5)
			add_child(button);_buttons[id]=button
	custom_minimum_size=Vector2(1400,ceili(skills.size()/2.0)*660)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	_wire_focus();_refresh_nodes();set_process(false)
func _build_node(id: StringName, at: Vector2) -> Button:
	var info := TalentGraph.node(id)
	var button := Button.new(); button.name = str(id); button.position = at
	button.size = Vector2.ONE * NODE_SIZE; button.custom_minimum_size = button.size
	button.clip_contents = false; button.set_meta("glass_skip_style", true)
	var icon := UiFactory.texture_icon(str(info.icon), ICON_SIZE)
	icon.name = "TalentIcon"; icon.position = Vector2(13, 5); icon.size = Vector2.ONE * ICON_SIZE
	button.add_child(icon)
	var badge := PixelUi.label("", 16, PixelUi.GOLD); badge.name = "RankBadge"
	badge.position = Vector2(0, 64); badge.size = Vector2(NODE_SIZE, 22)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; badge.mouse_filter = Control.MOUSE_FILTER_IGNORE; button.add_child(badge)
	var caption := PixelUi.label(str(info.name), 15, PixelUi.INK)
	caption.position = Vector2(-58, NODE_SIZE + 3); caption.size = Vector2(NODE_SIZE + 116, 27)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; caption.mouse_filter = Control.MOUSE_FILTER_IGNORE; button.add_child(caption)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept") and not event.is_echo():
			node_activated.emit(id); button.accept_event(); return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
			if _last_click_branch == id and Time.get_ticks_msec() - _last_click_msec <= 450:
				_last_click_branch = &""; node_activated.emit(id); get_viewport().set_input_as_handled())
	button.pressed.connect(func() -> void:
		_last_click_branch = id; _last_click_msec = Time.get_ticks_msec(); select(id); node_selected.emit(id))
	button.focus_entered.connect(func() -> void:
		if not UIFlow.pointer_active: select(id); node_selected.emit(id))
	return button
func _refresh_nodes() -> void:
	for skill:StringName in _roots:
		var active:=SkillTalentCatalog.equipped(skill)
		_roots[skill].title.text="%s · %d / 9%s" % [Skills.get_skill(skill).name,SkillTalentCatalog.tree_spent(skill),"" if active else " · 未携带"]
		_roots[skill].icon.modulate=Color.WHITE if active else Color(.55,.6,.68,.75)
	for id: StringName in _buttons:
		var button: Button = _buttons[id]
		var owned := TalentGraph.owned(id, GameState.talents); var unlocked := TalentGraph.unlocked(id, GameState.talents)
		var previous := bool(button.get_meta("owned", owned)); button.set_meta("owned", owned); _style_node(button, id)
		button.tooltip_text = "%s\n%s\n%s" % [TalentGraph.node(id).name, TalentGraph.node(id).desc, ItemInsight.talent_requirement(id)]
		button.get_node("RankBadge").text = "已点亮" if owned else "1 点" if unlocked else "未解锁"
		button.get_node("TalentIcon").modulate = Color(.46,.50,.57,.68) if not SkillTalentCatalog.equipped(TalentGraph.node(id).skill) else Color.WHITE if owned or unlocked else Color(.42, .48, .57, .64)
		if owned and not previous: ComicMotion.emphasize(button)
	queue_redraw()
func cancel_pointer_sequence()->void:
	_last_click_branch=&"";_last_click_msec=0

func select(id: StringName) -> void:
	selected = id
	for key: StringName in _buttons: _style_node(_buttons[key], key)
func _style_node(button: Button, id: StringName) -> void:
	var owned := TalentGraph.owned(id, GameState.talents); var unlocked := TalentGraph.unlocked(id, GameState.talents)
	var color := Color("75c9a1") if owned else Color("e5c38a") if unlocked and GameState.talent_points > 0 else Color("556272")
	if id == selected: color = Color("a4e2fa")
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new(); box.bg_color = Color(.055, .10, .15, .86 if owned else .68)
		box.border_color = color.lightened(.16) if state in ["hover", "focus"] else color
		box.set_border_width_all(3 if id == selected else 2); box.set_corner_radius_all(16 if int(TalentGraph.node(id).rank) == 3 else 34)
		if state == "pressed": box.bg_color = Color(.12, .22, .28, .9)
		button.add_theme_stylebox_override(state, box)
func _draw() -> void:
	var graph := TalentGraph.visible_nodes()
	for skill:StringName in _roots:
		for route:StringName in SkillTalentCatalog.ROUTES:
			var id:=TalentGraph.id_for(SkillTalentCatalog.route_id(skill,route),1)
			if not _centers.has(id):continue
			var start:Vector2=_roots[skill].at+Vector2(0,48)
			var end:Vector2=_centers[id]-Vector2(0,NODE_SIZE*.5+5)
			draw_line(start,end,Color("d3b778") if SkillTalentCatalog.equipped(skill) else Color("556272"),2,true)
	for id: StringName in _centers:
		var info: Dictionary = graph[id]
		for need: StringName in info.requires_all: _draw_edge(need, id, false)
		for need: StringName in info.requires_any: _draw_edge(need, id, info.requires_any.size() > 1)
func _draw_edge(need: StringName, id: StringName, alternate: bool) -> void:
	if not _centers.has(need): return
	var from: Vector2 = _centers[need]; var to: Vector2 = _centers[id]; var direction := (to - from).normalized()
	from += direction * (NODE_SIZE * .5 + 5); to -= direction * (NODE_SIZE * .5 + 5)
	var lit := TalentGraph.owned(need, GameState.talents); var owned := TalentGraph.owned(id, GameState.talents)
	var color := Color("72bf9b") if lit and owned else Color("d3b778") if lit else Color(.36, .43, .51, .6)
	var points := PackedVector2Array([from])
	if absf(to.x - from.x) < 65 and to.y - from.y > ROW_PITCH * 1.4:
		var side := -1.0 if int(TalentGraph.node(id).lane) % 2 == 0 else 1.0; var channel := from.x + side * 82
		points.append(Vector2(channel, from.y + 28)); points.append(Vector2(channel, to.y - 28))
	points.append(to); draw_polyline(points, Color(.015, .035, .05, .9), 6, true)
	if alternate and not lit:
		for index in points.size() - 1: draw_dashed_line(points[index], points[index + 1], color, 2, 8, true)
	else: draw_polyline(points, color, 3, true)
	var last := (points[-1] - points[-2]).normalized()
	draw_colored_polygon(PackedVector2Array([to, to - last.rotated(.5) * 10, to - last.rotated(-.5) * 10]), color)
func _wire_focus() -> void:
	for id: StringName in _buttons:
		var child: Button = _buttons[id]
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var best: Button = child; var cost := INF
			for other: StringName in _buttons:
				if other == id: continue
				var offset: Vector2 = _centers[other] - _centers[id]; var forward := offset.dot(direction)
				if forward <= 1: continue
				var candidate := forward + absf(offset.cross(direction)) * 2.8
				if candidate < cost: cost = candidate; best = _buttons[other]
			var path := child.get_path_to(best)
			if direction == Vector2.LEFT: child.focus_neighbor_left = path
			elif direction == Vector2.RIGHT: child.focus_neighbor_right = path
			elif direction == Vector2.UP: child.focus_neighbor_top = path
			else: child.focus_neighbor_bottom = path
