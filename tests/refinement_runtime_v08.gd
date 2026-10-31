extends "res://tests/cadence_content.gd"
var keep_starting_star_prompt:=false
func run()->void:
	check(OS.get_user_data_dir().begins_with("E:/CodexWorkspace/PixelRogue/"),"isolated save")
	AchievementTracker.set_process(false)
	composition_checks()
	for character in [&"sylphiette",&"xixifu",&"ilyua"]:
		await begin(character);buffer_checks();await settle_actor()
	await begin(&"sylphiette");await target_checks();await mechanism_checks();await query_checks();await warnings_and_delivery();await story_checks()
	await settle_actor();AudioManager.shutdown();await get_tree().process_frame
	print("REFINEMENT_RUNTIME_V08 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
func begin(character:StringName)->void:
	SaveService.data.control_setup_done=true;SaveService.data.run={};Outpost.data.active={};Characters.set_current(character)
	main=ProbeRoom.new();add_child(main);main._build_world();main._build_ui();main.set_process(false)
	await main._begin_run({"departure":{"loadout":[],"carried":0,"difficulty":1,"initial_level":1}})
	# Combat fixtures isolate the new mandatory initial choice. Dedicated
	# star tests keep it pending and exercise the actual selection transaction.
	if not keep_starting_star_prompt:GameState.fate.star_pending=false
	actor=main.player;gear=actor.equipment_mechanics;GameState.set_process(false);actor.set_physics_process(false);actor.caster.set_physics_process(false);gear.set_process(false);main.director.set_process(false);main.special_rooms.set_process(false);main.expansion.set_process(false);main.expedition.set_process(false)
	if is_instance_valid(actor.holy_runtime):actor.holy_runtime.set_process(false)
	if is_instance_valid(actor.ilyua_runtime):actor.ilyua_runtime.set_process(false)
	var order:=Skills.order_for();GameState.unlocked_skills.assign(order);GameState.learned_skills.assign([order[0],order[1],order[2]]);GameState.ultimate_skill=order[3];GameState.skill_cooldowns_by_id.clear();GameState._sync_skill_cooldowns();GameState.mp=100
func settle_actor()->void:
	GameState.run_active=false;actor.caster.clear_input_buffer();actor.set_physics_process(false);main.set_process(false)
	await get_tree().create_timer(1.4,true,false,true).timeout
	main.queue_free();await get_tree().process_frame;await get_tree().process_frame;Outpost.pending_checkpoint=false
func composition_checks()->void:
	for biome in ["forest","wetland","ruin"]:
		for wave in [1,4,8,12,30,50]:
			for difficulty in [1,2,3,4]:
				for seed in 12:
					var count:=RunDifficulty.spawn_count(int(WaveTable.build(wave).total),difficulty);var rng:=RandomNumberGenerator.new();rng.seed=seed
					var result:=RoomEnemyComposer.compose(count,biome,wave,rng)
					check(result.size()==count,"exact room population")
					var types:Dictionary={};var legal:=true;var order_ok:=true
					for index in result.size():
						types[str(result[index])]=true
						legal=legal and RoomEnemyComposer.POOLS[biome].any(func(entry:Array)->bool:return str(entry[0])==str(result[index]) and wave>=int(entry[1]))
						if index>=3 and result[index]==result[index-1] and result[index]==result[index-2] and result[index]==result[index-3]:
							for later in range(index+1,result.size()):
								if result[later]!=result[index]:order_ok=false
					var eligible:Array=RoomEnemyComposer.POOLS[biome].filter(func(entry:Array)->bool:return wave>=int(entry[1]))
					check(legal,"habitat and unlock eligibility")
					check(types.size()>=mini(2,eligible.size()) and types.size()<=4,"two to four species")
					check(order_ok,"no four identical spawns while alternatives remain")
					rng.seed=seed;check(result==RoomEnemyComposer.compose(count,biome,wave,rng),"deterministic composition")
	var a:=RandomNumberGenerator.new();a.seed=1;var b:=RandomNumberGenerator.new();b.seed=1
	check(RoomEnemyComposer.compose(30,"ruin",30,a,0)!=RoomEnemyComposer.compose(30,"ruin",30,b,1),"existing formation profile changes actual composition")
	check(EnemyCombatPolicy.excluded_affixes(&"thorn_mantis").has(EnemyAffixes.EMBER_GRAVE),"inherent death bomb cannot pair with grave")
func buffer_checks()->void:
	var caster:=actor.caster;var id:=GameState.skill_for_slot(0);var cost:=GameState.skill_cost(id);var mana:=GameState.mp
	GameState.skill_cooldowns_by_id[id]=.05
	check(caster.request(0) and GameState.mp==mana,"buffer accepts near-ready skill without charging MP")
	caster._buffer_frame=-1;GameState.skill_cooldowns_by_id[id]=0;caster._physics_process(.06);check(GameState.mp==mana and caster.busy(),"buffer begins casting windup without charging");caster._physics_process(.33)
	check(is_equal_approx(GameState.mp,mana-cost) and caster._buffer_slot<0,"buffer releases real character skill exactly once")
	caster._physics_process(.11);check(is_equal_approx(GameState.mp,mana-cost),"buffer never repeats held request")
	GameState.mp=100;GameState.skill_cooldowns_by_id[id]=.1;caster.request(0);var id2:=GameState.skill_for_slot(1);GameState.skill_cooldowns_by_id[id2]=.1;caster.request(1)
	check(caster._buffer_skill==id2,"last valid request replaces earlier input")
	UIFlow.push_screen(main.inventory_ui);check(caster._buffer_slot<0,"opening menu clears pending input");UIFlow.pop_screen(main.inventory_ui)
	GameState.skill_cooldowns_by_id[id]=.1;caster.request(0);caster._buffer_frame=-1;caster._physics_process(.16);GameState.skill_cooldowns_by_id[id]=0;mana=GameState.mp;caster._physics_process(.01)
	check(caster._buffer_slot<0 and GameState.mp==mana,"expired input cannot fire later")
	GameState.skill_cooldowns_by_id[id]=.1;caster.request(0);actor.stop_room_travel_motion();check(caster._buffer_slot<0 and GameState.skill_cooldowns_by_id[id]==.1,"travel clears input but keeps cooldown")
	caster.request(0);var hp:=actor.hp;actor.hp=0;caster._buffer_frame=-1;caster._physics_process(.01);actor.hp=hp;check(caster._buffer_slot<0,"death invalidates input")
	GameState.mp=0;GameState.skill_cooldowns_by_id[id]=0;check(not caster.request(0) and caster._buffer_slot<0,"insufficient MP never queued")
	GameState.mp=100;GameState.skill_cooldowns_by_id[id]=.16;check(not caster.request(0),"cooldown outside 150ms is not buffered")
func make_ally(at:Vector2)->RoomAlly:
	var ally:=RoomAlly.new();ally.room=main.level;ally.setup(HireOffers._monster_offer(&"walker",Rng.stream()),actor,main.level,main.fx_root);ally.position=at;main.actors_root.add_child(ally);ally.set_physics_process(false);return ally
func target_checks()->void:
	var origin:=main.level.bounds().get_center();var owner:=enemy(origin);actor.position=origin+Vector2(100,0)
	var ally:=make_ally(origin+Vector2(80,0));owner.aggro=actor;owner._aggro_timer=0;owner._update_aggro(1)
	check(owner.aggro==actor,"enemy keeps current target when challenger is only twenty percent nearer")
	ally.position=origin+Vector2(74,0);owner._aggro_timer=0;owner._update_aggro(1);check(owner.aggro==ally,"enemy switches when challenger is at least twenty-five percent nearer")
	owner.queue_free();await get_tree().process_frame
	actor.position=origin;ally.position=origin;var old:=enemy(origin+Vector2(100,0));var other:=enemy(origin+Vector2(80,0));ally._cached_target=weakref(old);ally._room_target_timer=0
	check(ally._choose_target()==old,"ally target hysteresis uses same threshold")
	other.position=origin+Vector2(74,0);ally._room_target_timer=0;check(ally._choose_target()==other,"ally switches to substantially closer enemy")
	old._dead=true;other._dead=true;ally._roam_initialized=true;ally._roam_arrived=false;ally._roam_goal=ally.position
	check(ally.follow_goal()==ally.position and ally._roam_rest>=1 and ally._roam_rest<=3,"idle ally rests one to three seconds after arriving")
	ally._roam_arrived=false;ally._roam_rest=0;ally._roam_left=5;ally._roam_goal=ally.position+Vector2(30,0);ally.nav_timer=0;ally._physics_process(1.0/60);check(not ally.velocity.is_zero_approx(),"ally continues through old 42px stop radius until real arrival tolerance")
	ally.position=ally._roam_goal;ally.follow_goal();check(ally._roam_rest>=1 and ally._roam_rest<=3,"real movement arrival begins idle rest")
	old._dead=false;ally._room_target_timer=0;check(ally._choose_target()==old,"enemy appearance interrupts idle rest")
	for unit in [old,other,ally]:unit.queue_free()
	await get_tree().process_frame
func mechanism_checks()->void:
	actor.position=main.level.nearest_clear(main.level.bounds().get_center(),12)
	var target:=enemy(actor.position+Vector2(30,0));var neighbour:=enemy(actor.position+Vector2(50,0))
	acquire([&"armor_storm_conductor"]);var receipt:=BasicAttackReceipt.new(actor);basic(target,receipt);basic(neighbour,receipt)
	check(gear.cadence.storm_hits==1,"piercing and multi-hit share a primary receipt")
	var events:Array=[];target.damage_applied.connect(func(_e:EnemyBase,_a:float,_s:Node,type:StringName)->void:events.append(type))
	for index in 3:basic(target)
	check(events.size()==1 and events[0]==&"equipment" and gear.cadence.storm_hits==0,"equipment burst does not recursively count as primary hit")
	var cooldowns:Dictionary=gear.snapshot().cooldowns;gear.on_room_enter("qa-first",false);gear.on_room_enter("qa-next",false);check(gear.snapshot().cooldowns==cooldowns,"room changes retain item cooldown")
	var statuses:=PlayerStatusCatalog.snapshot(actor);var ids:Dictionary={}
	for row in statuses:ids[row.id]=true
	check(ids.size()==statuses.size(),"status HUD has unique identities")
	var rows:Array[Dictionary]=[];PlayerStatusCatalog._append(rows,"slow",1);PlayerStatusCatalog._append(rows,"slow",2);check(rows.size()==1 and rows[0].remaining==2,"same status refresh updates one slot")
	target.queue_free();neighbour.queue_free();await get_tree().process_frame
func legacy_nearest(origin:Vector2,radius:float,limit:int)->Array[EnemyBase]:
	var found:Array[EnemyBase]=[]
	for node in get_tree().get_nodes_in_group("enemies"):
		var unit:=node as EnemyBase
		if gear._live_enemy(unit) and origin.distance_squared_to(unit.global_position)<=radius*radius and main.level.projectile_clear(origin,unit.global_position):found.append(unit)
	found.sort_custom(func(a:EnemyBase,b:EnemyBase)->bool:return a.global_position.distance_squared_to(origin)<b.global_position.distance_squared_to(origin))
	if found.size()>limit:found.resize(limit)
	return found
func query_checks()->void:
	var origin:=main.level.bounds().get_center()
	for index in 45:enemy(main.level.nearest_clear(origin+Vector2.from_angle(index*2.399)*float(35+index*4),12))
	var rng:=RandomNumberGenerator.new();rng.seed=991
	for index in 25:
		var point:=origin+Vector2(rng.randf_range(-80,80),rng.randf_range(-60,60))
		check(gear.nearest_enemies(point,400,3)==legacy_nearest(point,400,3),"optimized query keeps exact target and LOS result")
	var before:int=main.level.tactics.roster_builds
	for index in 50:gear.nearest_enemies(origin,400,1)
	check(main.level.tactics.roster_builds==before,"same-frame queries reuse scoped roster")
	var born:=enemy(origin+Vector2(10,0));check(main.level.tactics.enemies(main.level).has(born),"same-frame spawn invalidates roster immediately")
	born._dead=true;check(not gear.nearest_enemies(origin,400,100).has(born),"dead units excluded immediately")
	var start:=Time.get_ticks_usec()
	for index in 250:legacy_nearest(origin,400,1)
	var baseline:=Time.get_ticks_usec()-start;start=Time.get_ticks_usec()
	for index in 250:gear.nearest_enemies(origin,400,1)
	print("QUERY_BENCH old_us=",baseline," new_us=",Time.get_ticks_usec()-start)
	for unit in main.enemies_root.get_children():unit.queue_free()
	await get_tree().process_frame
func warnings_and_delivery()->void:
	var warning:=BossPatternWarning.create(main.fx_root,main.level,{"shape":"circle","at":actor.position,"radius":60},.8,Color.RED)
	check(warning.z_index==800 and not warning.z_as_relative,"danger warning has absolute foreground layer")
	var chest:=RoomChest.new();chest.setup(main.level,actor);chest.position=actor.position;main.chests_root.add_child(chest);chest.begin_delivery()
	var landing:=chest.landing_position();chest._fall_elapsed=.3;chest._update_fall_visual();check(chest.landing_position()==landing and chest._sprite.position.y<chest._art_origin.y,"falling sprite moves while ground anchor remains fixed")
	chest.free_opening=true;check(chest.required_keys()==0,"reward chest remains key-free")
	AudioManager.play(&"boss_warning",-13,0);AudioManager.play(&"shield_break",-9,0)
	check(AudioManager._priority_voices.has("danger") and AudioManager._priority_voices.has("hurt"),"danger and damage use protected sound voices")
	var stamp:int=AudioManager._last_played.get("shield_break",0);AudioManager.play(&"shield_break",-9,0);check(AudioManager._last_played.get("shield_break",0)==stamp,"same sound cue is rate limited")
	warning.queue_free();chest.queue_free();await get_tree().process_frame
func story_checks()->void:
	var dialogue:=main.dialogue;dialogue._open();dialogue._review=false;dialogue._repeat_read_only=false;dialogue._scene_id=&"v08_choice_probe"
	dialogue._scene={"choices":[{"text":"保留这份礼物","give":"plate_mail"}]};dialogue._mode="scene";dialogue._pending_next=&"";dialogue._skip_story()
	check(dialogue._choosing and not dialogue._closing,"skip dialogue stops at reward/branch decision")
	var before:=GameState.items.size();dialogue._pick(dialogue._offered[0]);check(GameState.items.size()==before+1,"skipped dialogue still grants chosen reward once")
	dialogue._pick({"text":"保留这份礼物","give":"plate_mail"});check(GameState.items.size()==before+1,"choice cannot duplicate reward")
	dialogue.cancel();await get_tree().process_frame
