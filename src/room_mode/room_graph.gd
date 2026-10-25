class_name RoomGraph
extends RefCounted
## Persistent room graph. Room allocation and boss rolls use an isolated RNG.
const VERSION := 3
const SERVICE_INTERVAL := 6
const MAX_RETAINED_ROOMS := 10
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const BOSSES := ["king", "mage", "tide"]
const BOSS_ENTRY_DEADLINES := [10,20,30]
var staged:=false
var stage_index:=1
var stage_seed:=0
var run_seed:=0
var stage_terminal:=""
var stage_boss_cleared:=false
var normal_clear_eligible:=false
var optional_stage_entered:=false
var boss_rush_completed:=false
var extraction_committed:=false
var run_failed:=false
var chapter_id:StringName=ChapterCatalog.FIRST
func boss_ids()->Array:return ChapterCatalog.bosses(chapter_id)
var rooms: Dictionary = {}
var current := "0,0"
var normal_clears:=0
var cleared_count := 0
var encounters := 0
var completed_encounter := 0
var pity := 0
var generated: Array = []
var defeated: Array = []
var service_batches := 0
var next_service := "shop"
var rush_offered := false
const RANDOM_KINDS := ["normal","elite","reward","game","shop","tavern","altar","trial","event"]
const RANDOM_WEIGHTS := [50,15,8,5,4,3,4,7,4]
var _room_serial := 0
var rng := RandomNumberGenerator.new()
var altar_pacing:Dictionary={"seen":false,"clears":0,"bonus":0,"notice":""}

static func key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func cell(id: String) -> Vector2i:
	var parts := id.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func begin(seed_value:int,chapter:StringName=ChapterCatalog.FIRST,staged_run:bool=true)->void:
	staged=staged_run;run_seed=seed_value;stage_index=1
	stage_seed=0;stage_terminal=""
	stage_boss_cleared=false;normal_clear_eligible=false;optional_stage_entered=false;boss_rush_completed=false;extraction_committed=false;run_failed=false
	chapter_id=ChapterCatalog.normalize(chapter)
	rng.seed = seed_value ^ 0x73f129
	rooms.clear(); generated.clear(); defeated.clear()
	current = "0,0"; normal_clears=0;cleared_count = 0; encounters = 0; completed_encounter = 0; pity = 0
	service_batches = 0; next_service = "shop"
	rush_offered=false
	_room_serial = 0
	altar_pacing={"seen":false,"clears":0,"bonus":0,"notice":""}
	if staged:
		_build_stage(0);return
	rooms[current] = _allocate(Vector2i.ZERO, "spawn", "")
	rooms[current].cleared = true
	enter(current)

static func is_combat(kind: String) -> bool:
	return kind in ["normal","elite","boss","boss_rush","altar","trial"]

static func title(kind: String) -> String:
	return {"spawn":"起点","shop":"商店","tavern":"酒馆","boss":"Boss","normal":"战斗房","elite":"精英房","reward":"奖励房","game":"游戏房","boss_rush":"BossRush","altar":"祭坛房","trial":"试炼房","event":"异闻房"}.get(kind,"房间")

func _allocate(at: Vector2i, kind: String, boss_id: String) -> Dictionary:
	if kind=="altar":altar_pacing.seen=true;altar_pacing.clears=0
	var room_seed:=rng.randi()
	_room_serial += 1
	return {"chapter_id":str(chapter_id),"id":key(at), "seed":str(room_seed), "kind":kind, "boss":boss_id,
		"retention_order":_room_serial,
		"encounter_mode":["resident","mixed","spawned"][posmod(room_seed,3)] if kind in ["normal","elite"] else "spawned",
		"biome":["forest", "wetland", "ruin"][rng.randi_range(0,2)],
		"doors":[], "visited":false, "cleared":not is_combat(kind), "rewarded":not is_combat(kind) and kind!="event",
		"encounter":0, "boss_stats":{}, "delta":{}}

