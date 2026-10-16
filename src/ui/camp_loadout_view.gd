class_name CampLoadoutView
extends VBoxContainer
## Preparation is a reservation only. Warehouse stock changes at the gate.
signal equip_requested(id:String)
signal remove_requested(id:String)
signal selection_changed(id:String)
var loadout:Array=[]
var selected_id:=""
var initial_scroll:=0
var combat_mode:="rooms"
var quality:=-1
var _filter:="all"
var _grid:GridContainer
var _detail:Label
var _action:Button
var _records:Array[String]=[]
var _cells:Array[Button]=[]
var _grid_scroll:ScrollContainer
var _columns:HBoxContainer
var _stock:VBoxContainer
var _equipment:VBoxContainer

func _ready()->void:
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",10)
	_columns=UiFactory.hbox(20);add_child(_columns)
	_equipment=UiFactory.vbox(8);_equipment.custom_minimum_size.x=235;_columns.add_child(_equipment)
	_equipment.add_child(PixelUi.label("出发配装",21,PixelUi.GOLD))
	for slot in ItemDB.SLOTS:
		var id:=equipped_id(slot)
		var item:=Outpost.stored_item(id) if not id.is_empty() else {}
		var button:=PixelUi.button("%s · %s"%[{&"weapon":"武器",&"armor":"护甲",&"accessory":"饰品"}[slot],str(item.get("name","未装备"))],16,0,64)
		button.name="DepartureSlot_"+str(slot);button.set_meta("focus_token","departure_slot:"+str(slot));button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		if not item.is_empty():button.icon=_texture(item);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",36);button.set_meta("quality_slot",ItemDB.rarity_color(int(item.rarity)))
		button.tooltip_text="点击卸下" if not id.is_empty() else "从仓库选择对应部位的装备"
		button.pressed.connect(func()->void:
			if not id.is_empty():remove_requested.emit(id))
		_equipment.add_child(button)
	var potions:Dictionary={}
	for id in loadout:
		if ItemDB.is_usable(Outpost.stored_item(str(id))):potions[str(id)]=int(potions.get(str(id),0))+1
	var total:=0
	for count in potions.values():total+=int(count)
	_equipment.add_child(PixelUi.label("随行药剂 · %d / 15"%total,18,PixelUi.GOLD))
	for id:String in potions:
		var item:=Outpost.stored_item(id)
		var button:=PixelUi.compact_button("%s ×%d  −"%[str(item.name),int(potions[id])],16);button.icon=_texture(item);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",28)
		button.set_meta("focus_token","departure_potion:"+id);button.tooltip_text="点击移出一瓶";button.pressed.connect(func()->void:remove_requested.emit(id));_equipment.add_child(button)
	_stock=UiFactory.vbox(8);_stock.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_columns.add_child(_stock)
	_stock.add_child(PixelUi.label("仓库库存",21,PixelUi.GOLD))
	var filters:=UiFactory.hbox(6);_stock.add_child(filters)
	for entry in [["全部","all"],["武器","weapon"],["护甲","armor"],["饰品","accessory"],["药剂","potion"]]:
		var button:=PixelUi.tab_button(entry[0],false,16);filters.add_child(button)
		button.pressed.connect(func()->void:_filter=str(entry[1]);_populate())
		button.set_meta("loadout_filter",entry[1])
	_grid_scroll=ScrollContainer.new();_grid_scroll.custom_minimum_size.y=180;_grid_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;_grid_scroll.follow_focus=true;_stock.add_child(_grid_scroll)
	_grid=GridContainer.new();_grid.columns=7;_grid.add_theme_constant_override("h_separation",6);_grid.add_theme_constant_override("v_separation",6);_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_grid_scroll.add_child(_grid)
	_stock.resized.connect(func()->void:_grid.columns=maxi(1,floori(maxf(66,_stock.size.x)/72)))
	_detail=PixelUi.label("选择仓库物品查看详情",17);_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(_detail)
	_action=PixelUi.compact_button("装备所选",17);add_child(_action);_action.pressed.connect(_activate_selected)
	resized.connect(_resize_columns)
	_populate();_resize_columns.call_deferred();_restore_scroll.call_deferred()
func _restore_scroll()->void:
	if not is_inside_tree() or is_queued_for_deletion():return
	await get_tree().process_frame
	if is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(_grid_scroll):_grid_scroll.scroll_vertical=initial_scroll

func equipped_id(slot:StringName)->String:
	for id in loadout:
		if ItemDB.slot_of(Outpost.stored_item(str(id)))==slot:return str(id)
	return ""

