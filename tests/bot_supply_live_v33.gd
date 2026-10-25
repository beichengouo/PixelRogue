extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v33-bot-suspend/"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	await begin(&"ilyua")
	var next:String=main.graph.rooms[main.graph.current].doors[0]
	main.graph.rooms[next].kind="shop";main.graph.rooms[next].cleared=true;main.graph.rooms[next].rewarded=true
	await main._change_room(RoomGraph.cell(next)-RoomGraph.cell(main.graph.current));actor=main.player
	GameState.items.clear()
	for i in 8:GameState.items.append(ExpeditionData.resolve("forest_sample").duplicate(true))
	for i in 6:GameState.items.append(ExpeditionData.resolve("star_dust").duplicate(true))
	actor.global_position=main.level.nearest_clear(main.npc.global_position+Vector2(220,0),12)
	actor.hp=actor.max_hp*.35;var health:=actor.hp;var origin:=actor.global_position
	var bank:Dictionary=Outpost.data.inventory.duplicate(true);var ledger:Dictionary=GameState.material_ledger.duplicate(true)
	actor.set_physics_process(true);GameState.set_process(true)
	check(main.gm_pilot.activate_for_test(),"live pilot uses normal activation")
	var saw_service:=false;var made:=false
	for index in 1200:
		await get_tree().physics_frame
		saw_service=saw_service or main.shop_ui.is_open()
		made=int(GameState.material_ledger.get("crafted",{}).get("potion_health",0))>int(ledger.get("crafted",{}).get("potion_health",0))
		if made and actor.hp>health and not main.shop_ui.is_open():break
	main.gm_pilot.stop();actor.set_physics_process(false);GameState.set_process(false)
	check(saw_service and actor.global_position.distance_to(origin)>20,"production process loop walks to service")
	check(made and actor.hp>health,"production process crafts and drinks healing")
	check(not main.shop_ui.is_open() and not UIFlow.has_screen(),"production process exits service after bounded supply")
	check(GameState.material_ledger!=ledger and Outpost.data.inventory==bank,"live run spends real carried materials with warehouse preserved")
	await settle_actor();AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout
	print("BOT_SUPPLY_LIVE_V33 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
