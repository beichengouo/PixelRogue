extends Node
class ProbeRoom:
	extends "res://src/room_mode/room_main.gd"
	func _ready()->void:pass
	func _autoplay_requested()->bool:return true
class ProbeAlly:
	extends HiredAlly
	func _ready()->void:add_to_group("allies")
var main:ProbeRoom
var actor:RoomPlayer
var gear:EquipmentMechanics
var checks:=0
var failures:=0
const IDS:Array[StringName]=[&"armor_storm_conductor",&"accessory_counterbeat",&"armor_mana_reservoir",&"accessory_last_flame",&"armor_orbit_guard",&"accessory_cadence_prism",&"relic_copper_metre",&"relic_aftertone",&"relic_dew_battery",&"relic_dry_wick",&"relic_sentinel_thread",&"relic_wayfarer_score"]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",message)
func _ready()->void:process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
func enemy(at:Vector2)->RoomEnemy:
	var node:=RoomEnemy.new();node.configure(&"walker");node.room=main.level;node.setup(actor,main.level,1,1,1);node.director=main.director;node.fx_root=main.fx_root;node.position=at;main.enemies_root.add_child(node);node.set_physics_process(false);node.hp=100000;node.max_hp=100000;return node
func acquire(ids:Array[StringName],count:=1)->void:
	GameState.items.clear();GameState._clear_equipment();GameState.temp_buffs.clear();GameState.talents.clear();GameState._reset_stats()
	gear.cadence=CadenceEquipment.new();gear.cadence.owner=gear;gear.cooldowns.clear();gear.clock=100
	for id in ids:
		for index in count:
			var item:=ItemDB.by_id(id).duplicate(true);GameState.items.append(item)
			if ItemDB.is_equippable(item):check(GameState.equip(item),"actual equip "+str(id))
	gear.refresh();actor.shield_hp=0;actor._shield_time=0;GameState.mp=20
func basic(target:EnemyBase,receipt:BasicAttackReceipt=null)->void:
	var projectile:=RoomProjectile.new();main.fx_root.add_child(projectile);projectile.set_physics_process(false)
	gear.on_basic_hit(target,BasicAttackReceipt.new(actor) if receipt==null else receipt,projectile);projectile.queue_free()
func status(id:String)->Dictionary:
	for row in PlayerStatusCatalog.snapshot(actor):
		if row.icon_id==id:return row
	return {}
