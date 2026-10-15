class_name Projectile
extends CharacterBody2D
## 飞行物：玩家和敌人共用。
##   is_friendly = false  打玩家（敌人发射的）
##   is_friendly = true   打敌人（玩家发射的火球）
##
## 移动方式和角色一样：走物理引擎（move_and_collide 是「扫掠」检测，
## 一帧走多远都不会穿过薄墙）。撞墙用的是瓦片真正的碰撞体，
## 和人物踩的地面是同一份数据，不再靠代码里另存一份格子表来判断。

const LIFETIME := 4.0
## 最远飞行距离。改成「从出膛点算飞了多远」而不是「有没有飞出关卡矩形」：
## 关卡矩形取决于地图画了多大，小地图上会在屏幕中间就把火球判死，
## 看起来就像火球凭空消失。用距离就不会受地图大小影响。
const MAX_RANGE := 1500.0
const HIT_RADIUS := 18.0
## 物理碰撞圆半径 = 命中半径 × 这个系数。
## 数值比贴图小一点是故意的：贴图是长条形的，圆取小一点手感更准。
const COLLIDER_RATIO := 0.7
const FIREBALL_ART := "res://assets/pixel_batch3/fire_vfx_v1.png"
const FIREBALL_FRAME := Vector2i(32, 16)
const FIREBALL_FRAMES := 4
const FIREBALL_FPS := 15.0
const ENEMY_BOLT_COLOR := Color("ff6576")

var speed := 320.0
var damage := 10.0
var direction := Vector2.RIGHT
var level: Level
var player: Node2D
var color := Color("ff8a3d")
var is_friendly := false
var use_fireball_art := false
var weapon_fx:=""
var _weapon_frames:Array[Texture2D]=[]
## 贴图放大倍数（像素画用 0.5 的整数倍最清晰）。玩家火球会调大，敌人弹丸保持 1。
var art_scale := 1.0
## 拖尾：飞行时留下小亮点（枪械细弹 / 法球都用，粗细由 trail_size 控制）
var trail := false
var trail_color := Color.WHITE
var trail_size := 3.0
var _trail_timer := 0.0
var _legendary_trail_clock:=0.0
## 命中半径。默认 HIT_RADIUS，贴图放大后会跟着变大，
## 免得出现「看起来明明擦到怪了却不掉血」。
var hit_radius := HIT_RADIUS
## 爆炸（天赋「爆裂余烬」给火球加的）：> 0 时命中后炸开，波及周围敌人。
var burn_dps := 0.0
var is_basic_attack := false
var attack_receipt: BasicAttackReceipt
var explosion_radius := 0.0
## 追踪：每秒最多偏转多少弧度（0 = 直线飞行）。
## 实现方式是每帧把 direction 朝目标转一点点，所以「拐弯」是指数式的，
## 越接近目标越贴合，不会出现瞬间甩头。
var homing_turn := 0.0
## 追踪的搜索半径：只在附近找目标，免得全图乱拐
var homing_range := 620.0
## 穿透：还能再穿过几个敌人（0 = 撞到第一个就炸）
var pierce := 0
## 穿墙：直接不跟地形碰撞，越过实心块继续追
var ghost := false
## 已经打过的敌人（穿透时避免对同一只反复结算）
var _hit_ids := {}
## 爆炸伤害 = 直击伤害 × 这个比例
var explosion_ratio := 0.0

var _life := LIFETIME
var _spin := 0.0
var _visual: Node2D
var _orb_outer: Polygon2D
var _orb_inner: Polygon2D
var _orb_particles: CPUParticles2D
var _sprite: Sprite2D
var _frame := 0
var _frame_timer := 0.0
var _start := Vector2.ZERO
var _collider: CollisionShape2D


