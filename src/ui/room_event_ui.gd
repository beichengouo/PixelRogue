class_name RoomEventUI
extends CanvasLayer
var controller:RoomExpansionController
var column:VBoxContainer
var text:Label
var buttons:VBoxContainer
var _closing:=false
func _ready()->void:
	layer=44;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true)
	var root:=UiFactory.full_rect();add_child(root);root.add_child(UiFactory.dim_layer(0.42))
	var frame:=StarUi.frame(root,Vector2(920,620));var row:=UiFactory.hbox(20);frame.add_child(row);row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var portrait:=TextureRect.new();portrait.texture=load(Characters.portrait_path());portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.custom_minimum_size=Vector2(245,380);row.add_child(portrait)
	column=UiFactory.vbox(12);column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(column)
	column.add_child(PixelUi.title(str(controller.TITLES[controller.state.event_id]),26))
	text=PixelUi.label("",19);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(text)
	buttons=UiFactory.vbox(10);column.add_child(buttons);_refresh()
	var close_button:=PixelUi.button("暂时合上 · 靠近遗留物可继续",17);column.add_child(close_button);close_button.pressed.connect(close)
	UIFlow.push_screen(self)
	InteractionSkin.mount(root,"event",frame)

func _refresh()->void:
	for child in buttons.get_children():buttons.remove_child(child);child.queue_free()
	var stage:=int(controller.state.dialogue);var id:=str(controller.state.event_id)
	if stage<2:
		text.text=str(controller.INTRO[id]) if stage==0 else Characters.current_name()+"\n"+str(controller.REPLIES.get(str(Characters.current_id()),controller.REPLIES.sylphiette)[id])
		var next:=PixelUi.button("继续 · "+UIFlow.hint(&"ui_accept"),20);buttons.add_child(next);next.pressed.connect(_advance);next.grab_focus.call_deferred()
	else:
		text.text="留下怎样的回应？\n本房间只能选择一次；两种选择都不会扣除物资。"
		for index in controller.state.offers.size():
			var offer:Dictionary=controller.state.offers[index];var button:=PixelUi.button(str(offer.name)+"\n"+str(offer.desc),17);button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.custom_minimum_size.y=90;buttons.add_child(button);button.pressed.connect(_claim.bind(index))
		(buttons.get_child(0) as Button).grab_focus.call_deferred()
func _advance()->void:
	controller.state.dialogue=mini(2,int(controller.state.dialogue)+1);controller._checkpoint();_refresh()
func _claim(index:int)->void:
	if not controller.claim_event(index):text.text="保存失败，奖励未发放，请重试。"
func close(preserve_resume:=false)->void:
	if _closing:return
	_closing=true
	if not preserve_resume:controller.state.event_panel_open=false;controller._checkpoint()
	UIFlow.pop_screen(self);queue_free()
func _unhandled_input(event:InputEvent)->void:
	if UIFlow.is_top(self) and event.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
func _exit_tree()->void:
	UIFlow.pop_screen(self)
