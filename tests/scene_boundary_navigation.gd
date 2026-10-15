extends Node2D

var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func _ready()->void:call_deferred("run")

func run()->void:
	var template:=RoomTemplateCodec.read_file("res://assets/room_templates/forest_bone_glade.json")
	check(not template.is_empty(),"bone glade template loads")
	if template.is_empty():finish();return
	var errors:=RoomTemplateValidator.validate(template)
	check(errors.is_empty(),"bone glade validator accepts traversable boundary: "+str(errors))
	var layout:=RoomTemplateCodec.to_layout(template)
	check(not layout.is_empty(),"accepted bone glade builds a layout")
	if layout.is_empty():finish();return
	var room:RoomLevel=load("res://src/room_mode/room_level.tscn").instantiate()
	add_child(room)
	room.load_room({"id":"0,0","kind":"normal","biome":"forest","seed":17,"delta":{},"doors":["0,-1","1,0","0,1","-1,0"],"terrain_layout":layout})
	var start:=Vector2(810,450)
	var goal:=room.door_point(Vector2i.UP,90.0)
	check(goal.distance_to(Vector2(414,90))<0.01,"north door target is (414,90)")
	check(room.body_clear(start,14),"boundary start has body clearance")
	check(room.segment_clear(start,Vector2(774,450),14),"boundary corridor has continuous clearance")
	check(room.scene_navigation.spawn_reachable(room,start,14,false),"boundary start joins runtime navigation")
	check(not room.path_direction(start,goal,14).is_zero_approx(),"boundary start gives a route direction")
	var cursor:=start
	var safe:=true
	for step in 1200:
		if cursor.distance_to(goal)<12:break
		var direction:=room.path_direction(cursor,goal,14)
		if direction.is_zero_approx():safe=false;break
		var next:=cursor+direction*minf(4.0,cursor.distance_to(goal))
		if not room.segment_clear(cursor,next,14):safe=false;break
		cursor=next
	check(safe and cursor.distance_to(goal)<12,"4px steps follow boundary corridor to north door without collision")
	room.queue_free()
	finish()

func finish()->void:
	print("SCENE_BOUNDARY_NAVIGATION checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
