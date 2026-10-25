extends "res://tests/inventory_v17.gd"

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);SaveService.data.reduced_motion=true
	await begin(&"ilyua")
	var hud:=main.hud as RoomHud
	var bar:BossBar=main.boss_bar
	# Two complete rows exercise status layout without changing combat effects.
	hud._player_statuses.set_process(false);hud._player_statuses.columns=9
	for i in 18:hud._player_statuses._make_cell()
	hud._player_statuses.show()
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(5)
		var area:=MobileControls.safe_rect() if MobileControls.enabled() else get_viewport().get_visible_rect()
		var group:=hud._hero_panel.get_global_rect()
		check(area.grow(1).encloses(group),"hero group in safe area "+str(extent))
		for control:Control in [hud._portrait_frame,hud._hp_bar,hud._mp_bar,hud._exp_bar,hud._resources_row]:
			check(group.grow(1).encloses(control.get_global_rect()),"one connected hero status group "+str(extent))
		check(hud._portrait.size.x<=72 and hud._portrait.size.y<=72,"compact head portrait")
		check(hud._hp_bar.size.y>hud._mp_bar.size.y and hud._mp_bar.size.y>hud._exp_bar.size.y*2,"health mana and experience hierarchy")
		check(hud._hp_bar.position.x==hud._mp_bar.position.x and hud._hp_bar.size.x==hud._mp_bar.size.x,"aligned equal-width vital tracks")
		check(hud._time_column.get_global_rect().position.y>=hud.room_map.get_global_rect().end.y+6,"clocks attached below minimap")
		check(hud._world_time_text.is_visible_in_tree(),"numeric world clock retained")
		hud.set_coins(2147483647);hud._level_text.text="Lv.100";await frames()
		check(group.grow(1).encloses(hud._resources_row.get_global_rect()),"long coin count stays in group")
		check(hud._coin_text.get_global_rect().end.x<=hud._resources_row.get_global_rect().end.x,"coin text retained before XP")
		hud.set_coins(0);hud._level_text.text="Lv.1";await frames()
		for id:StringName in [&"king",&"mage",&"tide",&"sephra",&"verena",&"nameless"]:
			bar._on_boss_started(id);await frames(3)
			var expected:Texture2D=BossEntranceArt.pack(str(id)).title
			check(expected!=null and bar._name_art.texture==expected,"exact entrance title resource "+str(id))
			check(bar._name_art.visible and not bar._name_label.visible,"art replaces normal title "+str(id))
			check((bar._name_art.texture as AtlasTexture).atlas.resource_path.ends_with(str(id)+"_title.png"),"name art source "+str(id))
			var subtitle:=str(BossRoster.get_data(id).get("subtitle",""))
			check(not bar._root.find_children("*","Label",true,false).any(func(node:Node)->bool:return node.text==subtitle and not subtitle.is_empty()),"no boss descriptor text "+str(id))
			check(not bar.get_property_list().any(func(property:Dictionary)->bool:return property.name in ["_sub_art","_sub_label"]),"no boss descriptor artwork")
			check(bar._panel.get_theme_stylebox("panel") is StyleBoxEmpty,"boss bar has no background")
			check(area.grow(1).encloses(bar._panel.get_global_rect()),"boss inside safe bounds "+str(extent))
			check(not bar._panel.get_global_rect().intersects(group),"boss avoids player stats")
			check(not bar._panel.get_global_rect().intersects(hud.room_map.get_global_rect()),"boss avoids minimap")
			check(not bar._panel.get_global_rect().intersects(hud._time_column.get_global_rect()),"boss avoids clocks")
			check(bar._panel.get_global_rect().encloses(bar._name_art.get_global_rect()),"complete title art inside boss area")
			check(bar._name_art.size.y>=34 and bar._bar.size.y>=30,"title and health remain readable")
		print("HUD_V24_LAYOUT window=",extent," viewport=",get_viewport().get_visible_rect().size," hero=",group," boss=",bar._panel.get_global_rect())
		check(not bar._panel.get_global_rect().intersects(hud._player_statuses.get_global_rect()),"boss avoids multiple status rows")
	bar._root.hide();bar._boss_id=&""
	for id:StringName in [&"sylphiette",&"xixifu",&"ilyua"]:
		Characters.set_current(id);hud._process(0);await frames()
		check(hud._portrait_id==id and hud._portrait.texture.resource_path.contains("/hud_v24/avatar_"+str(id)),"new portrait refreshes with character "+str(id))
	var hp:=hud._hp_bar as PlayerStatBar
	hp.set_max_value(100);hp.set_capacity_loss(20);hp.set_value(30,true);hp.set_value(10);await frames()
	check(hp._ghost>hp._shown and hp._loss_time>0,"damage ghost remains")
	hp.set_value(50);await frames();check(hp._gain_time>0 and hp.capacity_loss==20,"healing feedback retains scars")
	check(hp._amount_label.text=="50 / 100","health values remain exact")
	hud._exp_bar.call("set_capped",true);await frames();check((hud._exp_bar as PlayerStatBar)._amount_label.is_visible_in_tree() and (hud._exp_bar as PlayerStatBar)._amount_label.text=="已满级","capped experience visible beside resources")
	await settle_actor();AudioManager.shutdown();await frames()
	print("HUD_REFINEMENT_V24 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
