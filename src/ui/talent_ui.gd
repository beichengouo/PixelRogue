class_name TalentUI
extends CanvasLayer
## 天赋树独立窗口（按 T 开关）。
##
## 布局：左边是树（可滚轮缩放、拖拽平移，缩放时保持画面中心不动），
## 右边是详情面板 —— 单击节点看介绍，双击同一节点投入一点。
## 详情面板也保留显式加点按钮，方便键盘与手柄操作。
##
## 四条流派根部在下面；可同时投资不同流派。

## 同背包：打开时把战斗 HUD 收起来，别和左边的血条/技能格叠在一起。
signal opened
signal closed

const ZOOM_MIN := 0.3
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1
## 默认缩放（打开时先给个整体视角，想看细节再滚轮放大）
const DEFAULT_ZOOM := 0.5
## 详情面板宽度
const DETAIL_W := 330.0

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
var _hint_label: Label
var _tree_base_size := Vector2(400.0, 300.0)
var _zoom := DEFAULT_ZOOM
var _selected: StringName = &""
var _view_initialized := false
var _saved_pan := Vector2i.ZERO
var _submit_until := 0
var _view_epoch := 0
## 按住「加 1 点」自动连点用的状态
var _add_button: Button = null
var _hold_time := 0.0


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
	EventBus.coins_changed.connect(func(_coins:int)->void:_refresh())
	EventBus.level_changed.connect(func(_lv: int, _g: int) -> void: _refresh())


func is_open() -> bool:
	return _root.visible

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
	if not UIFlow.can_open(self): return
	_class_title.text="精灵天赋" if Characters.current_id()==&"ilyua" else ("影契天赋" if Characters.current_id()==&"xixifu" else "圣光天赋")
	_class_subtitle.text="自由搭配箭术、荆棘、月影与血脉" if Characters.current_id()==&"ilyua" else ("自由搭配四条契约流派" if Characters.current_id()==&"xixifu" else "自由搭配晨曦、圣羽、云庭与祈愿")
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
		_fit_tree.call_deferred()
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


func _upgrade_branch(branch: StringName) -> void:
	if _closing or not UIFlow.is_top(self) or Time.get_ticks_msec() < _submit_until: return
	if not GameState.TALENT_BRANCHES.has(branch): return
	if not GameState.talent_unlocked(branch) or GameState.talent_points <= 0: return
	if GameState.talent_rank(branch) >= int(GameState.TALENT_BRANCHES[branch].get("max_rank", 0)): return
	_submit_until = Time.get_ticks_msec() + 120
	_selected = branch
	if GameState.spend_talent_point(branch):
		AudioManager.play(&"ui_click", -6.0)
		ComicMotion.feedback(_canvas, "%s 升至 %d 级" % [GameState.TALENT_BRANCHES[branch].name, GameState.talent_rank(branch)])

func close(immediate := false) -> void:
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
	if not UIFlow.is_top(self) or _closing: return
	if not _root.visible:
		return
	if event.is_action_pressed("talents") or event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
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
	_root.add_child(UiFactory.dim_layer(0.42))
	_canvas = StarUi.frame(_root, Vector2(1200, 640))
	var panel := PixelUi.panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(panel)
	var column := UiFactory.vbox(12)
	panel.add_child(column)
	var header := UiFactory.hbox(14)
	column.add_child(header)
	_class_title=PixelUi.title("圣光天赋",30);header.add_child(_class_title)
	_class_subtitle=PixelUi.label("自由搭配四条法术流派",15,PixelUi.MUTED);header.add_child(_class_subtitle)
	header.add_child(UiFactory.spacer())
	_points_label = PixelUi.label("", 19, PixelUi.GOLD)
	header.add_child(_points_label)
	var close_button := PixelUi.compact_button("关闭  ×", 16)
	close_button.tooltip_text = "%s / %s"%[KeyBindings.label("talents"),KeyBindings.label("ui_cancel")]
	close_button.pressed.connect(close)
	var reset := PixelUi.compact_button("免费重置" if CampSession.active else "洗点 · 100金币", 15)
	_reset_button = reset
	reset.tooltip_text = "营地训练免费调整，不改变正式出征。" if CampSession.active else "消耗100局内金币，退还全部已投入点数；未投入不收费"
	reset.pressed.connect(GameState.reset_talents)
	header.add_child(reset)
	header.add_child(close_button)
	var body := UiFactory.hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var tree_panel := PixelUi.inset_panel(12)
	tree_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(tree_panel)
	var tree_col := UiFactory.vbox(8)
	tree_panel.add_child(tree_col)
	var toolbar := UiFactory.hbox(8)
	tree_col.add_child(toolbar)
	_hint_label = PixelUi.label("滚轮缩放 · 滚动条平移", 14, Color("becade"))
	if MobileControls.enabled():_hint_label.text="手指拖动平移 · ＋ / − 缩放"
	toolbar.add_child(_hint_label)
	toolbar.add_child(UiFactory.spacer())
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
	tree_col.add_child(PixelUi.label("单击查看 · 双击加 1 点    灰 未解锁    金 可加点    绿 满级    蓝 已选中", 13, Color("c6d1e1")))
	var detail := PixelUi.inset_panel(18)
	detail.custom_minimum_size.x = DETAIL_W
	body.add_child(detail)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(detail_scroll)
	_detail_box = UiFactory.vbox(16)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail_box)
	_set_zoom(_zoom)
	InteractionSkin.mount(_root,"talents",panel)

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
	_tree_base_size = Vector2(
		maxf(_tree.custom_minimum_size.x, 300.0),
		maxf(_tree.custom_minimum_size.y, 220.0)
	)
	# 打开时先自动选中一个节点（优先「现在就能加点」的），右侧面板就不会空着
	if _selected == &"" or not GameState.TALENT_BRANCHES.has(_selected):
		_selected = _default_pick()
	_set_zoom(_zoom)
	_refresh()


