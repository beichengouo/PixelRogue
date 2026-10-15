extends Node2D

var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func _ready()->void:call_deferred("run")

func run()->void:
	var upper:=[[330,0],[350,0],[350,171],[330,171]]
	var lower:=[[330,225],[350,225],[350,468],[330,468]]
	var shapes:Array[PackedVector2Array]=[RoomSceneGeometry.polygon(upper),RoomSceneGeometry.polygon(lower)]
	var reached_large:=RoomTemplateValidator._reachable_scene(Vector2i(7,6),Vector2i(23,13),{},26.0,[],shapes)
	var reached_small:=RoomTemplateValidator._reachable_scene(Vector2i(7,6),Vector2i(23,13),{},14.0,[],shapes)
	check(not reached_large.has(Vector2i(12,6)),"26px validator rejects unsupported narrow door")
	check(reached_small.has(Vector2i(12,6)),"14px validator accepts traversable narrow door")
	var layout:={"room_rect":[0,0,828,468],"props":[],"water":[],"ground":[],"decor":[],"entities":[],"scene_objects":[
		{"id":"wall_upper","kind":"stone","texture":"res://assets/room_mode/refinement/stone.png","position_px":[0,0],"render_width_px":36,"collision_polygon_px":upper},
		{"id":"wall_lower","kind":"stone","texture":"res://assets/room_mode/refinement/stone.png","position_px":[0,0],"render_width_px":36,"collision_polygon_px":lower}]}
	var room:RoomLevel=load("res://src/room_mode/room_level.tscn").instantiate();add_child(room)
	room.load_room({"id":"0,0","kind":"normal","biome":"forest","seed":17,"delta":{},"doors":[],"terrain_layout":layout})
	var from:=Vector2(270,234)
	var to:=Vector2(450,234)
	check(not room.segment_clear(from,to,26),"large body has no direct corridor")
	check(room.path_direction(from,to,26).is_zero_approx(),"runtime large graph also rejects narrow door")
	check(not room.path_direction(from,to,14).is_zero_approx(),"runtime small graph passes after large graph cache")
	var cursor:=from
	var route_safe:=true
	for step in 300:
		if cursor.distance_to(to)<7:break
		var direction:=room.path_direction(cursor,to,14)
		if direction.is_zero_approx():route_safe=false;break
		cursor+=direction*4.0
		if not room.body_clear(cursor,14):route_safe=false;break
	check(route_safe and cursor.distance_to(to)<7,"small body completes the whole narrow-door route without clipping")
	var shop:=RoomTemplateCodec.read_file("res://assets/room_templates/shop_garden.json")
	check(not shop.is_empty(),"authored service map is available")
	if not shop.is_empty():
		var id:=str(shop.scene_art)
		var original:Dictionary=RoomSceneArtCatalog.definition(id)
		var simple:=original.duplicate(true)
		simple.objects=[]
		simple.service_building.collision_polygon_px=[[-60,-50],[60,-50],[60,-10],[-60,-10]]
		RoomSceneArtCatalog._cache[id]=simple
		var shop_errors:=RoomTemplateValidator.validate(shop)
		check(shop_errors.is_empty(),"valid authored service building passes: "+str(shop_errors.slice(0,2)))
		var shop_layout:=RoomTemplateCodec.to_layout(shop)
		check(shop_layout.get("service_props",[]).size()==1 and shop_layout.get("scene_objects",[]).is_empty(),"authored service building creates one interactive entity")
		var wrong_kind:=shop.duplicate(true);wrong_kind.room_kinds=["tavern"]
		var kind_errors:=RoomTemplateValidator.validate(wrong_kind)
		check(kind_errors.any(func(error:String):return error.begins_with("建筑与房间类别不匹配")),"manifest building kind is validated")
		var duplicate:=shop.duplicate(true)
		duplicate.layers.decor.append({"id":"extra_shop","asset_id":"service:building_shop","at":[5,5],"config":{}})
		var duplicate_errors:=RoomTemplateValidator.validate(duplicate)
		check(duplicate_errors.has("服务房只能有一个交互建筑"),"manifest and layer building cannot coexist")
		check(RoomTemplateCodec.to_layout(duplicate).is_empty(),"duplicate building never enters saved layout")
		var same_id:=shop.duplicate(true)
		same_id.layers.decor.append({"id":"service_building","asset_id":"service:goods","at":[5,5],"config":{}})
		check(RoomTemplateValidator.validate(same_id).any(func(error:String):return error.begins_with("条目ID缺失或重复")),"manifest building ID is reserved")
		var doubled:=simple.duplicate(true)
		doubled.objects.append({"id":"service_building","texture":"service_building.png","position_px":[500,150],"collision_polygon_px":[[-10,-10],[10,-10],[10,10],[-10,10]]})
		RoomSceneArtCatalog._cache[id]=doubled
		check(RoomTemplateValidator.validate(shop).has("场景建筑不能同时作为普通物件"),"manifest building cannot be drawn twice")
		var blocked_door:=simple.duplicate(true)
		var at:Array=blocked_door.service_building.position_px
		blocked_door.objects.append({"position_px":[float(at[0]),float(at[1])+34.0],"collision_polygon_px":[[-12,-12],[12,-12],[12,12],[-12,12]]})
		RoomSceneArtCatalog._cache[id]=blocked_door
		var door_errors:=RoomTemplateValidator.validate(shop)
		check(door_errors.has("建筑门口必须为玩家和大型角色保留通路"),"manifest doorway blocks are rejected")
		RoomSceneArtCatalog._cache[id]=original
	room.queue_free()
	print("SCENE_NAV_SERVICE checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
