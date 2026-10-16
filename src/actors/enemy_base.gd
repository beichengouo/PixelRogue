class_name EnemyBase
extends CharacterBody2D
var training_target:=false
signal damage_applied(enemy: EnemyBase, amount: float, source: Node, damage_type: StringName)
signal died(enemy: EnemyBase, source: Node, damage_type: StringName)
## 敌人基类：血量、受伤、击退、接触伤害、死亡掉落。
##
## 具体的行动方式交给子类的 think()，这样加新怪只要写一个 think。

const HURT_FLASH := 0.12
const CONTACT_INTERVAL := 0.7
const VISUAL_SCALE := 1.125   # 与玩家一致：格子从 32px 变成 36px

## 寻路：每隔一段时间算一次到玩家的路径，地面单位沿着路径走。
## 没有寻路时，玩家站在实心平台上方怪物就完全找不到人 —— 这是加它的原因。
const PATH_INTERVAL := 0.45
const WAYPOINT_REACHED := 22.0
## 下穿单向平台时临时关掉碰撞的时长（和玩家的「↓+跳」是同一招）

var loot_origin := "normal"
## Only scheduled room reinforcements consume the director's deployment slots.
var reinforcement_spawn:=false
var reward_uid := ""
var kind: StringName = &"walker"
var display_name := "敌人"
var base_hp := 30.0
var base_damage := 16.0
var balance_revision := 4
var base_speed := 70.0
var base_coins := 2
var body_color := Color("e0576b")
var body_size := Vector2(26.0, 26.0)
## 用哪张怪物图集（assets/characters/monster_<名字>.png）；留空则退回代码画的形状
var sprite_name := ""
var uses_gravity := false
var collides_with_world := true

var hp := 1.0
var ilyua_root_left := 0.0
var max_hp := 1.0
var damage := 1.0
var move_speed := 1.0
var coin_value := 1
var telegraph := 0.0
var is_enraged := false
var room_pressure_growth := 0

var player: Node2D
var level: Level
var fx_root: Node2D          # 特效挂载点，由刷怪系统注入
var visual: Node2D
var _pixel_enemy_art := false
var _visual_release_left := 0.0
var _visual_release_duration := 0.22
var contact_area: Area2D

var _hp_scale := 1.0
var _damage_scale := 1.0
var _speed_scale := 1.0
## 出手频率倍数（波次越高越勤）：技能冷却统一除以它
var _attack_scale := 1.0
## 头顶血条：设置页可以关掉（关掉后完全不画，不影响性能）
var _show_hp_bar := true
## 精英词条（空数组 = 普通怪）
var affixes: Array[StringName] = []
var danger := 0
var _affix_timer := 0.0
var _ranged_cd := 0.0
## 滞空计时：走地单位要是长时间没落地（被卡在墙上反复跳），加一点额外重力把它拽下来
## 卡住检测：连续两次"几乎没挪动"就请波次系统把它重新投放一次
var _stuck_timer := 0.0
var _stuck_anchor := Vector2.ZERO
var _stuck_hits := 0
## 仇恨目标：玩家和酒馆帮手一视同仁，谁近就打谁（0.4 秒刷新一次）
var aggro: Node2D = null
var _aggro_timer := 0.0
const AGGRO_RANGE := 460.0
## 波次系统（重投放要用它挑新落点）；普通场景下为 null 也不影响
var director: Node = null
var _slow_time := 0.0
var _slow_strength := 0.0
var _slow_effects:Array[Dictionary]=[]
var _burn_time := 0.0
var _burn_dps := 0.0
var _burn_tick := 0.0
var _burn_source: WeakRef
var _flash := 0.0
var _contact_cd := 0.0
var _dead := false
var _facing := 1.0
var _path: Array[Vector2i] = []
var _path_index := 0
var _path_timer := 0.0
var _can_path := true
var _warning: EnemyTelegraph
var _last_damage_source: Node
var _last_damage_type: StringName = &"environment"
var affix_shield := 0.0


func setup(player_node: Node2D, level_node: Level, hp_scale: float, damage_scale: float, speed_scale: float) -> void:
	## 必须在 add_child 之前调用
	player = player_node
	level = level_node
	_hp_scale = hp_scale
	_damage_scale = damage_scale
	_speed_scale = speed_scale


