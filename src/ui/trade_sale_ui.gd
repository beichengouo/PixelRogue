class_name TradeSaleUI
extends CanvasLayer
var _root: Control
var _list: VBoxContainer
var _status: Label
var _guard := 0
var _selected_index=0
var _confirm:SaleConfirmUI
var _pending_sale:Array=[]

func _ready() -> void:
	layer=26
	process_mode=Node.PROCESS_MODE_ALWAYS
	_root=UiFactory.full_rect()
	_root.theme=PixelUi.theme()
	add_child(_root)
	_root.add_child(UiFactory.dim_layer(0.42))
	var frame:=StarUi.frame(_root,Vector2(760,570))
	var panel:=PixelUi.panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(panel)
	var box:=UiFactory.vbox(12)
	panel.add_child(box)
	box.add_child(PixelUi.title("出售行囊物资",28))
	_status=PixelUi.label("",17,PixelUi.GOLD)
	box.add_child(_status)
	var scroll:=ScrollContainer.new()
	scroll.follow_focus=true
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list=UiFactory.vbox(8)
	_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var close_button:=PixelUi.compact_button("返回",18)
	close_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(close)
	box.add_child(close_button)
	InteractionSkin.apply_tree(_root,"shop")
	_root.visible=false
	InteractionSkin.mount(_root,"trade",panel)

func open() -> void:
	_guard=Time.get_ticks_msec()+150
	_root.visible=true
	UIFlow.push_screen(self)
	_refresh()

func close() -> void:
	_pending_sale.clear()
	if is_instance_valid(_confirm):_confirm.close()
	_root.visible=false
	UIFlow.pop_screen(self)

func _input(event: InputEvent) -> void:
	if _root.visible and UIFlow.is_top(self) and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		close()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	var focus=get_viewport().gui_get_focus_owner()
	if focus!=null and _list.is_ancestor_of(focus): _selected_index=int(focus.get_meta("sale_index",_selected_index))
	for child in _list.get_children():_list.remove_child(child);child.queue_free()
	_status.text="随身 %d 金 · 出售物证会影响委托进度 · 装备按基础价50%%出售" % GameState.coins
	var count:=0
	var groups: Array = []
	var heads: Dictionary = {}
	for item in GameState.items:
		var value:=ExpeditionData.sale_value(item)
		if value<=0: continue
		var key=str(item.id)+":"+str(value)+("|bound" if BoundEquipment.is_bound(item) else "|ordinary")
		var limit=ExpeditionData.stack_limit(item)
		if not heads.has(key) or heads[key].size()>=limit:
			var batch: Array=[item]
			heads[key]=batch
			groups.append(batch)
		else: heads[key].append(item)
	for batch in groups:
		var item: Dictionary=batch[0]
		var value=ExpeditionData.sale_value(item)*batch.size()
		count+=1
		var row:=UiFactory.hbox(12)
		var icon:=UiFactory.item_icon(item,36)
		row.add_child(icon)
		BoundEquipment.badge(icon,item)
		var name:=PixelUi.label(str(item.name)+(" ×%d" % batch.size() if batch.size()>1 else ""),18,ItemDB.rarity_color(int(item.rarity)))
		name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var b:=PixelUi.compact_button("出售 +%d金"%value,17)
		b.custom_minimum_size.x=150
		b.set_meta("sale_index",count-1)
		b.pressed.connect(_sell_stack.bind(batch))
		row.add_child(b)
		_list.add_child(row)
	if count==0:_list.add_child(PixelUi.label("没有可出售的物品。已装备物品需先卸下。",18))
	InteractionSkin.apply_tree(_root,"shop")
	_restore_sale_focus.call_deferred()

func _sell(item: Dictionary) -> void:
	_sell_stack([item])
func _sell_stack(items: Array) -> void:
	if Time.get_ticks_msec()<_guard or not UIFlow.is_top(self): return
	_guard=Time.get_ticks_msec()+150
	if items.any(func(item:Dictionary)->bool:return BoundEquipment.is_bound(item)):
		if not is_instance_valid(_confirm):
			_confirm=SaleConfirmUI.new();_confirm.title_text="出售绑定装备？";add_child(_confirm)
			_confirm.confirmed.connect(func()->void:
				var pending:=_pending_sale.duplicate();_pending_sale.clear()
				if _root.visible:_commit_sale(pending))
			_confirm.canceled.connect(func()->void:_pending_sale.clear())
		_pending_sale=items.duplicate()
		var rows:PackedStringArray=[];var total:=0
		for item in items:rows.append(str(item.name));total+=ExpeditionData.sale_value(item)
		_confirm.open("%s\n数量：%d件 · 出售收益：%d 金\n\n这些装备已绑定，成功撤离原本可以原件入库。确认后将出售。"%["、".join(rows),items.size(),total]);return
	_commit_sale(items)
func _commit_sale(items:Array)->void:
	var sold:=false
	for item in items:
		if GameState.sell_item(item):sold=true
	if sold:
		AudioManager.play(&"coin",-6);_refresh()

func _restore_sale_focus() -> void:
	if not _root.visible: return
	if _list.get_child_count()>0:
		var row=_list.get_child(clampi(_selected_index,0,_list.get_child_count()-1))
		for button in row.find_children("*","Button",true,false):
			button.grab_focus()
			return
	PixelUi.focus_button(_root)
