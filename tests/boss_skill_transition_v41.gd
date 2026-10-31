extends Node
## Admitted V41 contract: every live skill animation resolves its independent
## middle pose while V40 timing slots and source traceability remain intact.
const STAGES:=["king_1","king_2","mage_1","mage_2","tide_1","tide_2","tide_3","sephra_1","sephra_2","verena_1","verena_2","nameless_1","nameless_2","nameless_3"]
const SOURCE:="res://art_src/boss_redraw_v40/"
const V41:="res://assets/boss_stages_v41/"
const SELECTION:=SOURCE+"skill_transitions/selection.json"
var checks:=0
var failures:=0
var selected:Dictionary={}

func _ready()->void:
	_check(BossStageArt.ROOT==V41,"BossStageArt loads V41")
	var selection:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SELECTION))
	selected=selection.get("stages",{})
	_check(int(selection.get("revision",0))==41 and int(selection.get("skill_count",0))==74,"approved skill source selection")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(V41+"manifest.json"))
	_check(int(manifest.get("stage_count",0))==STAGES.size(),"manifest stage count")
	_check(not bool(manifest.get("candidate_only",true)) and bool(manifest.get("runtime_loader_switched",false)),"manifest admitted status")
	var total_required:=0
	var total_covered:=0
	for key:String in STAGES:
		var result:=_stage(key)
		total_required+=int(result.required)
		total_covered+=int(result.covered)
	_check(total_required==int(manifest.get("required_skill_transitions",-1)),"manifest required total")
	_check(total_covered==int(manifest.get("covered_skill_transitions",-1)),"manifest covered total")
	_check(total_required==74 and total_covered==74,"all 74 skills admitted")
	var manifest_stages:Array=manifest.get("stages",[])
	_check(manifest_stages.size()==STAGES.size(),"manifest stage entries")
	for item:Dictionary in manifest_stages:
		var key:=str(item.get("stage",""))
		_check(key in STAGES,key+" declared stage")
		_check((item.get("pending",[]) as Array).is_empty(),key+" no pending skills")
		_check(FileAccess.get_sha256(V41+key+".png")==str(item.get("atlas_sha256","")),key+" atlas SHA")
		_check(FileAccess.get_sha256(V41+key+".json")==str(item.get("metadata_sha256","")),key+" metadata SHA")
	print("BOSS_SKILL_TRANSITION_V41 checks=",checks," failures=",failures," coverage=",total_covered,"/",total_required)
	get_tree().quit(1 if failures else 0)

