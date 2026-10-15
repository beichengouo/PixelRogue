class_name WarehouseView
extends VBoxContainer
signal status_changed(message:String)
var _filter="all"
var _page=0
var _selected=""
var _records:Array=[]
var _cells:Array[Button]=[]
var _mushrooms:Array[Button]=[]
var _grid:GridContainer
var _detail:Label
var _detail_quality:RarityWordmark
var _quantity:SpinBox
var _sell:Button
var _expand:Button
var _capacity:Label
var _pager:Label
var _previous:Button
var _next:Button
var _message:Label
var _filters:Array[Button]=[]
var extra_reserves:Dictionary={}
var _search:LineEdit
var _sort:OptionButton
var _lock:Button
var _batch:Button
var _batch_quality:OptionButton
var _batch_dialog:SaleConfirmUI
var _pending_plan:Dictionary={}
const PAGE_SIZE=60
func _ready()->void:
	add_theme_constant_override("separation",10)
	_message=PixelUi.label("",16,PixelUi.GOLD);add_child(_message)
	status_changed.connect(func(message:String)->void:_message.text=message)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var heading=UiFactory.hbox(10);add_child(heading)
	_capacity=PixelUi.label("",19,PixelUi.GOLD);_capacity.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(_capacity)
	_expand=PixelUi.compact_button("",17);heading.add_child(_expand)
	_expand.pressed.connect(func()->void:
		status_changed.emit("扩容成功 · 增加10格" if Outpost.expand_warehouse() else "金币不足或保存失败，未扣款")
		refresh())
	var filters=UiFactory.hbox(8);add_child(filters)
	for entry in [["全部","all"],["装备","gear"],["药剂","potion"],["材料","material"],["蘑菇","mushroom"]]:
		var b=PixelUi.tab_button(entry[0],false,17);filters.add_child(b)
		_filters.append(b)
		b.set_meta("filter",entry[1]);b.pressed.connect(func()->void:_filter=entry[1];_page=0;refresh())
	var toolbar=UiFactory.hbox(8);add_child(toolbar)
	_search=LineEdit.new();_search.placeholder_text="搜索名称或效果";_search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;toolbar.add_child(_search)
	_search.text_changed.connect(func(_text:String)->void:_page=0;refresh())
	_sort=OptionButton.new();toolbar.add_child(_sort)
	_compact_option(_sort)
	for title in ["排序：名称","排序：品质","排序：价值"]:_sort.add_item(title)
	_sort.item_selected.connect(func(_index:int)->void:_page=0;refresh())
	_batch_quality=OptionButton.new();toolbar.add_child(_batch_quality)
	_compact_option(_batch_quality)
	for title in ["出售普通","出售普通/精良","出售全部品质"]:_batch_quality.add_item(title)
	_batch_quality.select(1)
	_batch=PixelUi.compact_button("批量出售预览",16);toolbar.add_child(_batch);_batch.pressed.connect(_preview_batch)
	_batch.set_meta("focus_token","warehouse_batch")
	var note=PixelUi.label("批量整理当前分类与搜索结果；保留保护锁、委托、配装与准备清单所需库存，蘑菇仅手动出售。",14,PixelUi.MUTED);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(note)
	var row=UiFactory.hbox(18);add_child(row)
	_grid=GridContainer.new();_grid.columns=10;_grid.add_theme_constant_override("h_separation",6);_grid.add_theme_constant_override("v_separation",6)
	_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(_grid)
	for i in PAGE_SIZE:
		var b=PixelUi.compact_button("",14);b.custom_minimum_size=Vector2(68,68);b.expand_icon=true;b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;b.add_theme_constant_override("icon_max_width",40)
		b.pressed.connect(_select.bind(i));_grid.add_child(b);_cells.append(b)
		var count=PixelUi.label("",14);count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);count.offset_top=-21;count.offset_right=-4;count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;count.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(count);b.set_meta("count_label",count)
		var mark=PixelUi.label("",12,PixelUi.GOLD);mark.position=Vector2(4,3);mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(mark);b.set_meta("mark_label",mark)
	var detail=UiFactory.vbox(10);detail.custom_minimum_size.x=250;row.add_child(detail)
	_detail_quality=RarityWordmark.make(0,36);_detail_quality.visible=false;detail.add_child(_detail_quality)
	_detail=PixelUi.label("选择一个物品查看详情",18);_detail.custom_minimum_size.x=240;_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_child(_detail)
	_quantity=SpinBox.new();_quantity.min_value=1;_quantity.step=1;_quantity.prefix="出售数量 ";detail.add_child(_quantity)
	MobileControls.decorate_number(_quantity)
	_sell=PixelUi.compact_button("出售所选物品",17);detail.add_child(_sell)
	_sell.set_meta("focus_token","warehouse_sell")
	_sell.pressed.connect(func()->void:
		status_changed.emit("出售成功" if Outpost.sell_stored(_selected,int(_quantity.value),extra_reserves) else "库存已变化、物品受保护或保存失败，物品保留")
		refresh())
	_lock=PixelUi.compact_button("保护此道具",16);detail.add_child(_lock)
	_lock.set_meta("focus_token","warehouse_lock")
	_lock.pressed.connect(func()->void:
		status_changed.emit("保护状态已保存" if Outpost.set_locked(_selected,not Outpost.is_locked(_selected)) else "保存失败，保护状态未变")
		refresh())
	var nav=UiFactory.hbox(8);add_child(nav)
	_previous=PixelUi.compact_button("上一页",16);nav.add_child(_previous);_previous.pressed.connect(func()->void:_page=maxi(0,_page-1);refresh())
	_pager=PixelUi.label("",16);nav.add_child(_pager)
	_next=PixelUi.compact_button("下一页",16);nav.add_child(_next);_next.pressed.connect(func()->void:_page+=1;refresh())
	add_child(PixelUi.label("蘑菇收藏 · 不占仓库容量 · 每种最多999",17,PixelUi.GOLD))
	var mushrooms=UiFactory.hbox(8);add_child(mushrooms)
	for i in ItemDB.mushroom_count():
		var b=PixelUi.compact_button("",15);b.custom_minimum_size=Vector2(110,64);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",36);mushrooms.add_child(b);_mushrooms.append(b)
		b.pressed.connect(func()->void:_selected="glow_mushroom_%d" % i;_refresh_detail())
	_batch_dialog=SaleConfirmUI.new();add_child(_batch_dialog)
	_batch_dialog.confirmed.connect(func()->void:
		var plan=_pending_plan;_pending_plan={}
		_batch.grab_focus()
		status_changed.emit("批量出售成功 · +%d金 · 释放%d格" % [int(plan.get("gold",0)),int(plan.get("slots_freed",0))] if Outpost.sell_batch(plan) else "清单已变化或保存失败，未出售，请重新预览")
		refresh())
	_batch_dialog.canceled.connect(func()->void:_pending_plan={})
	refresh()
