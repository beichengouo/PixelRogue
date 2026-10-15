class_name SpecialMachineUI
extends CanvasLayer
var controller:SpecialRoomController
var machine:=""
var _result:Label
var _play:Button
var _stake:SpinBox
var _digits:LineEdit
var _wheel:TextureRect
var _closing:=false
var _prize_icons:HBoxContainer
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;layer=44;set_meta("blocking_screen",true)
	var root:=UiFactory.full_rect();add_child(root);root.add_child(UiFactory.dim_layer(0.42))
	var frame:=StarUi.frame(root,Vector2(760,620));var column:=UiFactory.vbox(10);frame.add_child(column);column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_child(PixelUi.title(str(controller.TITLES[machine]),28))
	var rules:=PixelUi.label("每间房每台装置只能游玩一次。",18);rules.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(rules)
	if machine=="machine_wheel":
		rules.text+="\n固定投入500金币。五种结果各20%：适用传说武器、1000金币、三个需钥匙的宝箱、五把钥匙、谢谢惠顾。"
		_wheel=TextureRect.new();_wheel.texture=SpecialRoomArt.room_icon("game");_wheel.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_wheel.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_wheel.custom_minimum_size=Vector2(120,110);column.add_child(_wheel)
	elif machine=="machine_lottery":
		rules.text+="\n输入八位数字，按相同位置对号；每猜中一位，获得投入额的50%。最低投入50金币，最高八位全部命中为四倍。"
		_digits=LineEdit.new();_digits.max_length=8;_digits.placeholder_text="八位数字，例如00123456";_digits.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_DEFAULT;_digits.custom_minimum_size.y=58;column.add_child(_digits)
		_stake=SpinBox.new();_stake.min_value=50;_stake.max_value=maxi(50,GameState.coins);_stake.allow_greater=false;_stake.allow_lesser=false;_stake.step=1;_stake.value=50;_stake.prefix="投入金币 ";column.add_child(_stake)
	else:rules.text="这台古老星匣尚未苏醒，暂时没有可游玩的功能，也不会扣除金币。"
	_prize_icons=UiFactory.hbox(8);_prize_icons.alignment=BoxContainer.ALIGNMENT_CENTER;column.add_child(_prize_icons)
	_result=PixelUi.label("随身金币：%d"%GameState.coins,18,PixelUi.GOLD);_result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_result.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(_result)
	_play=PixelUi.button("投入500金币 · 转动" if machine=="machine_wheel" else "刮开彩票",20);column.add_child(_play);_play.pressed.connect(_run)
	_play.visible=machine!="machine_reserved";_play.disabled=bool(controller.state.used.get(machine,false))
	if _play.disabled:_result.text="这台装置已使用过，下一间游戏房可以再次游玩。"
	var close_button:=PixelUi.button("返回房间",20);column.add_child(close_button);close_button.pressed.connect(close)
	UIFlow.push_screen(self);(_digits if _digits!=null else close_button).grab_focus.call_deferred()
	InteractionSkin.mount(root,"machine",frame)

func _run()->void:
	if _play.disabled:return
	var result:=controller.play(machine,int(_stake.value) if _stake!=null else 500,_digits.text if _digits!=null else "")
	if not str(result.get("error","")).is_empty():_result.text=str(result.error);return
	_play.disabled=true
	if _wheel!=null and not ComicMotion.reduced():
		_result.text="星运正在转动……";_wheel.pivot_offset=_wheel.size*.5
		var tween:=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(_wheel,"rotation",TAU*3,1.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_show_result.bind(result))
	else:_show_result(result)
func _show_result(result:Dictionary)->void:
	_result.text=str(result.message)
	if bool(result.get("gm",false)):close.call_deferred();return
	if str(controller.record.get("terrain_layout",{}).get("scene_art",""))!="game_moonboat_v01":return
	var outcome:=int(result.get("outcome",1));var count:=3 if outcome==2 else (5 if outcome==3 else 1)
	for index in count:
		var texture:Texture2D
		if outcome==2:texture=WorldPropArt.chest_texture(0)
		elif outcome==3:texture=load("res://assets/next_revision/loot/key.png")
		elif result.has("weapon"):
			var item_control:=UiFactory.item_icon(result.weapon,42);_prize_icons.add_child(item_control);_animate_prize(item_control,index);continue
		else:texture=SpecialRoomArt.room_icon("shop" if outcome==1 else "game")
		var icon:=TextureRect.new();icon.texture=texture;icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(42,42);icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;_prize_icons.add_child(icon);_animate_prize(icon,index)
func _animate_prize(icon:Control,index:int)->void:
	if ComicMotion.reduced():return
	icon.modulate.a=0;icon.pivot_offset=Vector2(21,21);icon.scale=Vector2.ONE*.8
	var tween:=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.tween_property(icon,"modulate:a",1.0,.25).set_delay(index*.06)
	tween.tween_property(icon,"scale",Vector2.ONE,.25).set_delay(index*.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
func close()->void:
	if _closing:return
	_closing=true;UIFlow.pop_screen(self);queue_free()
func _unhandled_input(event:InputEvent)->void:
	if UIFlow.is_top(self) and event.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
