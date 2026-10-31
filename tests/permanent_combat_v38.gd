extends "res://tests/refinement_runtime_v08.gd"

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	AchievementTracker.set_process(false)
	var original:=Outpost.data.duplicate(true)
	var saved:=SaveService.data.duplicate(true)
	var args:=OS.get_cmdline_user_args()
	SaveService.data.spell_fx_strength=.35 if args.has("low") else 1.0
	SaveService.data.reduced_motion=args.has("reduced")
	check(is_equal_approx(float(SaveService.data.spell_fx_strength),.35 if args.has("low") else 1.0) and ComicMotion.reduced()==args.has("reduced"),"FX setting variant applied")
	for hero:StringName in [&"sylphiette",&"xixifu",&"ilyua"]:
		await begin(hero)
		GameState.talents.clear()
		for skill_id:StringName in Skills.order_for(hero):
			for route:StringName in SkillTalentCatalog.ROUTES:GameState.talents[SkillTalentCatalog.route_id(skill_id,route)]=3
			GameState.talents[PermanentTalents.terminal_id(skill_id)]=1
		actor.global_position=main.level.nearest_clear(main.level.bounds().get_center(),12)
		actor.aim_direction=Vector2.RIGHT
		var first:=enemy(actor.global_position+Vector2(45,0))
		var second:=enemy(actor.global_position+Vector2(75,0))
		var third:=enemy(actor.global_position+Vector2(110,0))
		for unit in [first,second,third]:unit.hp=100000;unit.max_hp=100000
		if hero==&"sylphiette":holy_checks(first,second,third)
		elif hero==&"xixifu":summon_checks(first,second,third)
		else:ilyua_checks(first,second,third)
		var capstone_fx:=get_tree().get_nodes_in_group("talent_capstone_fx").filter(func(node:Node)->bool:return node is TalentCapstoneFX)
		check(not capstone_fx.is_empty(),"capstone texture spawned "+str(hero))
		if not capstone_fx.is_empty():
			check(capstone_fx[0].texture!=null and capstone_fx[0].texture.get_size().x>=1000,"large capstone texture "+str(hero))
		for unit in [first,second,third]:if is_instance_valid(unit):unit.queue_free()
		await settle_actor()
	Outpost.data=original;SaveService.data=saved
	AudioManager.shutdown();await get_tree().process_frame
	print("PERMANENT_COMBAT_V38 checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

func equip(skill_id:StringName)->void:
	var order:=Skills.order_for()
	var small:Array=[]
	for candidate:StringName in order:
		if Skills.is_ultimate(candidate):continue
		if candidate==skill_id:small.push_front(candidate)
		else:small.append(candidate)
	while small.size()>3:small.pop_back()
	var ultimate:=skill_id if Skills.is_ultimate(skill_id) else order[3]
	small.append(ultimate)
	GameState._assign_skill_loadout(small)
	check(PermanentTalents.active(skill_id),"equipped capstone "+str(skill_id))

func holy_checks(first:RoomEnemy,second:RoomEnemy,third:RoomEnemy)->void:
	var h:=actor.holy_runtime
	equip(&"flame_nova");h._release(&"flame_nova",first.global_position,false,1,1)
	check(h.fields.filter(func(row:Dictionary)->bool:return row.kind=="pillar").size()>=2,"holy linked pillars")
	h.fields.clear()
	equip(&"fan_bolts");h._release(&"fan_bolts",first.global_position,false,1,2);h._tick_feathers();h.clock+=2.1;h._tick_feathers()
	check(float(h.cooldowns.get("feather_capstone",0))>h.clock,"holy feather reformation whirl")
	equip(&"blink");h._release(&"blink",first.global_position,false,1,3);actor.shield_hp=0;h._process(.1)
	check(h.fields.any(func(row:Dictionary)->bool:return row.kind=="cloud_capstone"),"holy cloud after shield")
	h.fields.clear();h.feathers.clear()
	equip(&"meteor");h._release(&"meteor",first.global_position,false,1,4);h.clock=h.judgment_until+.1;h._process(.1)
	check(h.fields.filter(func(row:Dictionary)->bool:return row.kind=="burst").size()>=3,"holy judgment moving wave")
	h.fields.clear()
	equip(&"flame_shield");h._release(&"flame_shield",first.global_position,false,1,5)
	check(h.fields.any(func(row:Dictionary)->bool:return row.kind=="bell"),"holy bell echo target")
	h.fields.clear()
	equip(&"frost_nova");h._release(&"frost_nova",first.global_position,false,1,6)
	var court:Dictionary=h.fields[0];h._tick_field(court,9)
	check(h.fields.any(func(row:Dictionary)->bool:return row.kind=="court_after"),"holy lingering court")
	h.fields.clear()
	equip(&"healing_light");h._release(&"healing_light",first.global_position,false,1,7)
	var before:=get_tree().get_nodes_in_group("holy_derived").size();h._release(&"healing_light",first.global_position,false,1,8)
	check(h.step_link_until>h.clock and get_tree().get_nodes_in_group("holy_derived").size()>before,"holy linked next step feathers")
	equip(&"starfall");h._release(&"starfall",first.global_position,false,1,9);h.clock=h.sanctuary_until+.1;h._process(.1)
	check(h.afterlight_until>h.clock and float(h.cooldowns.get("sanctuary_afterlight",0))>h.clock,"holy lingering sanctuary aura")

func summon_effect(id:StringName)->Dictionary:
	var effect:Dictionary=Skills.get_skill(id).effect.duplicate(true)
	effect["source_skill"]=str(id)
	return effect
func summoned(id:StringName)->Array:
	var result:Array=[]
	for unit in actor.summons.companions():if unit.source_skill==id:result.append(unit)
	return result
func summon_checks(first:RoomEnemy,second:RoomEnemy,_third:RoomEnemy)->void:
	var s:=actor.summons
	equip(&"shadow_companions")
	var effect:=summon_effect(&"shadow_companions");s._release(effect,s.safe_positions(2),actor.global_position,SummonRules.hero_snapshot(actor,effect))
	var pair:=summoned(&"shadow_companions")
	check(pair.size()==2 and pair[0].capstone_cover_charge==1 and pair[1].capstone_cover_charge==1,"summon mutual cover ready")
	if pair.size()==2:pair[0].take_damage(1,first.global_position,first)
	check(pair.size()==2 and pair[0].capstone_cover_charge==0 and pair[1].capstone_cover_charge==0,"summon mutual cover once")
	equip(&"ghost_lantern");effect=summon_effect(&"ghost_lantern");s._release(effect,s.safe_positions(1),actor.global_position,SummonRules.hero_snapshot(actor,effect))
	var lanterns:=summoned(&"ghost_lantern")
	if not lanterns.is_empty():
		var p:=ContractProjectile.new();p.room=actor.room;p.damage_actor=lanterns[0];p.is_friendly=true;p.damage=10;p.explosion_radius=80;main.fx_root.add_child(p);p.global_position=first.global_position;p._explode();p.queue_free()
	check(main.fx_root.get_children().any(func(node:Node)->bool:return node is ContractProjectile and node.capstone_lantern),"summon lantern single tracking fire")
	equip(&"homeward_light");effect=summon_effect(&"homeward_light");s._release(effect,[],actor.global_position,{})
	check(actor.shield_hp>0 and pair[0].shield_hp>0,"summon recall shields")
	equip(&"forest_guardian");effect=summon_effect(&"forest_guardian");s._release(effect,s.safe_positions(1),actor.global_position,SummonRules.hero_snapshot(actor,effect))
	var guardians:=summoned(&"forest_guardian")
	if not guardians.is_empty():SummonRules.guardian_pulse(guardians[0],"roots",first.global_position);SummonRules.guardian_pulse(guardians[0],"burst",first.global_position)
	check(not guardians.is_empty() and guardians[0].capstone_roots_left==0,"summon guardian combo spent")
	equip(&"gatekeeper");effect=summon_effect(&"gatekeeper");s._release(effect,s.safe_positions(1),actor.global_position,SummonRules.hero_snapshot(actor,effect))
	var gates:=summoned(&"gatekeeper")
	if not gates.is_empty():gates[0]._physics_process(.01)
	check(not gates.is_empty() and gates[0].capstone_gate_cooldown>0,"summon gate interception pulse")
	equip(&"night_shelter");effect=summon_effect(&"night_shelter");s._release(effect,[],actor.global_position,{})
	actor.take_damage(1,first.global_position,first)
	check(not s.shelter_transfer_ready and not pair.is_empty() and pair[0].capstone_guard_left>0,"summon shelter transferred once")
	equip(&"shadow_step");effect=summon_effect(&"shadow_step");var hp:=first.hp;s._release(effect,[],actor.global_position,{})
	check(first.hp<hp,"summon echo from companions")
	equip(&"spirit_parade");effect=summon_effect(&"spirit_parade");s._release(effect,s.safe_positions(3),actor.global_position,{})
	var parade:=summoned(&"spirit_parade")
	if not parade.is_empty():s.parade_pulse(parade[0])
	check(not parade.is_empty() and not s.parade_pulse_pending,"summon parade one assembly pulse")

func ilyua_checks(first:RoomEnemy,second:RoomEnemy,third:RoomEnemy)->void:
	var r:=actor.ilyua_runtime
	equip(&"ilyua_wind_arrow");r._release_skill(&"ilyua_wind_arrow",first.global_position,1)
	var arrow:=r.spawn_arrow(&"basic",actor.global_position,Vector2.RIGHT,.5,true,false,BasicAttackReceipt.new(actor))
	r.on_arrow_hit(arrow,first,true)
	check(r.capstone_wind_marks.has(first.get_instance_id()),"ilyua pierce leaves wind mark")
	var next:=r.spawn_arrow(&"basic",actor.global_position,Vector2.RIGHT,.5,true,false,BasicAttackReceipt.new(actor));r.on_arrow_hit(next,first,true)
	check(first.hp<first.max_hp,"ilyua next arrow detonates mark")
	equip(&"ilyua_thorn_seed");r.attach_seed(first,4,.2);r._on_enemy_died(first,DamageContext.skill(actor),&"skill")
	check(r.seed_marks.has(second.get_instance_id()) and r.seed_marks.has(third.get_instance_id()),"ilyua seed spreads to two once")
	first._dead=false;first.hp=100000
	equip(&"ilyua_forest_step");r._release_skill(&"ilyua_forest_step",first.global_position,1)
	var decoys:=get_tree().get_nodes_in_group("ilyua_decoys").filter(func(node:Node)->bool:return node is IlyuaDecoy and node.runtime==r)
	if not decoys.is_empty():decoys[0].expire()
	check(not decoys.is_empty() and get_tree().get_nodes_in_group("room_projectiles").any(func(node:Node)->bool:return node is IlyuaArrow and node.arrow_kind==&"leaf"),"ilyua decoy leaf arrow")
	equip(&"ilyua_thousand_winds");r.ultimate_finish_pending=true;r.finish_ultimate()
	check(get_tree().get_nodes_in_group("room_projectiles").filter(func(node:Node)->bool:return node is IlyuaArrow and node.arrow_kind==&"ultimate_finish").size()>=14,"ilyua concentrated remaining wind")
	equip(&"ilyua_hunter_mark");r._release_skill(&"ilyua_hunter_mark",first.global_position,1)
	var precision:=r.spawn_arrow(&"precision",actor.global_position,Vector2.RIGHT,.4,false,false,null,first);r.on_arrow_hit(precision,first,true)
	check(r.marked.has(first.get_instance_id()) and float(r.marked[first.get_instance_id()].get("weak_until",0))>r.clock,"ilyua precision reveals weakness")
	equip(&"ilyua_vine_trap");r._release_skill(&"ilyua_vine_trap",first.global_position,1)
	var traps:=r.active_fields(&"trap")
	if not traps.is_empty():traps[0].remaining=.01;traps[0]._physics_process(.1)
	check(not traps.is_empty() and first.ilyua_root_left>0,"ilyua trap final constriction")
	equip(&"ilyua_moon_arrows");r._release_skill(&"ilyua_moon_arrows",first.global_position,1);r.moon_left=.01;r._physics_process(.1)
	check(r.capstone_moon_fired,"ilyua moon finish seeks mark")
	equip(&"ilyua_ancient_tree");r._release_skill(&"ilyua_ancient_tree",first.global_position,1)
	var trees:=r.active_fields(&"tree");actor.hp=actor.max_hp*.5;var hp_before:=actor.hp
	if not trees.is_empty():r.finish_tree(trees[0])
	check(not trees.is_empty() and actor.hp>hp_before,"ilyua ancient tree final healing pulse")
