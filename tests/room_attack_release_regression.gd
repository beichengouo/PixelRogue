extends Node2D

class DummyPlayer:
	extends Node2D
	var hp:=1000.0
	var max_hp:=1000.0
	var hits:=0
	func take_damage(amount:float,_from:=Vector2.ZERO,_source:Node=null)->void:
		hp-=amount;hits+=1

class ContactProbeAlly:
	extends RoomAlly
	var last_source:Node
	func take_damage(amount:float,from:=Vector2.ZERO,source:Node=null)->void:
		last_source=source
		super.take_damage(amount,from,source)

var checks:=0
var failures:=0
var room:RoomLevel
var player:DummyPlayer
var fx:Node2D

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func _ready()->void:call_deferred("run")

func _record(layout:Dictionary)->Dictionary:
	return {"id":"0,0","kind":"normal","biome":"forest","seed":17,"delta":{},"doors":[],"terrain_layout":layout}

func _layout()->Dictionary:
	return {"room_rect":[0,0,828,468],"props":[],"water":[],"ground":[],"decor":[],"entities":[]}

func _wall()->Array:
	return [{"id":"attack_wall","kind":"stone","texture":"res://assets/room_mode/refinement/stone.png","position_px":[325,234],"render_width_px":30,"collision_polygon_px":[[-10,-60],[10,-60],[10,60],[-10,60]]}]

func _grazing_wall()->Array:
	return [{"id":"grazing_wall","kind":"stone","texture":"res://assets/room_mode/refinement/stone.png","position_px":[300,251],"render_width_px":30,"collision_polygon_px":[[-10,-14],[10,-14],[10,14],[-10,14]]}]

func _projectiles()->int:
	var count:=0
	for child in fx.get_children():
		if child is RoomProjectile and not child.is_queued_for_deletion():count+=1
	return count

func _enemy(kind:StringName,at:Vector2)->RoomEnemy:
	var result:=RoomEnemy.new();result.configure(kind);result.room=room;result.setup(player,room,1,1,1);result.fx_root=fx;result.position=at;add_child(result)
	result.set_physics_process(false);result.hp=1000;result._action_cd=0
	return result

func _ally(index:int,at:Vector2)->RoomAlly:
	var result:=RoomAlly.new();result.room=room;result.setup({"uid":"test_%d"%index,"kind":"merc","merc_index":index,"name":"测试帮手"},player,room,fx);result.position=at;add_child(result)
	result.set_physics_process(false);result._cooldown=0
	return result

