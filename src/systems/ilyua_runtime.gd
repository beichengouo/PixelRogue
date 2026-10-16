class_name IlyuaRuntime
extends Node

const DERIVED_CAP := 48
var actor: RoomPlayer
var clock := 0.0
var wind_pierce_until:=0.0
var wind_pierce_serial:=0
var wind_hit_serial:=0
var ultimate_left := 0.0
var ultimate_finish_pending := false
var wind_stacks := 0
var wind_grace := 0.0
var no_fire := 0.0
var moon_charges := 0
var moon_regen := 0.0
var moon_left := 0.0
var dash_serial := 0
var dash_start := 0.0
var blessing := 0
var next_basic_bonus := 0.0
var next_basic_until := 0.0
var next_natural_bonus := 0.0
var light_empower := false
var light_empower_until := 0.0
var marked: Dictionary = {}
var marks: Dictionary = {}
var seed_marks: Dictionary = {}
var mature_marks: Dictionary = {}
var true_hits: Dictionary = {}
var ultimate_hits: Dictionary = {}
var precision_hits: Dictionary = {}
var cooldowns: Dictionary = {}
var field_serial := 0
var _derived_this_frame := 0
var _kill_times: Array[float] = []
var _skill_history: Dictionary = {}
var _observed: Dictionary = {}
var _last_movement := Vector2.ZERO
var move_time:=0.0
var stop_time:=0.0
var step_left:=0.0
var step_direction:=Vector2.ZERO
var sprout_marks:Dictionary={}
var moon_slots:Array[Dictionary]=[]
var volley_hits:Dictionary={}
var _favor_times:Array[float]=[]
var _phased:Array[WeakRef]=[]
var _moon_visuals:Array[IlyuaFX]=[]
var _step_hit_ids:Dictionary={}
var _field_sequence:=0
var natural_hits:Dictionary={}

func _ready() -> void:
	if actor == null: actor = get_parent() as RoomPlayer
	if actor == null: return
	actor.ilyua_runtime = self
	set_process_priority(20)
	observe_enemies()

func rank(id: StringName) -> int: return GameState.talent_rank(id)
func attack() -> float: return actor.stats.get_value(&"attack") if is_instance_valid(actor) else 0.0
func live(enemy: EnemyBase) -> bool: return is_instance_valid(enemy) and not enemy._dead and not enemy.is_queued_for_deletion()
func ready(id: StringName) -> bool: return clock >= float(cooldowns.get(id, 0.0))
func start(id: StringName, duration: float) -> void: cooldowns[id] = clock + duration
func active_fields(kind: StringName) -> Array[IlyuaField]:
	var result: Array[IlyuaField] = []
	for node in get_tree().get_nodes_in_group("ilyua_fields"):
		var field := node as IlyuaField
		if is_instance_valid(field) and field.runtime == self and field.kind == kind and not field.is_queued_for_deletion(): result.append(field)
	return result

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.hp<=0:return
	clock+=delta
	observe_enemies()
	_tick_marks(delta)
	var moving:=actor.velocity.length_squared()>64
	move_time=move_time+delta if moving else move_time
	stop_time=0.0 if moving else stop_time+delta
	if stop_time>=.5:move_time=0.0
	if rank(&"ilyua_light_body")>=1 and move_time>=1.5 and stop_time<.5:actor._dash_cd=maxf(0,actor._dash_cd-delta*.1)
	if GameState.passive_id==&"ilyua_wind_rhythm":
		var grace:=3.0 if moving else 2.0
		var decay_before:=maxf(0,no_fire-grace)
		no_fire+=delta
		if no_fire>grace:
			wind_grace+=maxf(0,no_fire-grace)-decay_before
			while wind_grace>=1 and wind_stacks>0:wind_grace-=1;wind_stacks-=1;refresh_wind()
	if ultimate_left>0:
		ultimate_left=maxf(0,ultimate_left-delta)
		if ultimate_left==0:finish_ultimate()
	moon_left=maxf(0,moon_left-delta)
	_update_moons(delta)
	for key in marked.keys():
		if float(marked[key].until)<=clock:marked.erase(key)
	for key in true_hits.keys():
		if float(true_hits[key].until)<=clock:true_hits.erase(key)
	if clock>=float(_skill_history.get("phase_until",0)):
		for ref in _phased:
			var enemy:EnemyBase=ref.get_ref() as EnemyBase
			if is_instance_valid(enemy):actor.remove_collision_exception_with(enemy)
		_phased.clear()
	else:
		for enemy in enemies_in(actor.global_position,80):
			actor.add_collision_exception_with(enemy);_phased.append(weakref(enemy))
	if actor._dash_timer>0 or step_left>0:moon_dash_hits()

func observe_enemies() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyBase
		if not live(enemy) or _observed.has(enemy.get_instance_id()): continue
		_observed[enemy.get_instance_id()] = weakref(enemy)
		if not enemy.died.is_connected(_on_enemy_died):enemy.died.connect(_on_enemy_died)
		if not enemy.damage_applied.is_connected(_on_enemy_damaged):enemy.damage_applied.connect(_on_enemy_damaged)

func enemies_in(at: Vector2, radius: float, exclude: EnemyBase = null) -> Array[EnemyBase]:
	var result: Array[EnemyBase] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyBase
		if live(enemy) and enemy != exclude and at.distance_squared_to(enemy.global_position) <= radius * radius and actor.room.sight(at, enemy.global_position): result.append(enemy)
	return result

func nearest_enemy(at: Vector2, radius: float, exclude: EnemyBase = null, skip: Dictionary = {}) -> EnemyBase:
	var best: EnemyBase
	var distance := radius * radius
	for enemy in enemies_in(at, radius, exclude):
		if skip.has(enemy.get_instance_id()): continue
		var d := at.distance_squared_to(enemy.global_position)
		if d < distance: best = enemy; distance = d
	return best

func forward_enemy(distance: float, angle: float = PI / 4.0) -> EnemyBase:
	var best: EnemyBase
	var best_dist := distance * distance
	for enemy in enemies_in(actor.global_position, distance):
		var offset: Vector2 = enemy.global_position - actor.global_position
		if offset.is_zero_approx() or actor.aim_direction.dot(offset.normalized()) < cos(angle): continue
		if offset.length_squared() < best_dist: best = enemy; best_dist = offset.length_squared()
	return best

