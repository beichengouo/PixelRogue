extends Node2D
## Independent, isolated-save acceptance fixture for the second illustrated batch.
var checks := 0
var failures := 0
var expected_ids: Array[String] = []
var expected_scene_ids: Array[String] = []
var tested_ids: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	verify_occlusion_rules()
	# The production manifest chooses the art; this fixture does not edit any layout.
	var candidates: Array[Dictionary] = []
	var directory := DirAccess.open("res://assets/room_templates")
	for filename in directory.get_files():
		if not filename.ends_with(".json"): continue
		var document := RoomTemplateCodec.read_file("res://assets/room_templates/" + filename)
		var scene_id := str(document.get("scene_art", ""))
		var definition := RoomSceneArtCatalog.definition(scene_id)
		if not definition.get("objects", []).is_empty():
			var requested := OS.get_cmdline_user_args()
			if not requested.is_empty() and not requested.has(str(document.id)): continue
			candidates.append(document)
			expected_ids.append(str(document.id))
			expected_scene_ids.append(scene_id)
	check(candidates.size() >= 1, "irregular-object illustrated templates are present")
	var pool := RoomTemplatePool.new()
	pool.reload()
	for id in expected_ids:
		var matches := 0
		for document in pool.templates:
			if str(document.id) == id: matches += 1
		check(matches == 1, "template pool has exactly one replacement for " + id)
	for document in candidates:
		await verify_room(document)
	if not expected_ids.is_empty():
		for id in expected_ids: check(tested_ids.has(id), "original built-in template replaced: " + id)
	print("MAP_BATCH_V03 checks=", checks, " failures=", failures, " templates=", tested_ids)
	get_tree().quit(1 if failures else 0)

func verify_room(document: Dictionary) -> void:
	var id := str(document.id)
	print("VERIFY_ROOM ",id)
	tested_ids.append(id)
	var errors := RoomTemplateValidator.validate(document)
	check(errors.is_empty(), id + " template valid: " + str(errors))
	if not errors.is_empty(): return
	var layout := RoomTemplateCodec.to_layout(document)
	check(str(layout.get("template_id", "")) == id, id + " preserves built-in identity")
	check(expected_scene_ids.has(str(document.scene_art)), id + " correct new scene mapping")
	var size: Array = layout.get("size", [])
	check(size.size() == 2 and int(size[0]) == 23 and int(size[1]) == 13, id + " keeps physical 23 by 13 room")
	var definition := RoomSceneArtCatalog.definition(str(document.scene_art))
	var asset_root := RoomSceneArtCatalog.ROOT + str(document.scene_art) + "/"
	for plane in definition.get("planes", []):
		check(ResourceLoader.exists(asset_root + str(plane.path)), id + " ground plane has imported texture")
	for gate in definition.get("gates", {}).values():
		check(ResourceLoader.exists(asset_root + str(gate.path)), id + " gate has imported texture")
	for object in definition.get("objects", []):
		check(ResourceLoader.exists(asset_root + str(object.texture)), id + " object has imported texture")
	var objects: Array = definition.get("objects", [])
	check(not objects.is_empty(), id + " authored independent objects exist")
	var room: RoomLevel = load("res://src/room_mode/room_level.tscn").instantiate()
	add_child(room)
	var record: Dictionary = {"id":"0,0", "kind":str(document.room_kinds[0]), "biome":document.theme, "seed":311,
		"delta":{}, "cleared":false, "doors":["0,-1", "1,0", "0,1", "-1,0"], "terrain_layout":layout}
	room.load_room(record)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(room.illustration.active(), id + " illustrated artwork is active")
	check(not room.shell_art.visible, id + " legacy wall sprites are hidden")
	verify_gates(room, id)
	verify_navigation(room, id)
	await verify_objects(room, objects, id)
	verify_water_polygons(room, definition, id)
	verify_authored_bridges(room, definition, id)
	verify_authored_service(room, definition, id)
	await verify_break_and_restore(room, record, id)
	print("VERIFIED_ROOM ",id)
	room.free()
	await get_tree().process_frame

