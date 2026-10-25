extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v33-bot-suspend/"
func add_item(id:String,count:=1)->void:
	for index in count:GameState.items.append(ExpeditionData.resolve(id).duplicate(true))
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	await begin(&"ilyua");var pilot:GMPilot=main.gm_pilot;pilot.set_process(false)
	var bank:Dictionary=Outpost.data.duplicate(true)
	GameState.items.clear();Outpost.data.inventory={};Outpost.data.workshop={"goal":"alch_focus","unlocked":{}}
	add_item("forest_sample",3);add_item("star_dust",6)
	check(pilot.supplies.recipe().is_empty(),"all carried goal materials reserved from automatic supply")
	add_item("forest_sample",2);add_item("star_dust");pilot.supplies._cached_at=0
	check(pilot.supplies.recipe().get("id","")=="alch_health","only surplus goal materials eligible")
	Outpost.data=bank;GameState.items.clear()
	for id in 24:
		var potion:=ExpeditionData.resolve("potion_focus").duplicate(true);potion.id="test_full_"+str(id)
		for index in 5:GameState.items.append(potion.duplicate(true))
	add_item("forest_sample",4);add_item("star_dust",4);pilot.supplies._cached_at=0
	check(pilot.supplies.recipe().is_empty(),"full potion category never attracts uncraftable supply detour")
	GameState.items.clear();GameState.fate=FateCatalog.empty();var room:Dictionary=main.graph.rooms[main.graph.current]
	room.kind="altar";room.cleared=true;room.rewarded=true;room.delta={}
	for character in [&"ilyua",&"xixifu",&"sylphiette"]:
		Characters.set_current(character)
		for reverse in [false,true]:
			GameState.fate=FateCatalog.empty();pilot.supplies.reset()
			room.delta={"fate_reading":{"offers":[FateCatalog.owned_card(),"chariot","fool"],"reverse":reverse,"done":false}}
			main.fate_ui.open_altar(room);await get_tree().create_timer(.8,true,false,true).timeout
			pilot._advance_screen();var choice:FateChoiceUI=main.fate_ui._choice
			check(choice.pending_index==0,"three heroes choose compatible resonance "+str(character)+" reverse="+str(reverse))
			pilot._advance_screen();await get_tree().create_timer(.8,true,false,true).timeout
			check(GameState.fate.cards.size()==1 and str(GameState.fate.cards[0].id)==FateCatalog.owned_card() and bool(GameState.fate.cards[0].reverse)==reverse,"three heroes commit exact offered orientation "+str(character)+" reverse="+str(reverse))
	Characters.set_current(&"ilyua");GameState.items.clear();add_item("forest_sample",2);add_item("star_dust")
	room.kind="normal";var error:=MaterialWorkshop.craft("alch_health",0,false,true,main.shop_ui)
	check(not error.is_empty() and GameState.items.size()==3,"craft rejected in battle room with closed service")
	await settle_actor();AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout
	print("BOT_SUPPLY_POLICY_V33 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
