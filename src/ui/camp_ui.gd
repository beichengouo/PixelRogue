class_name CampUI
extends CanvasLayer
signal departure_requested(payload: Dictionary)
signal resume_requested(snapshot: Dictionary)
signal back_requested
signal closed
var world_mode:=false
var _root: Control
var _canvas: Control
var _body: VBoxContainer
var _portrait: TextureRect
var _status: Label
var _page = "prepare"
var _tabs: Array[Button]=[]
var cart: Array = []
var chapter_id:StringName=ChapterCatalog.FIRST
var combat_mode := "rooms"
var carried = 0
var initial_level := 1
var difficulty := 1
var danger:int:
	get:return RunDifficulty.multiplier(difficulty)-1
	set(value):difficulty=RunDifficulty.from_legacy_danger(value)
var _busy = false
var _npc = "sylphiette"
var _scene: Dictionary = {}
var _line = 0
var _rarity_filter = -1
var _farewell = false
var _scroll: ScrollContainer
var _confirm: GlassConfirmUI
var _left: Control
var _warehouse: WarehouseView
var _workshop:MaterialWorkshopUI
var _visit_return:Dictionary={}
var _result_details:=false
var _feedback=""
var _shop_timer=0.0
var _shop_clock:Label
var _page_cache:Node
var _prepare_step:=0
var _show_presets:=false
var _loadout_selected:=""
var _loadout_filter:="all"
var _loadout_scroll:=0
var _page_heading:Label
var _preset_index=0
var _preset_name="方案1"
var _contract_timers:Dictionary={}
var _contract_states:Dictionary={}

func _ready() -> void:
	layer=31
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_meta("blocking_screen",true)
	_root=UiFactory.full_rect()
	_root.theme=PixelUi.theme()
	add_child(_root)
	_workshop=MaterialWorkshopUI.new();add_child(_workshop)
	_page_cache=Node.new();_page_cache.name="PageCache";add_child(_page_cache)
	var art = TextureRect.new()
	if not world_mode:art.texture=CampArt.texture("background")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_root.add_child(art)
	_root.add_child(UiFactory.dim_layer(0.42))
	_canvas=StarUi.frame(_root,Vector2(1160,654))
	var row=UiFactory.hbox(24)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(row)
	var left=UiFactory.vbox(8)
	_left=left
	left.custom_minimum_size.x=310
	row.add_child(left)
	left.add_child(PixelUi.title("星辉回廊",30))
	left.add_child(PixelUi.label("契约者的营地  /  CAMP",15,PixelUi.GOLD))
	_portrait=TextureRect.new()
	_portrait.texture=load(Characters.portrait_path())
	_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size=Vector2(300,380)
	_portrait.size_flags_vertical=Control.SIZE_EXPAND_FILL
	left.add_child(_portrait)
	_status=PixelUi.label("",17,PixelUi.GOLD)
	_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_status)
	var back=PixelUi.compact_button("返回主菜单",18)
	back.custom_minimum_size.y=42
	if world_mode:back.text="返回营地"
	back.pressed.connect(func()->void:close();back_requested.emit())
	left.add_child(back)
	var right=UiFactory.vbox(12)
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var panel=PixelUi.inset_panel(18)
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(panel)
	panel.add_child(right)
	var page_header:=UiFactory.hbox(12);right.add_child(page_header)
	_page_heading=PixelUi.title("",26);_page_heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;page_header.add_child(_page_heading)
	var page_back:=PixelUi.compact_button("返回营地" if world_mode else "关闭",18);page_header.add_child(page_back);page_back.pressed.connect(close)
	var tabs=UiFactory.hbox(8)
	right.add_child(tabs)
	tabs.visible=not world_mode
	for entry in [["出发准备","prepare"],["仓库","warehouse"],["随机商店","shop"],["营地委托","contracts"],["人物互动","relations"],["上次结算","result"]]:
		var button=PixelUi.tab_button(entry[0],false,16)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
		button.set_meta("camp_page",entry[1])
		_tabs.append(button)
		button.pressed.connect(_switch.bind(entry[1]))
	var scroll=ScrollContainer.new()
	_scroll=scroll
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	right.add_child(scroll)
	_body=UiFactory.vbox(10)
	_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_confirm=GlassConfirmUI.new()
	_confirm.title="放弃挂起的出征"
	_confirm.dialog_text="本局带入装备、金币与未撤物资将全部损失。是否放弃并准备新出征？"
	_confirm.confirmed.connect(func()->void:
		if Outpost.abandon_saved():_refresh()
		else:_status.text="保存失败，请重试。")
	add_child(_confirm)
	_root.visible=false
	Outpost.changed.connect(_on_outpost_changed)
	InteractionSkin.mount(_root,"camp",_canvas)

func _on_outpost_changed() -> void:
	if is_open(): _refresh.call_deferred()
func _process(delta:float)->void:
	if not is_open() or not _page in ["shop","contracts"]:return
	_shop_timer-=delta
	if _shop_timer>0:return
	_shop_timer=1.0
	if _page=="contracts":
		Outpost.sync_contracts()
		for contract in ExpeditionData.CONTRACTS:
			var id:=str(contract.id)
			if _contract_states.get(id,"")!=Outpost.contract_status(contract):
				_refresh();return
			var label:=_contract_timers.get(id) as Label
			if is_instance_valid(label):label.text=_contract_description(contract)
		return
	Outpost.sync_shop()
	if is_instance_valid(_shop_clock):
		var seconds=CampStock.PERIOD-(CampStock.local_seconds()%CampStock.PERIOD)
		_shop_clock.text="下批商品 %02d:%02d:%02d · 每3小时自动刷新" % [seconds/3600,(seconds%3600)/60,seconds%60]

func open(result = false) -> void:
	if not UIFlow.can_open(self):return
	if is_open():
		if result:_switch("result")
		return
	ComicMotion.cancel(_canvas)
	Outpost.sync_contracts()
	_busy=false
	_feedback=SaveService.take_migration_notice()
	_scene={}
	_line=0
	_page="result" if result else "prepare"
	cart.clear()
	carried=0;initial_level=1
	difficulty=1
	_root.visible=true
	_scroll.scroll_vertical=0
	UIFlow.push_screen(self)
	_refresh()
	ComicMotion.reveal(_canvas)

