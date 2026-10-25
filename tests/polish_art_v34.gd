extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v34-gameplay-polish/"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	for hero:StringName in [&"ilyua",&"xixifu",&"sylphiette"]:
		await begin(hero);main.gm_pilot.set_process(false)
		for form:bool in [false,true]:
			GameState.legendary_looks[str(hero)]={"set":form}
			var art:=HanddrawnHeroArt.frames(form,hero);actor._sprite.sprite_frames=art;RoomHeroArt.align(actor._sprite)
			check(art.get_meta("redrawn_character")==hero and bool(art.get_meta("set_form"))==form,"correct hero and outfit "+str(hero)+str(form))
			for dir:String in HanddrawnHeroArt.DIRECTIONS:
				check(art.get_frame_count("idle_"+dir)==1,"idle is a stable authored pose "+str(hero)+dir)
				for action:String in ["walk","attack","move_attack","back_attack","skill_cast"]:
					var name_value:=StringName(action+"_"+dir)
					check(art.get_frame_count(name_value)==4,"action keeps four source phases "+str(name_value))
					check(is_equal_approx(art.get_animation_speed(name_value),7.5 if action=="walk" else 12.5),"existing animation clock retained "+str(name_value))
					for index in 4:
						var texture:AtlasTexture=art.get_frame_texture(name_value,index)
						check(texture.atlas.resource_path.begins_with(HanddrawnHeroArt.ROOT) and texture.region.size==Vector2(448,448),"runtime uses current atlas and cell")
						var bounds:Rect2=texture.get_meta("painted_bounds")
						check(Rect2(0,0,448,448).encloses(bounds) and bounds.has_area(),"authored bounds are valid")
			for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
				get_window().size=extent;await frames(2)
				for dir:String in HanddrawnHeroArt.DIRECTIONS:
					actor._sprite.play("walk_"+dir);actor._sprite.flip_h=RoomHeroArt.flip_for("walk",dir);RoomHeroArt.align(actor._sprite)
					var foot:Vector2=art.get_meta("hd_foot");var cell:=float(art.get_meta("hd_cell"))
					# Flipping reflects only local x, whose foot pivot is centered.
					check(actor._sprite.to_global(foot-Vector2.ONE*cell*.5).distance_to(actor.global_position+Vector2(0,14))<.01,"foot anchor stable at "+str(extent)+dir)
			var seen:Dictionary={};actor._sprite.play(&"walk_w")
			for step in 9:
				await get_tree().create_timer(.075,true,false,true).timeout;seen[actor._sprite.frame]=true
			check(seen.has(1) and seen.has(3) and seen.size()==4,"real animation visits both centered passing poses")
			# Production player physics drives locomotion, with no enemy or stat aid.
			actor.global_position=main.level.nearest_clear(main.level.bounds().get_center(),12)
			var origin:=actor.global_position;var direction:=Vector2.ZERO
			for index in 16:
				var candidate:=Vector2.RIGHT.rotated(index*TAU/16)
				if main.level.segment_clear(origin,origin+candidate*130,12,false):direction=candidate;break
			GameState.gm_pilot_active=true;actor.movement_override=direction;actor.aim_override=Vector2.ZERO;actor.set_physics_process(true)
			var saw_walk:=false
			for index in 48:
				await get_tree().physics_frame;saw_walk=saw_walk or str(actor._sprite.animation).begins_with("walk_")
			actor.set_physics_process(false);GameState.gm_pilot_active=false;actor.movement_override=Vector2.ZERO
			check(saw_walk and actor.global_position.distance_to(origin)>10,"full player physics selects moving frames "+str(hero)+str(form))
			# Form replacement and decoy snapshots retain their own frame resources.
			var retained:=art;HanddrawnHeroArt.clear()
			check(retained.get_frame_texture(&"walk_w",1)!=null,"cache cleanup leaves live snapshot valid")
		await settle_actor()
	AudioManager.shutdown();await get_tree().create_timer(.3,true,false,true).timeout
	print("POLISH_ART_V34 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
