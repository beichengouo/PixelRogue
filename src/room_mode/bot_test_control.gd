class_name BotTestControl
extends Node
## Local adventure test shortcut. Reuses GMPilot; never changes run resources.
const ENABLE_FLAG := "--bot-test"
const HOTKEY := KEY_B
var main

static func available_in_build(debug_build:bool,args:PackedStringArray)->bool:
	return debug_build or args.has(ENABLE_FLAG)

static func available()->bool:
	var args:=OS.get_cmdline_args();args.append_array(OS.get_cmdline_user_args())
	return available_in_build(OS.is_debug_build(),args)

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_key_input(available())
	main.pause_ui.configure_bot_test(available())
	main.pause_ui.bot_test_requested.connect(_from_pause_menu)
	if available():print("[BotTest] 冒险中按 B 或暂停菜单的 Bot 测试启动／停止；F9 留给编辑器挂起／恢复。")

func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.alt_pressed or event.ctrl_pressed or event.shift_pressed or event.meta_pressed:return
	var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if code!=HOTKEY:return
	var reason:=toggle()
	if not reason.is_empty():
		print("[BotTest] ",reason)
		if is_instance_valid(main) and is_instance_valid(main.hud):main.hud.show_banner(reason,2)
	get_viewport().set_input_as_handled()

func _from_pause_menu()->void:
	if not UIFlow.is_top(main.pause_ui) or main.pause_ui._closing:return
	if not UIFlow.can_process():
		main.pause_ui.set_status("请先恢复编辑器中的游戏运行。")
		return
	main.pause_ui.close(true)
	var reason:=toggle()
	if not reason.is_empty():
		main.pause_ui.open();main.pause_ui.set_status(reason)

## Empty return means success; a message explains why a start was refused.
## Stopping remains available while a dialog, pause or transition is active.
func toggle()->String:
	if not available():return "当前构建未启用 Bot 测试。"
	if not is_instance_valid(main) or not is_instance_valid(main.gm_pilot):return "当前场景没有冒险 Bot。"
	if GameState.gm_pilot_active:
		main.gm_pilot.stop();print("[BotTest] 已停止，恢复手动操作。")
		return ""
	if not UIFlow.can_process():return "请先恢复编辑器中的游戏运行。"
	if CampSession.active or not GameState.run_active or not is_instance_valid(main.player) or main.player.hp<=0:
		return "请进入冒险后再启动 Bot。"
	if TransitionLayer.busy or main._navigation_pending or main._room_transfer:return "切房结束后可启动 Bot。"
	if main._extraction_blocks_input() or main.player.extraction_controls_locked():return "接引结束后可启动 Bot。"
	if UIFlow.has_screen() or get_tree().paused:return "请先关闭当前界面，再按 B 启动 Bot。"
	if not main.gm_pilot.activate_for_test():return "现在无法启动 Bot。"
	print("[BotTest] 已启动：",Characters.current_id()," · 种子 ",Rng.run_seed," · 难度 ",GameState.difficulty)
	return ""
