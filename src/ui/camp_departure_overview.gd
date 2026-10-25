class_name CampDepartureOverview
extends VBoxContainer
## Compact preparation view. All edits target the shared camp draft.
var camp:CampUI
var draft:CampPreparation
var _destinations:GridContainer
var _footer:VBoxContainer
var _cost:Label
var _error:Label
var _start:Button

func _ready()->void:
	add_theme_constant_override("separation",8)
	_destinations=GridContainer.new();_destinations.columns=2;_destinations.add_theme_constant_override("h_separation",12);add_child(_destinations)
	for id:StringName in [ChapterCatalog.FIRST,ChapterCatalog.NEXT]:
		var available:=ChapterCatalog.unlocked(id)
		var button:=PixelUi.compact_button("",18);button.name="Destination_"+str(id);button.custom_minimum_size=Vector2(0,100);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.disabled=not available;button.set_meta("interaction_selected",draft.chapter_id==id);button.set_meta("focus_token","destination:"+str(id));_destinations.add_child(button)
		var image:=TextureRect.new();image.texture=load("res://assets/room_illustrated/"+("forest_clearing_v03" if id==ChapterCatalog.FIRST else "city_silent_gate_v01")+"/background.png");image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);image.mouse_filter=Control.MOUSE_FILTER_IGNORE;image.modulate=Color(.65,.65,.65,.65 if available else .25);button.add_child(image)
		var caption:=PixelUi.label(ChapterCatalog.title(id)+( "" if available else "  🔒"),23,Color.WHITE);caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER);caption.grow_horizontal=Control.GROW_DIRECTION_BOTH;caption.position=Vector2(-120,-16);caption.size=Vector2(240,32);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.add_theme_constant_override("outline_size",5);button.add_child(caption)
		button.tooltip_text="选择目的地" if available else "通关苏醒林地后开放"
		if not available:
			var lock_note:=PixelUi.label("通关苏醒林地后开放",14,Color.WHITE);lock_note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);lock_note.offset_top=-24;lock_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;lock_note.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(lock_note)
		button.pressed.connect(func()->void:draft.set_destination(id))
	var challenges:=UiFactory.hbox(8);add_child(challenges)
	for option:Dictionary in RunDifficulty.OPTIONS:
		var button:=PixelUi.compact_button(str(option.name),18);button.name="Difficulty_"+str(option.id);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.set_meta("focus_token","difficulty:"+str(option.id));button.set_meta("interaction_selected",draft.difficulty==int(option.id));challenges.add_child(button)
		button.pressed.connect(func()->void:draft.set_difficulty(int(option.id)))
	var multipliers:=HFlowContainer.new();multipliers.add_theme_constant_override("h_separation",18);add_child(multipliers)
	for value in [["attack","攻击",RunDifficulty.attack_multiplier(draft.difficulty)],["max_hp","生命",RunDifficulty.health_multiplier(draft.difficulty)],["level","数量",RunDifficulty.spawn_multiplier(draft.difficulty)],["coin_gain","金币",RunDifficulty.gold_multiplier(draft.difficulty)]]:
		var row:=UiFactory.hbox(4);row.add_child(UiFactory.texture_icon(InventoryUI.STAT_ICONS[value[0]],24));row.add_child(PixelUi.label("%s ×%s"%[value[1],str(value[2])],16));multipliers.add_child(row)
	var info:=PixelUi.compact_button("规则 ⓘ",15);multipliers.add_child(info);info.pressed.connect(func()->void:camp._show_difficulty_info=not camp._show_difficulty_info;camp._refresh())
	if camp._show_difficulty_info:add_child(_note(RunDifficulty.description(draft.difficulty)))
	var gear:=HFlowContainer.new();gear.add_theme_constant_override("h_separation",8);add_child(gear);gear.add_child(PixelUi.label("装备",17,PixelUi.GOLD))
	for slot:StringName in ItemDB.SLOTS:
		var item:=Outpost.stored_item(draft.equipped_key(slot));var button:=_item_button(item,str(ItemDB.SLOT_NAMES[slot]) if item.is_empty() else "",&"gear");button.name="Summary_"+str(slot);button.set_meta("focus_token","summary:gear:"+str(slot));button.tooltip_text=str(ItemDB.SLOT_NAMES[slot])+" · "+str(item.get("name","未装备"));gear.add_child(button)
	gear.add_child(PixelUi.label("药剂",17,PixelUi.GOLD))
	var shown:Dictionary={}
	for key in draft.loadout:
		var item:=Outpost.stored_item(str(key))
		if not ItemDB.is_usable(item) or shown.has(str(key)):continue
		shown[str(key)]=true
		var button:=_item_button(item,"×%d"%draft.potion_count(str(key)),&"potion");button.set_meta("focus_token","summary:potion:"+str(key));gear.add_child(button)
	if shown.is_empty():gear.add_child(_item_button({},"＋",&"potion"))
	var skills:=HFlowContainer.new();skills.add_theme_constant_override("h_separation",8);add_child(skills);skills.add_child(PixelUi.label("技能",17,PixelUi.GOLD))
	for index in draft.skill_loadout.size():
		var skill:=Skills.get_skill(StringName(draft.skill_loadout[index]));var button:=_icon_button(str(skill.icon),"",&"skill");button.name="SummarySkill%d"%index;button.set_meta("focus_token","summary:skill:"+str(index));button.tooltip_text=str(skill.name);skills.add_child(button)
	for passive:Dictionary in PassiveDefinitions.for_character(Characters.current_id()):
		if StringName(passive.id)==PassiveDefinitions.selected(Characters.current_id()):
			var button:=_icon_button(str(passive.icon),"被动",&"skill");button.tooltip_text=str(passive.name);skills.add_child(button)
	var options:=PixelUi.compact_button("更多选项 ▴" if camp._show_departure_options else "更多选项 ▾",16);options.name="DepartureOptions";options.set_meta("focus_token","departure:options");add_child(options);options.pressed.connect(func()->void:camp._show_departure_options=not camp._show_departure_options;camp._refresh())
	if camp._show_departure_options:_options()
	if not draft.memory_notice.is_empty():
		add_child(_note(draft.memory_notice))
		if draft.memory_dirty:
			var retry:=PixelUi.compact_button("重试保存配置",16);add_child(retry);retry.pressed.connect(func()->void:draft.save_memory();camp._refresh())
	resized.connect(_layout);_layout.call_deferred()

