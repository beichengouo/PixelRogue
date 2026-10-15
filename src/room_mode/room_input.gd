class_name RoomInput
extends RefCounted
const ATTACK_MODES:=["keyboard","mouse","auto"]
const ACTIONS := {"room_left":KEY_A,"room_right":KEY_D,"room_up":KEY_W,"room_down":KEY_S,
	"room_aim_left":KEY_LEFT,"room_aim_right":KEY_RIGHT,"room_aim_up":KEY_UP,"room_aim_down":KEY_DOWN}
static func install() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var event := InputEventKey.new(); event.physical_keycode = ACTIONS[action]
		InputMap.action_add_event(action,event)
	if not InputMap.has_action("room_call_goddess"):
		InputMap.add_action("room_call_goddess")
		var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_DPAD_DOWN;event.device=-1
		InputMap.action_add_event("room_call_goddess",event)
	KeyBindings.apply()

static func quantize(value: Vector2) -> Vector2:
	if value.length() < 0.25: return Vector2.ZERO
	return Vector2.RIGHT.rotated(roundf(value.angle()/(PI/4.0))*PI/4.0)

static func movement() -> Vector2:
	if MobileControls.enabled() and MobileControls.move_finger>=0:return MobileControls.move_vector.normalized() if MobileControls.move_vector.length()>.25 else Vector2.ZERO
	var direction := Input.get_vector("room_left","room_right","room_up","room_down")
	for pad in Input.get_connected_joypads():
		var stick := Vector2(Input.get_joy_axis(pad,JOY_AXIS_LEFT_X),Input.get_joy_axis(pad,JOY_AXIS_LEFT_Y))
		if stick.length()>0.25: direction = quantize(stick)
	return quantize(direction)

static func aim() -> Vector2:
	if MobileControls.enabled() and MobileControls.aim_finger>=0:return MobileControls.direction()
	var direction := Input.get_vector("room_aim_left","room_aim_right","room_aim_up","room_aim_down")
	for pad in Input.get_connected_joypads():
		var stick := Vector2(Input.get_joy_axis(pad,JOY_AXIS_RIGHT_X),Input.get_joy_axis(pad,JOY_AXIS_RIGHT_Y))
		if stick.length()>0.25: direction = quantize(stick)
	return quantize(direction)

static func using_mouse() -> bool:
	return str(SaveService.data.get("attack_mode","keyboard"))=="mouse" and not UIFlow.gamepad

static func using_auto()->bool:return str(SaveService.data.get("attack_mode","keyboard"))=="auto"

static func can_change_attack_mode()->bool:
	if CampSession.active:return true
	if not is_instance_valid(GameState.runtime_node):return false
	var runtime:=GameState.runtime_node as RoomRuntime
	return is_instance_valid(runtime) and GameState.run_active and is_instance_valid(runtime.extraction) and (runtime.extraction as RoomExtraction).room_is_safe()

static func set_attack_mode(mode:String)->String:
	if mode not in ATTACK_MODES:return "请选择有效的攻击方式。"
	if not can_change_attack_mode():return "只能在营地或安全房间更换攻击方式。"
	var before:String=str(SaveService.data.get("attack_mode","keyboard"));SaveService.data.attack_mode=mode
	if not SaveService.save_data():SaveService.data.attack_mode=before;return "保存失败，攻击方式未修改。"
	return ""

static func auto_aim(actor:RoomPlayer)->Vector2:
	var best:EnemyBase;var distance:=float(WeaponArt.profile().get("reach",540.0))
	for node in actor.get_tree().get_nodes_in_group("enemies"):
		var enemy:=node as EnemyBase
		if not is_instance_valid(enemy) or enemy._dead or enemy.hp<=0 or enemy.is_queued_for_deletion():continue
		var candidate:=actor.global_position.distance_to(enemy.global_position)
		if candidate<distance and actor.room.sight(actor.global_position,enemy.global_position):best=enemy;distance=candidate
	return (best.global_position-actor.global_position).normalized() if is_instance_valid(best) else Vector2.ZERO

static func pointer_aim(actor: Node2D) -> Vector2:
	if MobileControls.enabled():return MobileControls.direction()
	# Canvas inverse includes the moving camera, zoom and viewport stretch.
	var offset := actor.get_global_mouse_position()-actor.global_position
	return offset.normalized() if offset.length_squared()>1.0 else Vector2.ZERO