func _populate()->void:
	for button in _stock.find_children("*","Button",true,false):
		if button.has_meta("loadout_filter"):button.set_meta("interaction_selected",str(button.get_meta("loadout_filter"))==_filter);InteractionSkin.apply_button(button,"camp_loadout")
	for cell in _grid.get_children():_grid.remove_child(cell);cell.queue_free()
	_cells.clear();_records.clear()
	for id in Outpost.data.inventory:
		var item:=Outpost.stored_item(str(id));var count:=int(Outpost.data.inventory[id])
		if count<=0 or not (ItemDB.is_equippable(item) or ItemDB.is_usable(item)) or not ItemDB.available_in_mode(item,combat_mode):continue
		if quality>=0 and int(item.get("rarity",0))!=quality:continue
		if _filter!="all" and str(item.get("kind",""))!=_filter:continue
		_records.append(str(id))
	_records.sort_custom(func(a:String,b:String)->bool:
		var left:=Outpost.stored_item(a);var right:=Outpost.stored_item(b)
		if int(left.rarity)!=int(right.rarity):return int(left.rarity)>int(right.rarity)
		return str(left.name)<str(right.name))
	for id in _records:
		var item:=Outpost.stored_item(id);var selected:=loadout.count(id)
		var button:=PixelUi.compact_button("",15);button.custom_minimum_size=Vector2(66,66);button.icon=_texture(item);button.expand_icon=true;button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;button.add_theme_constant_override("icon_max_width",40)
		button.set_meta("quality_slot",ItemDB.rarity_color(int(item.get("rarity",0))));button.set_meta("focus_token","camp_item:"+id);button.set_meta("interaction_selected",selected_id==id)
		button.tooltip_text=str(item.name)+"\n"+str(item.desc);_grid.add_child(button);_cells.append(button)
		var count:=PixelUi.label("×%d"%int(Outpost.data.inventory[id]),13);count.mouse_filter=Control.MOUSE_FILTER_IGNORE;count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);count.offset_top=-20;count.offset_right=-4;count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;button.add_child(count)
		var mark:=PixelUi.label("已装" if selected>0 and ItemDB.is_equippable(item) else "选%d"%selected if selected>0 else "绑" if ItemDB.is_equippable(item) else "",12,PixelUi.GOLD);mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;mark.position=Vector2(4,3);button.add_child(mark)
		button.pressed.connect(func()->void:_select(id))
		button.focus_entered.connect(_select.bind(id))
		button.gui_input.connect(func(event:InputEvent)->void:
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.double_click:button.accept_event();_select(id);_activate_selected()
			elif event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("ui_accept"):button.accept_event();_select(id);_activate_selected())
		InteractionSkin.apply_button(button,"camp_loadout")
	if not _records.has(selected_id):selected_id=_records[0] if not _records.is_empty() else ""
	_update_detail()

func _select(id:String)->void:
	selected_id=id;selection_changed.emit(id)
	for index in _cells.size():_cells[index].set_meta("interaction_selected",_records[index]==id);InteractionSkin.apply_button(_cells[index],"camp_loadout")
	_update_detail()

func _update_detail()->void:
	var item:=Outpost.stored_item(selected_id) if not selected_id.is_empty() else {}
	if item.is_empty():_detail.text="仓库中暂无可携带的装备或药剂。";_action.hide();return
	var wearing:=ItemDB.is_equippable(item) and loadout.has(selected_id)
	var available:=int(Outpost.data.inventory.get(selected_id,0))-loadout.count(selected_id)
	_detail.text="%s · %s · 库存%d · 已选%d\n%s\n%s"%[str(item.name),ItemDB.rarity_name(int(item.rarity)),int(Outpost.data.inventory.get(selected_id,0)),loadout.count(selected_id)," / ".join(ItemDB.stat_lines(item)),str(item.desc)]
	if BoundEquipment.is_bound(item):_detail.text+="\n"+BoundEquipment.description()
	_detail.text+="\n\n"+ItemDB.flavor_text(item)
	if not ItemDB.can_equip(item):_detail.text+="\n当前角色无法装备。"
	_action.show();_action.text="卸下装备" if wearing else "携带一瓶" if ItemDB.is_usable(item) else "装备所选"
	_action.disabled=not ItemDB.can_equip(item) or (not wearing and available<=0)
	_action.tooltip_text="当前角色无法装备" if not ItemDB.can_equip(item) else "库存已全部加入携带清单" if not wearing and available<=0 else "卸下不会减少库存" if wearing else "加入准备清单，出发时才扣库存"
	_action.set_meta("focus_token","camp_loadout_action")

func _activate_selected()->void:
	if _action.disabled or selected_id.is_empty():return
	var item:=Outpost.stored_item(selected_id)
	if ItemDB.is_equippable(item) and loadout.has(selected_id):remove_requested.emit(selected_id)
	else:equip_requested.emit(selected_id)

func _resize_columns()->void:
	if _grid==null:return
	# The enclosing preparation scroll handles short windows; portrait mobile
	# stacks both blocks rather than squeezing labels and equipment slots.
	var narrow:=size.x<620
	if narrow and _equipment.get_parent()==_columns:
		_columns.remove_child(_equipment);add_child(_equipment);move_child(_equipment,0)
	elif not narrow and _equipment.get_parent()==self:
		remove_child(_equipment);_columns.add_child(_equipment);_columns.move_child(_equipment,0)
	_grid.columns=maxi(1,floori(maxf(66,_stock.size.x)/72))

func _texture(item:Dictionary)->Texture2D:
	var texture:=ItemDB.icon_texture(item)
	if texture==null:return null
	var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=ItemDB.icon_region(item);atlas.filter_clip=true;return atlas
