extends Node2D
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:call_deferred("run")
func run()->void:
 var pool:=RoomTemplatePool.new();pool.reload()
 check(pool.templates.size()==15 and pool.rejected.is_empty(),"all 15 builtin templates accepted: "+str(pool.rejected))
 var selected:Dictionary={}
 # Find one actual seed for every tavern across its authored biomes.
 for theme in ["forest","ruin","wetland"]:
  for seed_value in range(1,40):
   var doc:=pool.select(seed_value,"tavern",theme)
   if doc.is_empty():continue
   selected[str(doc.id)]={"seed":seed_value,"theme":theme}
 check(selected.has("tavern_veranda") and selected.has("tavern_waterfront") and not selected.has("illustrated_tavern_v01"),"pool offers current taverns and excludes retired star courtyard")
 for id in selected:
  var data:Dictionary={"id":"0,0","kind":"tavern","biome":selected[id].theme,"seed":selected[id].seed,"delta":{},"doors":["-1,0"],"cleared":true}
  var room:RoomLevel=load("res://src/room_mode/room_level.tscn").instantiate();add_child(room)
  room.load_room(data)
  await get_tree().physics_frame
  check(str(data.terrain_layout.get("template_id",""))==id,"new tavern uses actual pool selection "+id)
  var frozen:Dictionary=data.terrain_layout.duplicate(true)
  data.seed=999;data.biome="forest"
  room.load_room(data)
  check(data.terrain_layout==frozen,"saved tavern keeps layout "+id)
  room.free()
 var probe:RoomLevel=load("res://src/room_mode/room_level.tscn").instantiate();add_child(probe)
 for seed_value in range(1,65):
  var graph:=RoomGraph.new();graph.begin(seed_value)
  probe._select_room_template(graph.rooms["0,0"],pool)
  check(str(graph.rooms["0,0"].terrain_layout.get("template_id",""))=="forest_clearing","opening map uses morning clearing for seed %d"%seed_value)
  for data in graph.rooms.values():
   if str(data.kind)!="tavern":continue
   probe._select_room_template(data,pool)
   check(str(data.terrain_layout.get("template_id",""))=="tavern_waterfront","opening tavern uses waterfront for seed %d"%seed_value)
 var legacy:Dictionary={"id":"1,0","kind":"tavern","biome":"forest","seed":13,"doors":["0,0"],"delta":{"runtime":{"tavern":{"offers":["kept"]}}},"terrain_layout":{"template_id":"illustrated_tavern_v01","scene_art":"tavern_v01"}}
 check(probe._room_requires_template(legacy),"retired saved tavern requires replacement")
 probe.load_room(legacy)
 check(str(legacy.terrain_layout.get("template_id",""))=="tavern_waterfront","retired saved tavern loads waterfront replacement")
 check(legacy.delta.runtime.tavern.offers==["kept"],"tavern replacement preserves persistent service offers")
 var retired_forest:Dictionary={"id":"0,0","kind":"spawn","biome":"wetland","seed":15,"doors":[],"delta":{},"terrain_layout":{"template_id":"illustrated_forest_v01","scene_art":"forest_v01"}}
 check(probe._room_requires_template(retired_forest),"retired saved forest requires replacement")
 probe.load_room(retired_forest)
 check(str(retired_forest.terrain_layout.get("template_id",""))=="forest_clearing","retired opening forest loads morning clearing")
 check(not pool.templates.any(func(item):return str(item.id)=="illustrated_forest_v01"),"retired forest is absent from editor template pool")
 probe.free()
 print("ROOM_TEMPLATE_SELECTION checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
