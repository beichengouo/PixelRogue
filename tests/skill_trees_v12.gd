extends "res://tests/refinement_runtime_v08.gd"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	AchievementTracker.set_process(false)
	var old_outpost:=Outpost.data.duplicate(true);var old_save:=SaveService.data.duplicate(true)
	for hero:StringName in [&"sylphiette",&"xixifu",&"ilyua"]:
		await begin(hero)
		var graph:=TalentGraph.nodes(hero)
		check(graph.size()==80,"eight ten-node trees "+str(hero))
		check(GameState.talent_budget(3)==1 and GameState.talent_budget(10)==3,"three-level point schedule "+str(hero))
		for skill:StringName in Skills.order_for(hero):
			var nodes:=0
			for route:StringName in SkillTalentCatalog.ROUTES:
				var effect:=SkillTalentCatalog.route_id(skill,route)
				for rank in range(1,4):
					var id:=TalentGraph.id_for(effect,rank)
					check(graph.has(id),"route node "+str(id))
					check(graph[id].requires_all.size()==(0 if rank==1 else 1),"linear rank prerequisite "+str(id))
					nodes+=1
			var terminal:=TalentGraph.id_for(PermanentTalents.terminal_id(skill),1)
			check(graph.has(terminal) and graph[terminal].requires_all.size()==3,"terminal needs three max routes "+str(skill))
			check(nodes==9,"nine base nodes "+str(skill))
		check(TalentGraph.visible_nodes().size()==40,"four equipped skill trees "+str(hero))
		var first_skill:=GameState.skill_loadout()[0]
		var route:=SkillTalentCatalog.route_id(first_skill,&"power")
		GameState.talent_points=1
		check(GameState.spend_talent_point(route),"run spends skill point "+str(hero))
		check(SkillTalentCatalog.route_rank(first_skill,&"power")==1,"equipped effect active "+str(hero))
		await settle_actor()
	Outpost.data=old_outpost;SaveService.data=old_save
	AudioManager.shutdown();await get_tree().process_frame
	print("SKILL_TREES_V39 checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
