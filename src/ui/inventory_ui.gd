class_name InventoryUI
extends CanvasLayer
## 背包、技能与属性界面。布局壳在 inventory_shell.tscn 中可编辑。
## 星辉主题仅作用于这页，旧菜单可逐步迁移。
signal opened
signal closed

const COLS := 6
const ROWS := 3
## 保持固定方形格子，长列表由滚动容器承载。
const SLOT_SIZE := 126.0
const EQUIP_SLOT := 104.0

var _root: Control
var _shell: Control
var _open_tween: Tween
var _portrait_tween: Tween
var _caption_tween: Tween
var _close_tween: Tween
var _tab_memory: Dictionary = {}
var _sort_mode := 0
var _sort_button: Button
var _gear_filter:OptionButton
var _gear_part:StringName=&""
var _toolbar: Control
var _sell_button:Button
var _bind_button:Button
var _sale_confirm:SaleConfirmUI
var _pending_sale:Dictionary={}
const SHELL_SIZE:=Vector2(2016,1100)
var _equip_wrapper: Control
var _equip_box: HBoxContainer
var _grid: GridContainer
var _grid_hint: Label
var _page_box: VBoxContainer
var _detail_box: VBoxContainer
var _character_name: Label
var _character_job: Label
var _bag_count: Label
var _selected: Dictionary = {}
var _ordered_ids: Array = []
var _submit_until := 0
var _last_click_key := ""
var _last_click_msec := 0
const DOUBLE_CLICK_MSEC := 450
var _panel: Control
## 立绘与名字（打开时做滑入动画用）
var _portrait_node: Control
var _caption_node: Control
## 正在播关闭动画：这期间不再响应开关，避免连点把状态搞乱
var _closing := false
## 分类页签的按钮与它们的 id/名字（用来刷新件数）
var _tab_buttons: Array[Button] = []
var _tab_ids: Array[StringName] = []
var _tab_labels: Array[String] = []
## 背包分类页签：全部 / 装备 / 遗物
## 默认页签必须是 TABS 里真实存在的 id。
## 以前这里是 &"all"，而 TABS 里根本没有 all —— 于是打开背包时
## 左边走 _rebuild_stat_page()（落到 `_` 分支）、右边走道具占位文案、
## 顶部一个页签都不高亮，看起来就像"左右两半不是同一个界面"。
var _material_usage_id:=""
var _filter: StringName = &"gear"
## 技能页 / 天赋页当前选中的条目（详情面板用）
var _selected_skill: StringName = &""
var _selected_talent: StringName = &""
## 页签定义：id -> 显示名
func skill_key(slot:int)->String:return KeyBindings.label(["skill_1","skill_2","skill_3","ultimate"][slot])
func talent_groups()->Array:
	return GameState.talent_groups()

const TABS: Array = [
	[&"gear", "装备"], [&"relic", "遗物"], [&"potion", "药剂"], [&"material", "材料"],
	[&"skill", "技能"], [&"talent", "天赋"], [&"stat", "属性"],
]
## 属性页每条属性前面的图标（取自 Cooked Pixel Icons 里语义最接近的那张）
const STAT_ICONS := {
	&"level": "res://assets/icons/08_Magic/0061_spellbook_arcane.png",
	&"attack": "res://assets/icons/01_Weapons/0001_sword_steel.png",
	&"max_hp": "res://assets/icons/12_Status_UI/0087_heart.png",
	&"crit_chance": "res://assets/icons/12_Status_UI/0093_lightning.png",
	&"move_speed": "res://assets/icons/02_Armor/0013_boots_iron.png",
	&"mp_regen": "res://assets/icons/08_Magic/0065_mana_crystal_frost.png",
	&"lifesteal": "res://assets/icons/03_Potions/0025_heart_bottle_love.png",
	&"thorns": "res://assets/icons/02_Armor/0014_round_shield_steel.png",
	&"coin_gain": "res://assets/icons/10_Loot_Currency/0074_coin_gold.png",
}


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build()
	_root.visible = false
	EventBus.run_started.connect(func(_id: int) -> void: _tab_memory.clear(); _selected = {}; _selected_skill = &""; _selected_talent = &"")
	EventBus.item_acquired.connect(func(_item: Dictionary) -> void: _refresh_if_open())
	EventBus.equipment_changed.connect(_refresh_if_open)
	EventBus.coins_changed.connect(func(_c: int) -> void: _refresh_counters())
	EventBus.keys_changed.connect(func(_k: int) -> void: _refresh_counters())


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if not UIFlow.can_open(self): return
	if _root.visible and not _closing:
		return
	_closing = false
	if _close_tween != null and _close_tween.is_valid():
		_close_tween.kill()
	# 每次打开才选一次；翻页、装备及刷新属性不随机换图。
	(_portrait_node as TextureRect).texture = load(LegendarySets.portrait())
	_character_name.text = Characters.current_name()
	_character_job.text = "%s  /  星辉旅人" % Characters.current_job()
	# 顺序很重要：先让界面可见，_rebuild 里的计数刷新才不会被「还没打开」挡掉
	_root.visible = true
	_rebuild()
	UIFlow.push_screen(self)
	opened.emit()
	_play_open_animation()
	_focus_active_tab.call_deferred()


