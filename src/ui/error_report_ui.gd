extends CanvasLayer
signal closed
var root:Control
var canvas:Control
var details:TextEdit
var copy_button:Button
var status:Label
var _open:=false
func _ready()->void:
	layer=240;process_mode=Node.PROCESS_MODE_ALWAYS
	set_meta("interrupt_transition",true);set_meta("blocking_screen",true);set_meta("show_previous_screen",true)
	root=UiFactory.full_rect();add_child(root);root.add_child(UiFactory.dim_layer(.64))
	canvas=StarUi.frame(root,Vector2(960,620))
	var panel:=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.add_child(panel)
	var column:=UiFactory.vbox(14);panel.add_child(column)
	column.add_child(PixelUi.title("运行异常 · 请协助反馈",28))
	var prompt:=PixelUi.label("请复制下方报错信息，并将触发前的操作一并反馈给开发者。关闭后可尝试继续；若异常持续，请重启游戏。",18,PixelUi.INK)
	prompt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(prompt)
	details=TextEdit.new();details.name="ErrorDetails";details.editable=false;details.context_menu_enabled=true;details.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	details.size_flags_vertical=Control.SIZE_EXPAND_FILL;details.custom_minimum_size=Vector2(0,250);details.add_theme_font_size_override("font_size",16);column.add_child(details)
	status=PixelUi.label("复制内容仅保留本次运行的错误信息，不会自动发送。",16,PixelUi.MUTED);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	var row:=UiFactory.hbox(16);column.add_child(row)
	copy_button=PixelUi.button("复制报错信息",21,0,48);copy_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(copy_button);copy_button.pressed.connect(copy_report)
	var dismiss:=PixelUi.button("关闭 · 尝试继续",21,0,48);dismiss.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(dismiss);dismiss.pressed.connect(close)
	InteractionSkin.mount(root,"error_report",panel);root.hide()
func show_report(text:String)->void:
	var scroll:=details.scroll_vertical
	if details.text!=text:details.text=text;details.scroll_vertical=scroll
	copy_button.text="复制报错信息"
	if _open:return
	_open=true;root.show();UIFlow.push_screen(self);copy_button.grab_focus.call_deferred()
func copy_report()->void:
	DisplayServer.clipboard_set(details.text)
	copy_button.text="已复制"
	status.text="已复制报错信息，请粘贴并反馈给开发者。"
func close()->void:
	if not _open:return
	_open=false;root.hide();UIFlow.pop_screen(self);closed.emit()
func is_open()->bool:return _open
func _input(event:InputEvent)->void:
	if _open and UIFlow.is_top(self) and not event.is_echo() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		get_viewport().set_input_as_handled();close()
