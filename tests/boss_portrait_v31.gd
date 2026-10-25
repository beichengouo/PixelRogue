extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v31-boss-pressure/"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	await begin(&"sylphiette")
	var rows:Array=[]
	for extent in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(5)
		for id:String in BossPhaseRules.SKILLS:
			var boss:RoomBoss=CityBoss.new() if id in ["sephra","verena","nameless"] else RoomBoss.new()
			boss.configure(StringName(id));boss.room=main.level;boss.setup(actor,main.level,1,1,1);boss.fx_root=main.fx_root;boss.director=main.director
			main.enemies_root.add_child(boss);boss.set_physics_process(false)
			for phase in range(1,BossPhaseRules.thresholds(StringName(id)).size()):
				var cuts:=BossPhaseRules.thresholds(StringName(id))
				boss.hp=boss.max_hp*(float(cuts[phase-1])+float(cuts[phase]))*.5
				var bar:BossBar=main.boss_bar;bar._process(0);await frames(4)
				var texture:=BossStageArt.icon(StringName(id),phase)
				var pixels:=TexturePixels.image(texture);var visible_rect:=pixels.get_used_rect()
				var icon_box:=bar._icon.get_global_rect()
				var scale_factor:=minf(icon_box.size.x/texture.get_width(),icon_box.size.y/texture.get_height())
				var painted:=Vector2(visible_rect.size)*scale_factor
				check(bar._icon.visible and maxf(painted.x,painted.y)>=80,"visible silhouette enlarged "+id+str(phase)+str(extent))
				check(get_viewport().get_visible_rect().encloses(bar._panel.get_global_rect()),"HUD fits viewport "+id+str(extent))
				check(not icon_box.intersects(bar._name_art.get_global_rect()) and not icon_box.intersects(bar._bar.get_global_rect()),"portrait separates title and health "+id)
				check(bar._name_art.texture==BossEntranceArt.pack(id).title,"entrance title retained "+id)
				rows.append({"resolution":str(extent),"boss":id,"phase":phase,"box":str(icon_box),"painted_size":str(painted),"texture_region":str((texture as AtlasTexture).region)})
			boss.queue_free();await frames(2)
	var file:=FileAccess.open(ROOT+"portraits.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"));file.close()
	await settle_actor();AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout
	print("BOSS_PORTRAIT_V31 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