func _play_open_animation() -> void:
	## 打开背包：右侧面板从 0.94 弹到 1.0（带回弹）并淡入；
	## 左侧立绘从画面外滑进来，比面板稍晚一点点，形成"先开盖、再亮人"的层次。
	## 注意动画期间游戏是暂停的，所以 tween 必须设成 TWEEN_PAUSE_PROCESS。
	if _panel != null:
		_panel.pivot_offset = _panel.size * 0.5
		_panel.scale = Vector2.ONE if ComicMotion.reduced() else Vector2.ONE * 0.98
		_panel.modulate.a = 0.0
		if _open_tween != null and _open_tween.is_valid():
			_open_tween.kill()
		var pt := _panel.create_tween()
		_open_tween = pt
		pt.set_parallel(true)
		pt.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		pt.tween_property(_panel, "scale", Vector2.ONE, (0.10 if ComicMotion.reduced() else 0.22)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pt.tween_property(_panel, "modulate:a", 1.0, (0.10 if ComicMotion.reduced() else 0.18))
	if _portrait_node != null:
		var base := Vector2(0, 76)
		_portrait_node.position = base if ComicMotion.reduced() else base + Vector2(-32.0, 0.0)
		_portrait_node.modulate.a = 0.0
		if _portrait_tween != null and _portrait_tween.is_valid():
			_portrait_tween.kill()
		var pt2 := _portrait_node.create_tween()
		_portrait_tween = pt2
		pt2.set_parallel(true)
		pt2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		pt2.tween_property(_portrait_node, "position", base, (0.10 if ComicMotion.reduced() else 0.22)).set_delay(0.0) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		pt2.tween_property(_portrait_node, "modulate:a", 1.0, (0.10 if ComicMotion.reduced() else 0.22)).set_delay(0.0)
	if _caption_node != null:
		_caption_node.modulate.a = 0.0
		if _caption_tween != null and _caption_tween.is_valid():
			_caption_tween.kill()
		var pt3 := _caption_node.create_tween()
		_caption_tween = pt3
		pt3.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		pt3.tween_property(_caption_node, "modulate:a", 1.0, (0.10 if ComicMotion.reduced() else 0.18)).set_delay(0.0 if ComicMotion.reduced() else 0.04)


func close() -> void:
	if not _root.visible or _closing:
		return
	# 关闭也走一小段收拢动画（面板缩回 + 淡出），播完再真正隐藏并解除暂停。
	_closing = true
	for running in [_open_tween, _portrait_tween, _caption_tween]:
		if running != null and running.is_valid():
			running.kill()
	var t := create_tween()
	_close_tween = t
	t.set_parallel(true)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _panel != null:
		t.tween_property(_panel, "scale", Vector2.ONE if ComicMotion.reduced() else Vector2.ONE * 0.98, (0.08 if ComicMotion.reduced() else 0.14)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(_panel, "modulate:a", 0.0, (0.08 if ComicMotion.reduced() else 0.14))
	if _portrait_node != null:
		t.tween_property(_portrait_node, "modulate:a", 0.0, (0.08 if ComicMotion.reduced() else 0.12))
	if _caption_node != null:
		t.tween_property(_caption_node, "modulate:a", 0.0, (0.08 if ComicMotion.reduced() else 0.12))
	t.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	_pending_sale={}
	if is_instance_valid(_sale_confirm):_sale_confirm.close()
	for running in [_open_tween, _portrait_tween, _caption_tween]:
		if running != null and running.is_valid():
			running.kill()
	if _close_tween != null and _close_tween.is_valid():
		_close_tween.kill()
	_closing = false
	_root.visible = false
	if _panel != null:
		_panel.scale = Vector2.ONE
		_panel.modulate.a = 1.0
	if _portrait_node != null:
		_portrait_node.modulate.a = 1.0
	if _caption_node != null:
		_caption_node.modulate.a = 1.0
	UIFlow.pop_screen(self)
	closed.emit()


func _input(event: InputEvent) -> void:
	if not UIFlow.is_top(self): return
	if not _root.visible or _closing:
		return
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		var focused:=get_viewport().gui_get_focus_owner()
		if focused!=null and _shell.is_ancestor_of(focused):
			if focused.has_meta("inventory_slot"):
				_unequip(StringName(focused.get_meta("inventory_slot")));get_viewport().set_input_as_handled();return
			if focused.has_meta("inventory_item"):
				var item:Dictionary=focused.get_meta("inventory_item")
				if ItemDB.can_equip(item):
					_equip(item);get_viewport().set_input_as_handled();return
	if event.is_action_pressed("talents"):
		_finish_close()
		if get_parent() != null and get_parent().has_method("open_talents"):
			get_parent().open_talents()
		get_viewport().set_input_as_handled()
		return
	# 注意：背包打开时游戏是暂停的，主节点收不到输入，
	# 所以「按 Tab 关闭」必须在这里处理。
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


func _refresh_if_open() -> void:
	if _root.visible:
		_rebuild()


func _refresh_counters() -> void:
	if not _root.visible:
		return
	_bag_count.text = "遗物不占格" if _filter == &"relic" else ("%d / 24 格" % GameState.bag_slots({},_filter) if _filter in [&"gear",&"material",&"potion"] else "分类容量各24格")
	_refresh_footer()


## ---------------- 构建 ----------------

func _place_layout(node:Control,rect:Rect2)->void:
	node.position=rect.position;node.size=rect.size
	UiArtLayout.register("inventory",node,rect,str(node.get_meta("art_layout_id","")))

func _build() -> void:
	_root=UiFactory.full_rect();_root.theme=PixelUi.theme();add_child(_root);_root.add_child(UiFactory.dim_layer(0.42))
	_shell=preload("res://src/ui/inventory_shell.tscn").instantiate();_root.add_child(_shell)
	_panel=_shell.get_node("Panel");_panel.set_meta("ui_layout_canvas",true);_panel.add_theme_stylebox_override("panel",InteractionSkin.style("inventory"))
	var content:=_shell.get_node("Panel/Content") as Control
	var items_glass:=Panel.new();items_glass.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(items_glass);_place_layout(items_glass,Rect2(47,235,894,636));content.move_child(items_glass,0);items_glass.add_theme_stylebox_override("panel",InteractionSkin.style("inventory"))
	_portrait_node=_shell.get_node("Portrait");(_portrait_node as TextureRect).texture=load(Characters.portrait_path());_portrait_node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_portrait_node.mouse_filter=Control.MOUSE_FILTER_STOP
	_portrait_node.gui_input.connect(func(event:InputEvent)->void:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT or event is InputEventScreenTouch and event.pressed:
			if Time.get_ticks_msec()-int(_portrait_node.get_meta("last_portrait_tap",0))<120:return
			_portrait_node.set_meta("last_portrait_tap",Time.get_ticks_msec());(_portrait_node as TextureRect).texture=load(LegendarySets.next_portrait());_portrait_node.accept_event())
	_caption_node=_shell.get_node("Caption");_character_name=PixelUi.title(Characters.current_name(),28,Color("f4dfaf"));_character_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_caption_node.add_child(_character_name)
	_character_job=PixelUi.label(Characters.current_job()+" / 星辉旅人",18,Color("b3c2d9"));_character_job.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_caption_node.add_child(_character_job)
	var header:=_build_titlebar();content.add_child(header);_place_layout(header,Rect2(120,50,1280,84))
	var tabs:=_build_tabs();content.add_child(tabs);_place_layout(tabs,Rect2(100,155,1340,72))
	_toolbar=Control.new();content.add_child(_toolbar);_place_layout(_toolbar,Rect2(94,243,816,42))
	_sort_button=PixelUi.compact_button("排序：获得时间",20);_sort_button.custom_minimum_size=Vector2(220,42);_toolbar.add_child(_sort_button);_place_layout(_sort_button,Rect2(380,0,220,42))
	_sort_button.pressed.connect(func()->void:_sort_mode=(_sort_mode+1)%3;_sort_button.text=["排序：获得时间","排序：品质","排序：名称"][_sort_mode];_rebuild())
	_gear_filter=OptionButton.new();_gear_filter.custom_minimum_size=Vector2(200,42);_gear_filter.add_theme_font_size_override("font_size",20)
	for caption in ["全部部位","武器","护甲","饰品"]:_gear_filter.add_item(caption)
	_toolbar.add_child(_gear_filter);_place_layout(_gear_filter,Rect2(616,0,200,42));_gear_filter.item_selected.connect(func(index:int)->void:_gear_part=[&"",&"weapon",&"armor",&"accessory"][index];_selected={};_rebuild())
	var items:=_shell.get_node("Panel/Content/Body/ItemsScroll/Items") as VBoxContainer
	_grid=GridContainer.new();_grid.columns=COLS;_grid.add_theme_constant_override("h_separation",11);_grid.add_theme_constant_override("v_separation",11);items.add_child(_grid)
	_page_box=UiFactory.vbox(12);items.add_child(_page_box)
	_grid_hint=PixelUi.label("",18,PixelUi.MUTED);_grid_hint.hide();content.add_child(_grid_hint);_place_layout(_grid_hint,Rect2(96,706,810,28))
	_equip_box=UiFactory.hbox(22);_equip_wrapper=_build_equip_row();content.add_child(_equip_wrapper);_place_layout(_equip_wrapper,Rect2(306,718,360,140))
	var detail:=_shell.get_node("Panel/Content/Body/Detail") as PanelContainer;detail.set_meta("interaction_paper",true)
	_detail_box=_shell.get_node("Panel/Content/Body/Detail/DetailScroll/Details")
	UiArtLayout.register("inventory",detail,Rect2(948,235,545,635),"details")
	UiArtLayout.register("inventory",_shell.get_node("Panel/Content/Body/ItemsScroll"),Rect2(83,290,834,412),"items")
	var actions:=Control.new();content.add_child(actions);_place_layout(actions,Rect2(160,885,1220,70))
	_sell_button=PixelUi.button("售卖",24,0,70);_sell_button.set_meta("art_layout_id","sale");_bind_button=PixelUi.button("绑定",24,0,70);_bind_button.set_meta("art_layout_id","binding");var close_button:=PixelUi.button("关闭",24,0,70);close_button.set_meta("art_layout_id","close")
	for button in [_sell_button,_bind_button,close_button]:
		actions.add_child(button);_place_layout(button,Rect2((actions.get_child_count()-1)*416,0,388,70))
	_sell_button.pressed.connect(func()->void:
		if not _selected.is_empty():_sell(_selected,ExpeditionData.sale_value(_selected)))
	_bind_button.pressed.connect(func()->void:
		if not _claim_action() or _selected.is_empty():return
		var ok:=GameState.bind_inventory_equipment(_selected);_rebuild();ComicMotion.feedback(_shell,"装备已绑定" if ok else "无法绑定，未扣费"))
	close_button.pressed.connect(close)
	get_viewport().size_changed.connect(_layout_shell);_layout_shell()
	InteractionSkin.mount(_root,"inventory",_panel)

func _layout_shell() -> void:
	if _shell==null:return
	var view:=get_viewport().get_visible_rect().size
	var area:=MobileControls.safe_rect() if MobileControls.enabled() else Rect2(Vector2.ZERO,view)
	var factor:=minf(1.0,minf((area.size.x-24)/SHELL_SIZE.x,(area.size.y-24)/SHELL_SIZE.y))
	_shell.scale=Vector2.ONE*maxf(.1,factor);_shell.position=area.position+(area.size-SHELL_SIZE*_shell.scale)*.5

func _refresh_footer()->void:
	if _sell_button==null:return
	var item:=_selected if _filter in [&"gear",&"relic",&"potion",&"material"] else {}
	var value:=ExpeditionData.sale_value(item);var fee:=BoundEquipment.binding_price(item)
	_sell_button.text="售卖 · +%d金"%value if value>0 else "售卖";_sell_button.disabled=value<=0 or not (GameState.items.has(item) or GameState.is_equipped(item))
	_bind_button.text="绑定 · %d金"%fee if fee>0 else "绑定";_bind_button.disabled=fee<=0 or CampSession.active or not GameState.items.has(item) or GameState.coins<fee
	_sell_button.tooltip_text="选择可出售的物品" if item.is_empty() else "此物品不可出售" if value<=0 else "出售绑定装备前会再次确认" if BoundEquipment.is_bound(item) else "出售所选物品，获得%d金"%value
	_bind_button.tooltip_text="营地训练物品不能付费绑定" if CampSession.active else BoundEquipment.description() if BoundEquipment.is_bound(item) else "请先卸下这件装备" if GameState.is_equipped(item) else "仅稀有或传说装备可以付费绑定" if fee<=0 else "金币不足，还差%d金"%(fee-GameState.coins) if GameState.coins<fee else "支付%d金，将这件装备改为绑定装备"%fee

func _build_titlebar() -> Control:
	var row:=Control.new();var title:=PixelUi.title("旅人的行囊",65)
	row.add_child(title);title.set_meta("art_layout_id","bag_title");_place_layout(title,Rect2(260,0,760,84));title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_bag_count=PixelUi.label("",20,PixelUi.MUTED);row.add_child(_bag_count);_bag_count.set_meta("art_layout_id","bag_capacity");_place_layout(_bag_count,Rect2(1060,0,220,84));_bag_count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	return row

func _build_tabs() -> Control:
	## 页签：装备 / 遗物 / 药剂 / 技能 / 天赋 / 属性
	## 技能与天赋不再是独立面板，全部并进背包这里。
	var row := Control.new()
	for entry in TABS:
		var id: StringName = entry[0]
		var button := PixelUi.tab_button(str(entry[1]), id == _filter, 17)
		button.custom_minimum_size = Vector2(0,72)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.set_meta("interaction_asset","tab_plate")
		button.pressed.connect(func() -> void:
			_last_click_key = ""
			_tab_memory[_filter] = {"item": _selected, "skill": _selected_skill, "talent": _selected_talent, "scroll": (_shell.get_node("Panel/Content/Body/ItemsScroll") as ScrollContainer).scroll_vertical}
			_filter = id
			var memory: Dictionary = _tab_memory.get(id, {})
			_selected = memory.get("item", {})
			if not _selected.is_empty() and not GameState.items.has(_selected): _selected = {}
			_selected_skill = StringName(memory.get("skill", &""))
			_selected_talent = StringName(memory.get("talent", &""))
			_rebuild()
			_restore_tab_scroll(id)
			ComicMotion.reveal(_grid if _grid.visible else _page_box, 0.12)
		)
		_tab_ids.append(id)
		_tab_labels.append(str(entry[1]))
		_tab_buttons.append(button)
		row.add_child(button)
		button.set_meta("art_layout_id","tab_"+str(id));_place_layout(button,Rect2((_tab_buttons.size()-1)*194,0,176,72))
	_refresh_tab_counts()
	return row


func _refresh_tab_counts() -> void:
	## 页签件数：装备 / 遗物 / 药剂 / 技能 / 天赋 / 属性
	var gear_count := 0
	var relic_count := 0
	var potion_count := 0
	var material_count := 0
	for item in GameState.items:
		if ItemDB.is_material(item):
			material_count += 1
		elif ItemDB.is_usable(item):
			potion_count += 1
		elif ItemDB.is_equippable(item):
			gear_count += 1
		else:
			relic_count += 1
	var skill_count := GameState.unlocked_skills.size()
	for i in _tab_buttons.size():
		var id: StringName = _tab_ids[i]
		var text: String = _tab_labels[i]
		match id:
			&"gear":
				text += " %d" % gear_count
			&"relic":
				text += " %d" % relic_count
			&"potion":
				text += " %d" % potion_count
			&"material":
				text += " %d" % material_count
			&"skill":
				text += " %d" % skill_count
			&"talent":
				text += " %d" % GameState.talent_points
			&"stat":
				text += " Lv%d" % GameState.level
		_tab_buttons[i].text = text
		var active: bool = _tab_ids[i] == _filter
		_tab_buttons[i].disabled = false
		# 页签底图是「创建时算一次」的样式，切换页签必须重新算一遍，否则高亮不会跟着动
		PixelUi.apply_tab_style(_tab_buttons[i], active)
		_tab_buttons[i].set_meta("interaction_selected",active)
		InteractionSkin.apply_button(_tab_buttons[i],"inventory")


func _build_equip_row() -> Control:
	## 装备栏：三个格子横排，上面一行小标题
	var wrapper := UiFactory.vbox(4)
	wrapper.add_child(PixelUi.label("装备栏（每个槽位一件）", 16, PixelUi.MUTED))
	wrapper.add_child(_equip_box)
	return wrapper


## ---------------- 刷新内容 ----------------

func _rebuild() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var token := str(focused.get_meta("focus_token", "")) if focused != null else ""
	for child in _equip_box.get_children():
		_equip_box.remove_child(child)
		child.queue_free()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for child in _page_box.get_children():
		_page_box.remove_child(child)
		child.queue_free()

	# 物品页用格子，技能/天赋/属性页用整块页面
	var is_item_tab := _filter == &"gear" or _filter == &"relic" or _filter == &"potion" or _filter == &"material"
	_grid.visible = is_item_tab
	_toolbar.visible = is_item_tab
	_gear_filter.visible=_filter==&"gear"
	_equip_wrapper.visible = _filter == &"gear" or _filter == &"potion"
	(_equip_wrapper.get_child(0) as Label).text = "已装备" if _filter == &"gear" else "药剂快捷栏"
	if _grid_hint != null:
		_grid_hint.visible = is_item_tab
	_refresh_footer()
	_page_box.visible = not is_item_tab
	if is_item_tab:
		_rebuild_item_page()
	else:
		match _filter:
			&"skill":
				_rebuild_skill_page()
			&"talent":
				_rebuild_talent_page()
			_:
				_rebuild_stat_page()

	_rebuild_detail()
	_refresh_counters()
	_refresh_tab_counts()
	_wrap_paragraphs(_page_box)
	_wrap_paragraphs(_detail_box)
	UiArtLayout.refresh(_panel)
	InteractionSkin.apply_tree(_panel,"inventory")
	_panel.add_theme_stylebox_override("panel",InteractionSkin.style("inventory"))
	var paper:=_shell.get_node("Panel/Content/Body/Detail") as PanelContainer
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:paper.get_theme_stylebox("panel").set_content_margin(side,36)
	_gear_filter.text=_gear_filter.get_item_text(_gear_filter.selected);InteractionSkin.apply_button(_gear_filter,"inventory",true)
	_fit_details(_detail_box)
	_fit_page_text(_page_box)
	if token != "":
		_restore_focus.call_deferred(token)


func _rebuild_item_page() -> void:
	## 装备页顺带显示三个装备槽；药剂页顺带显示快捷栏
	if _filter == &"gear":
		for slot: StringName in ItemDB.SLOTS:
			_equip_box.add_child(_build_equip_slot(slot))
	elif _filter == &"potion":
		for i in GameState.HOTBAR_SIZE:
			_equip_box.add_child(_build_hotbar_slot(i))

	var ordered: Array[Dictionary] = []
	for item in _bag_entries():
		var usable := ItemDB.is_usable(item)
		var equippable := ItemDB.is_equippable(item)
		if _filter == &"gear" and not equippable:
			continue
		if _filter==&"gear" and _gear_part!=&"" and ItemDB.slot_of(item)!=_gear_part:continue
		if _filter == &"relic" and (equippable or usable or ItemDB.is_material(item)):
			continue
		if _filter == &"potion" and not usable:
			continue
		if _filter == &"material" and not ItemDB.is_material(item): continue
		ordered.append(item)
	if _sort_mode == 1:
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("rarity", 0)) > int(b.get("rarity", 0)))
	elif _sort_mode == 2:
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("name", "")) < str(b.get("name", "")))
	if not _selected.is_empty() and not (_filter == &"gear" and GameState.is_equipped(_selected)):
		var id: Variant = _selected.get("uid",_selected.get("id", &""))
		var found := false
		for item in ordered:
			if item.get("uid",item.get("id")) == _selected.get("uid",id):
				_selected = item
				found = true
				break
		if not found:
			var index := maxi(0, _ordered_ids.find(id))
			_selected = ordered[mini(index, ordered.size()-1)] if not ordered.is_empty() else {}
	_ordered_ids.clear()
	for item in ordered: _ordered_ids.append(item.get("uid",item.get("id")))
	for item in ordered:
		_grid.add_child(_build_item_slot(item))
	for i in maxi(0, COLS * ROWS - ordered.size()):
		var empty := PixelUi.slot_button(Color(1.0, 1.0, 1.0, 0.55), SLOT_SIZE)
		empty.disabled = true
		_grid.add_child(empty)


