class_name RoomDirector
extends WaveDirector
const MAX_REINFORCEMENTS:=8
var deployment_cd:=0.0
static func counted_reinforcement(entry:Dictionary)->bool:return not bool(entry.get("split",false)) and bool(entry.get("reinforcement",str(entry.get("origin","normal"))=="normal"))
func reinforcement_limit()->int:return mini(MAX_REINFORCEMENTS,int(plan.get("max_alive",MAX_REINFORCEMENTS)))
func reinforcement_count()->int:
	var count:=0
	for unit in enemies_root.get_children():
		if unit is EnemyBase and unit.reinforcement_spawn and not unit._dead and not unit.is_queued_for_deletion():count+=1
	return count
func pending_reinforcements()->int:
	return room_pending.filter(counted_reinforcement).size()
signal room_cleared
var room:RoomLevel
var graph:RoomGraph
var room_record:Dictionary={}
var spawn_rng:=RandomNumberGenerator.new()
var room_pending:Array=[]
var room_intro:=false
var _room_timer:=0.0
const PRESSURE_GRACE:=[60.0,30.0,5.0]
const PRESSURE_INTERVAL:=15.0
var room_pressure_elapsed:=0.0
var room_pressure_step:=0
var rush_index:=0
var trial_index:=0
var trial_rounds:Array=[]
const RUSH_REST_SECONDS:=15.0

func pressure_attack_multiplier(step:int)->float:return minf(10.0,1.0+maxi(0,step))
func pressure_speed_multiplier(step:int)->float:return minf(2.0,1.0+maxi(0,step)*.25)

func advance_room_pressure(dt:float)->void:
	if phase!=Phase.FIGHT or extraction_hold or not GameState.run_active or get_tree().paused:return
	if _queue.is_empty() and room_pending.is_empty() and _living_enemy_count()==0:return
	room_pressure_elapsed+=maxf(0.0,dt)
	var elapsed:=room_pressure_elapsed+0.000001
	var grace:float=PRESSURE_GRACE[RunDifficulty.multiplier(GameState.difficulty)-1]
	var next_step:=mini(9,1+floori((elapsed-grace)/PRESSURE_INTERVAL)) if elapsed>=grace else 0
	if next_step<=room_pressure_step:return
	var attack_ratio:=pressure_attack_multiplier(next_step)/pressure_attack_multiplier(room_pressure_step)
	var speed_ratio:=pressure_speed_multiplier(next_step)/pressure_speed_multiplier(room_pressure_step)
	for enemy in enemies_root.get_children():
		if not enemy is EnemyBase or enemy._dead or enemy.is_queued_for_deletion():continue
		enemy.damage*=attack_ratio;enemy._damage_scale*=attack_ratio
		enemy.move_speed*=speed_ratio;enemy._speed_scale*=speed_ratio
		enemy.room_pressure_growth=next_step;enemy.queue_redraw()
	if room_pressure_step==0:EventBus.enemies_enraged.emit()
	room_pressure_step=next_step

func _ready()->void:
	EventBus.enemy_died.connect(_on_enemy_died)

