class_name GlassConfirmUI
extends CanvasLayer
signal confirmed
signal canceled
signal about_to_popup
var title:="请确认"
var dialog_text:=""
var _root:Control
var _title:Label
var _text:Label
var _accept:Button
var _cancel:Button
var _open:=false
func _ready()->void:
	layer=48;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true);set_meta("show_previous_screen",true)
	_root=UiFactory.full_rect();add_child(_root);_root.add_child(UiFactory.dim_layer(.4))
	var frame:=StarUi.frame(_root,Vector2(660,360));var column:=UiFactory.vbox(18);frame.add_child(column);column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);column.offset_left=28;column.offset_right=-28;column.offset_top=28;column.offset_bottom=-28
	_title=PixelUi.title(title,28);_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(_title)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	_text=PixelUi.label(dialog_text,20);_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(_text)
	var row:=UiFactory.hbox(14);column.add_child(row)
	_cancel=get_cancel_button();row.add_child(_cancel);_cancel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_cancel.pressed.connect(_dismiss.bind(false))
	_accept=get_ok_button();_accept.set_meta("glass_danger",true);row.add_child(_accept);_accept.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_accept.pressed.connect(_dismiss.bind(true))
	InteractionSkin.mount(_root,"confirm",frame);_root.hide();visible=false
func get_ok_button()->Button:
	if _accept==null:_accept=PixelUi.button("确认",20,0,52)
	return _accept
func get_cancel_button()->Button:
	if _cancel==null:_cancel=PixelUi.button("取消",20,0,52)
	return _cancel
func popup_centered(_size:=Vector2i.ZERO)->void:
	if _open:return
	_title.text=title;_text.text=dialog_text;_open=true;visible=true;_root.show();about_to_popup.emit();UIFlow.push_screen(self);_cancel.grab_focus.call_deferred()
func _dismiss(accept:bool)->void:
	if not _open or not UIFlow.is_top(self):return
	close()
	if accept:confirmed.emit()
	else:canceled.emit()
func close()->void:
	_open=false
	if is_instance_valid(_root):_root.hide()
	visible=false;UIFlow.pop_screen(self)
func _input(event:InputEvent)->void:
	if _open and UIFlow.is_top(self) and not event.is_echo() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		get_viewport().set_input_as_handled();_dismiss(false)
