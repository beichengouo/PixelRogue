class_name GameOverUI
extends CanvasLayer
## 死亡结算界面。

signal restart_requested
signal menu_requested

var _root: Control
var _stat_label: Label
var _canvas: Control
var _core_label: Label
var _stages: Array[Control] = []
var _presenting := false
var _presentation_epoch := 0
var _report_snapshot: Dictionary = {}
var _again: Button


func _ready() -> void:
	set_meta("blocking_screen", true)
	layer = 30
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func show_result(wave: int, coins: int, snapshot: Dictionary = {}) -> void:
	_report_snapshot = GameState.snapshot().duplicate(true) if snapshot.is_empty() else snapshot.duplicate(true)
	var best := int(SaveService.data.get("best_wave", 0))
	_core_label.text = "到达第 %d 波 · 损失随身金币 %d\n历史最佳 第 %d 波 · 有效游玩 %s" % [wave, coins, best, GameState.play_time_text(float(_report_snapshot.get("active_play_seconds", 0.0)))]
	RunBuildReport.populate(_stat_label, _report_snapshot)
	_root.visible = true
	UIFlow.push_screen(self)
	_start_presentation()
	_again.grab_focus()


func hide_ui() -> void:
	_presentation_epoch += 1
	ComicMotion.cancel(_canvas)
	_presenting = false
	_root.visible = false
	UIFlow.pop_screen(self)


func request_restart() -> void:
	if not is_open():
		return
	if not UIFlow.is_top(self) or _complete_presentation(): return
	hide_ui()
	restart_requested.emit()


func _build() -> void:
	_root = UiFactory.full_rect()
	_root.theme = PixelUi.theme()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(UiFactory.dim_layer(0.82))

	_canvas = StarUi.frame(_root, Vector2(920, 620))
	var panel := PixelUi.panel()
	var padding := PixelUi.plate(4)
	padding.content_margin_top = 44
	padding.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", padding)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(panel)

	var column := UiFactory.vbox(16)
	panel.add_child(column)

	column.add_child(PixelUi.label("星辉尚未熄灭", 16, PixelUi.GOLD))
	var title := PixelUi.title("旅途仍在继续", 36)
	title.custom_minimum_size = Vector2(0.0, 64.0)
	column.add_child(title)
	_stages.append(title)

	_core_label = PixelUi.label("", 20, PixelUi.GOLD)
	_core_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_core_label)
	_stages.append(_core_label)
	_stat_label = PixelUi.label("", 18)
	_stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var report_scroll := ScrollContainer.new()
	report_scroll.custom_minimum_size.y = 180
	report_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	report_scroll.focus_mode = Control.FOCUS_ALL
	report_scroll.follow_focus = true
	column.add_child(report_scroll)
	_stages.append(report_scroll)
	_stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var report_box := UiFactory.vbox(14)
	report_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_scroll.add_child(report_box)
	report_box.add_child(_stat_label)

	var hint := PixelUi.label("带入装备与未撤物资全部遗落；营地金库与关系保留。\n确认可完成展示，再次确认执行操作。", 16, PixelUi.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	column.add_child(spacer)

	var footer := UiFactory.hbox(12)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(footer)
	_stages.append(footer)

	var again := PixelUi.button("返回营地准备", 19, 0, 52)
	_again = again
	again.pressed.connect(request_restart)
	footer.add_child(again)

	var quit := PixelUi.button("返回主菜单", 19, 0, 52)
	quit.pressed.connect(func() -> void:
		if not is_open() or not UIFlow.is_top(self) or _complete_presentation(): return
		hide_ui()
		menu_requested.emit())
	footer.add_child(quit)

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
