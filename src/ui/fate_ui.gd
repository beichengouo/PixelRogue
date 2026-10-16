class_name FateUI
extends CanvasLayer
signal constellation_selected(id:String)
signal story_requested
var _root:Control
var _body:VBoxContainer
var _title:Label
var _confirm:GlassConfirmUI
var _action:Callable
var _room:Dictionary={}
var _selected:=""
var _reverse:=false
var _replace:=""
var _star:=""
var _error:=""
var _mode:=""
var _busy:=false
func _ready()->void:
	layer=40;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true);set_meta("show_previous_screen",true)
	_root=UiFactory.full_rect();add_child(_root);_root.add_child(UiFactory.dim_layer(.68))
	var frame:=StarUi.frame(_root,Vector2(1080,740));var column:=UiFactory.vbox(12);frame.add_child(column);column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);column.offset_left=24;column.offset_right=-24;column.offset_top=22;column.offset_bottom=-22
	_title=PixelUi.title("星象与命运",30);column.add_child(_title)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	_body=UiFactory.vbox(14);_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(_body)
	var close_button:=PixelUi.button("关闭",20,0,48);column.add_child(close_button);close_button.pressed.connect(close)
	InteractionSkin.mount(_root,"fate",frame);_root.hide()
	_confirm=GlassConfirmUI.new();add_child(_confirm);_confirm.confirmed.connect(func()->void:if _action.is_valid():_action.call())
func is_open()->bool:return is_instance_valid(_root) and _root.visible
func _show(mode:String)->void:
	_mode=mode;_root.show();UIFlow.push_screen(self);_refresh()
func close()->void:
	if not is_open():return
	_confirm.close();_root.hide();UIFlow.pop_screen(self)
func open_altar(room:Dictionary)->void:
	if is_open() or not FateService.eligible(room):return
	_room=room;_selected="";_reverse=false;_replace="";_error=""
	var reading:Dictionary=room.delta.get("fate_reading",{})
	if reading.is_empty():reading=FateService.draw(room)
	_error=str(reading.get("error",""));_show("altar")
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
	else:_altar()
	InteractionSkin.apply_tree(_body,"fate")
	PixelUi.focus_button.call_deferred(_root,token)
func _art(id:String,parent:Node,reverse:=false)->void:
	var image:=TextureRect.new();image.custom_minimum_size=Vector2(150,225);image.size_flags_horizontal=Control.SIZE_EXPAND_FILL;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(FateCatalog.art(id)):image.texture=load(FateCatalog.art(id))
	parent.add_child(image)
	if reverse:
		image.resized.connect(func()->void:image.pivot_offset=image.size*.5);image.rotation=PI
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
func _altar()->void:
	_title.text="命运祭坛 · 占卜 %d／3 · 持牌 %d／2"%[int(GameState.fate.readings),GameState.fate.cards.size()]
	_text("选择正位或逆位。逆位拥有更强收益，也须承担公开的代价。关闭保留本次候选，明确放弃才结束本祭坛占卜。",18)
	if not _error.is_empty():_text(_error,18,Color("e9bd85"))
	var owned:=UiFactory.hbox(12);_body.add_child(owned)
	for card in GameState.fate.cards:
		var id:=str(card.id)
		_button("舍弃 · "+str(FateCatalog.CARDS[id].name)+("（逆位）" if card.reverse else "（正位）"),func()->void:_ask("舍弃命运牌", "将失去：\n"+FateCatalog.description(id,bool(card.reverse)),func()->void:_mutate(FateService.discard.bind(_room,id))),owned)
	var reading:Dictionary=_room.delta.get("fate_reading",{})
	if reading.is_empty() or bool(reading.get("done",false)):
		_text("本祭坛占卜已结束。仍可在这里舍弃已有命运牌。" if not reading.is_empty() else "本次出征没有剩余占卜次数。")
		return
	var row:=UiFactory.hbox(18);_body.add_child(row)
	for value in reading.get("offers",[]):
		var id:=str(value);var column:=UiFactory.vbox(8);column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(column);_art(id,column,_reverse and _selected==id)
		var button:=_button(str(FateCatalog.CARDS[id].name),func()->void:_selected=id;_refresh(),column);button.set_meta("interaction_selected",_selected==id)
	if not _selected.is_empty():
		var orientation:=UiFactory.hbox(12);_body.add_child(orientation)
		for reversed in [false,true]:
			var button:=_button("逆位" if reversed else "正位",func()->void:_reverse=reversed;_refresh(),orientation);button.set_meta("interaction_selected",reversed==_reverse)
		_text(FateCatalog.description(_selected,_reverse),20)
		if GameState.fate.cards.size()>=2:
			var options:=OptionButton.new();options.add_item("选择将被替换的命运牌")
			for card in GameState.fate.cards:options.add_item(str(FateCatalog.CARDS[str(card.id)].name)+(" · 逆位" if card.reverse else " · 正位"))
			options.select(0)
			for i in GameState.fate.cards.size():
				if str(GameState.fate.cards[i].id)==_replace:options.select(i+1)
			options.item_selected.connect(func(index:int)->void:_replace=str(GameState.fate.cards[index-1].id) if index>0 else "";_refresh());_body.add_child(options)
		var take:=_button("缔结 · "+str(FateCatalog.CARDS[_selected].name),_claim)
		take.disabled=GameState.fate.cards.size()>=2 and _replace.is_empty();take.tooltip_text="先选择要替换的命运牌。" if take.disabled else ""
	_button("放弃本次占卜",func()->void:_ask("放弃本次占卜","本祭坛将不再提供新的候选；已有命运牌不受影响。",func()->void:_mutate(FateService.pass_reading.bind(_room))))
func _ask(title:String,message:String,action:Callable)->void:
	_action=action;_confirm.title=title;_confirm.dialog_text=message;_confirm.popup_centered()
func _claim()->void:
	var lost:=""
	for card in GameState.fate.cards:
		if str(card.id)==_replace:lost="\n将失去："+str(FateCatalog.CARDS[_replace].name)+"\n"+FateCatalog.description(_replace,bool(card.reverse))
	_ask("缔结命运 · "+("逆位" if _reverse else "正位"),FateCatalog.description(_selected,_reverse)+lost,func()->void:_mutate(FateService.claim.bind(_room,_selected,_reverse,_replace)))
func _mutate(action:Callable)->void:
	if _busy:return
	_busy=true;var ok:=bool(action.call());_busy=false;_error="" if ok else "保存失败或状态已变化，本次操作未提交，请重试。";_selected="" if ok else _selected;_refresh()
func _input(event:InputEvent)->void:
	if is_open() and UIFlow.is_top(self) and not event.is_echo() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		close();get_viewport().set_input_as_handled()
