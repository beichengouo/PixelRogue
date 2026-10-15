class_name LayerArtEditor
extends Window
var canvas:ArtEditCanvas
var _documents:Array[Dictionary]=[]
var _document_picker:OptionButton
var _layers:ItemList
var _controls:ItemList
var _status:Label
var _font:SpinBox
var _pending:=false
var _saved_overrides:Dictionary={}
var _document_index:=0
func _ready()->void:
	title="图层精修与界面布局";size=Vector2i(1320,840);min_size=Vector2i(1080,680);close_requested.connect(_request_close)
	var root:=VBoxContainer.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root)
	var toolbar:=HFlowContainer.new();root.add_child(toolbar)
	_document_picker=OptionButton.new();_document_picker.custom_minimum_size.x=280;toolbar.add_child(_document_picker)
	var mode:=OptionButton.new();mode.add_item("抠图精修");mode.add_item("界面布局：拖文案 / 按钮");toolbar.add_child(mode)
	var brush:=SpinBox.new();brush.min_value=1;brush.max_value=128;brush.value=12;brush.prefix="画笔";toolbar.add_child(brush)
	var restore:=CheckBox.new();restore.text="恢复原图透明边缘";toolbar.add_child(restore)
	var solo:=CheckBox.new();solo.text="单看选中层";toolbar.add_child(solo)
	_button(toolbar,"撤销",func():canvas.buffer.undo_stroke();canvas.refresh_image();_pending=true)
	_button(toolbar,"重做",func():canvas.buffer.redo_stroke();canvas.refresh_image();_pending=true)
	_button(toolbar,"适应窗口",func():canvas.fit())
	_button(toolbar,"保存并应用",_save)
	var body:=HSplitContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;root.add_child(body)
	var sidebar:=VBoxContainer.new();sidebar.custom_minimum_size.x=285;body.add_child(sidebar)
	var label:=Label.new();label.text="图层（底图只读）";sidebar.add_child(label)
	_layers=ItemList.new();_layers.custom_minimum_size.y=250;_layers.size_flags_vertical=Control.SIZE_EXPAND_FILL;sidebar.add_child(_layers)
	var visible:=CheckBox.new();visible.text="选中图层参与合成";sidebar.add_child(visible)
	label=Label.new();label.text="可拖动的界面文案 / 按钮 / 区域";sidebar.add_child(label)
	_controls=ItemList.new();_controls.custom_minimum_size.y=170;_controls.size_flags_vertical=Control.SIZE_EXPAND_FILL;sidebar.add_child(_controls)
	_font=SpinBox.new();_font.min_value=10;_font.max_value=48;_font.prefix="选中文案字号";sidebar.add_child(_font)
	_button(sidebar,"恢复该控件默认布局",_reset_control)
	canvas=ArtEditCanvas.new();canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL;canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(canvas)
	_status=Label.new();_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;root.add_child(_status)
	_document_picker.item_selected.connect(_choose_document)
	mode.item_selected.connect(func(index:int):canvas.mode=index;canvas.queue_redraw())
	brush.value_changed.connect(func(value:float):canvas.brush=value)
	restore.toggled.connect(func(value:bool):canvas.restore=value)
	solo.toggled.connect(func(value:bool):canvas.solo=value;canvas.queue_redraw())
	visible.toggled.connect(func(value:bool):if canvas.selected>=0:canvas.document.layers[canvas.selected].visible=value;canvas.queue_redraw())
	_layers.item_selected.connect(func(index:int):_choose_layer(index);visible.set_pressed_no_signal(bool(canvas.document.layers[index].visible)))
	_controls.item_selected.connect(func(index:int):canvas.selected_control=index;canvas.mode=1;mode.select(1);_select_control(index);canvas.queue_redraw())
	canvas.control_selected.connect(func(index:int):_controls.select(index);_select_control(index))
	canvas.edited.connect(func():_pending=true;_status.text="存在未保存修改。保存写入对应PNG / 界面布局，碰撞与底图不变。")
	_font.value_changed.connect(_change_font)
	_collect_ui_defaults()
	_documents=LayerArtCatalog.documents()
	for doc in _documents:_document_picker.add_item(doc.name)
	_saved_overrides=UiArtLayout.snapshot();canvas.overrides=_saved_overrides.duplicate(true)
	if not _documents.is_empty():_choose_document(0)
