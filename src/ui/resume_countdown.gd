class_name ResumeCountdown
extends CanvasLayer
signal finished
var _root:Control
var _number:Label
var _open=false
var _epoch=0
var remaining=3
var _playing=false
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	layer=99
	set_meta("blocking_screen",true)
	_root=UiFactory.full_rect();add_child(_root)
	_root.add_child(UiFactory.dim_layer(0.22))
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_root.add_child(center)
	var stack=UiFactory.vbox(12);center.add_child(stack)
	var title=PixelUi.label("旅途即将继续",25,PixelUi.GOLD);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stack.add_child(title)
	_number=PixelUi.label("3",76);_number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stack.add_child(_number)
	_root.hide()
func is_open()->bool:return _open
func open()->void:
	_epoch+=1;_open=true;remaining=3;_root.show();_number.text="3";UIFlow.push_screen(self)
func play()->bool:
	if _playing:return false
	if not _open:open()
	_playing=true
	var ticket=_epoch
	var deadline=Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<deadline:
		if ticket!=_epoch or not _open or not is_inside_tree():return false
		var value=ceili(float(deadline-Time.get_ticks_msec())/1000.0)
		if remaining!=value:
			remaining=value;_number.text=str(value);ComicMotion.reveal(_number,0.12)
		await get_tree().process_frame
	if ticket!=_epoch or not _open:return false
	# Polling actions cannot inherit a held attack/dash from the countdown.
	for action in ["attack","aim_up","aim_down","aim_left","aim_right","dash","skill_1","skill_2","skill_3","ultimate","pause_menu","inventory","talents","call_goddess"]:
		if InputMap.has_action(action):Input.action_release(action)
	cancel();finished.emit();return true
func cancel()->void:
	_epoch+=1
	_playing=false
	if not _open:return
	_open=false;remaining=0
	if is_instance_valid(_root):_root.hide()
	UIFlow.pop_screen(self)
func _input(_event:InputEvent)->void:
	if _open:get_viewport().set_input_as_handled()
func _exit_tree()->void:cancel()
