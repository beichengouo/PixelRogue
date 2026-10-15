extends Node2D
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:call_deferred("run")
func run()->void:
	var pool:=RoomTemplatePool.new();pool.reload()
	pool.templates.assign([
		{"id":"a","theme":"forest","room_kinds":["normal"],"tags":[],"selection_weight":1},
		{"id":"b","theme":"ruin","room_kinds":["normal"],"tags":[],"selection_weight":10},
		{"id":"c","theme":"wetland","room_kinds":["normal"],"tags":[],"selection_weight":100}])
	var counts:={"a":0,"b":0,"c":0}
	for seed_value in range(1,601):
		var selected:=pool.select(seed_value,"normal","forest")
		counts[selected.id]+=1
		if seed_value<=12:check(selected.id==pool.select(seed_value,"normal","ruin").id,"normal selection is not biased by biome")
	for id in counts:check(absf(float(counts[id])-200)<35,"equal normal frequencies "+id+": "+str(counts[id]))
	check(RoomTemplatePool.selection_weight(pool.templates[2],"normal")==1.0,"combat ignores former high weights")
	check(RoomTemplatePool.selection_weight(pool.templates[2],"shop")==100.0,"shop preserves its configured weight")
	check(RoomTemplatePool.selection_weight(pool.templates[2],"tavern")==100.0,"tavern preserves its configured weight")
	var room:RoomLevel=load("res://src/room_mode/room_level.tscn").instantiate();add_child(room)
	var fresh:={"id":"0,0","kind":"spawn","biome":"forest","seed":37,"doors":[],"delta":{}}
	room.load_room(fresh)
	check(not str(fresh.terrain_layout.get("scene_art","")).is_empty(),"new starting room uses painted map")
	var legacy:=RoomLayout.generate(17,"spawn")
	var old_run:={"id":"0,0","kind":"normal","biome":"forest","seed":91,"doors":[],"delta":{},"terrain_layout":legacy}
	room.load_room(old_run)
	check(not str(old_run.terrain_layout.get("scene_art","")).is_empty(),"retired plain grass room is replaced on entry")
	var custom:={"room_rect":[0,0,828,468],"props":[],"ground":[],"water":[],"decor":[]}
	var manual:={"id":"0,0","kind":"normal","biome":"forest","seed":19,"doors":[],"delta":{},"terrain_layout":custom}
	room.load_room(manual)
	check(manual.terrain_layout==custom and not manual.terrain_layout.has("scene_art"),"explicit custom geometry remains unchanged")
	room.free()
	print("ROOM_UNIFORM_SELECTION checks=",checks," failures=",failures," distribution=",counts)
	get_tree().quit(1 if failures else 0)
