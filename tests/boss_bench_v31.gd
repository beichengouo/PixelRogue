extends Node
## Replays an untouched natural-route checkpoint with controlled legal gear.
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v31-boss-pressure/"
class MeasuredPlayer:
	extends RoomPlayer
	var observer:Node
	func take_damage(amount:float,from:Vector2,source:Node=null,direct_hit:=true)->void:
		var before_hp:=hp;var before_shield:=shield_hp;var blocked:=_invuln>0
		super.take_damage(amount,from,source,direct_hit)
		if observer!=null:observer.damage_probe(amount,before_hp-hp,maxf(0,before_shield-shield_hp),blocked,source)
class BenchRoom:
	extends "res://src/room_mode/room_main.gd"
	var observer:Node
	func _ready()->void:pass
	func _autoplay_requested()->bool:return true
	func _spawn_player()->void:
		var unit:=MeasuredPlayer.new();unit.observer=observer;unit.room=level;unit.level=level
		unit.position=level.nearest_clear(level.room_rect.get_center()+Vector2(0,72));player=unit;actors_root.add_child(player)
		camera.target=player;camera.snap_to_target()
class FixedGearPilot:
	extends GMPilot
	var standing:=false
	func _equip_upgrades()->void:pass
	func _go_to_next_room(_step:float=0.0)->void:pass
	func _combat(target:EnemyBase)->void:
		if not standing:super._combat(target);return
		# Deliberately standing/basic-only is a separate threat control, never
		# a normal Bot score. It still takes damage through production physics.
		main.player.movement_override=Vector2.ZERO
		main.player.aim_override=(target.global_position-main.player.global_position).normalized()
var main:BenchRoom
var sample:Dictionary={}
var observing:=false
var fight_seconds:=0.0
var result:Dictionary={"attempts":0,"invulnerable_contacts":0,"hp_damage":0.0,"shield_absorbed":0.0,"raw_contact_damage":0.0,"hits":0,"sources":{},"phases":{},"patterns":{},"pressure_max":0}
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",message)
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
func damage_probe(raw:float,hp_loss:float,shield_loss:float,blocked:bool,source:Node)->void:
	if not observing:return
	result.attempts+=1;result.invulnerable_contacts+=int(blocked);result.raw_contact_damage+=raw
	result.hp_damage+=maxf(0,hp_loss);result.shield_absorbed+=shield_loss
	result.hits+=int(hp_loss>0 or shield_loss>0)
	var kind:="other"
	if source is RoomBoss:kind="boss_direct"
	elif source is BossPatternProjectile:kind="boss_projectile"
	elif source is RoomEnemy and not source.boss_wave_tag.is_empty():kind="boss_add"
	elif source is RoomProjectile:kind="projectile"
	result.sources[kind]=int(result.sources.get(kind,0))+1
func _process(dt:float)->void:
	if not observing or get_tree().paused or not is_instance_valid(main):return
	if main.director.phase!=WaveDirector.Phase.FIGHT:return
	fight_seconds+=dt
	var boss:=main.director.boss as RoomBoss
	if is_instance_valid(boss):
		result.phases[str(boss.phase)]=true;result.patterns[boss.pattern]=true
		result.pressure_max=maxi(int(result.pressure_max),boss.room_pressure_growth)
