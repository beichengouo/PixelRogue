extends "res://tests/inventory_v17.gd"
func run()->void:
	if not OS.get_user_data_dir().begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(1);return
	AchievementTracker.set_process(false);SaveService.data.reduced_motion=true
	for hero:StringName in Characters.DATA:
		await begin(hero)
		await bounds_checks()
		await settle_actor()
	await story_checks()
	AudioManager.shutdown()
	# Dummy audio still owns mixer references until its next mix cycle.
	await get_tree().create_timer(.25,true,false,true).timeout
	await frames()
	print("INTERACTION_NARRATIVE_V20 checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
func bounds_checks()->void:
	var bag:=main.inventory_ui;var talent:=bag.talent_view
	for extent:Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames()
		bag.open_talent_page();await frames(6)
		var mount:=bag._talent_mount.get_global_rect()
		var viewport:=talent._canvas.get_child(0) as ScrollContainer
		check(mount.grow(1).encloses(viewport.get_global_rect()),"talent viewport stays inside bag "+str(extent))
		check(viewport.get_child(0).size.x<=viewport.size.x+1,"panel does not propagate excessive intrinsic width")
		for id:StringName in TalentGraph.visible_nodes():
			talent._on_node_selected(id);await frames(2)
			check(viewport.get_child(0).size.x<=viewport.size.x+1,"long node description fits "+str(id))
		check(talent._root.clip_contents,"embedded tree clips offscreen scrolled content")
		talent._set_zoom(2);await frames();check(mount.grow(1).encloses(viewport.get_global_rect()),"200 percent zoom stays within inventory")
		bag._finish_close();await frames()
	get_window().size=Vector2i(1920,1080)
func story_checks()->void:
	# Expected injected disk failures must not open the player's diagnostics modal.
	ErrorReporter.interactive=false
	var ids:Array=[&"intro_wake",&"intro_weapon",&"death_first",&"death_hall",&"death_hall_intro",&"death_reenter",&"forest_king_before",&"forest_mage_before",&"forest_tide_before",&"stage_echo_entry",&"fate_observation"]
	for checkpoint in range(10,101,10):ids.append(Story.checkpoint_id(checkpoint))
	ids.append_array(CityStories.IDS)
	for hero:StringName in Characters.DATA:
		Characters.set_current(hero)
		for id:StringName in ids:
			var scene:=Story.get_scene(id,false,hero)
			check(not scene.is_empty(),"stable narrative ID "+str(id))
			check(scene.get("choices",[]).size()<=3,"choice limit "+str(id))
			var encoded:=JSON.stringify(scene)
			if hero==&"sylphiette":check(not encoded.contains("帽檐") and not encoded.contains("帽带"),"no retired hat persona")
			check(not encoded.contains("每一次潮汐，都会杀死所有人") and not encoded.contains("第一个约定的人，是我"),"unproven history stays uncertain")
		check(CampStory.EVENTS[str(hero)].size()>=5,"all heroes have five relationship scenes")
		Outpost.data.bonds[str(hero)]=250
		for event:Dictionary in CampStory.EVENTS[str(hero)]:
			if str(event.id)!="romance":Outpost.data.events[str(hero)+":"+str(event.id)]=true
		Outpost.data["relationships"]={}
		check(not CampStory.can_romance(str(hero)),"high affinity alone does not grant romance")
		Outpost.data.relationships[str(hero)]="mutual_interest"
		check(CampStory.can_romance(str(hero)),"mutual interest permits explicit invitation")
		check(Outpost.bond_event(str(hero),"romance",5,false,"romance"),"explicit romance committed")
		check(CampStory.relationship(str(hero))=="romance","relationship persisted")
		var persisted:Variant=JSON.parse_string(FileAccess.get_file_as_string(SaveService.SAVE_PATH))
		check(persisted.outpost.relationships[str(hero)]=="romance","relationship survives save serialization")
		check(not Outpost.bond_event(str(hero),"romance",5,false,"romance"),"replay never grants another reward")
		var other:="ilyua" if hero!=&"ilyua" else "xixifu"
		Outpost.data.relationships[other]="mutual_interest"
		check(not CampStory.can_romance(other),"one consensual romance at a time")
		Outpost.data.relationships={}
		var daily:=CampStory.daily_event(str(hero));var before:=int(Outpost.data.bonds[str(hero)])
		check(Outpost.bond_event(str(hero),str(daily.id),4),"daily conversation available independent of selected hero")
		check(not Outpost.bond_event(str(hero),str(daily.id),4),"daily interaction cannot repeat rewards")
		check(int(Outpost.data.bonds[str(hero)])>=before,"daily growth does not penalize friendships")
		Outpost.data.get("conversation_days",{})[str(hero)]=BondRules.day_key(BondRules.now())-1
		check(Outpost.bond_event(str(hero),str(daily.id),4),"next day's conversation remains available")
		Outpost.data.events.erase(str(hero)+":close");Outpost.data.relationships={}
		var pending_path:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp"
		DirAccess.make_dir_recursive_absolute(pending_path)
		var before_failure:=Outpost.data.duplicate(true);var save_before:=SaveService.data.duplicate(true)
		check(not Outpost.bond_event(str(hero),"close",4,false,"mutual_interest"),"failed save rejects relationship transition")
		check(Outpost.data==before_failure and SaveService.data==save_before,"failed relationship save rolls back all state")
		DirAccess.remove_absolute(pending_path)
		Outpost.data.events[str(hero)+":close"]=true
		var invitation:=CampStory.invitation_event(str(hero))
		check(not invitation.is_empty(),"legacy close event can explicitly choose relationship")
		check(Outpost.bond_event(str(hero),"invitation",4,false,"mutual_interest"),"legacy opt-in preserves old event IDs")
	var camp:=CampUI.new();camp.world_mode=true;add_child(camp);await frames()
	Outpost.data.bonds.sylphiette=250;Outpost.data.events["sylphiette:memory"]=true;Outpost.data.events.erase("sylphiette:memory_flower");Outpost.data.inventory.memory_gift=0
	var flower:Dictionary=CampStory.EVENTS.sylphiette.back()
	check(not CampStory.available("sylphiette",flower),"optional gift requires a real flower without blocking the memory scene")
	Outpost.data.inventory.memory_gift=1
	check(Outpost.bond_event("sylphiette","memory_flower",4,false),"gift consumption is derived from the event definition")
	check(int(Outpost.data.inventory.memory_gift)==0,"optional flower consumes exactly one stored item")
	camp.open_facility("relations")
	for npc in ["sylphiette","ilyua","xixifu","iris","merchant","tavern"]:
		camp._npc=npc;camp._refresh();await frames()
		check(camp._portrait.texture!=null,"relationship portrait "+npc)
	camp._npc="ilyua";var event:Dictionary=CampStory.EVENTS.ilyua[3]
	camp._play_event(event,true);camp._line=event.lines.size()-1;camp._refresh();await frames()
	var snapshot:=Outpost.data.duplicate(true)
	camp._choose_relation(event.choices[0]);camp._advance_scene();check(Outpost.data==snapshot,"replaying relationship choices is read only")
	camp.close();camp.queue_free();await frames()
	Characters.set_current(&"sylphiette")
	var dialogue:=DialogueUI.new();add_child(dialogue);await frames()
	dialogue.expedition_restore({"scene_id":"cp_50","scene":{"title":"old"},"lines":[{"text":"old 帽檐"}],"offered":[{"text":"old grant","give":"iron_sword"}],"index":0,"mode":"reply"})
	await frames()
	check(int(dialogue._scene.get("narrative_revision",0))==ContractorNarrative.REVISION and not JSON.stringify(dialogue._lines).contains("帽檐"),"legacy embedded dialogue payload uses revised canonical text")
	check(dialogue._offered.is_empty(),"legacy reward/choice payload cannot replay committed effects")
	dialogue.cancel();dialogue.queue_free();await frames()
