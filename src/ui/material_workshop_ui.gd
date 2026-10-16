class_name MaterialWorkshopUI
extends CanvasLayer
var _root:Control
var _body:VBoxContainer
var _scroll:ScrollContainer
var _tabs:HBoxContainer
var _title:Label
var _status:Label
var _protect:CheckButton
var _stock:Label
var _camp:=false
var _page:="alchemy"
var _rendered_page:=""
var _service:WeakRef
var _variants:Dictionary={}
var _positions:Dictionary={}
var _guard_until:=0
var _epoch:=0
var _refresh_queued:=false
var _confirm:GlassConfirmUI
var _replacement:Dictionary={}
var _search:LineEdit
var _filter:OptionButton
var _material_hint:Button
var _material_id:=""
var _focus_id:=""
var _browse:Dictionary={}
var _quantities:Dictionary={}
var _auto_variants:Dictionary={}
var _views:Array=[]
func _ready()->void:
	layer=40;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true);set_meta("show_previous_screen",true)
	_root=UiFactory.full_rect();_root.theme=PixelUi.theme();_root.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(_root);_root.add_child(UiFactory.dim_layer(.42))
	var frame:=StarUi.frame(_root,Vector2(980,700));var plate:=PixelUi.inset_panel(20);plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);frame.add_child(plate)
	var box:=UiFactory.vbox(10);plate.add_child(box)
	var heading:=UiFactory.hbox(12);box.add_child(heading);_title=PixelUi.title("",28);_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(_title)
	var back:=PixelUi.compact_button("返回",20);back.custom_minimum_size=Vector2(105,58 if MobileControls.enabled() else 44);heading.add_child(back);back.pressed.connect(close)
	_tabs=UiFactory.hbox(8);box.add_child(_tabs)
	_protect=CheckButton.new();_protect.text="保留委托与目标研究所需材料";_protect.button_pressed=true;_protect.add_theme_font_size_override("font_size",18);_protect.tooltip_text="默认保护所需数量；关闭后可主动消耗。不会使用记忆花或未列入配方的素材。";box.add_child(_protect);_protect.toggled.connect(func(_v:bool)->void:_refresh())
	var tools:=UiFactory.hbox(8);box.add_child(tools)
	_search=LineEdit.new();_search.placeholder_text="搜索名称或材料";_search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_search.custom_minimum_size.y=52 if MobileControls.enabled() else 42;tools.add_child(_search);_search.text_changed.connect(func(_value:String)->void:_reset_list())
	_filter=OptionButton.new();_filter.fit_to_longest_item=false;_filter.custom_minimum_size=Vector2(165,52 if MobileControls.enabled() else 42);tools.add_child(_filter)
	for title in ["全部","已解锁","当前可操作"]:_filter.add_item(title)
	_filter.tooltip_text="研究页的已解锁表示已经完成；当前可操作按材料保留、容量和地点限制计算。"
	_filter.item_selected.connect(func(_value:int)->void:_reset_list())
	_material_hint=PixelUi.compact_button("",17);_material_hint.visible=false;box.add_child(_material_hint);_material_hint.pressed.connect(func()->void:_material_id="";_reset_list())
	_stock=PixelUi.label("",16,PixelUi.MUTED);_stock.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(_stock)
	_scroll=ScrollContainer.new();_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;_scroll.follow_focus=true;_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(_scroll)
	_body=UiFactory.vbox(12);_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_scroll.add_child(_body)
	_status=PixelUi.label("",18,PixelUi.GOLD);_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(_status)
	_confirm=GlassConfirmUI.new();_confirm.title="替换本局刻印";add_child(_confirm)
	_confirm.confirmed.connect(func()->void:
		var request:=_replacement;_replacement={}
		if not request.is_empty() and is_open():_execute("enchant",str(request.id),int(request.variant)))
	_confirm.canceled.connect(func()->void:_replacement={})
	InteractionSkin.mount(_root,"workshop",plate);_root.hide();Outpost.changed.connect(_queue_refresh)
func is_open()->bool:return _root.visible
func open_camp(page:="",material_id:="",focus_id:="")->void:
	if not MaterialWorkshop.bank_error().is_empty():return
	_remember_browse();_camp=true;_service=null;_material_id=material_id;_focus_id=focus_id
	if not page.is_empty():_page=page
	if _page=="enchant":_page="alchemy"
	if not _material_id.is_empty():
		var uses:=MaterialWorkshopCatalog.uses(_material_id)
		if not uses.any(func(row:Dictionary)->bool:return str(row.kind)==_page):
			for candidate in ["alchemy","research","craft"]:
				if uses.any(func(row:Dictionary)->bool:return str(row.kind)==candidate):_page=candidate;break
	_open()