func set_attack_scale(value: float) -> void:
	_attack_scale = maxf(0.2, value)


func apply_affixes(list: Array[StringName]) -> void:
	## 必须在 add_child（也就是 _ready 跑完）之后调用：有些词条要改已经算好的属性
	affixes = EnemyCombatPolicy.filtered_affixes(kind,list)
	danger = EnemyAffixes.total_danger(affixes)
	if has_affix(EnemyAffixes.HASTE):
		move_speed *= 1.25
		base_speed *= 1.25
	if danger > 0:
		# 精英：出场闪一下，让玩家一眼看到（颜色按危险度）
		Effects.spawn_marker(_fx(), global_position, EnemyAffixes.danger_color(danger))
		queue_redraw()


func has_affix(id: StringName) -> bool:
	return affixes.has(id)


func is_elite() -> bool:
	return not affixes.is_empty()


func _update_affixes(delta: float) -> void:
	if affixes.is_empty() or _dead:
		return
	if has_affix(EnemyAffixes.REGEN) and hp < max_hp:
		hp = minf(max_hp, hp + max_hp * 0.012 * delta)
		queue_redraw()
	if has_affix(EnemyAffixes.RANGED) and EnemyCombatPolicy.ranged_affix_allowed(kind):
		_ranged_cd = maxf(0.0, _ranged_cd - delta)
		if _ranged_cd <= 0.0 and player != null and is_instance_valid(player):
			_ranged_cd = attack_cd(2.0)
			if global_position.distance_to(player.global_position) < 420.0:
				_affix_shoot()
	if has_affix(EnemyAffixes.TELEPORT):
		_affix_timer = maxf(0.0, _affix_timer - delta)
		if _affix_timer <= 0.0:
			_affix_timer = attack_cd(3.6)
			_affix_teleport()


func _affix_shoot() -> void:
	## 「远程」词条：朝玩家丢一颗小弹丸
	var dir := (player.global_position + Vector2(0.0, -12.0) - global_position).normalized()
	var bullet := Projectile.new()
	bullet.is_friendly = false
	bullet.art_scale = 0.9
	var parent := _fx()
	parent.add_child(bullet)
	bullet.setup(global_position + dir * 10.0, dir, attack_damage() * 0.7, 240.0, level, player, body_color)
	Effects.hit_spark(parent, global_position + dir * 12.0, Color("ff6576"), 4)
	AudioManager.play(&"enemy_shoot", -8.0, -0.05)


func _affix_teleport() -> void:
	## 「瞬移」词条：朝玩家闪现一段距离（中间留个残影提示）
	if player == null or not is_instance_valid(player):
		return
	if navigation_paused():return
	var dir := (player.global_position - global_position).normalized()
	if dir.length() < 0.01:
		return
	var destination:=global_position+dir*92.0
	if level!=null and not _room_position_clear(destination,body_size):return
	Effects.hit_spark(_fx(), global_position, EnemyAffixes.danger_color(danger), 8)
	global_position=destination
	reset_path()
	# 别闪进墙里
	Effects.hit_spark(_fx(), global_position, EnemyAffixes.danger_color(danger), 8)
	AudioManager.play(&"dash", -8.0, 0.2)


func attack_cd(base: float) -> float:
	## 攻击/技能冷却统一走这里：后期怪出手更快
	return base / (_attack_scale * (1.2 if has_affix(EnemyAffixes.ENRAGE) and get_meta("affix_enraged",false) else 1.0))


func attack_damage() -> float:
	## 敌人打玩家的统一出口：「重创」词条会额外按玩家**最大生命的百分比**加伤，
	## 所以玩家一味堆血也扛不住，必须真的躲开。
	var amount := damage
	if has_affix(EnemyAffixes.PERCENT_DAMAGE) and player != null and is_instance_valid(player):
		var percent := maxf(amount, player.max_hp * 0.08)
		amount = percent
	if level is RoomLevel and is_instance_valid(director) and director.has_method("banner_attack_multiplier"):
		amount *= director.banner_attack_multiplier(self)
	return amount


