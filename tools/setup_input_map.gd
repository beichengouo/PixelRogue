extends SceneTree
## 一次性工具：把按键映射写进 project.godot。
##
## 用法（在工程根目录执行）：
##   "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" ^
##       --headless --path . --script res://tools/setup_input_map.gd
##
## 之所以用脚本而不是让人手写 project.godot：让引擎自己序列化，格式一定是对的。
## 想改键，改下面的表再跑一次即可；也可以以后在游戏里做改键界面。

const KEYBOARD := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	# 弹幕方向：W/↑ = 朝上（配合左右就是 45° 斜射），S/↓ = 朝下
	"aim_up": [KEY_W, KEY_UP],
	"aim_down": [KEY_S, KEY_DOWN],
	# 下穿单向平台要用的「下」，和 aim_down 是同一批键
	"move_down": [KEY_S, KEY_DOWN],
	# 跳跃只留空格：上/W 让给瞄准，不然「按上瞄准」会变成「往上跳」
	"jump": [KEY_SPACE],
	"attack": [KEY_J],
	"dash": [KEY_K, KEY_SHIFT],
	"interact": [KEY_E],
	# 打开背包 / 装备栏
	"inventory": [KEY_I, KEY_TAB],
	# 药水快捷栏（战斗中点一下就用）
	"potion_1": [KEY_1],
	"potion_2": [KEY_2],
	"potion_3": [KEY_3],
	# 特殊技能（消耗魔法值）
	"skill_1": [KEY_Q],
	"skill_2": [KEY_F],
	"skill_3": [KEY_G],
	"ultimate": [KEY_V],
	# 天赋面板
	"talents": [KEY_T],
	"start_wave": [KEY_ENTER],
	"restart": [KEY_R],
	"pause_menu": [KEY_ESCAPE],
}

const GAMEPAD_BUTTONS := {
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"aim_up": [JOY_BUTTON_DPAD_UP],
	"aim_down": [JOY_BUTTON_DPAD_DOWN],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"jump": [JOY_BUTTON_A],
	"attack": [JOY_BUTTON_X],
	"dash": [JOY_BUTTON_B],
	"interact": [JOY_BUTTON_Y],
	"skill_1": [JOY_BUTTON_LEFT_SHOULDER],
	"skill_2": [JOY_BUTTON_RIGHT_SHOULDER],
	"talents": [JOY_BUTTON_DPAD_UP],
	"start_wave": [JOY_BUTTON_START],
	"pause_menu": [JOY_BUTTON_BACK],
}

const GAMEPAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"aim_up": [JOY_AXIS_LEFT_Y, -1.0],
	"aim_down": [JOY_AXIS_LEFT_Y, 1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}

## 鼠标：不参与战斗操作。
## 以前左键触发攻击、攻击方向跟鼠标走，但「角色不动只动鼠标」这种情况
## 会让弹幕朝奇怪的方向飞（比如往地里打），现在弹幕方向完全由方向键决定。
const MOUSE_BUTTONS := {}


func _initialize() -> void:
	var actions := {}
	for action: String in KEYBOARD:
		actions[action] = []
	for action: String in KEYBOARD:
		for code: int in KEYBOARD[action]:
			actions[action].append(_key_event(code))
	for action: String in GAMEPAD_BUTTONS:
		for index: int in GAMEPAD_BUTTONS[action]:
			actions[action].append(_pad_button_event(index))
	for action: String in GAMEPAD_AXES:
		actions[action].append(_pad_axis_event(GAMEPAD_AXES[action][0], GAMEPAD_AXES[action][1]))
	for action: String in MOUSE_BUTTONS:
		for index: int in MOUSE_BUTTONS[action]:
			actions[action].append(_mouse_event(index))

	for action: String in actions:
		ProjectSettings.set_setting("input/" + action, {
			"deadzone": 0.25,
			"events": actions[action],
		})

	var err := ProjectSettings.save()
	if err == OK:
		print("[setup_input_map] 已写入 %d 个动作到 project.godot" % actions.size())
	else:
		printerr("[setup_input_map] 保存失败，错误码 %d" % err)
	quit()


func _key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _pad_button_event(index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	return event


func _pad_axis_event(axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _mouse_event(index: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	return event

