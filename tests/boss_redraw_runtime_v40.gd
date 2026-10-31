extends Node
## Regression contract: the active redraw preserves V34 action timing and feet,
## while V41 adds a distinct middle pose for every phase skill.
const STAGES:=["king_1","king_2","mage_1","mage_2","tide_1","tide_2","tide_3","sephra_1","sephra_2","verena_1","verena_2","nameless_1","nameless_2","nameless_3"]
var checks:=0
var failures:=0

func _ready()->void:
	for key:String in STAGES:_check_stage(key)
	print("BOSS_REDRAW_RUNTIME checks=",checks," failures=",failures)
	get_tree().quit(1 if failures>0 else 0)

func _check(ok:bool,reason:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error("BOSS_REDRAW "+reason)

func _check_stage(key:String)->void:
	var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/boss_stages_v34/"+key+".json"))
	var active_root:=BossStageArt.ROOT
	var now:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(active_root+key+".json"))
	var is_v41:=int(now.get("revision",0))==41
	_check(is_v41 or int(now.get("revision",0))==40,key+" revision")
	var source_count:=int(now.get("source_pose_count",0))
	var expected_count:=4
	if is_v41:expected_count+=now.skill_transition_coverage.required.size()
	_check(source_count==expected_count,key+" source pose count")
	_check(str(now.get("animation_kind",""))==("skill_mid_key_poses_complete" if is_v41 else "held_four_key_poses"),key+" honest animation kind")
	if is_v41:_check(bool(now.skill_transition_coverage.complete) and now.skill_transition_coverage.pending.is_empty(),key+" complete skill coverage")
	var components:=key.split("_")
	var id:=StringName(components[0])
	var phase:=int(components[1])
	var frames:=BossStageArt.frames(id,phase)
	_check(frames.get_meta("boss_stage_art",false),key+" stage flag")
	_check(int(frames.get_meta("source_pose_count",0))==source_count,key+" runtime source count")
	_check(frames.get_animation_names().size()==old.animations.size(),key+" action count")
	var poses:Dictionary=now.poses
	var cell:=int(now.cell)
	var foot:Vector2=frames.get_meta("foot",Vector2.ZERO)
	_check(foot==Vector2(now.foot[0],now.foot[1]),key+" foot metadata")
	_check(float(now.body_height)>=500.0,key+" 2K source detail")
	for pose:String in poses:
		_check(poses.has(pose),key+"/"+pose+" source pose")
		var bounds:Array=poses[pose].painted_bounds
		_check(int(bounds[3])==int(foot.y),key+"/"+pose+" painted baseline")
		_check(bounds[0]>=0 and bounds[1]>=0 and bounds[2]<=cell and bounds[3]<=cell,key+"/"+pose+" unclipped")
	var unique_textures:Dictionary={}
	for action:String in old.animations:
		_check(frames.has_animation(action),key+"/"+action+" animation exists")
		if not frames.has_animation(action):continue
		var spec:Dictionary=old.animations[action]
		_check(frames.get_frame_count(action)==spec.frames.size(),key+"/"+action+" time slots")
		_check(is_equal_approx(frames.get_animation_speed(action),float(spec.fps)),key+"/"+action+" fps")
		_check(frames.get_animation_loop(action)==(action in ["idle","move"]),key+"/"+action+" loop")
		for index in frames.get_frame_count(action):
			var tile:=frames.get_frame_texture(action,index) as AtlasTexture
			_check(tile!=null,key+"/"+action+"/"+str(index)+" atlas frame")
			if tile==null:continue
			unique_textures[tile.get_instance_id()]=true
			_check(tile.atlas.resource_path.begins_with(active_root),key+"/"+action+" active redraw atlas")
	_check(unique_textures.size()==source_count,key+" every independent pose used")
	var sprite:=AnimatedSprite2D.new()
	sprite.sprite_frames=frames
	sprite.play(&"idle")
	BossStageArt.align(sprite,id,Vector2(80,120))
	var foot_y:float=sprite.position.y+(foot.y-cell*.5)*sprite.scale.y
	_check(absf(foot_y-60.0)<.01,key+" world foot anchor")
	sprite.free()
