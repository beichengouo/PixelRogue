class_name DeveloperTools
extends Window
const STAT_NAMES:={"hp":"基础生命","max_hp":"基础生命","attack":"基础攻击","speed":"基础移速","move_speed":"基础移速","coins":"基础金币","attack_speed":"攻速倍率","mp_regen":"MP回复/秒","dash_cooldown":"闪避冷却/秒","crit_chance":"暴击率(0—1)","crit_mult":"暴击倍率","lifesteal":"命中回血","thorns":"反伤","coin_gain":"金币倍率","hp_multiplier":"继承生命倍率","attack_multiplier":"继承攻击倍率","speed_multiplier":"继承移速倍率"}
var console:=DeveloperSaveTool.new()
var _path:LineEdit
var _message:Label
var _grant_kind:OptionButton
var _item:OptionButton
var _amount:SpinBox
var _search:LineEdit
var _items:Array[Dictionary]=[]
var _confirm:ConfirmationDialog
var _units:Array[Dictionary]=[]
var _unit_picker:OptionButton
var _fields:GridContainer
var _draft:Dictionary={}
var _unit_status:Label
var _selected:=""
var _dirty:=false
func _ready()->void:
	title="PixelRogue · 开发调试工具";size=Vector2i(1040,760);min_size=Vector2i(800,600);close_requested.connect(_close)
	var margin:=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	var body:=VBoxContainer.new();margin.add_child(body)
	var back:=Button.new();back.text="返回地图编辑器";body.add_child(back);back.pressed.connect(_close)
	var tabs:=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(tabs)
	_build_console(tabs);_build_units(tabs)
	_confirm=ConfirmationDialog.new();add_child(_confirm);_confirm.confirmed.connect(_grant)
func _label(parent:Node,text:String)->Label:
	var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label);return label
func _button(parent:Node,text:String,action:Callable)->Button:
	var button:=Button.new();button.text=text;parent.add_child(button);button.pressed.connect(action);return button
func _build_console(tabs:TabContainer)->void:
	var body:=VBoxContainer.new();body.name="物资控制台";tabs.add_child(body)
	_label(body,"选择目标存档后发放。请先关闭正在使用该存档的游戏，避免内存中的旧数据再次写回。每次写入前自动在工程外备份，存档发生变化会拒绝覆盖。")
	_path=LineEdit.new();_path.text=ProjectSettings.globalize_path(SaveService.SAVE_PATH);body.add_child(_path)
	var row:=HBoxContainer.new();body.add_child(row)
	var dialog:=FileDialog.new();dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.filters=PackedStringArray(["*.json ; 游戏存档"]);add_child(dialog);dialog.file_selected.connect(func(path:String)->void:_path.text=path;_load_save())
	_button(row,"选择存档…",func()->void:dialog.popup_centered_ratio(.8));_button(row,"载入 / 重新载入",_load_save)
	_grant_kind=OptionButton.new();body.add_child(_grant_kind)
	for entry in [["营地金库金币","gold"],["活跃出征随身金币","coins"],["活跃出征钥匙","keys"],["物品 → 营地仓库（装备绑定）","warehouse"],["物品 → 活跃出征背包","bag"]]:
		_grant_kind.add_item(entry[0]);_grant_kind.set_item_metadata(_grant_kind.item_count-1,entry[1])
	_search=LineEdit.new();_search.placeholder_text="按物品名称或ID筛选";body.add_child(_search)
	_item=OptionButton.new();body.add_child(_item)
	for item in ItemDB.all():
		if ItemDB.is_equippable(item) or ItemDB.is_relic(item) or ItemDB.is_usable(item):_items.append(item)
	for id in ExpeditionData.MATERIALS:_items.append(ExpeditionData.resolve(str(id)))
	for index in 4:_items.append(ItemDB.mushroom_item(index))
	_search.text_changed.connect(func(_text:String)->void:_filter_items());_filter_items()
	_amount=SpinBox.new();_amount.min_value=1;_amount.max_value=1000000;_amount.step=1;_amount.value=1;_amount.prefix="数量 ";body.add_child(_amount)
	_button(body,"预览并发放",_preview_grant)
	_message=_label(body,"尚未载入存档；不会自动修改当前玩家数据。")
func _filter_items()->void:
	_item.clear()
	for item in _items:
		if not _search.text.is_empty() and not (str(item.name)+str(item.id)).to_lower().contains(_search.text.to_lower()):continue
		_item.add_item(str(item.name)+"  ["+str(item.id)+"]");_item.set_item_metadata(_item.item_count-1,str(item.id))
