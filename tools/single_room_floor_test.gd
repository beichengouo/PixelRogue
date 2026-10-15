extends Node
var checks:=0
var failures:Array[String]=[]
func _ready()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FLOOR_FAIL "+label)
func run()->void:
	var room:RoomLevel=load("res://src/room_mode/room_level.tscn").instantiate();add_child(room)
	var pool:=RoomTemplatePool.new();pool.reload()
	check(pool.templates.size()==15,"All fifteen templates remain legal")
	for template in pool.templates:
		var kind:String=template.room_kinds[0];var layout:=RoomTemplateCodec.to_layout(template)
		var data:Dictionary={"id":"0,0","kind":kind,"biome":template.theme,"seed":1,"cleared":true,"delta":{},"doors":[],"terrain_layout":layout}
		room.load_room(data)
		var materials:Dictionary={}
		for y in int(template.grid.size[1]):
			for x in int(template.grid.size[0]):materials[room.service_material(Vector2i(x,y))]=true
		if kind in ["shop","tavern"]:check(materials.size()>=2,"Service room preserves mixed floor "+str(template.id))
		else:
			check(materials.size()==1 and materials.has(str(layout.base_ground)),"Single floor across entire "+str(template.id))
			check(template.layers.ground.is_empty(),"No patchwork stored in template "+str(template.id))
		check(room.deep_water.size()==layout.water.size(),"Water cells preserved "+str(template.id))
		check(not room.get_node("FloorTiles").visible,"Legacy painted ground cannot overlay runtime floor "+str(template.id))
	for seed_value in 50:
		var generated:=RoomLayout.generate(seed_value,"normal")
		check(generated.ground.is_empty() and generated.base_ground=="grass","Fallback single-floor seed "+str(seed_value))
	var legacy:Dictionary={"version":2,"ground":[{"at":[1,1],"kind":"mud"},{"at":[2,1],"kind":"stone"}],"base_ground":"wood","water":[[3,3]],"props":[],"decor":[]}
	var legacy_copy:=legacy.duplicate(true)
	room.load_room({"id":"0,0","kind":"normal","biome":"forest","cleared":true,"delta":{},"doors":[],"terrain_layout":legacy})
	check(room.service_material(Vector2i(1,1))=="wood" and room.service_material(Vector2i(2,1))=="wood","Old mixed save rendered with its single base floor")
	check(legacy==legacy_copy and room.deep_water.has(Vector2i(3,3)),"Old saved water/positions/layout remain intact")
	room.queue_free();await get_tree().process_frame;AudioManager.shutdown()
	print("SINGLE_ROOM_FLOOR ",JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