func _ready() -> void:
	UnitBalance.apply_enemy(self)
	max_hp = base_hp * _hp_scale
	hp = max_hp
	damage = base_damage * _damage_scale
	move_speed = base_speed * _speed_scale
	coin_value = base_coins
	collision_layer = Layers.ENEMY
	add_to_group("enemies")   # 玩家的火球靠这个组找目标
	collision_mask = Layers.WORLD if collides_with_world else 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	floor_snap_length = 0.0
	_build_body_collider()
	_build_visual()
	_build_contact_area()
	_show_hp_bar = bool(SaveService.data.get("show_enemy_hp", true))
	# 会走路、且会被地形挡住的单位才需要寻路；飞行单位直接朝玩家飞
	_can_path = false
	# 错开刷新时间，避免同一帧所有怪物一起算路径
	_path_timer = Rng.next_float() * PATH_INTERVAL
	_warning = EnemyTelegraph.new()
	add_child(_warning)
	_stuck_anchor=global_position


func _draw() -> void:
	## 精英光环：危险度越高颜色越"烫"，一圈柔光 + 一圈描边
	if danger > 0 and not _dead:
		var tint := EnemyAffixes.danger_color(danger)
		var radius := maxf(body_size.x, body_size.y) * 0.78 + 6.0
		draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, 0.12))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(tint.r, tint.g, tint.b, 0.45), 2.0, true)
	## 头顶血条：宽度跟着体型走，掉血才显示（满血不画，场面干净）
	if not _show_hp_bar or _dead or hp <= 0.0 or max_hp <= 0.0 or (hp >= max_hp and room_pressure_growth==0):
		return
	var width := clampf(body_size.x + 14.0, 26.0, 54.0)
	var height := 4.0
	var origin := Vector2(-width * 0.5, -(body_size.y * 0.5 + 16.0))
	if room_pressure_growth>0:
		var font:=ThemeDB.fallback_font;var text:=str(room_pressure_growth)
		var text_width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		var at:=origin+Vector2(-text_width-4,7)
		draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,2,Color(0,0,0,.9))
		draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ff4c59"))
	# 底槽
	draw_rect(Rect2(origin + Vector2(-1.0, -1.0), Vector2(width + 2.0, height + 2.0)),
		Color(0.05, 0.06, 0.10, 0.85), true)
	draw_rect(Rect2(origin, Vector2(width, height)), Color(0.16, 0.19, 0.26), true)
	# 血量
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var fill := Palette.ENEMY_HEALTH
	draw_rect(Rect2(origin, Vector2(width * ratio, height)), fill, true)
	draw_rect(Rect2(origin, Vector2(width * ratio, 1.0)), fill.lightened(0.35), true)


func navigation_paused() -> bool:
	return _dead or _flash>0 or telegraph>0 or (_warning!=null and _warning.active)

func can_fight_from_here() -> bool:
	var offset:=aggro_position()-global_position
	var window:=engagement_window()
	return attack_target()!=null and absf(offset.x)<window.x and absf(offset.y)<window.y and can_see_target()

func engagement_window() -> Vector2:
	return Vector2(50,45)

func navigation_profile()->Dictionary:
	return {"speed":move_speed}

func reset_attack_state() -> void:
	pass

func reset_after_relocation(at:Vector2) -> void:
	_visual_release_left=0.0
	global_position=at
	velocity=Vector2.ZERO
	reset_path()
	reset_attack_state()
	stop_warning()
	telegraph=0
	_stuck_timer=0
	_stuck_hits=0
	_stuck_anchor=at
	_aggro_timer=0
	_contact_cd=0.4
	_affix_timer=maxf(_affix_timer,0.5)
	_ranged_cd=maxf(_ranged_cd,0.5)