func spawn_arrow(kind: StringName, at: Vector2, direction: Vector2, ratio: float, main: bool, natural_source: bool, receipt: BasicAttackReceipt=null, target: EnemyBase=null) -> IlyuaArrow:
	if not main:
		var count:=0
		for node in get_tree().get_nodes_in_group("room_projectiles"):
			if node is IlyuaArrow and not node.main_arrow and not node.is_queued_for_deletion():count+=1
		if count>=DERIVED_CAP:return null
	var arrow:=IlyuaArrow.new()
	arrow.runtime=self;arrow.room=actor.room;arrow.arrow_kind=kind
	arrow.damage_owner=&"player";arrow.is_friendly=true
	arrow.main_arrow=main;arrow.natural=natural_source
	arrow.is_basic_attack=main and kind in [&"basic",&"ultimate_basic"]
	arrow.attack_receipt=receipt;arrow.art_scale=1;arrow.range_limit=540
	arrow.homing_turn=0
	if arrow.is_basic_attack:
		arrow.enable_basic_tracking(direction,at)
		arrow.homing_range=144 if rank(&"ilyua_wind_feathers")>=1 else 108
		arrow.strong_pierce=clock<wind_pierce_until
		arrow.wind_skill_serial=wind_pierce_serial if arrow.strong_pierce else 0
		arrow.weapon_fx=str(GameState.equipped(&"weapon").get("weapon",{}).get("fx","bow_vine_short"))
		if rank(&"ilyua_returning_arrow")>=1:arrow.bounce_left=1
		if rank(&"ilyua_returning_arrow")>=2:arrow.redirect_left=1
	if kind==&"wind":
		arrow.pierce_left=2;arrow.pierce=2;arrow.bounce_left=1;arrow.wall_seek=true;arrow.seek_after_bounce=true
		arrow.primary_skill=&"ilyua_wind_arrow"
	if kind==&"seed":arrow.primary_skill=&"ilyua_thorn_seed"
	if kind in [&"moon",&"tree_shot"]:arrow.primary_skill=&"ilyua_moon_arrows" if kind==&"moon" else &"ilyua_ancient_tree";arrow.natural=kind==&"tree_shot"
	if kind==&"ultimate_basic":arrow.bounce_left=1;arrow.homing_range=144;arrow.homing_turn=PI
	if target!=null:arrow.target_ref=weakref(target);arrow.basic_tracking=false;arrow.homing_range=144;arrow.homing_turn=TAU*2
	arrow.color=Color("b3e8ee") if arrow.weapon_fx=="bow_lake_light" else Color("c8e59d")
	var parent:Node=get_tree().get_first_node_in_group("room_fx")
	if parent==null:parent=actor.get_parent()
	parent.add_child(arrow)
	var arrow_speed:=560.0*(1+wind_stacks*.04 if arrow.is_basic_attack else 1.0)
	if kind==&"wind":arrow_speed=720
	arrow.setup(at,direction if not direction.is_zero_approx() else actor.aim_direction,attack()*ratio,arrow_speed,actor.room,null,arrow.color)
	return arrow

func fire_basic(direction: Vector2, roll: Dictionary, receipt: BasicAttackReceipt, origin:=Vector2.INF) -> bool:
	if not is_instance_valid(actor):return false
	no_fire=0;wind_grace=0
	var ratio:=float(roll.damage)/maxf(.001,attack())
	if ultimate_left>0:ratio*=.85
	if light_empower and light_empower_until>clock:ratio*=1.25;light_empower=false
	if blessing>0:ratio*=1.2;blessing=0
	var kind:StringName=&"ultimate_basic" if ultimate_left>0 else &"basic"
	var from:=origin if origin.is_finite() else actor.global_position
	var arrow:=spawn_arrow(kind,from+direction*14,direction,ratio,true,false,receipt)
	if arrow==null:return false
	if next_basic_until>clock:
		arrow.pact_empowered=true;next_basic_bonus=0;next_basic_until=0
	if is_instance_valid(actor.equipment_aura):actor.equipment_aura.on_attack()
	actor.equipment_mechanics.on_basic_fired(direction,receipt)
	# The nocking flash belongs to the moving bow; flying arrows stay in world space.
	var cast_fx:=IlyuaFX.spawn(actor.get_parent() if origin.is_finite() else actor,from+direction*14 if origin.is_finite() else direction*14,"spring_cast" if arrow.weapon_fx=="bow_spring_wind" else "bow_cast",32,.25)
	if cast_fx!=null:cast_fx.global_rotation=arrow.direction.angle()
	return true

func fire_decoy_volley(at:Vector2)->void:
	if not is_instance_valid(actor) or actor.hp<=0:return
	for index in 8:
		var receipt:=BasicAttackReceipt.new(actor);var roll:=Combat.roll_attack(actor.stats,Rng.stream())
		roll.damage=float(roll.damage)*1.5;receipt.critical=bool(roll.crit)
		fire_basic(Vector2.RIGHT.rotated(index*TAU/8),roll,receipt,at)

func cast(slot: int) -> bool:
	if UIFlow.has_screen() or (not GameState.run_active and not CampSession.active) or actor.hp<=0:return false
	var id:=GameState.skill_for_slot(slot)
	if id==&"" or not GameState.skill_ready(slot):return false
	var target:=actor.global_position+actor.aim_direction*216
	if id==&"ilyua_ancient_tree":target=legal_ground(actor.room.bounds().get_center(),false)
	elif id==&"ilyua_vine_trap":target=legal_ground(target,true)
	if not target.is_finite():return false
	if GameState.begin_skill_cast(slot)==&"":return false
	var bonus:=actor.equipment_mechanics.on_skill_cast(false,id)
	actor._cast_timer=.28;actor._cast_pose=&"cast";actor._animation_request+=1
	var fate_bonus:=FateRuntime.cast_factor()
	var perform:=func()->void:_release_skill(id,target,bonus,fate_bonus)
	if not UltimateCutin.present(actor,id,perform):perform.call()
	return true

func legal_ground(at:Vector2,require_visible:bool)->Vector2:
	var bounds:=actor.room.bounds().grow(-12)
	at=Vector2(clampf(at.x,bounds.position.x,bounds.end.x),clampf(at.y,bounds.position.y,bounds.end.y))
	for ring in 13:
		for j in (1 if ring==0 else 16):
			var point:=at+Vector2.RIGHT.rotated(TAU*j/16)*ring*18
			if bounds.has_point(point) and actor.room.body_clear(point,12) and (not require_visible or (actor.global_position.distance_to(point)<=216 and actor.room.sight(actor.global_position,point))):return point
	return Vector2.INF

func _release_skill(id:StringName,target:Vector2,cast_bonus:float,fate_bonus:=1.0)->void:
	var at:=actor.global_position
	var bonus:=cast_bonus
	if next_natural_bonus>0 and id in [&"ilyua_thorn_seed",&"ilyua_vine_trap",&"ilyua_ancient_tree"]:bonus*=1+next_natural_bonus;next_natural_bonus=0
	match id:
		&"ilyua_wind_arrow":
			wind_pierce_until=clock+5;wind_pierce_serial+=1;IlyuaFX.spawn(actor,Vector2.ZERO,"bow_cast",48,.25)
		&"ilyua_thorn_seed":
			var arrow:=spawn_arrow(&"seed",at+actor.aim_direction*14,actor.aim_direction,.5*bonus,true,true)
			if arrow!=null:arrow.seed_ratio=.18*bonus;arrow.fate_direct_multiplier=fate_bonus
		&"ilyua_forest_step":forest_step()
		&"ilyua_thousand_winds":ultimate_left=8;ultimate_finish_pending=true;ultimate_hits.clear();IlyuaFX.spawn(actor,Vector2.ZERO,"ultimate",96,.5)
		&"ilyua_hunter_mark":
			var enemy:=forward_enemy(216)
			if enemy!=null:marked.clear();marked[enemy.get_instance_id()]={"enemy":weakref(enemy),"until":clock+8,"hits":0,"transfers":0};IlyuaFX.spawn(enemy,Vector2.ZERO,"mark",44,8)
		&"ilyua_vine_trap":
			var traps:=active_fields(&"trap")
			if traps.size()>=3:traps[0].queue_free()
			make_field(&"trap",target,72,6,1,.12*bonus,.8,.35)
		&"ilyua_moon_arrows":
			moon_left=8
			for i in range(moon_slots.size()-1,-1,-1):
				if moon_slots[i].kind=="skill":moon_slots.remove_at(i)
			for i in 3:moon_slots.append({"kind":"skill","ready":clock,"expires":clock+8})
		&"ilyua_ancient_tree":make_field(&"tree",target,144,8,.5,.06*bonus,.6,.35)
	if not IlyuaSkills.DATA.get(id,{}).get("ultimate",false):on_small_skill(id)
	AudioManager.play(&"wave_clear",-10)

