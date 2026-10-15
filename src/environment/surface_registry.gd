class_name SurfaceRegistry
extends RefCounted
var surfaces: Array[Dictionary] = []
var columns: Dictionary = {}
var level: Level
var water: Array[Dictionary] = []
func setup(world: Level) -> void:
	level = world
	surfaces.clear()
	columns.clear()
	water.clear()
	var authored := level.get_node_or_null("WaterAreas")
	if authored != null:
		for node in authored.find_children("*","Node2D",true,false):
			if node is WaterArea:
				water.append({"rect":Rect2(level.to_local(node.global_position),node.size*node.scale.abs()),"flow_speed":node.flow_speed,"ripple_strength":node.ripple_strength,"color_tint":node.color_tint})
	for cell: Vector2i in level.solid:
		if level.is_solid_cell(cell+Vector2i.UP): continue
		var x := level.tile_origin().x+cell.x*36.0
		var y := level.tile_origin().y+cell.y*36.0
		var source := level.tiles.get_cell_source_id(cell)
		if source==16: continue
		var material := "stone" if source/4 == 2 else "mud" if source/4 == 1 else "grass"
		if source/4 == 3: material = "wood"
		if source==20: material = "soil"
		if material=="grass" and not level.is_one_way_cell(cell):
			if x>=level.shop_spawn.x-150 and x<level.tavern_spawn.x+150 and absf(y-level.shop_spawn.y-21)<2: material = "soil"
		for pond in water:
			if x>=pond.rect.position.x and x<pond.rect.end.x and absf(y-pond.rect.end.y)<2: material = "water"
		register(Rect2(x,y,36,1),material,false)
	# Roof anchors use the same ground-aligned NPC markers as building sprites.
	register_building_roof("shop",level.shop_spawn)
	register_building_roof("tavern",level.tavern_spawn)
	for pond in water:
		var waterline := register(Rect2(pond.rect.position,Vector2(pond.rect.size.x,1)),"water",false)
		waterline["waterline"] = true
	# Static geometry is authored once per level load. Cache cover instead of
	# querying each roof column again for every blade and render frame.
	for record in surfaces:
		record["covered"] = sheltered(record.rect.position+Vector2(record.rect.size.x*0.5,-1))
func register(rect: Rect2, material: String, shelter: bool) -> Dictionary:
	var record := {"rect":rect,"material":material,"shelter":shelter,"zone":WorldMapV2.zone_at(rect.position.x),"normal":Vector2.UP}
	surfaces.append(record)
	for x in range(floori(rect.position.x/36.0),ceili(rect.end.x/36.0)):
		if not columns.has(x): columns[x] = []
		columns[x].append(record)
	return record
func register_building_roof(name: String, anchor: Vector2) -> void:
	var texture: Texture2D = load("res://assets/round5/buildings/"+name+".png")
	var image := TexturePixels.image(texture)
	var origin := anchor+Vector2(-image.get_width()*0.5,21-image.get_height())
	var tops := PackedInt32Array()
	tops.resize(image.get_width())
	for x in image.get_width():
		tops[x] = image.get_height()
		for y in image.get_height():
			if image.get_pixel(x,y).a>0.65:
				tops[x] = y
				break
	var edges := [origin+Vector2(6,tops[6]+3),origin+Vector2(image.get_width()-7,tops[image.get_width()-7]+3)]
	for x in range(0,image.get_width(),4):
		var y := image.get_height()
		for column in range(x,mini(x+4,image.get_width())): y = mini(y,tops[column])
		if y==image.get_height(): continue
		var record := register(Rect2(origin+Vector2(x,y),Vector2(4,1)),"roof",true)
		record["drip_positions"] = edges
func sample_surface(position: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var distance := 48.0
	for record in columns.get(floori(position.x/36.0),[]):
		if record.shelter or position.x < record.rect.position.x or position.x >= record.rect.end.x: continue
		var d := absf(record.rect.position.y-position.y)
		# A grounded actor touches the shallow pond floor physically, while
		# splashes, entry ripples and footsteps belong to its visible waterline.
		if record.get("waterline",false) and d<48:
			best = record.duplicate()
			best["position"] = Vector2(position.x,record.rect.position.y)
			return best
		if d < distance:
			distance = d
			best = record.duplicate()
			best["position"] = Vector2(position.x,record.rect.position.y)
	return best
func trace_surface(from: Vector2, to: Vector2) -> Dictionary:
	if to.y <= from.y: return {}
	var best: Dictionary = {}
	var first := 2.0
	var start := mini(floori(from.x/36),floori(to.x/36))
	var end := maxi(floori(from.x/36),floori(to.x/36))
	for column in range(start,end+1):
		for record in columns.get(column,[]):
			var t: float = (record.rect.position.y-from.y)/(to.y-from.y)
			if t < 0 or t > 1 or t >= first: continue
			var hit := from.lerp(to,t)
			if hit.x < record.rect.position.x or hit.x >= record.rect.end.x: continue
			first = t
			best = record.duplicate()
			best["position"] = hit
	return best
func sheltered(position: Vector2) -> bool:
	for record in columns.get(floori(position.x/36),[]):
		if record.rect.position.y < position.y-2 and position.x >= record.rect.position.x and position.x < record.rect.end.x: return true
	return false
