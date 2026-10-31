extends Node
var checks:=0
var failures:=0
const IDS:=["surveyor","carpenter","herbalist","minstrel"]
const VECTORS:=[Vector2.DOWN,Vector2(-1,1),Vector2.LEFT,Vector2(-1,-1),Vector2.UP,Vector2(1,-1),Vector2.RIGHT,Vector2(1,1)]
const DIRECTIONS:=["s","sw","w","nw","n","ne","e","se"]
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",why)
func ticks(n:=2)->void:
	for i in n:await get_tree().process_frame
func _ready()->void:call_deferred("run")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):
		push_error("Isolated E profile required");get_tree().quit(2);return
	AchievementTracker.set_process(false);GameState.set_process(false)
	for id:String in IDS:
		var art:=CampResidentArt.frames(id)
		var root:="res://assets/camp_npcs_handdrawn_v37/"+id+"/"
		var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root+"production.json"))
		check(bool(art.get_meta("handdrawn",false)) and str(art.get_meta("resident_id",""))==id,"new distinct resident resource "+id)
		check(art==CampResidentArt.frames(id),"resident frames cached")
		check(int(manifest.source_frames)==33 and int(manifest.clip_count)==12 and int(manifest.animation_count)==18,"complete source pose contract")
		check(art.get_animation_names().size()==18,"eight directions plus rest/talk")
		for asset:String in manifest.source_sha256:
			check(FileAccess.get_sha256("res://art_src/camp_npcs_v37/"+id+"/sources/"+asset+".png")==str(manifest.source_sha256[asset]),"reviewed fresh source "+asset)
		for animation:StringName in art.get_animation_names():
			var count:=art.get_frame_count(animation)
			check(count==(1 if str(animation).begins_with("idle_") else 4),"authored frame count")
			check(art.get_animation_loop(animation)==(animation!=&"rest"),"rest remains non-looping")
			for i in count:
				var texture:=art.get_frame_texture(animation,i) as AtlasTexture
				check(texture!=null and texture.region.size==Vector2(448,448),"full cell")
				if texture==null:continue
				var pixels:=texture.get_image()
				check(pixels!=null and not pixels.is_invisible(),"actual atlas pixels available")
				var bounds:Rect2=texture.get_meta("painted_bounds")
				check(bounds.has_area() and bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<448 and bounds.end.y<448,"body and props inside transparent frame")
	SaveService.data.control_setup_done=true;SaveService.data.input_guide_seen=true
	SaveService.data.camp_tutorial={"enabled":false,"completed":true};SaveService.data.reduced_motion=true;SaveService.data.replay_seen_dialogue=false
	var camp:=CampWorld.new();add_child(camp)
	while not camp.initialization_complete:await ticks(1)
	check(camp.initialization_success,"real camp initializes")
	if not camp.initialization_success:get_tree().quit(1);return
	check(camp.residents_root.get_child_count()==4,"same four patrol residents")
	for npc:CampResident in camp.residents_root.get_children():npc.set_physics_process(false)
	for size:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=size;await ticks()
		for npc:CampResident in camp.residents_root.get_children():
			var shape:=npc.get_child(0) as CollisionShape2D
			check(shape!=null and is_equal_approx((shape.shape as CircleShape2D).radius,9.0),"original collision radius")
			check(npc.patrol.size()>=2,"existing patrol route")
			check(npc._badge.position==Vector2(0,-30),"quest badge anchor")
			check(npc._sprite.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"painted art filter")
			for d in VECTORS.size():
				npc._facing=VECTORS[d]
				for action:StringName in [&"idle_south",&"walk_north",&"rest",&"talk"]:
					npc._pose(action)
					var expected:String=str(action) if action in [&"rest",&"talk"] else ("walk_" if action==&"walk_north" else "idle_")+DIRECTIONS[d]
					check(str(npc._sprite.animation)==expected,"actual actor direction mapping")
					check(npc._sprite.flip_h==(VECTORS[d].x>0 if action in [&"rest",&"talk"] else DIRECTIONS[d] in ["e","ne","se"]),"mirrored direction")
					var origin:=npc._sprite.position;var scale_before:=npc._sprite.scale
					for frame in npc._sprite.sprite_frames.get_frame_count(npc._sprite.animation):
						npc._sprite.set_frame_and_progress(frame,0)
						check(npc._sprite.position==origin and npc._sprite.scale==scale_before,"stable runtime transform")
						check((origin+Vector2(0,168)*scale_before).is_equal_approx(Vector2(0,12)),"foot anchor at all resolutions")
	for npc:CampResident in camp.residents_root.get_children():
		npc._facing=Vector2(-1,1)
		for action:StringName in [&"walk_south",&"rest",&"talk"]:
			var seen:Dictionary={};var sprite:=npc._sprite
			var listener:=func()->void:seen[sprite.frame]=true
			sprite.frame_changed.connect(listener);npc._pose(action);sprite.set_frame_and_progress(0,0);seen[0]=true;sprite.play();sprite.speed_scale=8
			await get_tree().create_timer(.55,true,false,true).timeout
			check(seen.size()==4,"actual playback all four frames "+npc.resident_id+" "+str(action))
			sprite.frame_changed.disconnect(listener);sprite.speed_scale=1
		# Exercise original physics and conversation pause without global UIFlow pause.
		var route:=npc.patrol.duplicate();var goal:=npc._goal
		npc.interacting=true;npc.velocity=Vector2(48,0);var before:=npc.position
		npc._physics_process(1.0/60.0)
		check(npc.velocity==Vector2.ZERO and npc.position==before and npc._sprite.animation==&"talk","conversation stops movement with new talk pose")
		npc.interacting=false;npc._rest_left=0;npc._rest_pose_left=0;npc._stalled=0
		npc.position=npc.patrol[0];npc._patrol_index=1;npc._goal=npc.patrol[1]
		for i in 4:
			await get_tree().physics_frame;npc._physics_process(1.0/60.0)
		check(npc.velocity.length()<=48.001,"original patrol speed cap")
		check(npc.position.distance_to(npc.patrol[0])>.01 and str(npc._sprite.animation).begins_with("walk_"),"real route moves with new directional walk")
		check(npc.patrol==route,"pose changes cannot rewrite patrol")
		npc._goal=goal;npc._rest_left=3.2;npc._rest_pose_left=3.2;npc._physics_process(1.0/60.0)
		check(npc._sprite.animation==&"rest" and npc.velocity==Vector2.ZERO,"original occupational rest drives new frames")
	camp.queue_free();await ticks(8);CampResidentArt.clear();HanddrawnHeroArt.clear();AudioManager.shutdown();await ticks()
	print("CAMP_NPC_ART_V37 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
