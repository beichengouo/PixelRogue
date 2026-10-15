class_name KeyBindings
extends RefCounted
## Keyboard overrides only; controller axes/buttons and menu navigation survive.
const ACTIONS := {
	"ui_accept":"确认 / 继续", "ui_cancel":"返回 / 取消",
	"ui_up":"菜单向上", "ui_down":"菜单向下", "ui_left":"菜单向左", "ui_right":"菜单向右",
	"room_up":"向上移动", "room_down":"向下移动", "room_left":"向左移动", "room_right":"向右移动",
	"room_aim_up":"向上射击", "room_aim_down":"向下射击", "room_aim_left":"向左射击", "room_aim_right":"向右射击",
	"dash":"闪避", "interact":"交互 / 采集", "inventory":"背包", "talents":"天赋", "room_map":"地图", "pause_menu":"暂停",
	"skill_1":"技能 1", "skill_2":"技能 2", "skill_3":"技能 3", "ultimate":"大招",
	"potion_1":"药剂 1", "potion_2":"药剂 2", "potion_3":"药剂 3", "call_goddess":"呼唤女神", "start_wave":"开始下一场", "restart":"重新开始"
}
static var _defaults:Dictionary={}

static func apply()->void:
	if _defaults.is_empty():
		for action:String in ACTIONS:
			_defaults[action]=[]
			if not InputMap.has_action(action):continue
			for event in InputMap.action_get_events(action):
				if event is InputEventKey:_defaults[action].append(event.duplicate())
	var saved:Variant=SaveService.data.get("keyboard_bindings",{})
	if not saved is Dictionary:return
	for action:String in ACTIONS:
		if not saved.has(action):continue
		var raw:Variant=saved[action]
		if (raw is int or raw is float) and int(raw)>0 and not OS.get_keycode_string(int(raw)).is_empty():_replace(action,int(raw))

static func _replace(action:String,code:int)->void:
	if not InputMap.has_action(action):return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:InputMap.action_erase_event(action,event)
	var event:=InputEventKey.new();event.physical_keycode=code
	InputMap.action_add_event(action,event)
	Input.action_release(action)

static func label(action:String)->String:
	if MobileControls.enabled():return str(MobileControls.LABELS.get(action,"点按"))
	if not InputMap.has_action(action):return "—"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
			return "空格" if code==KEY_SPACE else OS.get_keycode_string(code)
	return "—"

static func conflict(action:String,code:int)->String:
	for other:String in ACTIONS:
		if other==action:continue
		# These shared defaults operate in separate UI/gameplay contexts.
		if action in ["ui_accept","start_wave"] and other in ["ui_accept","start_wave"]:continue
		if action in ["ui_cancel","pause_menu"] and other in ["ui_cancel","pause_menu"]:continue
		var menus:=["ui_up","ui_down","ui_left","ui_right"]
		var directions:=["room_up","room_down","room_left","room_right","room_aim_up","room_aim_down","room_aim_left","room_aim_right"]
		if (action in menus and other in directions) or (other in menus and action in directions):continue
		for event in InputMap.action_get_events(other):
			if event is InputEventKey and code==(event.physical_keycode if event.physical_keycode!=0 else event.keycode):return str(ACTIONS[other])
	return ""

static func bind(action:String,code:int)->String:
	apply()
	if not ACTIONS.has(action) or code<=0 or OS.get_keycode_string(code).is_empty():return "请选择有效的键盘按键"
	var occupied:=conflict(action,code)
	if not occupied.is_empty():return "该键已用于「%s」，请先修改那项操作"%occupied
	var stored:Variant=SaveService.data.get("keyboard_bindings",{})
	var previous:Dictionary=stored.duplicate(true) if stored is Dictionary else {}
	var updated:=previous.duplicate(true);updated[action]=code;SaveService.data.keyboard_bindings=updated
	if not SaveService.save_data():SaveService.data.keyboard_bindings=previous;return "保存失败，键位未修改"
	_replace(action,code)
	return ""

static func reset()->bool:
	apply()
	var stored:Variant=SaveService.data.get("keyboard_bindings",{})
	var previous:Dictionary=stored.duplicate(true) if stored is Dictionary else {}
	SaveService.data.keyboard_bindings={}
	if not SaveService.save_data():SaveService.data.keyboard_bindings=previous;return false
	for action:String in _defaults:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:InputMap.action_erase_event(action,event)
		for event in _defaults[action]:InputMap.action_add_event(action,event.duplicate())
	return true

static func help_rows()->Array[Array]:
	if MobileControls.enabled():return [["移动","左侧摇杆"],["普通攻击","右側摇杆瞄准连射" if not RoomInput.using_auto() else "自动攻击最近敌人 · 战斗金币减半"],["技能 / 大招","点按底部中央对应按钮"],["药剂","点按底部中央药剂按钮"],["闪避 / 交互","点按闪避 / 交互按钮"],["背包 / 天赋","点按对应功能按钮"],["地图 / 暂停","点按地图 / 暂停按钮"],["呼唤女神","点按撤离按钮"],["菜单确认","点按按钮；安卓返回键可返回"]]
	if UIFlow.gamepad:return [["移动","左摇杆"],["普通攻击","右摇杆瞄准连射" if not RoomInput.using_auto() else "自动攻击最近敌人 · 战斗金币减半"],["闪避","B"],["交互","Y"],["技能 / 大招","LB / RB / LT 技能 · RT 大招"],["呼唤女神","十字键 ↓"],["菜单确认","A 确认 · B 返回"]]
	var attack:="鼠标指向 · 按住左键连续攻击" if RoomInput.using_mouse() else "%s / %s / %s / %s 瞄准并连射"%[label("room_aim_up"),label("room_aim_left"),label("room_aim_down"),label("room_aim_right")]
	if RoomInput.using_auto():attack="自动攻击最近敌人 · 战斗金币减半"
	return [["移动","%s / %s / %s / %s"%[label("room_up"),label("room_left"),label("room_down"),label("room_right")]],["普通攻击",attack],["闪避",label("dash")],["交互",label("interact")],["技能 / 大招","%s / %s / %s · 大招 %s"%[label("skill_1"),label("skill_2"),label("skill_3"),label("ultimate")]],["药剂","%s / %s / %s"%[label("potion_1"),label("potion_2"),label("potion_3")]],["背包 / 天赋","%s / %s"%[label("inventory"),label("talents")]],["地图 / 暂停","%s / %s"%[label("room_map"),label("pause_menu")]],["呼唤女神",label("call_goddess")],["确认 / 返回","%s / %s"%[label("ui_accept"),label("ui_cancel")]]]
static func battle_hint()->String:
	var lines:PackedStringArray=[]
	for row:Array in help_rows():lines.append("%s：%s"%[row[0],row[1]])
	return "\n".join(lines)
