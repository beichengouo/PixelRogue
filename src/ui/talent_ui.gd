class_name TalentUI
extends CanvasLayer
## 技能天赋树：复用在背包天赋页，独立窗口仅作为旧入口兼容。
##
## 布局：左边是树（可滚轮缩放、拖拽平移，缩放时保持画面中心不动），
## 右边是详情面板 —— 单击节点看介绍，双击同一节点购买。
## 详情面板也保留显式购买按钮，方便键盘与手柄操作。
##
## 每个携带技能有独立根节点及三条路线，集中在同一画布。

## 同背包：打开时把战斗 HUD 收起来，别和左边的血条/技能格叠在一起。
signal opened
signal closed

const ZOOM_MIN := 0.25
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1
## 默认缩放（打开时先给个整体视角，想看细节再滚轮放大）
const DEFAULT_ZOOM := 0.5
## 详情面板宽度
const DETAIL_W := 330.0

var embedded_host: Node
var _embedded_parent: Control
var _canvas: Control
var _transition: Tween
var _closing := false
var _exit_tween: Tween
var _root: Control
var _points_label: Label
var _reset_button: Button
var _class_title:Label
var _class_subtitle:Label
var _zoom_label: Label
var _scroll: ScrollContainer
var _center: CenterContainer
var _holder: Control
var _tree: TalentTreeView
var _detail_box: VBoxContainer
var _tree_panel:Control
var _detail_panel:Control
var _stat_panel:VBoxContainer
var _mode_button:Button
var _run_view_stats:=true
var _hint_label: Label
var _tree_base_size := Vector2(400.0, 300.0)
var _zoom := DEFAULT_ZOOM
var _selected: StringName = &""
var _view_initialized := false
var _saved_pan := Vector2i.ZERO
var _submit_until := 0
var _view_epoch := 0
var _add_button: Button = null
var _pan_origin:=Vector2.INF
var _pan_scroll:=Vector2i.ZERO
var _panning:=false


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build()
	_root.visible = false
	EventBus.run_started.connect(func(_id: int) -> void:
		_view_initialized = false
		_selected = &""
		_zoom = DEFAULT_ZOOM
		_saved_pan = Vector2i.ZERO
		_view_epoch += 1)
	EventBus.talents_changed.connect(_refresh)
	EventBus.skills_changed.connect(func()->void:
		if is_open():_rebuild_tree())
	EventBus.coins_changed.connect(func(_coins:int)->void:_refresh())
	EventBus.level_changed.connect(func(_lv: int, _g: int) -> void: _refresh())


func is_open() -> bool:
	return _root.visible and (embedded_host == null or embedded_host.is_open())

func expedition_snapshot() -> Dictionary:
	var pan=Vector2i(_scroll.scroll_horizontal,_scroll.scroll_vertical) if is_open() else _saved_pan
	return {"zoom":_zoom,"selected":str(_selected),"initialized":_view_initialized,"pan":[pan.x,pan.y]}

func expedition_restore(data: Dictionary) -> void:
	if data.is_empty(): return
	_zoom=clampf(float(data.get("zoom",DEFAULT_ZOOM)),ZOOM_MIN,ZOOM_MAX)
	_selected=StringName(data.get("selected",""))
	_view_initialized=bool(data.get("initialized",false))
	var pan:Array=data.get("pan",[0,0])
	_saved_pan=Vector2i(int(pan[0]),int(pan[1]))
	_view_epoch+=1


func open() -> void:
	if is_instance_valid(embedded_host):
		embedded_host.open_talent_page(); return
	if not UIFlow.can_open(self): return
	_class_title.text="精灵天赋" if Characters.current_id()==&"ilyua" else ("影契天赋" if Characters.current_id()==&"xixifu" else "圣光天赋")
	_class_subtitle.text="营地永久属性 · 局内技能树每树9节点与终点"
	_run_view_stats=CampSession.active and not CampSession.training_active
	_closing = false
	if _exit_tween != null and _exit_tween.is_valid(): _exit_tween.kill()
	_root.visible = true
	UIFlow.push_screen(self)
	_view_epoch += 1
	_rebuild_tree()
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_transition = StarUi.reveal(_canvas)
	if not _view_initialized:
		_view_initialized = true
		_initial_view.call_deferred()
	else:
		_restore_pan.call_deferred(_view_epoch)
	opened.emit()


