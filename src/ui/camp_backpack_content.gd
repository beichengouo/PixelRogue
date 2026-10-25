class_name CampBackpackContent
extends RefCounted
## Camp-only content inside the existing inventory shell; warehouse is read-only.
var bag:InventoryUI
var selected_key:=""
var details_mode:="item"
var _preset_index:=0
var _preset_name:=""
var notice:=""
var _flavor:=false
var _detail_signature:=""

func rebuild()->void:
	var draft:=bag.camp_preparation
	var focus:=bag.get_viewport().gui_get_focus_owner()
	var token:=str(focus.get_meta("focus_token","")) if focus!=null else ""
	var signature:=str(bag._filter)+":"+selected_key+":"+str(bag._selected_skill)+":"+details_mode
	if signature!=_detail_signature:
		(bag._shell.get_node("Panel/Content/Body/Detail/DetailScroll") as ScrollContainer).scroll_vertical=0
		_detail_signature=signature
	for parent in [bag._equip_box,bag._grid,bag._page_box,bag._detail_box]:
		for child in parent.get_children():parent.remove_child(child);child.queue_free()
	bag._talent_mount.hide();bag.talent_view.hide_embedded()
	bag._shell.get_node("Panel/Content/Body/ItemsScroll").show();bag._shell.get_node("Panel/Content/Body/Detail").show()
	var items:=bag._filter in [&"gear",&"potion"]
	bag._toolbar.visible=items;bag._gear_filter.visible=bag._filter==&"gear";bag._grid.visible=items;bag._page_box.visible=not items
	bag._equip_wrapper.visible=items;bag._grid_hint.hide();bag._sell_button.hide();bag._bind_button.hide()
	(bag._equip_wrapper.get_child(0) as Label).text="正式出征装备" if bag._filter==&"gear" else "携带药剂 · %d / 15"%draft.potion_count()
	if items:_items()
	elif bag._filter==&"skill":_skills()
	else:_stats()
	_detail()
	bag._refresh_tab_counts();bag._refresh_counters()
	(bag._portrait_node as TextureRect).texture=load(LegendarySets.portrait())
	bag._wrap_paragraphs(bag._page_box);bag._wrap_paragraphs(bag._detail_box)
	UiArtLayout.refresh(bag._panel);InteractionSkin.apply_tree(bag._panel,"inventory")
	bag._fit_details(bag._detail_box);bag._fit_page_text(bag._page_box)
	var paper:=bag._shell.get_node("Panel/Content/Body/Detail") as PanelContainer
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:paper.get_theme_stylebox("panel").set_content_margin(side,36)
	bag.call_deferred("_fit_camp_content")
	if not token.is_empty():bag._restore_focus.call_deferred(token)

func _button(text:String,action:Callable,parent:Node,token:="")->Button:
	var button:=PixelUi.compact_button(text,18);button.custom_minimum_size.y=44;button.set_meta("focus_token",token);parent.add_child(button);button.pressed.connect(action);return button