func available_boss() -> String:
	if staged:return ""
	if encounters < 9: return ""
	for i in boss_ids().size():
		if encounters+1 >= int(BOSS_ENTRY_DEADLINES[i]) and not generated.has(boss_ids()[i]) and (i == 0 or defeated.has(boss_ids()[i-1])):
			return boss_ids()[i]
	return ""

static func unfinished_boss(record:Dictionary)->bool:
	return str(record.get("kind",""))=="boss" and not bool(record.get("cleared",false))

func entry_destination(requested:String)->String:
	if staged:return requested
	if requested==current or not rooms.has(requested):return requested
	for stage in boss_ids().size():
		var boss_id:String=boss_ids()[stage]
		if defeated.has(boss_id):continue
		if stage>0 and not defeated.has(boss_ids()[stage-1]):return requested
		if encounters+1<int(BOSS_ENTRY_DEADLINES[stage]):return requested
		# Generation pity alone cannot ensure the player enters the room. At the
		# deadline every doorway leads to the existing unfinished encounter.
		for id in rooms:
			if unfinished_boss(rooms[id]) and str(rooms[id].boss)==boss_id:return str(id)
		# Repair old saves whose former retention policy discarded the boss.
		var origin:=cell(current)
		for distance in range(1,rooms.size()+2):
			for direction in DIRECTIONS:
				var position:Vector2i=origin+direction*distance;var id:=key(position)
				if rooms.has(id):continue
				rooms[id]=_allocate(position,"boss",boss_id)
				if distance==1:_connect(current,id)
				if not generated.has(boss_id):generated.append(boss_id)
				prune_rooms();return id
		return requested
	return requested

func _connect(a: String, b: String) -> void:
	if not rooms[a].doors.has(b): rooms[a].doors.append(b)
	if not rooms[b].doors.has(a): rooms[b].doors.append(a)

