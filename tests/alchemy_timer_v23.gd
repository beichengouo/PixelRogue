extends Node
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",message)
func frames(count:=4)->void:
	for index in count:await get_tree().process_frame
func _ready()->void:call_deferred("run")
func click(position:Vector2)->void:
	var motion:=InputEventMouseMotion.new();motion.position=position;motion.global_position=position;get_viewport().push_input(motion,true)
	for pressed:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=position;event.global_position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;get_viewport().push_input(event,true)
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);Outpost.set_process(false)
	SaveService.data.control_setup_done=true;SaveService.data.reduced_motion=true;Outpost.data.active={};Outpost.pending_checkpoint=false;Outpost.data.inventory={};Outpost.data.capacity=2000;Outpost.data.workshop={"unlocked":{},"goal":""};Outpost.data.contract_jobs={}
	for id in ExpeditionData.MATERIALS:Outpost.data.inventory[id]=100
	CampSession.begin(self)
	var ui:=MaterialWorkshopUI.new();add_child(ui);ui.open_camp("alchemy");await frames(6)
	check(ui.is_open(),"open actual camp alchemy")
	for attempt in 3:
		var numbers:=ui._body.find_children("*","SpinBox",true,false)
		check(not numbers.is_empty(),"actual quantity control exists")
		if numbers.is_empty():break
		var spin:=numbers[0] as SpinBox;var before:=spin.value
		ui._scroll.ensure_control_visible(spin);await frames()
		var rect:=spin.get_global_rect();click(Vector2(rect.end.x-8,rect.position.y+rect.size.y*.25));await frames(6)
		check(int(ui._quantities.values().max())==int(before)+1 if not ui._quantities.is_empty() else false,"arrow click updates draft quantity")
	var timer_errors:=0
	for entry in ErrorReporter.entries:
		if str(entry.get("file","")).contains("timer.cpp") and str(entry.get("function",""))=="start":timer_errors+=int(entry.get("count",1))
	print("ALCHEMY_TIMER_CAPTURE ",timer_errors)
	check(timer_errors==0,"quantity arrow never starts orphaned SpinBox timer")
	ui.close();ui.queue_free();CampSession.end(self);await frames();AudioManager.shutdown();await frames()
	print("ALCHEMY_TIMER_V23 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
