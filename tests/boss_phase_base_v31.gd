extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v31-boss-pressure/"
var report:Dictionary={"arenas":[],"skills":[],"phases":[]}
func seconds(value:float)->void:await get_tree().create_timer(value,true,false,true).timeout
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);SaveService.data.reduced_motion=true;TransitionLayer.boot_played=true
	await begin(&"sylphiette");main.process_mode=Node.PROCESS_MODE_PAUSABLE
	await clear_world()
	if "edges" in OS.get_cmdline_user_args():
		await edge_checks();await clear_world();await settle_actor();await seconds(.1);AudioManager.shutdown();await seconds(.25)
		print("BOSS_EDGES_V30 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0);return
	if "clocks" in OS.get_cmdline_user_args():
		await stage_checks();await clear_world();await settle_actor();await seconds(.1);AudioManager.shutdown();await seconds(.25)
		print("BOSS_CLOCKS_V30 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0);return
	await arena_checks()
	await stage_checks()
	await edge_checks()
	await skill_checks()
	await ui_checks()
	await autonomous_checks()
	await clear_world();await settle_actor();await seconds(.1);AudioManager.shutdown();await seconds(.25)
	var file:=FileAccess.open(ROOT+"boss-checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BOSS_PHASES_V30 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
func clear_world()->void:
	for node in get_tree().get_nodes_in_group("bosses"):
		if node is RoomBoss and is_instance_valid(node._phase_ui):node._phase_ui.finish()
	for parent in [main.enemies_root,main.fx_root]:
		for node in parent.get_children():parent.remove_child(node);node.queue_free()
	main.director.boss=null;main.director.room_pending.clear();await frames(3)
func arena_record(id:String)->Dictionary:
	var chapter:=ChapterCatalog.NEXT if id in ["sephra","verena","nameless"] else ChapterCatalog.FIRST
	var pool:=RoomTemplatePool.new();var template:=pool.select(81030,"boss:"+id,"ruin" if chapter==ChapterCatalog.NEXT else "forest",chapter,false)
	return {"id":"0,0","kind":"boss","boss":id,"seed":81030,"chapter_id":str(chapter),"biome":"ruin" if chapter==ChapterCatalog.NEXT else "forest","terrain_layout":RoomTemplateCodec.to_layout(template),"delta":{},"doors":[],"cleared":false}
func arena_checks()->void:
	var objects:=[{"id":"rock","kind":"decor","collision_polygon_px":[[0,0],[20,0],[20,20]],"position_px":[100,100]},{"id":"lamp","kind":"light","collision_polygon_px":[[0,0],[10,0],[10,10]],"position_px":[180,100]},{"id":"rune","kind":"decor","position_px":[200,200]}]
	var copy:=objects.duplicate(true);var filtered:=BossArenaPolicy.objects(objects)
	check(objects==copy,"arena filtering preserves authored source")
	check(filtered.size()==2 and filtered[0].id=="lamp" and filtered[0].collision_polygon_px.is_empty(),"lights retained without collision; solid decor removed")
	for id:String in BossPhaseRules.SKILLS:
		var data:=arena_record(id);var original:Dictionary=data.terrain_layout.duplicate(true)
		main.level.load_room(data)
		check(main.level.scene_polygons.is_empty() and main.level.obstacles.is_empty(),"arena has no decorative solids "+id)
		check(data.terrain_layout.get("props",[])==original.get("props",[]),"stored prop layout not filtered in place "+id)
		check(main.level.boundary_root.get_child_count()==4,"arena boundaries retained "+id)
		report.arenas.append({"boss":id,"solids":main.level.scene_polygons.size(),"props":main.level.props_root.get_child_count(),"lights":main.level.decor_root.get_children().filter(func(n:Node)->bool:return n is RoomLightProp).size()})
		await frames()
func spawn(id:String)->RoomBoss:
	await clear_world();main.level.load_room(arena_record(id));actor.global_position=main.level.bounds().get_center()+Vector2(130,0);actor._invuln=10000
	var boss:RoomBoss=CityBoss.new() if id in ["sephra","verena","nameless"] else RoomBoss.new()
	boss.configure(StringName(id));boss.room=main.level;boss.setup(actor,main.level,1,1,1);boss.fx_root=main.fx_root;boss.director=main.director;boss.position=main.level.bounds().get_center()-Vector2(60,0)
	main.enemies_root.add_child(boss);main.director.boss=boss;main.director.phase=WaveDirector.Phase.FIGHT;boss.set_physics_process(false)
	return boss
func stage_checks()->void:
	for id:String in BossPhaseRules.SKILLS:
		var boss:RoomBoss=await spawn(id);var cutoffs:=BossPhaseRules.thresholds(StringName(id))
		for stage in range(1,cutoffs.size()):
			var ratio:float=(float(cutoffs[stage-1])+float(cutoffs[stage]))*.5
			boss.hp=boss.max_hp*ratio;boss.phase=boss.phase_for_health();boss.phase_seen=boss.phase;boss._update_visual()
			var health:=boss.phase_health()
			check(int(health.phase)==stage and boss.phase==stage,"HUD and AI share threshold "+id+str(stage))
			var art:=BossStageArt.frames(StringName(id),stage)
			# Missing art is a genuine incomplete item, never a fallback success.
			check(art.get_meta("boss_stage_art",false),"independent stage atlas "+id+str(stage))
			for skill:String in BossPhaseRules.skills(StringName(id),stage):
				for release in [false,true]:check(art.has_animation(BossPhaseRules.action(StringName(id),skill,release)),"direct action hit "+id+str(stage)+skill+str(release))
			if stage>1:
				GameState.mp=0;GameState.set_process(true);actor.set_physics_process(true);actor.movement_override=Vector2.RIGHT;main.director.set_process(true);main.set_process(true);boss.set_physics_process(true)
				var skill:=GameState.skill_for_slot(0);GameState.skill_cooldowns_by_id[skill]=7.0
				var world_minutes:float=main.world_clock.minutes
				var cooldown:float=boss.room_cooldown
				var pos:=actor.global_position;var pressure:float=main.director.room_pressure_elapsed;var mp:=GameState.mp
				boss._begin_phase_presentation();await frames(2)
				check(get_tree().paused and is_instance_valid(boss._phase_ui),"phase pause lease "+id)
				var hp:=boss.hp;boss.take_damage(10);check(boss.hp==hp,"no damage during cut-in "+id)
				await frames(6)
				check(actor.global_position==pos,"position frozen "+id)
				check(pressure==main.director.room_pressure_elapsed,"pressure frozen "+id)
				check(mp==GameState.mp,"MP frozen "+id)
				check(GameState.skill_cooldowns_by_id[skill]==7.0,"skill cooldown frozen "+id)
				check(main.world_clock.minutes==world_minutes,"world clock frozen "+id)
				check(boss.room_cooldown==1.5 and cooldown>=0,"boss cooldown frozen "+id)
				boss._phase_ui.finish();boss.set_physics_process(false);main.set_process(false);GameState.set_process(false);actor.set_physics_process(false);actor.movement_override=Vector2.ZERO;main.director.set_process(false);await frames(2)
				check(not get_tree().paused and boss.phase_guard_left>0,"phase releases lease and adds grace "+id)
				report.phases.append({"boss":id,"phase":stage,"duration":.6})
		var runtime:=main.expedition
		var fields:=runtime._fields(boss);fields["phase_presenting"]=true
		runtime._apply_fields(boss,fields)
		check(not boss.phase_presenting and boss.phase_seen==boss.phase_for_health(),"restore skips interrupted presentation "+id)
		if boss is CityBoss:
			fields.erase("boss_pattern_revision");fields["timeline"]=[{"type":"repeat_pattern","left":.1}]
			runtime._apply_fields(boss,fields)
			check(boss.timeline.is_empty() and boss.recovery>=1,"legacy attacks cancelled "+id)
func skill_checks()->void:
	for id:String in ["sephra","verena","nameless"]:
		var boss:CityBoss=await spawn(id)
		boss.phase=BossPhaseRules.thresholds(StringName(id)).size()-1;boss.hp=boss.max_hp*.15;boss.phase_seen=boss.phase;boss.phase_rotation_seen=boss.phase
		for skill:String in BossPhaseRules.SKILLS[id]:
			boss.cancel_attacks(true);boss.pattern=skill;boss.room_aim=Vector2.RIGHT;boss.room_target=actor.global_position;boss.pattern_last_time=0
			boss.plan_pattern(skill);boss.attack_id=&"windup"
			check(not boss.timeline.is_empty(),"skill schedules commands "+id+skill)
			var maximum:=boss.pattern_last_time+5.5;var bullets:=0
			# Physics-enabled actors, projectiles and destructible units; controlled scheduler clock.
			for frame in ceili(maximum*60):
				boss._advance_commands(1.0/60);boss.recovery=maxf(0,boss.recovery-1.0/60)
				bullets=maxi(bullets,boss._owned_bullets.size());await get_tree().physics_frame
			check(not boss.main_pending(),"skill completes without infinite timeline "+id+skill)
			check(bullets<=boss.bullet_budget(),"legal bullet budget "+id+skill)
			report.skills.append({"boss":id,"skill":skill,"max_owned_bullets":bullets})
			for construct in boss._constructs():construct.retire()
			await frames()

func edge_checks()->void:
	for id:String in BossPhaseRules.SKILLS:
		var boss:RoomBoss=await spawn(id);var cuts:=BossPhaseRules.thresholds(StringName(id))
		for index in range(1,cuts.size()-1):check(BossPhaseRules.phase_at(StringName(id),float(cuts[index]))==index+1,"exact phase threshold "+id+str(index))
		check(BossPhaseRules.phase_at(StringName(id),.01)==cuts.size()-1,"burst damage can skip directly to final phase "+id)
		boss.hp=boss.max_hp*.1;boss.phase_guard_left=0;boss._physics_process(1.0/60)
		check(boss.phase==cuts.size()-1 and boss.phase_presenting and get_tree().paused,"live threshold starts one immediate final-form presentation "+id)
		var ui:BossPhaseUI=boss._phase_ui
		check(ui._old_ghost.sprite_frames==BossStageArt.frames(StringName(id),1),"burst crossfade starts from the actual prior form "+id)
		check(is_equal_approx(ui.duration,.6),"reduced motion uses short presentation "+id)
		check(is_equal_approx(ui._ghost.position.y-boss.position.y+112*ui._ghost.scale.y,boss.body_size.y*.5),"phase model shares grounded anchor "+id)
		var wait_start:=Time.get_ticks_msec()
		while ui.elapsed<.22 and Time.get_ticks_msec()-wait_start<3000:await get_tree().process_frame
		ui._released=true
		var accept:=InputEventAction.new();accept.action=&"ui_accept";accept.pressed=true;accept.strength=1
		ui._input(accept);await frames()
		check(not boss.phase_presenting and not get_tree().paused,"keyboard/controller action skips and releases pause "+id)
		boss.phase_guard_left=0;boss.take_damage(boss.hp+boss.max_hp);await frames()
		check((not is_instance_valid(boss) or boss._dead) and not get_tree().paused,"lethal damage never locks a cut-in "+id)
	SaveService.data.reduced_motion=false
	var boss:RoomBoss=await spawn("sephra");boss.hp=boss.max_hp*.25;boss._physics_process(1.0/60)
	check(is_equal_approx(boss._phase_ui.duration,1.5),"normal presentation lasts 1.5 seconds")
	boss._phase_ui._skip.pressed.emit();await frames();check(not get_tree().paused,"touch/button skip releases pause")
	var warning:=BossPatternWarning.create(main.fx_root,main.level,{"at":Vector2(100,100),"end":Vector2(500,100),"shape":"line","width":120,"safe_corridor":true},1.2,Color.WHITE)
	var threats:={"enemies":[],"bullets":[],"hazards":[],"warnings":[warning]}
	check(main.gm_pilot._danger_at(Vector2(250,100),threats)<main.gm_pilot._danger_at(Vector2(250,240),threats),"Bot follows visible safe corridor instead of evading it")
	warning.queue_free()
	SaveService.data.reduced_motion=true

func ui_checks()->void:
	var bar:BossBar=main.boss_bar
	for extent in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(5)
		var viewport:=get_viewport().get_visible_rect()
		for id:String in BossPhaseRules.SKILLS:
			bar._on_boss_started(StringName(id));bar._fit_layout();await frames()
			check(viewport.encloses(bar._panel.get_global_rect()),"Boss HUD inside viewport "+str(extent)+id)
			check(bar._icon.custom_minimum_size.x>=40 and bar._name_art.custom_minimum_size.y>=36,"larger portrait and same entrance title "+id)
			check(bar._name_art.texture==BossEntranceArt.pack(id).title,"title exact resource "+id)
	get_window().size=Vector2i(1280,720);await frames()
func autonomous_checks()->void:
	for id:String in ["sephra","verena","nameless"]:
		var boss:CityBoss=await spawn(id);boss.set_physics_process(true)
		var seen:Dictionary={}
		for stage in range(1,boss.max_phase+1):
			var cuts:=BossPhaseRules.thresholds(StringName(id));boss.hp=boss.max_hp*(float(cuts[stage-1])+float(cuts[stage]))*.5
			for frame in 2700:
				# Full physics/AI enabled; a scripted moving target exercises lock/release and recovery.
				actor.global_position=main.level.nearest_clear(main.level.bounds().get_center()+Vector2.from_angle(frame*.012)*130,12)
				if not boss.pattern.is_empty():seen[boss.pattern]=true
				await get_tree().physics_frame
		check(seen.size()>=3,"autonomous boss uses multiple skills "+id)
		report["autonomous_"+id]=seen.keys()