func make_field(kind: StringName, at: Vector2, field_radius: float, duration: float, every: float, ratio: float, root_duration: float = 0.0, slow: float = 0.0) -> IlyuaField:
	var field := IlyuaField.new()
	field.runtime = self
	field.kind = kind
	field.radius = field_radius
	field.remaining = duration
	field.tick_every = every
	field.damage_ratio = ratio
	field.root_time = root_duration
	field.slow_strength = slow
	actor.get_parent().add_child(field)
	field.global_position = at
	return field

func direct_hit(enemy: EnemyBase, ratio: float,skill_id:StringName=&"",natural_source:=true,at:Vector2=Vector2.ZERO) -> bool:
	if not live(enemy): return false
	var before := enemy.hp
	var shield_before:=enemy.affix_shield
	var amount := attack() * ratio * actor.equipment_mechanics.skill_multiplier(enemy) * skill_bonus()
	if rank(&"ilyua_wild_growth") >= 1 and natural_source and controlled(enemy): amount *= 1.08
	if natural_source:natural_hits[enemy.get_instance_id()]=true
	enemy.take_damage(amount, false, actor.global_position if at==Vector2.ZERO else at, DamageContext.field(actor), false)
	if natural_hits.has(enemy.get_instance_id()) and (enemy.hp<before or enemy.affix_shield<shield_before):on_direct_natural_hit(enemy)
	natural_hits.erase(enemy.get_instance_id())
	if enemy.hp < before or enemy.affix_shield<shield_before:
		actor.equipment_mechanics.on_skill_hit(enemy, true)
		skill_effective_hit(skill_id,enemy)
	return enemy.hp < before or enemy.affix_shield<shield_before

func skill_bonus()->float:return 1.1 if float(_skill_history.get("will_until",0))>clock else 1.0

func proc(enemy:EnemyBase,ratio:float,from:Vector2=Vector2.ZERO)->bool:
	if not live(enemy) or enemy.hp<=0:return false
	var before:=enemy.hp;var shield:=enemy.affix_shield
	enemy.take_damage(attack()*ratio,false,from if from!=Vector2.ZERO else actor.global_position,DamageContext.character_proc(actor),false)
	return enemy.hp<before or enemy.affix_shield<shield

func area_proc(at: Vector2, radius: float, ratio: float, cap: int = 999) -> void:
	var count := 0
	for enemy in enemies_in(at, radius):
		if count >= cap: break
		if proc(enemy, ratio, at): count += 1

func root_enemy(enemy: EnemyBase, duration: float) -> void:
	if live(enemy) and not enemy is BossBase: enemy.ilyua_root_left = maxf(enemy.ilyua_root_left, duration)

func forest_step()->void:
	var direction:=actor.movement_override if actor.movement_override!=Vector2.ZERO else RoomInput.movement()
	step_direction=(direction if direction!=Vector2.ZERO else actor.aim_direction).normalized()
	step_left=.18;actor._invuln=maxf(actor._invuln,.18)
	spawn_decoy(actor.global_position,3,true)
	on_dash_started(false)
	IlyuaFX.spawn(actor.get_parent(),actor.global_position,"step",72,.3)

func spawn_decoy(at:Vector2,duration:float,death_volley:=false)->IlyuaDecoy:
	var decoy:=IlyuaDecoy.new();decoy.runtime=self;decoy.remaining=duration;decoy.leaves_left=2 if rank(&"ilyua_forest_shadow")>=3 else 0
	decoy.death_volley=death_volley
	actor.get_parent().add_child(decoy);decoy.global_position=at;return decoy

func step_motion(delta:float)->Vector2:
	var time:=minf(step_left,delta);step_left=maxf(0,step_left-delta)
	return step_direction*600*time/maxf(.0001,delta)

func field_tick(field:IlyuaField)->void:
	if field.kind==&"seed":
		var enemy:EnemyBase=field.owner_enemy.get_ref() as EnemyBase if field.owner_enemy!=null else null
		if live(enemy) and proc(enemy,field.damage_ratio*(1.1 if overlap_seed_vine(enemy) else 1.0),field.global_position):actor.heal_player(1)
	elif field.kind in [&"trap",&"zone",&"wild_zone",&"spread_vine",&"tree"]:
		for enemy in enemies_in(field.global_position,field.radius):
			var ratio:=field.damage_ratio
			if field.kind==&"trap" and overlap_seed_vine(enemy):ratio*=1.1
			if field.kind in [&"trap",&"tree"]:direct_hit(enemy,ratio,&"ilyua_vine_trap" if field.kind==&"trap" else &"ilyua_ancient_tree",true,field.global_position)
			else:proc(enemy,ratio,field.global_position)

func overlap_seed_vine(enemy:EnemyBase)->bool:
	if rank(&"ilyua_nature_resonance")<2 or not seed_marks.has(enemy.get_instance_id()):return false
	for trap in active_fields(&"trap"):
		if trap.global_position.distance_to(enemy.global_position)<=trap.radius:return true
	return false

func tree_leaves(field:IlyuaField)->void:
	var targets:=enemies_in(field.global_position,field.radius)
	targets.sort_custom(func(a:EnemyBase,b:EnemyBase)->bool:return a.global_position.distance_squared_to(field.global_position)<b.global_position.distance_squared_to(field.global_position))
	for i in mini(3,targets.size()):spawn_arrow(&"tree_shot",field.global_position,(targets[i].global_position-field.global_position).normalized(),field.damage_ratio/.06*.2,false,false,null,targets[i])

func attach_seed(enemy: EnemyBase, duration: float, ratio: float, generation: int = 0) -> void:
	if not live(enemy): return
	var existing := seed_marks.get(enemy.get_instance_id(), {}) as Dictionary
	if not existing.is_empty() and is_instance_valid(existing.get("field")):
		var old: IlyuaField = existing.field
		old.remaining = maxf(old.remaining, duration)
		existing.until=clock+old.remaining
		seed_marks[enemy.get_instance_id()]=existing
		old.damage_ratio = maxf(old.damage_ratio, ratio)
		return
	var field := make_field(&"seed", enemy.global_position, 0.0, duration, 1.0, ratio)
	field.owner_enemy = weakref(enemy)
	field.generation = generation
	seed_marks[enemy.get_instance_id()] = {"enemy": weakref(enemy), "field": field, "until": clock + duration}
	IlyuaFX.spawn(enemy, Vector2.ZERO, "seed", 38.0, 0.5)

func finish_tree(field:IlyuaField)->void:
	for enemy in enemies_in(actor.global_position,10000):
		proc(enemy,.8,field.global_position)
		var count:=0
		for plant in field.plants:
			if count>=4:break
			if plant.distance_to(enemy.global_position)<=72:proc(enemy,.15,plant);count+=1
	IlyuaFX.spawn(actor.get_parent(),field.global_position,"tree_end",field.radius*2,.5)

func on_arrow_bounce(arrow:IlyuaArrow)->void:
	if arrow.is_basic_attack and rank(&"ilyua_returning_arrow")>=2:arrow.redirect_left=1