func verify_authored_bridges(room: RoomLevel, definition: Dictionary, id: String) -> void:
	for bridge in definition.get("bridge_paths_px", []):
		var start_values: Array = bridge.get("start", [])
		var end_values: Array = bridge.get("end", [])
		check(start_values.size() == 2 and end_values.size() == 2, id + " bridge has world-space test endpoints")
		if start_values.size() != 2 or end_values.size() != 2: continue
		var start := Vector2(float(bridge.start[0]), float(bridge.start[1]))
		var end := Vector2(float(bridge.end[0]), float(bridge.end[1]))
		for radius in bridge.get("radii", [12.0, 14.0, 26.0]):
			check(room.segment_clear(start, end, float(radius)), id + " authored bridge carries body radius " + str(radius))
			check(follow_route(room, start, end, float(radius)), id + " authored bridge route can be followed")
		check(physical_hits(room, room.to_global((start + end) * 0.5), Layers.DEEP_WATER).is_empty(), id + " bridge midpoint excludes physical water")

func verify_authored_service(room: RoomLevel, definition: Dictionary, id: String) -> void:
	var building: Dictionary = definition.get("service_building", {})
	if building.is_empty(): return
	check(is_instance_valid(room.service_building), id + " service interaction building exists")
	if not is_instance_valid(room.service_building): return
	var foot := Vector2(float(building.position_px[0]), float(building.position_px[1]))
	check(room.service_building.position.distance_to(foot) < 0.05, id + " service building keeps original foot anchor")
	check(room.service_building.asset_name == str(building.asset), id + " service building keeps correct interaction type")
	check(room.scene_polygons.has("service:" + str(building.id)), id + " service foot has exact polygon collision")
	var doorway := foot + Vector2(0, 34)
	for radius in [14.0, 26.0]:
		check(room.body_clear(doorway, radius), id + " service doorway has body clearance " + str(radius))
		check(follow_route(room, room.door_point(Vector2i.UP, 90), doorway, radius), id + " service doorway can be reached " + str(radius))
	var registered := false
	for entry in room.scene_occlusion.entries:
		if entry.sprite.get_ref() == room.service_building.art: registered = true
	check(registered, id + " service building fades when it occludes player")

func verify_gates(room: RoomLevel, id: String) -> void:
	var directions := {"north":Vector2i.UP, "east":Vector2i.RIGHT, "south":Vector2i.DOWN, "west":Vector2i.LEFT}
	check(room.illustration.gates.size() == 4, id + " four artwork gates are registered")
	for opened in [false, true]:
		room.doors_open = opened
		room.door_phase = 1.0 if opened else 0.0
		room.illustration.refresh_gates()
		for side in directions:
			check(room.illustration.gates.has(side), id + " " + side + " gate exists")
			if room.illustration.gates.has(side):
				var sprite: Sprite2D = room.illustration.gates[side]
				check(sprite.texture != null, id + " " + side + " gate has real texture")
				check(is_equal_approx(sprite.modulate.a, 0.0 if opened else 1.0), id + " " + side + " gate artwork obeys open state")
			var point := room.door_point(directions[side])
			check((room.door_at(point) != Vector2i.ZERO) == opened, id + " gate traversal obeys " + str(opened))
	room.doors_open = true
	room.door_phase = 0.5
	room.illustration.refresh_gates()
	for side in directions:
		check(room.door_at(room.door_point(directions[side])) == Vector2i.ZERO, id + " opening gate waits for traversal threshold " + side)
		check(is_equal_approx(room.illustration.gates[side].modulate.a,0.5), id + " opening gate artwork tracks phase " + side)
	room.door_phase = 1.0
	# Unconnected ports must still be visually closed and cannot exit the graph.
	room.door_directions.erase(Vector2i.LEFT)
	room.illustration.refresh_gates()
	check(room.door_at(room.door_point(Vector2i.LEFT)) == Vector2i.ZERO, id + " unconnected west gate cannot exit")
	check(is_equal_approx(room.illustration.gates.west.modulate.a, 1.0), id + " unconnected west gate remains painted closed")
	room.door_directions.append(Vector2i.LEFT)
	room.illustration.refresh_gates()

