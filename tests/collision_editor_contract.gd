extends Node

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var source := RoomTemplateCodec.read_file("res://assets/room_templates/forest_clearing.json")
	var original := RoomSceneArtCatalog.definition(str(source.scene_art))
	var object: Dictionary = original.objects[0]
	var id := str(object.id)
	var key := "object:"+id
	var default_shape: Array = object.collision_polygon_px.duplicate(true)
	check(RoomEditorCollision.shape(source,key)==default_shape,"old template inherits shared scene collision")
	var first := source.duplicate(true)
	RoomEditorCollision.assign(first,key,[])
	check(RoomEditorCollision.shape(first,key).is_empty(),"per-template empty override disables collision")
	check(RoomEditorCollision.shape(source,key)==default_shape and RoomSceneArtCatalog.definition(str(source.scene_art)).objects[0].collision_polygon_px==default_shape,"another template and shared scene remain untouched")
	var layout := RoomTemplateCodec.to_layout(first)
	check(not layout.is_empty(),"disabled scene collision passes validation and layout conversion")
	if not layout.is_empty():
		check(layout.scene_objects[0].collision_polygon_px.is_empty(),"runtime layout carries disabled scene collision")
	var path := "E:/CodexWorkspace/PixelRogue/temp/collision_editor_contract.json"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(RoomTemplateCodec.write_file(path,first)==OK,"edited template saves to isolated test file")
	var loaded := RoomTemplateCodec.read_file(path)
	check(RoomEditorCollision.shape(loaded,key).is_empty(),"edited collision survives JSON round trip")
	RoomEditorCollision.restore(loaded,key)
	check(RoomEditorCollision.shape(loaded,key)==default_shape,"restore default returns original polygon")
	check(not RoomEditorCollision.valid_polygon([[0,0],[30,30],[0,30],[30,0]]).is_empty(),"self-intersecting polygon rejected")
	var blank := RoomTemplateCodec.blank()
	blank.layers.obstacles.append({"id":"placed_crate","asset_id":"scene:forest_clearing_v03:crate_a","at":[9,6]})
	check(RoomTemplateValidator.validate(blank).is_empty(),"placed scene piece baseline valid")
	var editor := RoomTemplateEditor.new();add_child(editor)
	await get_tree().process_frame
	editor.document=blank.duplicate(true);editor._sync()
	var placed_key := "placed:placed_crate"
	var before := RoomEditorCollision.shape(editor.document,placed_key)
	var point := Vector2(float(before[0][0])-1.0,float(before[0][1]))+RoomEditorCollision.origin(editor.document,placed_key)
	editor._collision_edit(placed_key,"move",0,point)
	check(editor._undo.size()==1 and RoomEditorCollision.shape(editor.document,placed_key)!=before,"vertex drag creates one undo transaction")
	editor._undo_edit()
	check(RoomEditorCollision.shape(editor.document,placed_key)==before,"undo restores polygon")
	editor._redo_edit()
	check(RoomEditorCollision.shape(editor.document,placed_key)!=before,"redo reapplies polygon")
	var moved_layout := RoomTemplateCodec.to_layout(editor.document)
	check(not moved_layout.is_empty() and moved_layout.scene_objects.size()==1,"placed polygon reaches runtime layout")
	var room: RoomLevel = load("res://src/room_mode/room_level.tscn").instantiate();add_child(room)
	room.load_room({"id":"0,0","kind":"normal","biome":"forest","seed":7,"delta":{},"doors":[],"terrain_layout":moved_layout})
	check(room.scene_polygons.has("placed_crate"),"preview and runtime load real edited polygon")
	var center := RoomEditorCollision.origin(editor.document,placed_key)+Vector2(0,-7)
	check(not room.body_clear(center,2),"edited crate shape blocks real body clearance")
	RoomEditorCollision.assign(editor.document,placed_key,[])
	var clear_layout := RoomTemplateCodec.to_layout(editor.document)
	room.load_room({"id":"0,0","kind":"normal","biome":"forest","seed":7,"delta":{},"doors":[],"terrain_layout":clear_layout})
	check(not room.scene_polygons.has("placed_crate") and room.body_clear(center,2),"disabled collision clears body and navigation geometry")
	var service := RoomServiceProp.new();add_child(service)
	service.setup("building_shop",Vector2(300,200),180,66,null,PackedVector2Array(),true)
	check(service.get_child_count()==1 and service.footprint.size==Vector2.ZERO,"explicitly disabled service building creates no fallback rectangle")
	var water := RoomTemplateCodec.blank()
	var water_key := RoomEditorCollision.add_water(water)
	RoomEditorCollision.assign(water,water_key,[[250,150],[320,150],[320,210],[250,210]])
	var water_layout := RoomTemplateCodec.to_layout(water)
	check(not water_layout.is_empty() and water_layout.scene_water_polygons_px.size()==1,"new water polygon saves to runtime layout")
	room.load_room({"id":"0,0","kind":"normal","biome":"forest","seed":7,"delta":{},"doors":[],"terrain_layout":water_layout})
	check(not room.body_clear(Vector2(280,180),3) and room.body_clear(Vector2(340,180),3),"new water contour controls runtime body clearance")
	var shop := RoomTemplateCodec.blank(Vector2i(23,13),"shop")
	shop.layers.decor.append({"id":"own_service","asset_id":"service:building_shop","at":[11,6],"config":{"width_px":180,"depth_px":66,"offset_px":[0,0]}})
	var service_key := "placed:own_service"
	check(RoomEditorCollision.shape(shop,service_key).size()==4,"standard service building exposes its actual default rectangle")
	RoomEditorCollision.assign(shop,service_key,[])
	var shop_layout := RoomTemplateCodec.to_layout(shop)
	check(not shop_layout.is_empty() and shop_layout.service_props[0].collision_disabled,"standard service building can disable fallback rectangle per template")
	var authored_shop := RoomTemplateCodec.read_file("res://assets/room_templates/shop_garden.json")
	RoomEditorCollision.assign(authored_shop,"service_building",[])
	var authored_layout := RoomTemplateCodec.to_layout(authored_shop)
	check(not authored_layout.is_empty() and authored_layout.service_props[0].collision_disabled,"illustrated service building disable reaches runtime layout")
	if not authored_layout.is_empty():
		room.load_room({"id":"0,0","kind":"shop","biome":"forest","seed":7,"delta":{},"doors":[],"terrain_layout":authored_layout})
		check(is_instance_valid(room.service_building) and room.service_building.get_child_count()==1,"preview service building has no fallback collider")
	var coarse_water := RoomTemplateCodec.blank()
	coarse_water.layers.water.append({"id":"cell_water","asset_id":"water","at":[8,6]})
	var disabled_key := RoomEditorCollision.add_water(coarse_water)
	RoomEditorCollision.assign(coarse_water,disabled_key,[])
	var disabled_layout := RoomTemplateCodec.to_layout(coarse_water)
	check(not disabled_layout.is_empty() and disabled_layout.scene_water_collision_override,"explicit disabled water is encoded")
	if not disabled_layout.is_empty():
		room.load_room({"id":"0,0","kind":"normal","biome":"forest","seed":7,"delta":{},"doors":[],"terrain_layout":disabled_layout})
		check(room.body_clear(RoomLayout.center(Vector2i(8,6)),3) and not room.navigation.is_point_solid(Vector2i(8,6)),"disabled water does not regain coarse collision or navigation blockage")
	var bounds_doc := RoomTemplateCodec.blank()
	check(RoomEditorCollision.bounds(bounds_doc)==Rect2(0,0,828,468),"legacy template keeps original walkable bounds")
	var invalid_bounds := bounds_doc.duplicate(true);invalid_bounds.room_bounds_override=[0,0,100,100]
	check(not RoomEditorCollision.bounds_error(invalid_bounds).is_empty(),"boundary rejects undersized rectangle")
	invalid_bounds.room_bounds_override=[-1,0,829,468]
	check(not RoomEditorCollision.bounds_error(invalid_bounds).is_empty(),"boundary rejects space outside original map")
	var tightened := RoomEditorCollision.moved_bounds(bounds_doc,5,Vector2(414,432))
	bounds_doc.room_bounds_override=tightened
	check(RoomTemplateValidator.validate(bounds_doc).is_empty(),"tightened bottom preserves four valid doors and body routes")
	var bounds_layout := RoomTemplateCodec.to_layout(bounds_doc)
	check(bounds_layout.get("room_rect",[])==[0.0,0.0,828.0,432.0] and bounds_layout.get("visual_room_rect",[])==[0,0,828,468],"layout separates collision bounds from original art frame")
	check(RoomTemplateCodec.write_file(path,bounds_doc)==OK and RoomEditorCollision.bounds(RoomTemplateCodec.read_file(path))==Rect2(0,0,828,432),"bounds override survives JSON round trip")
	bounds_doc.id="collision_boundary_contract"
	var pool_path := RoomTemplatePool.USER+"/collision_boundary_contract.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RoomTemplatePool.USER))
	check(RoomTemplateCodec.write_file(pool_path,bounds_doc)==OK,"bounds override saves to isolated template pool")
	var pool_check := RoomTemplatePool.new();pool_check.reload()
	check(pool_check.templates.any(func(item):return str(item.id)=="collision_boundary_contract" and RoomEditorCollision.bounds(item)==Rect2(0,0,828,432)),"template pool reload preserves edited bounds")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pool_path))
	room.load_room({"id":"0,0","kind":"normal","biome":"forest","seed":7,"delta":{},"doors":[],"terrain_layout":bounds_layout})
	check(room.body_clear(Vector2(414,420),5) and not room.body_clear(Vector2(414,449),5),"real body clearance follows tightened bottom boundary")
	check(room.door_point(Vector2i.DOWN).y==412.0 and room.entry_point(Vector2i.UP).y==374.0,"south door and entry use tightened boundary")
	await get_tree().physics_frame;await get_tree().physics_frame
	var boundary_query := PhysicsPointQueryParameters2D.new();boundary_query.collision_mask=Layers.WORLD;boundary_query.position=Vector2(414,450)
	check(not room.get_world_2d().direct_space_state.intersect_point(boundary_query).is_empty(),"bottom boundary real physics collider moved with edited bounds")
	editor.document=RoomTemplateCodec.blank();editor._sync()
	var undo_count := editor._undo.size()
	editor._collision_edit("room_bounds","move",5,Vector2(414,432))
	check(editor._undo.size()==undo_count+1 and RoomEditorCollision.bounds(editor.document).end.y==432,"edge drag is one undo transaction")
	editor._undo_edit()
	check(RoomEditorCollision.bounds(editor.document).end.y==468,"edge drag undo restores original bounds")
	var illustrated := source.duplicate(true)
	illustrated.room_bounds_override=RoomEditorCollision.moved_bounds(illustrated,5,Vector2(414,464))
	var illustrated_layout := RoomTemplateCodec.to_layout(illustrated)
	check(not illustrated_layout.is_empty(),"illustrated room accepts small template-only bottom adjustment")
	if not illustrated_layout.is_empty():
		room.load_room({"id":"0,0","kind":"normal","biome":"forest","seed":7,"delta":{},"doors":[],"terrain_layout":illustrated_layout})
		var frame_before := room.illustration.frame_rect()
		var original_layout := RoomTemplateCodec.to_layout(source)
		room.load_room({"id":"0,0","kind":"normal","biome":"forest","seed":7,"delta":{},"doors":[],"terrain_layout":original_layout})
		check(room.illustration.frame_rect()==frame_before,"scene artwork frame stays fixed when collision bounds change")
	room.free();editor.free();service.free()
	print("COLLISION_EDITOR checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