func setup(
	from: Vector2,
	dir: Vector2,
	dmg: float,
	spd: float,
	level_node: Level,
	player_node: Node2D,
	tint: Color
) -> void:
	global_position = from
	_start = global_position
	direction = dir.normalized()
	damage = dmg
	speed = spd
	level = level_node
	player = player_node
	# Enemy bolts have their own warning color; ally spell tints stay untouched.
	color = tint if is_friendly else ENEMY_BOLT_COLOR
	rotation = direction.angle()
	_update_orb_color()
	# art_scale 可能在 add_child 之后才设，这里再刷一次，保证贴图和命中半径都跟上
	_apply_art_scale()
	_apply_physics_profile()
	if is_friendly and is_basic_attack and weapon_fx in WeaponBuildFX.LEGENDARY:
		if attack_receipt==null or not attack_receipt.has_meta("weapon_cast_shown"):
			if attack_receipt!=null:attack_receipt.set_meta("weapon_cast_shown",true)
			WeaponBuildFX.pulse(get_parent(),global_position,weapon_fx,"cast",42,direction.angle())


func _apply_physics_profile() -> void:
	## 子弹不占物理层（collision_layer = 0）：任何单位都不会被子弹推开或挡住。
	## 但它会主动去撞：实心地形 + 对面阵营。
	## 单向平台不挡弹幕 —— 否则站在平台后面就没法对射，手感很差（上下左右随便打）。
	collision_layer = 0
	# 穿墙的火球完全不和地形碰：mask 里不放 WORLD，move_and_collide 就会一路飞过去。
	# 命中敌人改由 _physics_process 里的邻近判定负责。
	var mask := 0 if ghost else Layers.WORLD
	mask |= (Layers.ENEMY|Layers.BOSS_OBJECT) if is_friendly else Layers.PLAYER
	collision_mask = mask
	velocity = direction * speed


func _build_collider() -> void:
	## 圆形碰撞体：旋转贴图时不会跟着转，判定稳定。
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = hit_radius * COLLIDER_RATIO
	shape_node.shape = circle
	add_child(shape_node)
	_collider = shape_node


func _ready() -> void:
	z_index = 6
	# 飞行物不踩重力、不贴地，用「漂浮」模式：撞墙就停，不会被地形吸附
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_build_collider()
	_apply_physics_profile()
	if not weapon_fx.is_empty():
		_build_weapon_effect()
	elif use_fireball_art and ResourceLoader.exists(FIREBALL_ART):
		_build_fireball()
	else:
		_build_orb()
	# 夜晚照明：玩家的弹幕自带一盏小灯（只照明、不投影 —— 一次几十发，
	# 每发都算阴影贴图会明显掉帧）。真正投影的是蘑菇和月亮。
	if is_friendly:
		# 范围收得比较小：弹幕是"移动的小光源"，
		# 一片片大光晕会把夜色的黑吃掉。
		add_child(LightUtil.make_point_light(color, 1.15, 130.0, false))
	else:
		# 敌人的弹幕也给一点微光（偏红）：夜色很浓时，远方射过来的子弹
		# 至少能看见一条红光，不至于"凭空挨打"。
		add_child(LightUtil.make_point_light(Color(1.0, 0.42, 0.34), 0.65, 95.0, false))


func _build_weapon_effect()->void:
	_weapon_frames=WeaponBuildFX.frames(weapon_fx,"flight") if weapon_fx in WeaponBuildFX.LEGENDARY else WeaponArt.frames(weapon_fx+"_flight")
	if _weapon_frames.is_empty():_build_fireball();return
	_sprite=Sprite2D.new();_sprite.texture=_weapon_frames[0];_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite);_frame_timer=1.0/12.0;_apply_art_scale()


func _build_fireball() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelSpellArt.frames("fire")[12]
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.material = PixelSpellArt.material()
	_sprite.centered = true
	add_child(_sprite)
	_frame_timer = 1.0 / (12.0 if not _weapon_frames.is_empty() else FIREBALL_FPS)
	_apply_art_scale()