func _label(text:String,font_size:=18,color:=PixelUi.INK)->Label:
	var label:=PixelUi.label(text,font_size,color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;return label
func _icon(path:String,caption:String,action:Callable,parent:Node,token:String)->Button:
	var button:=_button(caption,action,parent,token);button.custom_minimum_size=Vector2(76,70);button.icon=load(path) if not path.is_empty() and ResourceLoader.exists(path) else null;button.expand_icon=true;button.add_theme_constant_override("icon_max_width",44);return button
func _item_icon(item:Dictionary,caption:String,action:Callable,parent:Node,token:String)->Button:
	var button:=_icon("",caption,action,parent,token)
	if not item.is_empty():button.icon=UiFactory.atlas_texture(ItemDB.icon_texture(item),ItemDB.icon_region(item));button.set_meta("quality_slot",ItemDB.rarity_color(int(item.rarity)))
	return button
func _items()->void:
	var draft:=bag.camp_preparation
	if bag._filter==&"gear":
		for slot:StringName in ItemDB.SLOTS:
			var key:=draft.equipped_key(slot);var item:=Outpost.stored_item(key)
			var button:=_item_icon(item,str(ItemDB.SLOT_NAMES[slot]) if key.is_empty() else "",func()->void:selected_key=key;details_mode="item";bag._rebuild(),bag._equip_box,"camp:slot:"+str(slot));button.tooltip_text=str(item.get("name","未装备"));button.set_meta("inventory_slot",slot)
	else:
		var totals:Dictionary={}
		for key in draft.loadout:
			if ItemDB.is_usable(Outpost.stored_item(str(key))):totals[str(key)]=draft.potion_count(str(key))
		for key:String in totals:
			_item_icon(Outpost.stored_item(key),"×%d"%int(totals[key]),func()->void:selected_key=key;details_mode="item";bag._rebuild(),bag._equip_box,"camp:carried:"+key)
	var keys:Array[String]=[]
	for raw in Outpost.data.inventory:
		var key:=str(raw);var item:=Outpost.stored_item(key)
		if int(Outpost.data.inventory[key])<=0:continue
		if not ItemDB.available_in_mode(item,draft.combat_mode):continue
		if bag._filter==&"gear" and (not ItemDB.is_equippable(item) or bag._gear_part!=&"" and ItemDB.slot_of(item)!=bag._gear_part):continue
		if bag._filter==&"potion" and not ItemDB.is_usable(item):continue
		keys.append(key)
	if bag._sort_mode==1:keys.sort_custom(func(a:String,b:String)->bool:return int(Outpost.stored_item(a).get("rarity",0))>int(Outpost.stored_item(b).get("rarity",0)))
	elif bag._sort_mode==2:keys.sort_custom(func(a:String,b:String)->bool:return str(Outpost.stored_item(a).name)<str(Outpost.stored_item(b).name))
	if not keys.has(selected_key):selected_key=keys[0] if not keys.is_empty() else ""
	for key in keys:
		var item:=Outpost.stored_item(key);var available:=int(Outpost.data.inventory[key]);var selected:=draft.loadout.count(key)
		var button:=_item_icon(item,"",func()->void:_select(key),bag._grid,"camp:item:"+key);button.name="CampStock_"+key;button.set_meta("interaction_selected",key==selected_key);button.tooltip_text=str(item.name)
		var count:=_label("%d/%d"%[selected,available] if ItemDB.is_usable(item) else "已装" if selected>0 else "×%d"%available,14,PixelUi.GOLD);count.mouse_filter=Control.MOUSE_FILTER_IGNORE;count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);count.offset_top=-20;count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;button.add_child(count)
		button.gui_input.connect(func(event:InputEvent)->void:
			if event is InputEventMouseButton and event.pressed and event.double_click:
				selected_key=key;equip_selected();button.accept_event()
			elif event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("ui_accept"):
				selected_key=key;equip_selected();button.accept_event())
	bag._selected=Outpost.stored_item(selected_key) if not selected_key.is_empty() else {}
func _select(key:String)->void:
	selected_key=key;details_mode="item";_flavor=false;bag._rebuild()
func equip_selected()->void:
	var item:=Outpost.stored_item(selected_key)
	if ItemDB.is_equippable(item):bag.camp_preparation.equip_key(selected_key)
	elif ItemDB.is_usable(item):bag.camp_preparation.set_potion_count(selected_key,bag.camp_preparation.potion_count(selected_key)+1)
	bag._rebuild()
func _skills()->void:
	var draft:=bag.camp_preparation
	bag._page_box.add_child(_label("出征技能 · 3＋1",24,PixelUi.GOLD))
	var row:=HFlowContainer.new();bag._page_box.add_child(row)
	for index in draft.skill_loadout.size():
		var id:=StringName(draft.skill_loadout[index]);var skill:=Skills.get_skill(id)
		_icon(str(skill.icon),bag.skill_key(index),func()->void:bag._selected_skill=id;details_mode="item";bag._rebuild(),row,"camp:skill_slot:"+str(index))
	bag._page_box.add_child(_label("技能库",20,PixelUi.GOLD))
	var library:=HFlowContainer.new();bag._page_box.add_child(library)
	for id:StringName in Skills.order_for():
		var skill:=Skills.get_skill(id);var button:=_icon(str(skill.icon),"大招" if Skills.is_ultimate(id) else "",func()->void:bag._selected_skill=id;details_mode="item";bag._rebuild(),library,"camp:skill:"+str(id));button.tooltip_text=str(skill.name)+"\n"+CharacterUnlocks.skill_condition(id);button.modulate=Color.WHITE if CharacterUnlocks.skill_available(id) else Color(.55,.55,.6);button.set_meta("interaction_selected",id==bag._selected_skill)
		if not CharacterUnlocks.skill_available(id):_lock_badge(button)
	bag._page_box.add_child(_label("同行被动",20,PixelUi.GOLD))
	var passives:=HFlowContainer.new();bag._page_box.add_child(passives)
	for passive:Dictionary in PassiveDefinitions.for_character(Characters.current_id()):
		var button:=_icon(str(passive.icon),str(passive.name),func()->void:
			details_mode="passive:"+str(passive.id)
			if PassiveDefinitions.select(Characters.current_id(),StringName(passive.id)):bag.camp_preparation.publish(false)
			bag._rebuild(),passives,"camp:passive:"+str(passive.id));button.tooltip_text=str(passive.desc)+"\n"+CharacterUnlocks.passive_condition(StringName(passive.id),Characters.current_id());button.set_meta("interaction_selected",StringName(passive.id)==PassiveDefinitions.selected(Characters.current_id()))
		if not CharacterUnlocks.passive_available(StringName(passive.id),Characters.current_id()):_lock_badge(button)
