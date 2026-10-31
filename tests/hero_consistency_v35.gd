extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v35-hero-consistency/"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	for hero:StringName in [&"ilyua",&"xixifu",&"sylphiette"]:
		await begin(hero);main.gm_pilot.set_process(false)
		for form:bool in [false,true]:
			GameState.legendary_looks[str(hero)]={"set":form}
			var art:=HanddrawnHeroArt.frames(form,hero);actor._sprite.sprite_frames=art;RoomHeroArt.align(actor._sprite)
			check(str(art.get_meta("utility_facing",""))=="w","new utility source facing is explicit")
			if hero==&"ilyua" and form:
				check(not actor.uses_basic_chain(),"Ilyua model admission preserves current combat behavior")
				check(bool(art.get_meta("design_combo_only",false)),"Ilyua design preview is labelled")
			if hero==&"ilyua" and not form:
				check(not actor.uses_basic_chain(),"Ilyua model admission preserves current combat behavior")
				check(bool(art.get_meta("design_combo_only",false)),"Ilyua design preview is labelled")
			if hero==&"sylphiette":
				check(not actor.uses_basic_chain(),"Sylphiette art admission preserves current combat rules")
				check(bool(art.get_meta("design_combo_only",false)),"five-stage preview is explicitly design-only")
				for stage in range(1,6):
					check(art.get_frame_count("attack"+str(stage)+"_s")==4 and art.get_frame_count("move_attack"+str(stage)+"_s")==4,"five prayer gesture source clips retained")
			check(not RoomHeroArt.utility_flip(art,-1) and RoomHeroArt.utility_flip(art,1),"west source faces requested left/right")
			transition_checks(art)
			await decoy_checks(hero,art)
			check(art.get_meta("redrawn_character")==hero and bool(art.get_meta("set_form"))==form,"correct hero and outfit "+str(hero)+str(form))
			for dir:String in HanddrawnHeroArt.DIRECTIONS:
				check(art.get_frame_count("idle_"+dir)==1,"idle is a stable authored pose "+str(hero)+dir)
				for action:String in ["walk","attack","move_attack","back_attack","skill_cast"]:
					var name_value:=StringName(action+"_"+dir)
					check(art.get_frame_count(name_value)==4,"action keeps four source phases "+str(name_value))
					check(is_equal_approx(art.get_animation_speed(name_value),7.5 if action=="walk" else 12.5),"existing animation clock retained "+str(name_value))
					for index in 4:
						var texture:AtlasTexture=art.get_frame_texture(name_value,index)
						var atlas_root:="res://assets/heroes_handdrawn_v35/"
						if hero==&"xixifu":atlas_root="res://assets/heroes_handdrawn_v37/" if form else "res://assets/heroes_handdrawn_v36/"
						elif hero==&"sylphiette":atlas_root="res://assets/heroes_handdrawn_v37/sylphiette/"+("set/" if form else "normal/")
						elif hero==&"ilyua" and form:atlas_root="res://assets/heroes_handdrawn_v37/ilyua/set/"
						elif hero==&"ilyua" and not form:atlas_root="res://assets/heroes_handdrawn_v37/ilyua/normal/"
						check(texture.atlas.resource_path.begins_with(atlas_root) and texture.region.size==Vector2(448,448),"runtime uses current atlas and cell")
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
	print("HERO_CONSISTENCY_V35 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)

func transition_checks(art:SpriteFrames)->void:
	actor.hp=maxf(1,actor.hp);actor.extraction_pose=&"";actor._hurt_timer=0;actor._flash=0;actor.firing=false;actor._swing_timer=0;actor._cast_timer=0;actor._holy_pose_left=0
	var previous_scale:=actor._sprite.scale;var previous_position:=actor._sprite.position
	for index in 8:
		actor.aim_direction=Vector2.DOWN.rotated(index*PI/4)
		var direction:=RoomHeroArt.direction_name(actor.aim_direction)
		actor.velocity=Vector2.ZERO;actor._update_animation()
		check(actor._sprite.animation==StringName("idle_"+direction),"idle uses the same facing as movement")
		actor.velocity=actor.aim_direction*180;actor._update_animation()
		check(actor._sprite.animation==StringName("walk_"+direction),"start selects matching authored moving body")
		for frame in 4:
			actor._sprite.set_frame_and_progress(frame,0);RoomHeroArt.align(actor._sprite)
			check(actor._sprite.scale.is_equal_approx(previous_scale) and actor._sprite.position.is_equal_approx(previous_position),"per-frame bounds cannot scale or sway the actor")
		actor.velocity=Vector2.ZERO;actor._update_animation()
		check(actor._sprite.animation==StringName("idle_"+direction) and actor._sprite.frame==0,"stopping returns to stable same-direction ready")
	# Hurt must set its own facing instead of inheriting the prior eight-way flip.
	for face:int in [-1,1]:
		actor.facing=face;actor._sprite.flip_h=face<0;actor._hurt_timer=.3;actor._flash=.2;actor._update_animation()
		check(actor._sprite.animation==&"hurt" and actor._sprite.flip_h==(face>0),"hurt has correct authored-side mirroring")
		actor._hurt_timer=0;actor._flash=0
		actor.extraction_pose=&"prayer";actor._update_animation()
		check(actor._sprite.animation==&"prayer" and actor._sprite.flip_h==(face>0),"extraction uses explicit utility source side")
		actor.extraction_pose=&""
	actor.velocity=Vector2.ZERO;actor._update_animation()

func decoy_checks(hero:StringName,art:SpriteFrames)->void:
	if hero not in [&"ilyua",&"sylphiette"]:return
	var decoy:Node=IlyuaDecoy.new() if hero==&"ilyua" else HolyDecoy.new()
	main.add_child(decoy);decoy.set_physics_process(false)
	var visual:Sprite2D
	for child in decoy.get_children():
		if child is Sprite2D:visual=child;break
	check(visual!=null,"both ordinary and legendary decoys use current hero art")
	if visual!=null:
		var retained:Texture2D=visual.texture
		check(retained==art.get_frame_texture(&"idle_s",0),"decoy uses exact current body/outfit snapshot")
		var original:=bool(art.get_meta("set_form"))
		GameState.legendary_looks[str(hero)]={"set":not original};HanddrawnHeroArt.clear();HanddrawnHeroArt.frames(not original,hero)
		check(visual.texture==retained,"later costume changes do not replace a living decoy snapshot")
		GameState.legendary_looks[str(hero)]={"set":original}
	decoy.queue_free();await frames(2)