func enter_room(record:Dictionary)->void:
	room_record=record
	wave=maxi(1,int(record.encounter)); time_left=0; alive=0; _queue.clear();room_pending.clear();boss=null;_room_timer=0;_kill_timer=0
	room_pressure_elapsed=0;room_pressure_step=0
	deployment_cd=0
	rush_index=0
	trial_index=0;trial_rounds.clear()
	GameState.wave_exp_multiplier=.6 if record.kind=="altar" else 1.0
	spawn_rng.seed=int(record.seed)^0x142c
	if record.cleared:
		phase=Phase.REST;total_this_wave=0;room.doors_open=bool(record.rewarded) or record.kind=="spawn";room.queue_redraw();return
	var existing_experience:=GameState.wave_exp_awarded if GameState.wave==wave and not record.delta.get("runtime",{}).is_empty() else 0.0
	GameState.wave=wave;GameState.wave_completed=false;GameState.wave_exp_awarded=float(record.delta.get("experience_awarded",existing_experience))
	if record.kind=="boss_rush":record.boss=graph.boss_ids()[rush_index]
	plan=RoomLayout.encounter(wave,str(record.boss))
	if record.kind=="boss":
		if record.boss_stats.is_empty():record.boss_stats=plan.duplicate(true)
		plan=record.boss_stats.duplicate(true)
	plan=RunDifficulty.encounter(plan,GameState.difficulty)
	if record.kind in ["altar","trial"]:plan=RoomExpansionRules.population(plan,.6 if record.kind=="altar" else 1.5)
	if record.kind=="elite":
		for attribute in ["hp_scale","damage_scale","attack_scale"]:plan[attribute]=float(plan.get(attribute,1))*1.5
	total_this_wave=int(plan.total);_hp_scale=float(plan.hp_scale)
	_damage_scale=float(plan.damage_scale);_speed_scale=float(plan.speed_scale);_attack_scale=float(plan.attack_scale)
	_boss_wave=bool(plan.boss);room.doors_open=false;phase=Phase.PREPARE;time_left=1.2
	EventBus.wave_started.emit(wave,total_this_wave)
	if not _boss_wave:
		var habitat:=str(record.get("biome","forest"))
		if record.kind in ["normal","elite"]:habitat="ruin" if graph.chapter_id==ChapterCatalog.NEXT else ("wetland" if habitat=="wetland" else "forest")
		_queue.assign(RoomEnemyComposer.compose(total_this_wave,habitat,wave,spawn_rng,int(plan.get("composition",0))))
	else:_queue.append(StringName("boss_"+str(record.boss)))
	if record.kind=="trial":
		trial_rounds=[[],[],[]]
		var shuffled:=_queue.duplicate()
		for index in range(shuffled.size()-1,0,-1):
			var pick:=spawn_rng.randi_range(0,index);var swap:Variant=shuffled[index];shuffled[index]=shuffled[pick];shuffled[pick]=swap
		for index in shuffled.size():trial_rounds[index%3].append(shuffled[index])
		_queue.assign(trial_rounds[0])
	if not _boss_wave:
		var mode:=str(record.get("encounter_mode",["resident","mixed","spawned"][posmod(int(record.seed),3)]))
		record.encounter_mode=mode
		var count:=_queue.size() if mode=="resident" else (maxi(1,int(_queue.size()*.45)) if mode=="mixed" else 0)
		count=mini(count,3)
		for i in count:
			var kind_value:StringName=_queue.pop_front()
			var at:=room.spawn_point(spawn_rng,player.global_position,14)
			for retry in 40:
				var occupied:=false
				for unit in enemies_root.get_children():
					if unit is EnemyBase and unit.position.distance_to(at)<30:occupied=true;break
				if not occupied:break
				at=room.spawn_point(spawn_rng,player.global_position,14)
			_spawn_room_enemy(kind_value,at)
		alive=_living_enemy_count()

func _process(dt:float)->void:
	if not GameState.run_active:return
	GameState.advance_play_time(dt)
	if extraction_hold:return
	if phase==Phase.REST and room_record.kind=="boss_rush" and not room_record.cleared:
		time_left=maxf(0,time_left-dt)
		if time_left<=0:_begin_rush_boss()
		return
	if phase==Phase.REST and room_record.kind=="trial" and not room_record.cleared:
		time_left=maxf(0,time_left-dt)
		if time_left<=0:_begin_trial_round()
		return
	if phase==Phase.PREPARE:
		time_left-=dt
		if time_left<=0:phase=Phase.FIGHT
	elif phase==Phase.FIGHT:
		deployment_cd=maxf(0,deployment_cd-dt)
		advance_room_pressure(dt)
		_kill_timer+=dt;_room_timer-=dt
		for pending in room_pending.duplicate():
			var counted:=counted_reinforcement(pending)
			if counted and (reinforcement_count()>=reinforcement_limit() or deployment_cd>0):continue
			pending.remaining-=dt
			if pending.remaining<=0:
				room_pending.erase(pending)
				var spawned:=_spawn_room_enemy(StringName(pending.kind),pending.at,pending.get("split",false),str(pending.get("origin","normal")),counted)
				if counted:deployment_cd=maxf(.65,float(plan.spawn_interval))
				if spawned is RoomEnemy:spawned.boss_wave_tag=str(pending.get("boss_wave_tag",""))
		alive=_living_enemy_count()
		if _room_timer<=0 and reinforcement_count()+pending_reinforcements()<reinforcement_limit() and not _queue.is_empty():
			var kind_value:StringName=_queue.pop_front()
			var at:=room.spawn_point(spawn_rng,player.global_position,26 if str(kind_value).begins_with("boss_") else 14)
			room_pending.append({"kind":str(kind_value),"at":at,"remaining":0.75,"reinforcement":true})
			RoomSpawnFX.spawn(fx_root,at)
			_room_timer=float(plan.spawn_interval)
		if _queue.is_empty() and room_pending.is_empty() and alive==0:_on_wave_cleared()