func verify_navigation(room: RoomLevel, id: String) -> void:
	var points: Array[Vector2] = []
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		points.append(room.door_point(direction, 90.0))
	# Enemy and ally both use 12px, player 14px, boss 26px.
	for radius in [12.0, 14.0, 26.0]:
		for point in points: check(room.body_clear(point, radius), id + " door approach clear radius " + str(radius))
		var grid: AStarGrid2D = room.large_navigation if radius > 18.0 else room.navigation
		var reachable := flood_clear(room, radius)
		for point in points:
			var cell := Vector2i((point / 18.0).floor())
			check(point_reaches_flood(room, point, radius, reachable), id + " full navigation route to door radius " + str(radius))
		for start_index in points.size():
			for goal_index in points.size():
				if start_index == goal_index: continue
				var start := Vector2i((points[start_index] / grid.cell_size).floor())
				var goal := Vector2i((points[goal_index] / grid.cell_size).floor())
				var label := id + " " + str(start_index) + "→" + str(goal_index) + " radius " + str(radius)
				check(not room.path_direction(points[start_index], points[goal_index], radius).is_zero_approx(), label + " navigation provides an actual route direction")
				check(follow_route(room, points[start_index], points[goal_index], radius), label + " unit can actually follow waypoints")
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261102
		for sample in 60:
			var spawn := room.spawn_point(rng, points[0], radius)
			check(room.body_clear(spawn, radius), id + " generated spawn has body clearance")
			check(point_reaches_flood(room, spawn, radius, reachable), id + " generated spawn is not in trapped pocket at " + str(spawn))
		var isolated := 0
		for y in 26:
			for x in 46:
				var cell := Vector2i(x, y)
				var center := (Vector2(cell) + Vector2.ONE * 0.5) * 18.0
				if room.body_clear(center, radius) and not point_reaches_flood(room, center, radius, reachable):
					isolated += 1
					printerr("ISOLATED ", id, " radius=", radius, " point=", center)
		check(isolated == 0, id + " no isolated walkable body centers radius " + str(radius) + ": " + str(isolated))
	if id == "wetland_curve":
		# The authored river is split around the central horizontal bridge deck.
		for radius in [12.0,14.0,26.0]:
			check(room.segment_clear(Vector2(295,213),Vector2(435,213),radius), id + " central bridge carries ground body radius " + str(radius))
			check(follow_route(room,Vector2(295,213),Vector2(435,213),radius), id + " bridge route can be followed radius " + str(radius))
			check(room.segment_clear(Vector2(586,255),Vector2(586,380),radius), id + " eastern bridge carries ground body radius " + str(radius))
			check(follow_route(room,Vector2(586,255),Vector2(586,380),radius), id + " eastern bridge route can be followed radius " + str(radius))
		for center in [Vector2(364,213),Vector2(586,312)]:
			check(physical_hits(room,room.to_global(center),Layers.DEEP_WATER).is_empty(), id + " physical bridge deck excludes water at " + str(center))

func point_reaches_flood(room: RoomLevel, point: Vector2, radius: float, reached: Dictionary) -> bool:
	# A clear point near a blocked cell center can still join adjacent open cells.
	var cell := Vector2i((point/18.0).floor())
	for y in range(cell.y-2,cell.y+3):
		for x in range(cell.x-2,cell.x+3):
			var candidate := Vector2i(x,y)
			if reached.has(candidate) and room.segment_clear(point,graph_point(room,candidate,radius),radius):return true
	return false

func graph_point(room: RoomLevel, cell: Vector2i, radius: float) -> Vector2:
	var inner := room.room_rect.grow(-radius - 0.1)
	var center := (Vector2(cell) + Vector2.ONE * 0.5) * 18.0
	return Vector2(clampf(center.x, inner.position.x, inner.end.x), clampf(center.y, inner.position.y, inner.end.y))

func follow_route(room: RoomLevel, start: Vector2, goal: Vector2, radius: float) -> bool:
	var point := start
	var visited := {}
	for step in 1200:
		if point.distance_to(goal) < 12.0: return true
		var direction := room.path_direction(point, goal, radius)
		if direction.is_zero_approx():
			printerr("ROUTE_STUCK radius=",radius," start=",start," goal=",goal," point=",point)
			return false
		# Four pixels approximates a normal physics step and exposes cell-edge loops.
		var movement := direction * minf(4.0, point.distance_to(goal))
		if room.segment_clear(point, point + movement, radius): point += movement
		elif room.segment_clear(point, point + Vector2(movement.x, 0), radius): point.x += movement.x
		elif room.segment_clear(point, point + Vector2(0, movement.y), radius): point.y += movement.y
		else: return false
		var key := Vector2i((point*4).round())
		visited[key] = int(visited.get(key,0))+1
		if int(visited[key]) > 5:
			printerr("ROUTE_LOOP radius=",radius," start=",start," goal=",goal," point=",point)
			return false
	return false