func open_field(service:Node,page:="",material_id:="")->void:
	var error:=MaterialWorkshop.field_error(service)
	if not error.is_empty():return
	_remember_browse();_camp=false;_service=weakref(service);_material_id=material_id;_focus_id=""
	if not page.is_empty():_page=page
	if _page not in ["alchemy","enchant"]:_page="alchemy"
	_open()
func _open()->void:
	_variants.clear();_auto_variants.clear();_quantities.clear();_protect.set_pressed_no_signal(true);_restore_browse()
	_title.text="布琳娜的制作与研究" if _camp else "战地炼金与装备刻印";_status.text="使用仓库材料；研究全角色共享，制作产物存入仓库。" if _camp else "仅使用本局材料；刻印仅本次出征有效，卸下装备停止生效。"
	_root.show();UIFlow.push_screen(self);_guard_until=Time.get_ticks_msec()+150;_build_tabs();_refresh()
	for tab in _tabs.get_children():
		if str(tab.get_meta("workshop_page"))==_page:tab.grab_focus.call_deferred();break
func close()->void:
	_remember_browse();_replacement={};_confirm.close();_positions[_page]=_scroll.scroll_vertical;_root.hide();UIFlow.pop_screen(self)
func _queue_refresh()->void:
	if not is_open() or _refresh_queued:return
	_refresh_queued=true;_queued_refresh.call_deferred()
func _queued_refresh()->void:
	_refresh_queued=false
	if is_inside_tree() and is_open():_refresh()
func _build_tabs()->void:
	for child in _tabs.get_children():_tabs.remove_child(child);child.queue_free()
	var entries:Array=[["炼金配方","alchemy"],["永久研究","research"],["定向制作","craft"]] if _camp else [["战地炼金","alchemy"],["装备刻印","enchant"]]
	for entry in entries:
		var button:=PixelUi.tab_button(str(entry[0]),_page==str(entry[1]),20);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size.y=62 if MobileControls.enabled() else 46;_tabs.add_child(button)
		button.set_meta("workshop_page",str(entry[1]));button.pressed.connect(_change_page.bind(str(entry[1])))
func _refresh()->void:
	if not is_open():return
	var focus:=get_viewport().gui_get_focus_owner();var token:=str(focus.get_meta("focus_token","")) if is_instance_valid(focus) and _body.is_ancestor_of(focus) else ""
	if _rendered_page==_page:_positions[_page]=_scroll.scroll_vertical
	var scroll:int=_positions.get(_page,0);_rendered_page=_page;_epoch+=1;var epoch:=_epoch
	for child in _body.get_children():_body.remove_child(child);child.queue_free()
	for button in _tabs.get_children():button.set_meta("interaction_selected",str(button.get_meta("workshop_page"))==_page);InteractionSkin.apply_button(button,"workshop")
	var known:=MaterialWorkshopCatalog.research(MaterialWorkshop.goal())
	_stock.text=("永久仓库" if _camp else "本局背包 · 不使用仓库材料")+" · 各项显示总量／保留／可用／消耗后剩余。"
	if not known.is_empty():
		_stock.text+="\n目标研究："+str(known.name)+" · "+_cost_line(known.needs,str(known.id))
	_material_hint.visible=not _material_id.is_empty();_material_hint.text="相关材料："+str(ExpeditionData.resolve(_material_id).get("name",_material_id))+"  × 清除筛选"
	_views.clear()
	var source:Array=MaterialWorkshopCatalog.RESEARCH if _page=="research" else MaterialWorkshopCatalog.ENCHANTS.values() if _page=="enchant" else MaterialWorkshopCatalog.CRAFT if _page=="craft" else MaterialWorkshopCatalog.ALCHEMY
	for index in source.size():
		var entry:Dictionary=source[index].duplicate(true)
		if _page=="enchant":
			for id in MaterialWorkshopCatalog.ENCHANTS:
				if MaterialWorkshopCatalog.ENCHANTS[id]==source[index]:entry.id=id;break
		var kind:="research" if _page=="research" else "enchant" if _page=="enchant" else "craft"
		var variant:=0 if kind=="research" else _variant_index(str(entry.id),entry.variants)
		var quantity:=int(_quantities.get(str(entry.id),1)) if kind=="craft" else 1;var view:=MaterialWorkshop.preview(kind,str(entry.id),variant,_camp,_protect.button_pressed,quantity,_field_service())
		var unlocked:=MaterialWorkshopCatalog.unlocked(str(entry.id) if kind=="research" else str(entry.research))
		var search:=str(entry.name)+" "+str(entry.get("desc",""));var related:=_material_id.is_empty()
		for needs in [entry.needs] if kind=="research" else entry.variants:
			for id in needs:search+=" "+str(ExpeditionData.resolve(str(id)).get("name",id));related=related or str(id)==_material_id
		if not related or not _search.text.strip_edges().is_empty() and not search.to_lower().contains(_search.text.strip_edges().to_lower()):continue
		if _filter.selected==1 and not unlocked or _filter.selected==2 and not str(view.error).is_empty():continue
		_views.append({"entry":entry,"kind":kind,"view":view,"order":index,"ready":str(view.error).is_empty()})
	_views.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.order)<int(b.order) if bool(a.ready)==bool(b.ready) else bool(a.ready))
	for row in _views:
		if row.kind=="research":_research_card(row.entry)
		elif row.kind=="enchant":_enchant_card(str(row.entry.id),row.entry)
		else:_recipe_card(row.entry)
	if _views.is_empty():_text(_body,"没有符合当前筛选的项目。可清除搜索、切换页面或查看全部。",18,PixelUi.MUTED)
	_material_list();InteractionSkin.apply_tree(_body,"workshop");_restore_view.call_deferred(epoch,token,scroll)