func _button(parent:Node,text:String,callback:Callable)->void:
	var button:=Button.new();button.text=text;button.pressed.connect(callback);parent.add_child(button)
func _collect_ui_defaults()->void:
	for script in ["res://src/ui/inventory_ui.gd","res://src/ui/shop_ui.gd","res://src/ui/tavern_ui.gd"]:
		var ui:Node=load(script).new();add_child(ui);ui.queue_free()
func _choose_document(index:int)->void:
	if _pending:_document_picker.select(_document_index);_status.text="请先保存当前修改，再切换图册。";return
	_document_index=index
	canvas.set_document(_documents[index]);_layers.clear();_controls.clear()
	for layer in canvas.document.layers:_layers.add_item(("[底图] " if layer.locked else "")+str(layer.name))
	for control in canvas.document.controls:_controls.add_item(str(control.caption))
	_status.text="左键擦除 / 恢复透明边缘，滚轮缩放，中键平移；界面布局模式下拖动标框。底图无法抠图。"
func _choose_layer(index:int)->void:
	if _pending:
		if canvas.selected>=0:_layers.select(canvas.selected)
		_status.text="请先保存当前精修，再切换图层。";return
	var error:=canvas.select_layer(index)
	_status.text=("底图已保护，只能查看。" if canvas.buffer.locked else "选中："+canvas.buffer.path+" · 可精修透明边缘") if error==OK else "图片读取失败："+error_string(error)
func _select_control(index:int)->void:
	var entry:Dictionary=canvas.document.controls[index];_font.set_value_no_signal(canvas.overrides.get(entry.id,{}).get("font_size",entry.font_size))
	_status.text="拖动："+str(entry.caption)+"。保存后重新打开对应界面即可应用。"
func _change_font(value:float)->void:
	if canvas.selected_control<0:return
	var entry:Dictionary=canvas.document.controls[canvas.selected_control];var data:Dictionary=canvas.overrides.get(entry.id,{}).duplicate(true);data.font_size=int(value);canvas.overrides[entry.id]=data;_pending=true;canvas.queue_redraw()
func _reset_control()->void:
	if canvas.selected_control<0:return
	canvas.overrides.erase(canvas.document.controls[canvas.selected_control].id);_pending=true;canvas.queue_redraw()
func _save()->void:
	if canvas.selected>=0 and not canvas.buffer.locked:
		var error:=canvas.buffer.save()
		if error!=OK:_status.text="图层保存失败："+error_string(error);return
	var error:=UiArtLayout.save(canvas.overrides)
	if error!=OK:_status.text="布局保存失败："+error_string(error);return
	_saved_overrides=canvas.overrides.duplicate(true);_pending=false;_status.text="已保存PNG精修及界面布局。PNG重新导入后用于游戏，布局重新开页生效。"
func _request_close()->void:
	if not _pending:queue_free();return
	var dialog:=ConfirmationDialog.new();dialog.dialog_text="仍有未保存的精修或布局，保存后关闭？";dialog.ok_button_text="保存并关闭";dialog.cancel_button_text="继续编辑";add_child(dialog);dialog.confirmed.connect(func():
		_save()
		if not _pending:queue_free())
	dialog.popup_centered()
func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.ctrl_pressed and event.keycode==KEY_S:_save();get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode==KEY_Z and canvas.mode==0:
		if event.shift_pressed:canvas.buffer.redo_stroke()
		else:canvas.buffer.undo_stroke()
		canvas.refresh_image();_pending=true;get_viewport().set_input_as_handled()