func _default_pick() -> StringName:
	for branch: StringName in GameState.TALENT_BRANCHES:
		if GameState.talent_unlocked(branch) \
				and GameState.talent_rank(branch) < int(GameState.TALENT_BRANCHES[branch]["max_rank"]) \
				and GameState.talent_points > 0:
			return branch
	for branch: StringName in GameState.TALENT_BRANCHES:
		return branch
	return &""


func _on_node_selected(branch: StringName) -> void:
	_selected = branch
	_tree.select(branch)
	_refresh_detail()


func _refresh() -> void:
	if is_instance_valid(_reset_button):
		_reset_button.disabled = not GameState.can_reset_talents()
		_reset_button.text = "无需洗点" if GameState.spent_talent_points()==0 else ("免费重置" if CampSession.active else "洗点 · 100金币")
	if _points_label != null:
		_points_label.text = "可用天赋点：%d" % GameState.talent_points
	# 加点后节点状态会变，重建一次树让颜色/等级角标跟上
	if _root != null and _root.visible:
		_tree.selected = _selected
		_tree.build()
		_set_zoom(_zoom)
	_refresh_detail()


## ---------------- 右侧详情 ----------------

func _refresh_detail() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var restore_add := is_instance_valid(_add_button) and focus == _add_button
	if _detail_box == null:
		return
	for child in _detail_box.get_children():
		_detail_box.remove_child(child)
		child.queue_free()

	if _selected == &"" or not GameState.TALENT_BRANCHES.has(_selected):
		_detail_box.add_child(PixelUi.label("天赋介绍", 22, PixelUi.GOLD))
		var empty_hint := PixelUi.label(
			"点一下左边的天赋节点，这里会显示它的介绍、前置条件和加点按钮。", 16,
			PixelUi.MUTED)
		# 必须开自动换行：否则这行字会把详情面板顶宽，把左边的树挤扁
		empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_hint.custom_minimum_size = Vector2(DETAIL_W - 48.0, 0.0)
		_detail_box.add_child(empty_hint)
		return

	var info: Dictionary = GameState.TALENT_BRANCHES[_selected]
	var rank := GameState.talent_rank(_selected)
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
	title_col.add_child(PixelUi.label(str(info["name"]), 21, PixelUi.INK))
	title_col.add_child(PixelUi.label(
		"%s　·　%d / %d 级" % [str(info.get("branch_name", _branch_name(info))), rank, max_rank],
		14, PixelUi.MUTED))
	_detail_box.add_child(title_row)

	var desc := PixelUi.label(str(info["desc"]), 16, PixelUi.INK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(DETAIL_W - 48.0, 0.0)
	_detail_box.add_child(desc)
	var preview := PixelUi.label(str(GameState.preview_talent(_selected).get("text", "")), 15, Color("9ee6ab"))
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.custom_minimum_size.x = DETAIL_W - 48.0
	_detail_box.add_child(preview)

	var req := PixelUi.label("前置：%s" % _requirement_text(info), 15,
		PixelUi.MUTED if unlocked else Color("ff9e9e"))
	req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	req.custom_minimum_size = Vector2(DETAIL_W - 48.0, 0.0)
	_detail_box.add_child(req)

	var state_text := "已满级" if full else ("天赋点不足" if unlocked and GameState.talent_points <= 0 else ("可以加点" if unlocked else "前置未满足"))
	_detail_box.add_child(PixelUi.label("状态：%s" % state_text, 15,
		PixelUi.GOLD if unlocked and not full else PixelUi.MUTED))

	var add := PixelUi.primary("已满级" if full else ("前置未满足" if not unlocked else ("天赋点不足" if GameState.talent_points <= 0 else "投入 1 点")), 19)
	add.custom_minimum_size = Vector2(DETAIL_W - 48.0, 46.0)
	# 加点按钮就是普通按钮：不加图标（图标已经在上面标题行里了）
	add.disabled = full or not unlocked or GameState.talent_points <= 0
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


func _process(delta: float) -> void:
	_hold_to_add(delta)


func _hold_to_add(delta: float) -> void:
	## 按住「加 1 点」不放就连续加点（0.45 秒后开始，每 0.18 秒加一点），
	## 免得多级天赋要一层层狂点。
	if _closing or not UIFlow.is_top(self) or not is_instance_valid(_add_button) or _add_button.disabled or not _root.visible:
		_hold_time = 0.0
		return
	var mouse := get_viewport().get_mouse_position()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			or not _add_button.get_global_rect().has_point(mouse):
		_hold_time = 0.0
		return
	_hold_time += delta
	if _hold_time < 0.45:
		return
	_hold_time = 0.18
	_upgrade_selected()


func _branch_name(info: Dictionary) -> String:
	return str(info.get("branch_name","天赋"))


func _requirement_text(info: Dictionary) -> String:
	var requires: Dictionary = info.get("requires", {})
	var parts: Array[String] = []
	for need: StringName in requires:
		if not GameState.TALENT_BRANCHES.has(need):
			continue
		var have := GameState.talent_rank(need)
		var want := int(requires[need])
		parts.append("%s ≥%d（当前 %d）" % [str(GameState.TALENT_BRANCHES[need]["name"]), want, have])
	return "、".join(parts) if not parts.is_empty() else "无（基础天赋）"