func _remember_browse()->void:
	if not is_instance_valid(_search):return
	_browse[("camp:" if _camp else "field:")+_page]={"search":_search.text,"filter":_filter.selected,"scroll":_scroll.scroll_vertical}
func _restore_browse()->void:
	var saved:Dictionary=_browse.get(("camp:" if _camp else "field:")+_page,{})
	_search.text=str(saved.get("search",""));_filter.select(int(saved.get("filter",0)));_positions[_page]=int(saved.get("scroll",0));_rendered_page=""
	if not _material_id.is_empty() or not _focus_id.is_empty():_search.text="";_filter.select(0);_positions[_page]=0
func _change_page(page:String)->void:
	_remember_browse();_positions[_page]=_scroll.scroll_vertical;_page=page;_restore_browse();_refresh()
func _reset_list()->void:
	_positions[_page]=0;_rendered_page="";_refresh()
func _field_service()->Node:return _service.get_ref() if _service!=null else null
func _variant_index(key:String,variants:Array)->int:
	if _variants.has(key):return clampi(int(_variants[key]),0,variants.size()-1)
	if not _auto_variants.has(key):
		_auto_variants[key]=0
		for index in variants.size():
			if MaterialWorkshop.cost_error(variants[index],_camp,_protect.button_pressed).is_empty():_auto_variants[key]=index;break
	return int(_auto_variants[key])
func _restore_view(epoch:int,token:String,scroll:int)->void:
	if not is_inside_tree():return
	await get_tree().process_frame
	if not is_inside_tree() or epoch!=_epoch or not is_open():return
	for control in _body.find_children("*","Control",true,false):
		if not token.is_empty() and str(control.get_meta("focus_token",""))==token and control.focus_mode!=Control.FOCUS_NONE and (not control is BaseButton or not control.disabled):control.grab_focus();break
	_scroll.scroll_vertical=scroll
	if not _focus_id.is_empty():
		for button in _body.find_children("*","Button",true,false):
			if str(button.get_meta("focus_token","")).ends_with(":"+_focus_id):
				_scroll.ensure_control_visible(button);button.grab_focus();break
		_focus_id=""
func _card(title:String,desc:String,item:Dictionary={},icon_path:="")->VBoxContainer:
	var panel:=PixelUi.inset_panel(12);_body.add_child(panel);var box:=UiFactory.vbox(8);panel.add_child(box);var head:=UiFactory.hbox(12);box.add_child(head)
	if not item.is_empty():head.add_child(UiFactory.item_icon(item,46))
	elif not icon_path.is_empty():head.add_child(UiFactory.texture_icon(icon_path,46))
	var label:=PixelUi.label(title,22,PixelUi.GOLD);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(label)
	_text(box,desc,18);return box
