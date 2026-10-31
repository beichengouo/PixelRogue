extends "res://tests/refinement_runtime_v08.gd"

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	AchievementTracker.set_process(false)
	await begin(&"sylphiette")
	var pilot:GMPilot=main.gm_pilot
	var supplies=pilot.supplies
	var original_items:=GameState.items.duplicate(true)
	var original_rooms:=main.graph.rooms.duplicate(true)
	var original_current:=main.graph.current
	var original_special:=main.special_rooms.state.duplicate(true)
	var original_active:=GameState.gm_pilot_active
	actor.bloodbath_hp_loss=0;actor.cruel_hp_loss=0
	check(supplies.capacity_doses_missing()==0,"no scar needs no capacity potion")
	var full:=actor.stats.get_value(&"max_hp")
	actor.cruel_hp_loss=full*.55
	check(supplies.capacity_doses_missing()==3,"55 percent scar requires three 25 percent doses")
	GameState.items.clear()
	for index in 3:GameState.items.append(ExpeditionData.resolve("river_pearl"))
	for index in 6:GameState.items.append(ExpeditionData.resolve("forest_resin"))
	for index in 12:GameState.items.append(ExpeditionData.resolve("star_dust"))
	supplies._cached_at=0
	check(str(supplies.recipe().get("id",""))=="alch_capacity","repair recipe takes priority while doses are missing")
	GameState.items.append(ExpeditionData.resolve("potion_capacity"))
	check(supplies.capacity_doses_missing()==2,"owned capacity potion reduces crafting target")
	supplies._cached_at=0
	check(str(supplies.recipe().get("id",""))=="alch_capacity","one dose does not prematurely stop capacity crafting")
	var center:={"kind":"spawn","doors":["1,0","0,1"],"visited":true,"cleared":true,"seed":"1"}
	var elite:={"kind":"elite","doors":["0,0"],"visited":false,"cleared":false,"seed":"2"}
	var game:={"kind":"game","doors":["0,0"],"visited":false,"cleared":true,"seed":"3"}
	main.graph.rooms={"0,0":center,"1,0":elite,"0,1":game};main.graph.current="0,0"
	check(pilot._frontier_exits()[0]=="0,1","scar without enough repair diverts around elite")
	GameState.items.append(ExpeditionData.resolve("potion_capacity"))
	GameState.items.append(ExpeditionData.resolve("potion_capacity"))
	check(supplies.capacity_doses_missing()==0 and pilot._frontier_exits()[0]=="1,0","enough repair restores elite priority")
	GameState.items.clear();main.graph.rooms.erase("0,1");main.graph.rooms["0,0"].doors=["1,0"]
	check(pilot._frontier_exits()==["1,0"],"elite remains last resort when no bypass exists")
	main.graph.rooms["0,0"].kind="game"
	main.graph.rooms["0,0"].terrain_layout={"scene_art":"normal_windbridge_v01"}
	main.special_rooms.state={"chase":{"prepare":5.0,"remaining":30.0,"done":false}}
	check(pilot._shadow_challenge_pending(),"shadow preparation is already noncombat")
	main.special_rooms.state.chase.prepare=0.0
	check(pilot._shadow_challenge_pending(),"shadow pursuit stays noncombat")
	GameState.gm_pilot_active=true;actor.aim_override=Vector2.RIGHT;actor.firing=true
	pilot._elapsed=.1;pilot._process(.1)
	check(actor.aim_override==Vector2.ZERO and not actor.firing,"shadow policy suppresses Bot attacks")
	main.special_rooms.state.chase.done=true
	check(not pilot._shadow_challenge_pending(),"completed shadow room releases policy")
	GameState.gm_pilot_active=original_active;GameState.items=original_items;main.graph.rooms=original_rooms;main.graph.current=original_current;main.special_rooms.state=original_special
	actor.bloodbath_hp_loss=0;actor.cruel_hp_loss=0
	await settle_actor();AudioManager.shutdown();await get_tree().process_frame
	print("BOT_ROOM_POLICY_V40 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
