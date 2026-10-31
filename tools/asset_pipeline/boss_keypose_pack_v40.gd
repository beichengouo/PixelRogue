extends SceneTree
## Packs newly redrawn whole-body poses into one high-resolution key-pose atlas.
## This source atlas is QA-only; it is not substituted for an incomplete runtime action atlas.
const SOURCE_ROOT:="res://art_src/boss_redraw_v40/poses/"
const OUTPUT_ROOT:="res://art_src/boss_redraw_v40/packed/"
const POSES:=["idle","move","windup","release"]
const CELL:=1536
const INSET:=60

func _initialize()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE_ROOT+"audit.json"))
	if not audit.has("sets"):
		push_error("Run boss_pose_audit_v40.gd before packing")
		quit(1)
		return
	var failures:=0
	for phase:String in DirAccess.get_directories_at(SOURCE_ROOT):
		var images:Array[Image]=[]
		var trims:Array[Rect2i]=[]
		var max_extent:=0
		for pose:String in POSES:
			var image:=Image.new()
			var path:=SOURCE_ROOT+phase+"/"+pose+".png"
			if image.load(path)!=OK:
				push_error("Missing redrawn pose "+path)
				failures+=1
				break
			var phase_audit:Dictionary=audit.sets.get(phase,{})
			var pose_audit:Dictionary=phase_audit.get(pose,{})
			if not pose_audit.get("passes",false):
				push_error("Pose has not passed audit "+path)
				failures+=1
				break
			var used:Array=pose_audit.used
			var trim:=Rect2i(int(used[0]),int(used[1]),int(used[2]),int(used[3])).grow(4).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
			trims.append(trim)
			images.append(image.get_region(trim))
			max_extent=maxi(max_extent,maxi(trim.size.x,trim.size.y))
		if images.size()!=POSES.size():continue
		var common_scale:=minf(1.0,float(CELL-INSET*2)/float(max_extent))
		var atlas:=Image.create(CELL*POSES.size(),CELL,false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		var entries:Dictionary={}
		for index in POSES.size():
			var source:=images[index]
			var w:=roundi(source.get_width()*common_scale)
			var h:=roundi(source.get_height()*common_scale)
			if common_scale<1.0:source.resize(w,h,Image.INTERPOLATE_LANCZOS)
			var at:=Vector2i(index*CELL+(CELL-w)/2,CELL-INSET-h)
			atlas.blit_rect(source,Rect2i(Vector2i.ZERO,Vector2i(w,h)),at)
			entries[POSES[index]]={"cell_index":index,"source_sha256":FileAccess.get_sha256(SOURCE_ROOT+phase+"/"+POSES[index]+".png"),"trim":[trims[index].position.x,trims[index].position.y,trims[index].size.x,trims[index].size.y],"frame_size":[w,h],"top_left":[at.x-index*CELL,at.y]}
		var path:=OUTPUT_ROOT+phase+"_keyposes.png"
		if atlas.save_png(path)!=OK:
			push_error("Atlas write failed "+path)
			failures+=1
			continue
		var data:Dictionary={"status":"qa_keyposes_not_runtime","cell":CELL,"foot":[CELL/2,CELL-INSET],"scale":common_scale,"poses":entries}
		var file:=FileAccess.open(OUTPUT_ROOT+phase+"_keyposes.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(data,"  "))
		file.close()
		print("BOSS_KEYPOSE ",phase," cell=",CELL," scale=",common_scale," atlas=",path)
	print("BOSS_KEYPOSE_PACK failures=",failures)
	quit(1 if failures else 0)
