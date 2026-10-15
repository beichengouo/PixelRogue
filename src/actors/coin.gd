class_name Coin
extends CharacterBody2D
## 掉落物：金币 / 钥匙。先小跳一下落地，玩家靠近时自动吸过来。
## 肉鸽里「捡东西」这件事最好完全不要消耗玩家注意力。
##
## 【为什么改成 CharacterBody2D】
## 以前这里是 Area2D，自己用格子坐标（floor(x / TILE)）算「脚下是不是实心块」。
## 但地图的 Tiles 图层被挪过位置（tile_origin 不是 0，见 level.gd tile_origin()），
## 那套换算和真实墙面整整错开了一截 —— 症状就是金币有时停在半空、
## 有时钻在实心块里吸不到。现在改成和玩家一模一样的做法：
## 真正的重力 + move_and_slide()，落点/碰撞全部交给物理引擎，不再自己算格子。

const MAGNET_RANGE := 260.0     # 吸取范围调大：金币不容易"看得见捡不到"
const PICKUP_RANGE := 26.0
const FRAME_TIME := 0.22
## 和玩家同一套重力数值，掉出来的东西看起来才像"同一个世界"里的
const UNSTICK_MAX_LIFT := 16
## 碰撞体用「小方块」而不是圆：Godot 的单向平台对非矩形形状判定不稳，
## 圆形的金币落在悬空平台上会陷进瓦片里，方块就没这个问题。
const BODY_HALF := 7.0

var value := 1
var reward_visual_scale := 1.0
## &"coin" = 金币，&"key" = 钥匙
var kind: StringName = &"coin"
var level: Level
var player: Node2D

var _frame_timer := 0.0
var _frame := 0
var _sprite: Sprite2D
var _collected := false
var _life := 30.0
var _stuck_timer := 0.0
var _spawned := false
var _key_frames: SpriteFrames
var _key_clock := 0.0
var flight_origin := Vector2.ZERO
var flight_duration := 0.0
var flight_left := 0.0
var landing_wait := 0.0

func launch_scatter(from: Vector2, landing: Vector2, duration := 0.48, pause := 0.32) -> void:
	global_position = landing
	flight_origin = from
	flight_duration = maxf(0.01, duration)
	flight_left = flight_duration
	landing_wait = maxf(0.0, pause)
	velocity = Vector2.ZERO
	_set_world_collision(false)
	_scatter_visual()

func _advance_scatter(delta: float) -> bool:
	if flight_left > 0.0:
		flight_left = maxf(0.0, flight_left - delta)
		_scatter_visual()
		return true
	if landing_wait > 0.0:
		landing_wait = maxf(0.0, landing_wait - delta)
		if _sprite != null: _sprite.position = Vector2.ZERO
		return true
	return false

func _scatter_visual() -> void:
	if _sprite == null: return
	var progress := 1.0 - flight_left / maxf(0.01, flight_duration)
	_sprite.position = (flight_origin - global_position) * (1.0 - progress) + Vector2.UP * sin(progress * PI) * 38.0


func setup(
	level_node: Level,
	player_node: Node2D,
	coin_value: int,
	direction: float = 0.0,
	drop_kind: StringName = &"coin"
) -> void:
	level = level_node
	player = player_node
	value = coin_value
	kind = drop_kind
	velocity = Vector2(direction * 70.0, 0)


func _ready() -> void:
	collision_layer = Layers.PICKUP
	# 只和地形碰：不带 PLAYER / ENEMY，金币就不会把角色或怪物顶开
	collision_mask = Layers.WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	floor_snap_length = 0.0
	_build_collider()
	_build_visual()


func _build_collider() -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(BODY_HALF * 2.0, BODY_HALF * 2.0)
	var shape := CollisionShape2D.new()
	shape.shape = rect
	add_child(shape)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _advance_scatter(delta):
		_animate(delta)
		return
	if not _spawned:
		# main.gd 是 add_child() 之后才设 global_position 的，
		# 所以拖到第一次物理帧再做"卡在墙里就顶出来"的自救
		_spawned = true
		_unstick_from_world()

	_animate(delta)

	var magnetized := _update_magnet(delta)
	if _collected:
		return

	# 和玩家一样的重力：被吸走时不用管，其余时候老老实实往下掉
	if not magnetized:
		velocity=velocity.move_toward(Vector2.ZERO,300*delta)

	move_and_slide()

	if not magnetized:
		if velocity.length()<10:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		# 万一被拖进墙里还是卡住了，每半秒试着顶出来一次
		_stuck_timer -= delta
		if _stuck_timer <= 0.0:
			_stuck_timer = 0.5
			_unstick_from_world()

	if level != null and global_position.y > level.kill_floor_y():
		queue_free()


