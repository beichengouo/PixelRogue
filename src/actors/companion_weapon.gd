class_name CompanionWeapon
extends Node2D
## 悬浮武器：装备后飘在角色头顶，自动朝最近的敌人开火（「辅助攻击」）。
##
## 设计要点：
##   · 玩家自己的火球攻击照旧，武器是额外的一份输出 —— 所以叫「辅助」。
##   · 索敌用「最近的敌人」，超出 reach 就不打，避免隔半张地图点名。
##   · 贴图只做左右翻转 + 上下小角度倾斜，不做整圈旋转 ——
##     俯视视角的枪整圈转会变成倒着的枪，很难看。
##
## 三类武器的手感 / 特效完全分开：
##   枪械类（弓·枪）：后坐力 + 枪口闪光 + 高速细弹（带拖尾）
##   法杖类（法杖·魔杖）：施法光环 + 大颗慢速法球（带拖尾，伤害更高）
##   近战类（匕首·战锤）：不发射弹丸 —— 武器图标**朝目标戳出去再收回来**（像回旋镖），
##                        戳出去的瞬间按"细长判定"打伤害；范围小、但单下伤害更高；
##                        重武器（战锤）额外震屏 + 扬尘，出招更慢更重

const HOVER_HEIGHT := 66.0     # 悬浮高度（相对玩家原点，玩家脚下是 +21）
const HOVER_BACK := 6.0        # 稍微靠后一点，别挡住角色的头
const BOB_AMPLITUDE := 3.5     # 上下浮动幅度
const BOB_SPEED := 2.4
## 近战判定：身体中心（比脚下高一点）；判定形状是"戳出去的那条线段"
const MELEE_ORIGIN := Vector2(0.0, -22.0)
## 敌人也用它的身体中心参与判定（用脚下原点会出现"贴脸打不到"）
const ENEMY_CENTER := Vector2(0.0, -14.0)
## 戳出去 / 收回来各用多久（秒）
const POKE_OUT := 0.13
const POKE_BACK := 0.22
## 判定粗细：到"戳出去那条线"的距离小于它就命中
const POKE_HIT_RADIUS := 32.0

enum Family { GUN, STAFF, MELEE }

var player: Player
var level: Level
var data: Dictionary = {}      # ItemDB 里的 weapon 字段
var item_id: StringName = &""  # 装备的是哪一件（用于判断要不要重建）

var _sprite: Sprite2D
var _cooldown := 0.0
var _bob := 0.0
var _aim := Vector2.RIGHT
var _recoil := 0.0
var _poke_t := -1.0            # >= 0 表示正在戳出去/收回来
var _poke_dir := Vector2.RIGHT
var _poke_dist := 80.0


func setup(player_node: Player, level_node: Level, item: Dictionary) -> void:
	## 必须在 add_child 之前调用
	player = player_node
	level = level_node
	data = item.get("weapon", {})
	item_id = item.get("id", &"")
	_cooldown = float(data.get("cd", 1.0))


func _ready() -> void:
	z_index = 5
	_build_visual()


