extends Node
const ROOT:="res://art_src/heroes_v36/xixifu/normal/packed/"
var checks:=0
var failures:=0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",why)
func ticks(n:=3)->void:
	for i in n:await get_tree().process_frame
func _ready()->void:call_deferred("run")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):
		push_error("Isolated E profile required");get_tree().quit(1);return
	AchievementTracker.set_process(false);GameState.set_process(false)
	var art:=load(ROOT+"xixifu_normal_draft.tres") as SpriteFrames
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"production.json"))
	check(art!=null,"draft resource parses")
	if art==null:get_tree().quit(1);return
	check(bool(art.get_meta("draft",false)),"incomplete draft is explicitly labelled")
	check(art.get_animation_names().size()==int(manifest.resource_animations),"only available animations published")
	check(not bool(manifest.calibration_pass_is_visual_approval),"technical registration cannot grant visual approval")
	check(not bool(manifest.runtime_integrated) and not bool(manifest.combat_chain_implemented),"draft playback cannot claim combat integration")
	check(int(manifest.source_files)==69 and int(manifest.authored_source_frames)==261,"complete normal-form authored source set")
	check(manifest.pending_source_files.is_empty() and manifest.calibration_pending_source_files.is_empty(),"no missing source or uncalibrated clip")
	check(manifest.groups_need_review.is_empty(),"no failed clip silently substituted")
	check(int(manifest.draft_frame_positions)==261,"all authored source frames present in draft")
	var source_views:={"s":"s","sw":"sw","w":"w","nw":"nw","n":"n","ne":"nw","e":"w","se":"sw"}
	for view:String in source_views:
		for action in ["idle","walk","skill_cast","attack1","attack2","attack3","attack4","attack5","move_attack1","move_attack2","move_attack3","move_attack4","move_attack5"]:
			check(art.has_animation(action+"_"+view),"authored action available "+action+"_"+view)
		check(art.has_animation("combo_cycle_"+view) and art.has_animation("move_combo_cycle_"+view),"both authored five-stage cycles available "+view)
	for missing:String in manifest.groups_need_review:
		var parts:=missing.trim_prefix("xixifu_normal_").split("_")
		var source:=parts[0];var action:=parts[1]
		for view:String in source_views:
			if source_views[view]!=source:continue
			check(not art.has_animation(action+"_"+view),"rejected source absent, including mirror "+missing+" "+view)
			check(not art.has_animation("combo_cycle_"+view),"incomplete chain absent "+view)
	for animation:StringName in art.get_animation_names():
		var count:=art.get_frame_count(animation);check(count>0,"nonempty animation")
		var duration:=0.0
		for index in count:
			var texture:=art.get_frame_texture(animation,index) as AtlasTexture
			check(texture!=null and texture.region.size==Vector2(448,448),"full original frame cell")
			if texture==null:continue
			var image:=texture.get_image();check(image!=null and image.get_width()==448,"actual cropped atlas data available")
			var bb:Rect2=texture.get_meta("painted_bounds")
			check(Rect2(0,0,448,448).encloses(bb) and bb.has_area() and bb.position.x>0 and bb.position.y>0 and bb.end.x<448 and bb.end.y<448,"painted bounds fit whole cell with alpha clearance")
			duration+=art.get_frame_duration(animation,index)/art.get_animation_speed(animation)
		if str(animation).contains("combo_cycle_"):
			check(count==20 and absf(duration-3.85)<.0001,"five-stage20-frame cycle timing")
	var holder:=Node2D.new();holder.position=Vector2(320,360);add_child(holder)
	var sprite:=AnimatedSprite2D.new();sprite.sprite_frames=art;holder.add_child(sprite)
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await ticks()
		for animation:StringName in art.get_animation_names():
			sprite.play(animation);sprite.flip_h=str(animation).ends_with("_e") or str(animation).ends_with("_ne") or str(animation).ends_with("_se");HanddrawnHeroArt.place(sprite,art,32,14)
			var position_before:=sprite.position;var scale_before:=sprite.scale
			for index in art.get_frame_count(animation):
				sprite.set_frame_and_progress(index,0);HanddrawnHeroArt.place(sprite,art,32,14)
				check(sprite.position==position_before and sprite.scale==scale_before,"frame bounds cannot change display transform")
				var expected:Vector2=Vector2(0,14)
				var foot:=sprite.position+(Vector2(224,392)-Vector2(224,224))*sprite.scale
				check(foot.is_equal_approx(expected),"fixed448cell foot anchor at all resolutions")
				var texture:=art.get_frame_texture(animation,index) as AtlasTexture
				var painted:Rect2=texture.get_meta("painted_bounds")
				if sprite.flip_h:painted.position.x=448-painted.end.x
				var top_left:=sprite.to_global(painted.position-Vector2(224,224))
				var bottom_right:=sprite.to_global(painted.end-Vector2(224,224))
				check(get_viewport().get_visible_rect().encloses(Rect2(top_left,bottom_right-top_left)),"painted character actually inside rendered viewport")
	for prefix in ["combo_cycle_","move_combo_cycle_"]:
		for direction:String in source_views:
			if not art.has_animation(prefix+direction):continue
			var seen:Dictionary={}
			var listener:=func()->void:seen[sprite.frame]=true
			sprite.frame_changed.connect(listener);sprite.play(prefix+direction);sprite.flip_h=direction in ["ne","e","se"];sprite.speed_scale=2
			await get_tree().create_timer(2.1,true,false,true).timeout
			check(seen.size()==20,"real animation playback visits all20 authored poses "+prefix+direction)
			sprite.frame_changed.disconnect(listener)
	holder.queue_free();await ticks();art=null;HanddrawnHeroArt.clear();AudioManager.shutdown();await ticks()
	print("XIXIFU_SPRITE_DRAFT_V36 checks=%d failures=%d"%[checks,failures]);get_tree().quit(1 if failures else 0)
