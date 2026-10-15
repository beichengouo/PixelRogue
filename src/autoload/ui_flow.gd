extends Node
## A screen owns a pause lease until its exit animation completes.
signal stack_changed
signal input_device_changed
signal navigation_mode_changed
var gamepad := false
var pointer_active := true
var background_paused := false
var _stack: Array[Dictionary] = []
var _huds: Array[WeakRef] = []

func _ready() -> void:
	if "--room-editor" in OS.get_cmdline_user_args():return
	process_mode = Node.PROCESS_MODE_ALWAYS
	RoomInput.install.call_deferred()
	if not InputMap.has_action("room_map"):
		InputMap.add_action("room_map")
		var key:=InputEventKey.new();key.physical_keycode=KEY_M;InputMap.action_add_event("room_map",key)
	# Keep existing bindings while ensuring every menu has controller confirm/back.
	for binding in [[&"ui_accept", JOY_BUTTON_A], [&"ui_cancel", JOY_BUTTON_B]]:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = int(binding[1])
		if not InputMap.action_has_event(binding[0], event):
			InputMap.action_add_event(binding[0], event)

func bind_hud(node: CanvasLayer) -> void:
	_huds = _huds.filter(func(reference: WeakRef) -> bool: return reference.get_ref() != null)
	_huds.append(weakref(node))
	_sync()

func can_open(owner: Node) -> bool:
	var top := top_screen()
	return top == null or top == owner or top == get_node_or_null("/root/TransitionLayer") or not bool(top.get_meta("blocking_screen", false))

func push_screen(owner: Node) -> void:
	for entry in _stack:
		if entry.id == owner.get_instance_id(): return
	var focused := get_viewport().gui_get_focus_owner()
	var entry := {"id": owner.get_instance_id(), "owner": weakref(owner), "focus": weakref(focused) if focused != null else null}
	if top_screen() == get_node_or_null("/root/TransitionLayer") and owner != top_screen():
		_stack.insert(_stack.size() - 1, entry)
	else:
		_stack.append(entry)
	var cleanup := _remove_id.bind(owner.get_instance_id())
	if not owner.tree_exiting.is_connected(cleanup): owner.tree_exiting.connect(cleanup, CONNECT_ONE_SHOT)
	_sync()

func pop_screen(owner: Node) -> void:
	_remove_id(owner.get_instance_id())

func _remove_id(id: int) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if int(_stack[i].id) != id: continue
		var entry: Dictionary = _stack[i]
		var was_top := i == _stack.size() - 1
		_stack.remove_at(i)
		_sync()
		if was_top and entry.focus != null:
			_restore_focus.call_deferred(entry.focus)
		return

func _restore_focus(reference: WeakRef) -> void:
	var node: Variant = reference.get_ref()
	if not is_instance_valid(node) or not node.is_visible_in_tree(): return
	var top := top_screen()
	if top == null or top.is_ancestor_of(node): node.grab_focus()

func top_screen() -> Node:
	if _stack.is_empty(): return null
	return _stack.back().owner.get_ref() as Node

func is_top(owner: Node) -> bool:
	return top_screen() == owner

func has_screen() -> bool:
	return not _stack.is_empty()

func refresh() -> void:
	_sync()

func _sync() -> void:
	get_tree().paused = background_paused or not _stack.is_empty()
	var backdrop:Node=null
	var top:=top_screen()
	if top!=null and bool(top.get_meta("show_previous_screen",false)) and _stack.size()>1:
		backdrop=_stack[_stack.size()-2].owner.get_ref() as Node
	for entry in _stack:
		var owner: Variant = entry.owner.get_ref()
		if is_instance_valid(owner) and owner is CanvasLayer:
			owner.visible = owner == top or owner == backdrop
	for reference in _huds:
		var node: Variant = reference.get_ref()
		if is_instance_valid(node): node.visible = _stack.is_empty()
	stack_changed.emit()
	_focus_top.call_deferred()

func _focus_top() -> void:
	var owner := top_screen()
	if owner == null: return
	var current := get_viewport().gui_get_focus_owner()
	if current != null and current.is_visible_in_tree() and owner.is_ancestor_of(current): return
	for node in owner.find_children("*", "Control", true, false):
		if node is BaseButton and not node.disabled and node.is_visible_in_tree() and node.focus_mode == Control.FOCUS_ALL:
			node.grab_focus()
			return

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length_squared() > 0.0):
		set_pointer_active(true)
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.35):
		set_pointer_active(false)
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_TAB or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept")):
		set_pointer_active(false)
	var next := gamepad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.35): next = true
	elif event is InputEventKey or event is InputEventMouseButton: next = false
	if next != gamepad:
		gamepad = next
		input_device_changed.emit()

func set_pointer_active(value: bool) -> void:
	if pointer_active == value: return
	pointer_active = value
	navigation_mode_changed.emit()

func hint(action: StringName) -> String:
	if MobileControls.enabled():return str(MobileControls.LABELS.get(str(action),"点按"))
	var names := {JOY_BUTTON_A:"A", JOY_BUTTON_B:"B", JOY_BUTTON_X:"X", JOY_BUTTON_Y:"Y", JOY_BUTTON_BACK:"View", JOY_BUTTON_LEFT_STICK:"L3", JOY_BUTTON_RIGHT_STICK:"R3", JOY_BUTTON_START:"Start", JOY_BUTTON_LEFT_SHOULDER:"LB", JOY_BUTTON_RIGHT_SHOULDER:"RB", JOY_BUTTON_DPAD_UP:"↑", JOY_BUTTON_DPAD_DOWN:"↓", JOY_BUTTON_DPAD_LEFT:"←", JOY_BUTTON_DPAD_RIGHT:"→"}
	for event in InputMap.action_get_events(action):
		if gamepad and event is InputEventJoypadButton: return str(names.get(event.button_index, "手柄"))
		if gamepad and event is InputEventJoypadMotion:
			if event.axis == JOY_AXIS_RIGHT_Y and event.axis_value < 0: return "右摇杆↑"
			if event.axis == JOY_AXIS_TRIGGER_LEFT: return "LT"
			if event.axis == JOY_AXIS_TRIGGER_RIGHT: return "RT"
		if not gamepad and event is InputEventKey:
			var code:int=event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return "空格" if code==KEY_SPACE else OS.get_keycode_string(code)
	return "—"