func _note(text:String)->Label:
	var label:=PixelUi.label(text,16,PixelUi.MUTED);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return label
func _icon_button(path:String,caption:String,tab:StringName)->Button:
	var button:=PixelUi.compact_button(caption,14);button.custom_minimum_size=Vector2(64,48);button.icon=load(path) if not path.is_empty() and ResourceLoader.exists(path) else null;button.expand_icon=true;button.add_theme_constant_override("icon_max_width",32);button.set_meta("focus_token","summary:"+str(tab)+":"+str(get_child_count())+":"+caption+":"+path);button.pressed.connect(func()->void:camp.request_backpack(tab));return button
func _item_button(item:Dictionary,caption:String,tab:StringName)->Button:
	var button:=_icon_button("",caption,tab)
	if not item.is_empty():
		button.icon=UiFactory.atlas_texture(ItemDB.icon_texture(item),ItemDB.icon_region(item));button.set_meta("quality_slot",ItemDB.rarity_color(int(item.rarity)))
	return button
func _options()->void:
	var row:=UiFactory.hbox(12);add_child(row)
	var gold:=SpinBox.new();gold.name="CarriedGold";gold.prefix="携带金币 ";gold.min_value=0;gold.max_value=maxi(Outpost.gold(),draft.carried);gold.value=draft.carried;gold.custom_minimum_size.x=220;row.add_child(gold);MobileControls.decorate_number(gold)
	gold.value_changed.connect(func(value:float)->void:draft.carried=int(value);draft.publish(false);refresh_footer())
	var level:=SpinBox.new();level.name="InitialLevel";level.prefix="出发等级 ";level.min_value=1;level.max_value=DepartureLevels.MAXIMUM;level.value=draft.initial_level;level.custom_minimum_size.x=220;row.add_child(level);MobileControls.decorate_number(level)
	level.value_changed.connect(func(value:float)->void:draft.initial_level=int(value);draft.publish(false);refresh_footer())
	if maxi(int(Outpost.data.bonds.get(str(Characters.current_id()),0)),int(Outpost.data.bonds.get("iris",0)))>=200:
		var farewell:=CheckButton.new();farewell.text="出发前送行";farewell.button_pressed=camp._farewell;farewell.toggled.connect(func(value:bool)->void:camp._farewell=value);add_child(farewell)
func mount_footer(parent:VBoxContainer)->void:
	_footer=parent
	_cost=PixelUi.label("",17,PixelUi.GOLD);_cost.name="DepartureCost";_cost.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(_cost)
	_error=PixelUi.label("",16,Palette.UI_DANGER);_error.name="DepartureError";_error.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(_error)
	var actions:=UiFactory.hbox(12);parent.add_child(actions)
	var back:=PixelUi.compact_button("返回营地",18);back.size_flags_horizontal=Control.SIZE_EXPAND_FILL;back.pressed.connect(camp.close);actions.add_child(back)
	_start=PixelUi.compact_button("出发",21);_start.name="DepartNow";_start.custom_minimum_size.y=46;_start.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_start.set_meta("focus_token","departure:start");_start.pressed.connect(camp._depart);actions.add_child(_start)
	parent.add_child(_note("死亡损失本次携带物资，成功撤离后带回。"));refresh_footer()
func refresh_footer()->void:
	if not is_instance_valid(_cost):return
	_cost.text="携带 %d金   ·   等级费用 %d金   ·   余额 %d金"%[draft.carried,DepartureLevels.cost(draft.initial_level),Outpost.gold()-draft.carried-DepartureLevels.cost(draft.initial_level)]
	var error:=camp.departure_error();_error.text=error if not error.is_empty() else camp._feedback;_error.visible=not _error.text.is_empty();_start.disabled=not error.is_empty() or camp._busy
func _layout()->void:
	if not is_inside_tree() or is_queued_for_deletion():return
	var viewport:=get_viewport().get_visible_rect().size
	if is_instance_valid(_destinations):_destinations.columns=1 if size.x<620 or viewport.y>viewport.x else 2
