extends Node
class ProbeShell:
	extends "res://src/main/game_shell.gd"
	func _ready()->void:pass
	func _process(_dt:float)->void:pass
var checks:=0
var failures:=0
var _departures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",message)
func frames(count:=4)->void:
	for index in count:await get_tree().process_frame
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
	get_tree().create_timer(300,true,false,true).timeout.connect(func()->void:printerr("FAIL test timeout");get_tree().quit(2))
func fresh(hero:StringName)->void:
	Characters.set_current(hero);SaveService.data.run={};Outpost.data.active={};SaveService.data.control_setup_done=true;SaveService.data.input_guide_seen=true;SaveService.data.camp_tutorial={"enabled":false,"completed":true};SaveService.data.reduced_motion=true;SaveService.data.replay_seen_dialogue=false
	Outpost.data.gold=10000;Outpost.data.capacity=1000;Outpost.data.inventory={};Outpost.data.presets={};Outpost.data.locks={};StoryState.flags.chapter_2_unlocked=true
	for id in LegendarySets.DATA[hero].values():Outpost.data.inventory[str(id)]=2
	Outpost.data.inventory.potion_health=20;Outpost.data.inventory.potion_energy=20
	GameState.run_active=false
	# This compatibility fixture exercises unlocked loadout operations; gates are covered separately.
	Outpost.data.contracts=CharacterUnlocks.COMMISSIONS.values()
	for character in Characters.DATA:
		for tier in ["opening","middle","final"]:SaveService.data.achievements[CharacterUnlocks.achievement_id(str(character),tier)]=1
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/work/v34-gameplay-polish/"):get_tree().quit(2);return
	AchievementTracker.set_process(false);TransitionLayer.boot_played=true
	for hero:StringName in Characters.DATA:
		fresh(hero);await model_checks(hero)
	print("CAMP_MODEL_DONE checks=",checks," failures=",failures)
	fresh(&"sylphiette");await world_checks()
	AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout
	print("CAMP_DEPARTURE_SIMPLIFY checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
func model_checks(hero:StringName)->void:
	var draft:=CampPreparation.new();draft.restore_memory();var stock:Dictionary=Outpost.data.inventory.duplicate(true);var gold:=Outpost.gold()
	for slot:String in ["weapon","armor","accessory"]:check(draft.equip_key(str(LegendarySets.DATA[hero][slot])),"draft equips owned gear "+str(hero)+slot)
	check(draft.set_potion_count("potion_health",10),"select potions")
	check(draft.set_potion_count("potion_energy",5),"select combined 15")
	check(not draft.set_potion_count("potion_energy",6),"potion cap enforced")
	check(not draft.set_potion_count("potion_health",-1),"negative potion count rejected")
	check(Outpost.data.inventory==stock and Outpost.gold()==gold,"preparation changes never debit stock or gold")
	var order:=Skills.order_for(hero);var smalls:Array=[]
	for id:StringName in order:
		if not Skills.is_ultimate(id):smalls.append(id)
	check(draft.set_skill(smalls[-1],0),"draft skill selection")
	check(draft.set_skill(StringName(draft.skill_loadout[0]),1) and Skills.valid_loadout(draft.skill_loadout),"duplicate skill swaps stay valid")
	draft.set_destination(ChapterCatalog.NEXT);draft.set_difficulty(4);draft.carried=100;draft.initial_level=5
	check(draft.save_memory(),"automatic memory persisted")
	var restored:=CampPreparation.new();restored.restore_memory()
	check(restored.loadout.size()==3 and restored.potion_count()==0,"only equipment restored")
	check(restored.carried==0 and restored.initial_level==1,"paid options not automatically restored")
	check(restored.chapter_id==ChapterCatalog.NEXT and restored.difficulty==4 and restored.skill_loadout==draft.skill_loadout,"character destination difficulty and skills restored")
	var key:=restored.equipped_key(&"weapon");Outpost.data.inventory[key]=0
	var missing:=CampPreparation.new();missing.restore_memory();check(missing.equipped_key(&"weapon").is_empty() and not missing.memory_notice.is_empty(),"missing equipment is visibly left empty")
	Outpost.data.inventory[key]=2
	check(Outpost.save_preset(0,"旧方案",draft.loadout,100,draft.danger,draft.difficulty),"existing manual preset saves")
	restored.apply_preset(0);check(restored.potion_count()==15 and restored.carried==100,"explicit old preset still restores consumables and gold")
	var before_save:=SaveService.data.duplicate(true);var disk:=FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)
	var blocked:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp"
	check(DirAccess.make_dir_absolute(blocked)==OK,"isolated atomic save blocker")
	restored.difficulty=2;check(not restored.save_memory() and restored.memory_dirty,"memory save failure visible")
	check(SaveService.data==before_save and restored.difficulty==2,"saved memory rolls back while editable draft stays")
	check(FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)==disk,"disk unchanged on failure")
	check(DirAccess.remove_absolute(blocked)==OK,"blocker removed")
	check(restored.save_memory() and not restored.memory_dirty,"memory retry succeeds")
	var legacy:Dictionary=SaveService.data.camp_preparations.duplicate(true)
	SaveService.data.camp_preparations={str(hero):{"equipment":{},"skill_loadout":["invalid"],"chapter_id":"unknown","difficulty":99}}
	var invalid:=CampPreparation.new();invalid.restore_memory();check(Skills.valid_loadout(invalid.skill_loadout) and invalid.difficulty==1 and invalid.chapter_id==ChapterCatalog.FIRST,"invalid remembered values safely default")
	SaveService.data.camp_preparations=legacy
