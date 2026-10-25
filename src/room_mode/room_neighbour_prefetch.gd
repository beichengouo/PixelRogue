class_name RoomNeighbourPrefetch
extends Node
## Adjacent maps are built in isolated, non-rendered physics worlds.
const DESKTOP_LIMIT := 4
const MOBILE_LIMIT := 2
func capacity()->int:return MOBILE_LIMIT if MobileControls.enabled() else DESKTOP_LIMIT
var main:Node
var ready_rooms:Dictionary={}
var _working := ""
var _generation := 0
var _poll := 0.0
var _stamp := ""
var hits := 0
var misses := 0
var last_prepare_ms := 0.0
var last_install_ms := 0.0
var _flow := -1

func _ready()->void:process_mode=Node.PROCESS_MODE_PAUSABLE
func _signature()->String:
	return str(RoomTemplatePool._signature(RoomTemplatePool._template_paths())).sha256_text()
func _key(record:Dictionary)->String:
	var delta:Dictionary=record.get("delta",{})
	return var_to_bytes([record.id,record.seed,record.kind,record.get("boss",""),record.get("biome",""),record.get("terrain_layout",{}),record.get("doors",[]),delta.get("broken",[]),delta.get("scene_broken",[]),delta.get("prop_hp",{}),delta.get("scene_prop_hp",{})]).hex_encode().sha256_text()
func clear()->void:
	_generation+=1
	for entry in ready_rooms.values():
		if is_instance_valid(entry.viewport):entry.viewport.queue_free()
	ready_rooms.clear();_stamp=""
func _exit_tree()->void:clear()
func _process(dt:float)->void:
	if not is_instance_valid(main.player) or not GameState.run_active or main._navigation_pending:return
	if _flow!=main._flow_epoch:_flow=main._flow_epoch;clear()
	_poll-=dt
	if _poll>0 or not _working.is_empty() or UIFlow.has_screen():return
	_poll=.35
	var choices:Array=[]
	for step:Vector2i in RoomGraph.DIRECTIONS:
		var id:String=main.graph.neighbour(step)
		if id.is_empty():continue
		id=main.graph.entry_destination(id)
		if id==main.graph.current or not main.graph.rooms.has(id):continue
		choices.append({"id":id,"distance":main.player.global_position.distance_squared_to(main.level.door_point(step,0))})
	choices.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.distance<b.distance)
	var wanted:Array=[]
	for entry in choices:
		if not wanted.has(entry.id):wanted.append(entry.id)
		if wanted.size()>=capacity():break
	for id in ready_rooms.keys():
		if not wanted.has(id):ready_rooms[id].viewport.queue_free();ready_rooms.erase(id)
	for id:String in wanted:
		if not ready_rooms.has(id):_prepare(id);return

func _valid(generation:int,flow:int,id:String)->bool:
	return is_inside_tree() and generation==_generation and is_instance_valid(main) and flow==main._flow_epoch and main.graph.rooms.has(id)
