extends "res://tests/inventory_v17.gd"
## Isolated 2560x1440 OpenGL battle-room render probe for all Boss stages.
## Captures are review evidence in the E: QA workspace, never player saves.
const OUTPUT := "E:/CodexWorkspace/PixelRogue/work/v40-boss-gl-qa/"
const STAGES := {"king":2,"mage":2,"tide":3,"sephra":2,"verena":2,"nameless":3}
var report:Array[Dictionary]=[]
var preview_v41:=false
var live_ai:=false
var output_root:=OUTPUT
var stage_filter:=""

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/test-userdata/"):
		push_error("Boss GL probe requires isolated E: user data")
		get_tree().quit(2)
		return
	if DisplayServer.get_name()=="headless":
		push_error("Boss GL probe requires a real windowed renderer")
		get_tree().quit(2)
		return
	preview_v41=OS.get_cmdline_user_args().has("preview_v41")
	live_ai=OS.get_cmdline_user_args().has("live_ai")
	for value:String in OS.get_cmdline_user_args():
		if value.begins_with("stage="):stage_filter=value.trim_prefix("stage=")
	output_root="E:/CodexWorkspace/PixelRogue/work/v41-boss-gl-qa/" if preview_v41 else OUTPUT
	DirAccess.make_dir_recursive_absolute(output_root+"captures/")
	get_window().mode=Window.MODE_WINDOWED
	get_window().size=Vector2i(2560,1440)
	SaveService.data.reduced_motion=false
	SaveService.data.control_setup_done=true
	AchievementTracker.set_process(false)
	TransitionLayer.boot_played=true
	await frames(12)
	# The game renders a 1280x720 logical canvas at 2x into a 2560x1440 GL window.
	check(get_window().size==Vector2i(2560,1440),"2K physical GL window")
	check(get_viewport().get_visible_rect().size==Vector2(1280,720),"expected 2x logical canvas")
	await begin(&"sylphiette")
	for id:String in STAGES:
		for phase:int in range(1,int(STAGES[id])+1):
			if not stage_filter.is_empty() and stage_filter!="%s_%d"%[id,phase]:continue
			await _stage(id,phase)
	await _clear_bosses()
	await settle_actor()
	AudioManager.shutdown()
	var path:=output_root+("report_"+stage_filter+".json" if not stage_filter.is_empty() else "report.json")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"preview_v41":preview_v41,"live_ai":live_ai,"stage_filter":stage_filter,"window_pixels":[get_window().size.x,get_window().size.y],"logical_viewport":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],"display_server":DisplayServer.get_name(),"stages":report},"\t"))
	file.close()
	print("BOSS_REDRAW_GL checks=",checks," failures=",failures," report=",path)
	get_tree().quit(1 if failures else 0)

func _record(id:String)->Dictionary:
	var chapter:=ChapterCatalog.NEXT if id in ["sephra","verena","nameless"] else ChapterCatalog.FIRST
	var pool:=RoomTemplatePool.new()
	var template:=pool.select(81030,"boss:"+id,"ruin" if chapter==ChapterCatalog.NEXT else "forest",chapter,false)
	return {"id":"0,0","kind":"boss","boss":id,"seed":81030,"chapter_id":str(chapter),"biome":"ruin" if chapter==ChapterCatalog.NEXT else "forest","terrain_layout":RoomTemplateCodec.to_layout(template),"delta":{},"doors":[],"cleared":false}

func _clear_bosses()->void:
	for parent in [main.enemies_root,main.fx_root]:
		for node in parent.get_children():
			parent.remove_child(node)
			node.queue_free()
	main.director.boss=null
	await frames(3)

