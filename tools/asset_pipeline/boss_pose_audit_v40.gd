extends SceneTree
## Source-only audit for newly redrawn complete-body boss poses.
## Never edits art or switches the runtime BossStageArt atlas.
const ROOT:="res://art_src/boss_redraw_v40/poses/"
const POSES:=["idle","move","windup","release"]
const MIN_NATIVE_HEIGHT:=680
const MIN_MARGIN:=1

func _initialize()->void:
	var total:=0
	var failures:=0
	var receipt:Dictionary={"contract":"native-size and painted-edge audit of new source poses","scope":"manual visual review remains required for backgrounds, phase identity, anatomy and animation","sets":{}}
	for phase:String in DirAccess.get_directories_at(ROOT):
		var entries:Dictionary={}
		receipt.sets[phase]=entries
		for pose:String in POSES:
			var path:=ROOT+phase+"/"+pose+".png"
			var image:=Image.new()
			var error:=image.load(path)
			if error!=OK:
				push_error("Missing source "+path)
				failures+=1
				continue
			var used:=_painted_bounds(image)
			var native_height:=used.size.y
			var margins:=[used.position.x,used.position.y,image.get_width()-used.end.x,image.get_height()-used.end.y]
			var has_margin:=true
			for margin:int in margins:
				if margin<MIN_MARGIN:has_margin=false
			var okay:=has_margin and native_height>=MIN_NATIVE_HEIGHT and used.has_area()
			entries[pose]={"sha256":FileAccess.get_sha256(path),"canvas":[image.get_width(),image.get_height()],"used":[used.position.x,used.position.y,used.size.x,used.size.y],"margins":margins,"native_height":native_height,"passes":okay}
			print("BOSS_POSE ",phase," ",pose," ","PASS" if okay else "FAIL"," height=",native_height," margins=",margins)
			total+=1
			if not okay:failures+=1
	var target:=ROOT+"audit.json"
	var file:=FileAccess.open(target,FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "))
	file.close()
	print("BOSS_POSE_AUDIT checks=",total," failures=",failures)
	quit(1 if failures else 0)

func _painted_bounds(image:Image)->Rect2i:
	var left:=image.get_width()
	var top:=image.get_height()
	var right:=0
	var bottom:=0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a<.18:continue
			left=mini(left,x)
			top=mini(top,y)
			right=maxi(right,x+1)
			bottom=maxi(bottom,y+1)
	return Rect2i(left,top,maxi(0,right-left),maxi(0,bottom-top))
