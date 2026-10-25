extends "res://tests/inventory_v17.gd"
class PreviewBoss:
	extends BossBase
	func _ready()->void:pass
	func _physics_process(_dt:float)->void:pass
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);SaveService.data.reduced_motion=true
	for hero:StringName in [&"sylphiette",&"xixifu",&"ilyua"]:
		await begin(hero)
		var hud:=main.hud as RoomHud
		check(not hud.get_children().any(func(node:Node)->bool:return node is WorldClockUI),"no analog clock in actual room HUD")
		check(hud._portrait.texture!=null and hud._portrait_id==hero,"matching chibi portrait "+str(hero))
		check(hud._level_text.get_theme_font_size("font_size")==20 and hud._coin_text.get_theme_font_size("font_size")==20,"resource numbers enlarged")
		var boss:=PreviewBoss.new();main.add_child(boss)
		for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
			get_window().size=extent;await frames(5)
			for active:bool in [false,true]:
				main.director.boss=boss if active else null;hud._process(0);await frames(3)
				if active:main.boss_bar._on_boss_started(&"king");await frames(3)
				var area:=MobileControls.safe_rect() if MobileControls.enabled() else get_viewport().get_visible_rect()
				for control:Control in [hud._portrait,hud._hp_bar,hud._mp_bar,hud._exp_bar,hud._resources_row,hud._time_column]:
					check(area.grow(1).encloses(control.get_global_rect()),"HUD element inside safe area "+str(extent))
				check(not hud._portrait.get_global_rect().intersects(hud._hp_bar.get_global_rect()),"portrait and health separated")
				check(hud._world_time_text.get_global_rect().position.y>=hud._time_text.get_global_rect().end.y,"world digits below journey")
				check(hud._time_column.is_visible_in_tree(),"both times remain visible during boss")
				check(not hud._resources_row.get_global_rect().intersects(hud._exp_bar.get_global_rect()),"larger coin/level below meters")
				check(not hud.room_map.get_global_rect().intersects(hud._time_column.get_global_rect()),"time avoids minimap")
				if active:check(not main.boss_bar._panel.get_global_rect().intersects(hud._time_column.get_global_rect()),"time avoids actual boss panel")
				else:check(not hud._status_text.get_global_rect().intersects(hud._time_column.get_global_rect()),"world/trip block avoids room instructions")
				for bar:PlayerStatBar in [hud._hp_bar,hud._mp_bar,hud._exp_bar]:
					check(bar._frame!=null and bar._liquid!=null and bar.meter_rect().size.y>=(6 if bar.kind=="xp" else 18),"meter trim and readable fill hierarchy")
		main.director.boss=null;boss.queue_free()
		main.world_clock.minutes=1439.8;hud._process(0);check(hud._world_time_text.text=="23:59","world time is numeric HH:MM")
		var journey:=GameState.active_play_seconds;main.world_clock.tick(1);hud._process(0)
		check(hud._world_time_text.text==main.world_clock.time_label() and GameState.active_play_seconds==journey,"world clock source and journey remain separate")
		var hp:=hud._hp_bar as PlayerStatBar;hp.set_max_value(100);hp.set_capacity_loss(20);hp.set_value(75,true)
		check(hp.capacity_loss==20 and hp._amount_label.text=="75 / 100","scar/value data preserved")
		hud._exp_bar.call("set_capped",true);check((hud._exp_bar as PlayerStatBar)._amount_label.text=="已满级","maximum-level wording preserved")
		await frames();await settle_actor()
	AudioManager.shutdown();await frames()
	print("HUD_REFRESH_V23 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