func _build_hotbar_slot(index: int) -> Control:
	## 药剂快捷栏格子（战斗里按 1/2/3 使用）
	var item: Dictionary = GameState.potion_hotbar[index] if index < GameState.potion_hotbar.size() else {}
	var tint := ItemDB.rarity_color(int(item["rarity"])) if not item.is_empty() else Color(0.72, 0.66, 0.58)
	var column := UiFactory.vbox(2)
	column.custom_minimum_size = Vector2(70.0, 0.0)
	var button := PixelUi.slot_button(Color(tint.r, tint.g, tint.b, 0.62), EQUIP_SLOT)
	_quality_slot(button,tint)
	if item.is_empty():
		button.disabled = true
	else:
		button.icon = _icon_for(item)
		BoundEquipment.badge(button,item)
		button.expand_icon = true
		button.tooltip_text = "%s\n点一下取消绑定" % str(item["name"])
		button.pressed.connect(func() -> void:
			if not _claim_action(): return
			GameState.clear_hotbar_slot(index)
			_rebuild()
			ComicMotion.feedback(_shell, "快捷栏 %d 已清空" % (index+1))
		)
	column.add_child(button)
	var key := PixelUi.label("快捷 %d" % (index + 1), 14, PixelUi.MUTED)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(key)
	return column


