extends "res://tests/inventory_v17.gd"
func run()->void:
	if RoomSceneWhole.definition("forest_clearing_v03").is_empty():
		print("ROOM_SCENE_WHOLE_V45 SKIP: trial disabled; use room_scene_static_v45");get_tree().quit(0);return
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/test-userdata/"):
		get_tree().quit(2);return
	AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=false
	await begin(&"sylphiette")
	main.room_prefetch.set_process(false);main.room_prefetch.clear()
	var art:RoomSceneArtwork=main.level.illustration
	art.set_process(false)
	var whole:RoomSceneWhole=art.scene_whole
	check(is_instance_valid(whole.sprite) and whole.textures.size()==8,"real initial room uses eight whole frames")
	check(art.scene_life.entries.is_empty(),"local animation not double drawn")
	check(RoomSceneWhole.texture_paths("forest_clearing_v03").size()==9,"prefetch includes eight frames and static wall layer")
	check(art.background_planes.size()==1 and art.ground_planes.size()==2,"whole ground and independent walls")
	check(art.gates.size()==4,"four independent gate sprites retained")
	var original_phase:float=main.level.door_phase
	main.level.door_phase=.75;art.refresh_gates()
	var sides:={"north":Vector2i.UP,"east":Vector2i.RIGHT,"south":Vector2i.DOWN,"west":Vector2i.LEFT}
	for side:String in art.gates:
		check(is_equal_approx(art.gates[side].modulate.a,.25 if main.level.door_directions.has(sides[side]) else 1.0),"gate phase retained "+side)
	main.level.door_phase=original_phase;art.refresh_gates()
	check(whole.sprite.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"smooth hand drawn sampling")
	var bounds:=art.camera_bounds()
	check(bounds.is_equal_approx(art.global_transform*art.frame_rect()),"full native canvas keeps camera extent")
	var geometry:=JSON.stringify(main.level.record.terrain_layout)
	var rng_state:int=Rng.stream().state
	for i in 8:
		whole.age=i/6.0+.0001;whole.update(0,false,false)
		check(whole.sprite.texture==whole.textures[i],"frame advances "+str(i))
	whole.age=8.0/6.0+.0001;whole.update(0,false,false)
	check(whole.sprite.texture==whole.textures[0],"frame sequence loops")
	var before:=whole.age
	whole.update(.5,true,true);check(whole.age==before and whole.sprite.texture==whole.textures[0],"reduced motion freezes with fixed frame")
	main.level.prefetching=true;art._process(.5);check(whole.age==before,"prefetch freeze");main.level.prefetching=false
	var screen:=Control.new();add_child(screen);UIFlow.push_screen(screen)
	art._process(.5);check(whole.age==before,"UI freeze");UIFlow.pop_screen(screen);screen.queue_free()
	TransitionLayer.busy=true;art._process(.5);check(whole.age==before,"transition freeze");TransitionLayer.busy=false
	get_tree().paused=true;art._process(.5);check(whole.age==before,"pause freeze");get_tree().paused=false
	art.hide();art._process(.5);check(whole.age==before,"hidden room freeze");art.show()
	art._process(.25);check(is_equal_approx(whole.age,before+.25),"visible room resumes")
	art.apply_weather(.6,.8)
	for plane:Sprite2D in art.ground_planes:
		check(plane.material is ShaderMaterial,"weather material attached")
		check(is_equal_approx(float(plane.material.get_shader_parameter("wet_amount")),.8),"wet tint applied")
	check(bool(whole.sprite.material.get_shader_parameter("ground_plane")),"ground snow policy")
	check(not bool(art.ground_planes[1].material.get_shader_parameter("ground_plane")),"walls retain separate snow policy")
	check(geometry==JSON.stringify(main.level.record.terrain_layout) and rng_state==Rng.stream().state,"layout and gameplay RNG unchanged")
	var children:=art.get_child_count()
	for i in 6:
		art.configure("forest_clearing_v03")
		check(art.get_child_count()==children and art.scene_whole.textures.size()==8,"bounded reload "+str(i))
		await frames(1)
	art.configure("missing_scene")
	check(art.scene_whole.textures.is_empty() and not is_instance_valid(art.scene_whole.sprite),"leaving clears whole-map references")
	art.configure("altar_moonwell_v01")
	check(art.scene_whole.textures.is_empty() and not art.background_planes.is_empty(),"unconfigured rooms retain original planes")
	art.configure("forest_clearing_v03")
	check(art.camera_bounds().is_equal_approx(bounds),"return preserves bounds")
	await frames(12)
	await settle_actor();AudioManager.shutdown();await frames()
	print("ROOM_SCENE_WHOLE_V45 checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
