extends "res://tests/inventory_v17.gd"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/test-userdata/"):
		get_tree().quit(2);return
	AchievementTracker.set_process(false);TransitionLayer.boot_played=true
	await begin(&"sylphiette")
	main.room_prefetch.set_process(false);main.room_prefetch.clear()
	var art:RoomSceneArtwork=main.level.illustration
	art.set_process(false)
	check(art.scene_whole.textures.is_empty(),"whole-map trial disabled")
	check(art.scene_life.entries.is_empty(),"local vegetation trial disabled")
	check(RoomSceneWhole.texture_paths("forest_clearing_v03").is_empty(),"no whole textures prefetched")
	check(RoomSceneLife.texture_paths("forest_clearing_v03").is_empty(),"no local textures prefetched")
	check(art.background_planes.size()==9,"original nine background tiles restored")
	check(art.ground_planes.size()==17,"original background and wall layers restored")
	check(art.gates.size()==4,"original independent gates retained")
	for node:Sprite2D in art.ground_planes:
		check(node.texture.resource_path.begins_with("res://assets/room_illustrated/forest_clearing_v03/"),"original source texture")
	var bounds:=art.camera_bounds()
	var geometry:=JSON.stringify(main.level.record.terrain_layout)
	art._process(2.0)
	check(not is_instance_valid(art.scene_whole.sprite) and art.scene_life.entries.is_empty(),"no plant animation rendered")
	art.configure("forest_clearing_v03")
	check(art.camera_bounds().is_equal_approx(bounds),"bounds unchanged on reentry")
	check(JSON.stringify(main.level.record.terrain_layout)==geometry,"layout data unchanged")
	await settle_actor();AudioManager.shutdown();await frames()
	print("ROOM_SCENE_STATIC_V45 checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