func _lock_badge(button:Button)->void:
	var icon:=UiFactory.texture_icon(Skills.FRAME_LOCKED,18);icon.name="ProgressLock";icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(icon);icon.position=Vector2(4,4)
func _stats()->void:
	var draft:=bag.camp_preparation;var stats:=Outpost.preview_loadout(draft.loadout)
	stats.add_flat(&"max_hp",GameState.HP_PER_LEVEL*maxi(0,draft.initial_level-1));stats.add_flat(&"attack",GameState.ATK_PER_LEVEL*maxi(0,draft.initial_level-1))
	bag._page_box.add_child(_label("出发预览 · Lv.%d"%draft.initial_level,25,PixelUi.GOLD))
	for key in [&"attack",&"max_hp",&"move_speed",&"crit_chance",&"attack_speed",&"mp_regen"]:
		var row:=UiFactory.hbox(14);row.add_child(UiFactory.texture_icon(InventoryUI.STAT_ICONS.get(key,InventoryUI.STAT_ICONS.attack),34));row.add_child(_label(ItemInsight.stat_text(key,stats.get_value(key)),22));bag._page_box.add_child(row)
	bag._page_box.add_child(_label("不含训练等级、天赋或局内遗物",17,PixelUi.MUTED))
func _detail()->void:
	var nav:=UiFactory.hbox(10);bag._detail_box.add_child(nav)
	_button("方案",func()->void:details_mode="presets";bag._rebuild(),nav,"camp:presets")
	_button("构筑思路",func()->void:details_mode="build";bag._rebuild(),nav,"camp:build")
	if not notice.is_empty():bag._detail_box.add_child(_label(notice,17,PixelUi.GOLD))
	if not bag.camp_preparation.memory_notice.is_empty():
		bag._detail_box.add_child(_label(bag.camp_preparation.memory_notice,17,PixelUi.GOLD))
		if bag.camp_preparation.memory_dirty:_button("重试保存配置",func()->void:bag.camp_preparation.save_memory();bag._rebuild(),bag._detail_box,"camp:retry_memory")
	if details_mode=="presets":_presets();return
	if details_mode=="build":_build_paths();return
	if bag._filter==&"skill":_skill_detail();return
	if bag._filter not in [&"gear",&"potion"]:return
	var item:=Outpost.stored_item(selected_key) if not selected_key.is_empty() else {}
	if item.is_empty():bag._detail_box.add_child(_label("仓库暂无可用物品",21,PixelUi.MUTED));return
	bag._detail_box.add_child(_label(str(item.name),25,ItemDB.rarity_color(int(item.rarity))))
	bag._detail_box.add_child(_label("库存 %d · 已选 %d"%[int(Outpost.data.inventory.get(selected_key,0)),bag.camp_preparation.loadout.count(selected_key)],17,PixelUi.GOLD))
	if ItemDB.is_equippable(item):
		var wearing:=bag.camp_preparation.loadout.has(selected_key)
		var action:=_button("卸下" if wearing else "装备",func()->void:
			if wearing:bag.camp_preparation.unequip_slot(ItemDB.slot_of(item))
			else:bag.camp_preparation.equip_key(selected_key)
			bag._rebuild(),bag._detail_box,"camp:equip:"+selected_key)
		action.disabled=not ItemDB.can_equip(item)
		if not ItemDB.can_equip(item):bag._detail_box.add_child(_label("当前角色无法装备",17,Palette.UI_DANGER))
	else:
		var row:=UiFactory.hbox(16);bag._detail_box.add_child(row)
		var key:=selected_key;var count:=bag.camp_preparation.potion_count(key)
		var minus:=_button("−",func()->void:bag.camp_preparation.set_potion_count(key,count-1);bag._rebuild(),row,"camp:potion_minus:"+key);minus.disabled=count<=0
		row.add_child(_label("%d"%count,23,PixelUi.GOLD))
		var plus:=_button("＋",func()->void:bag.camp_preparation.set_potion_count(key,count+1);bag._rebuild(),row,"camp:potion_plus:"+key);plus.disabled=count>=int(Outpost.data.inventory.get(key,0)) or bag.camp_preparation.potion_count()>=15
	var stats:=ItemDB.stat_lines(item)
	if not stats.is_empty():bag._detail_box.add_child(_label(" · ".join(stats),18,PixelUi.GOLD))
	if ItemDB.is_equippable(item):
		var losses:=ItemInsight.replacement_losses(item)
		if not losses.is_empty():bag._detail_box.add_child(_label(losses,17,Palette.UI_DANGER))
	bag._detail_box.add_child(_label(str(item.desc),18))
	_button("收起故事 ▴" if _flavor else "背景故事 ▾",func()->void:_flavor=not _flavor;bag._rebuild(),bag._detail_box,"camp:flavor")
	if _flavor:bag._detail_box.add_child(_label(ItemDB.flavor_text(item),18,PixelUi.MUTED))