func _stage(id:String,phase:int)->void:
	await _clear_bosses()
	main.level.load_room(_record(id))
	var center:=main.level.bounds().get_center()
	actor.global_position=center+Vector2(130,0)
	actor._invuln=10000
	var boss:RoomBoss=CityBoss.new() if id in ["sephra","verena","nameless"] else RoomBoss.new()
	boss.configure(StringName(id))
	boss.room=main.level
	boss.setup(actor,main.level,1,1,1)
	boss.fx_root=main.fx_root
	boss.director=main.director
	boss.position=center-Vector2(60,0)
	main.enemies_root.add_child(boss)
	main.director.boss=boss
	main.director.phase=WaveDirector.Phase.FIGHT
	boss.set_physics_process(false)
	boss.phase=phase
	boss.phase_seen=phase
	var cutoffs:=BossPhaseRules.thresholds(StringName(id))
	boss.hp=boss.max_hp*(float(cutoffs[phase-1])+float(cutoffs[phase]))*.5
	var meta:=BossStageArt.info(StringName(id),phase)
	if preview_v41:
		meta=JSON.parse_string(FileAccess.get_file_as_string("res://assets/boss_stages_v41/%s_%d.json"%[id,phase]))
		boss.visual.sprite_frames=_candidate_frames(id,phase,meta)
	else:boss.visual.sprite_frames=BossStageArt.frames(StringName(id),phase)
	boss.visual.play(&"idle")
	PixelBossArt.align(boss.visual,StringName(id),boss.body_size)
	main.boss_bar._on_boss_started(StringName(id))
	main.camera.snap_to_target()
	await frames(10)
	var skills:Array=BossPhaseRules.skills(StringName(id),phase)
	var first_skill:String=skills[0] if not skills.is_empty() else ""
	var skill_action:=BossPhaseRules.action(StringName(id),first_skill,true) if not first_skill.is_empty() else &"release"
	var entry:Dictionary={"id":id,"phase":phase,"skill":first_skill,"action":str(skill_action),"captures":[],"mid_captures":[]}
	for action:StringName in [&"idle",skill_action]:
		check(boss.visual.sprite_frames.has_animation(action),"actual battle action "+id+str(phase)+str(action))
		if not boss.visual.sprite_frames.has_animation(action):continue
		boss.visual.play(action)
		boss.visual.frame=1 if boss.visual.sprite_frames.get_frame_count(action)>1 else 0
		await frames(4)
		var filename:="%s_%d_%s.png"%[id,phase,str(action)]
		await _capture(filename)
		entry.captures.append(filename)
	if preview_v41:
		for value in meta.skill_transition_coverage.covered:
			var skill_index:=int(value)
			var mid:="skill_%d_mid"%skill_index
			var action:=StringName("skill_%d_windup"%skill_index)
			var sequence:Array=meta.animations[str(action)].pose_sequence
			var frame_index:=sequence.find(mid)
			check(frame_index>=0,id+str(phase)+"/"+mid+" mid pose present")
			if frame_index<0:continue
			boss.visual.play(action)
			boss.visual.frame=frame_index
			await frames(4)
			var filename:="%s_%d_%s.png"%[id,phase,mid]
			await _capture(filename)
			entry.mid_captures.append(filename)
	entry["atlas_cell"]=meta.cell
	entry["scale"]=boss.visual.scale.x
	entry["world_height"]=float(meta.body_height)*boss.visual.scale.x
	entry["boss_world_position"]=[boss.global_position.x,boss.global_position.y]
	entry["sprite_local_position"]=[boss.visual.position.x,boss.visual.position.y]
	if live_ai:
		await _live_ai(boss,id,phase,entry)
	report.append(entry)

func _live_ai(boss:RoomBoss,id:String,phase:int,entry:Dictionary)->void:
	# Must use the canonical runtime loader: RoomBoss refreshes SpriteFrames each
	# physics tick. V41 manual preview intentionally keeps physics paused.
	check(not preview_v41,"live AI uses formally switched BossStageArt")
	if preview_v41:return
	boss.cancel_attacks(true)
	boss._visual_release_left=0
	boss.pattern=""
	boss.visual.play(&"idle")
	boss.visual.frame=0
	boss.room_cooldown=.05
	boss.set_physics_process(true)
	var seen:Dictionary={}
	var matched_release:=false
	var seen_mid:=false
	var stage_meta:=BossStageArt.info(StringName(id),phase)
	for tick in 600:
		await get_tree().physics_frame
		var action:=str(boss.visual.animation)
		if not action.begins_with("skill_"):continue
		var action_spec:Dictionary=stage_meta.animations.get(action,{})
		var pose_sequence:Array=action_spec.get("pose_sequence",[])
		var frame_index:int=boss.visual.frame
		if not seen_mid and frame_index>=0 and frame_index<pose_sequence.size() and str(pose_sequence[frame_index]).ends_with("_mid"):
			seen_mid=true
			var mid_filename:="%s_%d_live_mid.png"%[id,phase]
			await _capture(mid_filename)
			entry["live_mid_capture"]=mid_filename
		if seen.has(action):continue
		seen[action]=tick
		var filename:="%s_%d_live_%s.png"%[id,phase,action]
		await _capture(filename)
		if action.ends_with("_release") and seen.has(action.trim_suffix("_release")+"_windup"):
			matched_release=true
			break
	boss.set_physics_process(false)
	check(seen.keys().any(func(action:String)->bool:return action.ends_with("_windup")),id+str(phase)+" live windup")
	check(seen_mid,id+str(phase)+" live unique mid pose")
	check(matched_release,id+str(phase)+" live matching release")
	entry["live_actions"]=seen

func _capture(filename:String)->void:
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	check(image.get_size()==Vector2i(2560,1440),"2K rendered capture "+filename)
	var error:=image.save_png(output_root+"captures/"+filename)
	check(error==OK,"saved GL review image "+filename)

func _candidate_frames(id:String,phase:int,meta:Dictionary)->SpriteFrames:
	var image:=Image.load_from_file("res://assets/boss_stages_v41/%s_%d.png"%[id,phase])
	var texture:=ImageTexture.create_from_image(image)
	var result:=SpriteFrames.new()
	result.remove_animation(&"default")
	var poses:Dictionary={}
	for pose:String in meta.poses:
		var item:Dictionary=meta.poses[pose]
		var tile:=AtlasTexture.new()
		tile.atlas=texture
		tile.region=Rect2(int(item.column)*int(meta.cell),int(item.row)*int(meta.cell),int(meta.cell),int(meta.cell))
		tile.filter_clip=true
		poses[pose]=tile
	for action:String in meta.animations:
		var spec:Dictionary=meta.animations[action]
		result.add_animation(action)
		result.set_animation_speed(action,float(spec.fps))
		result.set_animation_loop(action,action in ["idle","move"])
		for pose:String in spec.pose_sequence:result.add_frame(action,poses[pose])
	result.set_meta("boss_stage_art",true)
	result.set_meta("body_height",float(meta.body_height))
	result.set_meta("cell",int(meta.cell))
	result.set_meta("foot",Vector2(meta.foot[0],meta.foot[1]))
	return result