func _update_magnet(delta: float) -> bool:
	## 返回 true = 这一帧正在被吸（此时不加地形重力，避免和磁力互相拉扯）
	if player == null or not is_instance_valid(player):
		_set_world_collision(true)
		return false
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	# 掉了一会儿还没被捡走的金币：无论多远都朝玩家飞
	var desperate := _life < 24.0 and dist < 900.0
	if dist < MAGNET_RANGE or desperate:
		# 吸过来的时候干脆不碰地形：绝对不会卡在墙后面看得见吃不到
		_set_world_collision(false)
		var pull := clampf(1.0 - dist / MAGNET_RANGE, 0.0, 1.0)
		var weight := maxf(pull, 0.4)
		var speed := 200.0 + 420.0 * weight
		velocity = velocity.lerp(to_player.normalized() * speed, 1.0 - exp(-7.0 * weight * delta))
		if dist < PICKUP_RANGE:
			_collect()
		return true
	_set_world_collision(true)
	return false


func _set_world_collision(on: bool) -> void:
	var want := (Layers.WORLD) if on else 0
	if collision_mask != want:
		collision_mask = want


func _animate(delta: float) -> void:
	# 金币独立四帧旋转；钥匙继续使用原24帧旋转图集。
	if kind == &"coin":
		_frame_timer -= delta
		if _frame_timer <= 0.0:
			_frame_timer = FRAME_TIME
			_frame = (_frame + 1) % 4
			if _sprite != null:
				_sprite.texture = CurrencyArt.frame(_frame)
	elif _sprite != null:
		_key_clock += delta
		if _key_frames != null:
			_sprite.texture = _key_frames.get_frame_texture(&"default",posmod(floori(_key_clock*12),24))
		_sprite.position = Vector2(0.0, roundf(sin(Time.get_ticks_msec() / 220.0) * 2.0))


func _unstick_from_world() -> void:
	## 万一还是卡进地形（怪物死在墙里、抛出来的位置就在墙里、
	## 或者停在单向平台的格子里），沿着这一列往上顶出实心块。
	## 这里直接读 level 的格子表：它已经带上了 Tiles 图层的偏移，
	## 不会再出现「金币停在半空 / 钻在墙里吸不到」。
	if level == null:
		return
	var cell := level.world_to_cell(global_position)
	var lift := 0
	while level.is_solid_cell(cell - Vector2i(0, lift)) and lift < UNSTICK_MAX_LIFT:
		lift += 1
	if lift <= 0:
		return
	var top := level.cell_center(cell.x, cell.y - lift)
	global_position.y = top.y + Level.TILE * 0.5 - BODY_HALF - 0.5
	velocity.y = 0.0


func _collect() -> void:
	if _collected or flight_left > 0.0 or landing_wait > 0.0:
		return
	_collected = true
	if kind == &"key":
		GameState.add_keys(value)
		AudioManager.play(&"coin", -4.0)
		Effects.text(get_parent(), global_position + Vector2(0.0, -14.0), "钥匙 +%d" % value, Palette.UI_ACCENT, 20)
	else:
		var earned:=GameState.add_reward_coins(value)
		AudioManager.play(&"coin", -6.0)
		if earned>0:Effects.text(get_parent(), global_position + Vector2(0.0, -14.0), "+%d" % earned, Palette.COIN, 20)
	queue_free()


func _build_visual() -> void:
	_sprite = Sprite2D.new()
	if kind == &"key":
		# 每帧独立 AtlasTexture，旋转时不会把整张图集挤进一个图标。
		_key_frames = load("res://assets/supplied_20261011/key/rotate.tres") as SpriteFrames
		_sprite.texture = _key_frames.get_frame_texture(&"default",0)
		_sprite.scale = Vector2.ONE * 0.7
	else:
		_sprite.texture = CurrencyArt.frame(0)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.scale = Vector2.ONE * (36.0/96.0) * reward_visual_scale
	add_child(_sprite)
