class_name RoomLayout
extends RefCounted
const CELL := 36
const SIZE := Vector2i(19,11)
const RECT := Rect2(Vector2.ZERO,Vector2(684,396))

static func center(at: Vector2i) -> Vector2:
	return (Vector2(at)+Vector2(0.5,0.5))*CELL

const DIRECTIONS := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
const SOLIDS := ["pillar","ruined_pillar","boulder","rubble","stump","log","barricade","arch","altar"]
const DECOR := ["fern","flowers","bones","jar","shrub","planks"]
static func generate(seed_value:int, kind:String, region:=Rect2i(Vector2i.ZERO,SIZE))->Dictionary:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var result:Dictionary={"version":2,"crates":[],"stones":[],"water":[],"decor":[],"ground":[],"base_ground":"grass","models":{},"motif":rng.randi_range(0,7)}
	if kind not in ["normal","boss"]:return result
	var middle:=Vector2i(9,5)
	var solids:Array= ["stump","log","boulder"] if int(result.motif) in [0,4,5,6] else ["pillar","ruined_pillar","rubble"]
	var decor_palette:Array=["fern","flowers","shrub"] if int(result.motif) in [0,4,5,6] else ["bones","jar","planks"]
	var reserved:Dictionary={}
	# Two-cell approaches bend before reaching the center, so the safety routes
	# do not impose an identical three-cell cross on every generated room.
	for direction in DIRECTIONS:
		var end:=Vector2i(middle.x,region.position.y) if direction==Vector2i.UP else (Vector2i(middle.x,region.end.y-1) if direction==Vector2i.DOWN else (Vector2i(region.position.x,middle.y) if direction==Vector2i.LEFT else Vector2i(region.end.x-1,middle.y)))
		var side:=Vector2i(-direction.y,direction.x)
		var at:=end
		var bend:=rng.randi_range(-2,2)
		while at!=middle:
			for offset in [Vector2i.ZERO,side]:
				if region.has_point(at+offset):reserved[at+offset]=true
			if at.distance_to(end)>2 and at.distance_to(middle)>3 and bend!=0:
				for step in absi(bend):at+=side*signi(bend);reserved[at]=true;reserved[at-direction]=true
				bend=0
			if at.x!=middle.x and (direction.y==0 or at.y==middle.y):at.x+=signi(middle.x-at.x)
			elif at.y!=middle.y:at.y+=signi(middle.y-at.y)
			else:at.x+=signi(middle.x-at.x)
	for y in range(middle.y-(3 if kind=="boss" else 1),middle.y+(4 if kind=="boss" else 2)):
		for x in range(middle.x-(5 if kind=="boss" else 1),middle.x+(6 if kind=="boss" else 2)):reserved[Vector2i(x,y)]=true
	var blocked:Dictionary={}
	var motif:int=result.motif
	var pools:Array[Rect2i]=[]
	if motif in [0,4,5,6]:
		for side in [-1,1]:
			var base:=middle+Vector2i(side*rng.randi_range(4,7),rng.randi_range(-3,2))
			pools.append(Rect2i(base,Vector2i(rng.randi_range(2,4),rng.randi_range(2,4))))
	for y in range(region.position.y+1,region.end.y-1):
		for x in range(region.position.x+1,region.end.x-1):
			var at:=Vector2i(x,y)
			if reserved.has(at):continue
			var watery:=false
			for pool in pools:
				if pool.has_point(at):watery=true;break
			var eligible:=false
			match motif:
				0:eligible=(x+y)%7==0
				1:eligible=x%5 in [1,2] and y%4 in [1,2]
				2:eligible=(x*13+y*7+seed_value)%11<3
				3:eligible=(y%4==1 and x%6<4) or (x%7==2 and y%3<2)
				4:eligible=x%6==2 and y%3==1
				5:eligible=(x+y)%8 in [0,1]
				6:eligible=(x*3+y*5)%13<3
				7:eligible=(x%5==2 and y%6<4) or (y%5==2 and x%7<3)
			if not watery and (not eligible or rng.randf()>.82):continue
			blocked[at]=true
			if not connected(blocked,region):blocked.erase(at);continue
			var pair:=[x,y]
			if watery:result.water.append(pair)
			elif rng.randf()<.26:result.crates.append(pair);result.models["%d,%d"%[x,y]]="crate_iron"
			else:
				result.stones.append(pair)
				result.models["%d,%d"%[x,y]]=solids[rng.randi_range(0,solids.size()-1)]
	for y in range(region.position.y+1,region.end.y-1):
		for x in range(region.position.x+1,region.end.x-1):
			var at:=Vector2i(x,y)
			if blocked.has(at):continue
			if reserved.has(at):continue
			if rng.randf()<.07:result.decor.append({"at":[x,y],"model":decor_palette[rng.randi_range(0,decor_palette.size()-1)]})
	result.props=[]
	var claimed:Dictionary={}
	var water:Dictionary={}
	for pair in result.water:water[Vector2i(pair[0],pair[1])]=true
	for prop_kind in ["crate","stone"]:
		var pairs:Array=result.crates if prop_kind=="crate" else result.stones
		for pair in pairs.duplicate():
			var at:=Vector2i(pair[0],pair[1])
			if claimed.has(at):continue
			var size:Vector2i=[Vector2i.ONE,Vector2i(2,2),Vector2i(1,2),Vector2i(2,1)][rng.randi_range(0,3)]
			var cells:Array[Vector2i]=[]
			var added:Array[Vector2i]=[]
			var valid:=true
			for y in range(size.y):
				for x in range(size.x):
					var cell:=at+Vector2i(x,y)
					cells.append(cell)
					if not region.grow(-1).has_point(cell) or reserved.has(cell) or claimed.has(cell) or water.has(cell):valid=false
					if blocked.has(cell) and not pairs.has([cell.x,cell.y]):valid=false
			if valid:
				for cell in cells:
					if not blocked.has(cell):blocked[cell]=true;added.append(cell)
				if not connected(blocked,region):valid=false
			if not valid:
				for cell in added:blocked.erase(cell)
				size=Vector2i.ONE;cells=[at];added.clear()
			for cell in cells:claimed[cell]=true
			for cell in added:pairs.append([cell.x,cell.y])
			result.props.append({"at":[at.x,at.y],"size":[size.x,size.y],"kind":prop_kind,"model":result.models.get("%d,%d"%[at.x,at.y],"boulder")})
	result.decor=result.decor.filter(func(entry):return not blocked.has(Vector2i(entry.at[0],entry.at[1])))
	var occupied_decor:Dictionary={}
	var distinct_decor:Array=[]
	for entry in result.decor:
		var at:=Vector2i(entry.at[0],entry.at[1])
		if occupied_decor.has(at):continue
		var size:Vector2i=RoomTerrainCatalog.SIZES[rng.randi_range(0,3)]
		var valid:=true
		for y in size.y:
			for x in size.x:
				var cell:=at+Vector2i(x,y)
				if blocked.has(cell) or reserved.has(cell) or occupied_decor.has(cell) or not region.grow(-1).has_point(cell):valid=false
		if not valid:size=Vector2i.ONE
		entry.size=[size.x,size.y]
		distinct_decor.append(entry)
		for y in size.y:
			for x in size.x:occupied_decor[at+Vector2i(x,y)]=true
	result.decor=distinct_decor
	return result

static func connected(blocked:Dictionary,region:=Rect2i(Vector2i.ZERO,SIZE))->bool:
	var open: Array[Vector2i] = [Vector2i(9,5)]
	var reached := {Vector2i(9,5):true}
	var index := 0
	while index < open.size():
		var at := open[index]; index += 1
		for direction in DIRECTIONS:
			var next: Vector2i = at + direction
			if not region.has_point(next) or blocked.has(next) or reached.has(next): continue
			reached[next] = true; open.append(next)
	return reached.size() == region.size.x*region.size.y-blocked.size()

static func encounter(progress: int, boss_id := "") -> Dictionary:
	var plan := WaveTable.build(progress)
	if boss_id.is_empty() and bool(plan.boss):
		# Original fixed boss checkpoints must not delete a normal room's roster.
		var adjacent := WaveTable.build(progress-1)
		for kind in WaveTable.KINDS: plan[kind] = adjacent[kind]
		plan.total = adjacent.total
	plan.boss = not boss_id.is_empty()
	if plan.boss:
		plan.total = 1
		plan.boss_hp_scale = maxf(1.0,float(plan.hp_scale)*1.25)
	return plan