func _check(ok:bool,why:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error("BOSS_V41 "+why)

func _stage(key:String)->Dictionary:
	var base:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/boss_stages_v40/"+key+".json"))
	var now:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(V41+key+".json"))
	_check(int(now.get("revision",0))==41 and int(now.get("base_revision",0))==40,key+" revision")
	var cell:=int(now.get("cell",0))
	var columns:=int(now.get("columns",0))
	var rows:=int(now.get("rows",0))
	_check(cell==960 and columns>0 and columns<=8 and rows>0,key+" bounded atlas grid")
	_check(now.foot==base.foot,key+" common foot anchor")
	_check(float(now.body_height)>=500.0,key+" painted 2K body height")
	var image:=Image.load_from_file(V41+key+".png")
	_check(image!=null and image.get_size()==Vector2i(columns*cell,rows*cell),key+" atlas dimensions")
	var coverage:Dictionary=now.skill_transition_coverage
	var required:Array=coverage.required
	var covered:Array=coverage.covered
	var pending:Array=coverage.pending
	var covered_ids:Dictionary={}
	for value in covered:covered_ids[int(value)]=true
	_check(selected.has(key),key+" approved source stage")
	var selected_stage:Dictionary=selected.get(key,{})
	_check(selected_stage.size()==required.size(),key+" approved source count")
	_check(covered.size()+pending.size()==required.size(),key+" complete skill coverage partition")
	_check(bool(coverage.complete) and pending.is_empty(),key+" coverage completion flag")
	_check(int(now.source_pose_count)==4+covered.size(),key+" independent source pose count")
	_check(str(now.animation_kind)==("skill_mid_key_poses_complete" if pending.is_empty() else "skill_mid_key_poses_partial"),key+" honest animation kind")
	var seen:Dictionary={}
	for pose:String in now.poses:
		var item:Dictionary=now.poses[pose]
		var index:=int(item.index)
		var col:=int(item.column)
		var row:=int(item.row)
		_check(index>=0 and index<int(now.source_pose_count) and not seen.has(index),key+"/"+pose+" unique atlas slot")
		seen[index]=true
		_check(col==index%columns and row==floori(float(index)/float(columns)),key+"/"+pose+" row-column mapping")
		var box:Array=item.painted_bounds
		_check(box.size()==4 and int(box[0])>=0 and int(box[1])>=0 and int(box[2])<=cell and int(box[3])==int(now.foot[1]),key+"/"+pose+" painted bounds and sole")
		var source_path:=SOURCE+("poses/" if pose in ["idle","move","windup","release"] else "skill_transitions/")+key+"/"+pose+".png"
		_check(FileAccess.file_exists(source_path),key+"/"+pose+" source exists")
		if FileAccess.file_exists(source_path):
			_check(FileAccess.get_sha256(source_path)==str(item.source_sha256),key+"/"+pose+" source SHA")
			if pose.begins_with("skill_"):
				_check(str(selected_stage.get(pose,""))==str(item.source_sha256),key+"/"+pose+" approved SHA")
		if image!=null:
			_check(image.get_pixel(col*cell,row*cell).a<.18,key+"/"+pose+" transparent atlas corner")
	for action:String in base.animations:
		_check(now.animations.has(action),key+"/"+action+" action retained")
		if not now.animations.has(action):continue
		var before:Dictionary=base.animations[action]
		var after:Dictionary=now.animations[action]
		_check(is_equal_approx(float(after.fps),float(before.fps)),key+"/"+action+" FPS unchanged")
		_check(int(after.slots)==int(before.slots),key+"/"+action+" frame-slot count unchanged")
		var seq:Array=after.pose_sequence
		_check(seq.size()==int(before.slots),key+"/"+action+" sequence fills every slot")
		for pose:String in seq:
			_check(now.poses.has(pose),key+"/"+action+" references only packed poses")
		if action.begins_with("skill_"):
			var parts:=action.split("_")
			var mid:="skill_"+parts[1]+"_mid"
			_check(covered_ids.has(int(parts[1])) and seq.has(mid),key+"/"+action+" uses unique skill mid")
	var key_parts:=key.split("_")
	var frames:=BossStageArt.frames(StringName(key_parts[0]),int(key_parts[1]))
	_check(frames.get_meta("boss_stage_art",false),key+" live frames built")
	_check(int(frames.get_meta("source_pose_count",0))==int(now.source_pose_count),key+" live pose count")
	for action:String in now.animations:
		_check(frames.has_animation(action),key+"/"+action+" live action")
		if not frames.has_animation(action):continue
		var spec:Dictionary=now.animations[action]
		var seq:Array=spec.pose_sequence
		_check(frames.get_frame_count(action)==seq.size(),key+"/"+action+" live frame count")
		_check(is_equal_approx(frames.get_animation_speed(action),float(spec.fps)),key+"/"+action+" live FPS")
		for index:int in range(mini(frames.get_frame_count(action),seq.size())):
			var texture:=frames.get_frame_texture(action,index) as AtlasTexture
			_check(texture!=null,key+"/"+action+"/"+str(index)+" live atlas frame")
			if texture==null:continue
			var pose:Dictionary=now.poses[str(seq[index])]
			_check(texture.region==Rect2(int(pose.column)*cell,int(pose.row)*cell,cell,cell),key+"/"+action+"/"+str(index)+" exact live pose")
	return {"required":required.size(),"covered":covered.size()}