func _load_save()->void:
	var error:=console.open_file(_path.text)
	_message.text=error if not error.is_empty() else "目标：%s\n金库 %d 金 · 活跃出征：%s"%[console.path,int(console.data.outpost.get("gold",0)),"有" if not console.data.get("run",{}).is_empty() else "无"]
func _preview_grant()->void:
	var kind:=str(_grant_kind.get_selected_metadata());var id:=str(_item.get_selected_metadata()) if _item.selected>=0 else ""
	var result:=console.preview(kind,id,int(_amount.value))
	if not str(result.get("error","")).is_empty():_message.text=result.error;return
	_confirm.dialog_text="目标存档：%s\n发放到：%s\n物品：%s\n数量：%d\n自动备份后提交。"%[console.path,_grant_kind.get_item_text(_grant_kind.selected),id if kind in ["warehouse","bag"] else "金币 / 钥匙",int(_amount.value)]
	_confirm.popup_centered();_confirm.get_cancel_button().grab_focus()
func _grant()->void:
	var error:=console.grant(str(_grant_kind.get_selected_metadata()),str(_item.get_selected_metadata()) if _item.selected>=0 else "",int(_amount.value))
	_message.text=error if not error.is_empty() else "发放成功。重新加载该存档后生效。\n原档备份："+console.last_backup
func _build_units(tabs:TabContainer)->void:
	var body:=VBoxContainer.new();body.name="单位基础数值";tabs.add_child(body)
	_label(body,"修改基础数值，装备、难度、波次和暴怒继续在其上计算。召唤物按继承倍率调整。保存到工程 data/unit_balance.json，新启动的游戏使用新数值；不会改写存档中的装备或等级。")
	_units=UnitBalance.catalog();_draft=UnitBalance.snapshot();_unit_picker=OptionButton.new();body.add_child(_unit_picker)
	for entry in _units:_unit_picker.add_item(str(entry.name));_unit_picker.set_item_metadata(_unit_picker.item_count-1,str(entry.id))
	_unit_picker.item_selected.connect(_select_unit)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	_fields=GridContainer.new();_fields.columns=2;_fields.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_fields.add_theme_constant_override("h_separation",24);_fields.add_theme_constant_override("v_separation",8);scroll.add_child(_fields)
	var row:=HBoxContainer.new();body.add_child(row)
	_button(row,"保存全部数值",_save_units);_button(row,"恢复此单位默认值",_reset_unit);_button(row,"重新载入已保存值",func()->void:UnitBalance.reload();_draft=UnitBalance.snapshot();_dirty=false;_select_unit(_unit_picker.selected))
	_button(row,"恢复全部默认值",func()->void:_draft.clear();_dirty=true;_select_unit(_unit_picker.selected))
	_unit_status=_label(body,"");_select_unit(0)
func _select_unit(index:int)->void:
	if index<0 or index>=_units.size():return
	_selected=str(_units[index].id)
	for child in _fields.get_children():_fields.remove_child(child);child.queue_free()
	var stats:Dictionary=_units[index].stats
	for stat in stats:
		_label(_fields,str(STAT_NAMES.get(stat,stat))+"  （默认 %s）"%str(stats[stat]))
		var number:=SpinBox.new();number.min_value=0;number.max_value=10000000;number.step=.01;number.custom_minimum_size.x=210;number.value=float(_draft.get(_selected,{}).get(stat,stats[stat]));_fields.add_child(number)
		var id:=_selected;var key:=str(stat)
		number.value_changed.connect(func(value:float)->void:
			if not _draft.has(id):_draft[id]={}
			_draft[id][key]=value;_dirty=true;_unit_status.text="有未保存修改。")
	_unit_status.text="稳定ID："+_selected+(" · 有未保存修改" if _dirty else "")
func _reset_unit()->void:
	_draft.erase(_selected);_dirty=true;_select_unit(_unit_picker.selected)
func _save_units()->void:
	var error:=UnitBalance.save(_draft)
	if error==OK:_dirty=false
	_unit_status.text="数值已保存；新启动游戏后生效。" if error==OK else "保存失败："+error_string(error)
func _close()->void:
	if not _dirty:queue_free();return
	var dialog:=ConfirmationDialog.new();dialog.dialog_text="单位数值有未保存修改。丢弃并返回地图编辑器？";add_child(dialog);dialog.confirmed.connect(queue_free);dialog.popup_centered();dialog.get_cancel_button().grab_focus()