func _spawn_room_enemy(kind_value:StringName,at:Vector2,split:=false,origin:="normal",reinforcement:=false)->EnemyBase:
	var biome:=EnemyCombatPolicy.record_biome(room_record)
	if origin=="normal" and not str(kind_value).begins_with("boss_") and room_record.kind in ["normal","elite"]:
		kind_value=ChapterCatalog.enemy_variant(kind_value,graph.chapter_id,biome,spawn_rng,wave)
	elif origin=="normal" and not str(kind_value).begins_with("boss_") and EnemyCombatPolicy.biome_of(kind_value)!=biome:
		kind_value=EnemyCombatPolicy.room_variant(kind_value,biome,spawn_rng,wave)
	var enemy:EnemyBase
	var affix_list:Array[StringName]=[]
	if not split and origin=="normal" and not str(kind_value).begins_with("boss_"):
		var excluded:Array[StringName]=EnemyCombatPolicy.excluded_affixes(kind_value)
		affix_list.assign(EnemyAffixes.roll_for_wave(wave,spawn_rng,room_record.kind=="elite",excluded,GameState.difficulty))
		if room_record.kind=="elite":
			var target_count:=mini(5,affix_list.size()+2)
			for attempt in 40:
				if affix_list.size()>=target_count:break
				var additions:=EnemyAffixes.roll_for_wave(wave,spawn_rng,true,excluded,GameState.difficulty)
				for id in additions:
					if not affix_list.has(id) and EnemyAffixes.compatible(affix_list,id) and affix_list.size()<target_count:affix_list.append(id)
	if room_record.kind=="elite" or room_record.kind=="boss_rush" and str(kind_value).begins_with("boss_"):affix_list.append(EnemyAffixes.CRUEL)
	if str(kind_value).begins_with("boss_"):
		var unit:RoomBoss=CityBoss.new() if str(room_record.boss) in ChapterCatalog.bosses(ChapterCatalog.NEXT) else RoomBoss.new();unit.configure(StringName(room_record.boss));unit.room=room
		unit.setup(player,room,float(plan.boss_hp_scale),_damage_scale*pressure_attack_multiplier(room_pressure_step),_speed_scale*pressure_speed_multiplier(room_pressure_step))
		enemy=unit;boss=unit
	else:
		var unit:=RoomEnemy.new()
		unit.configure(kind_value);unit.room=room
		if not room.body_clear(at,unit.body_radius(),unit.is_flying()):at=room.nearest_clear(at,unit.body_radius(),unit.is_flying())
		unit.setup(player,room,_hp_scale*(0.2 if origin=="guardian" else (0.55 if split else 1.0)),_damage_scale*(0.4 if origin=="guardian" else 1.0)*pressure_attack_multiplier(room_pressure_step),_speed_scale*pressure_speed_multiplier(room_pressure_step));enemy=unit
	enemy.set_attack_scale(_attack_scale);enemy.director=self;enemy.fx_root=fx_root;enemy.position=at
	enemy.room_pressure_growth=room_pressure_step
	enemy.loot_origin="split" if split else origin
	enemy.reinforcement_spawn=reinforcement and not split and origin=="normal"
	enemies_root.add_child(enemy)
	enemy.died.connect(_on_unit_died)
	if enemy is RoomEnemy and not split and origin=="normal":
		if enemy.kind==&"thorn_mantis":
			for inherent in [EnemyAffixes.TELEPORT,EnemyAffixes.DEATH_BOMB]:
				if not affix_list.has(inherent):affix_list.append(inherent)
		enemy.apply_affixes(affix_list)
	elif affix_list.has(EnemyAffixes.CRUEL):enemy.apply_affixes(affix_list)
	EventBus.enemy_spawned.emit(enemy)
	return enemy

