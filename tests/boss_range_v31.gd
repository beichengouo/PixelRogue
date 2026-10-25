extends "res://tests/boss_phase_base_v31.gd"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	await begin(&"ilyua");await clear_world()
	var guard:=await spawn("sephra") as CityBoss
	var box:=main.level.bounds().grow(-36)
	guard.global_position=box.get_center()-Vector2(160,0);actor.global_position=guard.global_position+Vector2(300,0)
	guard.room_aim=Vector2.RIGHT;guard.room_target=actor.global_position;guard.pattern="归城突进";guard.plan_pattern(guard.pattern)
	var lock:Dictionary=guard.timeline.filter(func(event:Dictionary)->bool:return event.type=="lock_dash")[0]
	guard._execute(lock)
	var dash:Dictionary=guard.timeline.filter(func(event:Dictionary)->bool:return event.type=="city_dash")[0]
	check(float(dash.warning)>=1.0,"dash retains full one-second locked warning")
	check(AttackGeometry.contains(dash,actor.global_position),"dash warning covers stationary target and finishing slash")
	check((dash.destination as Vector2).distance_to(guard.global_position)>210,"dash is no longer cut off at 210 pixels")
	check((dash.destination as Vector2).distance_to(actor.global_position)>=30,"dash stops before the locked target instead of overshooting")
	guard._execute(dash);check(guard.dash_left>.7,"actual dash duration supports configured reach")
	guard.cancel_attacks(true)
	var core:=await spawn("nameless") as CityBoss
	box=main.level.bounds().grow(-36);core.global_position=Vector2(box.end.x-24,box.get_center().y);actor.global_position=Vector2(box.position.x+24,box.get_center().y)
	core.room_target=actor.global_position;core.room_aim=Vector2.LEFT;core.plan_pattern("星轨依次扫射")
	var beams:=core.timeline.filter(func(event:Dictionary)->bool:return event.type=="city_beam")
	check(beams.size()==38,"beam sequence and count retained")
	for event:Dictionary in beams:
		check(main.level.bounds().has_point(event.end) and float(event.warning)>=1.2,"full-room beam endpoint and warning remain legal")
	check(beams.any(func(event:Dictionary)->bool:return AttackGeometry.contains(event,actor.global_position)),"full-room beam reaches a distant visible player")
	core.cancel_attacks(true);core.plan_pattern("交错星环")
	var rings:=core.timeline.filter(func(event:Dictionary)->bool:return event.type=="city_ring")
	check(rings.size()==3,"ring salvo count retained")
	check(absf((rings[0].dir as Vector2).angle_to(rings[2].dir))>float(rings[0].opening),"successive safe gaps require repositioning")
	for event:Dictionary in rings:check(float(event.opening)==1.3 and float(event.warning)>=1.2,"ring openings and dodge warning retained")
	var king:=await spawn("king")
	box=main.level.bounds().grow(-36);king.global_position=box.get_center()-Vector2(180,0);actor.global_position=king.global_position+Vector2(360,0)
	king.room_action=1;king.room_cooldown=0;king.think(0)
	check(king.pattern=="断骨飞矛","king selects a ranged skill when sword is out of range")
	var spear_lock:Dictionary=king.timeline.filter(func(event:Dictionary)->bool:return event.type=="lock_spear")[0]
	actor.global_position+=Vector2(0,72);king._execute(spear_lock)
	var spear:Dictionary=king.timeline.filter(func(event:Dictionary)->bool:return event.type=="spear")[0]
	check((spear.dir as Vector2).is_equal_approx((actor.global_position-king.global_position).normalized()) and float(spear.warning)>=.85,"each spear locks before its own full warning")
	var mage:=await spawn("mage")
	mage.global_position=box.get_center()-Vector2(180,0);actor.global_position=mage.global_position+Vector2(360,0)
	mage.room_aim=Vector2.RIGHT;mage.room_target=actor.global_position;mage._mage_pattern("晶刺突生")
	check(mage.timeline.any(func(event:Dictionary)->bool:return event.type=="circle" and AttackGeometry.contains(event,actor.global_position)),"distant crystal eruption threatens its marked target")
	await clear_world();await settle_actor();AudioManager.shutdown();await seconds(.25)
	print("BOSS_RANGE_V31 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