func enter(id: String) -> Dictionary:
	assert(rooms.has(id))
	id=entry_destination(id)
	current = id
	if staged:
		var fresh:=not bool(rooms[id].visited)
		rooms[id].visited=true
		if fresh and is_combat(str(rooms[id].kind)):
			encounters+=1
			rooms[id].encounter=encounters
		return {"fresh":fresh,"created":[]}
	var record: Dictionary = rooms[id]
	_room_serial += 1; record.retention_order = _room_serial
	if record.visited:
		_ensure_rush_offer()
		prune_rooms(_ensure_frontier());return {"fresh":false, "created":[]}
	record.visited = true
	if is_combat(str(record.kind)):
		encounters += 1
		record.encounter = encounters
	var slots: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var neighbour: Vector2i = cell(id) + direction
		if not rooms.has(key(neighbour)): slots.append(neighbour)
		elif not record.doors.has(key(neighbour)): _connect(id, key(neighbour))
	# Shuffle locally; global loot/weather streams are unaffected.
	for i in range(slots.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap := slots[i]; slots[i] = slots[j]; slots[j] = swap
	var count := mini(slots.size(), rng.randi_range(1,3))
	if record.kind == "spawn": count = mini(3, slots.size())
	var boss_id := available_boss()
	var boss_slot := -1
	if count > 0 and is_combat(str(record.kind)) and not boss_id.is_empty():
		pity += 1
		var boss_index := boss_ids().find(boss_id)
		var guaranteed_at: int = int(BOSS_ENTRY_DEADLINES[boss_index])-1
		var chance: float = [0.10, 0.20, 0.30][boss_index]
		if encounters >= guaranteed_at or rng.randf() < chance:
			boss_slot = rng.randi_range(0,count-1)
			generated.append(boss_id); pity = 0
	var created: Array = []
	for i in count:
		var new_id := key(slots[i])
		var kind := "boss" if i == boss_slot else _roll_kind()
		if record.kind == "spawn" and i < 2: kind = "shop" if i == 0 else "tavern"
		rooms[new_id] = _allocate(slots[i], kind, boss_id if i == boss_slot else "")
		if kind=="boss_rush":rush_offered=true
		if record.kind=="spawn" and kind=="tavern":rooms[new_id].starting_tavern=true
		_connect(id, new_id); created.append(new_id)
	var frontier_path:=_ensure_frontier()
	_ensure_rush_offer()
	prune_rooms(frontier_path)
	return {"fresh":true, "created":created.filter(func(new_id:String)->bool:return rooms.has(new_id))}

func rush_unlocked()->bool:
	return encounters>=30 and boss_ids().all(func(id:String)->bool:return defeated.has(id))
func _rush_pending()->bool:
	return rooms.values().any(func(record:Dictionary)->bool:return record.kind=="boss_rush" and not record.cleared)
func _roll_kind()->String:
	if staged:return "elite" if stage_index==4 else "normal"
	if rush_unlocked() and encounters>=49 and not _rush_pending() and ((not rush_offered) or rng.randf()<.03):return "boss_rush"
	var weights:=RANDOM_WEIGHTS.duplicate()
	for index in RANDOM_KINDS.size():
		if completed_encounter<int(RoomExpansionRules.UNLOCK.get(RANDOM_KINDS[index],0)):weights[0]+=weights[index];weights[index]=0
	var value:=rng.randi_range(0,99)
	for index in RANDOM_KINDS.size():
		value-=weights[index]
		if value<0:return RANDOM_KINDS[index]
	return "normal"
func _ensure_rush_offer()->void:
	if staged:return
	# Offer a connected, optional room by wave 50. Never redirect an entrance.
	if rush_offered or not rush_unlocked() or encounters<49 or _rush_pending():return
	var origins:Array=[current]
	for id in rooms:
		if id!=current and rooms[id].cleared:origins.append(id)
	for origin:String in origins:
		for direction in DIRECTIONS:
			var at:Vector2i=cell(origin)+direction;var id:=key(at)
			if rooms.has(id):continue
			rooms[id]=_allocate(at,"boss_rush","");_connect(origin,id);rush_offered=true;return

func _ensure_frontier() -> Array[String]:
	if staged:return []
	# Retained bosses and pruned branches may be disconnected. Only a frontier
	# reachable through cleared rooms counts as a way forward from this room.
	if not rooms.has(current) or not bool(rooms[current].cleared):return []
	var origins:Array[String]=[current];var paths:Dictionary={current:[current]}
	var cursor:=0
	while cursor<origins.size():
		var origin:=origins[cursor];cursor+=1
		for other in rooms[origin].doors:
			var id:=str(other)
			if not rooms.has(id) or cell(id)-cell(origin) not in DIRECTIONS:continue
			if not bool(rooms[id].visited) or not bool(rooms[id].cleared):return []
			if not paths.has(id):
				paths[id]=paths[origin].duplicate();paths[id].append(id);origins.append(id)
	for id in origins:
		for direction in DIRECTIONS:
			var at: Vector2i = cell(id) + direction
			if not rooms.has(key(at)):
				rooms[key(at)] = _allocate(at, "normal", "")
				_connect(id,key(at))
				var protected:Array[String]=[];protected.assign(paths[id]);protected.append(key(at));return protected
	return []

func clear_current(readings:int=0) -> bool:
	var record: Dictionary = rooms[current]
	if record.cleared or not is_combat(str(record.kind)): return false
	record.cleared = true
	completed_encounter=maxi(completed_encounter,int(record.encounter))
	cleared_count += 1
	altar_pacing.clears=int(altar_pacing.clears)+1
	if record.kind == "boss" and not defeated.has(record.boss): defeated.append(record.boss)
	if staged:
		if current==stage_terminal:
			stage_boss_cleared=true
			if stage_index==3:normal_clear_eligible=true
			if stage_index==4:boss_rush_completed=true
		return true
	var protected:=_ensure_frontier()
	protected.append_array(_ensure_altar_offer(readings))
	prune_rooms(protected)
	return true

func _ensure_altar_offer(readings:int)->Array[String]:
	if staged:return []
	var protected:Array[String]=[]
	if readings>=3 or int(altar_pacing.bonus)>=3 or int(altar_pacing.clears)<(7 if altar_pacing.seen else 4):return protected
	# Breadth-first through cleared, connected rooms; unopened fights cannot be
	# treated as a safe path to an existing altar or a new frontier.
	var origins:Array[String]=[current];var paths:Dictionary={current:[current]}
	var cursor:=0
	while cursor<origins.size():
		var id:=origins[cursor];cursor+=1
		for direction in DIRECTIONS:
			var adjacent:=key(cell(id)+direction)
			if adjacent not in rooms[id].doors or not rooms.has(adjacent):continue
			var record:Dictionary=rooms[adjacent]
			if record.kind=="altar" and not bool(record.visited):return protected
			if bool(record.cleared) and not paths.has(adjacent):
				paths[adjacent]=paths[id].duplicate();paths[adjacent].append(adjacent);origins.append(adjacent)
	for origin:String in origins:
		for direction:Vector2i in DIRECTIONS:
			var at:Vector2i=cell(origin)+direction;var id:=key(at)
			if rooms.has(id):continue
			# Bonus generation must not advance the ordinary room RNG stream.
			var old_seed:=rng.seed;var old_state:=rng.state
			rng.seed=old_seed^(0x4a173+int(altar_pacing.bonus)*7919+cleared_count)
			rooms[id]=_allocate(at,"altar","");rooms[id].delta.guaranteed_altar=true
			rng.seed=old_seed;rng.state=old_state
			_connect(origin,id);altar_pacing.bonus=int(altar_pacing.bonus)+1;altar_pacing.notice=id
			# Keep the approach only during this pruning pass, not permanently.
			protected.assign(paths[origin]);protected.append(id)
			return protected
	return protected

func take_altar_notice()->String:
	var value:=str(altar_pacing.notice);altar_pacing.notice=""
	return "命运祭坛已显现 · 打开地图查看入口" if not value.is_empty() and rooms.has(value) else ""

func prune_rooms(protected:Array[String]=[]) -> Array[String]:
	if staged:return []
	var removed:Array[String]=[]
	var oldest:Array=rooms.keys().filter(func(id:Variant)->bool:return str(id)!=current and str(id) not in protected and not unfinished_boss(rooms[id]))
	oldest.sort_custom(func(a:Variant,b:Variant)->bool:return int(rooms[a].get("retention_order",0))<int(rooms[b].get("retention_order",0)))
	for id:Variant in oldest:
		if rooms.size()<=MAX_RETAINED_ROOMS:break
		_retire_room(str(id));removed.append(str(id))
	# No room or door may retain an expired room's snapshot / uncollected loot.
	for record in rooms.values():
		record.doors=record.doors.filter(func(id:Variant)->bool:return rooms.has(str(id)))
	if rooms.has(current) and rooms[current].doors.is_empty():
		# Pruning a surrounding older graph must never strand the active room.
		var repair_id:=""
		for direction in DIRECTIONS:
			var at:Vector2i=cell(current)+direction
			var id:=key(at)
			if not rooms.has(id):rooms[id]=_allocate(at,"normal","")
			_connect(current,id);repair_id=id;break
		# Above repair adds at most one room, so retire the next oldest once.
		if rooms.size()>MAX_RETAINED_ROOMS:
			for id:Variant in oldest:
				if rooms.has(id) and str(id)!=repair_id:_retire_room(str(id));removed.append(str(id));break
	return removed

func _retire_room(id:String)->void:
	if staged:return
	if id==current or not rooms.has(id) or unfinished_boss(rooms[id]):return
	var record:Dictionary=rooms[id]
	# An expired, unvisited boss must be eligible to appear again later.
	if str(record.kind)=="boss" and not defeated.has(str(record.boss)):
		generated.erase(str(record.boss))
	rooms.erase(id)
	for retained in rooms.values():retained.doors.erase(id)

func neighbour(direction: Vector2i) -> String:
	var id := key(cell(current) + direction)
	return id if rooms[current].doors.has(id) else ""

func snapshot() -> Dictionary:
	return {"version":VERSION if staged else 2,"stage":stage_state() if staged else {}, "chapter_id":str(chapter_id), "rooms":rooms.duplicate(true), "current":current,
		"normal_clears":normal_clears,"cleared":cleared_count, "encounters":encounters, "completed_encounter":completed_encounter, "pity":pity,
		"generated":generated.duplicate(), "defeated":defeated.duplicate(),
		"service_batches":service_batches, "next_service":next_service,"room_serial":_room_serial,
		"rush_offered":rush_offered,
		"altar_pacing":altar_pacing.duplicate(true),
		"seed":str(rng.seed), "rng":str(rng.state)}

func restore(data: Dictionary) -> bool:
	var version := int(data.get("version",0))
	if version not in [1,2,VERSION] or not data.get("rooms",{}).has(data.get("current","")): return false
	if version==VERSION:
		if not data.get("stage",{}) is Dictionary:return false
		var state:Dictionary=data.get("stage",{})
		var layout:Dictionary=data.rooms
		var starts:Array=layout.keys().filter(func(id:Variant)->bool:return str(layout[id].get("kind",""))=="spawn")
		if starts.size()!=1:return false
		if not StageMapGenerator.validate({"rooms":layout,"spawn":str(starts[0]),"terminal":str(state.get("terminal",""))},int(state.get("index",0)),layout.size()<(40 if int(state.get("index",0))==4 else 20)).is_empty():return false
	staged=version==VERSION
	if staged:_restore_stage(data.get("stage",{}))
	else:_restore_stage({})
	chapter_id=ChapterCatalog.normalize(data.get("chapter_id",ChapterCatalog.FIRST))
	rooms = data.rooms.duplicate(true); current = str(data.current)
	_room_serial=int(data.get("room_serial",0))
	for record in rooms.values():
		record.encounter=int(record.get("encounter",0))
		if not record.has("retention_order"):
			_room_serial+=1;record.retention_order=_room_serial
		_room_serial=maxi(_room_serial,int(record.retention_order))
	normal_clears=int(data.get("normal_clears",0))
	cleared_count = int(data.get("cleared",0)); encounters = int(data.get("encounters",0))
	completed_encounter=int(data.get("completed_encounter",encounters if rooms[current].cleared else maxi(0,encounters-1)))
	pity = int(data.get("pity",0)); generated = data.get("generated",[]).duplicate(); defeated = data.get("defeated",[]).duplicate()
	rng.seed = int(data.get("seed",0)); rng.state = int(data.get("rng",0))
	service_batches = int(data.get("service_batches",0)); next_service = str(data.get("next_service","shop"))
	rush_offered=bool(data.get("rush_offered",false))
	var pacing:Dictionary=data.get("altar_pacing",{}) if data.get("altar_pacing",{}) is Dictionary else {}
	altar_pacing={"seen":bool(pacing.get("seen",not defeated.is_empty() or rooms.values().any(func(room:Dictionary)->bool:return room.kind=="altar"))),"clears":clampi(int(pacing.get("clears",0)),0,10),"bonus":clampi(int(pacing.get("bonus",0)),0,3),"notice":str(pacing.get("notice",""))}
	if version == 1: _migrate_services()
	prune_rooms()
	return true

func _migrate_services() -> void:
	# Preserve explored geometry and inventory; append safe rooms at a reachable frontier.
	var stocks := {"shop":{}, "tavern":{}}
	var ids: Array = [current]
	for id in rooms:
		if id != current: ids.append(id)
	for id in ids:
		var record: Dictionary = rooms[id]
		if not bool(record.get("service",false)): continue
		var runtime: Dictionary = record.delta.get("runtime",{})
		for kind in ["shop","tavern"]:
			if stocks[kind].is_empty() and not runtime.get(kind,{}).is_empty(): stocks[kind] = runtime[kind].duplicate(true)
	for kind in ["shop","tavern"]:
		var added := false
		# Prefer the current room; fully surrounded rooms use the nearest graph frontier.
		for id in ids:
			if added: break
			for direction in DIRECTIONS:
				var at: Vector2i = cell(str(id)) + direction
				if rooms.has(key(at)): continue
				var record := _allocate(at,kind,"")
				if not stocks[kind].is_empty(): record.delta.runtime = {kind:stocks[kind]}
				rooms[key(at)] = record; _connect(str(id),key(at)); added = true; break
	for record in rooms.values():
		record.erase("service")
		if is_combat(str(record.kind)) or record.kind == "spawn":
			var runtime: Dictionary = record.delta.get("runtime",{})
			runtime.erase("shop"); runtime.erase("tavern")


func _build_stage(readings:int)->void:
	stage_seed=run_seed^((stage_index*73856093)+19349663)
	var layout:=StageMapGenerator.generate(stage_seed,stage_index,StageRules.DEFAULT_ROOMS,readings,StageRules.RETRIES,completed_encounter)
	rooms.clear();stage_boss_cleared=false;stage_terminal=str(layout.terminal)
	rng.seed=stage_seed^0x73f129
	var terminal_depth:=int(layout.rooms[stage_terminal].depth)
	for id:String in layout.rooms:
		var source:Dictionary=layout.rooms[id]
		var boss_id:=str(boss_ids()[stage_index-1]) if source.kind=="boss" else ""
		var record:=_allocate(cell(id),str(source.kind),boss_id)
		record.seed=source.seed;record.doors=source.doors.duplicate();record.depth=int(source.depth);record.stage_index=stage_index
		record.strength=StageRules.strength(stage_index,int(source.depth),terminal_depth,id==stage_terminal)
		record.encounter=0
		rooms[id]=record
		if source.kind=="boss" and not generated.has(boss_id):generated.append(boss_id)
	current=str(layout.spawn);rooms[current].visited=true

func can_advance()->bool:
	return staged and stage_index<4 and stage_boss_cleared and current==stage_terminal and bool(rooms[current].rewarded)

func advance_stage(readings:int=0)->bool:
	if not can_advance():return false
	stage_index+=1
	optional_stage_entered=stage_index==4
	_build_stage(readings)
	return true

func visible_rooms()->Array[String]:
	var visible_ids:Array[String]=[]
	for id:String in rooms:
		if not staged or bool(rooms[id].visited) or bool(rooms[id].delta.get("fate_revealed",false)):
			if id not in visible_ids:visible_ids.append(id)
			if staged and bool(rooms[id].visited):
				for adjacent:String in rooms[id].doors:
					if adjacent not in visible_ids:visible_ids.append(adjacent)
	return visible_ids

func room_type_revealed(id:String)->bool:
	if not rooms.has(id):return false
	if not staged or bool(rooms[id].visited) or bool(rooms[id].delta.get("fate_revealed",false)):return true
	for adjacent:String in rooms[id].doors:
		if rooms.has(adjacent) and bool(rooms[adjacent].visited):return true
	return false

func stage_state()->Dictionary:
	return {"index":stage_index,"seed":str(stage_seed),"run_seed":str(run_seed),"terminal":stage_terminal,
		"boss_cleared":stage_boss_cleared,"normal_eligible":normal_clear_eligible,"optional_entered":optional_stage_entered,
		"rush_completed":boss_rush_completed,"extraction_committed":extraction_committed,"failed":run_failed}

func _restore_stage(state:Dictionary)->void:
	stage_index=clampi(int(state.get("index",1)),1,4);stage_seed=int(state.get("seed",0));run_seed=int(state.get("run_seed",0))
	stage_terminal=str(state.get("terminal",""));stage_boss_cleared=bool(state.get("boss_cleared",false))
	normal_clear_eligible=bool(state.get("normal_eligible",false));optional_stage_entered=bool(state.get("optional_entered",false))
	boss_rush_completed=bool(state.get("rush_completed",false));extraction_committed=bool(state.get("extraction_committed",false));run_failed=bool(state.get("failed",false))