func flood_clear(room: RoomLevel, radius: float) -> Dictionary:
	var valid := {}
	for y in 26:
		for x in 46:
			var cell := Vector2i(x, y)
			if room.body_clear(graph_point(room, cell, radius), radius): valid[cell] = true
	var nearest := room.nearest_clear(room.door_point(Vector2i.UP, 90.0), radius)
	var start := Vector2i(-1, -1)
	var best := INF
	for cell: Vector2i in valid:
		var center := graph_point(room, cell, radius)
		var distance := nearest.distance_squared_to(center)
		if distance < best and room.segment_clear(nearest, center, radius):
			best = distance
			start = cell
	if start == Vector2i(-1, -1): return {}
	var queue: Array[Vector2i] = [start]
	var visited := {start:true}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for offset in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]:
			var target: Vector2i = cell + offset
			if visited.has(target) or not valid.has(target): continue
			var from := graph_point(room, cell, radius)
			var to := graph_point(room, target, radius)
			if not room.segment_clear(from, to, radius): continue
			visited[target] = true
			queue.append(target)
	return visited

func verify_objects(room: RoomLevel, objects: Array, id: String) -> void:
	var polygons: Array[CollisionPolygon2D] = []
	collect_polygons(room, polygons)
	check(polygons.size() > 0, id + " true polygon collision bodies are instantiated")
	for object in objects:
		var position_px: Array = object.get("position_px", [0,0])
		var expected := Vector2(float(position_px[0]), float(position_px[1]))
		var authored_node: Node2D = null
		for root in [room.props_root, room.decor_root]:
			for child in root.get_children():
				if str(child.get_meta("scene_object_id", "")) == str(object.get("id", "?")):
					authored_node = child
		check(authored_node != null, id + " authored object is actually instantiated: " + str(object.get("id", "?")))
		if authored_node != null:
			check(room.to_local(authored_node.global_position).distance_to(expected) < 0.05, id + " all object art stays at original foot anchor")
		var found: CollisionPolygon2D = null
		for polygon in polygons:
			if room.to_local(polygon.to_global(Vector2.ZERO)).distance_to(expected) < 0.05: found = polygon; break
		var authored: Array = object.get("collision_polygon_px", [])
		if authored.is_empty(): continue
		check(found != null, id + " object stays at authored foot position: " + str(object.get("id", "?")))
		if found == null: continue
		check(found.polygon.size() == authored.size(), id + " preserves authored irregular outline")
		for index in mini(found.polygon.size(), authored.size()):
			var point: Array = authored[index]
			check(found.polygon[index].distance_to(Vector2(float(point[0]),float(point[1]))) < 0.05, id + " polygon vertex is not rounded to tiles")
		var inside := polygon_inside(found.polygon)
		if inside != Vector2.INF:
			var hit := physical_hits(room, found.to_global(inside))
			check(hit.has(found.get_parent()), id + " physics hits object inside polygon")
			check(not room.body_clear(room.to_local(found.to_global(inside)), 0.2), id + " logical query agrees with polygon physics")
		var cutout := polygon_cutout(found.polygon)
		if cutout != Vector2.INF:
			check(not physical_hits(room, found.to_global(cutout)).has(found.get_parent()), id + " irregular outline excludes empty AABB corner")
	var lit_objects := 0
	for object in objects:
		if object.get("light", {}).is_empty(): continue
		lit_objects += 1
		var foot_polygon: Array = object.get("collision_polygon_px", [])
		check(foot_polygon.size() >= 3, id + " light has a physical base polygon")
		if foot_polygon.is_empty(): continue
		var min_y := INF
		var max_y := -INF
		for point in foot_polygon:
			min_y = minf(min_y, float(point[1]))
			max_y = maxf(max_y, float(point[1]))
		check(max_y - min_y < float(object.get("render_width_px", 36)), id + " lamp collision occupies bottom only")
	check(lit_objects > 0, id + " authored light-bearing objects are present")
	var light_field := RoomLightField.new()
	light_field.refresh(room, 1.0)
	var clock := RoomWorldClock.new()
	clock.minutes = 1380.0
	check(light_field.sources(room, clock, 0.0).size() >= lit_objects, id + " authored lamps join runtime light field")
	light_field.clear()
	check(room.scene_objects.size() == objects.size(), id + " independent object count is unchanged")
	var saved: Array = room.record.terrain_layout.get("scene_objects", [])
	check(saved.size() == objects.size(), id + " full authored objects are saved in room snapshot")
	for index in mini(saved.size(), objects.size()):
		check(saved[index].position_px == objects[index].position_px, id + " saved object is not moved during layer split")
	await get_tree().process_frame

