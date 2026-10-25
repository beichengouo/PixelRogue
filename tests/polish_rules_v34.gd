extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v34-gameplay-polish/"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	await begin(&"ilyua");main.gm_pilot.set_process(false)
	await binding_checks();await retirement_checks();await unlock_checks();await gate_checks();await art_checks()
	await settle_actor();AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout
	print("POLISH_RULES_V34 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
func blocked_save()->String:
	var path:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp";DirAccess.make_dir_recursive_absolute(path);return path
func binding_checks()->void:
	GameState.items.clear();GameState.coins=5000
	var item:=ItemDB.by_id(&"bow_spring_wind").duplicate(true);item.rarity=2;item.bound=false
	check(GameState.add_item(item),"equippable sample acquired normally")
	var actual:Dictionary=GameState.items.back();check(GameState.equip(actual),"sample equipped normally")
	check(not GameState.items.has(actual) and GameState.is_equipped(actual),"worn instance is outside bag")
	var bag:InventoryUI=main.inventory_ui;bag._filter=&"gear";bag._selected=actual;bag.open();await frames(4)
	check(not bag._bind_button.disabled,"binding button enabled on equipped item")
	var coins:=GameState.coins;check(GameState.bind_inventory_equipment(actual),"worn equipment can bind")
	check(BoundEquipment.is_bound(GameState.equipped(ItemDB.slot_of(actual))) and GameState.coins==coins-500,"exact worn instance bound for one fee")
	check(not GameState.bind_inventory_equipment(actual) and GameState.coins==coins-500,"double binding charges once")
	actual.bound=false;coins=GameState.coins;var path:=blocked_save()
	check(not GameState.bind_inventory_equipment(actual),"binding rejects failed disk write")
	check(not BoundEquipment.is_bound(actual) and GameState.coins==coins and GameState.is_equipped(actual),"failed binding preserves worn item and gold")
	DirAccess.remove_absolute(path);bag._finish_close();await frames()
	check(not GameState.bind_inventory_equipment(item.duplicate(true)),"external stale dictionary cannot bind worn changed instance")
	var twin:=actual.duplicate(true);actual.erase("uid");twin.erase("uid");GameState.items.append(twin)
	check(GameState.bind_inventory_equipment(actual) and BoundEquipment.is_bound(actual) and not BoundEquipment.is_bound(twin),"UID-less identical bag twin cannot steal worn binding")
func retirement_checks()->void:
	var before:Dictionary=Outpost.data.duplicate(true)
	Outpost.data.inventory={"glow_mushroom_0":3,"glow_mushroom_7":1,"forest_sample":4};var money:=Outpost.gold()
	var path:=blocked_save();check(not RetiredMushrooms.redeem_bank(),"legacy redemption detects save failure")
	check(Outpost.data.inventory.has("glow_mushroom_7") and Outpost.gold()==money,"failed redemption rolls back original stock")
	DirAccess.remove_absolute(path);check(RetiredMushrooms.redeem_bank(),"legacy stock redeem commits")
	check(Outpost.gold()==money+3*12+512 and Outpost.data.inventory=={"forest_sample":4},"legacy stock converted once at documented exchange value")
	check(RetiredMushrooms.redeem_bank() and Outpost.gold()==money+548,"repeat load does not repeat redemption")
	check(RetiredMushrooms.value("glow_mushroom_2")*3==int(CampStock.price(ItemDB.by_id(&"potion_starlight")).gold),"legacy potion currency retains replacement purchasing value")
	Outpost.data=before
	var mushroom:=GlowMushroom.new();main.fx_root.add_child(mushroom);await frames()
	check(not is_instance_valid(mushroom) and not main._try_grow_mushroom(),"retired mushroom actor and growth are disabled")
	check(main.expedition._restore_room_node({"script":"res://src/actors/glow_mushroom.gd"})==null,"old room entity does not respawn")
	check(not RoomMinimap._record_has_pickup({"script":"res://src/actors/glow_mushroom.gd","fields":{"_grow":1}}),"old mushroom never leaves minimap pickup marker")
	for contract:Dictionary in ExpeditionData.CONTRACTS:
		for id in contract.needs:check(not RetiredMushrooms.is_legacy(str(id)),"no mushroom requirement "+str(contract.id))
	for entry:Dictionary in MaterialWorkshopCatalog.ALCHEMY:
		for needs:Dictionary in entry.variants:
			for id in needs:check(not RetiredMushrooms.is_legacy(str(id)),"alchemy has no mushroom cost")
	for item:Dictionary in ItemDB.all():
		for id in CampStock.price(item).materials:check(not RetiredMushrooms.is_legacy(str(id)),"camp trade has no mushroom currency")
	var snap:=GameState.snapshot();snap.expedition_items=[ExpeditionData.pack(ItemDB.mushroom_item(0))];snap.coins=17
	GameState.restore(snap);check(GameState.coins==29 and GameState.items.is_empty(),"legacy carried mushroom becomes carried gold")
	snap=GameState.snapshot();GameState.restore(snap);check(GameState.coins==29,"carried redemption survives reload without duplicate gold")
func unlock_checks()->void:
	var old_stats:Dictionary=SaveService.data.achievement_stats.duplicate(true);var old_ach:Dictionary=SaveService.data.achievements.duplicate(true);var contracts:Array=Outpost.data.contracts.duplicate()
	for character:StringName in [&"ilyua",&"xixifu",&"sylphiette"]:
		Characters.set_current(character);SaveService.data.achievements={};SaveService.data.achievement_stats={};Outpost.data.contracts=[];PassiveDefinitions._selected.clear()
		GameState.set_starting_skills();check(GameState.unlocked_skills.size()==4,"new character starts with first set "+str(character))
		var fresh:=GameState.snapshot();GameState.restore(fresh)
		check(GameState.unlocked_skills.size()==4,"new-run reload does not unlock second set "+str(character))
		var advanced:Array=CharacterUnlocks.SKILLS[str(character)]
		for skill in advanced:check(not CharacterUnlocks.skill_available(StringName(skill)),"second set initially locked "+str(skill))
		var draft:=CampPreparation.new();check(not draft.set_skill(StringName(advanced[0]),0),"camp mutation rejects locked skill")
		Outpost.data.contracts.append(CharacterUnlocks.COMMISSIONS[str(character)])
		check(CharacterUnlocks.skill_available(StringName(advanced[0])),"committed commission unlocks utility skill")
		GameState.difficulty=1;AchievementTracker._boss(&"king")
		check(CharacterUnlocks.skill_available(StringName(advanced[1])),"normal opening boss unlocks second advanced skill")
		AchievementTracker._boss(&"mage")
		check(CharacterUnlocks.skill_available(StringName(advanced[2])),"normal middle boss unlocks advanced third skill")
		check(not CharacterUnlocks.skill_available(StringName(advanced[3])),"normal difficulty does not unlock strongest ultimate")
		AchievementTracker._boss(&"tide");check(not CharacterUnlocks.skill_available(StringName(advanced[3])),"normal final boss insufficient")
		GameState.difficulty=2;AchievementTracker._boss(&"tide")
		check(CharacterUnlocks.skill_available(StringName(advanced[3])),"dangerous final boss unlocks alternate ultimate")
		for passive:Dictionary in PassiveDefinitions.for_character(character):check(CharacterUnlocks.passive_available(StringName(passive.id),character),"passive tied to character mastery "+str(passive.id))
		var other:StringName=&"xixifu" if character!=&"xixifu" else &"ilyua"
		check(not CharacterUnlocks.skill_available(StringName(CharacterUnlocks.SKILLS[str(other)][3]),other),"different character proof cannot unlock another hero")
		SaveService.data.achievements={};var old_run:=GameState.snapshot();old_run.character=str(character);old_run.learned_skills=[advanced[0],advanced[1],advanced[2]];old_run.ultimate_skill=advanced[3]
		GameState.restore(old_run);check(GameState.skill_loadout()==[StringName(advanced[0]),StringName(advanced[1]),StringName(advanced[2]),StringName(advanced[3])],"ongoing old run retains advanced loadout")
		check(not CharacterUnlocks.valid_loadout(GameState.skill_loadout()),"old automatic access does not bypass next-departure gate")
	SaveService.data.achievement_stats=old_stats;SaveService.data.achievements=old_ach;Outpost.data.contracts=contracts;Characters.set_current(&"ilyua");GameState.difficulty=1
func gate_checks()->void:
	var graph:RoomGraph=main.graph;graph.staged=true;graph.stage_index=1;graph.stage_terminal=graph.current;graph.stage_boss_cleared=true
	var record:Dictionary=graph.rooms[graph.current];record.cleared=true;record.rewarded=true
	main._story_queue.clear();main._story_context="";main._reward_offers.clear();main._reward_pending.clear()
	var extraction:RoomExtraction=main.expedition.extraction;extraction.completed.disconnect(main.expedition._complete)
	var signals:=[0];extraction.completed.connect(func()->void:signals[0]+=1)
	check(extraction.leave_stage_gate(),"cleared stage gate submits direct extraction")
	check(extraction.state==ExtractionDirector.SETTLING and signals[0]==1 and actor.extraction_pose==&"","stage exit skips prayer wait and receiving poses")
	check(not extraction.leave_stage_gate() and signals[0]==1,"double stage click has one completion ticket")
	extraction.cancel(false,false);graph.stage_boss_cleared=false
	check(not extraction.leave_stage_gate(),"uncleared stage cannot use direct exit")
func art_checks()->void:
	for id:StringName in BossRoster.DATA:
		for phase in (3 if id in [&"tide",&"nameless"] else 2):
			var frames_value:=BossStageArt.frames(id,phase+1);var info:=BossStageArt.info(id,phase+1)
			check(int(info.cell)==384 and frames_value.get_meta("cell")==384,"boss uses higher-resolution packed source "+str(id)+str(phase))
			var sprite:=AnimatedSprite2D.new();sprite.sprite_frames=frames_value;BossStageArt.align(sprite,id,Vector2(40,40))
			var foot:Vector2=frames_value.get_meta("foot");var center:Vector2=Vector2.ONE*float(info.cell)*.5
			check((sprite.position+(foot-center)*sprite.scale).distance_to(Vector2(0,20))<.01,"boss shared foot anchor preserved "+str(id)+str(phase));sprite.free()
