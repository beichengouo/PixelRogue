extends Node
var checks := 0
var failures := 0
var commits := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures += 1; printerr("FAIL ", message)
func frames(count := 3) -> void:
 for i in count: await get_tree().process_frame
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 call_deferred("run")
func inject(event: InputEvent) -> void:
 Input.parse_input_event(event)
 await frames()
func key_press(_code: Key) -> void:
 var event: InputEventKey = null
 for binding: InputEvent in InputMap.action_get_events("ui_accept"):
  if binding is InputEventKey:
   event = binding.duplicate() as InputEventKey
   break
 if event == null:
  check(false, "actual keyboard accept binding exists")
  return
 event.pressed = true
 await inject(event)
 event = event.duplicate() as InputEventKey
 event.pressed = false
 await inject(event)
func joy_press(button: JoyButton) -> void:
 var event := InputEventJoypadButton.new()
 event.button_index = button; event.device = 0; event.pressed = true
 await inject(event)
 event = InputEventJoypadButton.new()
 event.button_index = button; event.device = 0; event.pressed = false
 await inject(event)
func activate(control: Control, mode: String) -> void:
 if mode in ["keyboard", "gamepad"]:
  if control is Button: control.grab_focus()
  else:
   var focused := get_viewport().gui_get_focus_owner()
   if focused != null: focused.release_focus()
  await frames()
  if mode == "keyboard": await key_press(KEY_ENTER)
  else: await joy_press(JOY_BUTTON_A)
  return
 # Input.parse_input_event receives physical window coordinates; the viewport applies stretch.
 var at := control.get_global_rect().get_center() * Vector2(get_window().size) / get_viewport().get_visible_rect().size
 if mode == "touch":
  var touch := InputEventScreenTouch.new()
  touch.index = 0; touch.pressed = true; touch.position = at
  await inject(touch)
  touch = InputEventScreenTouch.new()
  touch.index = 0; touch.pressed = false; touch.position = at
  await inject(touch)
 else:
  var mouse := InputEventMouseButton.new()
  mouse.position = at; mouse.global_position = at; mouse.button_index = MOUSE_BUTTON_LEFT
  mouse.button_mask = MOUSE_BUTTON_MASK_LEFT; mouse.pressed = true
  await inject(mouse)
  mouse = InputEventMouseButton.new()
  mouse.position = at; mouse.global_position = at; mouse.button_index = MOUSE_BUTTON_LEFT
  mouse.button_mask = 0; mouse.pressed = false
  await inject(mouse)
func run() -> void:
 if not OS.get_user_data_dir().replace("\\", "/").begins_with("E:/CodexWorkspace/PixelRogue/work/v21-combat-validation/"):
  get_tree().quit(1); return
 AchievementTracker.set_process(false); ErrorReporter.interactive = false
 SaveService.data.reduced_motion = true
 Input.emulate_mouse_from_touch = true
 StoryState.mark_seen(&"intro_wake", &"sylphiette")
 var dialogue := DialogueUI.new()
 add_child(dialogue)
 await frames()
 for extent: Vector2i in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1080), Vector2i(800,1280)]:
  get_window().size = extent
  await frames()
  for mode: String in ["keyboard", "mouse", "gamepad", "touch"]:
   var context := str(extent) + ":" + mode
   dialogue.play_local_lines([{"who":"iris", "text":"第一句，点按或按键继续。"}, {"who":"iris", "text":"第二句，仍由你亲自回答。"}])
   await frames()
   await activate(dialogue._bubble, mode)
   await activate(dialogue._bubble, mode)
   check(dialogue._index == 1 and dialogue.is_open(), "actual input advances dialogue " + context)
   dialogue.cancel()
   await frames()
   commits = 0
   dialogue.play_local_scene({"title":"输入回归", "lines":[{"who":"iris", "text":"请亲自选择这一次的回应。"}], "choices":[
    {"text":"第一项", "reply":[{"who":"iris", "text":"第一项回应。"}]},
    {"text":"第二项", "reply":[{"who":"iris", "text":"第二项回应。"}]}]}, func(_choice: Dictionary) -> bool: commits += 1; return true)
   await frames()
   await activate(dialogue._skip_button, mode)
   await frames(6)
   check(dialogue._choosing and commits == 0, "actual skip control retains uncommitted options " + context)
   var bounds := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
   for node: Control in [dialogue._bubble, dialogue._side, dialogue._skip_button, dialogue._face_art]:
    check(node.is_visible_in_tree() and bounds.grow(1).encloses(node.get_global_rect()), "dialogue controls visible inside viewport " + context + ":" + str(node.name))
   if dialogue._choice_box.get_child_count() == 0:
    dialogue.cancel()
    await frames()
    continue
   var button := dialogue._choice_box.get_child(0) as Button
   button.grab_focus()
   await frames()
   check(get_viewport().gui_get_focus_owner() == button, "choice accepts focus " + context)
   await activate(button, mode)
   check(commits == 1 and dialogue._mode == "reply", "actual input chooses exactly once " + context)
   dialogue.cancel()
   await frames()
   var flags_before := StoryState.flags.duplicate(true)
   var inventory_before := Outpost.data.duplicate(true)
   dialogue.play_replay(&"intro_wake", &"sylphiette")
   await frames()
   check(dialogue.is_open() and dialogue._skip_button.text == "关闭回看" and bounds.grow(1).encloses(dialogue._skip_button.get_global_rect()), "replay close control visible " + context)
   await activate(dialogue._skip_button, mode)
   await get_tree().create_timer(.12, true, false, true).timeout
   await frames()
   check(not dialogue.is_open(), "actual input closes replay " + context)
   check(StoryState.flags == flags_before and Outpost.data == inventory_before, "replay input cannot change progress or warehouse " + context)
 dialogue.queue_free()
 await frames()
 AudioManager.shutdown()
 await get_tree().create_timer(.25, true, false, true).timeout
 print("V21_DIALOGUE_INPUT checks=", checks, " failures=", failures, " android_device_tested=false")
 get_tree().quit(1 if failures else 0)
