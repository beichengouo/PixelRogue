extends Node2D

var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:call_deferred("run")
func run()->void:
	var template:=RoomTemplateCodec.read_file("res://assets/room_templates/ruin_archive.json")
	var layout:={"room_rect":[0,0,828,468],"props":[],"water":[],"ground":[],"decor":[],"entities":[],"scene_art":str(template.get("scene_art","")),"ports":template.get("ports",[])}
	var room:RoomLevel=load("res://src/room_mode/room_level.tscn").instantiate();add_child(room)
	room.load_room({"id":"0,0","kind":"normal","biome":"ruin","seed":71,"delta":{},"doors":[],"terrain_layout":layout})
	var anchor:=room.door_point(Vector2i.UP,90)
	var pocket:=Vector2(801,27)
	print("RUIN_ARCHIVE_POCKET clear=",room.body_clear(pocket,26)," route=",room.path_direction(pocket,anchor,26))
	var rng:=RandomNumberGenerator.new();rng.seed=1003
	var inner:=Vector2(594,126)
	var shapes:=[[[530,60],[670,60],[670,80],[530,80]],[[530,180],[670,180],[670,200],[530,200]],[[530,80],[550,80],[550,180],[530,180]],[[650,80],[670,80],[670,180],[650,180]]]
	var objects:Array=[]
	for index in shapes.size():objects.append({"id":"ring_%d"%index,"kind":"stone","texture":"res://assets/room_mode/refinement/stone.png","position_px":[0,0],"render_width_px":36,"collision_polygon_px":shapes[index]})
	var pocket_layout:={"room_rect":[0,0,828,468],"props":[],"water":[],"ground":[],"decor":[],"entities":[],"scene_objects":objects,"markers":[{"id":"trapped_marker","asset_id":"spawn","at":[16,3]}],"ports":RoomTemplateCodec.blank().ports}
	room.load_room({"id":"0,0","kind":"normal","biome":"ruin","seed":72,"delta":{},"doors":[],"terrain_layout":pocket_layout})
	var main:=room.door_point(Vector2i.LEFT,90)
	check(room.body_clear(inner,26) and room.path_direction(inner,main,26).is_zero_approx(),"synthetic marker sits in a real isolated walkable pocket")
	var spawned:=room.spawn_point(rng,main,26)
	check(spawned!=inner and not room.path_direction(spawned,main,26).is_zero_approx(),"spawn skips isolated marker and uses playable main component")
	pocket_layout.markers=[]
	room.load_room({"id":"0,0","kind":"normal","biome":"ruin","seed":73,"delta":{},"doors":[],"terrain_layout":pocket_layout})
	var random_safe:=true
	for sample in 100:
		var point:=room.spawn_point(rng,main,26)
		if not room.scene_navigation.spawn_reachable(room,point,26,false):random_safe=false;break
	check(random_safe,"random scene spawns stay in playable navigation component")
	var west_layout:={"room_rect":[0,0,828,468],"props":[],"water":[],"ground":[],"decor":[],"entities":[],"markers":[{"id":"east_marker","asset_id":"spawn","at":[16,6]}],"scene_objects":[{"id":"split_wall","kind":"stone","texture":"res://assets/room_mode/refinement/stone.png","position_px":[0,0],"render_width_px":36,"collision_polygon_px":[[250,0],[270,0],[270,468],[250,468]]}]}
	var west_record:Dictionary={"id":"0,0","kind":"normal","biome":"ruin","seed":74,"delta":{},"doors":["-1,0"],"terrain_layout":west_layout}
	room.load_room(west_record)
	var west_entry:=room.door_point(Vector2i.LEFT,90)
	var west_spawn:=room.spawn_point(rng,west_entry,26)
	check(west_spawn.x<224 and not room.path_direction(west_spawn,west_entry,26).is_zero_approx(),"single west entrance skips larger isolated east component and its marker")
	print("ROOM_SPAWN_CONNECTIVITY checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