func _on_unit_died(victim:EnemyBase,_source:Node,_damage_type:StringName)->void:
	if victim is RoomEnemy and is_instance_valid(boss) and boss is RoomBoss:boss.on_minion_death(victim)
	if victim is RoomEnemy and victim.royal_command_left>0 and is_instance_valid(boss) and boss is RoomBoss:
		boss._command("ring",.8,{"at":victim.global_position,"shape":"ring","radius":72,"count":10,"speed":130,"ratio":.35,"gap":(player.global_position-victim.global_position).normalized(),"opening":1.4,"auxiliary":true})
	for node in enemies_root.get_children():
		var other:=node as RoomEnemy
		if other==null or other==victim or other._dead or not is_instance_valid(other.affix_runtime):continue
		other.affix_runtime.on_other_enemy_died(victim)

func banner_attack_multiplier(attacker:EnemyBase)->float:
	for node in enemies_root.get_children():
		var other:=node as RoomEnemy
		if other==null or other==attacker or other._dead or not other.has_affix(EnemyAffixes.WAR_BANNER):continue
		if other.global_position.distance_to(attacker.global_position)<=144:return 1.15
	return 1.0

func spawn_guardian_children(owner:RoomEnemy)->void:
	if not is_instance_valid(owner) or owner._dead:return
	for index in 2:
		var desired:=owner.global_position+Vector2(-25 if index==0 else 25,0)
		var at:=room.nearest_clear(desired,12,owner.is_flying())
		if not room.body_clear(at,12,owner.is_flying()):continue
		var child:=_spawn_room_enemy(owner.kind,at,false,"guardian")
		if child!=null:
			child.affixes.assign([EnemyAffixes.CRUEL] if room_record.kind=="elite" else []);child.danger=EnemyAffixes.total_danger(child.affixes)
			child.max_hp=owner.max_hp*.2;child.hp=child.max_hp;child.damage=owner.damage*.4;child.base_damage=child.damage;child._damage_scale=1
			child.queue_redraw()
			Effects.spawn_marker(fx_root,at,Color("ff9c72"))
	alive=_living_enemy_count()

func _on_enemy_died(_kind:StringName,_where:Vector2,_coins:int)->void:
	_kill_timer=0
	if is_instance_valid(boss):
		if boss._dead or boss.is_queued_for_deletion():boss=null
	else:boss=null

func _on_wave_cleared()->void:
	if phase==Phase.FIGHT and room_record.kind=="trial" and trial_index<2:
		phase=Phase.REST;trial_index+=1;time_left=5.0;EventBus.rest_started.emit(time_left);Outpost.request_checkpoint();return
	if phase==Phase.FIGHT and room_record.kind=="boss_rush" and rush_index<2:
		phase=Phase.REST;rush_index+=1;time_left=RUSH_REST_SECONDS
		EventBus.rest_started.emit(time_left);Outpost.request_checkpoint();return
	if phase!=Phase.FIGHT or not graph.clear_current(int(GameState.fate.get("readings",0))):return
	FateRuntime.room_clear()
	phase=Phase.CLEARED;GameState.wave_completed=true;GameState.claim_wave_experience(true)
	AchievementTracker.room_cleared(room_record,room_pressure_step)
	GameState.add_reward_coins(roundi(WaveTable.coin_reward(wave)*(.6 if room_record.kind=="altar" else (1.5 if room_record.kind=="trial" else 1.0))))
	room_cleared.emit();EventBus.wave_cleared.emit(wave)

func _begin_trial_round()->void:
	_queue.assign(trial_rounds[trial_index]);room_pending.clear();alive=0;_room_timer=0;phase=Phase.FIGHT;time_left=0
	EventBus.wave_started.emit(wave,total_this_wave);Outpost.request_checkpoint()

func _begin_rush_boss()->void:
	room_record.boss=graph.boss_ids()[rush_index]
	plan=RunDifficulty.encounter(RoomLayout.encounter(wave,str(room_record.boss)),GameState.difficulty)
	_hp_scale=float(plan.hp_scale);_damage_scale=float(plan.damage_scale);_speed_scale=float(plan.speed_scale);_attack_scale=float(plan.attack_scale)
	_boss_wave=true;_queue.assign([StringName("boss_"+str(room_record.boss))]);room_pending.clear();boss=null;alive=0;_room_timer=0
	phase=Phase.PREPARE;time_left=.9;EventBus.wave_started.emit(wave,1);Outpost.request_checkpoint()