func _restore_pan(epoch: int) -> void:
	await get_tree().process_frame
	if epoch != _view_epoch or not is_open(): return
	_scroll.scroll_horizontal = _saved_pan.x
	_scroll.scroll_vertical = _saved_pan.y
	var node := _tree.get_node_or_null(NodePath(str(_selected))) as Button
	if node != null: node.grab_focus()

func _upgrade_selected() -> void:
	_upgrade_branch(_selected)

func _request_reset()->void:
	if not CampSession.active:return
	if CampSession.training_active:
		CampSession.clear_talents();_refresh();return
	var dialog:=ConfirmationDialog.new()
	dialog.title="重置永久属性"
	dialog.dialog_text="将清空此角色全部永久属性等级。已消耗的金币和材料不返还。"
	add_child(dialog)
	dialog.confirmed.connect(func()->void:
		if not PermanentStats.reset(Characters.current_id()):ComicMotion.feedback(_canvas,"重置保存失败，原属性已保留。")
		_refresh())
	dialog.popup_hide.connect(dialog.queue_free)
	dialog.popup_centered()


func _upgrade_branch(branch: StringName) -> void:
	if _closing or not _has_input_focus() or Time.get_ticks_msec() < _submit_until: return
	if TalentGraph.node(branch).is_empty(): return
	if not GameState.talent_unlocked(branch) or (CampSession.active and not CampSession.training_active):return
	if TalentGraph.owned(branch, GameState.talents): return
	_submit_until = Time.get_ticks_msec() + 120
	_selected = branch
	if GameState.spend_talent_point(branch):
		AudioManager.play(&"ui_click", -6.0)
		ComicMotion.feedback(_canvas, "点亮「%s」" % TalentGraph.node(branch).name)

func close(immediate := false) -> void:
	if is_instance_valid(embedded_host):
		if immediate:embedded_host._finish_close()
		else:embedded_host.close()
		return
	if not is_open(): return
	_saved_pan = Vector2i(_scroll.scroll_horizontal, _scroll.scroll_vertical)
	if immediate:
		_finish_close()
		return
	if _closing: return
	_closing = true
	ComicMotion.cancel(_canvas)
	_exit_tween = ComicMotion.dismiss(_canvas, _finish_close)

func _finish_close() -> void:
	_closing = false
	if _exit_tween != null and _exit_tween.is_valid(): _exit_tween.kill()
	if not _root.visible:
		return
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_root.visible = false
	UIFlow.pop_screen(self)
	closed.emit()


