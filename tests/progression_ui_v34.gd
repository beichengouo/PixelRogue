extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v34-gameplay-polish/"
func labels(parent:Node)->String:
	var text:=""
	for label in parent.find_children("*","Label",true,false):text+=label.text+"\n"
	return text
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);Outpost.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	SaveService.data.run={};SaveService.data.achievements={};SaveService.data.achievement_stats={};SaveService.data.camp_preparations={};SaveService.data.control_setup_done=true;SaveService.data.input_guide_seen=true;SaveService.data.camp_tutorial={"enabled":false,"completed":true}
	Characters.set_current(&"sylphiette");Outpost.data.active={};Outpost.data.contracts=[];Outpost.data.contract_jobs={};PassiveDefinitions._selected.clear();GameState.run_active=false
	var camp:=CampWorld.new();add_child(camp)
	while not camp.initialization_complete:await frames(1)
	check(camp.initialization_success,"locked progression camp initializes")
	var bag:InventoryUI=camp.inventory_ui
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;bag.open_camp_page(&"skill");await frames(5)
		var original:Array=camp.preparation.skill_loadout.duplicate()
		var button:=bag._find_focus_token(bag._shell,"camp:skill:healing_light") as Button
		check(button!=null and button.find_child("ProgressLock",true,false)!=null,"locked skill has graphic lock "+str(extent))
		button.pressed.emit();await frames(4)
		check(labels(bag._detail_box).contains("未解锁") and labels(bag._detail_box).contains("晶化巨影"),"selection shows explicit unlock condition "+str(extent))
		check(bag._find_focus_token(bag._shell,"camp:equip_skill:0")==null and camp.preparation.skill_loadout==original,"locked skill cannot be equipped "+str(extent))
		var passive:=bag._find_focus_token(bag._shell,"camp:passive:sylphiette_grace") as Button
		check(passive!=null and not passive.disabled and passive.find_child("ProgressLock",true,false)!=null,"locked passive can be inspected with any input "+str(extent))
		passive.pressed.emit();await frames(4)
		check(labels(bag._detail_box).contains("未解锁") and labels(bag._detail_box).contains("永恒恩典") and PassiveDefinitions.selected(&"sylphiette")==&"sylphiette_hymn","locked passive displays condition without selecting "+str(extent))
		bag._finish_close();await frames()
	var contract:Dictionary=ExpeditionData.CONTRACTS.filter(func(c:Dictionary)->bool:return str(c.id)=="camp_surveyor_labels")[0]
	Outpost.data.contract_jobs[str(contract.id)]={"status":"accepted"}
	check(Outpost.contract_needs(contract)==CommissionCosts.LEGACY[str(contract.id)],"already accepted commission retains promised quantity")
	Outpost.data.contract_jobs[str(contract.id)].cost_revision=34
	check(Outpost.contract_needs(contract)==contract.needs and contract.needs!=CommissionCosts.LEGACY[str(contract.id)],"new acceptance uses increased quantities")
	camp.queue_free();await frames(5);CampSession.active=false;GameState.run_active=false
	AudioManager.shutdown();await get_tree().create_timer(.3,true,false,true).timeout
	print("PROGRESSION_UI_V34 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
