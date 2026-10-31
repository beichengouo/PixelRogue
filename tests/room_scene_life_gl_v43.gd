extends "res://tests/inventory_v17.gd"
## Bounded ABBA comparison in the same room and process; never captures images.
const REPORT:="E:/CodexWorkspace/PixelRogue/work/map-life-v43/performance.json"
func run()->void:
	if RoomSceneLife.definition("forest_clearing_v03").is_empty():
		print("ROOM_SCENE_LIFE_GL_V43 SKIP: trial disabled; use room_scene_static_v45");get_tree().quit(0);return
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/test-userdata/") or DisplayServer.get_name()=="headless":
		get_tree().quit(2);return
	get_window().mode=Window.MODE_WINDOWED;get_window().size=Vector2i(2560,1440)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	SaveService.data.reduced_motion=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true
	await begin(&"sylphiette")
	main.room_prefetch.set_process(false);main.room_prefetch.clear()
	await get_tree().create_timer(2.0).timeout
	check(get_window().size==Vector2i(2560,1440),"2K physical render")
	check(get_viewport().get_visible_rect().size==Vector2(1280,720),"2x logical canvas")
	var art:RoomSceneArtwork=main.level.illustration
	check(art.scene_life.entries.size()==8,"eight animation patches")
	var disabled:Array[float]=[];var enabled:Array[float]=[]
	var cpu_disabled:Array[float]=[];var cpu_enabled:Array[float]=[]
	var draw_disabled:Array[float]=[];var draw_enabled:Array[float]=[]
	var phases:Array[Dictionary]=[]
	# Compile/warm the patch material and both draw paths before measurement.
	for active:bool in [false,true]:
		art.scene_life.enabled=active;art.scene_life.update(0,false,false)
		await get_tree().create_timer(1.0).timeout
	for active:bool in [false,true,true,false]:
		art.scene_life.enabled=active;art.scene_life.update(0,false,false)
		await get_tree().create_timer(1.1).timeout
		var samples:Array[float]=[];var cpu:Array[float]=[];var calls:Array[float]=[]
		for index in 600:
			var start:=Time.get_ticks_usec()
			await get_tree().process_frame
			samples.append(float(Time.get_ticks_usec()-start)/1000.0)
			cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if active:enabled.append_array(samples);cpu_enabled.append_array(cpu);draw_enabled.append_array(calls)
		else:disabled.append_array(samples);cpu_disabled.append_array(cpu);draw_disabled.append_array(calls)
		phases.append({"animated":active,"p95_ms":percentile(samples,.95),"process_p95_ms":percentile(cpu,.95),"draw_calls_median":percentile(calls,.5)})
	var difference:=percentile(enabled,.95)-percentile(disabled,.95)
	check(difference<=1.0,"animation P95 delta <= 1ms")
	var report:Dictionary={"checks":checks,"failures":failures,"physical":[2560,1440],"logical":[1280,720],"renderer":RenderingServer.get_video_adapter_name(),"samples_per_mode":enabled.size(),"sequence":"static,animated,animated,static","static_p95_ms":percentile(disabled,.95),"animated_p95_ms":percentile(enabled,.95),"p95_delta_ms":difference,"static_process_p95_ms":percentile(cpu_disabled,.95),"animated_process_p95_ms":percentile(cpu_enabled,.95),"static_draw_calls_median":percentile(draw_disabled,.5),"animated_draw_calls_median":percentile(draw_enabled,.5),"blocks":phases,"scope":"Isolated actual initial room, eight local patches, no enemies; not a crowded-combat performance claim."}
	var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"  "));file.close()
	else:check(false,"performance report writable")
	await settle_actor();AudioManager.shutdown();await frames()
	print("ROOM_SCENE_LIFE_GL_V43 checks=",checks," failures=",failures," p95_delta_ms=",difference)
	get_tree().quit(1 if failures else 0)

func percentile(values:Array[float],fraction:float)->float:
	var sorted:=values.duplicate();sorted.sort()
	return sorted[clampi(ceili(float(sorted.size())*fraction)-1,0,sorted.size()-1)] if not sorted.is_empty() else 0.0
