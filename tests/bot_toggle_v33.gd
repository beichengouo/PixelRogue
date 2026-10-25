extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v33-bot-suspend/"
func press(down:=true,echo:=false,ctrl:=false,key:int=KEY_B)->void:
	var event:=InputEventKey.new();event.physical_keycode=key;event.pressed=down;event.echo=echo;event.ctrl_pressed=ctrl
	get_viewport().push_input(event,true);await frames(2)
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	check(BotTestControl.available_in_build(true,[]),"debug builds enable shortcut")
	check(not BotTestControl.available_in_build(false,[]),"release default retains original GM access")
	check(BotTestControl.available_in_build(false,["--bot-test"]),"release opt-in flag enables shortcut")
	await begin(&"ilyua")
	var control:=main.get_node("BotTestControl") as BotTestControl
	check(control!=null,"production adventure installs local controller")
	await press(true,false,false,KEY_F9);check(not GameState.gm_pilot_active,"native editor F9 is not a game Bot shortcut")
	var before:={"items":GameState.items.duplicate(true),"equipment":GameState.equipment.duplicate(true),"level":GameState.level,"coins":GameState.coins,"stats":{}}
	for key in [&"max_hp",&"attack",&"mp_regen",&"move_speed"]:before.stats[str(key)]=actor.stats.get_value(key)
	await press();check(GameState.gm_pilot_active and GameState.gm_pilot_used,"physical B starts existing Bot")
	await press(true,true);check(GameState.gm_pilot_active,"OS key repeat does not stop Bot")
	await press(false);check(GameState.gm_pilot_active,"key release does not toggle")
	await press(true,false,true);check(GameState.gm_pilot_active,"modified key is ignored")
	actor.movement_override=Vector2.RIGHT;actor.aim_override=Vector2.UP
	await press();check(not GameState.gm_pilot_active and actor.movement_override==Vector2.ZERO and actor.aim_override==Vector2.ZERO,"B stops and returns both input axes")
	check(GameState.gm_pilot_used and not main.gm_pilot.activate(),"original once-per-run GM access is not reset")
	await press();check(GameState.gm_pilot_active,"same-run test restart allowed")
	for extent in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(4)
		check(get_viewport().get_visible_rect().encloses(main.gm_pilot._banner.get_global_rect()),"stop banner stays inside viewport "+str(extent))
	var screen:=Control.new();add_child(screen);UIFlow.push_screen(screen);await frames(2)
	await press();check(not GameState.gm_pilot_active and get_tree().paused and UIFlow.is_top(screen),"can stop under a pause lease without closing screen")
	await press();check(not GameState.gm_pilot_active and get_tree().paused,"cannot start through a blocking screen")
	UIFlow.pop_screen(screen);screen.queue_free();await frames(2)
	for field in ["_navigation_pending","_room_transfer"]:
		main.set(field,true);check(not control.toggle().is_empty() and not GameState.gm_pilot_active,"start blocked during "+field);main.set(field,false)
	TransitionLayer.busy=true;check(not control.toggle().is_empty(),"transition blocks start");TransitionLayer.busy=false
	CampSession.active=true;check(not control.toggle().is_empty(),"camp and training cannot start combat Bot");CampSession.active=false
	GameState.run_active=false;check(not control.toggle().is_empty(),"inactive adventure cannot start");GameState.run_active=true
	var old_hp:=actor.hp;actor.hp=0;check(not control.toggle().is_empty(),"dead player cannot restart");actor.hp=old_hp
	actor.extraction_pose=&"receiving"
	check(not control.toggle().is_empty(),"extraction controls block start")
	actor.extraction_pose=&""
	check(GameState.items==before.items and GameState.equipment==before.equipment and GameState.level==before.level and GameState.coins==before.coins,"toggles grant no equipment, level or currency")
	for key:String in before.stats:check(is_equal_approx(actor.stats.get_value(StringName(key)),float(before.stats[key])),"toggles add no attributes "+key)
	# One live room uses real room transition, AI and physics. It is an input
	# smoke check, not a campaign balance or framerate result.
	get_window().size=Vector2i(1280,720)
	var next:String=main.graph.rooms[main.graph.current].doors[0]
	await main._change_room(RoomGraph.cell(next)-RoomGraph.cell(main.graph.current))
	actor=main.player;main.set_process(true);main.director.set_process(true);main.special_rooms.set_process(true);main.expansion.set_process(true);main.expedition.set_process(true)
	GameState.set_process(true);actor.set_physics_process(true);actor.caster.set_physics_process(true);actor.equipment_mechanics.set_process(true)
	if is_instance_valid(actor.holy_runtime):actor.holy_runtime.set_process(true)
	if is_instance_valid(actor.ilyua_runtime):actor.ilyua_runtime.set_process(true)
	await press();var aimed:=false;var moved:=false;var origin:=actor.global_position
	for i in 360:
		await get_tree().physics_frame
		aimed=aimed or not actor.aim_override.is_zero_approx();moved=moved or actor.global_position.distance_to(origin)>4
	check(aimed and moved,"one-key Bot targets enemies and moves under full physics")
	if GameState.gm_pilot_active:main.gm_pilot.stop()
	main.set_process(false);main.director.set_process(false);actor.set_physics_process(false);GameState.set_process(false)
	await settle_actor();AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout
	print("BOT_TOGGLE_V32 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