func kit(profile:String,hero:String)->Array:
	if profile=="common":return [{"ilyua":"bow_wood","xixifu":"staff_apprentice","sylphiette":"staff_apprentice"}[hero],"traveler_leather","eagle_badge"]
	if profile=="rare":return [{"ilyua":"bow_lake_light","xixifu":"staff_shadow_stitch","sylphiette":"staff_tide_prayer"}[hero],"wind_cloak","wind_ring"]
	if profile=="legendary":return {"ilyua":["bow_spring_wind","armor_lakeleaf_hunt","accessory_moonwind_chime"],"xixifu":["staff_dusk_lantern","armor_dusk_mantle","accessory_companion_bells"],"sylphiette":["staff_cloud_radiance","armor_cloud_rites","accessory_eternal_ring"]}[hero]
	return []
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	var args:=OS.get_cmdline_user_args()
	if args.size()<4:get_tree().quit(2);return
	var key:=args[0];var difficulty:=clampi(int(args[1]),1,4);var profile:=args[2];var label:=args[3]
	sample=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"checkpoints/"+key+".json"))
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true
	SaveService.data=sample.save_data.duplicate(true);SaveService.data.reduced_motion=true
	Outpost.data=sample.outpost.duplicate(true);Outpost.data.active.difficulty=difficulty
	var snapshot:Dictionary=sample.snapshot.duplicate(true);snapshot.difficulty=difficulty
	# A fresh process and the recorded RNG stream keep each profile comparable.
	snapshot.gm_pilot_used=false;snapshot.gm_pilot_active=false
	SaveService.data.run=snapshot.duplicate(true);Engine.max_fps=0;Engine.physics_ticks_per_second=60
	main=BenchRoom.new();main.observer=self;main.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(main)
	main._build_world();main._build_ui();main._connect_events();await main._begin_run(snapshot)
	check(is_instance_valid(main.player),"restored real route player")
	check(main.graph.stage_index==int(sample.stage),"natural stage restored")
	check(not bool(main.graph.rooms[sample.destination].cleared),"unvisited boss destination")
	check(main.graph.rooms[sample.destination].get("boss_stats",{}).is_empty(),"difficulty not pre-applied")
	if failures:get_tree().quit(1);return
	var hp_ratio:=main.player.hp/main.player.max_hp
	var ids:=kit(profile,str(sample.hero))
	if not ids.is_empty():
		var discarded:Array=[]
		# A natural late-game bag can be full. Make room through the existing
		# discard API; never remove relics, consumables or equipped items, and
		# grant no sale gold. Keep this controlled-gear housekeeping visible.
		while GameState.bag_slots({},&"gear")>GameState.BAG_CATEGORY_CAPACITY-4:
			var spare:=GameState.items.filter(func(item:Dictionary)->bool:return ItemDB.is_equippable(item) and not GameState.is_equipped(item))
			if spare.is_empty():break
			var id:=str(spare[0].id);check(GameState.remove_item(StringName(id)),"discard spare gear for exchange space");discarded.append(id)
		result["discarded_spare_gear"]=discarded
		# Only controlled test equipment is supplied. All levels, talents, relics,
		# consumables and resource ratios remain those earned on the real route.
		for slot:StringName in ItemDB.SLOTS:
			if not GameState.equipped(slot).is_empty():check(GameState.unequip(slot),"legal unequip "+str(slot))
		for id:String in ids:
			var item:=ItemDB.by_id(StringName(id)).duplicate(true)
			check(not item.is_empty() and ItemDB.can_equip(item),"class-valid gear "+id)
			if item.is_empty():continue
			GameState.add_item(item);check(GameState.equip(GameState.items.back()),"equip "+id)
	main.player.hp=main.player.max_hp*hp_ratio
	main.gm_pilot.queue_free();await get_tree().process_frame
	var pilot:=FixedGearPilot.new();pilot.main=main;main.gm_pilot=pilot;main.add_child(pilot)
	pilot.standing=args.size()>4 and args[4]=="standing"
	check(pilot.activate(),"production Bot activated")
	await main._change_room(Vector2i(int(sample.direction[0]),int(sample.direction[1])))
	var wall:=Time.get_ticks_msec()
	while not is_instance_valid(main.director.boss) and Time.get_ticks_msec()-wall<10000:await get_tree().process_frame
	var boss:=main.director.boss as RoomBoss
	check(is_instance_valid(boss),"real boss spawn")
	if failures or boss==null:get_tree().quit(1);return
	var gear:Dictionary={}
	for slot:StringName in ItemDB.SLOTS:gear[str(slot)]=str(GameState.equipped(slot).get("id",""))
	var base:=RoomLayout.encounter(main.director.strength,str(boss.boss_id))
	check(is_equal_approx(boss.max_hp,UnitBalance.value("boss:"+str(boss.boss_id),"hp",float(BossRoster.get_data(boss.boss_id).hp))*float(base.boss_hp_scale)*RunDifficulty.health_multiplier(difficulty)),"Boss HP applies difficulty once")
	result["seed"]=sample.seed;result["navigation_assistance"]=bool(sample.get("navigation_assistance",false));result["control_style"]="standing_basic_only" if pilot.standing else "production_bot"
	result["start_player_position"]=str(main.player.global_position);result["start_boss_position"]=str(boss.global_position);result["room_bounds"]=str(main.level.bounds())
	result["start_clear_sight"]=main.level.sight(boss.global_position,main.player.global_position);result["start_projectile_clear"]=main.level.projectile_clear(boss.global_position,main.player.global_position)
	result.merge({"key":key,"hero":str(sample.hero),"chapter":str(sample.chapter),"stage":sample.stage,"difficulty":difficulty,"profile":profile,"boss":str(boss.boss_id),"max_hp":boss.max_hp,"boss_attack":boss.damage,"strength":main.director.strength,"hero_level":GameState.level,"hero_max_hp":main.player.max_hp,"hero_start_hp":main.player.hp,"hero_attack":main.player.stats.get_value(&"attack"),"gear":gear,"source_assisted":bool(sample.assisted_source),"invulnerability_override":false,"natural_route_checkpoint":true})
	observing=true
	while is_instance_valid(boss) and not boss._dead and main.player.hp>0 and fight_seconds<240 and Time.get_ticks_msec()-wall<240000:
		await get_tree().process_frame
	observing=false
	result["outcome"]="player_died" if main.player.hp<=0 else "boss_defeated" if not is_instance_valid(boss) or boss._dead else "timeout"
	result["combat_seconds"]=fight_seconds;result["hero_end_hp"]=main.player.hp
	result["boss_end_hp"]=boss.hp if is_instance_valid(boss) else 0
	result["wall_seconds"]=(Time.get_ticks_msec()-wall)/1000.0
	result["talents"]=GameState.talents.duplicate(true);result["relics"]=GameState.items.filter(func(item:Dictionary)->bool:return str(item.get("kind",""))=="buff")
	var file:=FileAccess.open(ROOT+label+".json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("V31_BENCH ",JSON.stringify(result));pilot.stop();GameState.run_active=false;main.queue_free()
	await get_tree().process_frame;await get_tree().process_frame
	AudioManager.shutdown();await get_tree().create_timer(.25,true,false,true).timeout
	print("BOSS_BENCH_V31 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
