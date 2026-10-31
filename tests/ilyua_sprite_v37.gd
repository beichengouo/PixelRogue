extends Node
var checks:=0
var failures:=0
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
	var form:="set" if "--legendary" in OS.get_cmdline_user_args() else "normal"
	var root:="res://assets/heroes_handdrawn_v37/ilyua/"+form+"/"
	var art:=load(root+"ilyua_"+form+".tres") as SpriteFrames
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root+"production.json"))
	check(art!=null,"authored resource parses")
	if art==null:get_tree().quit(1);return
	check(int(manifest.source_frames)==261 and int(manifest.clip_count)==69,"all source poses present")
	check(art.get_animation_names().size()==124,"eight directions with full actions and cycles")
	check(art.get_meta("character")==&"ilyua" and art.get_meta("form")==form,"correct hero and form")
	check(bool(art.get_meta("design_combo_only",false)),"design cycles do not claim a combat chain")
	for asset:String in manifest.source_sha256:
		check(FileAccess.get_sha256("res://art_src/heroes_v37/ilyua/"+form+"/sources/"+asset+".png")==str(manifest.source_sha256[asset]),"exact reviewed source "+asset)
	for animation:StringName in art.get_animation_names():
		var count:=art.get_frame_count(animation)
		var cycle:=str(animation).contains("combo_cycle_")
		check(count==(20 if cycle else 1 if str(animation).begins_with("idle_") else 4),"authored frame count "+str(animation))
		var seconds:=0.0
		for i in count:
			var texture:=art.get_frame_texture(animation,i) as AtlasTexture
			check(texture!=null and texture.region.size==Vector2(448,448),"full frame cell")
			if texture==null:continue
			var image:=texture.get_image()
			check(image!=null and image.get_width()==448 and not image.is_invisible(),"actual atlas pixels available")
			var bounds:Rect2=texture.get_meta("painted_bounds")
			check(bounds.has_area() and Rect2(0,0,448,448).encloses(bounds) and bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<448 and bounds.end.y<448,"full body and bow inside transparent cell")
			seconds+=art.get_frame_duration(animation,i)/art.get_animation_speed(animation)
		if cycle:check(is_equal_approx(seconds,5.0),"design five-stage cycle duration")
	var holder:=Node2D.new();holder.position=Vector2(320,360);add_child(holder)
	var sprite:=AnimatedSprite2D.new();sprite.sprite_frames=art;holder.add_child(sprite)
	for size:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=size;await ticks()
		for animation:StringName in art.get_animation_names():
			sprite.play(animation);sprite.flip_h=str(animation).ends_with("_e") or str(animation).ends_with("_ne") or str(animation).ends_with("_se")
			HanddrawnHeroArt.place(sprite,art,32,14)
			var position_before:=sprite.position;var scale_before:=sprite.scale
			for i in art.get_frame_count(animation):
				sprite.set_frame_and_progress(i,0);HanddrawnHeroArt.place(sprite,art,32,14)
				check(sprite.position==position_before and sprite.scale==scale_before,"frame cannot rescale or sway actor")
				check((sprite.position+Vector2(0,168)*sprite.scale).is_equal_approx(Vector2(0,14)),"fixed foot anchor at all resolutions")
	for prefix:String in ["combo_cycle_","move_combo_cycle_"]:
		for direction:String in HanddrawnHeroArt.DIRECTIONS:
			var seen:Dictionary={};var listener:=func()->void:seen[sprite.frame]=true
			sprite.frame_changed.connect(listener);sprite.play(prefix+direction);sprite.speed_scale=4
			await get_tree().create_timer(1.4,true,false,true).timeout
			check(seen.size()==20,"actual playback reaches all authored poses "+prefix+direction)
			sprite.frame_changed.disconnect(listener)
	holder.queue_free();await ticks();art=null;HanddrawnHeroArt.clear();AudioManager.shutdown();await ticks()
	print("ILYUA_SPRITE_V37 ",form," checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