func arrow_multiplier(arrow:IlyuaArrow,enemy:EnemyBase)->float:
	var result:=1.0
	if arrow.main_arrow and rank(&"ilyua_wild_growth")>=1 and controlled(enemy):result*=1.08
	if arrow.is_basic_attack and rank(&"ilyua_true_shot")>=1:
		var record:Dictionary=true_hits.get(enemy.get_instance_id(),{})
		if not record.is_empty() and float(record.until)>clock:result*=1+minf(.09,int(record.count)*.03)
	return result

func controlled(enemy:EnemyBase)->bool:
	if enemy.ilyua_root_left>0:return true
	for field in active_fields(&"trap"):
		if field.global_position.distance_to(enemy.global_position)<=field.radius:return true
	return false

func allow_volley_hit(arrow:IlyuaArrow,enemy:EnemyBase)->bool:
	if arrow.volley_id.is_empty():return true
	var record:Dictionary=volley_hits.get(arrow.volley_id,{})
	var id:=enemy.get_instance_id()
	if int(record.get(id,0))>=3:return false
	record[id]=int(record.get(id,0))+1;volley_hits[arrow.volley_id]=record;return true

func on_arrow_hit(arrow:IlyuaArrow,enemy:EnemyBase,effective:bool)->void:
	if not effective or not is_instance_valid(enemy):return
	if not arrow.main_arrow and arrow.primary_skill==&"":
		if arrow.arrow_kind==&"true_pierce" and rank(&"ilyua_true_shot")>=3:
			var count:=0
			for node in get_tree().get_nodes_in_group("room_projectiles"):
				if count>=2:break
				if node is IlyuaArrow and node.runtime==self and node.is_basic_attack and node._hit_ids.is_empty() and not node.guided and node.global_position.distance_to(enemy.global_position)<=144 and not node.is_queued_for_deletion() and live(enemy):
					node.guided=true;node.target_ref=weakref(enemy);node.basic_tracking=false;node.homing_turn=TAU*2;count+=1
		return
	if arrow.arrow_kind==&"seed" and live(enemy):attach_seed(enemy,4,arrow.seed_ratio)
	if arrow.arrow_kind==&"wind":
		for i in mini(2,4-arrow.blades_spawned):
			var target:=nearest_enemy(enemy.global_position,144,enemy)
			if target==null and live(enemy):target=enemy
			if target!=null:spawn_arrow(&"wind_blade",enemy.global_position,(target.global_position-enemy.global_position).normalized(),.2,false,false,null,target);arrow.blades_spawned+=1
	if not arrow.is_basic_attack:
		if arrow.primary_skill!=&"":skill_effective_hit(arrow.primary_skill,enemy)
		return
	var first:=arrow.attack_receipt==null or arrow.attack_receipt.claim_effect(&"ilyua_first_hit")
	if first:first_basic_hit(enemy,arrow)
	if arrow.wind_skill_serial>wind_hit_serial:
		wind_hit_serial=arrow.wind_skill_serial;skill_effective_hit(&"ilyua_wind_arrow",enemy)
	if not live(enemy):return
	var id:=enemy.get_instance_id()
	if arrow.arrow_kind==&"ultimate_basic":
		ultimate_hits[id]=int(ultimate_hits.get(id,0))+1
		if first and Rng.stream().randf()<.25:spawn_arrow(&"wind_blade",enemy.global_position,arrow.direction,.18,false,false,null,nearest_enemy(enemy.global_position,144,enemy))
		var key:=StringName("ultimate_%d"%id)
		if int(ultimate_hits[id])>=5 and ready(key):
			ultimate_hits[id]=0;start(key,1)
			var special:=spawn_arrow(&"ultimate_pierce",actor.global_position,arrow.direction,.6,false,false,null,enemy)
			if special!=null:special.pierce_left=2
	if rank(&"ilyua_true_shot")>=1:
		var record:Dictionary=true_hits.get(id,{"count":0,"until":clock+2})
		record.count=int(record.count)+1;record.until=clock+2;true_hits[id]=record
		if rank(&"ilyua_true_shot")>=2 and int(record.count)%5==0 and ready(&"true_shot"):
			start(&"true_shot",1)
			var shot:=spawn_arrow(&"true_pierce",actor.global_position,arrow.direction,.4,false,false,null,enemy)
			if shot!=null:shot.pierce_left=2
	if marked.has(id):
		var mark:Dictionary=marked[id];mark.hits=int(mark.hits)+1
		var key:=StringName("precision_%d"%id)
		if int(mark.hits)>=3 and ready(key):
			mark.hits=0;start(key,1);spawn_arrow(&"precision",actor.global_position,(enemy.global_position-actor.global_position).normalized(),.6,false,false,null,enemy)
		marked[id]=mark

func first_basic_hit(enemy:EnemyBase,arrow:IlyuaArrow=null)->void:
	if GameState.passive_id==&"ilyua_wind_rhythm":
		wind_stacks=mini(5,wind_stacks+1);refresh_wind()
		if wind_stacks==5 and ready(&"wind_rhythm") and Rng.stream().randf()<.2:
			var other:=nearest_enemy(enemy.global_position,108,enemy)
			if other!=null:spawn_arrow(&"wind_blade",enemy.global_position,(other.global_position-enemy.global_position).normalized(),.2,false,false,null,other);start(&"wind_rhythm",.6)
	if GameState.passive_id==&"ilyua_forest_whisper" and Rng.stream().randf()<.2:attach_forest_mark(enemy,4,.08,0)
	if rank(&"ilyua_wind_feathers")>=2 and ready(&"wind_feathers") and Rng.stream().randf()<.15:
		var target:=nearest_enemy(enemy.global_position,108,enemy)
		if target==null and live(enemy):target=enemy
		if target!=null:spawn_arrow(&"feather",enemy.global_position,(target.global_position-enemy.global_position).normalized(),.15,false,false,null,target if rank(&"ilyua_wind_feathers")>=3 else null);start(&"wind_feathers",.8)
	if rank(&"ilyua_life_sprout")>=1 and Rng.stream().randf()<.1:attach_sprout(enemy,4,0)
	if arrow!=null and arrow.weapon_fx=="bow_spring_wind" and ready(&"spring_bow") and Rng.stream().randf()<.15:
		var target:=nearest_enemy(enemy.global_position,108,enemy)
		if target==null and live(enemy):target=enemy
		if target!=null:spawn_arrow(&"wind_blade",enemy.global_position,(target.global_position-enemy.global_position).normalized(),.15,false,false,null,target);start(&"spring_bow",.8)
	if arrow!=null and arrow.pact_empowered:
		proc(enemy,.12)
		if rank(&"ilyua_ancient_pact")>=2 and ready(&"pact_reduction"):
			start(&"pact_reduction",1)
			for id in GameState.skill_cooldowns_by_id:
				if not Skills.get_skill(id).get("ultimate",false):GameState.skill_cooldowns_by_id[id]=maxf(0,float(GameState.skill_cooldowns_by_id[id])-.2)
			GameState._sync_skill_cooldowns()

func attach_sprout(enemy:EnemyBase,duration:float,generation:int)->void:
	if not live(enemy):return
	sprout_marks[enemy.get_instance_id()]={"enemy":weakref(enemy),"until":clock+duration,"ratio":.06,"tick":0.0,"generation":generation}
	IlyuaFX.spawn(enemy,Vector2.ZERO,"seed",32,duration)

