extends "res://tests/refinement_runtime_v08.gd"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	AchievementTracker.set_process(false)
	var primary:=load(GameFonts.BODY) as Font
	var song:=GameFonts.song_fallback()
	var body:=GameFonts.get_font("body") as FontVariation
	var theme:=load("res://assets/fonts/game_theme.tres") as Theme
	check(body.fallbacks.size()>=2 and body.fallbacks[0]==song,"Songti is first explicit body fallback")
	check(theme.default_font is FontVariation and (theme.default_font as FontVariation).fallbacks.size()>=2,"project theme includes fallback chain")
	var missing_codepoint:=0
	for codepoint in range(0x4e00,0x9fa6):
		if not primary.has_char(codepoint) and song.has_char(codepoint):missing_codepoint=codepoint;break
	check(missing_codepoint>0 and body.has_char(missing_codepoint),"missing game-font Han glyph is supplied by Songti")
	var original:=Outpost.data.duplicate(true);var old_save:=SaveService.data.duplicate(true)
	for hero:StringName in [&"sylphiette",&"xixifu",&"ilyua"]:
		await begin(hero)
		var inventory:=main.inventory_ui
		var ui:TalentUI=inventory.talent_view
		inventory.open_talent_page()
		for frame in 3:await get_tree().process_frame
		check(ui.is_open() and UIFlow.is_top(inventory),"run talent page opens "+str(hero))
		check(ui._tree_panel.visible and not ui._stat_panel.get_parent().visible,"run defaults to skill tree "+str(hero))
		check(ui._tree._buttons.size()==40,"run displays four equipped trees "+str(hero))
		GameState.talent_points=1;ui._refresh()
		var skill_id:=GameState.skill_loadout()[0]
		var route:=SkillTalentCatalog.route_id(skill_id,&"power")
		var first:=TalentGraph.id_for(route,1)
		ui._upgrade_branch(first)
		ui._upgrade_branch(first)
		check(int(GameState.talents.get(route,0))==1 and GameState.talent_points==0,"run node purchases one point "+str(hero))
		check(not ui._mode_button.visible and not ui._stat_panel.get_parent().visible,"run cannot enter permanent purchase page "+str(hero))
		inventory._finish_close()
		CampSession.active=true;CampSession.training_active=false;CampSession.owner=weakref(self)
		Outpost.data.permanent_stats={};Outpost.data.gold=PermanentStats.cost(&"vitality",1).gold
		var price:=PermanentStats.cost(&"vitality",1)
		Outpost.data.inventory={}
		for material in price.materials:Outpost.data.inventory[material]=price.materials[material]
		inventory.open_talent_page()
		for frame in 3:await get_tree().process_frame
		check(ui._stat_panel.get_parent().visible and not ui._tree_panel.visible,"camp defaults to permanent stats "+str(hero))
		var purchase:Button=null
		for candidate in ui._stat_panel.find_children("*","Button",true,false):
			if candidate.text=="购买下一级":purchase=candidate;break
		check(purchase!=null,"camp purchase control "+str(hero))
		if purchase!=null:purchase.pressed.emit()
		check(PermanentStats.rank(&"vitality")==1,"camp control buys permanent rank "+str(hero))
		check(not ui._mode_button.visible and not ui._tree_panel.visible,"camp cannot enter run skill tree "+str(hero))
		inventory._finish_close()
		inventory.camp_preparation=CampPreparation.new()
		inventory._filter=&"gear"
		inventory.open()
		for frame in 2:await get_tree().process_frame
		var visible_tabs:Array[Button]=[]
		for tab in inventory._tab_buttons:
			if tab.visible:visible_tabs.append(tab)
		check(visible_tabs.size()==5,"camp has five visible tabs "+str(hero))
		var aligned:=true
		for index in visible_tabs.size()-1:
			if not is_equal_approx(visible_tabs[index+1].position.x-visible_tabs[index].position.x,194.0):aligned=false
		check(aligned,"camp tabs are consecutive "+str(hero))
		inventory.open_talent_page()
		for frame in 3:await get_tree().process_frame
		check(ui._stat_panel.get_parent().visible and not ui._tree_panel.visible,"real camp backpack shows permanent talents "+str(hero))
		check(inventory._tab_buttons[6].visible and inventory._tab_buttons[6].get_global_rect().has_area(),"camp talent tab remains visible "+str(hero))
		inventory._finish_close()
		inventory.camp_preparation=null
		CampSession.active=false;CampSession.owner=null
		await settle_actor()
	Outpost.data=original;SaveService.data=old_save
	AudioManager.shutdown();await get_tree().process_frame
	print("TALENT_UI_V39 checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
