class_name FateUI
extends CanvasLayer
signal constellation_selected(id:String)
signal story_requested
var _root:Control
var _body:VBoxContainer
var _title:Label
var _choice:FateChoiceUI
var _room:Dictionary={}
var _star:=""
var _mode:=""
func _ready()->void:
	layer=40;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true);set_meta("show_previous_screen",true)
	_root=UiFactory.full_rect();add_child(_root);_root.add_child(UiFactory.dim_layer(.68))
	var frame:=StarUi.frame(_root,Vector2(1080,740));var column:=UiFactory.vbox(12);frame.add_child(column);column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);column.offset_left=24;column.offset_right=-24;column.offset_top=22;column.offset_bottom=-22
	_title=PixelUi.title("星象与命运",30);column.add_child(_title)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	_body=UiFactory.vbox(14);_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(_body)
	var close_button:=PixelUi.button("关闭",20,0,48);column.add_child(close_button);close_button.pressed.connect(close)
	InteractionSkin.mount(_root,"fate",frame);_root.hide()
	_choice=FateChoiceUI.new();add_child(_choice)
func is_open()->bool:return (is_instance_valid(_root) and _root.visible) or (is_instance_valid(_choice) and _choice.is_open())
func _show(mode:String)->void:
	_mode=mode;_root.show();UIFlow.push_screen(self);_refresh()
func close()->void:
	if not is_open():return
	if _choice.is_open():_choice.cancel()
	_root.hide();UIFlow.pop_screen(self)
func open_altar(room:Dictionary)->void:
	if is_open() or not FateService.eligible(room):return
	_room=room
	var reading:Dictionary=room.delta.get("fate_reading",{})
	if reading.is_empty():reading=FateService.draw(room)
	if reading.has("error") or bool(reading.get("done",false)):return
	_choice.open_reading(room)
func open_stars(selected:String)->void:
	if is_open():return
	_star=selected;_show("stars")
func open_forecast()->void:
	if is_open():return
	_show("forecast")
func _text(value:String,size:=19,color:=Color("eaf1f6"))->void:
	var label:=PixelUi.label(value,size,color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_body.add_child(label)
func _button(text:String,callback:Callable,parent:Node=null)->Button:
	var button:=PixelUi.button(text,19,0,46);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;(parent if parent!=null else _body).add_child(button);button.set_meta("focus_token",text);button.pressed.connect(callback);InteractionSkin.apply_button(button,"fate");return button
func _refresh()->void:
	var focus:=get_viewport().gui_get_focus_owner();var token:=str(focus.get_meta("focus_token","")) if focus!=null and _root.is_ancestor_of(focus) else ""
	for child in _body.get_children():_body.remove_child(child);child.queue_free()
	if _mode=="stars":_stars()
	elif _mode=="forecast":_title.text="星象预告";_text(FateForecast.describe(),21)

	InteractionSkin.apply_tree(_body,"fate")
	PixelUi.focus_button.call_deferred(_root,token)
func _art(id:String,parent:Node,reverse:=false)->void:
	var image:=TextureRect.new();image.custom_minimum_size=Vector2(150,225);image.size_flags_horizontal=Control.SIZE_EXPAND_FILL;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(FateCatalog.art(id,reverse)):image.texture=load(FateCatalog.art(id,reverse))
	parent.add_child(image)
func _stars()->void:
	_title.text="出发星象 · "+str(FateCatalog.STARS.get(_star,{}).get("name","不选择"))
	_text("免费选择一种星象，仅在正式出征生效；更换后需重新确认出发。三种星象均能观测既有邻接房间的部署。")
	var row:=UiFactory.hbox(18);_body.add_child(row)
	for id:String in FateCatalog.STARS:
		var column:=UiFactory.vbox(10);column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(column);_art(id,column)
		var info:Dictionary=FateCatalog.STARS[id];var label:=PixelUi.label(str(info.description),18);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(label)
		var button:=_button(str(info.name)+(" · 已选" if _star==id else ""),func()->void:_star=id;constellation_selected.emit(id);_refresh(),column);button.set_meta("interaction_selected",_star==id)
	_button("不选择星象",func()->void:_star="";constellation_selected.emit("");_refresh())
	_button("聆听伊莉丝解读",func()->void:close();story_requested.emit())
func _input(event:InputEvent)->void:
	if is_open() and UIFlow.is_top(self) and not event.is_echo() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		close();get_viewport().set_input_as_handled()