func start_rest()->void:
	phase=Phase.REST;room_record.rewarded=true;room.sync_door_links(room_record);room.doors_open=true;room.queue_redraw()
	EventBus.rest_started.emit(0.0)
func skip_rest()->void:pass
func next_wave()->void:pass
func start_run()->void:pass
func start_run_at(_from:int)->void:pass
func is_resting()->bool:return phase==Phase.REST
func phase_title()->String:
	if room_record.get("kind","")=="trial":return "试炼 · 第%d/3轮 · 休息 %.0f 秒"%[trial_index+1,time_left] if phase==Phase.REST and not room_record.cleared else "试炼 · 第%d/3轮"%[trial_index+1]
	if room_record.get("kind","")=="altar" and phase==Phase.CLEARED:return "守卫已清除 · 选择本次出征永久誓约"
	if room_record.get("kind","")=="boss_rush":return "BossRush · 第%d/3位首领 · 休息 %.0f 秒"%[rush_index+1,time_left] if phase==Phase.REST and not room_record.cleared else "BossRush · 第%d/3位首领"%[rush_index+1]
	if room_record.get("kind","") in ["shop","tavern"]:return RoomGraph.title(str(room_record.kind))+" · 安全休整"
	if room_record.get("kind","") in ["reward","game"]:return RoomGraph.title(str(room_record.kind))+" · 自由探索"
	var mode:=str(room_record.get("encounter_mode","spawned"))
	return "房门已开 · 自由探索" if phase==Phase.REST else (("驻守敌人 · 封锁房门" if mode=="resident" else "驻守与增援 · 封锁房门" if mode=="mixed" else "敌人将至 · 封锁房门") if phase==Phase.PREPARE else "清空敌人与增援后开放通路")
func queued_count()->int:return _queue.size()+room_pending.size()
func queue_split_children(source:EnemyBase)->void:
	for i in 2:
		var at:=source.global_position+Vector2(i*26-13,0)
		if room.body_clear(at):
			room_pending.append({"kind":str(source.kind),"at":at,"remaining":0.3,"split":true})
			RoomSpawnFX.spawn(fx_root,at,0.3)
func spawn_boss_minion(count:int)->void:
	if not is_instance_valid(boss) or boss._dead:return
	var living:=_living_enemy_count()+room_pending.size()
	for i in mini(RunDifficulty.spawn_count(count,GameState.difficulty),maxi(0,int(plan.max_alive)-living)):
		var at:=room.spawn_point(spawn_rng,player.global_position)
		room_pending.append({"kind":str(boss.minion_kinds()[spawn_rng.randi_range(0,boss.minion_kinds().size()-1)]),"at":at,"remaining":0.8,"origin":"boss_minion"})
		RoomSpawnFX.spawn(fx_root,at,0.8)
func clear_boss_minions()->void:
	# A defeated boss cancels unfinished summons, not living room enemies.
	room_pending=room_pending.filter(func(entry:Dictionary)->bool:return str(entry.get("origin","normal"))!="boss_minion")
	alive=_living_enemy_count()
func _clear_pending_spawns()->void:room_pending.clear()
func _clear_pending_minions()->void:pass

func summon_necromancer(owner:RoomEnemy)->void:
	if not is_instance_valid(owner) or owner._dead:return
	# Children count toward clearing but cannot recursively summon or drop loot.
	var children:=enemies_root.get_children().filter(func(node:Node)->bool:return node is EnemyBase and node.loot_origin=="necromancer" and not node._dead).size()
	var pending:=room_pending.filter(func(entry:Dictionary)->bool:return entry.get("origin","")=="necromancer").size()
	for index in mini(2,maxi(0,8-children-pending)):
		var desired:=owner.global_position+Vector2.from_angle(owner._locked_direction.angle()+PI/2+index*PI)*42
		var at:=room.nearest_clear(desired,12)
		if not room.body_clear(at,12) or not room.unit_position_clear(at,12,owner):continue
		room_pending.append({"kind":"walker","at":at,"remaining":.65,"origin":"necromancer"})
		HostileAttackFX.pulse(fx_root,at,"caster","summon",60,.85,0,room)