func attach_forest_mark(enemy: EnemyBase, duration: float, ratio: float, generation: int) -> void:
	if not live(enemy): return
	var key := enemy.get_instance_id()
	var existing: Dictionary = mature_marks.get(key, {})
	if not existing.is_empty() and float(existing.get("until", 0.0)) > clock:
		existing.until = maxf(float(existing.until), clock + duration)
		existing.ratio = maxf(float(existing.ratio), ratio)
		mature_marks[key] = existing
		return
	mature_marks[key] = {"enemy": weakref(enemy), "until": clock + duration, "ratio": ratio, "tick": 0.0, "generation": generation}
	IlyuaFX.spawn(enemy, Vector2.ZERO, "forest_mark", 38.0, 0.4)

func on_direct_natural_hit(enemy:EnemyBase)->void:
	if not is_instance_valid(enemy) or enemy._dead:return
	if GameState.passive_id==&"ilyua_forest_whisper" and mature_marks.has(enemy.get_instance_id()) and ready(&"forest_whisper_hit"):
		start(&"forest_whisper_hit",1);area_proc(enemy.global_position,72,.12)
	var key:=StringName("resonance_%d"%enemy.get_instance_id())
	if rank(&"ilyua_nature_resonance")>=1 and seed_marks.has(enemy.get_instance_id()) and ready(key):
		var seed:IlyuaField=seed_marks[enemy.get_instance_id()].get("field") as IlyuaField
		if is_instance_valid(seed):seed.damage_ratio*=1.1
		start(key,1)
	for field in active_fields(&"trap"):
		if field.global_position.distance_to(enemy.global_position)>field.radius or field.spread_used>=3+(2 if rank(&"ilyua_wild_growth")>=2 else 0) or clock<field.next_spread:continue
		var other:=nearest_enemy(enemy.global_position,72,enemy)
		if other!=null:
			field.spread_used+=1;field.next_spread=clock+1
			var vine:=make_field(&"spread_vine",other.global_position,12,minf(2,field.remaining),1,.12,.8,.35);vine.owner_enemy=weakref(other)
			root_enemy(other,.8);other.apply_slow(.35,minf(2,field.remaining))

func skill_effective_hit(id:StringName,enemy:EnemyBase)->void:
	if id==&"" or IlyuaSkills.DATA.get(id,{}).get("ultimate",false):return
	var history:Dictionary=_skill_history.get("different",{})
	for key in history.keys():
		if float(history[key])<clock-6:history.erase(key)
	history[str(id)]=clock;_skill_history["different"]=history
	if rank(&"ilyua_ancient_pact")>=3 and history.size()>=2 and ready(&"ancient_pact"):
		start(&"ancient_pact",5);_skill_history["different"]={};proc(enemy,.4)

func seed_burst(at:Vector2,ratio:float)->void:
	area_proc(at,72,ratio);IlyuaFX.spawn(actor.get_parent(),at,"seed_burst",144,.4)
	if rank(&"ilyua_nature_resonance")<3 or not ready(&"resonance_pulse"):return
	var count:=0
	for field in get_tree().get_nodes_in_group("ilyua_fields"):
		if count>=2:break
		if field is IlyuaField and field.runtime==self and field.kind in [&"trap",&"tree",&"zone",&"wild_zone"] and not field.is_queued_for_deletion() and field.global_position.distance_to(at)<=72+field.radius:
			count+=1;area_proc(field.global_position,field.radius,.1)
	if count>0:start(&"resonance_pulse",1)

func on_small_skill(_id:StringName)->void:
	if rank(&"ilyua_ancient_pact")>=1:next_basic_bonus=.12;next_basic_until=clock+4

func refresh_wind()->void:
	if not is_instance_valid(actor):return
	for i in range(GameState.temp_buffs.size()-1,-1,-1):
		if str(GameState.temp_buffs[i].get("label","")) in ["风之律动·攻速","风之律动·移动"]:GameState.temp_buffs.remove_at(i)
	if wind_stacks>0:GameState.temp_buffs.append({"stat":&"attack_speed","value":wind_stacks*.02,"remaining":3600.0,"label":"风之律动·攻速"})
	GameState._reset_stats();EventBus.player_stats_changed.emit()

func moon_block_projectiles()->void:
	for bullet in get_tree().get_nodes_in_group("room_projectiles"):
		if not bullet is RoomProjectile or bullet.is_friendly or bullet.is_queued_for_deletion() or bullet.has_meta("boss_owner") or bullet.art_scale>=1.5:continue
		for i in moon_slots.size():
			if not moon_available(i):continue
			var at:=moon_position(i)
			if bullet.global_position.distance_to(at)>18:continue
			consume_moon(i);bullet.queue_free();IlyuaFX.spawn(actor.get_parent(),bullet.global_position,"moon_block",48,.3)
			if rank(&"ilyua_moon_guard")>=2:
				var target:=nearest_enemy(actor.global_position,144)
				if target!=null:spawn_arrow(&"moon_reflect",at,(target.global_position-at).normalized(),.15,false,false,null,target)
			break

func moon_available(index:int)->bool:return float(moon_slots[index].ready)<=clock
func moon_position(index:int)->Vector2:return actor.global_position+Vector2.RIGHT.rotated(clock*2.5+TAU*index/maxi(1,moon_slots.size()))*36
func consume_moon(index:int)->void:
	moon_slots[index].ready=clock+(6 if moon_slots[index].kind=="guard" else 3)
	if moon_slots[index].kind=="reaction":moon_slots[index].expires=clock

func _update_moons(_delta:float)->void:
	for i in range(moon_slots.size()-1,-1,-1):
		if moon_slots[i].kind!="guard" and float(moon_slots[i].expires)<=clock:moon_slots.remove_at(i)
	var has_guard:=false
	for slot in moon_slots:
		if slot.kind=="guard":has_guard=true
	if rank(&"ilyua_moon_guard")>=1 and not has_guard:moon_slots.append({"kind":"guard","ready":clock,"expires":0.0})
	moon_charges=0
	for i in moon_slots.size():
		if moon_available(i):moon_charges+=1
	moon_block_projectiles()
	if ready(&"moon_shoot") and (moon_left>0 or moon_slots.any(func(slot:Dictionary)->bool:return slot.kind=="reaction")):
		moon_shoot();start(&"moon_shoot",.6)
	while _moon_visuals.size()<moon_slots.size():_moon_visuals.append(IlyuaFX.spawn(actor,Vector2.ZERO,"moon",22,3600))
	for i in _moon_visuals.size():
		if not is_instance_valid(_moon_visuals[i]):continue
		_moon_visuals[i].visible=i<moon_slots.size() and moon_available(i)
		if i<moon_slots.size():_moon_visuals[i].global_position=moon_position(i)

func moon_shoot()->void:
	var target:=nearest_enemy(actor.global_position,144)
	if target==null:return
	for i in moon_slots.size():
		if moon_slots[i].kind=="guard" or not moon_available(i):continue
		var at:=moon_position(i);spawn_arrow(&"moon",at,(target.global_position-at).normalized(),.15 if moon_slots[i].kind=="reaction" else .3,false,false,null,target);consume_moon(i)

func on_dash_started(base_dash:=true)->void:
	dash_serial+=1;dash_start=clock;_step_hit_ids.clear()
	if rank(&"ilyua_forest_shadow")>=1:GameState.add_temp_buff(&"move_speed",.10,2,"林影")
	if base_dash and rank(&"ilyua_forest_shadow")>=2 and ready(&"shadow_decoy"):spawn_decoy(actor.global_position,2);start(&"shadow_decoy",6)
	moon_dash_hits()

