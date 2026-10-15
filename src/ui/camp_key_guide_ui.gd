class_name CampKeyGuideUI
extends CanvasLayer
signal dismissed
var _status:Label
var _rows:GridContainer
func _ready()->void:
	layer=45;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true)
	var root:=UiFactory.full_rect();add_child(root);root.add_child(UiFactory.dim_layer(.68))
	var frame:=StarUi.frame(root,Vector2(740,640))
	var panel:=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_theme_stylebox_override("panel",InteractionSkin.style("guide"));frame.add_child(panel);InteractionSkin.attach_glass(panel)
	var body:=UiFactory.vbox(14);panel.add_child(body)
	body.add_child(PixelUi.title("出发前，认识你的操作",26))
	var introduction:=PixelUi.label("接下来伊莉丝会带你认识营地。这些提示采用你当前的操作模式和按键设置。",17,PixelUi.MUTED);introduction.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(introduction)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	_rows=GridContainer.new();_rows.columns=2;_rows.add_theme_constant_override("h_separation",22);_rows.add_theme_constant_override("v_separation",9);_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(_rows)
	for row:Array in KeyBindings.help_rows():
		var action:=PixelUi.label(str(row[0]),18,PixelUi.GOLD);action.custom_minimum_size.x=136;action.autowrap_mode=TextServer.AUTOWRAP_OFF;_rows.add_child(action)
		var keys:=PixelUi.label(str(row[1]),18);keys.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;keys.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_rows.add_child(keys)
	var reminder:=PixelUi.label("此弹窗只显示一次。忘记操作时，可在「设置」查看操作说明；键盘按键也可在那里修改。",17,PixelUi.MUTED);reminder.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(reminder)
	_status=PixelUi.label("",16,PixelUi.GOLD);body.add_child(_status)
	var button:=PixelUi.button("开始营地引导",20);body.add_child(button);InteractionSkin.apply_button(button,"guide");button.pressed.connect(close)
	UIFlow.push_screen(self);button.grab_focus.call_deferred()
func close()->void:
	var previous:bool=bool(SaveService.data.get("input_guide_seen",false))
	SaveService.data.input_guide_seen=true
	if not SaveService.save_data():SaveService.data.input_guide_seen=previous;_status.text="保存失败，请重试。";return
	UIFlow.pop_screen(self);dismissed.emit();queue_free()
func _unhandled_input(event:InputEvent)->void:
	if UIFlow.is_top(self) and event.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