## ---------------- 技能页 ----------------




func _rebuild_skill_page() -> void:
	_page_box.add_child(PixelUi.label("当前配装  ·  3 个普通技能 + 1 个大招", 18))
	var equipped := UiFactory.hbox(12)
	_page_box.add_child(equipped)
	for slot in 4:
		var id := GameState.skill_for_slot(slot)
		equipped.add_child(_skill_tile(id, skill_key(slot), id == &""))
	_page_box.add_child(PixelUi.label(("箭术与自然技能" if Characters.current_id()==&"ilyua" else "法术库")+"  ·  点击图标，在右侧选择装配栏位", 17))
	var gallery := GridContainer.new()
	gallery.columns = 4
	gallery.add_theme_constant_override("h_separation", 12)
	gallery.add_theme_constant_override("v_separation", 8)
	_page_box.add_child(gallery)
	for id: StringName in Skills.order_for():
		var unlocked := GameState.unlocked_skills.has(id)
		var name_text := str(Skills.get_skill(id,GameState.combat_mode).name)
		if not unlocked:
			name_text += " · %d级" % Skills.unlock_level(id)
		gallery.add_child(_skill_tile(id, name_text, not unlocked))
	gallery.tooltip_text = "本局已解锁的法术全部保留；换装保留该法术剩余冷却。"

