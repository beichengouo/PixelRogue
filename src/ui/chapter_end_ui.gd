class_name ChapterEndUI
extends CanvasLayer
signal menu_requested
signal restart_requested
signal next_requested(id: StringName)
var _root: Control
var _summary: Label
var _next: Button
var _canvas: Control
var _core_label: Label
var _stages: Array[Control] = []
var _presenting := false
var _presentation_epoch := 0
var _report_snapshot: Dictionary = {}
var _chapter_title:Label
var _chapter_hint:Label

func _ready() -> void:
	set_meta("blocking_screen", true)
	layer = 29
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_root = UiFactory.full_rect()
	_root.theme = PixelUi.theme()
	add_child(_root)
	_root.add_child(UiFactory.dim_layer(0.8))
	var canvas := StarUi.frame(_root, Vector2(980, 640))
	_canvas = canvas
	var panel := PixelUi.panel()
	var padding := PixelUi.plate(4)
	padding.content_margin_top = 44
	padding.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", padding)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(panel)
	var column := UiFactory.vbox(14)
	panel.add_child(column)
	column.add_child(PixelUi.label("章节 · 旅途刻印", 16, PixelUi.GOLD))
	var title := PixelUi.title("苏醒林地 · 通关", 38);_chapter_title=title
	column.add_child(title)
	_stages.append(title)
	_core_label = PixelUi.label("", 20, PixelUi.GOLD)
	_core_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_core_label)
	_stages.append(_core_label)
	_summary = PixelUi.label("", 18)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var report_scroll := ScrollContainer.new()
	report_scroll.custom_minimum_size.y = 180
	report_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	report_scroll.focus_mode = Control.FOCUS_ALL
	report_scroll.follow_focus = true
	column.add_child(report_scroll)
	_stages.append(report_scroll)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var report_box := UiFactory.vbox(14)
	report_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_scroll.add_child(report_box)
	report_box.add_child(_summary)
	var hint := PixelUi.label("伊莉丝会接引你返回营地，可重新准备并选择出征章节。",17,PixelUi.MUTED);_chapter_hint=hint
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	column.add_child(spacer)
	_next = PixelUi.primary("撤回营地 · 准备失名星城",19)
	_next.pressed.connect(func() -> void: next_requested.emit(ChapterCatalog.NEXT))
	column.add_child(_next)
	var row := UiFactory.hbox(12)
	column.add_child(row)
	_stages.append(row)
	var menu := PixelUi.button("呼唤女神 · 撤回营地", 18, 0, 52)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(func() -> void:
		if not is_open() or not UIFlow.is_top(self) or _complete_presentation(): return
		close(); menu_requested.emit())
	row.add_child(menu)
	var retry := PixelUi.button("继续无尽 · 收益仍有风险", 18, 0, 52)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(func() -> void:
		if not is_open() or not UIFlow.is_top(self) or _complete_presentation(): return
		close(); restart_requested.emit())
	row.add_child(retry)
	_root.visible = false

func open(snapshot: Dictionary) -> void:
	_root.visible = true
	UIFlow.push_screen(self)
	_report_snapshot = snapshot.duplicate(true)
	var chapter:=ChapterCatalog.normalize(snapshot.get("chapter_id",ChapterCatalog.FIRST))
	_chapter_title.text=ChapterCatalog.title(chapter)+" · 通关"
	_chapter_hint.text="强制归档已终止。回廊正为归来的旅人留灯。" if chapter==ChapterCatalog.NEXT else "失名星城已开放。请先撤回营地，再重新准备物资并选择目的地。"
	_next.visible=chapter==ChapterCatalog.FIRST
	_core_label.text = "击败三位守关者，完成本章。\nLv.%d · 金币 %d · 有效游玩 %s" % [int(snapshot.get("level", 1)), int(snapshot.get("coins", 0)), GameState.play_time_text(float(snapshot.get("first_chapter_seconds", snapshot.get("active_play_seconds", 0.0))))]
	RunBuildReport.populate(_summary, _report_snapshot)
	_next.disabled = not ChapterCatalog.is_ready(ChapterCatalog.NEXT)
	_start_presentation()
	var buttons := _root.find_children("*", "Button", true, false)
	for button in buttons:
		if not button.disabled and button.is_visible_in_tree():
			button.grab_focus()
			break

func close(_immediate := true) -> void:
	_presentation_epoch += 1
	ComicMotion.cancel(_canvas)
	_presenting = false
	_root.visible = false
	UIFlow.pop_screen(self)

func is_open() -> bool:
	return _root.visible

func _start_presentation() -> void:
	_presentation_epoch += 1
	var ticket := _presentation_epoch
	ComicMotion.cancel(_canvas)
	_canvas.modulate.a = 1.0
	_presenting = true
	for node in _stages: node.modulate.a = 0.0
	while ticket == _presentation_epoch and is_open() and not UIFlow.is_top(self):
		await get_tree().process_frame
	if ticket != _presentation_epoch or not is_open(): return
	ComicMotion.stage(_stages, _canvas, func() -> void: _presenting = false)

func _complete_presentation() -> bool:
	if not _presenting: return false
	_presentation_epoch += 1
	ComicMotion.cancel(_canvas)
	for node in _stages: node.modulate.a = 1.0
	_presenting = false
	return true

func _input(event: InputEvent) -> void:
	if not is_open() or not UIFlow.is_top(self): return
	if event.is_echo(): return
	if _presenting and (event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)):
		_complete_presentation()
		get_viewport().set_input_as_handled()