func _apply_art_scale() -> void:
	if _sprite != null:
		_sprite.scale = Vector2.ONE * art_scale * 32.0 / _sprite.texture.get_width()
	if _visual != null:
		_visual.scale = Vector2.ONE * art_scale
	if art_scale > 1.0:
		hit_radius = maxf(HIT_RADIUS, 9.0 * art_scale)
	if _collider != null and _collider.shape is CircleShape2D:
		(_collider.shape as CircleShape2D).radius = hit_radius * COLLIDER_RATIO


func _build_orb() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	_orb_outer = Shapes.circle(6.0, color, Vector2.ZERO, 10)
	_orb_inner = Shapes.circle(3.0, color.lightened(0.5), Vector2.ZERO, 8)
	_visual.add_child(_orb_outer)
	_visual.add_child(_orb_inner)
	_orb_particles = CPUParticles2D.new()
	_orb_particles.emitting = true
	_orb_particles.amount = 12
	_orb_particles.lifetime = 0.25
	_orb_particles.local_coords = false
	_orb_particles.direction = -direction
	_orb_particles.spread = 20.0
	_orb_particles.initial_velocity_min = 10.0
	_orb_particles.initial_velocity_max = 40.0
	_orb_particles.scale_amount_min = 1.5
	_orb_particles.scale_amount_max = 3.0
	add_child(_orb_particles)
	_update_orb_color()
	_apply_art_scale()


func _update_orb_color() -> void:
	if _orb_outer != null: _orb_outer.color = color
	if _orb_inner != null: _orb_inner.color = color.lightened(0.5)
	if _orb_particles != null: _orb_particles.color = Color(color.r, color.g, color.b, 0.55)


func _physics_process(delta: float) -> void:
	_legendary_trail_clock-=delta
	if weapon_fx in WeaponBuildFX.LEGENDARY and _legendary_trail_clock<=0:
		_legendary_trail_clock=.09
		WeaponBuildFX.trail(get_parent(),global_position,weapon_fx,direction.angle())
	_life -= delta
	_spin += delta * 9.0
	# 火球图集逐帧播（循环，因为素材本身是 loop 的）
	if _sprite != null:
		_frame_timer -= delta
		if _frame_timer <= 0.0:
			_frame_timer = 1.0 / (12.0 if not _weapon_frames.is_empty() else FIREBALL_FPS)
			_frame = (_frame + 1) % FIREBALL_FRAMES
			_sprite.texture = _weapon_frames[_frame] if not _weapon_frames.is_empty() else PixelSpellArt.frames("fire")[12 + _frame]
	if _visual != null:
		_visual.scale = Vector2.ONE * art_scale * (1.0 + sin(_spin) * 0.15)
	# 拖尾：每隔一小会儿丢一颗不带重力的亮点
	if trail:
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = 0.035
			Effects.trail_dot(get_parent(), global_position, trail_color, trail_size)

	# 移动交给物理引擎：move_and_collide 会沿这一帧的运动线段做扫掠检测，
	# 所以再快也不会穿过薄墙，而且撞点、撞到的是谁都是引擎给的准确结果。
	# 追踪：先朝目标转一点方向，再按新方向移动
	if homing_turn > 0.0 and is_friendly:
		var target := _nearest_enemy()
		if target != null:
			var want := (target.global_position - global_position).normalized()
			var max_step := homing_turn * delta
			direction = direction.rotated(clampf(direction.angle_to(want), -max_step, max_step))
			rotation = direction.angle()
	velocity = direction * speed
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		global_position = collision.get_position()
		if _on_body_hit(collision.get_collider()):
			return

	# 兜底：如果出膛那一刻就已经和目标重叠（贴着怪开火），
	# 物理扫掠不会把「一开始就重叠」算成碰撞，所以这里补一次邻近判定。
	if is_friendly:
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as EnemyBase
			if enemy == null or not is_instance_valid(enemy):
				continue
			if global_position.distance_to(enemy.global_position) < hit_radius:
				if _hit_enemy(enemy):
					return
	else:
		if player != null and is_instance_valid(player):
			if global_position.distance_to(player.global_position) < hit_radius:
				if player.has_method("take_damage"):
					player.take_damage(damage, global_position, self)
				_hit_effect(true)
				return

	if _life <= 0.0 or global_position.distance_to(_start) > MAX_RANGE:
		_fizzle()