func _skill_tile(id: StringName, caption: String, locked: bool) -> Control:
	var column := UiFactory.vbox(3)
	column.custom_minimum_size.x = 104
	var button := PixelUi.slot_button(PixelUi.GOLD if id == _selected_skill and id != &"" else PixelUi.LINE, 78)
	button.set_meta("focus_token", "skill:" + str(id) + ":" + caption)
	button.custom_minimum_size = Vector2(104, 78)
	var icon := UiFactory.texture_icon(str(Skills.get_skill(id,GameState.combat_mode).get("icon", Skills.FRAME_EMPTY)), 68)
	icon.position = Vector2(18, 5)
	icon.size = Vector2(68, 68)
	icon.modulate = Color(0.6, 0.65, 0.73, 0.7) if locked else Color.WHITE
	button.add_child(icon)
	if locked and id != &"":
		var lock := UiFactory.texture_icon(Skills.FRAME_LOCKED, 22)
		lock.position = Vector2(78, 3)
		button.add_child(lock)
	button.disabled = id == &""
	button.tooltip_text = str(Skills.get_skill(id,GameState.combat_mode).get("desc", "尚未装配"))
	button.pressed.connect(func() -> void:
		_selected_skill = id
		_rebuild()
	)
	column.add_child(button)
	var label := PixelUi.label(caption, 13, PixelUi.MUTED if locked else PixelUi.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 104
	column.add_child(label)
	return column

## ---------------- 天赋页（分叉树）----------------

func _rebuild_talent_page() -> void:
	_page_box.add_child(PixelUi.label(
		"可用天赋点：%d　（每 3 级获得 1 点）" % GameState.talent_points, 18, PixelUi.INK))
	# 树状图现在独立成窗口（按 T 打开，支持缩放），这里只放入口与前置说明
	_page_box.add_child(PixelUi.label(
		"按 [%s] 打开天赋树 · 滚轮缩放、拖拽平移"%KeyBindings.label("talents"), 15, PixelUi.MUTED))
	# 入口按钮改用主菜单那套「白芯 + 描金花边」的底图：够醒目，也比土黄色更贴合圣洁风
	var open_button := PixelUi.compact_button("天赋树 [%s]"%KeyBindings.label("talents"), 21)
	open_button.custom_minimum_size = Vector2(252.0, 50.0)
	open_button.pressed.connect(func() -> void:
		# 关掉背包再开天赋树，避免两层界面互相抢输入
		_finish_close()
		if get_parent() != null and get_parent().has_method("open_talents"):
			get_parent().open_talents()
	)
	_page_box.add_child(open_button)
	_page_box.add_child(PixelUi.label(
		"点亮节点后可查看下一等级与前置条件", 14, PixelUi.MUTED))
	# 分支进度一览：加点在树窗口里做，这里只让你一眼看到每条线还差多少
	var summary := UiFactory.vbox(3)
	summary.add_child(PixelUi.label("分支进度", 17, PixelUi.INK))
	for entry in talent_groups():
		var group_id: StringName = entry[0]
		var spent := 0
		var total := 0
		for node in _talent_nodes_of(group_id):
			spent += GameState.talent_rank(node)
			total += int(GameState.TALENT_BRANCHES[node]["max_rank"])
		var row := UiFactory.hbox(10)
		var name_label := PixelUi.label(str(entry[1]), 15, PixelUi.INK)
		name_label.custom_minimum_size = Vector2(120.0, 0.0)
		row.add_child(name_label)
		row.add_child(PixelUi.label("%d / %d" % [spent, total], 15, Palette.GOLD))
		summary.add_child(row)
	_page_box.add_child(summary)
	for entry in talent_groups():
		_page_box.add_child(PixelUi.label(str(entry[1]), 18, PixelUi.GOLD))
		for branch in _talent_nodes_of(entry[0]): _page_box.add_child(_build_talent_row(branch))


func _talent_nodes_of(group_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for branch: StringName in GameState.TALENT_BRANCHES:
		if StringName(GameState.TALENT_BRANCHES[branch].get("branch", &"")) == group_id:
			out.append(branch)
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return int(GameState.TALENT_BRANCHES[a].get("tier", 0)) < int(GameState.TALENT_BRANCHES[b].get("tier", 0))
	)
	return out


func _build_talent_row(branch: StringName) -> Control:
	var info: Dictionary = GameState.TALENT_BRANCHES[branch]
	var rank := GameState.talent_rank(branch)
	var max_rank := int(info["max_rank"])
	var unlocked := GameState.talent_unlocked(branch)
	var full := rank >= max_rank
	var tier := int(info.get("tier", 1))

	var row := UiFactory.hbox(8)
	var icon := UiFactory.texture_icon(str(info.get("icon", "")), 30.0)
	icon.modulate = Color.WHITE if unlocked else Color(0.5, 0.5, 0.55, 0.7)
	row.add_child(icon)

	# 层级缩进：一眼看出前置关系
	row.add_child(PixelUi.label("　".repeat(maxi(0, tier - 1)), 16, PixelUi.MUTED))

	var text := UiFactory.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(PixelUi.label("%s　%d / %d" % [str(info["name"]), rank, max_rank], 17, PixelUi.INK))
	if not unlocked:
		text.add_child(PixelUi.label("未解锁：%s" % _requirement_text(info), 14, PixelUi.MUTED))

	var plus := PixelUi.compact_button("已满" if full else "加点", 15)
	plus.custom_minimum_size = Vector2(86.0, 34.0)
	plus.disabled = full or not unlocked or GameState.talent_points <= 0
	plus.tooltip_text=ItemInsight.talent_requirement(branch)
	plus.set_meta("focus_token", "talent_add:" + str(branch))
	plus.pressed.connect(func() -> void:
		_add_talent_point(branch)
	)
	# 「详情」把这一节点送进右侧详情面板（联动）
	var detail := PixelUi.compact_button("详情", 14)
	detail.custom_minimum_size = Vector2(92.0, 34.0)
	detail.tooltip_text = "单击查看，双击投入 1 点"
	detail.set_meta("focus_token", "talent_detail:" + str(branch))
	detail.gui_input.connect(_on_talent_row_input.bind(branch))
	detail.pressed.connect(func() -> void:
		_remember_click("talent:" + str(branch))
		_selected_talent = branch
		_rebuild_detail()
		_wrap_paragraphs(_detail_box)
	)
	row.add_child(detail)
	row.add_child(plus)
	return row


func _requirement_text(info: Dictionary) -> String:
	var requires: Dictionary = info.get("requires", {})
	var parts: Array[String] = []
	for need: StringName in requires:
		parts.append("%s ≥%d" % [str(GameState.TALENT_BRANCHES[need]["name"]), int(requires[need])])
	return "、".join(parts) if not parts.is_empty() else "无"


## ---------------- 属性页 ----------------

func _rebuild_stat_page() -> void:
	_page_box.add_child(PixelUi.label("角色属性", 18, PixelUi.INK))
	var stats := GameState.stats
	# 等级与经验单独一行，带个法术书图标
	var head := UiFactory.hbox(8)
	head.add_child(UiFactory.texture_icon(STAT_ICONS[&"level"], 26.0))
	head.add_child(PixelUi.label("等级 Lv.%d" % GameState.level, 17, PixelUi.INK))
	head.add_child(UiFactory.spacer())
	head.add_child(PixelUi.label(
		"经验 %d / %d" % [int(GameState.exp), int(GameState.exp_needed(GameState.level))],
		15, PixelUi.MUTED))
	_page_box.add_child(head)
	# 每条属性前面挂一个图标（素材库里语义最接近的那张）
	var rows: Array = [
		[&"attack", "攻击力", "%.0f" % stats.get_value(&"attack")],
		[&"max_hp", "最大生命", "%.0f" % stats.get_value(&"max_hp")],
		[&"crit_chance", "暴击率", "%d%%" % int(round(stats.get_value(&"crit_chance") * 100.0))],
		[&"move_speed", "移动速度", "%.0f" % stats.get_value(&"move_speed")],
		[&"mp_regen", "魔法回复速度", "%.2f/秒" % _mp_regen_total(stats)],
		[&"lifesteal", "普攻命中回复", "%.0f 点生命" % stats.get_value(&"lifesteal")],
		[&"thorns", "反伤", "%.0f" % stats.get_value(&"thorns")],
		[&"coin_gain", "金币收益", "%d%%" % int(round(stats.get_value(&"coin_gain") * 100.0))],
	]
	for entry in rows:
		var row := UiFactory.hbox(8)
		row.add_child(UiFactory.texture_icon(str(STAT_ICONS.get(entry[0], "")), 24.0))
		# 图标列 + 名称列都定宽，数值列右对齐 —— 否则「攻击力 14 / 暴击率 0% / 金币收益 100%」
		# 每行的数字起点都不一样，看起来是歪的。
		var name_label := PixelUi.label(str(entry[1]), 15, PixelUi.MUTED)
		name_label.custom_minimum_size = Vector2(112.0, 0.0)
		row.add_child(name_label)
		row.add_child(UiFactory.spacer())
		var value_label := PixelUi.label(str(entry[2]), 16, PixelUi.INK)
		value_label.custom_minimum_size = Vector2(96.0, 0.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		_page_box.add_child(row)


func _build_equip_slot(slot: StringName) -> Control:
	var item: Dictionary = GameState.equipped(slot)
	var filled := not item.is_empty()
	var tint := ItemDB.rarity_color(int(item["rarity"])) if filled else Color(0.72, 0.66, 0.58)
	var column := UiFactory.vbox(2)
	# 槽位下面的两行字（槽位名 + 装备名）以前挤在 70 像素里会自动折行，
	# 折出来的第二行又和下一个槽位贴在一起。加宽到 96 并禁止折行、超出用省略号。
	column.custom_minimum_size = Vector2(96.0, 0.0)

	var button := PixelUi.slot_button(Color(tint.r, tint.g, tint.b, 0.62), EQUIP_SLOT)
	_quality_slot(button,tint)
	if filled:
		button.tooltip_text = "%s\n单击查看，双击或 %s 卸下" % [str(item["name"]),KeyBindings.label("ui_accept")]
		button.set_meta("inventory_slot",slot)
		BoundEquipment.badge(button,item)
		button.icon = _icon_for(item)
		button.expand_icon = true
		button.gui_input.connect(_on_equip_slot_input.bind(slot, item))
		button.pressed.connect(func() -> void:
			_remember_click("equip:" + str(item.get("uid",item.get("id", ""))))
			_selected = item
			_rebuild()
		)
	else:
		button.disabled = true
	button.set_meta("focus_token", "equip:" + str(slot))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(button)

	var slot_name := PixelUi.label(str(ItemDB.SLOT_NAMES.get(slot, slot)), 14, PixelUi.MUTED)
	slot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(slot_name)

	# 装备名通过图标提示展示，避免两行小字挤到内容区域外。
	return column


func _build_item_slot(item: Dictionary) -> Control:
	var border := ItemDB.rarity_color(int(item["rarity"]))
	var is_selected: bool = not _selected.is_empty() and _selected.get("uid",_selected["id"]) == item.get("uid",item["id"])
	var button := PixelUi.slot_button(border, SLOT_SIZE)
	_quality_slot(button,border,is_selected)
	button.set_meta("focus_token", "item:" + str(item.get("uid",item.get("id", ""))))
	button.set_meta("inventory_item",item)
	button.set_meta("interaction_selected",is_selected)
	button.icon = _icon_for(item)
	button.expand_icon = true
	button.tooltip_text = "%s\n%s\n单击查看，双击或 %s 装备" % [str(item["name"]), str(item["desc"]),KeyBindings.label("ui_accept")] if ItemDB.is_equippable(item) else "%s\n%s" % [str(item["name"]), str(item["desc"])]
	BoundEquipment.badge(button,item)
	if int(item.get("stack_count",1))>1:
		var count_label:=PixelUi.label(str(item.stack_count),14,Color.WHITE)
		count_label.position=Vector2(27,27)
		count_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(count_label)

	if ItemDB.is_equippable(item): button.gui_input.connect(_on_item_slot_input.bind(item))
	button.pressed.connect(func() -> void:
		_remember_click("item:" + str(item.get("uid",item.get("id", ""))))
		_selected = item
		_rebuild()
	)
	return button


func _icon_for(item: Dictionary) -> AtlasTexture:
	var texture := ItemDB.icon_texture(item)
	if texture == null:
		return null
	return UiFactory.atlas_texture(texture, ItemDB.icon_region(item))


func _rebuild_detail() -> void:
	_populate_detail()
	if _filter in [&"gear",&"relic",&"potion",&"material"] and not _selected.is_empty():ItemInsight.append_story(_detail_box,_selected,19)
	_fit_details(_detail_box)
	InteractionSkin.apply_tree(_detail_box,"inventory")

func _populate_detail() -> void:
	(_portrait_node as TextureRect).texture=load(LegendarySets.portrait())
	_detail_box.add_theme_constant_override("separation", 12)
	for child in _detail_box.get_children():
		_detail_box.remove_child(child)
		child.queue_free()

	# 技能页 / 天赋页 / 属性页有自己的详情内容
	match _filter:
		&"skill":
			_detail_skill()
			return
		&"talent":
			_detail_talent()
			return
		&"stat":
			_detail_run_summary()
			return

	if _selected.is_empty():
		## 文字对比度：原来标题和三条提示都用 PARCHMENT_TEXT_DIM（很淡的灰褐），
		## 压在米白面板上读起来费劲（画面自查反馈"字偏淡"）。标题换成正文色、字号提一档。
		_detail_box.add_child(PixelUi.label("物品详情", 24, PixelUi.INK))
		_detail_box.add_child(_parchment_rule())
		for text in ["点左侧背包里的格子看详情", "遗物：获得后立即生效", "装备：装到对应槽位才生效"]:
			_detail_box.add_child(PixelUi.label(text, 17, PixelUi.INK))
		return

	var item := _selected
	var rarity := int(item["rarity"])
	var color := ItemDB.rarity_color(rarity)
	var slot := ItemDB.slot_of(item)

	var head := UiFactory.hbox(10)
	_detail_box.add_child(head)
	head.add_child(UiFactory.item_icon(item, 44.0))
	var head_text := UiFactory.vbox(0)
	head_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	head.add_child(head_text)
	head_text.add_child(PixelUi.label(str(item["name"]), 21, PixelUi.INK))
	head_text.add_child(RarityWordmark.line(rarity,str(ItemDB.KIND_NAMES.get(item.get("kind", &"buff"),"道具")),36,20,color.darkened(.25)))

	_detail_box.add_child(_parchment_rule())
	var lines: Array[String] = ItemDB.weapon_lines(item)
	lines.append_array(ItemDB.stat_lines(item))
	if str(item.get("requires_character", "")) == "xixifu" and item.get("kind", &"") != &"weapon":
		lines.append("仅希希芙可使用")
	if lines.is_empty() and not ItemDB.is_usable(item) and not ItemDB.is_material(item):
		_detail_box.add_child(PixelUi.label("（没有属性加成）", 16, PixelUi.MUTED))
	else:
		for line in lines:
			_detail_box.add_child(PixelUi.label("◆ "+line,18,PixelUi.INK))
	# 药剂的 desc 和下面的「效果行」是同一句话，这里不重复显示
	if not ItemDB.is_usable(item) and not str(item["desc"]).is_empty() \
			and (not item.get("mechanics", []).is_empty() or not ItemDB.weapon_lines(item).is_empty() or ItemDB.stat_lines(item).is_empty()):
		var desc := PixelUi.label(("单件机制与触发限制\n" if ItemDB.is_equippable(item) and not item.get("mechanics",[]).is_empty() else "")+str(item["desc"]), 18, PixelUi.INK)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(0.0, 34.0)
		desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_detail_box.add_child(desc)

	var etch_note:=MaterialWorkshopCatalog.description(item)
	if not etch_note.is_empty():
		var note:=PixelUi.label("当前刻印\n"+etch_note,18,PixelUi.GOLD);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_detail_box.add_child(note)
	if ItemDB.is_material(item):
		var material_id:=str(item.id);var uses:=MaterialWorkshop.usage(material_id)
		var totals:=MaterialWorkshop.cost_preview({material_id:0},false)
		var amount:=PixelUi.label(("本局背包" if not CampSession.active else "营地训练背包 · 不消耗永久仓库")+"\n"+MaterialWorkshop.cost_text(totals.rows)+("\n"+uses if not uses.is_empty() else ""),17,PixelUi.GOLD);amount.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_detail_box.add_child(amount)
		var toggle:=PixelUi.compact_button("收起材料用途 ▴" if _material_usage_id==material_id else "查看材料用途 ▾",18);toggle.set_meta("focus_token","material_uses:"+material_id);_detail_box.add_child(toggle)
		toggle.pressed.connect(func()->void:_material_usage_id="" if _material_usage_id==material_id else material_id;_rebuild_detail())
		if _material_usage_id==material_id:
			var note:=PixelUi.label(MaterialWorkshop.uses_text(material_id,CampSession.active),17,PixelUi.INK);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_detail_box.add_child(note)

	if ItemDB.is_relic(item) and not item.get("mechanics", []).is_empty():
		_detail_box.add_child(PixelUi.label("同名效果：1件100% · 2件合计150% · 3件合计175%；目标数、触发条件与冷却不增加", 14, PixelUi.MUTED))

	if ItemDB.is_equippable(item):
		var binding:=UiFactory.vbox(5);_detail_box.add_child(binding)
		var note:=PixelUi.label(BoundEquipment.description() if BoundEquipment.is_bound(item) else "未绑定 · 撤离时自动出售；稀有/传说装备可付费绑定。",14,PixelUi.GOLD);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;binding.add_child(note)

	var set_description:=LegendarySets.description(item)
	if not set_description.is_empty():
		var set_note:=PixelUi.label(set_description,20,PixelUi.GOLD if LegendarySets.complete() else PixelUi.MUTED);set_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_detail_box.add_child(set_note);_detail_box.add_child(_parchment_rule())

	var lost:=ItemInsight.replacement_losses(item) if ItemDB.is_equippable(item) else ""
	if not lost.is_empty():_detail_box.add_child(PixelUi.label(lost,18,Palette.UI_DANGER))
	if ItemDB.is_relic(item):_detail_box.add_child(PixelUi.label(ItemInsight.relic_increment(item),18,PixelUi.GOLD))
	# 装备后的对比（武器比每秒输出/索敌，其它比属性）
	# 药剂：显示效果 + 「使用」按钮（用完就从背包里消失）
	if ItemDB.is_usable(item):
		for line in ItemDB.effect_lines(item):
			_detail_box.add_child(PixelUi.label("◆ %s" % line, 16, Color("9ee6ab")))
		_detail_box.add_child(PixelUi.label("在背包里点「使用」立即生效", 15, PixelUi.MUTED))
		# 快捷栏：把药剂放到 1/2/3 上，战斗中点一下就喝
		var hotbar_row := UiFactory.hbox(6)
		_detail_box.add_child(PixelUi.label("放到快捷栏：", 15, PixelUi.MUTED))
		for i in GameState.HOTBAR_SIZE:
			var assigned: bool = i < GameState.potion_hotbar.size() \
				and GameState.potion_hotbar[i].get("id", &"") == item["id"]
			var slot_button := PixelUi.compact_button("移出快捷栏 %d" % (i + 1) if assigned else "放入快捷栏 %d" % (i + 1), 16)
			slot_button.custom_minimum_size = Vector2(72.0, 34.0)
			slot_button.pressed.connect(func() -> void:
				if not _claim_action(): return
				if assigned:
					GameState.clear_hotbar_slot(i)
				else:
					GameState.set_hotbar_slot(i, item)
				_rebuild()
				ComicMotion.feedback(_shell, "快捷栏 %d 已%s" % [i+1, "清空" if assigned else "配置"])
			)
			hotbar_row.add_child(slot_button)
		_detail_box.add_child(hotbar_row)
		var use := PixelUi.compact_button("使用", 19)
		use.custom_minimum_size = Vector2(0.0, 44.0)
		use.pressed.connect(func() -> void:
			if not _claim_action(): return
			if GameState.use_item(item):
				_rebuild()
				ComicMotion.feedback(_shell, "已使用 %s" % item.name)
		)
		_detail_box.add_child(use)
		_detail_box.add_child(_sell_row(item))
		return

	if ItemDB.is_equippable(item) and not GameState.is_equipped(item) and ItemDB.can_equip(item):
		var preview := GameState.preview_with(item)
		var rows: Array = []
		for entry in [[&"attack", "攻击力", 0], [&"attack_speed", "攻击速度", 0], [&"max_hp", "最大生命", 0], [&"move_speed", "移动速度", 0], [&"mp_regen", "魔法回复速度", 0], [&"crit_chance", "暴击率", 1], [&"lifesteal", "命中回复", 0], [&"crit_mult", "暴击伤害", 1], [&"dash_cooldown", "冲刺冷却", 0], [&"thorns", "反伤", 0], [&"coin_gain", "金币收益倍率", 0]]:
			var stat := StringName(entry[0])
			var before := _mp_regen_total(GameState.stats) if stat == &"mp_regen" else GameState.stats.get_value(stat)
			var after := _mp_regen_total(preview) if stat == &"mp_regen" else preview.get_value(stat)
			if absf(after - before) < 0.001:
				continue
			rows.append(_compare_row(
				str(entry[1]),
				"%.2f/秒" % before if stat == &"mp_regen" else ItemInsight.stat_text(stat, before),
				"%.2f/秒" % after if stat == &"mp_regen" else ItemInsight.stat_text(stat, after),
				after - before
			))
		if not rows.is_empty():
			_detail_box.add_child(_parchment_rule())
			_detail_box.add_child(PixelUi.label("装备后", 15, PixelUi.MUTED))
			for row in rows:
				_detail_box.add_child(row)

	if not ItemDB.is_equippable(item):
		# 材料（采集来的发光蘑菇）在这里给一个售卖入口 ——
		# 遗物是"拿到就生效"，材料是"拿去换钱"，两者要分清楚。
		if ItemDB.is_material(item):
			_detail_box.add_child(PixelUi.label(
				"材料：撤回后入仓库，可提交委托或兑换", 15, PixelUi.MUTED))
			_detail_box.add_child(_sell_row(item))
		else:
			_detail_box.add_child(PixelUi.label("遗物持有即生效 · 出售后重新加入物品池", 15, PixelUi.MUTED))
			if ItemDB.is_relic(item):_detail_box.add_child(_sell_row(item))
		return

	if GameState.is_equipped(item):
		if MobileControls.enabled():
			var unequip:=PixelUi.primary("卸下装备",18)
			unequip.pressed.connect(func()->void:_unequip(slot))
			_detail_box.add_child(unequip)
		_detail_box.add_child(PixelUi.label("点按「卸下装备」，或双击已装备格" if MobileControls.enabled() else "双击上方已装备格卸下", 16, PixelUi.MUTED))
		_detail_box.add_child(_sell_row(item))
		return

	var current: Dictionary = GameState.equipped(slot)
	if MobileControls.enabled():
		var equip:=PixelUi.primary("装备",18);equip.disabled=not ItemDB.can_equip(item)
		equip.pressed.connect(func()->void:_equip(item));_detail_box.add_child(equip)
	if not current.is_empty():
		_detail_box.add_child(PixelUi.label("将替换：%s" % str(current["name"]), 18, PixelUi.GOLD))
	_detail_box.add_child(PixelUi.label(("点按「装备」，或双击背包格" if MobileControls.enabled() else "双击背包格或按 %s 装备"%KeyBindings.label("ui_accept")) if ItemDB.can_equip(item) else "职业不符 · 无法装备", 16, PixelUi.MUTED))
	_detail_box.add_child(_sell_row(item))


func _sell_row(item: Dictionary) -> Control:
	var row:=UiFactory.vbox(8)
	var price:=ExpeditionData.sale_value(item)
	row.add_child(PixelUi.label("单份售价 %d 金 · 可在背包直接售卖" % price if price>0 else "首领专属材料 · 保留用于刻印与研究" if MaterialWorkshopCatalog.BOSS_MATERIALS.has(str(item.id)) else "不可售卖 · 留给委托或营地兑换",16,PixelUi.MUTED))
	if ItemDB.is_material(item):
		row.add_child(PixelUi.label("仓库已有 %d 份%s" % [int(Outpost.data.inventory.get(str(item.id),0))," · 独立蘑菇格，最多999" if str(item.id).begins_with("glow_mushroom_") else " · 撤回后占用仓位"],16,PixelUi.GOLD))
		if Outpost.task_reserves().has(str(item.id)):
			var warning=PixelUi.label("未完成委托需要此材料 · 出售会减少本次携带的委托材料",15,PixelUi.GOLD);warning.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(warning)

	return row

func _sell(item: Dictionary, price: int) -> void:
	if not _claim_action():return
	if BoundEquipment.is_bound(item):
		if not is_instance_valid(_sale_confirm):
			_sale_confirm=SaleConfirmUI.new();_sale_confirm.title_text="出售绑定装备？";add_child(_sale_confirm)
			_sale_confirm.confirmed.connect(func()->void:
				var selected:=_pending_sale;_pending_sale={}
				if is_open() and not selected.is_empty():_commit_sale(selected,ExpeditionData.sale_value(selected)))
			_sale_confirm.canceled.connect(func()->void:_pending_sale={})
		_pending_sale=item;_sale_confirm.open("%s ×1\n出售收益：%d 金\n\n此装备已绑定，原本可以在成功撤离后带回仓库。确认后将出售这件装备。"%[str(item.name),ExpeditionData.sale_value(item)]);return
	_commit_sale(item,price)
func _commit_sale(item:Dictionary,price:int)->void:
	if GameState.sell_item(item):
		_rebuild()
		ComicMotion.feedback(_shell,"已售卖 %s · +%d金" % [str(item.name),price])

func _fit_details(node:Node)->void:
	if node is Label:
		if not node.has_meta("detail_base_font"):node.set_meta("detail_base_font",node.get_theme_font_size("font_size"))
		node.add_theme_font_size_override("font_size",clampi(int(node.get_meta("detail_base_font"))+5,24,30))
		node.add_theme_constant_override("line_spacing",5)
		node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		node.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;node.vertical_alignment=VERTICAL_ALIGNMENT_TOP
		node.custom_minimum_size.x=0
	if node is VBoxContainer:node.add_theme_constant_override("separation",12)
	for child in node.get_children():_fit_details(child)

func _fit_page_text(node:Node)->void:
	if node is Label:node.add_theme_font_size_override("font_size",clampi(node.get_theme_font_size("font_size")+4,20,26))
	for child in node.get_children():_fit_page_text(child)

func _parchment_rule() -> Control:
	var line := ColorRect.new()
	line.color = PixelUi.LINE
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## ---------------- 技能 / 天赋 / 属性 的详情面板 ----------------

func _detail_skill() -> void:
	_detail_box.add_theme_constant_override("separation", 6)
	if _selected_skill == &"":
		_detail_box.add_child(PixelUi.label("精灵箭术" if Characters.current_id()==&"ilyua" else ("影契法术" if Characters.current_id()==&"xixifu" else "圣光祷术"), 24))
		_detail_box.add_child(PixelUi.label("点击左侧图标查看法术，再选择要装配的栏位。", 16))
		return
	var skill := Skills.get_skill(_selected_skill,GameState.combat_mode)
	var icon := UiFactory.texture_icon(str(skill.icon), 80)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_box.add_child(icon)
	_detail_box.add_child(PixelUi.label(str(skill.name), 24))
	_detail_box.add_child(PixelUi.label("%s · %s" % [str(skill.role), "大招" if Skills.is_ultimate(_selected_skill) else "普通技能"], 14, PixelUi.GOLD))
	_detail_box.add_child(_parchment_rule())
	var description := PixelUi.label(str(skill.desc), 16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 282
	_detail_box.add_child(description)
	_detail_box.add_child(PixelUi.label("魔法 %.0f   ·   冷却 %.1f 秒" % [GameState.skill_cost(_selected_skill), GameState.skill_cooldown(_selected_skill)], 16))
	if not GameState.unlocked_skills.has(_selected_skill):
		_detail_box.add_child(PixelUi.label("Lv.%d 解锁" % Skills.unlock_level(_selected_skill), 18, PixelUi.MUTED))
		return
	var slots := [3] if Skills.is_ultimate(_selected_skill) else [0, 1, 2]
	for slot: int in slots:
		var current := GameState.skill_for_slot(slot)
		var is_current := current == _selected_skill
		var button := PixelUi.compact_button("已装配 %s" % skill_key(slot) if is_current else "装配 %s · %s" % [skill_key(slot), str(Skills.get_skill(current,GameState.combat_mode).get("name", "空栏位"))], 16)
		button.custom_minimum_size.y = 42
		button.disabled = is_current
		button.set_meta("focus_token", "equip_skill:" + str(slot))
		button.tooltip_text = "当前：" + str(Skills.get_skill(current,GameState.combat_mode).get("name", "空"))
		button.pressed.connect(func() -> void:
			if not _claim_action(): return
			if GameState.equip_skill(_selected_skill, slot):
				_rebuild()
				ComicMotion.feedback(_shell, "%s 已装配到 %s" % [skill.name, skill_key(slot)])
		)
		_detail_box.add_child(button)

func _detail_talent() -> void:
	if not GameState.TALENT_BRANCHES.has(_selected_talent):_selected_talent=&""
	if _selected_talent == &"":
		_detail_box.add_child(PixelUi.label("天赋", 22, PixelUi.MUTED))
		_detail_box.add_child(_parchment_rule())
		_detail_box.add_child(PixelUi.label("单击天赋「详情」查看，双击加 1 点", 16, PixelUi.MUTED))
		_detail_box.add_child(PixelUi.label("有前置条件的天赋要先点亮下方前置节点", 15, PixelUi.MUTED))
		_detail_box.add_child(PixelUi.label("天赋强化对应法术，可跨流派搭配", 15, PixelUi.MUTED))
		return

	var info: Dictionary = GameState.TALENT_BRANCHES[_selected_talent]
	var rank := GameState.talent_rank(_selected_talent)
	var max_rank := int(info["max_rank"])
	var head := UiFactory.hbox(10)
	_detail_box.add_child(head)
	head.add_child(UiFactory.texture_icon(str(info.get("icon", "")), 48.0))
	var head_text := UiFactory.vbox(0)
	head_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	head.add_child(head_text)
	head_text.add_child(PixelUi.label(str(info["name"]), 21, PixelUi.INK))
	head_text.add_child(PixelUi.label("%d / %d 级" % [rank, max_rank], 14, PixelUi.MUTED))
	_detail_box.add_child(_parchment_rule())
	var desc := PixelUi.label(str(info["desc"]), 16, PixelUi.INK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0.0, 54.0)
	_detail_box.add_child(desc)
	_detail_box.add_child(_parchment_rule())
	var preview := PixelUi.label(str(GameState.preview_talent(_selected_talent).get("text", "")), 15, Color("9ee6ab"))
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_box.add_child(preview)
	var unlocked := GameState.talent_unlocked(_selected_talent)
	_detail_box.add_child(PixelUi.label("前置：%s" % _requirement_text(info), 15,
		PixelUi.MUTED if unlocked else Color("ff9e9e")))
	var full := rank >= max_rank
	var add := PixelUi.compact_button("已满级" if full else ("加点（剩 %d）" % GameState.talent_points), 18)
	add.custom_minimum_size = Vector2(0.0, 44.0)
	add.set_meta("focus_token", "talent_detail_add:" + str(_selected_talent))
	add.disabled = full or not unlocked or GameState.talent_points <= 0
	add.tooltip_text=ItemInsight.talent_requirement(_selected_talent)
	if add.disabled:_detail_box.add_child(PixelUi.label(add.tooltip_text,16,PixelUi.MUTED))
	add.pressed.connect(func() -> void: _add_talent_point(_selected_talent))
	_detail_box.add_child(add)


func _detail_run_summary() -> void:
	## 属性页右侧：本局概况（不再放人物介绍 / 外貌设定）
	_detail_box.add_child(PixelUi.label("本局概况", 22, PixelUi.INK))
	_detail_box.add_child(_parchment_rule())
	var rows: Array = [
		["等级", "Lv.%d" % GameState.level],
		["经验", "%d / %d" % [int(GameState.exp), int(GameState.exp_needed(GameState.level))]],
		["魔法值", "%d / %d" % [int(GameState.mp), int(GameState.MAX_MP)]],
		["到达波次", "第 %d 波" % maxi(1, GameState.wave)],
		["已学技能", "%d 个（大招 %s）" % [
			GameState.unlocked_skills.size(),
			"已装配" if GameState.ultimate_skill != &"" else "未装配"]],
		["可用天赋点", str(GameState.talent_points)],
	]
	for entry in rows:
		var row := UiFactory.hbox(8)
		row.add_child(PixelUi.label(str(entry[0]), 16, PixelUi.MUTED))
		row.add_child(UiFactory.spacer())
		row.add_child(PixelUi.label(str(entry[1]), 16, PixelUi.INK))
		_detail_box.add_child(row)
	# 展示营地的持久人物关系；旧剧情分支权重仍由 StoryState 管理。
	if StoryState.deaths > 0 or StoryState.story_line != "":
		_detail_box.add_child(_parchment_rule())
		_detail_box.add_child(PixelUi.label("轮回记录", 18, Palette.GOLD))
		var line_text := StoryState.story_line if StoryState.story_line != "" else "尚未选择"
		for entry in [
			["死亡次数", "%d 次" % StoryState.deaths],
			["伊莉丝好感", "%d / 500 · %s" % [int(Outpost.data.bonds.get("iris",0)),BondRules.stage(int(Outpost.data.bonds.get("iris",0)))]],
			["剧情分支", line_text],
		]:
			var row := UiFactory.hbox(8)
			row.add_child(PixelUi.label(str(entry[0]), 16, PixelUi.MUTED))
			row.add_child(UiFactory.spacer())
			row.add_child(PixelUi.label(str(entry[1]), 16, PixelUi.INK))
			_detail_box.add_child(row)


func _mp_regen_total(block: StatBlock) -> float:
	# Shares combat's final regeneration rate, including debuffs on talent mana.
	return GameState.total_mp_regen(block)


func _compare_row(label: String, before: String, after: String, delta: float) -> Control:
	## 「旧值 → 新值」，变好绿色、变差红色、不变灰白
	var row := UiFactory.vbox(4)
	row.add_child(PixelUi.label(label, 15, PixelUi.MUTED))
	var tint := PixelUi.MUTED
	if delta > 0.001:
		tint = Color("9ee6ab")
	elif delta < -0.001:
		tint = Color("ff9e9e")
	row.add_child(PixelUi.label("%s → %s" % [before, after], 16, tint))
	return row


func _remember_click(key: String) -> void:
	_last_click_key = key
	_last_click_msec = Time.get_ticks_msec()


func _matches_double_click(event: InputEvent, key: String) -> bool:
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed \
		and mouse.double_click and _last_click_key == key \
		and Time.get_ticks_msec() - _last_click_msec <= DOUBLE_CLICK_MSEC


func _on_item_slot_input(event: InputEvent, item: Dictionary) -> void:
	if not _matches_double_click(event, "item:" + str(item.get("uid",item.get("id", "")))): return
	_last_click_key = ""
	if ItemDB.can_equip(item): _equip(item)
	get_viewport().set_input_as_handled()


func _on_equip_slot_input(event: InputEvent, slot: StringName, item: Dictionary) -> void:
	if not _matches_double_click(event, "equip:" + str(item.get("uid",item.get("id", "")))): return
	_last_click_key = ""
	_unequip(slot)
	get_viewport().set_input_as_handled()


func _on_talent_row_input(event: InputEvent, branch: StringName) -> void:
	if not _matches_double_click(event, "talent:" + str(branch)): return
	_last_click_key = ""
	_selected_talent = branch
	_add_talent_point(branch)
	get_viewport().set_input_as_handled()


func _add_talent_point(branch: StringName) -> void:
	if not _claim_action(): return
	if not GameState.TALENT_BRANCHES.has(branch): return
	if not GameState.talent_unlocked(branch) or GameState.talent_points <= 0: return
	if GameState.talent_rank(branch) >= int(GameState.TALENT_BRANCHES[branch].get("max_rank", 0)): return
	if GameState.spend_talent_point(branch):
		AudioManager.play(&"ui_click", -6.0)
		_rebuild()
		ComicMotion.feedback(_shell, "%s 升至 %d 级" % [GameState.TALENT_BRANCHES[branch].name, GameState.talent_rank(branch)])


func _equip(item: Dictionary) -> void:
	if not _claim_action(): return
	if GameState.equip(item):
		AudioManager.play(&"ui_click", -6.0)
		_selected = item
		_rebuild()
		ComicMotion.feedback(_shell, "已装备 %s" % item.name)


func _unequip(slot: StringName) -> void:
	if not _claim_action(): return
	if GameState.unequip(slot):
		AudioManager.play(&"ui_click", -8.0)
		_rebuild()
		ComicMotion.feedback(_shell, "装备已卸下")


func _focus_active_tab() -> void:
	if not _root.visible:
		return
	for i in _tab_ids.size():
		if _tab_ids[i] == _filter:
			_tab_buttons[i].grab_focus()
			return


func _restore_focus(token: String) -> void:
	if not _root.visible or _closing:
		return
	var found := _find_focus_token(_shell, token)
	if found == null and _filter in [&"gear", &"relic", &"potion", &"material"] and not _selected.is_empty():
		found = _find_focus_token(_shell, "item:" + str(_selected.get("uid",_selected.get("id", ""))))
	if found == null and _filter == &"talent" and _selected_talent != &"":
		found = _find_focus_token(_shell, "talent_detail:" + str(_selected_talent))
	if found != null:
		found.grab_focus()
	else:
		_focus_active_tab()


func _find_focus_token(node: Node, token: String) -> Control:
	if node is Button and str(node.get_meta("focus_token", "")) == token and not node.disabled:
		return node as Control
	for child in node.get_children():
		var found := _find_focus_token(child, token)
		if found != null:
			return found
	return null


func _wrap_paragraphs(node: Node) -> void:
	for child in node.get_children():
		if child is Label and (child as Label).text.length() > 22:
			(child as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			(child as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_wrap_paragraphs(child)

func _restore_tab_scroll(id: StringName) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if id != _filter or not is_open(): return
	var scroll := _shell.get_node("Panel/Content/Body/ItemsScroll") as ScrollContainer
	scroll.scroll_vertical = int(_tab_memory.get(id, {}).get("scroll", 0))

func _claim_action() -> bool:
	if _closing or not is_open() or not UIFlow.is_top(self) or Time.get_ticks_msec() < _submit_until: return false
	_submit_until = Time.get_ticks_msec() + 120
	return true

func _bag_entries() -> Array[Dictionary]:
	var output:Array[Dictionary]=[]
	var stacks:Dictionary={}
	for item in GameState.items:
		if ItemDB.is_material(item) or ItemDB.is_usable(item):
			var id:=str(item.id)
			var limit:=ExpeditionData.stack_limit(item)
			if not stacks.has(id) or int(stacks[id].get("stack_count",1))>=limit:
				item["stack_count"]=1
				stacks[id]=item
				output.append(item)
			else:stacks[id].stack_count+=1
		else:output.append(item)
	return output


func _quality_slot(button:Button,border:Color,selected:bool=false)->void:
	button.set_meta("quality_slot",border);button.set_meta("interaction_selected",selected);InteractionSkin.apply_button(button,"inventory")