func _build_visual() -> void:
	var path := str(data.get("sprite", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	_sprite = Sprite2D.new()
	_sprite.texture = load(path)
	_sprite.centered = true
	# 图标素材是 64px，比角色头还大；缩到 0.75（48px）和悬浮武器的体量匹配
	_sprite.scale = Vector2.ONE * 0.75
	add_child(_sprite)
	# 出生时先冒一圈火星，让玩家注意到「武器装上来了」
	Effects.hit_spark(get_parent(), global_position, data.get("color", Color.WHITE), 8)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.extraction_pose != &"": return
	_bob += delta * BOB_SPEED
	# 跟着头顶飘（挂在玩家下面，位置是相对坐标）
	var facing := float(player.facing)
	position = Vector2(
		roundf(-HOVER_BACK * facing),
		roundf(-HOVER_HEIGHT + sin(_bob) * BOB_AMPLITUDE)
	)

	_recoil = maxf(0.0, _recoil - delta * 42.0)
	if _poke_t >= 0.0:
		_poke_t += delta
		if _poke_t >= POKE_OUT + POKE_BACK:
			_poke_t = -1.0            # 收回来了，回到悬停状态

	var target := _find_target()
	if _poke_t >= 0.0:
		_aim = _poke_dir                # 戳出去的途中不改瞄向，否则会甩来甩去
	elif target != null:
		_aim = (target.global_position + ENEMY_CENTER - global_position).normalized()
	elif absf(player.aim_direction.x) > 0.15 or absf(player.aim_direction.y) > 0.15:
		# 没敌人时跟着玩家的瞄准方向转，看起来「在待命」
		_aim = player.aim_direction
	# 近战武器在够不着的目标身上没法挥砍 —— 按武器自己的射程重新判定
	if _family() == Family.MELEE and target != null:
		if global_position.distance_to(target.global_position + ENEMY_CENTER) > _melee_reach() * 2.2:
			target = null
	_update_sprite()

	_cooldown -= delta
	if target == null or _cooldown > 0.0:
		return
	_fire()
	_cooldown = float(data.get("cd", 1.0))


func _find_target() -> Node2D:
	var reach := float(data.get("reach", 500.0))
	var best: Node2D = null
	var best_dist := reach * reach
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var d := enemy.global_position.distance_squared_to(global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func _update_sprite() -> void:
	if _sprite == null:
		return
	var flip := _aim.x < 0.0
	_sprite.flip_h = flip
	var extra := Vector2.ZERO
	if _poke_t >= 0.0:
		# 戳出去 → 收回来（回旋镖式）
		if _poke_t < POKE_OUT:
			var k := _poke_t / POKE_OUT
			extra = _poke_dir * _poke_dist * (1.0 - pow(1.0 - k, 3.0))   # 出得快
		else:
			var k := (_poke_t - POKE_OUT) / POKE_BACK
			extra = _poke_dir * _poke_dist * (1.0 - k * k)               # 收得稳
		_sprite.rotation = 0.0 if _poke_dir.x >= 0.0 else 0.0
	else:
		# 翻转之后倾角要取反，否则「朝上瞄」会变成「朝下瞄」
		var tilt := asin(clampf(_aim.y, -1.0, 1.0))
		_sprite.rotation = tilt * (-1.0 if flip else 1.0)
	# 枪械开火后坐：贴图整体往回缩一下；近战则叠加上"戳出去"的位移
	_sprite.position = -_aim * _recoil + extra


## ---------------- 武器分类 ----------------

func _family() -> Family:
	var tag := str(data.get("family", "")).to_lower()
	if tag == "":
		# 没写 family 就按 id / 贴图名猜，方便以后直接加武器
		tag = (str(item_id) + " " + str(data.get("sprite", ""))).to_lower()
	if tag.contains("gun") or tag.contains("pistol") or tag.contains("rifle") \
			or tag.contains("bow") or tag.contains("arrow"):
		return Family.GUN
	if tag.contains("staff") or tag.contains("wand") or tag.contains("orb"):
		return Family.STAFF
	return Family.MELEE


func _melee_reach() -> float:
	return float(data.get("reach", 110.0))


func _is_heavy() -> bool:
	## 战锤这种又慢又重的，挥砍更慢、范围更大、还带震屏
	return bool(data.get("heavy", float(data.get("cd", 1.0)) >= 0.9))


## ---------------- 开火 ----------------

func _fire() -> void:
	match _family():
		Family.MELEE:
			_swing_melee()
		Family.STAFF:
			_cast_staff()
		_:
			_shoot_gun()


func _roll_damage(scale: float) -> float:
	var roll := Combat.roll_attack(player.stats, Rng.stream())
	return float(roll["damage"]) * scale


func _shoot_gun() -> void:
	## 枪械类：后坐力 + 枪口闪光 + 高速细弹
	## 子弹必须挂到玩家所在的容器（actors_root），不能挂在玩家自己身上：
	## 挂在玩家下面的话，子弹的坐标会跟着玩家一起平移，看起来就是「子弹黏在身上」。
	var parent := player.get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var shots := maxi(1, int(data.get("shots", 1)))
	var spread := float(data.get("spread", 0.0))
	var speed := float(data.get("speed", 430.0))
	var color: Color = data.get("color", Color("9ad8ff"))
	var damage_scale := float(data.get("dmg", 0.7))

	_recoil = 4.0 + float(shots) * 1.4
	Effects.muzzle_flash(parent, global_position + _aim * 18.0, _aim,
		Color(1.0, 0.93, 0.62), 30.0)
	AudioManager.play(&"enemy_shoot", -11.0, 0.08)

	for i in shots:
		# 多发时以中心为轴左右摊开，并加一点随机抖动，手感更活
		var offset := 0.0
		if shots > 1:
			offset = (float(i) - float(shots - 1) * 0.5) * spread
		offset += Rng.next_float() * spread * 0.12
		var dir := _aim.rotated(offset)

		var ball := Projectile.new()
		ball.is_friendly = true
		ball.art_scale = 0.85
		ball.trail = true
		ball.trail_color = color
		parent.add_child(ball)
		ball.setup(
			global_position + dir * 16.0,
			dir,
			_roll_damage(damage_scale),
			speed,
			level,
			null,
			color
		)


func _cast_staff() -> void:
	## 法杖类：脚下先亮一圈法阵，再慢慢推出一颗大法球
	var parent := player.get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var shots := maxi(1, int(data.get("shots", 1)))
	var spread := float(data.get("spread", 0.0))
	var speed := float(data.get("speed", 300.0))
	var color: Color = data.get("color", Color("ff9a3d"))
	var damage_scale := float(data.get("dmg", 0.9))
	var muzzle := global_position + _aim * 20.0

	Effects.cast_ring(parent, muzzle, color, 18.0, 0.34)
	Effects.cast_ring(parent, player.global_position + Vector2(0.0, 18.0), color, 26.0, 0.42)
	AudioManager.play(&"enemy_shoot", -13.0, -0.30)

	for i in shots:
		var offset := 0.0
		if shots > 1:
			offset = (float(i) - float(shots - 1) * 0.5) * spread
		var dir := _aim.rotated(offset)
		var orb := Projectile.new()
		orb.is_friendly = true
		orb.art_scale = maxf(1.3, 1.15 + damage_scale * 0.5)
		orb.trail = true
		orb.trail_color = color
		orb.trail_size = 4.0
		parent.add_child(orb)
		orb.setup(
			muzzle,
			dir,
			_roll_damage(damage_scale),
			speed * 0.78,
			level,
			null,
			color
		)


func _swing_melee() -> void:
	## 近战类：武器图标朝目标**戳出去再收回来**（像回旋镖），
	## 判定用"戳出去那条线段" —— 范围小、贴身，但单下伤害比远程高。
	var parent := player.get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var heavy := _is_heavy()
	var reach := _melee_reach()
	var color: Color = data.get("color", Color("ffe2a8"))
	var damage_scale := float(data.get("dmg", 0.8))
	var origin := player.global_position + MELEE_ORIGIN

	_poke_dir = _aim
	_poke_dist = reach
	_poke_t = 0.0
	# 戳出去时留一道短亮痕，强调"甩出去"的方向感
	Effects.muzzle_flash(parent, global_position + _poke_dir * 14.0, _poke_dir, color, reach * 0.9)
	if heavy:
		Effects.dust(parent, player.global_position + Vector2(0.0, 18.0), Palette.TERRAIN_TOP, 10)
		EventBus.request_screen_shake.emit(6.0)
	AudioManager.play(&"swing", -8.0, -0.12 if heavy else 0.12)

	# 命中判定：敌人中心到"戳出去那条线"的距离够近就算命中
	var tip := origin + _poke_dir * reach
	var radius := POKE_HIT_RADIUS + (10.0 if heavy else 0.0)
	var hit_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var point := enemy.global_position + ENEMY_CENTER
		if _point_to_segment(point, origin, tip) > radius:
			continue
		if enemy is EnemyBase:
			(enemy as EnemyBase).take_damage(_roll_damage(damage_scale), false, enemy.global_position, self)
		Effects.hit_spark(parent, point, color, 6)
		hit_any = true
	if hit_any and not heavy:
		EventBus.request_screen_shake.emit(2.0)


func _point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	## 点到线段的距离（"戳出去"的细长判定就靠它）
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)



