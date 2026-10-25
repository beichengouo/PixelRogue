extends "res://tests/v21_dialogue_input.gd"
func pick_token(bag:InventoryUI,token:String)->Control:
	return bag._find_focus_token(bag._shell,token)
func cancel_key()->void:
	for binding:InputEvent in InputMap.action_get_events("ui_cancel"):
		if binding is InputEventKey:
			var event:=binding.duplicate() as InputEventKey;event.pressed=true;await inject(event);event=event.duplicate() as InputEventKey;event.pressed=false;await inject(event);break
	await get_tree().create_timer(.2,true,false,true).timeout;await frames(6)
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/work/v34-gameplay-polish/"):get_tree().quit(2);return
	AchievementTracker.set_process(false);ErrorReporter.interactive=false;TransitionLayer.boot_played=true;Input.emulate_mouse_from_touch=true
	SaveService.data.run={};SaveService.data.control_setup_done=true;SaveService.data.input_guide_seen=true;SaveService.data.camp_tutorial={"enabled":false,"completed":true};SaveService.data.reduced_motion=true;SaveService.data.camp_preparations={}
	Characters.set_current(&"sylphiette");Outpost.data.active={};Outpost.data.inventory={"staff_cloud_radiance":3,"potion_health":20};Outpost.data.capacity=100;Outpost.data.gold=10000;StoryState.flags.chapter_2_unlocked=true
	# These input cases exercise already-unlocked controls. Gating has its own probe.
	Outpost.data.contracts=CharacterUnlocks.COMMISSIONS.values()
	for character in Characters.DATA:
		for tier in ["opening","middle","final"]:SaveService.data.achievements[CharacterUnlocks.achievement_id(str(character),tier)]=1
	var camp:=CampWorld.new();add_child(camp)
	while not camp.initialization_complete:await frames(1)
	check(camp.initialization_success,"input camp initialized")
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(8)
		for mode:String in ["keyboard","mouse","gamepad","touch"]:
			var context:=str(extent)+":"+mode
			camp.preparation.difficulty=1;camp.camp_ui.open_facility("prepare");await frames(8)
			var difficulty:=camp.camp_ui._body.find_child("Difficulty_2",true,false) as Button
			await activate(difficulty,mode);await frames(6)
			check(camp.preparation.difficulty==2,"actual difficulty input "+context)
			var shortcut:=camp.camp_ui._body.find_child("Summary_weapon",true,false) as Button
			await activate(shortcut,mode);await frames(8)
			var bag:=camp.inventory_ui
			check(UIFlow.is_top(bag) and bag._filter==&"gear","actual graphic shortcut opens bag "+context)
			bag.camp_content.selected_key="staff_cloud_radiance";bag.camp_content.details_mode="item";bag._rebuild();await frames(4)
			camp.preparation.unequip_slot(&"weapon");bag._rebuild();await frames(4)
			var equip:=pick_token(bag,"camp:equip:staff_cloud_radiance")
			check(equip!=null,"equipment action present "+context)
			if equip!=null:check(get_viewport().get_visible_rect().grow(1).encloses(equip.get_global_rect()),"equipment action fits viewport "+context)
			if equip!=null:await activate(equip,mode);await frames(4)
			check(camp.preparation.equipped_key(&"weapon")=="staff_cloud_radiance" and GameState.equipped(&"weapon").get("id","")=="staff_cloud_radiance","actual equip updates draft and preview "+context)
			var tab:=bag._tab_buttons[bag._tab_ids.find(&"skill")];await activate(tab,mode);await frames(4)
			check(bag._filter==&"skill","actual skill tab input "+context)
			var options:Array=[]
			for id:StringName in Skills.order_for():
				if not Skills.is_ultimate(id) and id!=StringName(camp.preparation.skill_loadout[0]):options.append(id)
			var chosen:=StringName(options[-1]);var skill:=pick_token(bag,"camp:skill:"+str(chosen))
			if skill!=null:await activate(skill,mode);await frames(4)
			var slot:=pick_token(bag,"camp:equip_skill:0")
			if slot!=null:await activate(slot,mode);await frames(4)
			check(StringName(camp.preparation.skill_loadout[0])==chosen and Skills.valid_loadout(camp.preparation.skill_loadout),"actual skill equip "+context)
			var passives:=PassiveDefinitions.for_character(Characters.current_id())
			var passive_id:=StringName(passives[1].id) if PassiveDefinitions.selected(Characters.current_id())==StringName(passives[0].id) else StringName(passives[0].id)
			var passive:=pick_token(bag,"camp:passive:"+str(passive_id))
			if passive!=null:await activate(passive,mode);await frames(4)
			check(PassiveDefinitions.selected(Characters.current_id())==passive_id and GameState.passive_id==passive_id,"actual passive choice updates camp preview "+context)
			tab=bag._tab_buttons[bag._tab_ids.find(&"potion")];await activate(tab,mode);await frames(4)
			bag.camp_content.selected_key="potion_health";bag.camp_content.details_mode="item";bag._rebuild();await frames(4)
			var old:=camp.preparation.potion_count("potion_health")
			if old>=15:camp.preparation.set_potion_count("potion_health",0);old=0;bag._rebuild();await frames(4)
			var plus:=pick_token(bag,"camp:potion_plus:potion_health")
			if plus!=null:await activate(plus,mode);await frames(4)
			check(camp.preparation.potion_count("potion_health")==old+1 and int(Outpost.data.inventory.potion_health)==20,"actual potion input reserves one "+context)
			check(not bag._sell_button.visible and not bag._bind_button.visible,"camp bag hides consuming item operations "+context)
			await cancel_key()
			check(camp.camp_ui.is_open() and not bag.is_open(),"actual back returns to overview "+context)
			var focus:=get_viewport().gui_get_focus_owner()
			check(focus!=null and str(focus.get_meta("focus_token",""))=="summary:gear:weapon","return restores original summary focus "+context)
			var start:=camp.camp_ui._root.find_child("DepartNow",true,false) as Button
			check(get_viewport().get_visible_rect().grow(1).encloses(start.get_global_rect()),"footer remains in viewport "+context)
			camp.camp_ui.close();await frames()
	# Optional farewell cancellation must never debit or enter a sortie.
	camp.camp_ui.open_facility("prepare");camp.camp_ui._farewell=true;await frames(6)
	var before:=Outpost.data.duplicate(true);camp.camp_ui._depart();await frames(6)
	check(is_instance_valid(camp.camp_ui._sendoff) and camp.camp_ui._sendoff.is_open(),"optional sendoff opens")
	await cancel_key();check(Outpost.data==before and camp.camp_ui.is_open() and not camp.camp_ui._busy,"sendoff cancellation retains inventory and camp")
	camp.camp_ui.close();camp.queue_free();await frames(10)
	AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout
	print("CAMP_DEPARTURE_INPUT checks=",checks," failures=",failures," android_device_tested=false");get_tree().quit(1 if failures else 0)
