extends Node2D
class DummyPlayer:
	extends Node2D
	var hp:=1000.0
class DummyMain:
	extends Node
	var level:RoomLevel
	var player:Node2D
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:call_deferred("run")
func record(layout:Dictionary,kind:="normal")->Dictionary:
	return {"id":"0,0","kind":kind,"biome":"forest","seed":17,"delta":{},"doors":[],"terrain_layout":layout}
func empty_layout()->Dictionary:
	return {"room_rect":[0,0,828,468],"props":[],"water":[],"ground":[],"decor":[],"entities":[]}
func run()->void:
	var room:RoomLevel=load("res://src/room_mode/room_level.tscn").instantiate();add_child(room)
	var template:=RoomTemplateCodec.blank()
	template.layers.obstacles.append({"id":"placed_crate","asset_id":"scene:flower_bend_v02:crate_a","at":[6,6],"config":{"offset_px":[12.5,-4.25]}})
	template.layers.entities.append({"id":"placed_lamp","asset_id":"scene:flower_bend_v02:lamp_east","at":[14,5],"config":{"offset_px":[2.5,3.25]}})
	var layout:=RoomTemplateCodec.to_layout(template)
	check(not layout.is_empty(),"scene palette template validates")
	check(layout.get("props",[]).is_empty(),"palette scene crate avoids whole-tile collision")
	check(layout.get("entities",[]).is_empty(),"palette scene light avoids duplicate entity")
	var placed:Dictionary={}
	for item in layout.get("scene_objects",[]):placed[item.id]=item
	check(placed.has("placed_crate") and placed.has("placed_lamp"),"palette objects retain stable IDs")
	if placed.has("placed_crate"):
		check(Vector2(placed.placed_crate.position_px[0],placed.placed_crate.position_px[1]).distance_to(Vector2(246.5,229.75))<0.01,"palette offset remains pixel precise")
		check(placed.placed_crate.collision_polygon_px.size()>=3,"palette collision polygon retained")
	room.load_room(record(layout))
	check(room.scene_polygons.has("placed_crate") and room.scene_polygons.has("placed_lamp"),"palette polygons reach runtime navigation")
	var crate:RoomProp
	for node in room.props_root.get_children():
		if node is RoomProp and node.scene_object_id=="placed_crate":crate=node
	check(is_instance_valid(crate),"palette crate is damageable")
	if is_instance_valid(crate):crate.take_damage(100)
	check(room.record.delta.get("scene_broken",[]).has("placed_crate"),"palette destruction persists by ID")
	var water:=empty_layout();water.water=[[10,5],[11,5],[10,6],[11,6]]
	water.scene_water_polygons_px=[[[330,180],[410,180],[410,210],[370,210],[370,250],[330,250]]]
	room.load_room(record(water))
	check(room.water_surface_at(Vector2(350,230)),"exact wetland water recognized")
	check(not room.water_surface_at(Vector2(394,230)),"dry notch stays dry despite coarse water cell")
	var player:=DummyPlayer.new();player.position=Vector2(700,230);add_child(player)
	var main:=DummyMain.new();main.level=room;main.player=player;add_child(main)
	var weather:=RoomWeatherVisual.new();weather.main=main;weather.weather=WeatherState.new();add_child(weather);weather.set_process(false)
	weather.weather.snow[0]=0.8
	check(weather.sample_surface(Vector2(350,230)).material=="water","rain contact samples exact water")
	check(weather.sample_surface(Vector2(394,230)).material!="water","rain contact preserves dry notch")
	check(weather.surface_snow_at(Vector2(350,230))==0.0,"snow excludes exact water")
	check(weather.surface_snow_at(Vector2(394,230))==0.0,"disabled snow accumulation leaves dry notch unchanged")
	var service:=empty_layout();service.service_layout=true
	service.service_props=[{"id":"authored_shop","asset":"building_shop","role":"building","texture_path":"res://assets/room_mode/structure/building_shop.png","position_px":[500,170],"width_px":220,"depth_px":90,"collision_polygon_px":[[-35,-50],[35,-50],[35,-10],[-35,-10]]}]
	room.load_room(record(service,"shop"))
	check(is_instance_valid(room.service_building) and room.service_building is RoomServiceProp,"authored building keeps service interaction")
	check(room.scene_polygons.has("service:authored_shop"),"authored building polygon reaches navigation")
	check(room.scene_occlusion.entries.size()>0,"authored building art participates in occlusion")
	check(not room.body_clear(Vector2(500,140),8),"authored building foot blocks")
	check(room.body_clear(Vector2(580,140),8),"building artwork outside foot remains walkable")
	var combat:=empty_layout()
	combat.scene_objects=[{"id":"wall","kind":"stone","texture":"res://assets/room_mode/refinement/stone.png","position_px":[414,234],"render_width_px":52,"collision_polygon_px":[[-25,-78],[25,-78],[25,78],[-25,78]]}]
	room.load_room(record(combat))
	player.position=Vector2(570,234)
	var enemy:=RoomEnemy.new();enemy.configure(&"walker");enemy.room=room;enemy.setup(player,room,1,1,1);enemy.position=Vector2(260,234);add_child(enemy)
	enemy._action_cd=100.0
	check(not room.sight(enemy.position,player.position),"real obstruction blocks enemy line of sight")
	check(not room.firing_position(Vector2(260,234),player.position,190,12)==Vector2(260,234),"ranged position seeks around real obstruction")
	var safe:=true
	for frame in 360:
		await get_tree().physics_frame
		if not room.body_clear(enemy.global_position,enemy.body_radius()-.5):safe=false
	check(safe,"enemy body never crosses scene collision")
	check(enemy.global_position.x>440,"enemy routes around real obstruction")
	enemy.set_physics_process(false);enemy.global_position=Vector2(570,234);enemy.hp=10000
	player.position=Vector2(260,234)
	var ally:=RoomAlly.new();ally.room=room;ally.setup({"uid":"test_archer","kind":"merc","merc_index":1,"name":"弓手"},player,room,self);ally.position=Vector2(260,234);add_child(ally)
	ally._cooldown=100.0
	var ally_safe:=true
	for frame in 360:
		await get_tree().physics_frame
		if not room.body_clear(ally.global_position,ally.body_radius()-.5):ally_safe=false
	check(ally_safe,"ranged ally body never crosses scene collision")
	check(ally.global_position.distance_to(Vector2(260,234))>120 and ally.global_position.distance_to(enemy.global_position)<=300 and room.sight(ally.global_position,enemy.global_position),"ranged ally reaches effective line-of-sight position")
	ally.queue_free();await get_tree().process_frame
	var swordsman:=RoomAlly.new();swordsman.room=room;swordsman.setup({"uid":"test_sword","kind":"merc","merc_index":0,"name":"剑士"},player,room,self);swordsman.position=Vector2(260,234);add_child(swordsman)
	swordsman._cooldown=100.0
	var melee_safe:=true
	for frame in 420:
		await get_tree().physics_frame
		if not room.body_clear(swordsman.global_position,swordsman.body_radius()-.5):melee_safe=false
	check(melee_safe,"melee ally body never crosses scene collision")
	check(swordsman.global_position.x>440,"melee ally routes to target around real obstruction")
	swordsman.queue_free();enemy.queue_free();await get_tree().process_frame
	player.position=Vector2(570,234)
	var caster:=RoomEnemy.new();caster.configure(&"caster");caster.room=room;caster.setup(player,room,1,1,1);caster.position=Vector2(260,234);add_child(caster)
	caster._action_cd=100.0
	var caster_safe:=true
	for frame in 360:
		await get_tree().physics_frame
		if not room.body_clear(caster.global_position,caster.body_radius()-.5):caster_safe=false
	check(caster_safe,"ranged enemy body never crosses scene collision")
	check(caster.global_position.distance_to(Vector2(260,234))>120 and caster.global_position.distance_to(player.global_position)<=300 and room.sight(caster.global_position,player.global_position),"ranged enemy reaches effective line-of-sight position")
	caster.queue_free();await get_tree().process_frame
	var crowd:Array[RoomEnemy]=[]
	for at in [Vector2(260,220),Vector2(260,248)]:
		var member:=RoomEnemy.new();member.configure(&"walker");member.room=room;member.setup(player,room,1,1,1);member.position=at;add_child(member);member._action_cd=100.0;crowd.append(member)
	for frame in 360:await get_tree().physics_frame
	var crowd_progress:=true
	for member in crowd:
		if member.global_position.distance_to(Vector2(260,234))<130 or not room.body_clear(member.global_position,member.body_radius()-.5):crowd_progress=false
	check(crowd_progress,"multiple enemies make progress around shared obstruction without clipping")
	check(crowd[0].global_position.distance_to(crowd[1].global_position)>20,"enemy crowd remains separated")
	for member in crowd:member.queue_free()
	await get_tree().process_frame
	var moat:=empty_layout();moat.scene_water_polygons_px=[[[400,200],[420,200],[420,260],[400,260]]]
	room.load_room(record(moat));player.position=Vector2(440,230)
	var walker:=RoomEnemy.new();walker.configure(&"walker");walker.room=room;walker.setup(player,room,1,1,1);walker.position=Vector2(380,230);add_child(walker);walker.set_physics_process(false)
	walker.aggro=player;walker._action_cd=0;walker.think(0.016)
	check(room.sight(walker.position,player.position) and not room.segment_clear(walker.position,player.position,walker.body_radius()),"water allows sight but blocks body corridor")
	check(walker._windup<=0,"melee enemy does not attack across impassable water")
	walker.queue_free()
	await get_tree().process_frame
	weather.queue_free();main.queue_free();player.queue_free();room.queue_free()
	print("ROOM_SCENE_AI checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
