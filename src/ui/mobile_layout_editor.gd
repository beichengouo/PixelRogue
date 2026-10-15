class_name MobileLayoutEditor
extends CanvasLayer
var draft:Dictionary={}
var selected:="move"
var area:=Rect2()
var _canvas:LayoutCanvas
var _toolbar:PanelContainer
var _feedback:Label
var _size:HSlider
var _choice:OptionButton
var _finger:=-1
var _last:=Vector2.ZERO
var _base:Dictionary={}
var _closing:=false
func _ready()->void:
	layer=76;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true)
	area=MobileControls.safe_rect();draft=MobileControlLayout.decode(SaveService.data.get("mobile_layout",{}),area);_base=draft.duplicate(true)
	_canvas=LayoutCanvas.new();_canvas.editor=self;_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_canvas)
	_toolbar=PanelContainer.new();_toolbar.theme=StarUi.theme();_toolbar.add_theme_stylebox_override("panel",StarUi.style(Color(.04,.08,.12,.95)));add_child(_toolbar)
	var body:=UiFactory.vbox(6);_toolbar.add_child(body)
	var row:=GridContainer.new();row.columns=5 if area.size.x>=760 else 2;row.add_theme_constant_override("h_separation",10);row.add_theme_constant_override("v_separation",6);body.add_child(row)
	_choice=OptionButton.new();_choice.custom_minimum_size=Vector2(130,52);row.add_child(_choice)
	for key in draft:_choice.add_item(_label(str(key)));_choice.set_item_metadata(_choice.item_count-1,key)
	_choice.item_selected.connect(func(index:int)->void:selected=str(_choice.get_item_metadata(index));_size.set_value_no_signal(100);_base[selected]=draft[selected];_canvas.queue_redraw())
	_size=HSlider.new();_size.min_value=60;_size.max_value=180;_size.step=5;_size.value=100;_size.custom_minimum_size=Vector2(160,52);row.add_child(_size)
	_size.value_changed.connect(_resize_control)
	for entry in [["保存布局",_save],["恢复默认",_reset],["取消",close]]:
		var button:=StarUi.button(str(entry[0]),17);button.pressed.connect(entry[1]);row.add_child(button)
	_feedback=StarUi.label("拖动调整位置；滑条调整大小。重叠或越界时无法保存。",15,Color.WHITE);_feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(_feedback)
	_toolbar.position=Vector2(area.get_center().x-minf(740,area.size.x-16)*.5,area.position.y+4);_toolbar.size=Vector2(minf(740,area.size.x-16),116)
	UIFlow.push_screen(self);MobileControls.reset()
	InteractionSkin.mount(_toolbar,"touch_layout",_toolbar)

func _label(key:String)->String:return "移动轮盘" if key=="move" else "攻击轮盘" if key=="aim" else str(MobileControls.LABELS.get(key,key))
func _resize_control(value:float)->void:
	var old:Rect2=draft[selected];var base:Rect2=_base[selected];var size:=base.size*value/100
	if selected in ["move","aim"]:size=Vector2.ONE*maxf(96,size.x)
	else:size=Vector2(maxf(48,size.x),maxf(48,size.y))
	draft[selected]=Rect2(old.get_center()-size*.5,size);_show_error()
func _show_error()->void:
	var message:=MobileControlLayout.error(draft,area);_feedback.text=message if not message.is_empty() else "布局有效；保存后立即应用。";_feedback.modulate=Color("ff8d8d") if not message.is_empty() else Color.WHITE;_canvas.queue_redraw()
func _reset()->void:
	draft=MobileControlLayout.defaults(area);_base=draft.duplicate(true);_size.set_value_no_signal(100);_show_error()
func _save()->void:
	var message:=MobileControlLayout.error(draft,area)
	if not message.is_empty():_show_error();return
	var before:Dictionary=SaveService.data.get("mobile_layout",{}).duplicate(true)
	SaveService.data.mobile_layout=MobileControlLayout.encode(draft,area)
	if not SaveService.save_data():SaveService.data.mobile_layout=before;_feedback.text="保存失败，原布局已保留。";return
	MobileControls.reset();close()
func close()->void:
	if _closing:return
	_closing=true;UIFlow.pop_screen(self);MobileControls.reset();queue_free()
func _input(event:InputEvent)->void:
	if not UIFlow.is_top(self):return
	if event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled();close();return
	var at:=Vector2.ZERO;var press:=false;var release:=false;var finger:=-2;var drag:=false
	if event is InputEventScreenTouch:at=event.position;press=event.pressed;release=not event.pressed;finger=event.index
	elif event is InputEventScreenDrag:at=event.position;finger=event.index;drag=true
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:at=event.position;press=event.pressed;release=not event.pressed;finger=-3
	elif event is InputEventMouseMotion and _finger== -3:at=event.position;finger=-3;drag=true
	else:return
	if _toolbar.get_global_rect().has_point(at) and _finger== -1:return
	if press and _finger== -1:
		for key in draft:
			if not (draft[key] as Rect2).has_point(at):continue
			selected=str(key);_base[selected]=draft[selected];_size.set_value_no_signal(100)
			for index in _choice.item_count:
				if _choice.get_item_metadata(index)==selected:_choice.select(index)
			_finger=finger;_last=at;break
	elif drag and finger==_finger:
		var box:Rect2=draft[selected];box.position+=at-_last;draft[selected]=box;_last=at;_show_error()
	elif release and finger==_finger:_finger=-1;_show_error()
	get_viewport().set_input_as_handled()
class LayoutCanvas extends Control:
	var editor:MobileLayoutEditor
	func _draw()->void:
		draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),Color(.015,.035,.055,.88))
		var font:=GameFonts.get_font()
		for key in editor.draft:
			var box:Rect2=editor.draft[key];var color:=Color("80dbaa") if key==editor.selected else Color("93afc7")
			draw_rect(box,Color(color,.12));draw_rect(box,color,false,3)
			if key in ["move","aim"]:draw_arc(box.get_center(),box.size.x*.5,0,TAU,64,color,3,true)
			var caption:=editor._label(key);var extent:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16)
			draw_string(font,box.get_center()+Vector2(-extent.x*.5,6),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
