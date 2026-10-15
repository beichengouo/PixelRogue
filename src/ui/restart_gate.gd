class_name RestartGate
extends CanvasLayer
## 长按 R 挂起当前出征并返回营地准备。
##
## 为什么不直接按 R 就重开：R 离方向键很近，战斗中手滑一下就白打一局。
## 必须按住 0.8 秒，底部进度填满后打开营地；保存失败时留在本局。
##
## 这一层用 PROCESS_MODE_ALWAYS，所以在暂停界面、死亡结算界面里同样有效。

signal restart_confirmed()

const HOLD_TIME := 0.8         # 需要按住多久
const FADE_OUT := 0.6          # 渐黑时长
const FADE_IN := 0.35          # 重开后再亮回来
const BAR_WIDTH := 220.0

## 主菜单打开时关掉，免得在标题页误触重开
var enabled := true

var _root: Control
var _fade: ColorRect
var _hint: Control
var _bar_fill: ColorRect
var _hold := 0.0
var _holding := false
var _busy := false


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = UiFactory.full_rect()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 渐黑用的黑幕：平时完全透明，且不吃鼠标事件
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	_build_hint()


func _build_hint() -> void:
	_hint = UiFactory.vbox(6)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -132.0
	_hint.offset_bottom = -70.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	_root.add_child(_hint)

	_hint.add_child(UiFactory.outlined_label("长按 R 重开本局…", 20, Palette.UI_TEXT, 5))

	var row := UiFactory.hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hint.add_child(row)

	var track := Control.new()
	track.custom_minimum_size = Vector2(BAR_WIDTH, 10.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(track)
	var back := ColorRect.new()
	back.color = Color(1.0, 1.0, 1.0, 0.22)
	back.size = Vector2(BAR_WIDTH, 10.0)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Palette.GOLD
	_bar_fill.size = Vector2(0.0, 10.0)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_bar_fill)


func _input(event: InputEvent) -> void:
	pass


func _process(delta: float) -> void:
	## 用轮询而不是收输入事件：这样无论是真键盘、手柄还是脚本模拟按键，
	## 判定逻辑都是同一套，也不会有别的界面把按键事件吃掉导致长按失效。
	var top := UIFlow.top_screen()
	var runtime: Variant = GameState.runtime_node
	var extracting: bool = is_instance_valid(runtime) and is_instance_valid(runtime.extraction) and runtime.extraction.blocks_input()
	if extracting or not enabled or _busy or TransitionLayer.busy or (top != null and not top is PauseUI and not top is GameOverUI):
		_holding = false
		_hold = 0
		_hint.hide()
		return
	if Input.is_action_just_pressed("restart"):
		_holding = true
		_hold = 0.0
		_bar_fill.size = Vector2(0.0, 10.0)
		_hint.visible = true
	if not _holding:
		return
	if not Input.is_action_pressed("restart"):
		_holding = false
		_hold = 0.0
		_hint.visible = false
		return
	_hold += delta
	var ratio := clampf(_hold / HOLD_TIME, 0.0, 1.0)
	_bar_fill.size = Vector2(BAR_WIDTH * ratio, 10.0)
	if ratio >= 1.0:
		_confirm()


func _confirm() -> void:
	_holding = false
	_busy = true
	_hint.visible = false
	AudioManager.play(&"wave_start", -6.0)
	
	restart_confirmed.emit()
	_release_busy()

func _release_busy() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_busy=false