func _update_aggro(delta: float) -> void:
	if not self is BossBase:
		var decoy:IlyuaDecoy
		var decoy_distance:=INF
		for node in get_tree().get_nodes_in_group("ilyua_decoys"):
			if not node is IlyuaDecoy or node.exploded or node.hp<=0 or node.is_queued_for_deletion():continue
			var distance:=global_position.distance_squared_to(node.global_position)
			if distance<=node.radius*node.radius and distance<decoy_distance and (level==null or level.clear_sight(global_position,node.global_position)):
				decoy=node;decoy_distance=distance
		if is_instance_valid(decoy):
			if aggro!=decoy:reset_path()
			aggro=decoy;_aggro_timer=0;return
	## 选仇恨目标：玩家和酒馆帮手**同优先级**，挑最近的那个（超出范围就盯着玩家）
	_aggro_timer -= delta
	if _aggro_timer > 0.0 and aggro != null and is_instance_valid(aggro) and float(aggro.get("hp"))>0:
		return
	_aggro_timer = 0.22
	var best: Node2D = player if is_instance_valid(player) and player.hp>0 else null
	var best_dist := INF
	if best != null:
		best_dist = global_position.distance_squared_to(best.global_position)
	var candidates:Array=level.tactics.allies(level) if level is RoomLevel else get_tree().get_nodes_in_group("allies")
	for node in candidates:
		var ally := node as Node2D
		if ally == null or not is_instance_valid(ally) or float(ally.get("hp"))<=0:
			continue
		if level is RoomLevel and (not ally is RoomAlly or ally.room!=level):continue
		var d := global_position.distance_squared_to(ally.global_position)
		if d < best_dist and (level is RoomLevel or d < AGGRO_RANGE * AGGRO_RANGE):
			best_dist = d
			best = ally
	if aggro==player or is_instance_valid(aggro) and aggro.is_in_group("allies"):
		best=RoomTactics.stable_target(aggro,best,global_position)
	if aggro != best:
		reset_path()
	aggro = best


func aggro_position() -> Vector2:
	## 「朝目标走 / 朝目标打」的地方统一改用这个，于是帮手也会被追打
	var target := attack_target()
	if target != null:
		return target.global_position
	return global_position


func attack_target() -> Node2D:
	if is_instance_valid(aggro) and float(aggro.get("hp"))>0:
		return aggro
	return player if is_instance_valid(player) and float(player.get("hp"))>0 else null


func can_see_target() -> bool:
	return attack_target()!=null and (level==null or level.clear_sight(global_position,aggro_position()))


func warn_attack(style: String, seconds: float, reach: float) -> void:
	if _warning != null:
		_warning.begin(style,seconds,reach,aggro_position()-global_position,-body_size.y*0.5-20)


func stop_warning() -> void:
	if _warning != null: _warning.stop()


func _request_relocate() -> void:
	if director != null and is_instance_valid(director) and director.has_method("relocate_enemy"):
		director.relocate_enemy(self)


func think(_delta: float) -> void:
	## 子类覆写
	pass


func _check_contact() -> void:
	if _contact_cd > 0.0:
		return
	for body in contact_area.get_overlapping_bodies():
		if body is Player and body.has_method("take_damage"):
			body.take_damage(attack_damage(), global_position, self)
			_contact_cd = CONTACT_INTERVAL
			return
		# 酒馆雇来的帮手也可以被打（它们和玩家同一物理层）
		if body is HiredAlly:
			(body as HiredAlly).take_damage(attack_damage() * 0.8, global_position, self)
			_contact_cd = CONTACT_INTERVAL
			return


func _update_visual() -> void:
	if visual == null:
		return
	if _warning != null and _warning.active:
		var aim := aggro_position()-global_position
		_warning.direction = Vector2(_facing,0) if _warning.style in ["melee","charge"] else aim.normalized()
	# 像素精灵用 flip_h 转向，不做缩放（非整数缩放会糊）
	if visual is AnimatedSprite2D:
		(visual as AnimatedSprite2D).flip_h = _facing < 0
		if _pixel_enemy_art:_update_pixel_animation(visual as AnimatedSprite2D)
	var color := Color.WHITE
	if _flash > 0.0:
		color = Color.WHITE.lerp(Color(2.2, 2.2, 2.2), float(SaveService.data.get("flash_strength", 1.0)))
	elif telegraph > 0.01:
		color = Color(1.0 + 1.6 * telegraph, 1.0 + 0.35 * telegraph, 1.0 + 0.35 * telegraph)
	elif is_enraged:
		color = Color(1.45, 0.85, 0.85)
	visual.modulate = color


func visual_attack_state()->StringName:
	return &"attack" if _visual_release_left>0.0 else &""


