class_name StageMapGenerator
extends RefCounted
## Data-only seeded frontier tree, bounded shortcuts and a protected terminal leaf.
const DIRS:=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]

static func id(at:Vector2i)->String:return "%d,%d"%[at.x,at.y]
static func at(key:String)->Vector2i:
	var parts:=key.split(",");return Vector2i(int(parts[0]),int(parts[1]))

static func generate(seed_value:int,stage:int,target:int=StageRules.DEFAULT_ROOMS,readings:int=0,attempt_limit:int=StageRules.RETRIES,completed:int=-1)->Dictionary:
	stage=clampi(stage,1,4);target=clampi(target,20,28)*(2 if stage==4 else 1)
	if completed<0:completed=(stage-1)*10
	for attempt in clampi(attempt_limit,0,StageRules.RETRIES):
		var rng:=RandomNumberGenerator.new();rng.seed=seed_value^(stage*104729)^(attempt*7919)
		var result:=_build(rng,stage,target,readings,seed_value,completed)
		if validate(result,stage).is_empty():result.attempts=attempt+1;result.fallback=false;return result
	# Deterministic comb tree guarantees connectivity, distant terminal and leaves.
	var rng:=RandomNumberGenerator.new();rng.seed=stage*15485863
	var fallback:=_build(rng,stage,target,readings,seed_value,completed,true)
	assert(validate(fallback,stage).is_empty(),"Invalid fallback stage topology")
	fallback.attempts=StageRules.RETRIES;fallback.fallback=true;return fallback

static func _build(rng:RandomNumberGenerator,stage:int,target:int,readings:int,seed_value:int,completed:int,safe:bool=false)->Dictionary:
	# Coordinates are occupancy only: doors are explicit tree/shortcut edges.
	var cells:Dictionary={Vector2i.ZERO:[]}
	var start:=Vector2i.ZERO
	if safe:
		var trunk:=target/2
		for x in range(1,trunk):
			var p:=Vector2i(x,0);var parent:=p+Vector2i.LEFT
			cells[p]=[parent];cells[parent].append(p)
		for x in target-trunk:
			var p:=Vector2i(x,1);var parent:=Vector2i(x,0)
			cells[p]=[parent];cells[parent].append(p)
	while cells.size()<target:
		var frontier:Dictionary={}
		for p:Vector2i in cells:
			for d:Vector2i in DIRS:
				var next:=p+d
				if not cells.has(next):frontier[next]=true
		var candidates:Array=frontier.keys();var weights:Array[float]=[];var total:=0.0
		for p:Vector2i in candidates:
			var neighbours:=0
			for d:Vector2i in DIRS:
				if cells.has(p+d):neighbours+=1
			var weight:float=[1.0,0.45,0.15,0.03][neighbours-1]
			weights.append(weight);total+=weight
		var roll:=rng.randf()*total;var selected:Vector2i=candidates.back()
		for i in candidates.size():
			roll-=weights[i]
			if roll<=0:selected=candidates[i];break
		var parents:Array[Vector2i]=[]
		for d:Vector2i in DIRS:
			if cells.has(selected+d):parents.append(selected+d)
		var parent:=parents[rng.randi_range(0,parents.size()-1)]
		cells[selected]=[parent];cells[parent].append(selected)
	var offset:=Vector2i((stage-1)*128,0)
	var records:Dictionary={}
	for p:Vector2i in cells:
		var links:Array=[]
		for next:Vector2i in cells[p]:links.append(id(next+offset))
		records[id(p+offset)]={"id":id(p+offset),"kind":"elite" if stage==4 else "normal","doors":links,"depth":0,"seed":str(rng.randi())}
	start+=offset
	var reachable:=distances(records,id(start));var end:=start;var farthest:=-1
	for key:String in records:
		if records[key].doors.size()==1 and int(reachable[key])>farthest:
			end=at(key);farthest=int(reachable[key])
	# Shortcuts never touch the boss leaf, never shorten its route below four doors,
	# and retain at least three dead ends for optional exploration.
	var pairs:Array=[]
	for key:String in records:
		for d:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
			var next:=id(at(key)+d)
			if records.has(next) and next not in records[key].doors and key!=id(end) and next!=id(end):pairs.append([key,next])
	_shuffle(pairs,rng)
	var loops:=0;var loop_budget:=0 if safe else rng.randi_range(1,3)
	for pair:Array in pairs:
		if loops>=loop_budget:break
		var left:String=pair[0];var right:String=pair[1]
		if int(distances(records,left)[right])<3:continue
		records[left].doors.append(right);records[right].doors.append(left)
		var leaves:=0
		for value:Dictionary in records.values():
			if value.doors.size()==1:leaves+=1
		if leaves<3 or int(distances(records,id(start))[id(end)])<4:
			records[left].doors.erase(right);records[right].doors.erase(left)
		else:loops+=1
	var final_distances:=distances(records,id(start))
	for key:String in records:records[key].depth=int(final_distances[key])
	var candidates:Array=records.keys();candidates.erase(id(start));candidates.erase(id(end));_shuffle(candidates,rng)
	# Depth-biased but random service placement; neither service is forced adjacent.
	for kind in ["shop","tavern"]:
		var index:=0;var score:=-INF
		for i in candidates.size():
			var depth:=float(records[candidates[i]].depth)/maxi(1,int(final_distances[id(end)]))
			var value:=rng.randf()-absf(depth-StageRules.SERVICE_DEPTH_BIAS)*0.6
			if value>score:score=value;index=i
		records[candidates.pop_at(index)].kind=kind
	var specials:=rng.randi_range(1,2)
	var reserved:=stage<=3 and readings<3
	for i in specials:
		var kind:="altar" if reserved and i==0 else ""
		if kind.is_empty():
			var choices:Array=["reward","game"]
			for candidate_kind in ["event","trial"]:
				if completed>=int(RoomExpansionRules.UNLOCK.get(candidate_kind,0)):choices.append(candidate_kind)
			if not reserved and completed>=int(RoomExpansionRules.UNLOCK.get("altar",4)):choices.append("altar")
			kind=choices[rng.randi_range(0,choices.size()-1)]
		records[candidates.pop_back()].kind=kind
	if stage<4:
		for i in stage:records[candidates.pop_back()].kind="elite"
	records[id(start)].kind="spawn";records[id(end)].kind="boss_rush" if stage==4 else "boss"
	return {"rooms":records,"spawn":id(start),"terminal":id(end),"seed":str(seed_value),"stage":stage,"target":target}

