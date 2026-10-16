class_name PauseUI
extends CanvasLayer
signal restart_requested
signal menu_requested
signal settings_requested
signal save_requested
signal leave_chapter_requested
var _closing := false
var _exit_tween: Tween
var _root: Control
var _status: Label
var _summary: Label
var _panel: PanelContainer
var _resume: Button
var _transition: Tween
var _leave_chapter: Button

func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build()
	_root.visible = false

func is_open() -> bool:
	return _root.visible

func open() -> void:
	if not UIFlow.can_open(self): return
	_closing = false
	if _exit_tween != null and _exit_tween.is_valid(): _exit_tween.kill()
	_root.visible = true
	UIFlow.push_screen(self)
	_status.text = ""
	_leave_chapter.visible = GameState.chapter_cleared
	_summary.text = "第 %d 波  /  Lv.%d\n金币 %d\n有效游玩  %s" % [GameState.wave, GameState.level, GameState.coins, GameState.play_time_text()]
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_transition = StarUi.reveal(_panel)
	_resume.grab_focus()

func close(immediate := false) -> void:
	if not is_open(): return
	if immediate:
		_finish_close()
		return
	if _closing: return
	_closing = true
	_exit_tween = ComicMotion.dismiss(_panel, _finish_close)

func _finish_close() -> void:
	_closing = false
	if _exit_tween != null and _exit_tween.is_valid(): _exit_tween.kill()
	if not _root.visible:
		return
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_root.visible = false
	UIFlow.pop_screen(self)

func _input(event: InputEvent) -> void:
	if not UIFlow.is_top(self) or _closing: return
	if _root.visible and (event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()

func _build() -> void:
	_root = UiFactory.full_rect()
	add_child(_root)
	_root.add_child(UiFactory.dim_layer(0.42))
	_root.theme = PixelUi.theme()
	var canvas := StarUi.frame(_root, Vector2(860, 500))
	_panel = PixelUi.panel()
	var style := PixelUi.plate(4)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 36
	style.content_margin_bottom = 36
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_panel)
	var row := UiFactory.hbox(26)
	_panel.add_child(row)
	var left := UiFactory.vbox(16)
	left.custom_minimum_size.x = 260
	row.add_child(left)
	left.add_child(PixelUi.label("旅途歇息", 18, PixelUi.GOLD))
	left.add_child(PixelUi.title("已暂停", 42))
	_summary = PixelUi.label("", 19, PixelUi.MUTED)
	left.add_child(_summary)
	var gap := UiFactory.spacer()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(gap)
	left.add_child(PixelUi.label("Esc 继续\n长按 R 返回营地", 16, PixelUi.MUTED))
	var right := UiFactory.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_resume = PixelUi.button("继续游戏    →", 21, 0, 54)
	_resume.custom_minimum_size.y = 54
	_resume.pressed.connect(close)
	right.add_child(_resume)
	_leave_chapter = PixelUi.button("女神接引 · 返回营地",18,0,48)
	_leave_chapter.custom_minimum_size.y = 44
	_leave_chapter.pressed.connect(func() -> void: leave_chapter_requested.emit())
	_leave_chapter.visible = false
	right.add_child(_leave_chapter)
	for entry in [
		["设置 · 显示与声音", func() -> void: settings_requested.emit()],
		["保存进度", func() -> void: save_requested.emit()],
		["返回主菜单", _on_menu_pressed],
		["退出游戏", func() -> void: SaveService.quit_game()],
	]:
		var button := PixelUi.button(str(entry[0]), 19, 0, 48)
		button.custom_minimum_size.y = 48
		button.pressed.connect(entry[1])
		right.add_child(button)
	_status = PixelUi.label("", 15, Color("9cddb0"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 44
	right.add_child(_status)
	InteractionSkin.mount(_root,"pause",_panel)

func _on_menu_pressed() -> void:
	close()
	menu_requested.emit()

func set_status(text: String) -> void:
	if _status != null:
		_status.text = text