func _warm_textures(record:Dictionary,valid:Callable)->bool:
	var layout:Dictionary=record.get("terrain_layout",{})
	var scene_id:=str(layout.get("scene_art",""))
	var data:=RoomSceneArtCatalog.definition(scene_id)
	var paths:Array[String]=[]
	for plane in data.get("planes",[]):paths.append(RoomSceneArtCatalog.ROOT+scene_id+"/"+str(plane.path))
	for gate in data.get("gates",{}).values():paths.append(RoomSceneArtCatalog.ROOT+scene_id+"/"+str(gate.path))
	for item in layout.get("scene_objects",data.get("objects",[])):
		var path:=str(item.get("texture",""))
		if not path.begins_with("res://"):path=RoomSceneArtCatalog.ROOT+scene_id+"/"+path
		if ResourceLoader.exists(path) and not paths.has(path):paths.append(path)
	# Dummy RenderingServer used by headless QA has no concurrent texture storage.
	# Player builds keep threaded IO; headless fixtures load on their sole render thread.
	if DisplayServer.get_name()=="headless":
		var started:=Time.get_ticks_usec()
		for path in paths:
			_texture_hold.append(load(path))
			if Time.get_ticks_usec()-started>=2000:
				await get_tree().process_frame;started=Time.get_ticks_usec()
				if not bool(valid.call()):return false
		return bool(valid.call())
	# Keep returned resources alive until the prepared level owns their references.
	var held:Array[Resource]=[]
	for offset in range(0,paths.size(),3):
		for index in range(offset,mini(offset+3,paths.size())):
			if ResourceLoader.has_cached(paths[index]):held.append(load(paths[index]));continue
			ResourceLoader.load_threaded_request(paths[index],"Texture2D")
		for index in range(offset,mini(offset+3,paths.size())):
			var path:=paths[index]
			while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
				if not bool(valid.call()):return false
			if ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_LOADED:held.append(ResourceLoader.load_threaded_get(path))
	# Return the resources to the coroutine caller, not a global unbounded texture cache.
	_texture_hold=held
	return bool(valid.call())
var _texture_hold:Array[Resource]=[]
func _prepare(id:String)->void:
	if not _working.is_empty() or not main.graph.rooms.has(id):return
	_working=id
	var generation:=_generation;var flow:int=main._flow_epoch
	var valid:=_valid.bind(generation,flow,id)
	var start:=Time.get_ticks_usec()
	var stamp:=_signature()
	if not _stamp.is_empty() and stamp!=_stamp:
		for entry in ready_rooms.values():entry.viewport.queue_free()
		ready_rooms.clear()
	_stamp=stamp
	var record:Dictionary=main.graph.rooms[id].duplicate(true)
	var original_key:=_key(record)
	var pool:=RoomTemplatePool.new()
	if not await pool.ensure_loaded_async(get_tree(),valid):_working="";return
	var view:=SubViewport.new();view.name="PreparedRoom"
	view.size=Vector2i(1280,720);view.world_2d=World2D.new();view.disable_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_DISABLED;view.process_mode=Node.PROCESS_MODE_DISABLED
	view.set_meta("room_prefetch",true);add_child(view)
	var level:RoomLevel=main._create_level();level.prefetching=true;level.prefetch_valid=valid
	view.add_child(level)
	if level._room_requires_template(record):level._select_room_template(record,pool)
	if not await _warm_textures(record,valid):view.queue_free();_working="";_texture_hold.clear();return
	var loaded:=await level.load_room_async(record,self)
	_texture_hold.clear()
	if loaded and bool(valid.call()):
		var warmed:=await CombatArtWarmup.prepare(get_tree(),BossEntranceArt.for_room(record,main.graph.chapter_id),valid)
		if warmed and bool(valid.call()):
			last_prepare_ms=(Time.get_ticks_usec()-start)/1000.0
			ready_rooms[id]={"viewport":view,"level":level,"key":original_key,"stamp":stamp}
		else:view.queue_free()
	else:view.queue_free()
	_working=""
func take(id:String)->RoomLevel:
	if ready_rooms.has(id):
		var entry:Dictionary=ready_rooms[id]
		if entry.key==_key(main.graph.rooms[id]) and entry.stamp==_signature():
			hits+=1;ready_rooms.erase(id)
			var prepared:RoomLevel=entry.level
			prepared.reparent(main,false);entry.viewport.queue_free()
			return prepared
		entry.viewport.queue_free();ready_rooms.erase(id)
	return null
func obtain(id:String)->RoomLevel:
	var result:=take(id)
	if result!=null:return result
	misses+=1
	while not _working.is_empty():
		await get_tree().process_frame
		if not is_instance_valid(main) or not main.graph.rooms.has(id):return null
	result=take(id)
	if result!=null:return result
	await _prepare(id)
	return take(id)