func _on_body_hit(collider: Object) -> bool:
	## move_and_collide 撞到东西时统一走这里：按「撞到谁」决定是打伤害还是撞墙。
	## 返回 true = 这个火球该消失了。
	if is_friendly and collider is EnemyBase:
		return _hit_enemy(collider as EnemyBase)
	if not is_friendly and collider is Player:
		(collider as Player).take_damage(damage, global_position, self)
		_hit_effect(true)
		return true
	# 其余都是地形（实心瓦片 / 单向平台）
	if ghost:
		return false          # 穿墙天赋：撞到地形也照飞
	_hit_effect(false)
	return true


func _hit_enemy(enemy: EnemyBase) -> bool:
	## 结算一次对敌人的命中。返回 true = 火球消失，false = 还能继续飞（穿透）。
	var id := enemy.get_instance_id()
	if _hit_ids.has(id):
		return false          # 这只是穿透路上已经打过的，别重复扣血
	_hit_ids[id] = true
	var hp_before:=enemy.hp
	enemy.take_damage(damage, false, global_position, self)
	# 吸血按一次有效普攻直击结算；技能、溅射和穿透的重复碰撞不会重复触发。
	if is_friendly and is_basic_attack and is_instance_valid(enemy) and enemy.hp<hp_before and is_instance_valid(GameState.player):
		if attack_receipt != null: GameState.player.heal_player(attack_receipt.claim())
	if is_friendly and burn_dps > 0 and is_instance_valid(enemy):
		enemy.apply_burn(burn_dps, 3.0, GameState.player)
	if pierce > 0:
		pierce -= 1
		add_collision_exception_with(enemy)
		# 穿透时不播命中爆点（否则一串连爆看不清），只留一点火星
		Effects.hit_spark(get_parent(), global_position, color, 5)
		return false
	_hit_effect(true)
	return true


func _nearest_enemy() -> EnemyBase:
	var best: EnemyBase = null
	var best_d := homing_range * homing_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyBase
		if enemy == null or not is_instance_valid(enemy) or enemy._dead or _hit_ids.has(enemy.get_instance_id()):
			continue
		var d := enemy.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _fizzle() -> void:
	## 寿命到 / 飞出关卡范围：撒一小撮火星再消失，别让火球硬生生凭空不见。
	## 之前这里直接 queue_free()，玩家看到的就是「火球在半空中莫名其妙没了」。
	Effects.hit_spark(get_parent(), global_position, color, 7)
	queue_free()


func _hit_effect(hit_target: bool) -> void:
	var parent := get_parent()
	if is_friendly:
		if weapon_fx in WeaponBuildFX.LEGENDARY:
			WeaponBuildFX.impact(parent,global_position,weapon_fx,56+explosion_radius*0.5,direction.angle() if weapon_fx=="staff_wind_branch" else 0.0)
		elif not weapon_fx.is_empty():
			WeaponPulse.spawn(parent,global_position,weapon_fx+"_flight",42,direction.angle(),96)
		else:PaintedSpellFX.spawn(parent, global_position, "res://assets/fx/painted/fx_fire_burst.png", 52 + explosion_radius * 0.65, 0.36)
		if explosion_radius > 0:
			_explode()
	else:
		Effects.hit_spark(parent, global_position, color, 6 if hit_target else 3)
	queue_free()



func _explode() -> void:
	## 范围伤害：不打刚命中的那只（它已经吃过直击伤害了），避免双倍结算
	var splash := damage * explosion_ratio
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyBase
		if enemy == null or not is_instance_valid(enemy):
			continue
		if _hit_ids.has(enemy.get_instance_id()):
			continue
		if global_position.distance_to(enemy.global_position) <= explosion_radius:
			enemy.take_damage(splash, false, global_position, self)