func _skill_detail()->void:
	if details_mode.begins_with("passive:"):
		for passive:Dictionary in PassiveDefinitions.for_character(Characters.current_id()):
			if str(passive.id)!=details_mode.trim_prefix("passive:"):continue
			bag._detail_box.add_child(_label(str(passive.name),25,PixelUi.GOLD));bag._detail_box.add_child(_label(str(passive.desc),18))
			bag._detail_box.add_child(_label(("已解锁 · " if CharacterUnlocks.passive_available(StringName(passive.id),Characters.current_id()) else "未解锁 · ")+CharacterUnlocks.passive_condition(StringName(passive.id),Characters.current_id()),18,PixelUi.MUTED))
		return
	if bag._selected_skill==&"":bag._selected_skill=StringName(bag.camp_preparation.skill_loadout[0])
	var id:=bag._selected_skill;var skill:=Skills.get_skill(id)
	bag._detail_box.add_child(_label(str(skill.name),25,PixelUi.GOLD))
	if not CharacterUnlocks.skill_available(id):bag._detail_box.add_child(_label("未解锁 · "+CharacterUnlocks.skill_condition(id),18,PixelUi.MUTED));return
	for slot:int in ([3] if Skills.is_ultimate(id) else [0,1,2]):
		var button:=_button("装配 "+bag.skill_key(slot),func()->void:bag.camp_preparation.set_skill(id,slot);bag._rebuild(),bag._detail_box,"camp:equip_skill:"+str(slot));button.disabled=StringName(bag.camp_preparation.skill_loadout[slot])==id
	bag._detail_box.add_child(_label(str(skill.desc),18))
func _presets()->void:
	bag._detail_box.add_child(_label("配装方案",24,PixelUi.GOLD))
	if _preset_name.is_empty():_preset_name=str(Outpost.data.get("presets",{}).get(str(_preset_index),{}).get("name","方案%d"%(_preset_index+1)))
	var selector:=OptionButton.new();selector.custom_minimum_size.y=44;bag._detail_box.add_child(selector)
	for index in 3:selector.add_item(str(Outpost.data.get("presets",{}).get(str(index),{}).get("name","方案%d"%(index+1))))
	selector.select(_preset_index);selector.item_selected.connect(func(index:int)->void:_preset_index=index;_preset_name=selector.get_item_text(index);bag._rebuild())
	var label:=LineEdit.new();label.text=_preset_name;label.max_length=20;label.custom_minimum_size.y=44;label.text_changed.connect(func(value:String)->void:_preset_name=value);bag._detail_box.add_child(label)
	var draft:=bag.camp_preparation
	_button("保存当前方案",func()->void:notice="方案已保存" if Outpost.save_preset(_preset_index,_preset_name,draft.loadout,draft.carried,draft.danger,draft.difficulty) else "保存失败，原方案保留";bag._rebuild(),bag._detail_box,"camp:preset_save")
	var use:=_button("取用方案",func()->void:var missing:=draft.apply_preset(_preset_index);notice="方案已取用" if missing.is_empty() else "缺货："+"、".join(missing);bag._rebuild(),bag._detail_box,"camp:preset_take");use.disabled=not Outpost.data.get("presets",{}).has(str(_preset_index))
	var remove:=_button("删除方案",func()->void:notice="方案已删除" if Outpost.delete_preset(_preset_index) else "保存失败，方案保留";bag._rebuild(),bag._detail_box,"camp:preset_delete");remove.disabled=use.disabled
func _build_paths()->void:
	var draft:=bag.camp_preparation;var snapshot:Dictionary={"character":str(Characters.current_id()),"equipment":{},"items":[],"learned_skills":draft.skill_loadout.slice(0,3),"ultimate_skill":str(draft.skill_loadout[3])}
	for slot:StringName in ItemDB.SLOTS:
		var item:=Outpost.stored_item(draft.equipped_key(slot))
		if not item.is_empty():snapshot.equipment[str(slot)]=str(item.id)
	for route:Dictionary in BuildPaths.routes():
		bag._detail_box.add_child(_label(BuildPaths.describe(route,snapshot),17))
		_button("取消追踪" if BuildPaths.selected()==str(route.id) else "追踪 · "+str(route.name),func()->void:notice=BuildPaths.set_goal("" if BuildPaths.selected()==str(route.id) else str(route.id));bag._rebuild(),bag._detail_box,"camp:route:"+str(route.id))