func refresh()->void:
	if _grid==null:return
	for b in _filters:PixelUi.apply_tab_style(b,str(b.get_meta("filter"))==_filter)
	var used=Outpost.warehouse_slots()
	var capacity=Outpost.warehouse_capacity()
	_capacity.text="仓库 %d / %d 格%s" % [used,capacity," · 超量！出发前请出售、交付或扩容" if used>capacity else ""]
	_capacity.add_theme_color_override("font_color",Palette.UI_DANGER if used>capacity else PixelUi.GOLD)
	_expand.text="扩容 +10格 · %d金" % Outpost.expansion_cost();_expand.disabled=Outpost.expansion_cost()>Outpost.gold()
	_records.clear()
	var search=_search.text.strip_edges().to_lower()
	var reserves=Outpost.reserved_counts(extra_reserves)
	var task_needs=Outpost.task_reserves()
	var physical=0
	for id in Outpost.data.inventory:
		var count=maxi(0,int(Outpost.data.inventory[id]))
		if count==0 or str(id).begins_with("glow_mushroom_"):continue
		var item=ExpeditionData.resolve(str(id))
		var limit=1 if ItemDB.is_equippable(item) else 999
		while count>0:
			var record={"id":str(id),"count":mini(limit,count),"index":physical}
			var match_filter=_filter=="all" or (_filter=="gear" and ItemDB.is_equippable(item)) or (_filter=="potion" and ItemDB.is_usable(item)) or (_filter=="material" and ItemDB.is_material(item))
			if match_filter and (search.is_empty() or (str(item.get("name",id))+" "+str(item.get("desc",""))).to_lower().contains(search)):_records.append(record)
			count-=limit;physical+=1
	_records.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		var x=ExpeditionData.resolve(a.id);var y=ExpeditionData.resolve(b.id)
		if _sort.selected==1 and int(x.get("rarity",0))!=int(y.get("rarity",0)):return int(x.get("rarity",0))>int(y.get("rarity",0))
		if _sort.selected==2 and ExpeditionData.sale_value(x)!=ExpeditionData.sale_value(y):return ExpeditionData.sale_value(x)>ExpeditionData.sale_value(y)
		return str(x.get("name",a.id))<str(y.get("name",b.id)))
	var total=maxi(1,ceili(float(maxi(_records.size(),capacity if _filter=="all" else 1))/PAGE_SIZE))
	_page=clampi(_page,0,total-1)
	var visible_count=mini(PAGE_SIZE,maxi(_records.size(),capacity) -_page*PAGE_SIZE) if _filter=="all" else mini(PAGE_SIZE,maxi(1,_records.size()-_page*PAGE_SIZE))
	if _filter=="mushroom":visible_count=0
	for i in _cells.size():
		var b=_cells[i];b.visible=i<visible_count
		var index=_page*PAGE_SIZE+i
		b.icon=null;b.text="";b.tooltip_text="空仓位";b.disabled=index>=_records.size()
		if index<_records.size():
			var record=_records[index];var item=ExpeditionData.resolve(record.id)
			b.icon=_texture(item);(b.get_meta("count_label") as Label).text="×%d" % int(record.count);b.tooltip_text=str(item.get("name",record.id))+"\n"+str(item.get("desc",""));b.disabled=false
			(b.get_meta("mark_label") as Label).text=("绑 " if ItemDB.is_equippable(item) else "")+("锁" if Outpost.is_locked(record.id) else ("委" if task_needs.has(record.id) else ("配" if int(reserves.get(record.id,0))>0 else "")))
			b.add_theme_stylebox_override("normal",PixelUi.style(PixelUi.NIGHT,PixelUi.GOLD if _selected==record.id else (Palette.UI_DANGER if int(record.index)>=capacity else ItemDB.rarity_color(int(item.get("rarity",0)))),2,4,2))
		else:
			(b.get_meta("count_label") as Label).text=""
			(b.get_meta("mark_label") as Label).text=""
			b.add_theme_stylebox_override("disabled",PixelUi.style(Color("152432"),PixelUi.LINE,2,4,1))
	_pager.text="%d / %d 页" % [_page+1,total];_previous.disabled=_page==0;_next.disabled=_page>=total-1
	for i in _mushrooms.size():
		var item=ItemDB.mushroom_item(i);var b=_mushrooms[i]
		b.icon=_texture(item);b.text="×%d%s" % [int(Outpost.data.inventory.get(str(item.id),0))," 锁" if Outpost.is_locked(str(item.id)) else ""];b.tooltip_text=str(item.name)+"\n"+str(item.desc)
		b.visible=search.is_empty() or (str(item.name)+str(item.desc)).to_lower().contains(search)
	if int(Outpost.data.inventory.get(_selected,0))<=0:
		_selected=str(_records[mini(_records.size()-1,_page*PAGE_SIZE)].id) if not _records.is_empty() else ""
	_refresh_detail()