func run()->void:
	room=load("res://src/room_mode/room_level.tscn").instantiate();add_child(room);room.load_room(_record(_layout()))
	fx=Node2D.new();add_child(fx)
	player=DummyPlayer.new();player.position=Vector2(450,234);add_child(player)
	var caster:=_enemy(&"caster",Vector2(200,234))
	caster.think(.01)
	check(caster._windup>0,"enemy begins a real visible in-range windup")
	var before:=_projectiles();caster.think(.5)
	check(_projectiles()==before+1,"enemy windup releases one projectile in range")
	room.load_scene_objects(_wall(),"res://")
	caster._windup=0;caster._action_cd=0;caster.think(.01)
	check(caster._windup<=0,"enemy blocked line of sight prevents windup")
	room.load_scene_objects([],"res://")
	caster._action_cd=0;caster.think(.01)
	check(caster._windup>0,"enemy windup starts before a new obstacle")
	room.load_scene_objects(_wall(),"res://")
	before=_projectiles();caster.think(.5)
	check(_projectiles()==before,"enemy new line-of-sight obstacle cancels release")
	room.load_scene_objects([],"res://")
	player.position=Vector2(499,234);caster._action_cd=0;caster.think(.01)
	check(caster._windup>0,"enemy begins windup just inside 300px")
	player.position=Vector2(501,234)
	before=_projectiles();caster.think(.5)
	check(_projectiles()==before,"enemy target leaving 300px during windup cancels release")
	player.position=Vector2(390,234);room.load_scene_objects(_grazing_wall(),"res://")
	check(room.sight(caster.position,player.position),"grazing wall leaves zero-width center line visible")
	check(not room.projectile_clear(caster.position,player.position),"grazing wall blocks a 5px projectile")
	caster._windup=0;caster._action_cd=0;caster._nav_cd=0;caster.think(.01)
	check(caster._windup<=0 and caster.velocity.length()>0,"ranged enemy moves to clear a grazing projectile path")
	room.load_scene_objects([],"res://");caster._action_cd=0;caster._windup=0;caster.think(.01)
	check(caster._windup>0,"ranged enemy begins a windup before grazing wall appears")
	room.load_scene_objects(_grazing_wall(),"res://")
	before=_projectiles();caster.think(.5)
	check(_projectiles()==before,"ranged enemy cancels release when projectile would graze wall")
	room.load_scene_objects([],"res://")
	caster.position=Vector2(700,400);caster._action_cd=100
	player.position=Vector2(250,234)
	var walker:=_enemy(&"walker",Vector2(200,234))
	walker.think(.01)
	check(walker._windup>0,"melee enemy begins reachable windup")
	walker.think(.5)
	check(walker._rush>0,"melee enemy completes reachable windup")
	room.load_scene_objects([{"id":"melee_wall","kind":"stone","texture":"res://assets/room_mode/refinement/stone.png","position_px":[225,234],"render_width_px":20,"collision_polygon_px":[[-6,-40],[6,-40],[6,40],[-6,40]]}],"res://")
	walker._rush=0;walker._windup=0;walker._action_cd=0;walker.think(.01)
	check(walker._windup<=0,"melee enemy cannot start attack through real wall")
	walker.queue_free();await get_tree().process_frame
	room.load_scene_objects([],"res://")
	player.position=Vector2(300,234)
	for case in [[&"walker",75.0,52.0],[&"guard",64.0,44.0]]:
		var melee_enemy:=_enemy(case[0],player.position-Vector2(case[1],0))
		melee_enemy._nav_cd=0;melee_enemy.think(.01)
		check(melee_enemy._windup<=0 and melee_enemy.velocity.x>0,"%s pursues until its first lunge can reach contact"%case[0])
		melee_enemy.position=player.position-Vector2(case[2],0);melee_enemy._nav_cd=0;melee_enemy.think(.01)
		check(melee_enemy._windup>0,"%s starts windup at first-lunge contact distance"%case[0])
		melee_enemy.think(.5);melee_enemy.think(.12)
		check(case[2]-melee_enemy.velocity.length()*.12<=31.0,"%s first rush reaches the 20px contact area and 11px player body"%case[0])
		melee_enemy.queue_free()
	await get_tree().process_frame
	player.position=Vector2(760,400)
	var target:=_enemy(&"walker",Vector2(450,234));target._action_cd=100
	var archer:=_ally(1,Vector2(200,234))
	archer._physics_process(.01)
	check(archer.attack_clock>=0 and not archer.attack_released,"ranged ally begins windup in range")
	before=_projectiles();archer._physics_process(.2)
	check(_projectiles()==before+1,"ranged ally windup releases projectile")
	room.load_scene_objects(_wall(),"res://")
	archer.attack_clock=-1;archer._cooldown=0;archer._physics_process(.01)
	check(archer.attack_clock<0,"ranged ally blocked line of sight prevents windup")
	room.load_scene_objects([],"res://")
	archer._cooldown=0;archer._physics_process(.01)
	check(archer.attack_clock>=0,"ranged ally windup starts before new obstacle")
	room.load_scene_objects(_wall(),"res://")
	before=_projectiles();archer._physics_process(.2)
	check(_projectiles()==before,"ranged ally new obstacle cancels release")
	room.load_scene_objects([],"res://")
	archer.position=Vector2(200,234);target.position=Vector2(499,234);archer.attack_clock=-1;archer._cooldown=0;archer._physics_process(.01)
	check(archer.attack_clock>=0,"ranged ally begins windup just inside 300px")
	target.position=Vector2(550,234)
	before=_projectiles();archer._physics_process(.2)
	check(_projectiles()==before,"ranged ally target leaving range cancels release")
	archer.position=Vector2(200,234);target.position=Vector2(390,234);archer.nav_timer=0;archer.attack_clock=-1;archer._cooldown=0
	room.load_scene_objects(_grazing_wall(),"res://")
	check(room.sight(archer.position,target.position),"ally grazing wall leaves zero-width center line visible")
	check(not room.projectile_clear(archer.position,target.position),"ally grazing wall blocks a 5px projectile")
	archer._physics_process(.01)
	check(archer.attack_clock<0 and archer.velocity.length()>0,"ranged ally moves to clear a grazing projectile path")
	archer.position=Vector2(200,234)
	room.load_scene_objects([],"res://");archer.nav_timer=0;archer._cooldown=0;archer._physics_process(.01)
	check(archer.attack_clock>=0,"ranged ally begins windup before grazing wall appears")
	room.load_scene_objects(_grazing_wall(),"res://")
	before=_projectiles();archer._physics_process(.2)
	check(_projectiles()==before,"ranged ally cancels release when projectile would graze wall")
	room.load_scene_objects([],"res://")
	archer.queue_free();await get_tree().process_frame
	var swordsman:=_ally(0,Vector2(200,234));target.position=Vector2(245,234);target.hp=1000
	swordsman._physics_process(.01)
	check(swordsman.attack_clock>=0,"melee ally begins reachable windup")
	var hp_before:=target.hp;swordsman._physics_process(.2)
	check(target.hp<hp_before,"melee ally windup lands reachable hit")
	var water:={"room_rect":[0,0,828,468],"props":[],"water":[],"ground":[],"decor":[],"entities":[],"scene_water_polygons_px":[[[216,210],[222,210],[222,260],[216,260]]]}
	swordsman.attack_clock=-1;swordsman._cooldown=0;target.hp=1000;swordsman._physics_process(.01)
	check(swordsman.attack_clock>=0,"melee ally starts windup before water appears")
	room.load_room(_record(water))
	hp_before=target.hp;swordsman._physics_process(.2)
	check(is_equal_approx(target.hp,hp_before),"melee ally new water barrier cancels release")
	swordsman.attack_clock=-1;swordsman._cooldown=0;target.hp=1000;swordsman._physics_process(.01)
	check(swordsman.attack_clock<0 and room.sight(swordsman.position,target.position) and not room.segment_clear(swordsman.position,target.position,swordsman.body_radius()),"melee ally cannot begin attack across visible water")
	swordsman.queue_free();target.queue_free();await get_tree().process_frame
	room.load_room(_record(_layout()))
	var primary:=_enemy(&"walker",Vector2(330,230));primary._action_cd=100
	var secondary:=_enemy(&"walker",Vector2(370,230));secondary._action_cd=100
	var summon:=SummonedAlly.new();summon.room=room;summon.monster_base_hp=100;summon.monster_base_attack=20
	summon.setup({"uid":"test_summon","kind":"monster","enemy_kind":"walker","name":"召唤战士"},player,room,fx)
	summon.position=Vector2(310,230);add_child(summon);summon.set_physics_process(false)
	summon.attack_direction=Vector2.RIGHT;summon.attack_target=weakref(primary)
	water.scene_water_polygons_px=[[[345,205],[350,205],[350,255],[345,255]]]
	room.load_room(_record(water))
	check(room.sight(summon.position,secondary.position) and not room.segment_clear(summon.position,secondary.position,summon.body_radius()),"summon splash target is visible across impassable water")
	var primary_before:=primary.hp;var secondary_before:=secondary.hp
	summon._release_attack(true)
	check(primary.hp<primary_before,"summon melee hits reachable primary target")
	check(is_equal_approx(secondary.hp,secondary_before),"summon melee splash does not cross water")
	summon.queue_free();primary.queue_free();secondary.queue_free();await get_tree().process_frame
	room.load_room(_record(_layout()))
	player.position=Vector2(400,234);player.hp=1000
	var bomber:=_enemy(&"bomber",Vector2(200,234))
	var near_ally:=_ally(0,Vector2(240,234));near_ally.hp=1000
	var side_ally:=_ally(0,Vector2(200,290));side_ally.hp=1000
	var far_ally:=_ally(0,Vector2(320,234));far_ally.hp=1000
	bomber._update_aggro(.5)
	check(bomber.attack_target()==near_ally,"bomber chooses the nearby ally over a distant player")
	bomber.think(.01)
	check(bomber._windup>0,"bomber winds up on its allied target")
	var blast_damage:=bomber.attack_damage()*1.3
	bomber.think(.7)
	check(is_equal_approx(near_ally.hp,1000-blast_damage) and is_equal_approx(side_ally.hp,1000-blast_damage),"bomber blast hits each nearby ally once, including its locked target")
	check(is_equal_approx(far_ally.hp,1000) and is_equal_approx(player.hp,1000),"bomber blast leaves out-of-range units untouched")
	room.load_scene_objects([{"id":"blast_wall","kind":"stone","texture":"res://assets/room_mode/refinement/stone.png","position_px":[220,234],"render_width_px":20,"collision_polygon_px":[[-5,-50],[5,-50],[5,50],[-5,50]]}],"res://")
	near_ally.hp=1000;side_ally.hp=1000;player.position=Vector2(175,234)
	bomber._release()
	check(is_equal_approx(near_ally.hp,1000),"bomber blast cannot hit an ally through a real wall")
	check(is_equal_approx(side_ally.hp,1000-blast_damage) and is_equal_approx(player.hp,1000-blast_damage),"bomber blast hits visible player and ally once each")
	bomber.queue_free();near_ally.queue_free();side_ally.queue_free();far_ally.queue_free()
	await get_tree().process_frame
	room.load_scene_objects([{"id":"thin_contact_wall","kind":"stone","texture":"res://assets/room_mode/refinement/stone.png","position_px":[220,234],"render_width_px":8,"collision_polygon_px":[[-1,-40],[1,-40],[1,40],[-1,40]]}],"res://")
	var contact_enemy:=_enemy(&"walker",Vector2(206,234))
	var contact_ally:=ContactProbeAlly.new();contact_ally.room=room
	contact_ally.setup({"uid":"contact_probe","kind":"merc","merc_index":0,"name":"接触测试"},player,room,fx)
	contact_ally.position=Vector2(234,234);add_child(contact_ally);contact_ally.set_physics_process(false);contact_ally.hp=1000
	await get_tree().physics_frame;await get_tree().physics_frame
	check(contact_enemy.contact_area.get_overlapping_bodies().has(contact_ally),"thin wall leaves real contact areas overlapping across its two sides")
	check(not room.segment_clear(contact_enemy.global_position,contact_ally.global_position,contact_enemy.body_radius()),"real thin wall blocks body-sized contact path")
	contact_enemy._check_contact()
	check(is_equal_approx(contact_ally.hp,1000),"overlapping contact area does not damage an ally through a thin wall")
	room.load_scene_objects([],"res://")
	await get_tree().physics_frame;await get_tree().physics_frame
	contact_enemy._contact_cd=0;contact_ally.hp=1000
	var touch_damage:=contact_enemy.attack_damage()*0.8
	contact_enemy._check_contact()
	check(is_equal_approx(contact_ally.hp,1000-touch_damage) and contact_ally.last_source==contact_enemy,"unblocked contact damages ally once with enemy attribution")
	contact_enemy._check_contact()
	check(is_equal_approx(contact_ally.hp,1000-touch_damage) and contact_enemy._contact_cd>0,"contact cooldown prevents duplicate damage")
	caster.queue_free();contact_enemy.queue_free();contact_ally.queue_free()
	await get_tree().process_frame
	var tile_layout:=_layout()
	tile_layout.props=[{"at":[8,6],"size":[1,1],"kind":"stone","model":""}]
	room.load_room(_record(tile_layout))
	var grazing_from:=Vector2(200,213)
	var grazing_to:=Vector2(390,213)
	check(room.sight(grazing_from,grazing_to) and not room.projectile_clear(grazing_from,grazing_to),"legacy tile corner blocks a 5px projectile despite clear center line")
	var service_layout:=_layout()
	service_layout.service_layout=true
	service_layout.service_props=[{"id":"grazing_table","asset":"table","position_px":[300,251],"width_px":26,"depth_px":34}]
	room.load_room(_record(service_layout))
	check(room.sight(grazing_from,grazing_to) and not room.projectile_clear(grazing_from,grazing_to),"service footprint corner blocks a 5px projectile despite clear center line")
	fx.queue_free();player.queue_free();room.queue_free()
	await get_tree().process_frame
	print("ROOM_ATTACK_RELEASE checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