func visual_windup_progress()->float:
	return 0.0


func visual_locomotion_state()->StringName:
	return &"walk" if velocity.length()>5 else &"idle"

func visual_facing_direction()->float:
	return _facing


func begin_visual_release(duration:float)->void:
	_visual_release_left=duration
	_visual_release_duration=maxf(duration,0.001)
	if _pixel_enemy_art and visual is AnimatedSprite2D:
		var sprite:=visual as AnimatedSprite2D
		sprite.play(&"attack")
		sprite.set_frame_and_progress(0,0)
		sprite.speed_scale=1.0


func _update_pixel_animation(sprite:AnimatedSprite2D)->void:
	sprite.flip_h=visual_facing_direction()<0
	var action:=visual_attack_state()
	if _flash>0.0:action=&"hurt"
	elif action==&"":action=visual_locomotion_state()
	if sprite.animation!=action:
		sprite.play(action)
		sprite.set_frame_and_progress(0,0)
	if action in [&"windup",&"attack"]:
		# 使用真实战斗进度，受击插入后不重新蓄力或重复出手。
		var progress:=visual_windup_progress() if action==&"windup" else clampf(1.0-_visual_release_left/_visual_release_duration,0.0,1.0)
		sprite.pause()
		sprite.frame=mini(sprite.sprite_frames.get_frame_count(action)-1,int(progress*3))
	else:
		sprite.speed_scale=clampf(absf(velocity.x)/maxf(base_speed,1.0),0.55,2.5) if action==&"walk" else 1.0


func set_enraged(value: bool) -> void:
	## 波次拖太久时由 WaveDirector 调用：提速 + 更凶，逼玩家正面解决
	if is_enraged == value:
		return
	is_enraged = value
	if is_enraged:
		move_speed *= 1.5


func take_damage(amount: float, is_crit := false, from := Vector2.ZERO, _source: Node = null, knockback := true) -> void:
	if _dead:
		return
	var fate_factor:=FateCatalog.direct_factor(_classify_damage(_source),_source)
	amount*=fate_factor
	# 「免疫普攻」：玩家的普通火球有概率被完全挡下；头顶装备 / 技能的伤害照常结算
	if has_affix(EnemyAffixes.IMMUNE_BASIC) and _is_basic_attack(_source):
		if Rng.stream().randf() < 0.42:
			if level is RoomLevel:HostileAttackFX.pulse(_fx(),global_position,"affix","armor",46,.25,0,level)
			Effects.damage_number(_fx(), global_position + Vector2(0.0, -30.0), 0.0, false, Color("8fd0ff"))
			Effects.text(_fx(), global_position + Vector2(0.0, -52.0), "免疫", Color("8fd0ff"), 18)
			Effects.hit_spark(_fx(), global_position, Color("8fd0ff"), 4)
			return
	# 「护甲」：受到的伤害降三成
	if has_affix(EnemyAffixes.ARMORED):
		amount *= 0.7
		if level is RoomLevel and _flash<=0:HostileAttackFX.pulse(_fx(),global_position,"affix","armor",46,.25,0,level)
	# 「百分比承受」：受伤改成"按自己最大生命的百分比"结算 —— 玩家输出再爆炸也得打够次数
	if has_affix(EnemyAffixes.PERCENT_TAKEN):
		amount = maxf(amount, max_hp * 0.055)
	var damage_type:=_classify_damage(_source)
	var before_hp:=hp
	if affix_shield>0:
		var absorbed:=minf(affix_shield,amount)
		affix_shield-=absorbed
		amount-=absorbed
	hp -= amount
	_last_damage_source=_source
	_last_damage_type=damage_type
	var applied:=minf(before_hp,maxf(0,amount))
	if applied>0:
		RunBuildMetrics.hit(self,applied,_source,damage_type,fate_factor)
		damage_applied.emit(self,applied,_source,damage_type)
		_notify_equipment("on_enemy_damaged",[self,applied,_source,damage_type])
	_flash = HURT_FLASH
	if _pixel_enemy_art and visual is AnimatedSprite2D:
		var sprite := visual as AnimatedSprite2D
		sprite.play(&"hurt")
		sprite.set_frame_and_progress(0, 0.0)
		sprite.speed_scale = 1.0
	Effects.damage_number(
		_fx(),
		global_position + Vector2(0.0, -26.0),
		amount,
		is_crit,
		Palette.UI_ACCENT if is_crit else Palette.UI_TEXT
	)
	Effects.hit_spark(_fx(), global_position, body_color, 6)
	queue_redraw()          # 头顶血条要跟着掉

	if knockback:
		var push := global_position - from
		if push.length() < 0.001:
			push = Vector2(0.0, -1.0)
		velocity += push.normalized() * 200.0

	if hp <= 0.0 and not training_target:
		if loot_origin!="boss_construct":PassiveRuntime.report_kill(self,_source)
		_die()