func _text(parent:Control,value:String,font_size:=18,color:=PixelUi.INK)->Label:
	var label:=PixelUi.label(value,font_size,color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(label);return label
func _cost_line(needs:Dictionary,exclude_goal:="")->String:
	return MaterialWorkshop.cost_text(MaterialWorkshop.cost_preview(needs,_camp,_protect.button_pressed,exclude_goal).rows,_protect.button_pressed)
func _variants_control(parent:Control,key:String,variants:Array)->int:
	var index:=_variant_index(key,variants)
	if variants.size()>1:
		var option:=OptionButton.new();option.fit_to_longest_item=false;option.size_flags_horizontal=Control.SIZE_EXPAND_FILL;option.custom_minimum_size.y=60 if MobileControls.enabled() else 44;parent.add_child(option)
		for needs in variants:option.add_item(MaterialWorkshopCatalog.cost_text(needs))
		option.select(index);option.set_meta("focus_token","variant:"+key);option.item_selected.connect(func(value:int)->void:_positions[_page]=_scroll.scroll_vertical;_variants[key]=value;_refresh())
	return index
func _button(parent:Control,caption:String,error:String,token:String,callback:Callable)->Button:
	var button:=PixelUi.compact_button(caption,20);button.custom_minimum_size.y=64 if MobileControls.enabled() else 46;button.tooltip_text=error;button.disabled=not error.is_empty();button.set_meta("focus_token",token);parent.add_child(button);button.pressed.connect(callback)
	if not error.is_empty():_text(parent,error,16,PixelUi.MUTED)
	return button
func _recipe_card(entry:Dictionary)->void:
	var id:=str(entry.id);var product:=ExpeditionData.resolve(str(entry.product));var title:=str(entry.name)+(" · 绑定装备" if ItemDB.is_equippable(product) else "")
	var box:=_card(title,str(product.get("desc","")),product);var variant:=_variants_control(box,id,entry.variants);var quantity:=int(_quantities.get(id,1))
	var view:=MaterialWorkshop.preview("craft",id,variant,_camp,_protect.button_pressed,quantity,_field_service())
	if ItemDB.is_usable(product):
		var amount:=SpinBox.new();amount.min_value=1;amount.max_value=10;amount.step=1;amount.prefix="制作数量 ";amount.value=quantity;amount.custom_minimum_size.y=52 if MobileControls.enabled() else 44;box.add_child(amount);MobileControls.decorate_number(amount)
		amount.get_line_edit().set_meta("focus_token","quantity:"+id);amount.value_changed.connect(func(value:float)->void:_quantities[id]=int(value);_refresh())
		_text(box,"本次产出 %d份 · 当前材料与空间最多支持%d份"%[quantity,int(view.max_quantity)],17,PixelUi.GOLD)
	_text(box,MaterialWorkshop.cost_text(view.rows,_protect.button_pressed),17,PixelUi.MUTED)
	_button(box,"制作%d份"%quantity,str(view.error),"craft:"+id,_execute.bind("craft",id,variant))
func _research_card(entry:Dictionary)->void:
	var done:=MaterialWorkshopCatalog.unlocked(str(entry.id));var icon_path:=""
	for id in entry.needs:
		if MaterialWorkshopCatalog.BOSS_MATERIALS.has(id):icon_path=MaterialWorkshopCatalog.icon(str(MaterialWorkshopCatalog.BOSS_MATERIALS[id].icon));break
	var box:=_card(str(entry.name)+(" · 已完成" if done else ""),str(entry.desc),{},icon_path);_text(box,_cost_line(entry.needs,str(entry.id)),17,PixelUi.MUTED)
	var view:=MaterialWorkshop.preview("research",str(entry.id),0,true,_protect.button_pressed)
	_button(box,"已研究" if done else "研究并永久解锁",str(view.error),"research:"+str(entry.id),_execute.bind("research",str(entry.id),0))
	if not done:_button(box,"取消研究目标" if MaterialWorkshop.goal()==str(entry.id) else "设为研究目标","","goal:"+str(entry.id),_execute.bind("goal","" if MaterialWorkshop.goal()==str(entry.id) else str(entry.id),0))
func _enchant_card(id:String,entry:Dictionary)->void:
	var item:=GameState.equipped(StringName(entry.slot));var old:=MaterialWorkshopCatalog.enchant(item)
	var box:=_card(str(entry.name)+" · "+str({"weapon":"武器","armor":"护甲","accessory":"饰品"}[entry.slot]),str(entry.desc),{},MaterialWorkshopCatalog.icon(str(entry.icon)))
	if not item.is_empty():
		var preview:=item.duplicate(true);preview.enchant=id
		var linkage:=BuildInsight.describe(preview)
		if not linkage.is_empty():_text(box,linkage,17,Color("b9dbe4"))
	_text(box,"当前装备："+str(item.get("name","未装备"))+("\n当前刻印："+str(old.name)+"；替换不返还旧材料。" if not old.is_empty() else ""),17,PixelUi.MUTED)
	var variant:=_variants_control(box,id,entry.variants);var view:=MaterialWorkshop.preview("enchant",id,variant,false,_protect.button_pressed,1,_field_service())
	_text(box,MaterialWorkshop.cost_text(view.rows,_protect.button_pressed),17,PixelUi.MUTED)
	_button(box,"替换当前刻印" if not old.is_empty() else "施加刻印",str(view.error),"enchant:"+id,_request_enchant.bind(id,variant))
func _request_enchant(id:String,variant:int)->void:
	if not UIFlow.is_top(self) or Time.get_ticks_msec()<_guard_until:return
	var entry:Dictionary=MaterialWorkshopCatalog.ENCHANTS[id];var old:=MaterialWorkshopCatalog.enchant(GameState.equipped(StringName(entry.slot)))
	if old.is_empty():_execute("enchant",id,variant);return
	_replacement={"id":id,"variant":variant};_confirm.dialog_text="将失去「%s」：%s\n\n改为「%s」：%s\n消耗：%s\n旧刻印材料不会返还。"%[str(old.name),str(old.desc),str(entry.name),str(entry.desc),MaterialWorkshopCatalog.cost_text(entry.variants[variant])];_confirm.popup_centered()
func _execute(kind:String,id:String,variant:int)->void:
	if not is_open() or not UIFlow.is_top(self) or Time.get_ticks_msec()<_guard_until:return
	_guard_until=Time.get_ticks_msec()+200;_positions[_page]=_scroll.scroll_vertical
	var error:="";var service:Node=_service.get_ref() if _service!=null else null
	match kind:
		"craft":error=MaterialWorkshop.craft(id,variant,_camp,_protect.button_pressed,service,int(_quantities.get(id,1)))
		"research":error=MaterialWorkshop.research(id,_protect.button_pressed)
		"goal":error=MaterialWorkshop.set_goal(id)
		"enchant":error=MaterialWorkshop.enchant(id,variant,_protect.button_pressed,service)
	_status.text=error if not error.is_empty() else {"craft":"制作%d份完成，已放入%s。"%[int(_quantities.get(id,1)),"仓库" if _camp else "本局背包"],"research":"研究完成，所有角色均可使用新配方。","goal":"研究目标已更新。","enchant":"刻印已施加，仅本次出征有效。"}.get(kind,"操作完成")
	AudioManager.play(&"purchase_failed" if not error.is_empty() else &"reward_claim",-10,0);_refresh()
func _material_list()->void:
	var stock:Dictionary=Outpost.data.get("inventory",{}) if _camp else MaterialWorkshop.counts(GameState.items);var parts:PackedStringArray=[]
	var held:=MaterialWorkshop.reserves(_camp)
	for id in stock:
		if int(stock[id])<=0 or not ItemDB.is_material(ExpeditionData.resolve(str(id))):continue
		parts.append("%s ×%d（保留%d／可用%d）"%[str(ExpeditionData.resolve(str(id)).name),int(stock[id]),mini(int(stock[id]),int(held.get(id,0))),maxi(0,int(stock[id])-(mini(int(stock[id]),int(held.get(id,0))) if _protect.button_pressed else 0))])
	_text(_body,("仓库材料：" if _camp else "本局材料：")+("、".join(parts) if not parts.is_empty() else "暂无"),17,PixelUi.MUTED)
func _input(event:InputEvent)->void:
	if is_open() and UIFlow.is_top(self) and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):close();get_viewport().set_input_as_handled()
func _unhandled_input(_event:InputEvent)->void:
	if is_open() and UIFlow.is_top(self):get_viewport().set_input_as_handled()
