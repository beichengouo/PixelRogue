extends "res://tests/inventory_v17.gd"
## Exercises the real initial-room renderer with isolated user data only.
func run()->void:
	if RoomSceneLife.definition("forest_clearing_v03").is_empty():
		print("ROOM_SCENE_LIFE_V43 SKIP: trial disabled; use room_scene_static_v45");get_tree().quit(0);return
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/test-userdata/"):
		get_tree().quit(2);return
	AchievementTracker.set_process(false);TransitionLayer.boot_played=true
	SaveService.data.reduced_motion=false
	await begin(&"sylphiette")
	var artwork:RoomSceneArtwork=main.level.illustration
	check(str(artwork.data.get("id",""))=="forest_clearing_v03","actual first chapter start illustration")
	artwork.set_process(false)
	var count:=int(OS.get_environment("PIXELROGUE_LIFE_EXPECTED"))
	if count==0:count=8
	check(artwork.scene_life.entries.size()==count,"all admitted patch pairs loaded")
	check(RoomSceneLife.texture_paths("forest_clearing_v03").size()==count*2,"prefetch includes every atlas and repair")
	var bounds:Rect2=artwork.camera_bounds()
	var geometry:=JSON.stringify(main.level.record.terrain_layout)
	var life:RoomSceneLife=artwork.scene_life
	var rng_state:int=Rng.stream().state
	for item:Dictionary in life.entries:
		check(item.sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"map pixel sampling "+str(item.id))
		check(item.sprite.hframes==4 and item.sprite.vframes==2,"eight authored cells "+str(item.id))
		check(item.sprite.get_index()==item.repair.get_index()+1,"repair below moving leaves "+str(item.id))
		check(item.sprite.position==item.repair.position and item.sprite.scale==item.repair.scale,"registered repair and leaves "+str(item.id))
		for step in 8:
			life.age=float(step)/6.0+.0001;life.update(0,false,false)
			check(item.sprite.frame==posmod(step+int(item.phase),8),"forward frame "+str(item.id)+str(step))
		life.age=8.0/6.0+.0001;life.update(0,false,false)
		check(item.sprite.frame==int(item.phase),"last to first loop "+str(item.id))
	var before:float=life.age
	life.update(2.0,false,false);check(life.age==before,"explicit frozen clock")
	life.update(.2,true,true);check(life.age==before,"reduced motion freezes clock")
	for item:Dictionary in life.entries:check(item.sprite.frame==0,"reduced motion static cell")
	SaveService.data.reduced_motion=false
	main.level.prefetching=true;artwork._process(.5)
	check(life.age==before,"neighbor prefetch freezes clock")
	main.level.prefetching=false
	var screen:=Control.new();add_child(screen);UIFlow.push_screen(screen)
	artwork._process(.5);check(life.age==before,"UI screen freezes clock")
	UIFlow.pop_screen(screen);screen.queue_free()
	TransitionLayer.busy=true;artwork._process(.5)
	check(life.age==before,"transition freezes clock");TransitionLayer.busy=false
	get_tree().paused=true;artwork._process(.5)
	check(life.age==before,"pause freezes clock");get_tree().paused=false
	artwork.hide();artwork._process(.5)
	check(life.age==before,"hidden room freezes clock");artwork.show()
	artwork._process(.25);check(is_equal_approx(life.age,before+.25),"visible room resumes independent clock")
	artwork.apply_weather(.6,.8)
	for item:Dictionary in life.entries:
		check(is_equal_approx(float(item.sprite.material.get_shader_parameter("wet_amount")),.8),"leaves receive wet weather")
		check(is_equal_approx(float(item.repair.material.get_shader_parameter("wet_amount")),.8),"repair receives wet weather")
	life.enabled=false;life.update(0,false,false)
	for item:Dictionary in life.entries:check(not item.sprite.visible and not item.repair.visible,"atomic static fallback")
	check(bounds==artwork.camera_bounds(),"camera ignores animation bounds")
	check(geometry==JSON.stringify(main.level.record.terrain_layout),"gameplay layout unchanged")
	check(Rng.stream().state==rng_state,"visual clock does not consume gameplay random numbers")
	var invalid:=RoomSceneLife.definition("forest_clearing_v03").duplicate(true)
	for patch:Dictionary in invalid.patches:patch.atlas="missing-animation.png"
	var missing:=RoomSceneLife.new();var count_before:=artwork.get_child_count()
	missing.configure_data(artwork,invalid,RoomSceneLife.ROOT+"forest_clearing_v03/",{"background":artwork.background_plane,"walls":artwork.background_plane})
	check(missing.entries.is_empty() and artwork.get_child_count()==count_before,"missing atlas never installs repair")
	for patch:Dictionary in invalid.patches:patch.repair="missing-repair.png";patch.atlas=str(patch.id)+"_atlas.png"
	missing.configure_data(artwork,invalid,RoomSceneLife.ROOT+"forest_clearing_v03/",{"background":artwork.background_plane,"walls":artwork.background_plane})
	check(missing.entries.is_empty() and artwork.get_child_count()==count_before,"missing repair never installs moving leaves")
	life.enabled=true;life.update(0,false,false)
	var children:int=artwork.get_child_count()
	for index in 12:
		artwork.configure("forest_clearing_v03")
		check(artwork.scene_life.entries.size()==count and artwork.get_child_count()==children,"reload has bounded nodes "+str(index))
		await frames(1)
	artwork.configure("missing_scene")
	check(artwork.scene_life.entries.is_empty(),"unmapped scene clears runtime references")
	artwork.configure("forest_clearing_v03")
	check(artwork.camera_bounds()==bounds,"return restores camera")
	await settle_actor();AudioManager.shutdown();await frames()
	print("ROOM_SCENE_LIFE_V43 checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