func world_checks()->void:
	SaveService.data.camp_preparations={}
	var camp:=CampWorld.new();add_child(camp)
	while not camp.initialization_complete:await frames(1)
	check(camp.initialization_success,"actual camp initializes")
	if not camp.initialization_success:return
	check(not is_instance_valid(camp.dummy) and not is_instance_valid(camp.training_ui),"camp has no dummy or training panel")
	check(camp.camp_ui.preparation==camp.preparation and camp.inventory_ui.camp_preparation==camp.preparation,"one shared draft")
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(8);camp.camp_ui.open_facility("prepare");await frames(8)
		var start:=camp.camp_ui._root.find_child("DepartNow",true,false) as Button
		check(start!=null and not start.disabled,"one-click departure available "+str(extent))
		check(camp.camp_ui._root.get_global_rect().grow(1).encloses(start.get_global_rect()),"fixed action stays inside viewport "+str(extent))
		check(camp.camp_ui._departure_footer.get_global_rect().grow(1).encloses(start.get_global_rect()),"action remains outside scroll "+str(extent))
		if extent.x>=1280:check(camp.camp_ui._scroll.get_v_scroll_bar().max_value<=camp.camp_ui._scroll.size.y+2,"default overview fits landscape "+str(extent))
		check(camp.camp_ui._body.find_child("DepartureLoadout",true,false)==null,"wizard loadout removed")
		check(camp.camp_ui._departure_view._destinations.columns==(1 if extent.y>extent.x else 2),"portrait destinations stack "+str(extent))
		camp.camp_ui.request_backpack(&"gear");await frames(6)
		check(UIFlow.is_top(camp.inventory_ui) and not camp.camp_ui.is_open(),"overview to existing bag "+str(extent))
		check(camp.inventory_ui._grid.get_child_count()>=3,"warehouse gear visible in camp bag")
		camp.inventory_ui.camp_content.selected_key=str(LegendarySets.DATA.sylphiette.weapon);camp.inventory_ui.camp_content.equip_selected();await frames()
		check(camp.preparation.equipped_key(&"weapon")==str(LegendarySets.DATA.sylphiette.weapon),"bag equip updates draft")
		camp.inventory_ui._finish_close();await frames(8);check(camp.camp_ui.is_open(),"bag returns to overview")
		camp.camp_ui.close();camp.inventory_ui.open_camp_page(&"potion");await frames(6)
		camp.inventory_ui.camp_content.selected_key="potion_health";camp.inventory_ui.camp_content.equip_selected();await frames()
		check(camp.preparation.potion_count()>0 and int(Outpost.data.inventory.potion_health)==20,"bag potion reservation without consumption")
		camp.inventory_ui._finish_close();await frames();check(not camp.camp_ui.is_open(),"direct bag closes to camp")
	get_window().size=Vector2i(1280,720)
	for item:Dictionary in ItemDB.all():
		if ItemDB.is_equippable(item) and ItemDB.available_in_mode(item,"rooms"):Outpost.data.inventory[str(item.id)]=1
	camp.inventory_ui.open_camp_page(&"gear");await frames(10)
	var stock_scroll:=camp.inventory_ui._shell.get_node("Panel/Content/Body/ItemsScroll") as ScrollContainer
	stock_scroll.scroll_vertical=120;await frames(5);var remembered_scroll:=stock_scroll.scroll_vertical
	camp.inventory_ui.camp_content._select(str(LegendarySets.DATA.sylphiette.weapon));await frames(8)
	check(remembered_scroll>0 and stock_scroll.scroll_vertical==remembered_scroll,"stock grid scroll survives item selection")
	camp.inventory_ui._gear_part=&"armor";camp.inventory_ui._rebuild();await frames(6)
	check(camp.inventory_ui._grid.get_child_count()>0,"camp part filter retains matching items")
	camp.inventory_ui._gear_part=&"";camp.inventory_ui._finish_close();await frames(6)
	var original:=camp.preparation.signature();var stock:Dictionary=Outpost.data.inventory.duplicate(true);var coins:=Outpost.gold()
	var shell:=ProbeShell.new();add_child(shell);camp.reparent(shell);shell.camp=camp
	await shell._open_training();await frames(8)
	check(is_instance_valid(shell.training) and shell.training.initialization_success,"independent training scene opens")
	check(camp.process_mode==Node.PROCESS_MODE_DISABLED and not camp.visible,"camp suspended while training")
	if is_instance_valid(shell.training):
		var training:=shell.training
		check(training.level.record.kind=="training" and is_instance_valid(training.dummy),"training has its own map and dummy")
		check(training.inventory_ui.camp_preparation==null,"training bag edits only sandbox")
		for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
			get_window().size=extent;await frames(8);training.training_ui.open();await frames(8)
			var frame:=training.training_ui._root.get_child(1) as Control
			check(get_viewport().get_visible_rect().grow(1).encloses(frame.get_global_rect()),"training settings frame stays in viewport "+str(extent))
			check(frame.get_child(0).get_global_rect().size.x<=frame.get_global_rect().size.x+1,"training settings content cannot widen frame "+str(extent))
			training.training_ui.close();await frames(4)
		get_window().size=Vector2i(1280,720)
		GameState.level=70;CampSession.clear_talents();var all:=Skills.order_for();GameState.equip_skill(all[1],0);CampSession.try_equipment(str(LegendarySets.DATA.sylphiette.armor))
		training.dummy.take_damage(30,false,training.player.position,training.player)
		check(training.dummy.meter.total>0,"dummy records actual damage")
		await shell._close_training();await frames(8)
	check(camp.visible and camp.process_mode==Node.PROCESS_MODE_PAUSABLE and CampSession.owner.get_ref()==camp,"returns to original camp")
	check(camp.preparation.signature()==original and GameState.level==1,"training changes do not leak into formal preparation")
	check(Outpost.data.inventory==stock and Outpost.gold()==coins and Outpost.active_id().is_empty(),"training does not consume stock or create sortie")
	check(GameState.skill_loadout()==camp.preparation.skill_loadout,"formal skills restored")
	await shell._open_training();await frames(6);await shell._close_training();await frames(6)
	check(camp.preparation.signature()==original and CampSession.owner.get_ref()==camp,"repeated training entry preserves original draft")
	check(not is_instance_valid(shell.training) and not UIFlow.has_screen(),"training return releases map and modal input")
	camp.camp_ui.departure_blocker=func()->String:return "引导进行中"
	camp.camp_ui.open_facility("prepare");await frames(6);camp.camp_ui._depart()
	check(Outpost.active_id().is_empty() and camp.camp_ui.is_open(),"tutorial blocks premature departure")
	camp.camp_ui.departure_blocker=camp._departure_blocker
	# Actual UI submission, actual atomic rollback, and repeat rejection.
	camp.preparation.set_difficulty(1);camp.preparation.carried=15;camp.preparation.initial_level=2;camp.camp_ui.open_facility("prepare");await frames(8)
	var blocked:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp";check(DirAccess.make_dir_absolute(blocked)==OK,"departure blocker created")
	var outpost_before:=Outpost.data.duplicate(true)
	camp.camp_ui._depart();await frames(6)
	check(Outpost.data==outpost_before and Outpost.active_id().is_empty() and camp.camp_ui.is_open(),"failed direct departure rolls back and stays in overview")
	check(not camp._departing,"failed submit can retry")
	check(DirAccess.remove_absolute(blocked)==OK,"departure blocker removed")
	camp.departure_requested.connect(func(_data:Dictionary)->void:_departures+=1)
	camp.camp_ui._depart();camp.camp_ui._depart();await frames(8)
	check(_departures==1 and not Outpost.active_id().is_empty(),"one click submits directly without gate and repeat ignored")
	check(Outpost.gold()==coins-15-DepartureLevels.cost(2),"carried gold and tuition debited exactly once")
	check(SaveService.run_info().get("departure",{}).get("skill_loadout",[])==camp.preparation.skill_loadout,"saved departure uses shared skills")
	check(int(Outpost.data.inventory.potion_health)==20-camp.preparation.potion_count("potion_health"),"reserved potions withdrawn exactly once")
	shell.queue_free();await frames(8);Outpost.data.active={};SaveService.data.run={};GameState.run_active=false