func _classify_damage(source:Node)->StringName:
	if source is DamageContext:return &"skill" if (source as DamageContext).owner_kind==&"skill_field" else (source as DamageContext).owner_kind
	if source is Projectile:
		if (source as Projectile).is_basic_attack:return &"basic"
		return &"skill" if DamageContext.player_owned(source) else &"projectile"
	if source is Player:return &"skill"
	if source is RoomAlly:return &"ally"
	return &"environment"

func _notify_equipment(method:String,args:Array)->void:
	var hero:=GameState.player
	if not is_instance_valid(hero):return
	var equipment=hero.get("equipment_mechanics")
	if is_instance_valid(equipment) and equipment.has_method(method):equipment.callv(method,args)


func _is_basic_attack(source: Node) -> bool:
	## 玩家的"普通攻击" = 那枚火球（图集火球）；装备/技能的弹丸不带这个标记
	var bullet := source as Projectile
	return bullet != null and bullet.is_basic_attack


func _die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self,_last_damage_source,_last_damage_type)
	AchievementTracker.enemy_defeated(self)
	_notify_equipment("on_enemy_died",[self,_last_damage_source,_last_damage_type])
	var where := global_position
	if director != null and director.has_method("reward_enemy"): director.reward_enemy(self)
	Effects.death_burst(_fx(), where, body_color, 14)
	# 「死亡爆炸」词条：倒下时炸开一圈，靠近的玩家要挨伤害
	if has_affix(EnemyAffixes.DEATH_BOMB):
		Effects.slash_arc(_fx(), where, 0.0, 62.0, EnemyAffixes.danger_color(danger), 360.0, 8.0, 0.28)
		Effects.hit_spark(_fx(), where, Color("ff9a3d"), 14)
		EventBus.request_screen_shake.emit(5.0)
		if player != null and is_instance_valid(player) and player.has_method("take_damage"):
			if player.global_position.distance_to(where) < 96.0:
				player.take_damage(attack_damage() * 0.8, where, self)
	# 「分裂」词条：倒下时裂成两只小怪（小怪不再带分裂，避免无限裂）
	if has_affix(EnemyAffixes.SPLIT):
		_spawn_split_children()
	# 后继先登记，再判断清场，避免最后一只分裂怪提前发奖励。
	EventBus.enemy_died.emit(kind, where, coin_value)
	if _pixel_enemy_art and visual is AnimatedSprite2D:
		PixelEnemyArt.spawn_remains(visual as AnimatedSprite2D,_fx())
	queue_free()


func _spawn_split_children() -> void:
	if is_instance_valid(director) and director.has_method("queue_split_children"):
		director.queue_split_children(self)
		return
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var child_affixes: Array[StringName] = []
	for id in affixes:
		if id != EnemyAffixes.SPLIT:
			child_affixes.append(id)
	for i in 2:
		var child := WaveDirector.create_enemy(kind)
		if child == null:
			continue
		child.setup(player, level, _hp_scale * 0.55, _damage_scale * 0.8, _speed_scale)
		child.set_attack_scale(_attack_scale)
		child.fx_root = fx_root
		child.director = director
		var point:=global_position+Vector2(-18+float(i)*36,-14)
		if level!=null and not _room_position_clear(point,child.body_size):
			child.free()
			continue
		child.position=parent.to_local(point)
		parent.add_child(child)
		if not child_affixes.is_empty():
			child.apply_affixes(child_affixes)
		Effects.hit_spark(_fx(), child.global_position, body_color, 8)
		EventBus.enemy_spawned.emit(child)