func moon_dash_hits()->void:
	if moon_left<=0 or moon_charges<=0:return
	for enemy in enemies_in(actor.global_position,54):
		if _step_hit_ids.has(enemy.get_instance_id()):continue
		_step_hit_ids[enemy.get_instance_id()]=true;proc(enemy,.2)

func on_damage_refused(source:Node)->void:
	if (actor._dash_timer<=0 and step_left<=0) or not is_instance_valid(source):return
	if rank(&"ilyua_light_body")>=2 and source is Node2D and actor.global_position.distance_to(source.global_position)<=72:
		light_empower=true;light_empower_until=clock+3
		if rank(&"ilyua_light_body")>=3:_skill_history["phase_until"]=clock+1
	if rank(&"ilyua_moon_guard")>=3 and clock-dash_start<=.12 and ready(&"moon_perfect"):
		start(&"moon_perfect",4)
		for i in mini(2,8-moon_slots.size()):moon_slots.append({"kind":"reaction","ready":clock,"expires":clock+3})

func on_hp_damage(amount:float)->void:
	if amount<=0:return
	if wind_stacks>0:wind_stacks=maxi(0,wind_stacks-2);refresh_wind()
	if rank(&"ilyua_forest_will")<1 or actor.hp>=actor.max_hp*.3 or not ready(&"forest_will"):return
	start(&"forest_will",30);actor.equipment_mechanics.grant_player_shield(actor.max_hp*.12,3,&"extend")
	if rank(&"ilyua_forest_will")>=2:
		for enemy in enemies_in(actor.global_position,72):
			enemy.apply_slow(.35,2)
			if rank(&"ilyua_forest_will")>=3:
				proc(enemy,.3)
				push_enemy(enemy,12 if enemy is BossBase else 24)
	if rank(&"ilyua_forest_will")>=3:_skill_history["will_until"]=clock+4

func push_enemy(enemy:EnemyBase,distance:float)->void:
	if not live(enemy):return
	var direction:=(enemy.global_position-actor.global_position).normalized()
	var radius:=actor.caster._push_body_radius(enemy)
	var origin:=enemy.global_position
	for i in range(1,ceili(distance/3)+1):
		var at:=origin+direction*minf(distance,i*3)
		if not actor.room.body_clear(at,radius,enemy.is_flying() if enemy.has_method("is_flying") else false):break
		enemy.global_position=at
	enemy.reset_path()

func finish_ultimate()->void:
	if not ultimate_finish_pending:return
	ultimate_finish_pending=false
	var volley:="finish_%d"%dash_serial+"_%s"%clock
	for i in 12:
		var arrow:=spawn_arrow(&"ultimate_finish",actor.global_position,Vector2.RIGHT.rotated(TAU*i/12),.2,false,false)
		if arrow!=null:arrow.volley_id=volley;arrow.homing_turn=0
	IlyuaFX.spawn(actor.get_parent(),actor.global_position,"ultimate_end",180,.5)

func _on_enemy_damaged(enemy:EnemyBase,amount:float,source:Node,_damage_type:StringName)->void:
	if amount>0 and natural_hits.has(enemy.get_instance_id()) and DamageContext.is_skill(source,actor):
		natural_hits.erase(enemy.get_instance_id());on_direct_natural_hit(enemy)

func _on_enemy_died(enemy:EnemyBase,source:Node,_damage_type:StringName)->void:
	var id:=enemy.get_instance_id();var was_seeded:=seed_marks.has(id)
	_observed.erase(id)
	for tree in active_fields(&"tree"):
		if was_seeded and tree.plant_count<6 and tree.global_position.distance_to(enemy.global_position)<=tree.radius:
			tree.plants.append(enemy.global_position);tree.plant_count=tree.plants.size();tree.radius=minf(252,144+tree.plant_count*18)
			IlyuaFX.spawn(actor.get_parent(),enemy.global_position,"thorn",36,tree.remaining)
	if was_seeded:
		var seed:IlyuaField=seed_marks[id].get("field") as IlyuaField
		seed_marks.erase(id)
		if is_instance_valid(seed):
			seed_burst(enemy.global_position,.4)
			if seed.generation==0:
				var near:=sorted_near(enemy.global_position,72,enemy)
				for i in mini(2,near.size()):
					if Rng.stream().randf()<.5:attach_seed(near[i],seed.remaining,seed.damage_ratio,1)
			seed.queue_free()
	if mature_marks.has(id):
		var mark:Dictionary=mature_marks[id];mature_marks.erase(id)
		if int(mark.generation)==0:
			var near:=sorted_near(enemy.global_position,72,enemy)
			for i in mini(2,near.size()):
				if Rng.stream().randf()<.4:attach_forest_mark(near[i],maxf(.01,float(mark.until)-clock),.08,1)
		_kill_times.append(clock)
		while not _kill_times.is_empty() and _kill_times[0]<clock-2:_kill_times.pop_front()
		if _kill_times.size()>=3 and ready(&"forest_zone"):make_field(&"zone",enemy.global_position,72,3,1,.12);start(&"forest_zone",6);_kill_times.clear()
	sprout_marks.erase(id)
	if marked.has(id):
		var mark:Dictionary=marked[id];marked.erase(id)
		if int(mark.transfers)<3:
			var next:=nearest_enemy(enemy.global_position,144,enemy)
			if next!=null:marked[next.get_instance_id()]={"enemy":weakref(next),"until":mark.until,"hits":0,"transfers":int(mark.transfers)+1};IlyuaFX.spawn(next,Vector2.ZERO,"mark",44,maxf(.01,float(mark.until)-clock))
	if rank(&"ilyua_wild_growth")>=3 and controlled(enemy):
		var zones:=active_fields(&"wild_zone")
		if zones.size()>=4:zones[0].queue_free()
		make_field(&"wild_zone",enemy.global_position,72,2,1,.08)
	var direct:bool=(source is IlyuaArrow and source.runtime==self and source.main_arrow) or DamageContext.is_skill(source,actor)
	if direct and rank(&"ilyua_nature_favor")>=1 and Rng.stream().randf()<.2:
		blessing=1
		if rank(&"ilyua_nature_favor")>=2:next_natural_bonus=.15
		_favor_times.append(clock)
		while not _favor_times.is_empty() and _favor_times[0]<clock-6:_favor_times.pop_front()
		if rank(&"ilyua_nature_favor")>=3 and _favor_times.size()>=3 and ready(&"nature_favor"):
			start(&"nature_favor",8);_skill_history["favor_until"]=clock+4;_skill_history["favor_tick"]=clock+1;_favor_times.clear()

func sorted_near(at:Vector2,radius:float,exclude:EnemyBase=null)->Array[EnemyBase]:
	var near:=enemies_in(at,radius,exclude)
	near.sort_custom(func(a:EnemyBase,b:EnemyBase)->bool:return a.global_position.distance_squared_to(at)<b.global_position.distance_squared_to(at))
	return near

func _tick_marks(delta:float)->void:
	for pair:Array in [[mature_marks,false],[sprout_marks,true]]:
		var table:Dictionary=pair[0]
		for key in table.keys():
			if not table.has(key):continue
			var mark:Dictionary=table[key];var enemy:EnemyBase=mark.enemy.get_ref() as EnemyBase
			if not live(enemy):table.erase(key);continue
			mark.tick=float(mark.tick)+delta
			while float(mark.tick)>=1:
				mark.tick=float(mark.tick)-1;proc(enemy,float(mark.ratio),enemy.global_position)
				if not live(enemy):break
			if not table.has(key):continue
			if float(mark.until)<=clock:
				table.erase(key)
				if bool(pair[1]) and rank(&"ilyua_life_sprout")>=2:
					seed_burst(enemy.global_position,.2)
					if rank(&"ilyua_life_sprout")>=3 and int(mark.generation)==0:
						var target:=nearest_enemy(enemy.global_position,72,enemy)
						if target!=null:attach_sprout(target,4,1)
			else:table[key]=mark
	if float(_skill_history.get("favor_until",0))>=clock and clock>=float(_skill_history.get("favor_tick",INF)):
		_skill_history["favor_tick"]=clock+1
		var target:=nearest_enemy(actor.global_position,144)
		if target!=null:spawn_arrow(&"favor",actor.global_position,(target.global_position-actor.global_position).normalized(),.12,false,false,null,target)

