class_name DialogueButtonArt
extends RefCounted
## Live captions replace the retired painted button plates.
static var _textures:Dictionary={}
static func action_button()->Button:
	var button:=PixelUi.button("继续",20,188,44);InteractionSkin.apply_button(button,"dialogue");return button
static func set_show_full(button:Button,full:bool)->void:
	button.text="显示全文" if full else "继续";button.tooltip_text=button.text
static func choice_button(caption:String,font_size:=18,height:=52.0)->Button:
	var button:=PixelUi.button(caption,font_size,0,height);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;InteractionSkin.apply_button(button,"dialogue")
	for state in ["normal","hover","pressed","focus","disabled"]:
		var box:=StyleBoxFlat.new();box.bg_color=Color("101b2b",.94 if state=="normal" else .98);box.border_color=Color("c7aa73",.85 if state=="focus" or state=="hover" else .42);box.set_border_width_all(2 if state=="focus" else 1);box.set_corner_radius_all(9);box.content_margin_left=18;box.content_margin_right=18;button.add_theme_stylebox_override(state,box)
	button.add_theme_color_override("font_color",Color("f7f2e8"));button.add_theme_color_override("font_hover_color",Color.WHITE);button.add_theme_color_override("font_focus_color",Color.WHITE);button.add_theme_color_override("font_pressed_color",Color.WHITE);button.add_theme_color_override("font_disabled_color",Color("c1bec0"))
	return button