func run()->void:
	check(OS.get_user_data_dir().begins_with("E:/CodexWorkspace/PixelRogue/work/"),"isolated saves")
	SaveService.data.control_setup_done=true;SaveService.data.run={};Outpost.data.active={};Characters.set_current(&"sylphiette")
	main=ProbeRoom.new();add_child(main);main._build_world();main._build_ui();main.set_process(false);await main._begin_run({"departure":{"loadout":[],"carried":0,"difficulty":1,"initial_level":1}})
	actor=main.player;gear=actor.equipment_mechanics;GameState.set_process(false)
	actor.set_physics_process(false);actor.holy_runtime.set_process(false);gear.set_process(false);main.director.set_process(false);main.special_rooms.set_process(false);main.expansion.set_process(false);main.expedition.set_process(false)
	actor.position=main.level.nearest_clear(main.level.bounds().get_center(),12)
	var target:=enemy(actor.position+Vector2(30,0));var neighbour:=enemy(actor.position+Vector2(55,0));var distant:=enemy(actor.position+Vector2(200,0))
	var ally:=ProbeAlly.new();ally.player=actor;ally.position=actor.position+Vector2(30,0);main.actors_root.add_child(ally);ally.set_physics_process(false);ally.hp=100;ally.max_hp=100
	for character in Characters.DATA:
		Characters.set_current(character)
		for id in IDS:
			var item:=ItemDB.by_id(id)
			check(not item.is_empty() and item.build_tags.size()>0,"valid item definition "+str(id))
			for pool in [&"shop",&"chest",&"reward"]:check(ItemDB.in_source(item,pool),"legal pool "+str(character)+str(id)+str(pool))
			var art:=ItemDB.icon_texture(item).get_image();check(art.get_size()==Vector2i(128,128),"standalone icon dimensions")
			var rect:=art.get_used_rect();check(rect.position.x>=10 and rect.position.y>=10 and rect.end.x<=118 and rect.end.y<=118,"complete subject safe alpha margin")
	Characters.set_current(&"sylphiette")
	var damage_events:Array=[]
	target.damage_applied.connect(func(_e:EnemyBase,amount:float,source:Node,kind:StringName)->void:damage_events.append({"amount":amount,"source":source,"kind":kind}))
	acquire([&"armor_storm_conductor"]);var shared:=BasicAttackReceipt.new(actor);basic(target,shared);basic(neighbour,shared)
	check(gear.cadence.storm_hits==1,"multishot and piercing grant only one storm beat")
	check(status("storm_conductor").stacks==1,"storm stacks and timer HUD")
	var hp:=target.hp;var near_hp:=neighbour.hp;var far_hp:=distant.hp
	for i in 3:basic(target)
	check(is_equal_approx(hp-target.hp,gear.attack()*.55) and is_equal_approx(near_hp-neighbour.hp,gear.attack()*.55) and far_hp==distant.hp,"fourth beat applies accurate bounded area damage")
	check(gear.cadence.storm_hits==0 and not gear.ready(&"storm_conductor"),"storm reset cooldown")
	basic(target);check(gear.cadence.storm_hits==0,"no accumulating beats during cooldown")
	gear.clock+=2;basic(target);gear.clock+=4.1;basic(target);check(gear.cadence.storm_hits==1,"expired chain starts at one")
	check(damage_events.size()==1 and damage_events[0].kind==&"equipment","equipment damage does not recursively trigger itself")
	acquire([&"armor_storm_conductor"])
	var real_shot:=actor.fire(Vector2.RIGHT,5,430,true,BasicAttackReceipt.new(actor));real_shot.set_physics_process(false);real_shot.pierce=2
	real_shot._hit_enemy(target);real_shot._hit_enemy(neighbour)
	check(gear.cadence.storm_hits==1,"real piercing projectile dispatch counts first effective hit once")
	real_shot.queue_free()
	acquire([&"accessory_counterbeat"]);gear.on_skill_cast(false,&"flame_nova");hp=target.hp;basic(target)
	check(is_equal_approx(hp-target.hp,gear.attack()*.22) and gear.cadence.counter_until==0,"counterbeat consumes once")
	gear.on_skill_cast(false,&"meteor");check(gear.cadence.counter_until==0,"ultimate cannot arm a small-skill effect")
	gear.on_skill_cast(false,&"flame_nova");gear.clock+=4.1;hp=target.hp;basic(target);check(target.hp==hp,"counterbeat expires")
	acquire([&"armor_mana_reservoir"]);GameState.mp=50
	for i in 5:gear.on_skill_cast(false,&"flame_nova")
	check(gear.cadence.reservoir_charges==3 and status("mana_reservoir").stacks==3,"reservoir three charges maximum at exact high mana threshold")
	hp=target.hp;basic(target);basic(target)
	check(gear.cadence.reservoir_charges==2 and GameState.mp==52 and is_equal_approx(hp-target.hp,gear.attack()*.3),"reservoir hit interval and MP")
	gear.clock+=.81;basic(target);check(gear.cadence.reservoir_charges==1 and GameState.mp==54,"next reservoir charge after interval")
	gear.clock+=8.1;gear.cadence.tick();check(gear.cadence.reservoir_charges==0 and status("mana_reservoir").is_empty(),"reservoir buff expiry")
	GameState.mp=49.99;gear.on_skill_cast(false,&"flame_nova");check(gear.cadence.reservoir_charges==0,"low mana cannot recharge reservoir")
	acquire([&"accessory_last_flame"]);GameState.mp=30;gear.on_skill_cast(false,&"flame_nova");check(actor.shield_hp==0,"exact 30 percent does not trigger low mana")
	GameState.mp=29.9;gear.on_skill_cast(false,&"flame_nova");check(is_equal_approx(actor.shield_hp,actor.max_hp*.08),"low-mana shield amount")
	actor.shield_hp=actor.max_hp*.2;gear.clock+=9;gear.on_skill_cast(false,&"flame_nova");check(is_equal_approx(actor.shield_hp,actor.max_hp*.2),"weaker shields never add or overwrite")
	acquire([&"armor_orbit_guard",&"relic_wayfarer_score"])
	for i in 4:gear.on_ally_hit(target,ally)
	check(gear.cadence.ally_hits==1 and gear.cadence.score_hits==1,"same-frame cleave or volley only one ally beat")
	for i in 3:gear.clock+=.21;gear.on_ally_hit(target,ally)
	check(is_equal_approx(actor.shield_hp,actor.max_hp*.05) and GameState.mp==22,"four ally beats shield and MP")
	gear.clock+=6;ally.position=actor.position+Vector2(200,0);gear.on_ally_hit(target,ally);check(gear.cadence.ally_hits==0,"distant ally cannot charge")
	ally.position=actor.position+Vector2(30,0)
	acquire([&"accessory_cadence_prism"]);hp=target.hp;basic(target);basic(target);check(gear.cadence.cadence_stacks==0,"same basic source no cadence stack")
	gear.on_skill_hit(target);gear.on_skill_hit(target);check(gear.cadence.cadence_stacks==1,"same skill source no duplicate cadence stack")
	basic(target);gear.on_skill_hit(target);check(is_equal_approx(hp-target.hp,gear.attack()*.65) and gear.cadence.cadence_kind==0,"third source switch triggers prism")
	gear.clock+=3;basic(target);gear.clock+=4.1;gear.on_skill_hit(target);check(gear.cadence.cadence_stacks==0 and gear.cadence.cadence_kind==2,"cadence expires before late alternate hit")
	acquire([&"relic_copper_metre"],3);GameState.mp=20;target._slow_effects.clear();target._slow_time=0;target._slow_strength=0
	for i in 4:basic(target)
	check(is_equal_approx(GameState.mp,23.5) and is_equal_approx(target._slow_strength,.35),"three relic numerical scale 175 percent, fixed trigger count")
	gear.clock+=2;target.kind=&"boss_king";target._slow_effects.clear();target._slow_time=0;target._slow_strength=0
	for i in 4:basic(target)
	check(is_equal_approx(target._slow_strength,.175),"boss slow reduction applied exactly once");target.kind=&"walker"
	acquire([&"relic_aftertone"],2);hp=target.hp;gear.on_skill_hit(target);gear.on_skill_hit(target)
	check(is_equal_approx(hp-target.hp,gear.attack()*.14*1.5),"skill vs slowed extra damage uses global cooldown and stack scaling")
	acquire([&"relic_dew_battery"],3);GameState.mp=60;gear.on_skill_cast(false,&"flame_nova");check(not status("dew_battery").is_empty(),"battery pending buff shown")
	shared=BasicAttackReceipt.new(actor);basic(target,shared);basic(neighbour,shared);check(is_equal_approx(GameState.mp,65.25) and gear.cadence.battery_until==0,"battery consumes once across targets")
	gear.on_skill_cast(false,&"fan_bolts");check(gear.cadence.battery_until==0,"battery arming cooldown retained")
	acquire([&"relic_dry_wick"],3);gear.on_skill_hit(target);gear.on_skill_hit(target);check(is_equal_approx(GameState.mp,25.25),"dry wick low mana 175 percent cooldown")
	gear.clock+=4;GameState.mp=30;gear.on_skill_hit(target);check(GameState.mp==30,"dry wick stops at exact threshold")
	acquire([&"relic_sentinel_thread"],2);ally.shield_hp=0;gear.on_shield_broken();hp=target.hp;basic(target)
	check(is_equal_approx(hp-target.hp,gear.attack()*.18*1.5) and is_equal_approx(ally.shield_hp,12),"shield break counter protects nearest ally")
	gear.clock+=5;ally.position=actor.position+Vector2(220,0);gear.on_shield_broken();hp=target.hp;basic(target);check(target.hp<hp,"sentinel still damages without nearby ally")
	ally.position=actor.position+Vector2(30,0)
	acquire([&"relic_wayfarer_score"],3)
	for i in 4:gear.on_ally_hit(target,ally);gear.clock+=.21
	check(is_equal_approx(GameState.mp,23.5),"score three copies keeps four-hit threshold")
	acquire([&"accessory_counterbeat"]);gear.on_skill_cast(false,&"flame_nova");check(GameState.unequip(&"accessory") and gear.cadence.counter_until==0,"unequip drops pending power")
	acquire([&"relic_dew_battery"]);GameState.mp=60;gear.on_skill_cast(false,&"flame_nova");GameState.run_refreshes["relic_dew_battery"]=3
	check(not ItemDB.can_refresh(ItemDB.by_id(&"relic_dew_battery")),"relic global three-display cap")
	check(GameState.sell_item(GameState.items[0]) and gear.cadence.battery_until==0 and ItemDB.can_refresh(ItemDB.by_id(&"relic_dew_battery")),"selling relic removes pending power and returns refresh slot")
	acquire([&"armor_mana_reservoir",&"accessory_counterbeat",&"relic_dew_battery"]);GameState.mp=60;gear.on_skill_cast(false,&"flame_nova");gear.clock+=1
	var saved:Dictionary=JSON.parse_string(JSON.stringify(gear.snapshot()));gear.clock+=100;gear.restore(saved)
	check(gear.cadence.reservoir_charges==1 and is_equal_approx(gear.cadence.reservoir_until-gear.clock,7) and is_equal_approx(gear.cadence.counter_until-gear.clock,3),"save roundtrip keeps charge and remaining durations")
	check(not gear.ready(&"dew_battery") and is_equal_approx(float(gear.cooldowns[&"dew_battery"])-gear.clock,2),"save keeps shared cooldown remaining")
	gear.on_room_enter("new-room-cadence",false);check(gear.cadence.reservoir_charges==1 and not gear.ready(&"dew_battery"),"room entry cannot refresh equipment timers")
	gear.restore({});check(gear.cadence.reservoir_charges==0 and gear.cadence.storm_hits==0,"old save missing module defaults to empty")
	# Proc feedback is bounded even in a summon-heavy room, including reduced FX.
	for node in get_tree().get_nodes_in_group("cadence_proc_fx"):node.queue_free()
	await get_tree().process_frame
	for i in 40:CadenceProcFX.spawn(main.fx_root,actor.position,32,Color.CYAN,i%4)
	check(get_tree().get_nodes_in_group("cadence_proc_fx").size()==24,"feedback concurrent cap")
	for node in get_tree().get_nodes_in_group("cadence_proc_fx"):node.queue_free()
	await get_tree().process_frame
	# Timed states advance only with owner scene time and survive pausing.
	acquire([&"accessory_counterbeat"]);gear.on_skill_cast(false,&"flame_nova");var remaining:=gear.cadence.counter_until-gear.clock
	get_tree().paused=true;await get_tree().create_timer(.05,true).timeout;get_tree().paused=false
	check(is_equal_approx(gear.cadence.counter_until-gear.clock,remaining),"paused state does not drain timed enhancement")
	# All three real actor runtimes invoke the shared hooks.
	for character in Characters.DATA:
		Characters.set_current(character);GameState.new_run(6006);GameState.set_process(false)
		var unit:=RoomPlayer.new();unit.room=main.level;unit.level=main.level;main.actors_root.add_child(unit);unit.set_physics_process(false)
		if is_instance_valid(unit.holy_runtime):unit.holy_runtime.set_process(false)
		if is_instance_valid(unit.ilyua_runtime):unit.ilyua_runtime.set_process(false)
		GameState.items.append(ItemDB.by_id(&"accessory_counterbeat"));GameState.equip(GameState.items[-1]);GameState.mp=100;GameState.skill_cooldowns_by_id.clear()
		check(unit.caster.cast(0),"real small skill casts "+str(character))
		check(unit.equipment_mechanics.cadence.counter_until>unit.equipment_mechanics.clock,"real character cast arms counterbeat "+str(character))
		unit.queue_free();GameState.player=actor;await get_tree().process_frame
	Characters.set_current(&"sylphiette");MobileControls.bind_actor(actor)
	var inv:=InventoryUI.new();add_child(inv);inv.open();await get_tree().process_frame
	for id in IDS:
		inv._selected=ItemDB.by_id(id);inv._rebuild_detail();await get_tree().process_frame
		check(inv._detail_box.find_children("*","Label",true,false).all(func(label:Label)->bool:return label.size.x<=inv._detail_box.size.x+1 and label.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART),"new long description wraps in inventory "+str(id))
	inv._finish_close();inv.queue_free();GameState.run_active=false;main.queue_free();await get_tree().process_frame;AudioManager.shutdown();await get_tree().create_timer(.35).timeout
	print("CADENCE_CONTENT checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
