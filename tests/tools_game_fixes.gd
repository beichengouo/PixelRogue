extends Node
class Shell:
	extends "res://src/main/game_shell.gd"
	func _ready()->void:pass
	func _process(_dt:float)->void:pass
var failures:=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:call_deferred("run")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	get_tree().create_timer(120).timeout.connect(func()->void:get_tree().quit(2))
	SaveService.data.camp_tutorial={"enabled":false,"completed":true};TransitionLayer.boot_played=true
	var shell:=Shell.new();add_child(shell)
	var camp:=CampWorld.new();shell.add_child(camp);shell.camp=camp
	await get_tree().process_frame
	camp.training_requested.connect(shell._open_training)
	var at:=Vector2(1318,814);camp.player.position=at;camp.player.set_physics_process(false)
	check(camp.facility_interaction_distance("training")<72,"reachable entrance")
	var draft:=camp.preparation.signature()
	camp.enter_training()
	while shell.busy:await get_tree().process_frame
	check(is_instance_valid(shell.training) and shell.training.initialization_success,"facility enters actual training scene")
	check(camp.process_mode==Node.PROCESS_MODE_DISABLED,"camp suspended")
	check(shell.training.camera.is_current() and not camp.camera.enabled,"training owns viewport camera")
	var training:=shell.training
	training.training_ui.open()
	await get_tree().process_frame
	check(training.training_ui.is_open() and UIFlow.is_top(training.training_ui),"configuration opens")
	var cancel:=InputEventAction.new();cancel.action=&"ui_cancel";cancel.pressed=true
	Input.parse_input_event(cancel)
	await get_tree().process_frame
	check(not training.training_ui.is_open() and not UIFlow.has_screen(),"escape closes configuration without reopening")
	training.training_ui.open();await get_tree().process_frame
	for button:Node in training.training_ui._root.find_children("*","Button",true,false):
		if button.text=="继续训练":button.pressed.emit();break
	await get_tree().process_frame
	check(not training.training_ui.is_open() and not get_tree().paused,"continue training button releases pause")
	await shell._close_training()
	check(camp.camera.is_current(),"return restores camp camera")
	check(camp.preparation.signature()==draft and not UIFlow.has_screen(),"return restores draft and releases modal")
	camp.player.position=at;camp.player.set_physics_process(false)
	check(camp.start_navigation("facility","training"),"map training navigation starts")
	camp.camp_navigation._physics_process(.016)
	await get_tree().process_frame
	while shell.busy:await get_tree().process_frame
	check(is_instance_valid(shell.training),"navigation arrival enters training")
	await shell._close_training()
	var enemy:=RoomEnemy.new();enemy.room=camp.level;enemy.configure(&"slime");enemy.setup(camp.player,camp.level,1,1,1);enemy.position=at;camp.enemies_root.add_child(enemy);enemy.set_physics_process(false);enemy.hp=1000000
	for i in 20:enemy.take_damage(1,false,at-Vector2(40,0),null,true)
	check(enemy.room_push.length()<=200.01,"multi-hit impulse capped")
	var push:=enemy.room_push;var travel:=0.0
	for i in 60:
		travel+=push.length()/60.0;push=push.move_toward(Vector2.ZERO,900.0/60.0)
	check(travel<25 and push==Vector2.ZERO,"bounded knockback settles quickly")
	enemy.queue_free();camp._leave_camp();shell.queue_free();await get_tree().process_frame
	AudioManager.shutdown();print("TOOLS_GAME_FIXES failures=",failures);get_tree().quit(1 if failures else 0)