func verify_break_and_restore(room: RoomLevel, record: Dictionary, id: String) -> void:
	var crates: Array[RoomProp] = []
	for child in room.props_root.get_children():
		if child is RoomProp and not child.scene_object_id.is_empty() and child.prop_kind == "crate": crates.append(child)
	if not crates.is_empty(): check(true, id + " breakable independent crates exist")
	if crates.is_empty(): return
	var destroyed_id := crates[0].scene_object_id
	crates[0].take_damage(999.0)
	check(record.delta.get("scene_broken", []).has(destroyed_id), id + " crate destruction uses stable object ID")
	check(not room.scene_polygons.has(destroyed_id), id + " destroyed object immediately releases logical collision")
	await get_tree().process_frame
	room.load_room(record)
	await get_tree().physics_frame
	check(not room.scene_polygons.has(destroyed_id), id + " destroyed object collision does not return on reload")
	var restored := false
	for child in room.props_root.get_children():
		if child is RoomProp and child.scene_object_id == destroyed_id: restored = true
	check(not restored, id + " destroyed object artwork does not return on reload")
	check(room.scene_occlusion.entries.size() <= room.scene_objects.size() + room.record.terrain_layout.get("service_props", []).size(), id + " reload does not accumulate stale occlusion sprites")

func verify_occlusion_rules() -> void:
	# Synthetic alpha mask tests the controller independently of any map placement.
	var image := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.position = Vector2(100, 100)
	add_child(sprite)
	var controller := RoomSceneOcclusion.new()
	controller.register_sprite(sprite, 132.0)
	controller.update_for_points([Vector2(108, 125)], 0.5)
	check(is_equal_approx(sprite.modulate.a, 0.4), "opaque foreground silhouette becomes translucent")
	controller.update_for_points([Vector2(108, 133)], 0.5)
	check(is_equal_approx(sprite.modulate.a, 1.0), "player in front of object restores opacity")
	controller.update_for_points([Vector2(80, 125)], 0.5)
	check(is_equal_approx(sprite.modulate.a, 1.0), "transparent space outside sprite does not fade object")
	controller.update_for_points([], 0.5)
	check(is_equal_approx(sprite.modulate.a, 1.0), "absence of player restores opacity")
	check(sprite.position == Vector2(100, 100), "occlusion does not move sprite")
	controller.clear()
	check(controller.entries.is_empty(), "occlusion registrations release on room change")
	sprite.free()

func collect_polygons(node: Node, result: Array[CollisionPolygon2D]) -> void:
	for child in node.get_children():
		if child is CollisionPolygon2D and not child.disabled: result.append(child)
		collect_polygons(child, result)

func physical_hits(room: RoomLevel, point: Vector2, mask: int = Layers.WORLD) -> Array:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = mask
	var result: Array = []
	for hit in room.get_world_2d().direct_space_state.intersect_point(query, 32): result.append(hit.collider)
	return result

func verify_water_polygons(room: RoomLevel, definition: Dictionary, id: String) -> void:
	var authored: Array = definition.get("surface_water_polygons_px", [])
	check(room.scene_water_polygons.size() == authored.size(), id + " real shoreline polygon count matches drawing")
	check(room.record.terrain_layout.get("scene_water_polygons_px", []) == authored, id + " shoreline is fixed in room save layout")
	for index in mini(authored.size(), room.scene_water_polygons.size()):
		var polygon: PackedVector2Array = room.scene_water_polygons[index]
		check(polygon.size() == authored[index].size(), id + " shore vertices are not replaced by grid rectangles")
		var inside := polygon_inside(polygon)
		if inside == Vector2.INF: continue
		check(not physical_hits(room, room.to_global(inside), Layers.DEEP_WATER).is_empty(), id + " actual deep-water collider matches water surface")
		check(not room.body_clear(inside, 0.2, false), id + " ground unit cannot cross actual water polygon")
		if physical_hits(room, room.to_global(inside)).is_empty():
			check(room.body_clear(inside, 0.2, true), id + " flight can pass above water without treating it as solid scenery")

func polygon_inside(polygon: PackedVector2Array) -> Vector2:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	for y in 12:
		for x in 12:
			var point := bounds.position + bounds.size * Vector2((x + 0.5)/12.0, (y + 0.5)/12.0)
			if Geometry2D.is_point_in_polygon(point, polygon): return point
	return Vector2.INF

func polygon_cutout(polygon: PackedVector2Array) -> Vector2:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	for y in 12:
		for x in 12:
			var point := bounds.position + bounds.size * Vector2((x + 0.5)/12.0, (y + 0.5)/12.0)
			if not Geometry2D.is_point_in_polygon(point, polygon): return point
	return Vector2.INF