func is_open() -> bool:return _root.visible
func close() -> void:
	if is_instance_valid(_workshop):_workshop.close()
	_visit_return={}
	var was_open:=is_open()
	if is_instance_valid(_confirm): _confirm.close()
	if is_instance_valid(_warehouse):_warehouse.cancel_dialog()
	ComicMotion.cancel(_canvas)
	_root.visible=false
	UIFlow.pop_screen(self)
	if was_open:closed.emit()

func _switch(page: String) -> void:
	if not _visit_return.is_empty() and page==str(_visit_return.page):_return_from_visit();return
	if world_mode and page=="prepare" and _page!="prepare":close();return
	if is_instance_valid(_warehouse):_warehouse.cancel_dialog()
	_scroll.scroll_vertical=0
	_page=page
	_scene={}
	_feedback=""
	if page=="shop":Outpost.sync_shop()
	_refresh()

func _input(event: InputEvent) -> void:
	if not is_open() or not UIFlow.is_top(self):return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		if not _visit_return.is_empty():_return_from_visit();get_viewport().set_input_as_handled();return
		close()
		back_requested.emit()
		get_viewport().set_input_as_handled()

func _text(text: String, size = 17, color = PixelUi.INK) -> void:
	var label=PixelUi.label(text,size,color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_body.add_child(label)

func _button(text: String, callback: Callable, disabled = false) -> Button:
	var b=PixelUi.compact_button(text,17)
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.disabled=disabled
	b.pressed.connect(callback)
	_body.add_child(b)
	return b

func _refresh() -> void:
	if not is_open():return
	var previous_view:=_body.find_child("DepartureLoadout",true,false) as CampLoadoutView
	if is_instance_valid(previous_view):
		_loadout_filter=previous_view._filter;_loadout_scroll=previous_view._grid_scroll.scroll_vertical
	var focus=get_viewport().gui_get_focus_owner()
	var token=str(focus.get_meta("focus_token","")) if focus!=null and _body.is_ancestor_of(focus) else ""
	var scroll=_scroll.scroll_vertical
	if _page!="relations": _portrait.texture=load(Characters.portrait_path())
	_left.visible=_page not in ["warehouse","prepare"]
	_page_heading.text={"prepare":"出发准备","warehouse":"回廊仓库","shop":"姜糖的星灯商铺","contracts":"冒险者工会","relations":"灯下相谈","result":"旅途记事"}.get(_page,"星辉回廊")
	for child in _body.get_children():
		if child==_warehouse and _page=="warehouse":continue
		_body.remove_child(child)
		if child==_warehouse:_page_cache.add_child(child);child.hide()
		else:child.queue_free()
	for button in _tabs:
		button.set_meta("interaction_selected",str(button.get_meta("camp_page"))==_page);InteractionSkin.apply_button(button,"camp")
	_status.text="金库 %d 金 · %s\n%s" % [Outpost.gold(),RunDifficulty.title(difficulty),_feedback if not _feedback.is_empty() else "死亡不追回装备与随身金币"]
	if not _visit_return.is_empty():_button("返回"+str(_visit_return.title),_return_from_visit).set_meta("focus_token","visit_return")
	match _page:
		"prepare":_prepare()
		"warehouse":_show_warehouse()
		"shop":_shop()
		"contracts":_contracts()
		"relations":_relations()
		"result":_result()
	_restore_page_focus.call_deferred(token,scroll)
	InteractionSkin.apply_tree(_body,"camp")

func _prepare() -> void:
	if str(Outpost.data.get("active",{}).get("status",""))=="dead":
		_text("本局已死亡，正在保存损失结算。保存完成后可准备新的旅途。",20,PixelUi.GOLD)
		_button("重试保存",func()->void:Outpost.finalize_death();_refresh())
		return
	if not Outpost.active_id().is_empty():
		_text("有一趟尚未撤回的旅途。继续不会重抽掉落或刷新物资。",20,PixelUi.GOLD)
		_button("继续挂起的出征",func()->void:
			if _busy:return
			_busy=true
			var saved=SaveService.run_info().duplicate(true)
			close()
			resume_requested.emit(saved))
		_button("放弃本局并准备新出征",func()->void:_confirm.popup_centered())
		return
	combat_mode="rooms"
	var steps:=UiFactory.hbox(12);_body.add_child(steps)
	for index in 3:
		var button:=PixelUi.button(["1  角色与目的地","2  携带物资","3  确认出发"][index],19,0,46)
		button.set_meta("interaction_selected",_prepare_step==index);steps.add_child(button)
		button.pressed.connect(func()->void:_prepare_step=index;_refresh())
	_text("%s · 金库 %d 金 · Lv.%d · %s"%[Characters.current_name(),Outpost.gold(),initial_level,RunDifficulty.title(difficulty)],18,PixelUi.GOLD)
	if not _feedback.is_empty():_text(_feedback,17,PixelUi.GOLD)
	if _prepare_step==0:_prepare_character()
	elif _prepare_step==1:_prepare_supplies()
	else:_prepare_confirmation()

func _prepare_character()->void:
	_text("目的地",19,PixelUi.GOLD)
	var destination:=OptionButton.new();destination.name="ChapterDestination";_compact_option(destination)
	var chapter_ids:Array=[ChapterCatalog.FIRST,ChapterCatalog.NEXT]
	for id in chapter_ids:
		var available:=ChapterCatalog.unlocked(id)
		destination.add_item(ChapterCatalog.title(id)+(" · 通关苏醒林地后开放" if not available else ""));destination.set_item_disabled(destination.item_count-1,not available)
	destination.select(maxi(0,chapter_ids.find(chapter_id)));destination.item_selected.connect(func(index:int)->void:chapter_id=chapter_ids[index]);_body.add_child(destination)
	_text("难度",19,PixelUi.GOLD)
	var challenge:=OptionButton.new();challenge.name="RunDifficulty";_compact_option(challenge)
	for option in RunDifficulty.OPTIONS:challenge.add_item(RunDifficulty.description(int(option.id)),int(option.id))
	challenge.select(clampi(difficulty,1,4)-1);challenge.item_selected.connect(func(index:int)->void:difficulty=challenge.get_item_id(index));_body.add_child(challenge)
	_passive_options()
	var row:=UiFactory.hbox(24);_body.add_child(row)
	var starting:=SpinBox.new();starting.name="InitialLevel";starting.min_value=1;starting.max_value=DepartureLevels.MAXIMUM;starting.allow_greater=false;starting.allow_lesser=false;starting.step=1;starting.prefix="初始等级 ";initial_level=clampi(initial_level,1,DepartureLevels.MAXIMUM);starting.value=initial_level;row.add_child(starting);MobileControls.decorate_number(starting)
	var tuition:=PixelUi.label("费用 %d 金"%DepartureLevels.cost(initial_level),18);row.add_child(tuition)
	starting.value_changed.connect(func(value:float)->void:initial_level=clampi(int(value),1,DepartureLevels.MAXIMUM);starting.set_value_no_signal(initial_level);tuition.text="费用 %d 金"%DepartureLevels.cost(initial_level))
	_text("最高10级；每级依次50、100、150金。仅本局有效，越过大门时才扣费。",16,PixelUi.MUTED)
	_button("下一步 · 选择携带物资",func()->void:_prepare_step=1;_refresh())

func _prepare_supplies()->void:
	_text("装备每槽1件 · 药剂最多15瓶 · 取用仓库物资不再次收费",18,PixelUi.GOLD)
	var money:=SpinBox.new();money.name="CarriedGold";money.min_value=0;money.max_value=Outpost.gold();money.step=1;money.prefix="随身金币 ";money.value=carried;money.value_changed.connect(func(value:float)->void:carried=int(value));_body.add_child(money);MobileControls.decorate_number(money)
	var selected:=UiFactory.hbox(12);_body.add_child(selected)
	var summary:=PixelUi.label("携带清单 · %d件"%cart.size(),20,PixelUi.GOLD);summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL;selected.add_child(summary)
	var clear:=PixelUi.compact_button("清空清单",17);clear.disabled=cart.is_empty();selected.add_child(clear);clear.pressed.connect(func()->void:cart.clear();_refresh())
	_button("配装方案 ▾" if not _show_presets else "收起配装方案 ▴",func()->void:_show_presets=not _show_presets;_refresh())
	if _show_presets:_presets()
	var filter:=OptionButton.new();_compact_option(filter);filter.add_item("全部品质")
	for i in 4:filter.add_item(ItemDB.rarity_name(i))
	filter.select(_rarity_filter+1);filter.item_selected.connect(func(i:int)->void:_rarity_filter=i-1;_refresh());_body.add_child(filter)
	var loadout:=CampLoadoutView.new();loadout.name="DepartureLoadout";loadout.loadout=cart;loadout.selected_id=_loadout_selected;loadout.combat_mode=combat_mode;loadout.quality=_rarity_filter;loadout._filter=_loadout_filter;loadout.initial_scroll=_loadout_scroll
	loadout.selection_changed.connect(func(id:String)->void:_loadout_selected=id)
	loadout.equip_requested.connect(_add_cart)
	loadout.remove_requested.connect(func(id:String)->void:cart.erase(id);_refresh())
	_body.add_child(loadout)
	_button("前往仓库整理",_visit_page.bind("warehouse"));_button("前往制作与研究",func()->void:_workshop.open_camp())
	_button("下一步 · 核对出发清单",func()->void:_prepare_step=2;_refresh())

func _preparation_check()->String:
	var value:=CampPreparation.new();value.chapter_id=chapter_id;value.loadout=cart;value.carried=carried;value.initial_level=initial_level;value.difficulty=difficulty
	return value.error()
func _resolve_preparation_error(message:String)->void:
	_feedback=message
	if message.contains("仓库超量"):_switch("warehouse");_feedback=message;_refresh();return
	_prepare_step=0 if message.begins_with("初始等级") or message.contains("失名") or message.contains("请选择有效的战斗难度") else 1
	_refresh()
func _prepare_confirmation()->void:
	_text("角色 · %s\n目的地 · %s\n难度 · %s\n出发等级 · Lv.%d\n同行被动 · %s"%[Characters.current_name(),ChapterCatalog.title(chapter_id),RunDifficulty.title(difficulty),initial_level,str(PassiveDefinitions.for_character(Characters.current_id()).filter(func(p:Dictionary)->bool:return StringName(p.id)==PassiveDefinitions.selected(Characters.current_id()))[0].name)],21)
	_text("携带物资 · %d件 · 随身金币 %d金\n等级费用 %d金 · 确认不扣费，出门后结余 %d金"%[cart.size(),carried,DepartureLevels.cost(initial_level),Outpost.gold()-carried-DepartureLevels.cost(initial_level)],19,PixelUi.GOLD)
	for id in cart:
		var item:=ExpeditionData.resolve(str(id));_text("• "+str(item.name),18,ItemDB.rarity_color(int(item.rarity)))
	if cart.is_empty():_text("空装出发",18,PixelUi.MUTED)
	for advice in CampPreparation.advice(cart):_text("准备提醒 · "+advice,17,PixelUi.GOLD)
	_button("前往仓库整理",_visit_page.bind("warehouse"));_button("前往制作与研究",func()->void:_workshop.open_camp())
	_prepare_preview()
	_text("出发后重置训练配置。成功撤离可带回绑定装备，死亡仍会损失带入物品。",17,PixelUi.MUTED)
	if Outpost.overfull():_text("仓库超量，请先清理或扩容。",18,Palette.UI_DANGER)
	if maxi(int(Outpost.data.bonds.sylphiette),int(Outpost.data.bonds.iris))>=200:
		var farewell:=CheckButton.new();farewell.text="出发前听一段专属送行";farewell.button_pressed=_farewell;farewell.toggled.connect(func(value:bool)->void:_farewell=value);_body.add_child(farewell)
	var error:=_preparation_check()
	if not error.is_empty():
		_text(error,18,Palette.UI_DANGER)
		_button("前往修正准备项目",_resolve_preparation_error.bind(error))
	var depart:=_button("确认准备 · 开启四座大门" if world_mode else "出发 · 进入初始房间",_depart,not error.is_empty())
	depart.tooltip_text=error if not error.is_empty() else "仅确认清单；越过大门时重新验证并扣除物资。"

func _add_cart(id: String) -> void:
	var item=ExpeditionData.resolve(id)
	if not ItemDB.can_equip(item):return
	if cart.count(id)>=int(Outpost.data.inventory.get(id,0)):return
	if ItemDB.is_equippable(item):
		for old in cart.duplicate():
			if ItemDB.slot_of(ExpeditionData.resolve(str(old)))==ItemDB.slot_of(item):cart.erase(old)
	else:
		var count=0
		for old in cart:
			if ItemDB.is_usable(ExpeditionData.resolve(str(old))):count+=1
		if count>=15:return
	cart.append(id)
	_refresh()

func _depart() -> void:
	if _busy or not is_open():return
	var error:=_preparation_check()
	if not error.is_empty():_resolve_preparation_error(error);return
	if Outpost.overfull():_switch("warehouse");return
	var cost=carried+DepartureLevels.cost(initial_level)
	for id in cart:
		if cart.count(id)>int(Outpost.data.inventory.get(id,0)):_feedback="所选物品库存不足，请重新选择。";_refresh();return
	if cost>Outpost.gold():
		_status.text="金币不足，还需要 %d 金。" % (cost-Outpost.gold())
		return
	if _farewell:
		_farewell=false
		_text("希露媞雅：‘回来的时候，先叫我的名字。’
伊莉丝：‘灯会亮着。我们会一起等。’",22,PixelUi.GOLD)
		_button("约好了 · 正式出发",_depart)
		return
	_busy=true
	cart=cart.filter(func(id:Variant)->bool:return ItemDB.available_in_mode(ExpeditionData.resolve(str(id)),combat_mode))
	var payload:Dictionary={"chapter_id":str(chapter_id),"departure":{"chapter_id":str(chapter_id),"loadout":cart.duplicate(),"carried":carried,"danger":danger,"difficulty":difficulty,"initial_level":initial_level,"combat_mode":combat_mode},"combat_mode":combat_mode}
	close()
	departure_requested.emit(payload)

func _contracts()->void:
	_contract_timers.clear();_contract_states.clear()
	_text("先接取，再提交仓库材料；接取后按系统时间计时，离线也会计时。",18,PixelUi.GOLD)
	_text("超时扣除委托人好感，1小时后可重新接取；每日委托每天可完成一次。",15,PixelUi.MUTED)
	for i in ExpeditionData.CONTRACTS.size():
		var contract:Dictionary=ExpeditionData.CONTRACTS[i]
		var status:=Outpost.contract_status(contract)
		_contract_states[str(contract.id)]=status
		_text(str(contract.title)+(" · 每日" if contract.get("repeatable",false) else ""),21)
		_text("委托人 · %s  |  %s好感 %d / 500 · %s" % [CampResidents.issuer_name(contract),BondRules.NAMES[contract.owner],int(Outpost.data.bonds.get(contract.owner,0)),BondRules.stage(int(Outpost.data.bonds.get(contract.owner,0)))],16,PixelUi.GOLD)
		_text(_contract_description(contract),17)
		_contract_timers[str(contract.id)]=_body.get_child(_body.get_child_count()-1)
		var progress:PackedStringArray=[]
		var ready:=status=="accepted"
		for id in Outpost.contract_needs(contract):
			progress.append("%s %d/%d" % [ExpeditionData.resolve(id).name,int(Outpost.data.inventory.get(id,0)),int(Outpost.contract_needs(contract)[id])])
			ready=ready and int(Outpost.data.inventory.get(id,0))>=int(Outpost.contract_needs(contract)[id])
		_text(" · ".join(progress),15,PixelUi.MUTED)
		if not str(contract.get("issuer","")).is_empty():
			_text("请在营地找「%s」接取或交付；工会仅展示记录。"%CampResidents.issuer_name(contract),17,PixelUi.GOLD)
			if status=="accepted":_button("追踪此委托",func()->void:Outpost.track_contract(str(contract.id));_refresh()).set_meta("focus_token","contract:"+str(contract.id)+":track")
			continue
		if status=="available":
			_button("接取委托 · 开始计时",_accept_contract.bind(i)).set_meta("focus_token","contract:"+str(contract.id)+":submit")
		elif status=="accepted":
			_button("交付材料 · 完成委托" if ready else "已接取 · 材料不足",_claim.bind(i),not ready).set_meta("focus_token","contract:"+str(contract.id)+":submit")
			_button("正在追踪" if Outpost.tracked_contract().get("id","")==contract.id else "追踪此委托",func()->void:Outpost.track_contract(str(contract.id));_refresh()).set_meta("focus_token","contract:"+str(contract.id)+":track")
		else:
			_button({"locked":"尚未开放 · 完成前置委托","completed":"已完成","expired":"已超时 · 等待重新接取"}.get(status,status),func()->void:pass,true)
	_text("好感增长：同一人物每日最多增加8点，回看剧情不重复增加。",15,PixelUi.MUTED)
func _contract_description(contract:Dictionary)->String:
	var timer:="接取后%d小时内完成" % int(contract.hours)
	if Outpost.contract_status(contract)=="accepted":
		var remaining:=Outpost.contract_remaining(contract)
		timer="剩余 %02d:%02d:%02d" % [remaining/3600,(remaining%3600)/60,remaining%60]
	return str(contract.desc)+"\n%s · 奖励%d金 · 好感+%d（超时−%d）" % [timer,contract.reward,contract.bond,contract.penalty]
func _accept_contract(index:int)->void:
	_feedback="已接取委托 · 开始计时" if Outpost.accept_contract(index) else "委托尚未开放、已接取或保存失败。"
	_refresh()

func _claim(index: int) -> void:
	if Outpost.claim_contract(index):
		var contract:Dictionary=ExpeditionData.CONTRACTS[index]
		var gain:=int(Outpost.data.contract_jobs[contract.id].get("bond_gained",0))
		_feedback="委托完成 · %s好感+%d · 获得%d金" % [BondRules.NAMES[contract.owner],gain,contract.reward]
		if gain==0:_feedback+="（今日增长已达上限或好感已满）"
		_refresh()
	else:_status.text="请先接取委托；超时、材料不足或保存失败时不能交付。"

func _relations() -> void:
	var selector=OptionButton.new()
	_compact_option(selector)
	var npcs:=BondRules.NAMES.keys()
	for npc in npcs:selector.add_item(BondRules.NAMES[npc])
	selector.select(maxi(0,npcs.find(_npc)))
	selector.item_selected.connect(func(i:int)->void:_npc=str(npcs[i]);_scene={};_refresh())
	_body.add_child(selector)
	_portrait.texture=load({"iris":Story.P_GODDESS,"sylphiette":Characters.DATA[Characters.DEFAULT_ID].portraits.stand,"merchant":NpcArt.portrait_path("merchant"),"tavern":NpcArt.portrait_path("tavern")}[_npc])
	var bond=int(Outpost.data.bonds.get(_npc,0))
	_text("%s · 好感 %d / 500" % [BondRules.NAMES[_npc],bond],21,PixelUi.GOLD)
	_text(BondRules.range_text(bond),18,PixelUi.GOLD)
	_text("0–50 初识 · 50–100 相知 · 100–200 信任\n200–300 亲近 · 300–400 默契 · 400–500 羁绊",15,PixelUi.MUTED)
	_text("完成对应人物委托可增加好感；剧情每次2–5点，每人每日最多8点，超时会扣减。关系不增加永久战斗属性。",16,PixelUi.MUTED)
	if _npc in ["merchant","tavern"]:_button("查看对方的委托",func()->void:_switch("contracts"))
	if not _scene.is_empty():
		var portrait_path = Story.P_GODDESS
		if _npc=="sylphiette":
			portrait_path=Characters.DATA[Characters.DEFAULT_ID].dialogue_portraits[["thoughtful","happy","determined"][_line%3]]
		elif _npc in ["merchant","tavern"]:
			portrait_path=NpcArt.portrait_path(_npc,["inspect","success","welcome"][_line%3])
		elif _npc=="iris" and ResourceLoader.exists("res://assets/characters/dialogue/goddess_welcome_pose_v1.png"):
			portrait_path="res://assets/characters/dialogue/goddess_welcome_pose_v1.png"
		_portrait.texture=load(portrait_path)
		_text(str(_scene.lines[_line]),22)
		_button("继续" if _line<_scene.lines.size()-1 else "记住这个约定",_advance_scene)
		return
	for event in CampStory.EVENTS.get(_npc,[]):
		var seen=Outpost.data.events.has(_npc+":"+str(event.id))
		_button(str(event.title)+(" · 回看" if seen else ""),_play_event.bind(event,seen),not seen and not CampStory.available(_npc,event))
	if bond>=100:_button("信任服务 · 查看调查委托",func()->void:_switch("contracts"))
	if bond>=200:_button("亲近服务 · 开启出发送行",func()->void:_farewell=true;_switch("prepare"))

func _play_event(event: Dictionary, replay: bool) -> void:
	_scene=event.duplicate(true)
	_scene["replay"]=replay
	_line=0
	_refresh()

func _advance_scene() -> void:
	if _line<_scene.lines.size()-1:
		_line+=1
		_refresh()
		return
	if not bool(_scene.get("replay",false)):
		Outpost.bond_event(_npc,str(_scene.id),int(_scene.gain),bool(_scene.get("gift",false)))
	_scene={}
	_refresh()

func _result() -> void:
	var r:Dictionary=Outpost.data.get("last_result",{})
	if r.is_empty():_text(CampStory.INTRO,20);return
	_text("撤回成功" if r.get("outcome","")=="extracted" else "旅途结束 · 未撤收益全部损失",25,PixelUi.GOLD)
	_text("第%d波 · 本次入库 %d 金 · 出发投入 %d 金" % [int(r.get("wave",0)),int(r.get("gold",0)),int(r.get("spent",0))],18)
	if r.get("outcome","")=="extracted":
		var sold:=0
		for row in r.get("rows",[]):sold+=int(row.get("gold",0))
		_text("随身金币入账 %d 金\n未绑定物品折价 %d 金\n合计到账 %d 金"%[int(r.get("coin_income",r.get("coins",0))),int(r.get("sale_income",sold)),int(r.get("gold",0))],18,PixelUi.GOLD)
	else:
		_text("损失随身金币 %d 金；本次出征物品未带回。"%int(r.get("coins",0)),18,Palette.UI_DANGER)
		for item in r.get("lost_items",[]):_text("遗失 · %s ×%d"%[str(item.name),int(item.count)],17,PixelUi.MUTED)
	_material_result(r)
	_text("战斗难度 · "+RunDifficulty.title(int(r.get("difficulty",1))),17,PixelUi.GOLD)
	for row in r.get("rows",[]):
		if ItemDB.is_material(ExpeditionData.resolve(str(row.get("id","")))):continue
		var income=UiFactory.hbox(10)
		var item=ExpeditionData.resolve(str(row.get("id","")))
		if not item.is_empty():
			item.bound=bool(row.get("bound",false));var icon:=UiFactory.item_icon(item,32);income.add_child(icon);BoundEquipment.badge(icon,item)
		income.add_child(PixelUi.label("%s ×%d   →   仓库存入" % [row.name,int(row.count)] if bool(row.get("stored",false)) else "%s ×%d   →   %d 金" % [row.name,int(row.count),int(row.gold)],17))
		_body.add_child(income)
	_text("绑定装备、材料与蘑菇已存入仓库；未绑定物品自动出售。" if r.get("outcome","")=="extracted" else "金库、人物关系和已知线索保留。",17,PixelUi.MUTED)
	if Outpost.overfull():_text("仓库超量，下一次出发前请清理或扩容。",18,Palette.UI_DANGER)
	var build:Dictionary=r.get("build",{})
	if not build.is_empty():
		_text("本次最终构筑",21,PixelUi.GOLD)
		var report=UiFactory.vbox(10)
		_body.add_child(report)
		var summary=PixelUi.label("",16)
		summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		report.add_child(summary)
		RunBuildReport.populate(summary,build)
	_button("准备下一次出征",func()->void:_switch("prepare"))

func _material_result(result:Dictionary)->void:
	var report:Dictionary=result.get("materials",{})
	if report.is_empty():return
	_text("材料战利品",23,PixelUi.GOLD)
	for entry in [["collected","本局收集"],["alchemy","炼金消耗"],["enchant","刻印消耗"],["crafted","炼金产物"],["brought_back","实际带回"],["lost","本局损失"]]:
		var values:Dictionary=report.get(str(entry[0]),{});var summary:Dictionary={};var parts:PackedStringArray=[]
		for id in values:
			var category:="首领素材" if MaterialWorkshopCatalog.BOSS_MATERIALS.has(str(id)) else "蘑菇" if str(id).begins_with("glow_mushroom_") else "药剂" if ItemDB.is_usable(ExpeditionData.resolve(str(id))) else "地区样本" if str(id).ends_with("_sample") else "其他材料"
			summary[category]=int(summary.get(category,0))+int(values[id])
		for category in summary:parts.append("%s ×%d"%[str(category),int(summary[category])])
		if not parts.is_empty():_text(str(entry[1])+" · "+"、".join(parts),18)
		if _result_details:
			for id in values:_text("    %s ×%d"%[str(ExpeditionData.resolve(str(id)).get("name",id)),int(values[id])],16,PixelUi.MUTED)
	_button("收起材料明细 ▴" if _result_details else "展开材料明细 ▾",func()->void:_result_details=not _result_details;_refresh()).set_meta("focus_token","material_report")
	for id in report.get("first",[]):_text("首次带回 · "+str(ExpeditionData.resolve(str(id)).get("name",id)),18,PixelUi.GOLD)
	for id in report.get("brought_back",{}):
		if MaterialWorkshopCatalog.BOSS_MATERIALS.has(str(id)):_text("首领战利品 · %s ×%d"%[str(ExpeditionData.resolve(str(id)).name),int(report.brought_back[id])],19,PixelUi.GOLD)
	if result.get("outcome","")!="extracted":_text("只损失本局携带材料，历史仓库库存不受影响。",17,PixelUi.MUTED);return
	for entry in MaterialWorkshopCatalog.RESEARCH:
		if not MaterialWorkshopCatalog.unlocked(str(entry.id)) and MaterialWorkshop.cost_error(entry.needs,true,true,str(entry.id)).is_empty():
			_button("查看可研究 · "+str(entry.name),func()->void:_workshop.open_camp("research","",str(entry.id)))
	for contract in ExpeditionData.CONTRACTS:
		if Outpost.contract_status(contract)!="accepted":continue
		var available:=true;var needs:=Outpost.contract_needs(contract)
		for id in needs:available=available and int(Outpost.data.inventory.get(id,0))>=int(needs[id])
		if available:_button("查看可交付委托 · "+str(contract.title)+" · 找"+CampResidents.issuer_name(contract),func()->void:_visit_page("contracts");_focus_page_target.call_deferred("contract:"+str(contract.id)+":track"))

func _visit_page(page:String)->void:
	var current:=_body.find_child("DepartureLoadout",true,false) as CampLoadoutView
	if is_instance_valid(current):_loadout_filter=current._filter;_loadout_scroll=current._grid_scroll.scroll_vertical
	if _visit_return.is_empty():_visit_return={"page":_page,"scroll":_scroll.scroll_vertical,"title":"出发准备" if _page=="prepare" else "旅途记事","step":_prepare_step}
	_page=page;_scroll.scroll_vertical=0;_refresh()
func _return_from_visit()->void:
	var target:=_visit_return;_visit_return={}
	if target.is_empty():return
	_page=str(target.page);_prepare_step=int(target.step);_refresh();_restore_page_focus.call_deferred("",int(target.scroll))
func _focus_page_target(token:String)->void:
	if not is_inside_tree() or not is_open():return
	await get_tree().process_frame
	if not is_inside_tree() or not is_open():return
	for button in _body.find_children("*","Button",true,false):
		if str(button.get_meta("focus_token",""))==token:_scroll.ensure_control_visible(button);button.grab_focus();break

func _show_warehouse()->void:
	_button("布琳娜的制作与研究",func()->void:_workshop.open_camp())
	if _warehouse==null:
		_warehouse=WarehouseView.new()
		_warehouse.recipe_requested.connect(func(id:String)->void:_workshop.open_camp("alchemy",id))
		_warehouse.status_changed.connect(func(message:String)->void:_feedback=message)
	if _warehouse.get_parent()==null:_body.add_child(_warehouse)
	elif _warehouse.get_parent()!=_body:_warehouse.reparent(_body,false)
	_warehouse.show()
	_body.move_child(_warehouse,_body.get_child_count()-1)
	_warehouse.extra_reserves=Outpost.loadout_counts(cart)
	_warehouse.refresh()
	if _body.get_child_count()==1:_button("返回出发准备 · 金库 %d 金" % Outpost.gold(),_switch.bind("prepare"))

func _presets()->void:
	_text("配装方案 · 保存与取用不扣金币 · 缺货只提示，不自动购买",16,PixelUi.MUTED)
	var row=UiFactory.hbox(8);_body.add_child(row)
	var selector=OptionButton.new();_compact_option(selector);row.add_child(selector)
	selector.set_meta("focus_token","preset_selector")
	for i in 3:selector.add_item(str(Outpost.data.get("presets",{}).get(str(i),{}).get("name","方案%d · 未保存" % (i+1))))
	selector.select(_preset_index)
	selector.item_selected.connect(func(i:int)->void:
		_preset_index=i;_preset_name=str(Outpost.data.get("presets",{}).get(str(i),{}).get("name","方案%d" % (i+1)));_refresh())
	var name_edit=LineEdit.new();name_edit.placeholder_text="方案名称";name_edit.text=_preset_name;name_edit.max_length=20;name_edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(name_edit)
	name_edit.text_changed.connect(func(text:String)->void:_preset_name=text)
	var actions=UiFactory.hbox(8);_body.add_child(actions)
	var save=PixelUi.compact_button("保存当前",16);actions.add_child(save)
	save.set_meta("focus_token","preset_save")
	save.pressed.connect(func()->void:
		_feedback="方案已保存；对应库存自动保留" if Outpost.save_preset(_preset_index,_preset_name,cart,carried,danger,difficulty) else "当前清单无效、缺货或保存失败";_refresh())
	var take=PixelUi.compact_button("取用方案",16);actions.add_child(take);take.disabled=not Outpost.data.get("presets",{}).has(str(_preset_index))
	take.set_meta("focus_token","preset_take")
	take.pressed.connect(func()->void:
		var preset=Outpost.use_preset(_preset_index)
		if preset.is_empty():return
		cart=preset.loadout;carried=int(preset.carried);difficulty=int(preset.difficulty)
		cart=cart.filter(func(id:Variant)->bool:return ItemDB.available_in_mode(ExpeditionData.resolve(str(id)),combat_mode))
		_feedback="方案已取用" if preset.missing.is_empty() else "缺货，未自动购买："+"、".join(preset.missing)
		_refresh())
	var clear=PixelUi.compact_button("删除方案",16);actions.add_child(clear);clear.disabled=take.disabled
	clear.set_meta("focus_token","preset_delete")
	clear.pressed.connect(func()->void:_feedback="方案已删除" if Outpost.delete_preset(_preset_index) else "保存失败，方案保留";_refresh())
func _prepare_preview()->void:
	var stats=Outpost.preview_loadout(cart)
	stats.add_flat(&"max_hp",GameState.HP_PER_LEVEL*maxi(0,initial_level-1));stats.add_flat(&"attack",GameState.ATK_PER_LEVEL*maxi(0,initial_level-1))
	var parts:PackedStringArray=[]
	for entry in [[&"max_hp","生命"],[&"attack","攻击"],[&"move_speed","移速"],[&"crit_chance","暴击"],[&"crit_mult","暴伤"],[&"dash_cooldown","冲刺冷却"],[&"lifesteal","命中回血"]]:
		parts.append("%s %s" % [entry[1],ItemInsight.stat_text(entry[0],stats.get_value(entry[0]))])
	for entry in [[&"thorns","反伤"],[&"coin_gain","金币收益"],[&"attack_speed","攻速"]]:
		if not is_equal_approx(stats.get_value(entry[0]),float(GameState.BASE_STATS[entry[0]])):parts.append("%s %s" % [entry[1],ItemInsight.stat_text(entry[0],stats.get_value(entry[0]))])
	_text("出发属性（Lv.%d，无局内遗物/天赋）\n"%initial_level+" · ".join(parts),16,PixelUi.GOLD)
func _camp_comparison(id:String)->String:
	var item=ExpeditionData.resolve(id)
	var candidate=cart.duplicate()
	for old in candidate.duplicate():
		if ItemDB.slot_of(ExpeditionData.resolve(str(old)))==ItemDB.slot_of(item):candidate.erase(old)
	candidate.append(id)
	var before=Outpost.preview_loadout(cart);var after=Outpost.preview_loadout(candidate)
	var lines:PackedStringArray=[]
	for entry in [[&"attack","攻击"],[&"max_hp","生命"],[&"move_speed","移速"],[&"crit_chance","暴击"],[&"crit_mult","暴伤"],[&"dash_cooldown","冲刺冷却"],[&"thorns","反伤"],[&"lifesteal","命中回血"],[&"coin_gain","金币收益"]]:
		if not is_equal_approx(before.get_value(entry[0]),after.get_value(entry[0])):lines.append("%s %s → %s" % [entry[1],ItemInsight.stat_text(entry[0],before.get_value(entry[0])),ItemInsight.stat_text(entry[0],after.get_value(entry[0]))])
	return " · ".join(lines) if not lines.is_empty() else "与当前准备装备属性相同"
func _shop()->void:
	var portrait_state:String="shortage" if _feedback.contains("不足") or _feedback.contains("失败") else "success" if _feedback.contains("购") or _feedback.contains("货架已更新") else "welcome"
	_portrait.texture=NpcArt.portrait("merchant",portrait_state)
	if world_mode:_button("与姜糖交谈",func()->void:_npc="merchant";_switch("relations"))
	_text("姜糖的星灯商铺 · 金库 %d 金" % Outpost.gold(),24,PixelUi.GOLD)
	_shop_clock=PixelUi.label("每3小时自动刷新 · 当前货架与售罄状态保存",17,PixelUi.MUTED);_body.add_child(_shop_clock)
	if not _feedback.is_empty():_text(_feedback,18,PixelUi.GOLD)
	var row=UiFactory.hbox(10);_body.add_child(row)
	var refresh=PixelUi.compact_button("立即刷新 · %d金" % Outpost.reroll_cost(),17);row.add_child(refresh);refresh.disabled=Outpost.reroll_cost()>Outpost.gold()
	refresh.pressed.connect(func()->void:_feedback="货架已更新" if Outpost.reroll_shop() else "金币不足或保存失败";_refresh())
	row.add_child(PixelUi.label("每日价格翻倍 · 自动刷新不清零",16,PixelUi.MUTED))
	var grid=GridContainer.new();grid.columns=1 if _left.visible else 2;grid.add_theme_constant_override("h_separation",14);grid.add_theme_constant_override("v_separation",10);_body.add_child(grid)
	var state:Dictionary=Outpost.data.get("shop",{})
	var offers:Array=state.get("offers",[])
	for i in offers.size():
		var item=Outpost.stored_item(str(offers[i].id));var card=PixelUi.inset_panel(10);card.custom_minimum_size.x=530;grid.add_child(card)
		var content=UiFactory.vbox(6);card.add_child(content)
		var title=UiFactory.hbox(10);content.add_child(title);var icon=UiFactory.item_icon(item,44);title.add_child(icon);BoundEquipment.badge(icon,item)
		var name_label=PixelUi.label(str(item.name),18,ItemDB.rarity_color(int(item.rarity)));name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.add_child(name_label);title.add_child(RarityWordmark.make(int(item.rarity),32))
		var desc=PixelUi.label(str(item.desc),16);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desc.custom_minimum_size.x=480;content.add_child(desc)
		if BoundEquipment.is_bound(item):
			var binding=PixelUi.label(BoundEquipment.description(),14,Color("a9f5d4"));binding.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(binding)
		var button=PixelUi.compact_button("已售罄" if bool(offers[i].sold) else "入库 · "+CampStock.price_text(item),17);content.add_child(button)
		var price=CampStock.price(item);var affordable=int(price.gold)<=Outpost.gold()
		for id in price.materials:affordable=affordable and int(Outpost.data.inventory.get(id,0))>=int(price.materials[id])
		button.disabled=bool(offers[i].sold) or not affordable or Outpost.warehouse_slots({str(item.id):1})>Outpost.warehouse_capacity()
		if not bool(offers[i].sold):
			if not affordable:button.text=("金币不足 · " if price.materials.is_empty() else "材料不足 · ")+CampStock.price_text(item)
			elif Outpost.warehouse_slots({str(item.id):1})>Outpost.warehouse_capacity():button.text="仓库已满 · 请先清理或扩容"
		button.set_meta("focus_token","stock:"+str(item.id));button.pressed.connect(_buy_stock.bind(i,int(state.batch),int(state.nonce)))
	_text("基础补给 · 普通装备与基础治疗药剂",20,PixelUi.GOLD)
	for item in ExpeditionData.catalog(0):
		_button("%s%s · %d金 · 购买入库" % [str(item.name)," · 绑定" if ItemDB.is_equippable(item) else "",CampStock.basic_price(item)],_buy_basic.bind(str(item.id)),CampStock.basic_price(item)>Outpost.gold() or Outpost.warehouse_slots({str(item.id):1})>Outpost.warehouse_capacity())
	_button("返回出发准备",_switch.bind("prepare"))
func _buy_stock(index:int,batch:int,nonce:int)->void:
	var offers:Array=Outpost.data.get("shop",{}).get("offers",[])
	var bound:=index>=0 and index<offers.size() and BoundEquipment.is_bound(Outpost.stored_item(str(offers[index].id)))
	_feedback=("购买成功 · 装备已绑定并存入仓库" if bound else "购买成功 · 已存入仓库") if Outpost.buy_offer(index,-1,batch,nonce) else "商品已更新、库存空间不足、材料不足或保存失败。"
	if _feedback.contains("失败") or _feedback.contains("不足"):AudioManager.play(&"purchase_failed",-10,0)
	_refresh()
func _buy_basic(id:String)->void:
	_feedback=("购买成功 · 装备已绑定并存入仓库" if ItemDB.is_equippable(Outpost.stored_item(id)) else "购买成功 · 已存入仓库") if Outpost.buy_basic(id) else "金币、仓位不足或保存失败。"
	if _feedback.contains("失败") or _feedback.contains("不足"):AudioManager.play(&"purchase_failed",-10,0)
	_refresh()

func _compact_option(option: OptionButton) -> void:
	option.size_flags_horizontal=Control.SIZE_EXPAND_FILL;option.fit_to_longest_item=false
	option.custom_minimum_size.y=60 if MobileControls.enabled() else 40
	for state in ["normal","hover","pressed","disabled"]:
		option.add_theme_stylebox_override(state,PixelUi.style(PixelUi.NIGHT,PixelUi.GOLD if state=="hover" else PixelUi.LINE,0,8))

func _restore_page_focus(token: String, scroll: int) -> void:
	if not is_open(): return
	for button in _body.find_children("*","Button",true,false):
		if not token.is_empty() and str(button.get_meta("focus_token",""))==token and not button.disabled:
			button.grab_focus()
			_scroll.scroll_vertical=scroll
			return
	PixelUi.focus_button(_body)
	if get_viewport().gui_get_focus_owner()==null:
		for button in _tabs:
			if str(button.get_meta("camp_page"))==_page:button.grab_focus();break
	_scroll.scroll_vertical=scroll

func _passive_options()->void:
	_text("同行之誓 · 出发后不可更改",18,PixelUi.GOLD)
	var character:=Characters.current_id()
	for passive:Dictionary in PassiveDefinitions.for_character(character):
		var chosen:=StringName(passive.id)==PassiveDefinitions.selected(character)
		var button:=_button(("◆ " if chosen else "◇ ")+str(passive.name),func()->void:PassiveDefinitions.select(character,StringName(passive.id));_refresh())
		button.tooltip_text=str(passive.desc)
		button.set_meta("focus_token","passive:"+str(passive.id))
	_text(str(PassiveDefinitions.for_character(character).filter(func(p:Dictionary)->bool:return StringName(p.id)==PassiveDefinitions.selected(character))[0].desc),16,PixelUi.MUTED)

func open_facility(page:String)->void:
	if not world_mode or not UIFlow.can_open(self):return
	_busy=false;_root.show();UIFlow.push_screen(self);_page=page;_scene={};_line=0
	if page=="shop":Outpost.sync_shop()
	if page=="contracts":Outpost.sync_contracts()
	_refresh()
