class_name CampTrainingUI
extends CanvasLayer
var world:Node
var _root:Control
var _body:VBoxContainer
var _message:Label
func _ready()->void:
	layer=31;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true)
	_root=UiFactory.full_rect();_root.theme=PixelUi.theme();add_child(_root);_root.add_child(UiFactory.dim_layer(0.42))
	var frame:=StarUi.frame(_root,Vector2(1000,650));var panel:=PixelUi.inset_panel(20);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);frame.add_child(panel)
	var outer:=UiFactory.vbox(10);panel.add_child(outer);outer.add_child(PixelUi.title("回廊训练场",28))
	_message=PixelUi.label("训练配置不会带入正式冒险 · 试穿不扣库存",16,PixelUi.GOLD);outer.add_child(_message)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.y=470;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.follow_focus=true;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;outer.add_child(scroll)
	_body=UiFactory.vbox(10);_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(_body)
	var close_button:=PixelUi.button("返回营地",18);close_button.pressed.connect(close);outer.add_child(close_button);_root.hide()
	InteractionSkin.mount(_root,"training",panel)

func is_open()->bool:return _root.visible
func open()->void:
	if not UIFlow.can_open(self):return
	_root.show();UIFlow.push_screen(self);_refresh()
func close()->void:
	_root.hide();UIFlow.pop_screen(self)
func _input(event:InputEvent)->void:
	if is_open() and UIFlow.is_top(self) and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):close();get_viewport().set_input_as_handled()
func _button(text:String,callback:Callable)->Button:
	var button:=PixelUi.compact_button(text,17);button.pressed.connect(callback);_body.add_child(button);return button
func _refresh()->void:
	for child in _body.get_children():_body.remove_child(child);child.queue_free()
	var line:=UiFactory.hbox(10);_body.add_child(line);line.add_child(PixelUi.label("训练等级",18))
	var level_box:=SpinBox.new();level_box.min_value=1;level_box.max_value=100;level_box.value=GameState.level;line.add_child(level_box)
	MobileControls.decorate_number(level_box)
	level_box.value_changed.connect(func(value:float)->void:GameState.level=int(value);CampSession.refresh_stats();world.reset_training())
	_button("恢复生命/MP与冷却 · 清理召唤物和稻草人状态",func()->void:world.reset_training())
	_button("重置本轮伤害统计与训练效果",func()->void:world.reset_training())
	_body.add_child(PixelUi.label("训练天赋 · 满级/清空/逐项调整，不消耗金币",19,PixelUi.GOLD))
	_button("全部满级",func()->void:CampSession.fill_talents();world.reset_training();_refresh())
	_button("全部清空",func()->void:CampSession.clear_talents();world.reset_training();_refresh())
	for id:StringName in GameState.TALENT_BRANCHES:
		var data:Dictionary=GameState.TALENT_BRANCHES[id];var row:=UiFactory.hbox(10);_body.add_child(row)
		var name_label:=PixelUi.label(str(data.name),17);name_label.custom_minimum_size.x=300;row.add_child(name_label)
		var rank:=SpinBox.new();rank.min_value=0;rank.max_value=int(data.max_rank);rank.value=GameState.talent_rank(id);rank.tooltip_text=str(data.desc);row.add_child(rank)
		MobileControls.decorate_number(rank)
		rank.value_changed.connect(func(value:float)->void:
			if not CampSession.set_rank(id,int(value)):rank.set_value_no_signal(GameState.talent_rank(id));_message.text="前置天赋不足，或有后续天赋依赖当前天赋，请先调整后续项。"
			else:world.reset_training();_message.text="训练天赋已更新，正式出发仍恢复初始状态。")
	_body.add_child(PixelUi.label("试穿已有装备 · 不改变准备携带清单",19,PixelUi.GOLD))
	for slot:StringName in ItemDB.SLOTS:
		_button("卸下试穿 · "+str(slot),func()->void:GameState.equipment[slot]={};GameState._after_equipment_change();world.reset_training())
	for id in Outpost.data.inventory:
		var item:=ExpeditionData.resolve(str(id))
		if int(Outpost.data.inventory[id])<=0 or not ItemDB.is_equippable(item) or not ItemDB.can_equip(item):continue
		_button("试穿 · "+str(item.name),func()->void:
			if CampSession.try_equipment(str(id)):world.reset_training();_message.text="已试穿："+str(item.name))
	_button("使用准备清单中的装备试穿",func()->void:world.preview_preparation();world.reset_training())
	_body.add_child(PixelUi.label("技能全部解锁：在背包中替换三个小技能和一个大招。稻草人无敌，击杀触发效果不由打桩触发。",16,PixelUi.MUTED))
	PixelUi.focus_button(_body)

