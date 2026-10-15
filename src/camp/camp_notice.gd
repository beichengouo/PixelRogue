class_name CampNotice
extends CanvasLayer
signal dismissed
var message := ""
var title := "系统提示"
func _ready()->void:
	layer=42;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true)
	var root:=UiFactory.full_rect();add_child(root);root.add_child(UiFactory.dim_layer(0.42))
	var frame:=StarUi.frame(root,Vector2(600,360));var box:=UiFactory.vbox(18);frame.add_child(box);box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(PixelUi.title(title,26));var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(scroll)
	var text:=PixelUi.label(message,20);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(text)
	var button:=PixelUi.button("知道了",20);box.add_child(button);button.pressed.connect(close)
	UIFlow.push_screen(self);button.grab_focus.call_deferred()
	InteractionSkin.mount(root,"notice",frame)

func close()->void:
	UIFlow.pop_screen(self);dismissed.emit();queue_free()
func _unhandled_input(event:InputEvent)->void:
	if UIFlow.is_top(self) and event.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