func on_room_exit()->void:
	for group in ["ilyua_fields","ilyua_decoys","room_projectiles"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is IlyuaField or node is IlyuaDecoy or node is IlyuaArrow:
				if node.runtime==self:node.queue_free()
	for ref in _observed.values():
		var enemy:EnemyBase=ref.get_ref() as EnemyBase
		if is_instance_valid(enemy):
			if enemy.died.is_connected(_on_enemy_died):enemy.died.disconnect(_on_enemy_died)
			if enemy.damage_applied.is_connected(_on_enemy_damaged):enemy.damage_applied.disconnect(_on_enemy_damaged)
	for table:Dictionary in [_observed,seed_marks,marked,mature_marks,sprout_marks,true_hits,ultimate_hits,precision_hits,volley_hits]:table.clear()
	step_left=0

func snapshot() -> Dictionary:
	var fields: Array = []
	var decoys: Array = []
	var arrows: Array = []
	for field in get_tree().get_nodes_in_group("ilyua_fields"):
		if field is IlyuaField and field.runtime == self and not field.is_queued_for_deletion(): fields.append(field.snapshot())
	for decoy in get_tree().get_nodes_in_group("ilyua_decoys"):
		if decoy is IlyuaDecoy and decoy.runtime == self and not decoy.is_queued_for_deletion(): decoys.append(decoy.snapshot())
	for arrow in get_tree().get_nodes_in_group("room_projectiles"):
		if arrow is IlyuaArrow and arrow.runtime == self and not arrow.is_queued_for_deletion(): arrows.append(arrow.snapshot())
	var save_marks: Array = []
	for mark in mature_marks.values():
		var enemy: EnemyBase = mark.enemy.get_ref() as EnemyBase if mark.get("enemy") is WeakRef else null
		if live(enemy): save_marks.append({"enemy": str(enemy.get_instance_id()), "left": maxf(0.0, float(mark.until) - clock), "ratio": mark.ratio, "generation": mark.generation, "tick": mark.tick})
	var save_hunter: Array = []
	for mark in marked.values():
		var enemy: EnemyBase = mark.enemy.get_ref() as EnemyBase if mark.get("enemy") is WeakRef else null
		if live(enemy): save_hunter.append({"enemy": str(enemy.get_instance_id()), "left": maxf(0.0, float(mark.until) - clock), "hits": mark.hits, "transfers": mark.transfers})
	var saved_cooldowns := {}
	for key in cooldowns: saved_cooldowns[str(key)] = maxf(0.0, float(cooldowns[key]) - clock)
	return {"wind_pierce_left":maxf(0,wind_pierce_until-clock),"wind_pierce_serial":wind_pierce_serial,"wind_hit_serial":wind_hit_serial,"clock":clock,"move_time":move_time,"stop_time":stop_time,"step_left":step_left,"step_direction":[step_direction.x,step_direction.y],"moon_slots":moon_slots.duplicate(true),"favor_times":_favor_times.duplicate(),"sprout_marks":_save_marks(sprout_marks),"volley_hits":volley_hits.duplicate(true),"ultimate_left": ultimate_left, "ultimate_pending": ultimate_finish_pending, "wind_stacks": wind_stacks, "wind_grace": wind_grace, "no_fire": no_fire, "moon_charges": moon_charges, "moon_regen": moon_regen, "moon_left": moon_left, "dash_serial": dash_serial, "blessing": blessing, "next_basic_bonus": next_basic_bonus, "next_basic_left": maxf(0.0, next_basic_until - clock), "next_natural_bonus": next_natural_bonus, "light_empower": light_empower, "light_left": maxf(0.0, light_empower_until - clock), "cooldowns": saved_cooldowns, "fields": fields, "decoys": decoys, "arrows": arrows, "forest_marks": save_marks, "hunter_marks": save_hunter, "true_hits": true_hits.duplicate(true), "ultimate_hits": ultimate_hits.duplicate(true), "precision_hits": precision_hits.duplicate(true), "kill_times": _kill_times.duplicate(), "skill_history": _skill_history.duplicate(true)}

func restore(data: Dictionary, restored_nodes: Dictionary = {}) -> void:
	on_room_exit()
	clock=float(data.get("clock",0))
	move_time=float(data.get("move_time",0));stop_time=float(data.get("stop_time",0));step_left=float(data.get("step_left",0))
	var saved_direction:Array=data.get("step_direction",[0,0]);step_direction=Vector2(saved_direction[0],saved_direction[1])
	moon_slots.clear()
	for slot in data.get("moon_slots",[]):moon_slots.append(slot.duplicate())
	_favor_times.clear()
	for time in data.get("favor_times",[]):_favor_times.append(float(time))
	wind_pierce_until=clock+maxf(0,float(data.get("wind_pierce_left",0)));wind_pierce_serial=int(data.get("wind_pierce_serial",0));wind_hit_serial=int(data.get("wind_hit_serial",0))
	ultimate_left = maxf(0.0, float(data.get("ultimate_left", 0.0)))
	ultimate_finish_pending = bool(data.get("ultimate_pending", false))
	wind_stacks = clampi(int(data.get("wind_stacks", 0)), 0, 5)
	wind_grace = float(data.get("wind_grace", 0.0))
	no_fire = float(data.get("no_fire", 0.0))
	moon_charges = clampi(int(data.get("moon_charges", 0)), 0, 8)
	moon_regen = float(data.get("moon_regen", 0.0))
	moon_left = float(data.get("moon_left", 0.0))
	dash_serial = int(data.get("dash_serial", 0))
	blessing = clampi(int(data.get("blessing", 0)), 0, 3)
	next_basic_bonus = float(data.get("next_basic_bonus", 0.0))
	next_basic_until = clock + float(data.get("next_basic_left", 0.0))
	next_natural_bonus = float(data.get("next_natural_bonus", 0.0))
	light_empower = bool(data.get("light_empower", false))
	light_empower_until = clock + float(data.get("light_left", 0.0))
	cooldowns.clear()
	for key in data.get("cooldowns", {}): cooldowns[StringName(key)] = clock + float(data.cooldowns[key])
	_skill_history = data.get("skill_history", {}).duplicate(true)
	_kill_times.clear()
	for age in data.get("kill_times", []): _kill_times.append(float(age))
	refresh_wind()
	for entry in data.get("fields", []):
		var p: Array = entry.get("at", [0.0, 0.0])
		var field := make_field(StringName(entry.get("kind", "seed")), Vector2(float(p[0]), float(p[1])), float(entry.get("radius", 72.0)), float(entry.get("remaining", 0.0)), float(entry.get("tick_every", 1.0)), float(entry.get("ratio", 0.0)), float(entry.get("root_time", 0.0)), float(entry.get("slow_strength", 0.0)))
		field.tick_clock = float(entry.get("tick_clock", 0.0))
		field.generation = int(entry.get("generation", 0))
		field.spread_budget = int(entry.get("spread_budget", 0))
		field.spread_used = int(entry.get("spread_used", 0))
		field.plant_count = int(entry.get("plant_count", 0))
		field.leaf_clock=float(entry.get("leaf_clock",0));field.next_spread=float(entry.get("next_spread",0))
		for point in entry.get("plants",[]):field.plants.append(Vector2(point[0],point[1]))
		for old_id in entry.get("entered", []):
			var mapped: EnemyBase = restored_nodes.get(str(old_id)) as EnemyBase
			if live(mapped): field.entered[mapped.get_instance_id()] = true
		var owner: EnemyBase = restored_nodes.get(str(entry.get("owner", ""))) as EnemyBase
		if live(owner):
			field.owner_enemy = weakref(owner)
			if field.kind == &"seed": seed_marks[owner.get_instance_id()] = {"enemy": weakref(owner), "field": field, "until": clock + field.remaining}
	for entry in data.get("decoys", []):
		var decoy := IlyuaDecoy.new()
		decoy.runtime = self
		decoy.remaining = float(entry.get("remaining", 0.0))
		decoy.hp = float(entry.get("hp", 1.0))
		decoy.leaves_left = int(entry.get("leaves_left", 0))
		decoy.leaf_clock = float(entry.get("leaf_clock", 0.0))
		decoy.death_volley=bool(entry.get("death_volley",false))
		actor.get_parent().add_child(decoy)
		var p: Array = entry.get("at", [0.0, 0.0])
		decoy.global_position = Vector2(float(p[0]), float(p[1]))
	for entry in data.get("forest_marks", []):
		var enemy: EnemyBase = restored_nodes.get(str(entry.get("enemy", ""))) as EnemyBase
		if live(enemy): mature_marks[enemy.get_instance_id()] = {"enemy": weakref(enemy), "until": clock + float(entry.get("left", 0.0)), "ratio": float(entry.get("ratio", 0.0)), "generation": int(entry.get("generation", 0)), "tick": float(entry.get("tick", 0.0))}
	for entry in data.get("hunter_marks", []):
		var enemy: EnemyBase = restored_nodes.get(str(entry.get("enemy", ""))) as EnemyBase
		if live(enemy): marked[enemy.get_instance_id()] = {"enemy": weakref(enemy), "until": clock + float(entry.get("left", 0.0)), "hits": int(entry.get("hits", 0)), "transfers": int(entry.get("transfers", 0))}
	observe_enemies()
	_restore_extra(data,restored_nodes)

func _save_marks(table:Dictionary)->Array:
	var result:Array=[]
	for mark in table.values():
		var enemy:EnemyBase=mark.enemy.get_ref() as EnemyBase
		if live(enemy):result.append({"enemy":str(enemy.get_instance_id()),"left":maxf(0,float(mark.until)-clock),"ratio":mark.ratio,"tick":mark.tick,"generation":mark.generation})
	return result

func _restore_extra(data:Dictionary,nodes:Dictionary)->void:
	for entry in data.get("sprout_marks",[]):
		var enemy:EnemyBase=nodes.get(str(entry.enemy)) as EnemyBase
		if live(enemy):sprout_marks[enemy.get_instance_id()]={"enemy":weakref(enemy),"until":clock+float(entry.left),"ratio":entry.ratio,"tick":entry.tick,"generation":entry.generation}
	for spec in [["true_hits",true_hits],["ultimate_hits",ultimate_hits],["precision_hits",precision_hits]]:
		for old in data.get(spec[0],{}):
			var enemy:EnemyBase=nodes.get(str(old)) as EnemyBase
			if live(enemy):spec[1][enemy.get_instance_id()]=data[spec[0]][old]
	for key in cooldowns.keys():
		var parts:=str(key).split("_")
		if parts.size()>1 and parts[-1].is_valid_int() and nodes.has(parts[-1]):
			var enemy:EnemyBase=nodes[parts[-1]] as EnemyBase
			if live(enemy):parts[-1]=str(enemy.get_instance_id());cooldowns[StringName("_".join(parts))]=cooldowns[key];cooldowns.erase(key)
	for volley in data.get("volley_hits",{}):
		var record:Dictionary={}
		for old in data.volley_hits[volley]:
			var enemy:EnemyBase=nodes.get(str(old)) as EnemyBase
			if live(enemy):record[enemy.get_instance_id()]=data.volley_hits[volley][old]
		volley_hits[volley]=record
	var receipts:Dictionary={}
	for entry in data.get("arrows",[]):
		var direction:Vector2=Vector2(entry.direction[0],entry.direction[1])
		var at:Vector2=Vector2(entry.at[0],entry.at[1])
		var receipt:BasicAttackReceipt
		var saved:Dictionary=entry.get("receipt",{}) if entry.get("receipt",{}) is Dictionary else {}
		if not saved.is_empty():
			var key:=str(saved.get("id",""))
			if not receipts.has(key):
				receipt=BasicAttackReceipt.new(actor);receipt.claimed=bool(saved.get("claimed",false));receipt.critical=bool(saved.get("critical",false))
				for effect in saved.get("effects",[]):receipt.effects[StringName(effect)]=true
				receipts[key]=receipt
			receipt=receipts[key]
		var arrow:=spawn_arrow(StringName(entry.kind),at,direction,float(entry.damage)/maxf(.001,attack()),bool(entry.main),bool(entry.natural),receipt)
		if arrow==null:continue
		arrow.damage=float(entry.damage);arrow.speed=float(entry.speed);arrow.range_limit=float(entry.range);arrow.traveled=float(entry.traveled);arrow.flight_left=float(entry.life)
		arrow.strong_pierce=bool(entry.get("strong_pierce",false));arrow.wind_skill_serial=int(entry.get("wind_skill_serial",0));arrow.bounce_left=int(entry.bounce_left);arrow.bounce_count=int(entry.bounce_count);arrow.pierce_left=int(entry.pierce_left);arrow.wall_seek=bool(entry.wall_seek);arrow.seek_after_bounce=bool(entry.seek_after_bounce);arrow.redirect_left=int(entry.redirect_left)
		arrow.weapon_fx=str(entry.get("weapon_fx",arrow.weapon_fx));arrow.seed_ratio=float(entry.get("seed_ratio",.18));arrow.blades_spawned=int(entry.get("blades_spawned",0));arrow.volley_id=str(entry.get("volley_id",""));arrow.pact_empowered=bool(entry.get("pact_empowered",false));arrow.guided=bool(entry.get("guided",false))
		arrow.refresh_art()
		arrow.fate_direct_multiplier=float(entry.get("fate_direct_multiplier",1.0));arrow.basic_tracking=bool(entry.get("basic_tracking",false));arrow.homing_range=float(entry.get("homing_range",108));arrow.homing_turn=float(entry.get("homing_turn",0));arrow.primary_skill=StringName(entry.get("primary_skill",""))
		var aim:Array=entry.get("owner_aim",entry.direction);arrow.owner_aim=Vector2(aim[0],aim[1])
		var target:EnemyBase=nodes.get(str(entry.get("target",""))) as EnemyBase
		if live(target):arrow.target_ref=weakref(target)
		for old in entry.get("hit_ids",[]):
			var enemy:EnemyBase=nodes.get(str(old)) as EnemyBase
			if live(enemy):arrow._hit_ids[enemy.get_instance_id()]=true;arrow.add_collision_exception_with(enemy)
