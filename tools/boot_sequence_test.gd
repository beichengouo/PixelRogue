extends Node
const OUT:="E:/CodexWorkspace/PixelRogue/temp/boot-sequence"
var checks:=0
var failures:=0
var menu_starts:=0
var pending_result:Variant=null
var shell
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("BOOT_SEQUENCE "+label)
func _ready()->void:process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
func wait_real(seconds:float)->void:
	var start:=Time.get_ticks_usec()
	while (Time.get_ticks_usec()-start)/1000000.0<seconds:await get_tree().process_frame
func capture(label:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+"/"+label+".png")
func boot(owner:Node)->void:
	pending_result=await TransitionLayer.play_boot_sequence("正在准备旅途…",owner)
func input_key(key:Key)->void:
	var event:=InputEventKey.new();event.keycode=key;event.pressed=true;get_tree().root.push_input(event)
	event=InputEventKey.new();event.keycode=key;get_tree().root.push_input(event)
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	check(ProjectSettings.globalize_path("user://").contains("PixelRogue_UI_Review"),"independent userdata")
	SaveService.data.reduced_motion=false;Outpost.set_process(false)
	check(TransitionLayer.has_method("play_boot_sequence"),"boot API exists")
	if not TransitionLayer.has_method("play_boot_sequence"):get_tree().quit(1);return
	TransitionLayer.boot_played=false
	var start:=Time.get_ticks_usec()
	shell=load("res://src/main/game_shell.tscn").instantiate();add_child(shell)
	check(TransitionLayer.busy and TransitionLayer.boot_played and shell._booting,"first shell claims cold boot immediately")
	check(shell.menu.is_open() and shell.game==null,"menu prepared under cold cover without game instantiation")
	check(TransitionLayer._boot_order.size()==3 and TransitionLayer._boot_order[0]!=TransitionLayer._boot_order[1] and TransitionLayer._boot_order[1]!=TransitionLayer._boot_order[2] and TransitionLayer._boot_order[0]!=TransitionLayer._boot_order[2],"three random distinct characters")
	check(UIFlow.is_top(TransitionLayer) and get_tree().paused and not TransitionLayer._progress_bar.visible,"boot owns input and uses truthful stage without fake progress")
	shell.menu.start_requested.connect(func():menu_starts+=1)
	input_key(KEY_ENTER);input_key(KEY_ESCAPE)
	await wait_real(.4);await capture("cold-first")
	check(menu_starts==0 and shell.menu.is_open() and TransitionLayer.busy,"confirm and escape do not penetrate cold cover")
	await wait_real(1.0);await capture("cold-second")
	check(TransitionLayer._boot_index==1,"second character follows first")
	await wait_real(1.0);await capture("cold-third")
	check(TransitionLayer._boot_index==2,"third character follows second")
	while TransitionLayer.busy:await get_tree().process_frame
	await get_tree().process_frame
	var elapsed:float=(Time.get_ticks_usec()-start)/1000000.0
	check(elapsed>=2.95 and elapsed<5.0,"first opening lasts about three seconds %.3f"%elapsed)
	check(not shell._booting and UIFlow.is_top(shell.menu) and shell.menu.is_open(),"boot finishes into already prepared menu")
	await capture("menu-ready")
	shell.queue_free();await get_tree().process_frame;await get_tree().process_frame
	shell=load("res://src/main/game_shell.tscn").instantiate();add_child(shell)
	check(not TransitionLayer.busy and not shell._booting and shell.menu.is_open(),"returning shell does not repeat boot")
	# Actual departure stays on the existing loading/cover path.
	Outpost.data={"version":4,"gold":1000,"danger":3,"inventory":{},"capacity":30,"expansions":0,"contracts":[],"bonds":{"sylphiette":0,"iris":0},"events":{"camp:intro":true},"best":{},"active":{},"last_result":{},"shop":{}}
	shell.begin({"departure":{"loadout":[],"carried":20,"danger":0,"combat_mode":"rooms"}})
	check(not TransitionLayer._boot_active and not shell._booting,"asynchronous departure does not replay cold boot")
	start=Time.get_ticks_usec()
	while shell.busy and (Time.get_ticks_usec()-start)/1000000.0<20:await get_tree().process_frame
	check(is_instance_valid(shell.game) and not shell.busy,"actual room departure completes existing threaded load")
	GameState.run_active=false;shell.queue_free();await get_tree().process_frame;await get_tree().process_frame
	# A departure can load in parallel with the intro, but cancel invalidates both paths.
	TransitionLayer.boot_played=false
	shell=load("res://src/main/game_shell.tscn").instantiate();add_child(shell)
	shell.begin({"departure":{"loadout":[],"carried":20,"danger":0,"combat_mode":"rooms"}})
	check(shell._request_ok and shell._booting and TransitionLayer._boot_active and shell.game==null,"departure starts real resource request while cold animation runs")
	shell.cancel_loading();await wait_real(.3)
	check(not shell.busy and shell.game==null and shell.menu.is_open() and not TransitionLayer.busy,"cancelled boot departure cannot continue into old page")
	shell.queue_free();await get_tree().process_frame;await get_tree().process_frame
	TransitionLayer.boot_played=false
	shell=load("res://src/main/game_shell.tscn").instantiate();add_child(shell)
	shell.begin({"departure":{"loadout":[],"carried":20,"danger":0,"combat_mode":"rooms"}})
	shell.queue_free();await wait_real(.3)
	check(not TransitionLayer.busy and not UIFlow.has_screen(),"shell freed during cold departure releases request and input")
	TransitionLayer.boot_played=false
	get_tree().root.set_meta("pending_departure",{"departure":{"loadout":[],"carried":20,"danger":0,"combat_mode":"rooms"}})
	shell=load("res://src/main/game_shell.tscn").instantiate();add_child(shell)
	check(TransitionLayer.boot_played and not shell._booting and not TransitionLayer._boot_active,"mode handoff marks boot consumed and cannot replay on later menu return")
	shell.cancel_loading();shell.queue_free();await get_tree().process_frame;await get_tree().process_frame
	# Cancel and owner deletion release the lease without continuing the old sequence.
	var owner:=Node.new();add_child(owner)
	TransitionLayer.boot_played=false;pending_result=null;boot(owner)
	await wait_real(.25);var index:int=TransitionLayer._boot_index;TransitionLayer.cancel()
	await wait_real(1.0)
	check(pending_result==false and not TransitionLayer.busy and TransitionLayer._boot_index==index,"cancel aborts waiter and cannot advance old pages")
	check(not UIFlow.has_screen() and not get_tree().paused,"cancel releases only its input lease")
	TransitionLayer.boot_played=false;pending_result=null;boot(owner);await wait_real(.2);owner.queue_free();await wait_real(.2)
	check(pending_result==false and not TransitionLayer.busy and not UIFlow.has_screen(),"owner free cancels boot and stale callback")
	# Reduced motion still occupies three seconds with no travel between samples.
	owner=Node.new();add_child(owner);SaveService.data.reduced_motion=true
	TransitionLayer.boot_played=false;pending_result=null;start=Time.get_ticks_usec();boot(owner)
	await wait_real(.3);var position:Vector2=TransitionLayer._ink.goddess.position
	await wait_real(.3);await capture("reduced-first")
	check(TransitionLayer._ink.reduced and TransitionLayer._ink.goddess.position==position,"reduced mode gently fades without displacement")
	while TransitionLayer.busy:await get_tree().process_frame
	check(pending_result==true and (Time.get_ticks_usec()-start)/1000000.0>=2.95,"reduced boot retains three-second duration")
	SaveService.data.reduced_motion=false
	check(await TransitionLayer.cover("希希芙 · 新的旅途","xixifu",owner),"existing cover API supports dedicated Xixifu silhouette")
	TransitionLayer._ink.manual_clock=true;TransitionLayer._ink.age=.52;TransitionLayer._ink.set_progress(1)
	await capture("xixifu-silhouette")
	check(TransitionLayer._ink.goddess.texture.resource_path.ends_with("xixifu_profile_v1.png"),"Xixifu uses generated silhouette asset")
	TransitionLayer._ink.manual_clock=false;TransitionLayer._ink.age=1.2
	await TransitionLayer.uncover()
	check(not TransitionLayer.busy and not UIFlow.has_screen(),"cover/uncover remains reusable after boot")
	owner.queue_free();await get_tree().process_frame
	AudioManager.shutdown();await wait_real(.25)
	print("BOOT_SEQUENCE checks=%d failures=%d"%[checks,failures]);get_tree().quit(1 if failures else 0)
