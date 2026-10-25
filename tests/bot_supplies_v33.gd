extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v33-bot-suspend/"
var pilot:GMPilot
func add_item(id:String,count:=1)->void:
	for index in count:GameState.items.append(ExpeditionData.resolve(id).duplicate(true))
func count_item(id:String)->int:
	var result:=0
	for item in GameState.items:
		if str(item.get("id",""))==id:result+=1
	return result
func clear_intent()->void:pilot.supplies._cached_at=0
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	await begin(&"ilyua");pilot=main.gm_pilot;pilot.set_process(false)
	check(pilot.activate_for_test(),"existing Bot activation used");GameState.gm_pilot_active=false
	GameState.items.clear();GameState.temp_buffs.clear()
	add_item("potion_focus",2);pilot.supplies.use_buff()
	check(count_item("potion_focus")==1 and not GameState.temp_buffs.is_empty(),"owned buff consumed through real use_item")
	pilot.supplies._buff_at=0;pilot.supplies.use_buff()
	check(count_item("potion_focus")==1,"active buff is not consumed again")
	GameState.temp_buffs[0].remaining=0;pilot.supplies._buff_at=0;pilot.supplies.use_buff()
	check(count_item("potion_focus")==0,"expired buff may be renewed")
	add_item("potion_focus");GameState.temp_buffs.clear();GameState.add_temp_buff(&"attack_speed",.9,30,"test stronger")
	pilot.supplies._buff_at=0;pilot.supplies.use_buff()
	check(count_item("potion_focus")==1,"stronger existing same-stat buff is preserved")
	GameState.items.clear();GameState.temp_buffs.clear();add_item("forest_sample",12);add_item("star_dust",12)
	check(pilot.supplies.recipe().get("id","")=="alch_health","needed default potion selected from carried materials")
	GameState.difficulty=4;clear_intent()
	check(pilot.supplies.recipe().get("id","")=="alch_energy","bloodbath never crafts ordinary healing")
	add_item("potion_health");var old_hp:=actor.hp;actor.hp=actor.max_hp*.3;pilot._use_potion("heal")
	check(count_item("potion_health")==1 and is_equal_approx(actor.hp,actor.max_hp*.3),"bloodbath does not waste ordinary healing")
	actor.hp=old_hp;GameState.difficulty=1
	GameState.items.clear();add_item("potion_capacity");pilot._use_capacity_potion(actor)
	check(count_item("potion_capacity")==1,"no capacity potion wasted without scars")
	actor.cruel_hp_loss=actor.stats.get_value(&"max_hp")*.2;pilot._use_capacity_potion(actor)
	check(count_item("potion_capacity")==0 and actor.permanent_hp_loss()<actor.stats.get_value(&"max_hp")*.2,"capacity potion actually repairs existing scars")
	actor.cruel_hp_loss=0;GameState._reset_stats()
	GameState.items.clear();clear_intent();check(pilot.supplies.recipe().is_empty(),"no free potions without material")
	var bank:=Outpost.data.duplicate(true)
	Outpost.data.inventory={"forest_sample":50,"star_dust":50};clear_intent()
	check(pilot.supplies.recipe().is_empty(),"warehouse materials are never used for field supply")
	Outpost.data=bank
	GameState.items.clear();add_item("storm_crystal",4);add_item("star_dust",12);clear_intent()
	check(pilot.supplies.recipe().is_empty(),"locked advanced recipe is not researched automatically")
	Outpost.data.workshop={"unlocked":{"alch_arcane":true},"goal":""};clear_intent()
	check(pilot.supplies.recipe().get("id","")=="alch_arcane","unlocked buff recipe becomes available")
	Outpost.data.workshop={"unlocked":{},"goal":""};GameState.items.clear()
	await service_checks("shop")
	await service_checks("tavern")
	await altar_checks()
	pilot.stop();await settle_actor();AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout
	print("BOT_SUPPLIES_V33 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)

func enter(kind:String)->void:
	var next:String=main.graph.rooms[main.graph.current].doors[0]
	main.graph.rooms[next].kind=kind;main.graph.rooms[next].cleared=true;main.graph.rooms[next].rewarded=true
	await main._change_room(RoomGraph.cell(next)-RoomGraph.cell(main.graph.current));actor=main.player
	main.director.set_process(false);main.special_rooms.set_process(false);main.expansion.set_process(false)
	actor.set_physics_process(false);actor.caster.set_physics_process(false);actor.equipment_mechanics.set_process(false)
	pilot.supplies.reset();await frames(3)

func service_checks(kind:String)->void:
	GameState.items.clear();add_item("forest_sample",10);add_item("star_dust",10)
	await enter(kind)
	var service:Node=main.shop_ui if kind=="shop" else main.tavern_ui
	var npc:Node2D=main.npc if kind=="shop" else main.tavern
	check(is_instance_valid(npc),kind+" real service spawned")
	if not is_instance_valid(npc):return
	var bank:Dictionary=Outpost.data.inventory.duplicate(true)
	actor.global_position=main.level.nearest_clear(npc.global_position+Vector2(200,0),12)
	var origin:=actor.global_position;actor.set_physics_process(true)
	var walked:=false
	for index in 600:
		pilot.supplies.visit(1.0/60)
		await get_tree().physics_frame
		walked=walked or actor.global_position.distance_to(origin)>10
		if service.is_open():break
	actor.set_physics_process(false);actor.movement_override=Vector2.ZERO
	check(walked and service.is_open(),kind+" reached by physics walking and NPC interaction")
	if not service.is_open():return
	check(MaterialWorkshop.field_error(service).is_empty(),kind+" normal safe workshop context")
	pilot._advance_screen()
	check(count_item("potion_health")==1 and count_item("forest_sample")==8 and count_item("star_dust")==9,kind+" real recipe spends exact carried cost")
	pilot._advance_screen();pilot._advance_screen();pilot._advance_screen();pilot._advance_screen()
	check(count_item("potion_health")==2 and count_item("potion_energy")==2,kind+" bounded two-heal two-mana stock")
	check(not service.is_open() and not UIFlow.has_screen(),kind+" closes service and resumes after supply")
	check(Outpost.data.inventory==bank,kind+" no permanent inventory change")
	# The route policy must also revisit already-cleared optional branches.
	GameState.items.clear();add_item("forest_sample",2);add_item("star_dust");pilot.supplies.reset()
	var graph:=main.graph;var rooms:Dictionary=graph.rooms.duplicate(true);var current:=graph.current
	graph.current="0,0";graph.rooms={"0,0":{"kind":"normal","visited":true,"cleared":true,"doors":["1,0","0,1"],"seed":1},"1,0":{"kind":kind,"visited":true,"cleared":true,"doors":["0,0"],"seed":2},"0,1":{"kind":"boss","visited":false,"cleared":false,"doors":["0,0"],"seed":3}}
	actor.hp=actor.max_hp*.5;var routes:=pilot._frontier_exits()
	check(not routes.is_empty() and routes[0]=="1,0",kind+" low health routes to visited supply before boss")
	graph.rooms=rooms;graph.current=current;actor.hp=actor.max_hp;pilot.supplies.reset()
	GameState.items.clear();add_item("forest_sample",2);add_item("star_dust");pilot.supplies.reset()
	service.open([]);var before:=GameState.items.duplicate(true);var sequence:=GameState.item_sequence
	var pending:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp"
	DirAccess.make_dir_recursive_absolute(pending)
	pilot._advance_screen()
	check(GameState.items==before and GameState.item_sequence==sequence,kind+" failed save rolls materials and UID back")
	check(not service.is_open() and not pilot.supplies.ready(main.graph.current),kind+" failed save closes with bounded retry cooldown")
	DirAccess.remove_absolute(pending)

func altar_checks()->void:
	GameState.items.clear();GameState.fate=FateCatalog.empty()
	await enter("altar")
	var room:Dictionary=main.graph.rooms[main.graph.current]
	room.delta.erase("fate_reading");room.delta.erase("fate_guard");main.fate_altar.sync_room()
	check(pilot.supplies.wants_altar(room),"unused altar requested")
	check(pilot.supplies.priority(main.graph.current)>130,"available altar takes priority over boss route")
	var altar:FateAltar=main.fate_altar
	actor.global_position=main.level.nearest_clear(altar.global_position+Vector2(180,0),12)
	var origin:=actor.global_position;var walked:=false;actor.set_physics_process(true)
	for index in 600:
		pilot.supplies.visit(1.0/60);await get_tree().physics_frame
		walked=walked or actor.global_position.distance_to(origin)>10
		if main.fate_ui.is_open():break
	actor.set_physics_process(false);actor.movement_override=Vector2.ZERO
	check(walked and main.fate_ui.is_open(),"altar reached physically before real reading opens")
	if not main.fate_ui.is_open():return
	var choice:FateChoiceUI=main.fate_ui._choice
	await get_tree().create_timer(.8,true,false,true).timeout
	pilot._advance_screen();check(UIFlow.is_top(choice.confirmation),"Bot previews actual offered fate card")
	var picked:Dictionary=choice.offers[choice.pending_index].duplicate(true)
	pilot._advance_screen();await get_tree().create_timer(.8,true,false,true).timeout
	check(GameState.fate.cards.size()==1 and str(GameState.fate.cards[0].id)==str(picked.fate_id),"confirmed card committed through fate transaction")
	check(bool(GameState.fate.cards[0].reverse)==FateService.orientation(room),"orientation remains room seed result")
	check(int(GameState.fate.readings)==1 and not pilot.supplies.wants_altar(room),"completed altar not requested repeatedly")
	check(not pilot.supplies.visit(.1) and int(GameState.fate.readings)==1,"revisit does not reroll or spend reading")
	room.delta.fate_reading={"offers":["emperor","moon","star"],"reverse":FateService.orientation(room),"done":false}
	main.fate_altar.sync_room();GameState.fate.readings=3
	check(pilot.supplies.wants_altar(room),"existing unclaimed reading may finish at limit")
	main.fate_ui.open_altar(room);await get_tree().create_timer(.8,true,false,true).timeout
	pilot._advance_screen();var before:=GameState.fate.duplicate(true)
	FateService.save_override=func()->bool:return false
	pilot._advance_screen();FateService.save_override=Callable();await frames(4)
	check(GameState.fate==before and not bool(room.delta.fate_reading.done),"failed fate save cannot grant card or complete reading")
	check(not main.fate_ui.is_open() and not pilot.supplies.ready(main.graph.current),"failed fate confirmation cancels with cooldown")
	room.delta.erase("fate_reading");check(not pilot.supplies.wants_altar(room),"new altar skipped after three readings")
	GameState.fate.readings=0;room.delta.fate_guard={"dead":true}
	check(not pilot.supplies.wants_altar(room),"destroyed altar skipped")
