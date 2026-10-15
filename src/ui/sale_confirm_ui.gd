class_name SaleConfirmUI
extends CanvasLayer
signal confirmed
signal canceled
var _root:Control
var _text:Label
var _open=false
var _panel:Control
var _cancel:Button
func _ready()->void:
	layer=45;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true)
	_root=UiFactory.full_rect();_root.theme=PixelUi.theme();add_child(_root)
	_root.add_child(UiFactory.dim_layer(0.42))
	_panel=StarUi.frame(_root,Vector2(700,490))
	var plate=PixelUi.inset_panel(20);plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_panel.add_child(plate)
	var box=UiFactory.vbox(14);plate.add_child(box)
	box.add_child(PixelUi.title("确认批量出售",25,PixelUi.GOLD))
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;box.add_child(scroll)
	_text=PixelUi.label("",17);_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(_text)
	var row=UiFactory.hbox(12);box.add_child(row)
	_cancel=PixelUi.compact_button("取消",18);_cancel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(_cancel)
	_cancel.set_meta("focus_token","warehouse_batch")
	_cancel.pressed.connect(func()->void:if _open:close();canceled.emit())
	var accept=PixelUi.compact_button("确认出售",18);accept.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(accept)
	accept.set_meta("focus_token","warehouse_batch")
	accept.pressed.connect(func()->void:if _open:close();confirmed.emit())
	_root.hide()
	InteractionSkin.mount(_root,"confirm",plate)

func open(text:String)->void:
	_text.text=text;_open=true;_root.show();UIFlow.push_screen(self);_cancel.grab_focus();ComicMotion.reveal(_panel)
func is_open()->bool:return _open
func close()->void:
	_open=false
	if is_instance_valid(_root):_root.hide()
	UIFlow.pop_screen(self)
func _input(event:InputEvent)->void:
	if _open and UIFlow.is_top(self) and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		close();canceled.emit();get_viewport().set_input_as_handled()
func _unhandled_input(_event:InputEvent)->void:
	if _open and UIFlow.is_top(self):get_viewport().set_input_as_handled()
func _exit_tree()->void:close()