func _fx() -> Node:
	## 特效统一挂到 fx_root，别污染敌人容器（否则统计和清场都会受影响）
	if fx_root != null and is_instance_valid(fx_root):
		return fx_root
	return get_parent()


func _despawn() -> void:
	## 掉出地图：算作消失，但不掉金币，也要通知波次系统避免卡住
	if _dead:
		return
	_dead = true
	EventBus.enemy_died.emit(kind, global_position, 0)
	queue_free()


func _build_contact_area() -> void:
	contact_area = Area2D.new()
	contact_area.name = "ContactArea"
	contact_area.collision_layer = Layers.ENEMY_ATTACK
	contact_area.collision_mask = Layers.PLAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	contact_area.add_child(shape)
	add_child(contact_area)


func _build_body_collider() -> void:
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	shape_node.shape = rect
	add_child(shape_node)


func _build_visual() -> void:
	## 有素材就用精灵动画；没有就退回子类用代码画的形状
	if PixelEnemyArt.supports(kind):
		var sprite:=AnimatedSprite2D.new()
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.sprite_frames=PixelEnemyArt.make_frames(kind)
		PixelEnemyArt.align(sprite,kind,body_size)
		add_child(sprite)
		sprite.play(&"idle")
		if kind==&"moss_badger":sprite.frame_changed.connect(func()->void:PixelEnemyArt.align(sprite,kind,body_size))
		visual=sprite
		_pixel_enemy_art=true
		return
	var strip := "res://assets/characters/monster_%s.png" % sprite_name
	if not sprite_name.is_empty() and ResourceLoader.exists(strip):
		var anim := AnimatedSprite2D.new()
		anim.name = "Visual"
		anim.sprite_frames = CharacterSprites.make_monster_frames(sprite_name)
		anim.centered = true
		add_child(anim)
		anim.play(&"idle")
		visual = anim
		return
	_build_polygon_placeholder()


func _build_polygon_placeholder() -> void:
	## 子类覆写，构建代码画的占位外形
	pass


func reset_path() -> void:
	## 被外部挪动过位置（比如波次调度把够不到玩家的怪物重新投放）时调用，
	## 让它下一帧立刻重新算路，而不是沿着旧路径继续走。
	_path.clear()
	_path_index = 0
	_path_timer = 0.0


func move_target()->Vector2:
	return aggro_position()

func apply_slow(strength: float, duration: float) -> void:
	if _dead:
		return
	if str(kind).contains("boss"):
		strength *= 0.5
	strength=clampf(strength,0,0.8)
	if strength<=0 or duration<=0:return
	var merged:=false
	for effect in _slow_effects:
		if absf(float(effect.strength)-strength)<0.001:
			effect.remaining=maxf(float(effect.remaining),duration)
			merged=true;break
	if not merged:_slow_effects.append({"strength":strength,"remaining":duration})
	_slow_time=maxf(_slow_time,duration)
	_slow_strength=maxf(_slow_strength,strength)

func advance_slow(dt:float)->void:
	if _slow_effects.is_empty() and _slow_time>0 and _slow_strength>0:
		_slow_effects.append({"strength":_slow_strength,"remaining":_slow_time})
	_slow_time=0;_slow_strength=0
	for i in range(_slow_effects.size()-1,-1,-1):
		var effect:Dictionary=_slow_effects[i]
		effect.remaining=float(effect.remaining)-dt
		if float(effect.remaining)<=0:_slow_effects.remove_at(i);continue
		_slow_time=maxf(_slow_time,float(effect.remaining))
		_slow_strength=maxf(_slow_strength,float(effect.strength))

func apply_burn(dps: float, duration: float, source: Node) -> void:
	if _dead or dps <= 0:
		return
	if _burn_time <= 0:
		_burn_dps = 0
		_burn_tick = 0
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, duration)
	_burn_source = weakref(DamageContext.stable_source(source)) if is_instance_valid(source) else null

func _room_position_clear(at:Vector2,size:Vector2)->bool:
	return (level as RoomLevel).body_clear(at,maxf(size.x,size.y)*.5,kind==&"flyer") if level is RoomLevel else true