func _input(event: InputEvent) -> void:
	if not _has_input_focus() or _closing: return
	if not _root.visible:
		return
	if embedded_host == null and (event.is_action_pressed("talents") or event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
		return
	# Dragging the page must never be mistaken for a talent double click.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and _scroll.get_global_rect().has_point(event.position):
			_pan_origin=event.position;_pan_scroll=Vector2i(_scroll.scroll_horizontal,_scroll.scroll_vertical);_panning=false
		elif not event.pressed:_pan_origin=Vector2.INF;_panning=false
	if event is InputEventMouseMotion and _pan_origin.is_finite() and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		var offset:Vector2=event.position-_pan_origin
		if _panning or offset.length()>8:
			_panning=true;_tree.cancel_pointer_sequence()
			_scroll.scroll_horizontal=_pan_scroll.x-roundi(offset.x/maxf(.01,_scroll.get_global_transform().get_scale().x));_scroll.scroll_vertical=_pan_scroll.y-roundi(offset.y/maxf(.01,_scroll.get_global_transform().get_scale().y))
			get_viewport().set_input_as_handled();return
	# 滚轮缩放：保持画面中心那个点不动（视觉上就是原地放大/缩小）
	if event is InputEventMouseButton and event.pressed and _scroll.get_global_rect().has_point(get_viewport().get_mouse_position()):
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif button == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(-ZOOM_STEP)
			get_viewport().set_input_as_handled()


func _zoom_by(delta_step: float) -> void:
	_apply_zoom(_zoom + delta_step)


func _apply_zoom(value: float) -> void:
	var next := clampf(value, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(next, _zoom) or _scroll == null:
		return
	# 记下「当前视口中心」对应树里的哪个位置，缩放后再把这个位置摆回中心
	var view := _scroll.size
	var focus := Vector2(
		(float(_scroll.scroll_horizontal) + view.x * 0.5 - _holder.position.x) / _zoom,
		(float(_scroll.scroll_vertical) + view.y * 0.5 - _holder.position.y) / _zoom
	)
	_set_zoom(next)
	# 等容器把新的滚动范围算出来再回填，否则会被旧的边界夹住
	await get_tree().process_frame
	if _scroll == null:
		return
	# 减掉居中垫层的偏移：树比视口小的时候 CenterContainer 会把它挪到中间，
	# 不减这个偏移的话「居中缩放」会越放越偏。
	_scroll.scroll_horizontal = int(round(focus.x * _zoom - view.x * 0.5 + _holder.position.x))
	_scroll.scroll_vertical = int(round(focus.y * _zoom - view.y * 0.5 + _holder.position.y))


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
	if _tree != null:
		# 树本体只做 scale（尺寸保持原始大小），外面套一个「占位控件」把缩放后的
		# 真实尺寸告诉 ScrollContainer —— 否则滚动范围会按未缩放的尺寸算，滚不动。
		_tree.scale = Vector2.ONE * _zoom
		_tree.size = _tree_base_size
		_tree.custom_minimum_size = _tree_base_size
		_tree.queue_redraw()
	if _holder != null:
		_holder.custom_minimum_size = _tree_base_size * _zoom
		_holder.size = _tree_base_size * _zoom
	if _zoom_label != null:
		_zoom_label.text = "缩放 %d%%" % int(round(_zoom * 100.0))


func _build() -> void:
	_root = UiFactory.full_rect()
	add_child(_root)
	if _embedded_parent != null:
		_root.reparent(_embedded_parent, false)
		_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_root.clip_contents = true
		_canvas = UiFactory.full_rect(); _root.add_child(_canvas)
	else:
		_root.add_child(UiFactory.dim_layer(0.42))
		_canvas = StarUi.frame(_root, Vector2(1200, 640))
	# A scrolling boundary prevents the independent window's intrinsic minimum
	# height/width from propagating into the manually sized inventory canvas.
	var viewport := ScrollContainer.new()
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	viewport.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_canvas.add_child(viewport)
	var panel := PixelUi.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(panel)
	var column := UiFactory.vbox(12)
	panel.add_child(column)
	var header := HFlowContainer.new()
	header.add_theme_constant_override("h_separation", 14)
	column.add_child(header)
	_class_title=PixelUi.title("圣光天赋",30);header.add_child(_class_title)
	_class_subtitle=PixelUi.label("技能专属天赋树",15,PixelUi.MUTED);header.add_child(_class_subtitle)
	_points_label = PixelUi.label("", 19, PixelUi.GOLD)
	header.add_child(_points_label)
	var close_button := PixelUi.compact_button("关闭  ×", 16)
	close_button.tooltip_text = "%s / %s"%[KeyBindings.label("talents"),KeyBindings.label("ui_cancel")]
	close_button.pressed.connect(close)
	var reset := PixelUi.compact_button("重置天赋", 15)
	_reset_button = reset
	reset.tooltip_text = "训练场临时调整" if CampSession.training_active else "营地重置会清空此角色全部永久属性，已付金币和材料不返还。"
	reset.pressed.connect(_request_reset)
	header.add_child(reset)
	_mode_button=PixelUi.compact_button("切换天赋页",15)
	_mode_button.pressed.connect(func()->void:_run_view_stats=not _run_view_stats;_refresh())
	header.add_child(_mode_button)
	var buy_point:=PixelUi.compact_button("1000金币购买1点",15)
	buy_point.pressed.connect(func()->void:
		if GameState.buy_talent_point():ComicMotion.feedback(_canvas,"局内天赋点 +1")
		else:ComicMotion.feedback(_canvas,"金币不足或保存失败"))
	header.add_child(buy_point)
	buy_point.set_meta("run_point_purchase",true)
	if embedded_host == null: header.add_child(close_button)
	else: close_button.free()
	var body := UiFactory.hbox(18)
	body.custom_minimum_size.y = 390
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var tree_panel := PixelUi.inset_panel(12)
	_tree_panel=tree_panel
	tree_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(tree_panel)
	var tree_col := UiFactory.vbox(8)
	tree_panel.add_child(tree_col)
	var toolbar := UiFactory.hbox(8)
	tree_col.add_child(toolbar)
	_hint_label = PixelUi.label("滚轮缩放 · 拖动平移", 14, Color("becade"))
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if MobileControls.enabled():_hint_label.text="手指拖动平移 · ＋ / − 缩放"
	toolbar.add_child(_hint_label)
	for entry in [["−", -ZOOM_STEP], ["+", ZOOM_STEP]]:
		var step := float(entry[1])
		var button := PixelUi.compact_button(str(entry[0]), 20)
		button.custom_minimum_size = Vector2(34, 34)
		button.pressed.connect(func() -> void: _zoom_by(step))
		toolbar.add_child(button)
	_zoom_label = PixelUi.label("", 14, Color("becade"))
	toolbar.add_child(_zoom_label)
	var fit := PixelUi.compact_button("全览", 14)
	fit.pressed.connect(_fit_tree)
	toolbar.add_child(fit)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tree_col.add_child(_scroll)
	_center = CenterContainer.new()
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_center)
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(_holder)
	_tree = TalentTreeView.new()
	_tree.node_selected.connect(_on_node_selected)
	_tree.node_activated.connect(_upgrade_branch)
	_holder.add_child(_tree)
	var help := PixelUi.label("局内每3级得1点，也可花1000金币购买 · 三路线各三级后开放终点", 13, Color("c6d1e1"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tree_col.add_child(help)
	var detail := PixelUi.inset_panel(18)
	_detail_panel=detail
	detail.custom_minimum_size.x = DETAIL_W
	body.add_child(detail)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(detail_scroll)
	_detail_box = UiFactory.vbox(16)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail_box)
	var stat_scroll:=ScrollContainer.new()
	stat_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	stat_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stat_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(stat_scroll)
	_stat_panel=UiFactory.vbox(12)
	_stat_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	stat_scroll.add_child(_stat_panel)
	stat_scroll.hide()
	_set_zoom(_zoom)
	InteractionSkin.mount(_root,"talents",panel)

func _initial_view()->void:
	await get_tree().process_frame
	if not is_open():return
	_set_zoom(clampf((_scroll.size.x-18)/_tree_base_size.x,.4,.7))
	_scroll.scroll_horizontal=0;_scroll.scroll_vertical=0

func _fit_tree() -> void:
	await get_tree().process_frame
	if not _root.visible:
		return
	var view := _scroll.size - Vector2(18, 18)
	var fit := minf(view.x / _tree_base_size.x, view.y / _tree_base_size.y)
	_set_zoom(clampf(fit, ZOOM_MIN, 1.0))
	_scroll.scroll_horizontal = 0
	_scroll.scroll_vertical = 0
	var node := _tree.get_node_or_null(NodePath(str(_selected))) as Button
	if node != null:
		node.grab_focus()



func _rebuild_tree() -> void:
	if _tree == null:
		return
	_tree.build()
	if _selected != &"": _selected = TalentGraph.resolve(_selected, GameState.talents)
	_tree_base_size = Vector2(
		maxf(_tree.custom_minimum_size.x, 300.0),
		maxf(_tree.custom_minimum_size.y, 220.0)
	)
	# 打开时先自动选中一个节点（优先「现在就能加点」的），右侧面板就不会空着
	if _selected == &"" or not TalentGraph.visible_nodes().has(_selected):
		_selected = _default_pick()
	_set_zoom(_zoom)
	_refresh()


func _default_pick() -> StringName:
	for id: StringName in TalentGraph.visible_nodes():
		if TalentGraph.unlocked(id, GameState.talents) and not TalentGraph.owned(id, GameState.talents): return id
	return TalentGraph.visible_nodes().keys()[0] if not TalentGraph.visible_nodes().is_empty() else &""


func _on_node_selected(branch: StringName) -> void:
	_selected = branch
	_tree.select(branch)
	var focus_node := _tree.get_node_or_null(NodePath(str(branch))) as Control
	if focus_node != null and not UIFlow.pointer_active: _scroll.ensure_control_visible(focus_node)
	_refresh_detail()


func _refresh() -> void:
	var show_stat:=_run_view_stats
	if is_instance_valid(_mode_button):
		_mode_button.visible=false
	for child in _mode_button.get_parent().get_children():
		if child.has_meta("run_point_purchase"):
			child.visible=not CampSession.active
			child.disabled=not GameState.run_active or GameState.coins<GameState.TALENT_POINT_PRICE
	if is_instance_valid(_tree_panel):_tree_panel.visible=not show_stat
	if is_instance_valid(_detail_panel):_detail_panel.visible=not show_stat
	if is_instance_valid(_stat_panel):
		_stat_panel.get_parent().visible=show_stat
		if show_stat:_refresh_stat_panel()
	if is_instance_valid(_reset_button):
		_reset_button.visible=CampSession.active
		_reset_button.disabled = GameState.spent_talent_points()==0 if CampSession.training_active else PermanentStats.ranks().is_empty()
		_reset_button.text = "训练清空" if CampSession.training_active else "重置永久属性"
	if _points_label != null:
		_points_label.text = "训练预览" if CampSession.training_active else ("营地金币 %d"%Outpost.gold() if CampSession.active else "局内技能点 %d · 随身金币 %d"%[GameState.talent_points,GameState.coins])
	# 加点后节点状态会变，重建一次树让颜色/等级角标跟上
	if _root != null and is_open():
		_tree.selected = _selected
		_tree.build()
		_set_zoom(_zoom)
	_refresh_detail()

func _refresh_stat_panel()->void:
	for child in _stat_panel.get_children():child.queue_free();_stat_panel.remove_child(child)
	var headline:=PixelUi.label("永久属性成长 · %s"%("训练预览" if CampSession.training_active else "营地购买"),23,PixelUi.GOLD)
	_stat_panel.add_child(headline)
	var help:=PixelUi.label("每项最多8级；只提高角色自身基础属性，不改变技能效果。按角色永久保存。",16,PixelUi.MUTED)
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_stat_panel.add_child(help)
	var grid:=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);_stat_panel.add_child(grid)
	for id:StringName in PermanentStats.ORDER:
		var info:Dictionary=PermanentStats.DATA[id]
		var card:=PixelUi.inset_panel(12);card.custom_minimum_size=Vector2(290,120);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(card)
		var content:=UiFactory.vbox(7);card.add_child(content)
		var rank:=PermanentStats.rank(id)
		content.add_child(PixelUi.label("%s  %d / %d"%[info.name,rank,PermanentStats.MAX_RANK],19,PixelUi.INK))
		var description:=PixelUi.label(str(info.description),15,PixelUi.MUTED);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(description)
		var next_rank:=rank+1
		var price:=PermanentStats.cost(id,next_rank)
		var cost_text:=PackedStringArray()
		for material in price.get("materials",{}):cost_text.append("%s ×%d"%[str(ExpeditionData.resolve(str(material)).get("name",material)),int(price.materials[material])])
		if not price.is_empty():content.add_child(PixelUi.label("费用 %d金币 · %s"%[int(price.gold),"、".join(cost_text)],14,PixelUi.MUTED))
		var gate:=PermanentStats.gate(id,next_rank)
		if not str(gate.text).is_empty():content.add_child(PixelUi.label(str(gate.text),13,PixelUi.MUTED if gate.met else Color("ff9e9e")))
		var button:=PixelUi.compact_button("已满级" if rank>=PermanentStats.MAX_RANK else "购买下一级",15)
		button.disabled=not CampSession.active or CampSession.training_active or rank>=PermanentStats.MAX_RANK or not gate.met or not PermanentStats.affordable(id,next_rank)
		button.pressed.connect(_buy_permanent_stat.bind(id));content.add_child(button)

func _buy_permanent_stat(id:StringName)->void:
	if not _has_input_focus():return
	if PermanentStats.purchase(id):AudioManager.play(&"ui_click",-6);ComicMotion.feedback(_canvas,"%s +1"%PermanentStats.DATA[id].name);_refresh()
	else:ComicMotion.feedback(_canvas,"购买失败，资源已保留。")


## ---------------- 右侧详情 ----------------

func _refresh_detail() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var restore_add := is_instance_valid(_add_button) and focus == _add_button
	if _detail_box == null:
		return
	for child in _detail_box.get_children():
		_detail_box.remove_child(child)
		child.queue_free()

	if _selected == &"" or not TalentGraph.visible_nodes().has(_selected):
		_detail_box.add_child(PixelUi.label("天赋介绍", 22, PixelUi.GOLD))
		var empty_hint := PixelUi.label(
			"点一下左边的天赋节点，这里会显示它的介绍、前置条件和加点按钮。", 16,
			PixelUi.MUTED)
		# 必须开自动换行：否则这行字会把详情面板顶宽，把左边的树挤扁
		empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_hint.custom_minimum_size = Vector2(DETAIL_W - 48.0, 0.0)
		_detail_box.add_child(empty_hint)
		return

	var info: Dictionary = TalentGraph.node(_selected)
	var rank := 1 if TalentGraph.owned(_selected, GameState.talents) else 0
	var max_rank := int(info["max_rank"])
	var unlocked := GameState.talent_unlocked(_selected)
	var full := rank >= max_rank

	var title_row := UiFactory.hbox(10)
	var icon := UiFactory.texture_icon(str(info.get("icon", "")), 48.0)
	icon.modulate = Color.WHITE if unlocked else Color(0.5, 0.5, 0.55, 0.75)
	title_row.add_child(icon)
	var title_col := UiFactory.vbox(0)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_col)
	var name_label := PixelUi.label(str(info["name"]), 21, PixelUi.INK)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_col.add_child(name_label)
	var branch_label := PixelUi.label(
		"%s · %s" % [str(info.branch_name),str(info.route_name)],
		14, PixelUi.MUTED)
	branch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_col.add_child(branch_label)
	_detail_box.add_child(title_row)

	var desc := PixelUi.label(str(info["desc"]), 16, PixelUi.INK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(DETAIL_W - 48.0, 0.0)
	_detail_box.add_child(desc)
	var preview := PixelUi.label("本局已点亮 %d / %d · 本节点消耗1点" % [int(GameState.talents.get(info.effect,0)), int(GameState.TALENT_BRANCHES[info.effect].max_rank)], 15, Color("9ee6ab"))
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.custom_minimum_size.x = DETAIL_W - 48.0
	_detail_box.add_child(preview)

	var req := PixelUi.label("前置：%s" % _requirement_text(info), 15,
		PixelUi.MUTED if unlocked else Color("ff9e9e"))
	req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	req.custom_minimum_size = Vector2(DETAIL_W - 48.0, 0.0)
	_detail_box.add_child(req)

	var affordable:=GameState.talent_points>0
	var state_text := "已点亮" if full else "营地仅预览" if CampSession.active and not CampSession.training_active else "可加点" if unlocked and affordable else "点数不足" if unlocked else "前置未满足"
	_detail_box.add_child(PixelUi.label("状态：%s" % state_text, 15,
		PixelUi.GOLD if unlocked and not full else PixelUi.MUTED))

	var add := PixelUi.primary("已点亮" if full else "营地仅预览" if CampSession.active and not CampSession.training_active else "前置未满足" if not unlocked else "点数不足" if not affordable else "投入1点", 19)
	add.custom_minimum_size = Vector2(DETAIL_W - 48.0, 46.0)
	# 加点按钮就是普通按钮：不加图标（图标已经在上面标题行里了）
	add.disabled = full or (CampSession.active and not CampSession.training_active) or not unlocked or not affordable
	add.tooltip_text=ItemInsight.talent_requirement(_selected)
	if add.disabled:
		var reason:=PixelUi.label(add.tooltip_text,16,PixelUi.MUTED);reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_detail_box.add_child(reason)
	add.pressed.connect(_upgrade_selected)
	_detail_box.add_child(add)
	_add_button = add
	if restore_add:
		if not add.disabled: add.grab_focus()
		else:
			var node := _tree.get_node_or_null(NodePath(str(_selected))) as Button
			if node != null: node.grab_focus()


func _branch_name(info: Dictionary) -> String:
	return str(info.get("branch_name","天赋"))


func _requirement_text(info: Dictionary) -> String:
	return TalentGraph.requirement_text(StringName(info.id), GameState.talents)


func _has_input_focus() -> bool:
	if is_instance_valid(embedded_host) and bool(embedded_host.get("_closing")):return false
	return UIFlow.is_top(embedded_host if is_instance_valid(embedded_host) else self)

func show_embedded() -> void:
	if not is_instance_valid(embedded_host): return
	_root.show()
	_run_view_stats=CampSession.active and not CampSession.training_active
	_class_title.text = "技能天赋"
	_class_subtitle.text = "营地永久属性 · 局内技能树每树9节点与终点"
	_view_epoch += 1
	_rebuild_tree()
	if not _view_initialized:
		_view_initialized = true; _initial_view.call_deferred()
	else: _restore_pan.call_deferred(_view_epoch)

func hide_embedded() -> void:
	if _root == null or not _root.visible: return
	_saved_pan = Vector2i(_scroll.scroll_horizontal, _scroll.scroll_vertical)
	_root.hide()
