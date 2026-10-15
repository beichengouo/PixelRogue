class_name DialogueButtonArt
extends RefCounted
## Live captions replace the retired painted button plates.
static var _textures:Dictionary={}
static func action_button()->Button:
	var button:=PixelUi.button("继续",20,188,44);InteractionSkin.apply_button(button,"dialogue");return button
static func set_show_full(button:Button,full:bool)->void:
	button.text="显示全文" if full else "继续";button.tooltip_text=button.text
static func choice_button(caption:String,font_size:=18,height:=52.0)->Button:
	var button:=PixelUi.button(caption,font_size,0,height);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;InteractionSkin.apply_button(button,"dialogue");return button