static func _shuffle(values:Array,rng:RandomNumberGenerator)->void:
	for i in range(values.size()-1,0,-1):
		var j:=rng.randi_range(0,i);var swap:Variant=values[i];values[i]=values[j];values[j]=swap
static func distances(rooms:Dictionary,start:String,blocked:String="")->Dictionary:
	if start==blocked:return {}
	var queue:Array[String]=[start];var found:Dictionary={start:0};var cursor:=0
	while cursor<queue.size():
		var key:=queue[cursor];cursor+=1
		for other:Variant in rooms[key].doors:
			var next:=str(other)
			if next!=blocked and rooms.has(next) and not found.has(next):found[next]=int(found[key])+1;queue.append(next)
	return found
static func validate(map:Dictionary,stage:int,legacy:bool=false)->Array[String]:
	var errors:Array[String]=[];var rooms:Dictionary=map.get("rooms",{})
	if stage<1 or stage>4:return ["invalid stage"]
	var start:=str(map.get("spawn",""));var end:=str(map.get("terminal",""))
	if not rooms.has(start) or not rooms.has(end):return ["missing endpoints"]
	var minimum:=40 if stage==4 else 20;var maximum:=56 if stage==4 else 28
	if legacy:minimum=20 if stage==4 else 10;maximum=28 if stage==4 else 14
	if rooms.size()<minimum or rooms.size()>maximum or rooms.size()!=int(map.get("target",rooms.size())):errors.append("room budget")
	var counts:Dictionary={};var special_count:=0
	for key:String in rooms:
		if str(rooms[key].get("id",""))!=key:errors.append("room identity")
		var kind:=str(rooms[key].kind);counts[kind]=int(counts.get(kind,0))+1
		if kind in StageRules.SPECIALS:special_count+=1
		for other:Variant in rooms[key].doors:
			if not rooms.has(str(other)) or at(str(other))-at(key) not in DIRS or key not in rooms[str(other)].doors:errors.append("invalid edge")
	for kind in ["spawn","shop","tavern","boss_rush" if stage==4 else "boss"]:
		if int(counts.get(kind,0))!=1:errors.append("quota "+kind)
	if special_count<1 or special_count>2:errors.append("special quota")
	if stage<4 and int(counts.get("elite",0))!=stage:errors.append("elite quota")
	if stage==4 and (counts.has("normal") or counts.has("boss")):errors.append("extreme types")
	if stage<4 and counts.has("boss_rush"):errors.append("premature rush")
	var reachable:=distances(rooms,start)
	if reachable.size()!=rooms.size():errors.append("unreachable")
	if start==end:errors.append("overlapping endpoints")
	if not legacy and rooms[end].doors.size()!=1:errors.append("boss must be a leaf")
	if int(reachable.get(end,0))<4:errors.append("boss too close")
	var leaves:=0
	for value:Dictionary in rooms.values():
		if value.doors.size()==1:leaves+=1
		var seen:Dictionary={}
		for door:Variant in value.doors:
			if seen.has(door):errors.append("duplicate edge")
			seen[door]=true
	if not legacy and leaves<3:errors.append("too few branches")
	return errors
