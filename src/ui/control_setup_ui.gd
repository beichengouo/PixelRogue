class_name ControlSetupUI
extends CanvasLayer
signal chosen
var _root:Control
var _status:Label
var _aim_guide:CheckButton
func _ready()->void:
	layer=45;process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true)
	_root=UiFactory.full_rect();add_child(_root);_root.add_child(UiFactory.dim_layer(0.42))
	var frame:=StarUi.frame(_root,Vector2(680,510));var body:=UiFactory.vbox(20);body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);frame.add_child(body)
	body.add_child(PixelUi.title("选择你的攻击方式",28))
	var description:=PixelUi.label("左侧摇杆移动，右侧摇杆瞄准连射；技能、闪避和交互使用独立触屏按钮。攻击方式只能在营地或安全房间更改。" if MobileControls.enabled() else "移动、技能和闪避使用同一套按键。攻击方式可在营地或安全房间的设置里更改。",18);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(description)
	_aim_guide=CheckButton.new();_aim_guide.name="MouseAimGuide";_aim_guide.text="鼠标模式：开启红色虚线瞄准指引"
	_aim_guide.button_pressed=bool(SaveService.data.get("mouse_aim_guide",true));body.add_child(_aim_guide)
	if MobileControls.enabled():_aim_guide.text="自由瞄准：开启红色虚线指引"
	var options:=[ ["mouse","自由瞄准 · 右摇杆 360° 瞄准并连射"],["keyboard","八向瞄准 · 右摇杆八方向瞄准并连射"],["auto","自动攻击 · 普攻最近敌人，战斗金币减半"] ] if MobileControls.enabled() else [["mouse","鼠标模式 · 指向瞄准，按住左键连续攻击"],["keyboard","键盘模式 · 使用方向键瞄准并连续攻击"],["auto","自动攻击 · 普攻最近敌人，战斗金币减半"]]
	for option in options:
		var mode:String=option[0];var button:=PixelUi.button(str(option[1]),19);body.add_child(button);button.pressed.connect(select_mode.bind(mode))
	_status=PixelUi.label("",16,PixelUi.GOLD);body.add_child(_status);UIFlow.push_screen(self);PixelUi.focus_button(_root)
	InteractionSkin.mount(_root,"controls",frame)

func select_mode(mode:String)->bool:
	if mode not in RoomInput.ATTACK_MODES:return false
	if bool(SaveService.data.get("control_setup_done",false)) and not RoomInput.can_change_attack_mode():_status.text="只能在营地或安全房间更换攻击方式。";return false
	var old:Dictionary=SaveService.data.duplicate(true)
	SaveService.data.attack_mode=mode;SaveService.data.control_setup_done=true
	SaveService.data.mouse_aim_guide=_aim_guide.button_pressed
	if not SaveService.save_data():SaveService.data=old;_status.text="暂时无法保存，请重试。";return false
	UIFlow.pop_screen(self);chosen.emit();queue_free();return true
