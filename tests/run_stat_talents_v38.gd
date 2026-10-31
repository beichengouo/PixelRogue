extends "res://tests/refinement_runtime_v08.gd"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	AchievementTracker.set_process(false)
	var old_outpost:=Outpost.data.duplicate(true);var old_save:=SaveService.data.duplicate(true)
	await begin(&"sylphiette")
	check(GameState.talent_points==0 and GameState.talents.is_empty(),"new run has no skill points")
	check(GameState.talent_budget(2)==0 and GameState.talent_budget(3)==1 and GameState.talent_budget(6)==2,"one point per three levels")
	GameState.gain_exp(GameState.exp_needed(1)+GameState.exp_needed(2))
	check(GameState.level==3 and GameState.talent_points==1,"level three grants one")
	var skill:=GameState.skill_loadout()[0]
	var route:=SkillTalentCatalog.route_id(skill,&"power")
	check(GameState.spend_talent_point(route),"run skill purchase")
	check(GameState.talent_points==0 and int(GameState.talents.get(route,0))==1,"point spent once")
	check(not GameState.spend_talent_point(route),"no free repeat")
	GameState.coins=2000
	check(GameState.buy_talent_point() and GameState.coins==1000 and GameState.talent_points==1,"1000 gold buys one point")
	var blocker:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp"
	check(DirAccess.make_dir_absolute(blocker)==OK,"save blocker")
	check(not GameState.buy_talent_point() and GameState.coins==1000 and GameState.talent_points==1,"buy rollback")
	check(DirAccess.remove_absolute(blocker)==OK,"remove blocker")
	GameState.award_talent_points(1)
	check(GameState.talent_points==2,"special reward point")
	var event_record:Dictionary={"kind":"event","rewarded":false,"seed":17,"biome":"forest","delta":{}}
	var event_state:Dictionary={"event_id":"pack","event_resolved":false,"offers":[],"pending":[]}
	event_record.delta.expansion=event_state
	main.expansion.record=event_record;main.expansion.state=event_state;main.expansion.validation_mode=true
	main.expansion._event_offers()
	check(main.expansion.state.offers.size()==3,"curio room offers talent point choice")
	var before_event:=GameState.talent_points
	check(main.expansion.claim_event(2) and GameState.talent_points==before_event+1,"curio event grants exactly one point")
	check(not main.expansion.claim_event(2) and GameState.talent_points==before_event+1,"curio cannot claim twice")
	main.expansion.validation_mode=false
	var pos:Vector2=main.player.position
	main.level.scene_polygons["machine_wheel"]=PackedVector2Array([pos+Vector2(30,-10),pos+Vector2(50,-10),pos+Vector2(50,10),pos+Vector2(30,10)])
	var wheel_record:Dictionary={"kind":"game","terrain_layout":{"scene_art":"game_hall_v01"},"delta":{}}
	var wheel_state:Dictionary={"used":{},"rng":"1","pending_prizes":[],"deliveries":[]}
	wheel_record.delta.special=wheel_state;main.special_rooms.record=wheel_record;main.special_rooms.state=wheel_state;main.special_rooms.validation_mode=true
	var rng:=RandomNumberGenerator.new()
	for seed_value in 100:
		rng.seed=seed_value;var chosen_state:=str(rng.state)
		if rng.randi_range(0,4)==4:wheel_state.rng=chosen_state;break
	GameState.coins=1000
	var before_wheel:=GameState.talent_points
	var result:Dictionary=main.special_rooms.play("machine_wheel")
	check(str(result.get("error",""))=="" and int(result.get("talent_points",0))==1 and GameState.talent_points==before_wheel+1,"wheel grants one point")
	check(not str(main.special_rooms.play("machine_wheel").get("error","")).is_empty(),"wheel cannot pay twice")
	var saved:=GameState.snapshot();GameState.restore(saved)
	check(GameState.talent_points==4 and int(GameState.talents.get(route,0))==1,"run reload")
	var terminal:=TalentGraph.id_for(PermanentTalents.terminal_id(skill),1)
	for lane:StringName in SkillTalentCatalog.ROUTES:GameState.talents[SkillTalentCatalog.route_id(skill,lane)]=3
	GameState.talent_points=1
	check(not GameState.talent_unlocked(terminal) and not GameState.spend_talent_point(terminal),"terminal meta gate blocks")
	var capstone:Dictionary=PermanentTalents.skill(skill)
	var tier:Dictionary=PermanentTalents.catalog().tiers[capstone.tier]
	SaveService.data.achievements[CharacterUnlocks.achievement_id(str(Characters.current_id()),str(tier.achievement))]=true
	SaveService.data.achievement_stats["hero_boss:%s:%s"%[Characters.current_id(),capstone.boss]]=int(tier.boss_kills)
	Outpost.data.talent_clears["%s|%s|%d"%[Characters.current_id(),PermanentTalents.chapter_for_boss(str(capstone.boss)),int(tier.difficulty)]]=int(tier.clears)
	check(GameState.talent_unlocked(terminal) and GameState.spend_talent_point(terminal),"terminal bought with run point after gate")
	check(PermanentTalents.active(skill) and not GameState.spend_talent_point(terminal),"terminal active once")
	GameState.learned_skills.erase(skill)
	check(not PermanentTalents.active(skill),"unequipped skill effect dormant")
	GameState.restore({"character":"sylphiette","level":10,"talent_points":20,"talents":{"power":3},"talent_tree_version":1})
	check(GameState.talent_points==0 and GameState.talents.is_empty(),"legacy run talents clear")
	await settle_actor()
	Outpost.data=old_outpost;SaveService.data=old_save
	AudioManager.shutdown();await get_tree().process_frame
	print("RUN_SKILL_TALENTS_V39 checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
