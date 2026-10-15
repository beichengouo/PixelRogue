extends Node2D
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:call_deferred("run")
func run()->void:
	var room:RoomLevel=load("res://src/room_mode/room_level.tscn").instantiate();add_child(room)
	room.load_room({"id":"0,0","kind":"normal","biome":"forest","seed":7,"delta":{},"doors":["0,-1","1,0","0,1","-1,0"],"terrain_layout":{"room_rect":[0,0,828,468],"props":[],"water":[],"ground":[],"decor":[],"entities":[]}})
	check(room.has_method("load_scene_objects"),"room supports world-space scene objects")
	if not room.has_method("load_scene_objects"):print("SCENE_POLYGON checks=",checks," failures=",failures);get_tree().quit(1);return
	var texture:="res://assets/room_illustrated/tavern_v01/lamp_01.png"
	if not ResourceLoader.exists(texture):texture="res://assets/room_mode/refinement/crate.png"
	var objects:Array=[{"id":"concave-rock","kind":"stone","texture":texture,"position_px":[210,210],"render_width_px":80,"collision_polygon_px":[[-40,-40],[40,-40],[40,-10],[-10,-10],[-10,40],[-40,40]]},{"id":"lamp-foot","kind":"light","texture":texture,"position_px":[414,240],"render_width_px":40,"collision_polygon_px":[[-5,-4],[5,-4],[5,3],[-5,3]],"light":{"kind":"lamp"}},{"id":"loose-crate","kind":"crate","texture":texture,"position_px":[610.5,250.25],"render_width_px":48,"collision_polygon_px":[[-20,-14],[18,-18],[22,12],[-17,15]]}]
	room.call("load_scene_objects",objects,"")
	check(room.body_clear(Vector2(230,230),5),"concave notch remains walkable")
	check(not room.body_clear(Vector2(180,225),5),"concave filled leg blocks body")
	check(not room.segment_clear(Vector2(150,220),Vector2(230,220),5),"swept corridor intersects actual polygon")
	check(room.sight(Vector2(225,220),Vector2(235,235)),"sight through concave notch")
	check(not room.sight(Vector2(150,225),Vector2(200,225)),"actual bottom polygon blocks sight")
	check(room.body_clear(Vector2(414,205),8),"lamp upper art remains walkable")
	check(not room.body_clear(Vector2(414,240),8),"lamp bottom footprint blocks")
	check(not room.navigation.is_point_solid(Vector2i(11,5)),"navigation leaves lamp top open")
	check(room.large_navigation.is_point_solid(Vector2i(23,13)),"large navigation sees lamp bottom")
	check(route_reaches(room,Vector2(140,220),Vector2(310,220),12),"ally and normal enemy navigate around concave footprint")
	check(route_reaches(room,Vector2(135,220),Vector2(315,220),26),"large enemy navigates around concave footprint with body clearance")
	var cell_edge:=Vector2(144.8329,230.9838)
	check(room.body_clear(cell_edge,12) and room.navigation.is_point_solid(room.world_to_cell(cell_edge)),"clear body can occupy a cell with blocked center")
	check(not room.path_direction(cell_edge,Vector2(310,220),12).is_zero_approx(),"blocked-center recovery continues moving")
	room.scene_polygons["thin-regression"]=RoomSceneGeometry.polygon([[54,70],[54.2,70],[54.2,110],[54,110]])
	check(not room.segment_clear(Vector2(50,90),Vector2(66,90),1),"continuous sweep detects thin polygon between samples")
	check(room.segment_clear(Vector2(50,65),Vector2(66,65),1),"continuous sweep allows clear corridor beside thin polygon")
	room.scene_polygons.erase("thin-regression")
	await get_tree().physics_frame;await get_tree().physics_frame
	var query:=PhysicsPointQueryParameters2D.new();query.collision_mask=Layers.WORLD
	query.position=Vector2(230,230)
	check(get_world_2d().direct_space_state.intersect_point(query).is_empty(),"real physics keeps concave notch open")
	query.position=Vector2(180,225)
	check(not get_world_2d().direct_space_state.intersect_point(query).is_empty(),"real physics blocks concave leg")
	query.position=Vector2(414,205)
	check(get_world_2d().direct_space_state.intersect_point(query).is_empty(),"real physics allows walking behind lamp upper artwork")
	query.position=Vector2(414,240)
	check(not get_world_2d().direct_space_state.intersect_point(query).is_empty(),"real physics blocks only lamp foot")
	var crate:RoomProp
	for child in room.props_root.get_children():
		if child is RoomProp and str(child.get("scene_object_id"))=="loose-crate":crate=child
	check(is_instance_valid(crate),"crate is damageable gameplay entity")
	check(crate.position==Vector2(610.5,250.25),"precise object position preserved")
	check(not room.scene_navigation.graphs.is_empty(),"precise navigation graph retained across path queries")
	crate.take_damage(100)
	check(room.scene_navigation.graphs.is_empty(),"crate destruction invalidates cached navigation graph")
	check(room.record.delta.get("scene_broken",[]).has("loose-crate"),"destruction keyed by stable object id")
	check(room.body_clear(Vector2(610.5,250.25),8),"destroyed crate releases geometry")
	room.call("load_scene_objects",objects,"")
	var count:=0
	for child in room.props_root.get_children():
		if child is RoomProp and str(child.get("scene_object_id"))=="loose-crate" and not child.is_queued_for_deletion():count+=1
	check(count==0,"reload respects object destruction")
	var occlusion=room.get("scene_occlusion")
	check(is_instance_valid(occlusion),"occlusion lifecycle controller created")
	var opaque:=Image.create(32,64,false,Image.FORMAT_RGBA8);opaque.fill(Color.WHITE)
	var target:=Sprite2D.new();target.texture=ImageTexture.create_from_image(opaque);target.position=Vector2(500,250);target.offset=Vector2(0,-32);room.decor_root.add_child(target)
	occlusion.call("register_sprite",target,250.)
	occlusion.call("update_for_points",[Vector2(500,220)],1.)
	check(target.modulate.a<0.45,"player hidden by upper artwork makes only sprite translucent")
	occlusion.call("update_for_points",[Vector2(500,270)],1.)
	check(target.modulate.a>0.99,"walking in front restores opacity")
	occlusion.call("update_for_points",[Vector2(510,220)],1.)
	check(target.modulate.a<0.45,"alpha overlap detected across actual art")
	for y in 64:
		for x in 17:opaque.set_pixel(x,y,Color.TRANSPARENT)
	target.texture=ImageTexture.create_from_image(opaque)
	occlusion.call("clear");occlusion.call("register_sprite",target,250.)
	occlusion.call("update_for_points",[Vector2(493,220)],1.)
	check(target.modulate.a>0.99,"transparent texture margins do not fade artwork")
	occlusion.call("update_for_points",[Vector2(510,220)],1.)
	check(target.modulate.a<0.45,"opaque pixels still fade beside transparent margin")
	room.load_room({"id":"1,0","kind":"normal","biome":"forest","seed":8,"delta":{},"doors":[],"terrain_layout":{"room_rect":[0,0,828,468],"props":[],"water":[],"ground":[],"decor":[],"entities":[]}})
	check(room.get("scene_polygons").is_empty(),"switch room clears former geometry")
	check(occlusion.get("entries").is_empty(),"switch room clears occlusion references")
	check(room.get("scene_water_polygons") is Array,"room supports precise water shoreline polygons")
	if room.get("scene_water_polygons") is Array:
		var water_shape:Array=[[330,180],[410,180],[410,210],[370,210],[370,250],[330,250]]
		room.load_room({"id":"2,0","kind":"normal","biome":"forest","seed":9,"delta":{},"doors":[],"terrain_layout":{"room_rect":[0,0,828,468],"props":[],"water":[[10,5],[11,5],[10,6],[11,6]],"ground":[],"decor":[],"entities":[],"scene_water_polygons_px":[water_shape]}})
		check(room.scene_water_polygons.size()==1,"precise water contour retained")
		check(room.deep_water.size()==4,"legacy water cells retained for weather surface queries")
		check(room.body_clear(Vector2(394,230),8),"concave riverbank dry notch remains walkable despite coarse water cells")
		check(not room.body_clear(Vector2(350,230),8),"exact water footprint blocks ground units")
		check(room.body_clear(Vector2(350,230),8,true),"flying units ignore precise water footprint")
		check(not room.segment_clear(Vector2(300,225),Vector2(390,225),8),"swept ground movement detects water contour")
		check(room.segment_clear(Vector2(300,225),Vector2(390,225),8,true),"flying movement crosses water contour")
		check(room.flying_navigation.is_point_solid(Vector2i(9,6))==false,"flying navigation ignores precise water")
		check(room.navigation.is_point_solid(Vector2i(9,6)),"ground navigation samples actual riverbank")
		check(not room.navigation.is_point_solid(Vector2i(11,6)),"ground navigation keeps coarse-cell dry area traversable")
		check(route_reaches(room,Vector2(280,225),Vector2(440,225),12),"ground ally and enemy route around precise shoreline")
		check(route_reaches(room,Vector2(280,225),Vector2(440,225),26),"large body routes around precise shoreline")
		check(route_reaches(room,Vector2(280,225),Vector2(440,225),12,true),"flying enemy crosses precise shoreline")
		check(room.scene_navigation.graphs.size()==2,"ground graphs separated by body radius and reused between routes")
		await get_tree().physics_frame;await get_tree().physics_frame
		query.collision_mask=Layers.DEEP_WATER;query.position=Vector2(394,230)
		check(get_world_2d().direct_space_state.intersect_point(query).is_empty(),"real water physics leaves irregular notch clear")
		query.position=Vector2(350,230)
		check(not get_world_2d().direct_space_state.intersect_point(query).is_empty(),"real water physics blocks authored contour")
		room.load_room({"id":"3,0","kind":"normal","biome":"forest","seed":10,"delta":{},"doors":[],"terrain_layout":{"room_rect":[0,0,828,468],"props":[],"water":[],"ground":[],"decor":[],"entities":[]}})
		check(room.scene_water_polygons.is_empty(),"switch room clears precise water geometry")
		check(room.scene_navigation.graphs.is_empty(),"switch room clears navigation graphs for prior shapes and room size")
	room.free();await get_tree().process_frame
	print("SCENE_POLYGON checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
func route_reaches(room:RoomLevel,start:Vector2,goal:Vector2,radius:float,flying:=false)->bool:
	var point:=start
	for step in 300:
		if point.distance_to(goal)<6:return true
		var direction:=room.path_direction(point,goal,radius,flying)
		if direction.is_zero_approx():
			print("ROUTE stopped point=",point," goal=",goal," radius=",radius," body_clear=",room.body_clear(point,radius,flying))
			return false
		var next:=point+direction*minf(3,point.distance_to(goal))
		if not room.segment_clear(point,next,radius,flying):
			print("ROUTE blocked point=",point," next=",next," radius=",radius)
			return false
		point=next
	print("ROUTE timeout point=",point," goal=",goal," radius=",radius)
	return false