func _select(index:int)->void:
	var actual=_page*PAGE_SIZE+index
	if actual>=_records.size():return
	_selected=str(_records[actual].id);refresh()
func _texture(item:Dictionary)->Texture2D:
	var tex=ItemDB.icon_texture(item)
	if item.get("icon",{}).has("rect"):
		var atlas=AtlasTexture.new();atlas.atlas=tex;atlas.region=ItemDB.icon_region(item);return atlas
	return tex
func _refresh_detail()->void:
	var item=ExpeditionData.resolve(_selected)
	if ItemDB.is_equippable(item):item=BoundEquipment.from_camp(item)
	var count=int(Outpost.data.inventory.get(_selected,0))
	var price=ExpeditionData.sale_value(item)
	_detail_quality.visible=not item.is_empty()
	if not item.is_empty():_detail_quality.set_quality(int(item.rarity))
	_detail.text="选择物品查看详情" if item.is_empty() else "%s\n\n%s\n\n仓库数量 %d%s" % [str(item.name),str(item.desc),count,"\n出售单价 %d 金" % price if price>0 else "\n兑换材料 · 保留用于兑换"]
	if BoundEquipment.is_bound(item):_detail.text+="\n"+BoundEquipment.description()
	var allowed=Outpost.sellable_count(_selected,extra_reserves)
	var reserved=mini(count,int(Outpost.reserved_counts(extra_reserves).get(_selected,0)))
	if count>0:
		_detail.text+="\n%s" % ("已保护 · 同一道具全部库存" if Outpost.is_locked(_selected) else "自动保留%d份 · 可出售%d份" % [reserved,allowed])
	_quantity.max_value=maxi(1,allowed);_quantity.value=1
	_quantity.visible=allowed>0;_sell.visible=allowed>0
	_lock.visible=count>0;_lock.text="解除保护" if Outpost.is_locked(_selected) else "保护此道具"
func _preview_batch()->void:
	var ids:Array=[]
	for record in _records:
		if not ids.has(record.id):ids.append(record.id)
	var quality=3 if _batch_quality.selected==2 else _batch_quality.selected
	_pending_plan=Outpost.sale_plan(ids,quality,extra_reserves)
	if _pending_plan.rows.is_empty():status_changed.emit("没有可批量出售的物品；保护、委托、配装和蘑菇库存保留");return
	var lines:PackedStringArray=["预计 +%d 金 · 共%d份 · 释放%d格" % [_pending_plan.gold,_pending_plan.count,_pending_plan.slots_freed],"以下清单确认后一次出售，保存失败不扣物品。",""]
	for record in _pending_plan.rows:lines.append("%s ×%d  →  %d金" % [record.name,record.count,record.gold])
	_batch.grab_focus()
	_batch_dialog.open("\n".join(lines))
func cancel_dialog()->void:
	_pending_plan={}
	if is_instance_valid(_batch_dialog):_batch_dialog.close()
func _compact_option(option:OptionButton)->void:
	option.custom_minimum_size.y=40
	for state in ["normal","hover","pressed","disabled"]:option.add_theme_stylebox_override(state,PixelUi.style(PixelUi.NIGHT,PixelUi.GOLD if state=="hover" else PixelUi.LINE,0,8))
