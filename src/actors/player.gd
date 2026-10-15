class_name Player
extends CharacterBody2D
signal extraction_interrupted
var extraction_pose: StringName = &""
var _extraction_model_hidden := false

func set_extraction_pose(pose: StringName, hide_model := false) -> void:
	extraction_pose = pose
	_extraction_model_hidden = hide_model
	if pose != &"":
		_swing_timer = 0
		_cast_timer = 0
		_dash_timer = 0
		if hitbox != null: hitbox.set_deferred("monitoring", false)
	if extraction_controls_locked(): velocity = Vector2.ZERO
	if is_instance_valid(_sprite): _sprite.visible = pose != &"prayer" and not hide_model
	if is_instance_valid(_companion): _companion.visible = pose == &""
	if is_instance_valid(_held_staff):_held_staff.visible=pose==&""

func extraction_controls_locked() -> bool:
	return extraction_pose in [&"receiving", &"settling"]
## 玩家角色：跑、跳、二段跳、冲刺、挥砍。
##
## 手感相关的数值都在文件顶部常量 + GameState.BASE_STATS 里，
## 想调「跳得高一点 / 挥刀快一点」，改常量即可。

const GROUND_ACCEL := 2700.0
const AIR_ACCEL := 1800.0
const FRICTION := 2925.0
const SWING_ACTIVE := 0.12       # 攻击判定持续时间
const SWING_RECOVER := 0.14      # 收招时间
const ATTACK_COOLDOWN := 0.34
const DASH_SPEED := 720.0
const DASH_TIME := 0.16
const INVULN_TIME := 0.75
const CONTACT_PUSH := 371.0

var facing := 1
## 攻击/弹幕方向。由方向键组合决定（8 方向），不再跟鼠标走：
## 只按左右 = 水平射击，左/右 + 上 = 45° 斜上，只按上 = 正上。
var aim_direction := Vector2.RIGHT
## 非零时直接覆盖瞄准方向。只给自动测试用（自动试玩没有真键盘输入）。
var aim_override := Vector2.ZERO
var hp := 100.0
var max_hp := 100.0
## Permanent loss belongs to this expedition, separate from equipment/level HP.
var bloodbath_hp_loss := 0.0
var cruel_hp_loss := 0.0

var stats: StatBlock
var level: Level
var visual: Node2D
var hitbox: Area2D

var _hitbox_shape: RectangleShape2D

var _swing_timer := 0.0
var _attack_cd := 0.0
var _dash_timer := 0.0
var _dash_cd := 0.0
var _dash_dir := 1.0
var _invuln := 0.0
var _flash := 0.0
var _squash := 0.0
var _hurt_timer := 0.0
var _cast_timer := 0.0
var _land_timer := 0.0
var _block_timer := 0.0
var _cast_pose: StringName = &"cast"
var _cast_duration := 0.28
var _feedback_pose: StringName = &"interact"
var _feedback_timer := 0.0
var _feedback_duration := 0.32
var _move_input_active := false
var shield_hp := 0.0
var _shield_time := 0.0
var _shield_thorns := 0.0
var _shield_visual: Sprite2D
var _shield_visual_age := 0.0
var _night_shelter_visual:NightShelterFX
var _swing_hits: Array = []
var _attack_receipt: BasicAttackReceipt
var _slows: Array[Dictionary] = []
var _debuffs: Dictionary = {}

func apply_slow(strength: float, duration: float) -> void:
	var amount := clampf(strength, 0.0, 0.9)
	for effect in _slows:
		if is_equal_approx(float(effect.strength), amount):
			effect.left = maxf(float(effect.left), duration)
			return
	_slows.append({"strength": amount, "left": maxf(0.0, duration)})

func movement_slow_multiplier() -> float:
	var strongest := 1.0-PlayerDebuffs.multiplier(self,&"move_speed")
	for effect in _slows: strongest = maxf(strongest, float(effect.strength))
	return 1.0 - strongest

## 视觉：AnimatedSprite2D 播放 Elf 精灵表；武器挂在「手部挂点」下面，有自己的动画
var _sprite: AnimatedSprite2D
var _animation_request := 0
var _animation_applied := -1
## 悬浮武器（装备栏里那把）。挂在玩家下面，跟着头顶走。
var _companion: CompanionWeapon = null
var equipment_aura:EquipmentAura
var summons:SummonController
var _held_staff:Sprite2D
## 默认攻击是火球（远程）。近战判定留着但暂时关闭，以后加近战武器再打开。
const MELEE_ENABLED := false
const FIREBALL_SPEED := 430.0
## 火球贴图放大倍数。素材一帧是 32x16，里面真正的火球只有 24x8，
## 一倍大在 1280x720 下几乎看不见，所以放大到 2.5 倍（约 60x20）。
## 像素画建议用 0.5 的整数倍，缩放后每个像素边还是整数，不会糊。
const FIREBALL_ART_SCALE := 2.5
## 技能特效（Wispstrike 法术包，tools/build_skill_fx.gd 生成）
const FX_CAST := "res://assets/fx/skill_cast.png"
const FX_IMPACT := "res://assets/fx/skill_impact.png"
const FX_FADE := "res://assets/fx/skill_fade.png"
## 这三个图集都是 256x256 一帧
const FX_FRAME := Vector2i(256, 256)
const FX_CAST_FRAMES := 13
const FX_IMPACT_FRAMES := 19
const FX_FADE_FRAMES := 13
## 火球用的是真实素材、不染色；这个颜色只用在「火球烧完熄灭」的小火星上。
const FIREBALL_TINT := Color("ff9a3d")
## 枪口定位：从角色中心往外探，每 4 像素一次，最多探到 26 像素。
const MUZZLE_STEP := 4.0
const MUZZLE_MAX := 26.0


func _ready() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	floor_snap_length = 0.0
	if stats == null:
		stats = GameState.stats
	_build_sprite()
	UltimateCutin.warm(Characters.current_id())
	_build_hitbox()
	max_hp = stats.get_value(&"max_hp")
	hp = max_hp
	GameState.player = self
	stats.status_owner = weakref(self)
	if Characters.current_id()==&"xixifu":
		summons=SummonController.new();summons.actor=self;add_child(summons)
	EventBus.player_stats_changed.connect(_on_stats_changed)
	EventBus.equipment_changed.connect(_sync_companion)
	_sync_companion()
	# 自带一圈微光：夜里能看清自己脚下，也让人物在暗处有"存在感"。
	# 不做投影（影子留给月亮和蘑菇），范围也压得比较小，免得整片地都被照亮。
	# 夜色压得很暗之后，这盏灯就是玩家的主要视野来源：
	# 范围给到 190（约 5 格），能量也提上来，保证周围一圈能看清。
	_player_light = LightUtil.make_point_light(Color(1.0, 0.86, 0.66), 1.3, 190.0, false)
	_player_light.position = Vector2(0.0, -18.0)
	add_child(_player_light)


var _player_light: PointLight2D


func _update_aim(move_axis: float) -> void:
	if aim_override != Vector2.ZERO:
		# 自动测试：直接给定方向
		aim_direction = aim_override.normalized()
		_update_facing(move_axis)
		return
	## 弹幕方向 = 方向键组合，8 方向（上 + 右一起按就是右上 45°）。
	## 完全不按方向键时回到「面向方向」，所以站在原地按住攻击就是平射。
	var vertical := Input.get_axis("aim_down", "aim_up")
	var horizontal := Input.get_axis("aim_left", "aim_right")
	# 方向键（↑↓←→）专门用来指定攻击方向；WASD 只管移动
	var aim := Vector2(horizontal, -vertical)
	if aim.length() > 0.15:
		aim_direction = aim.normalized()
	else:
		aim_direction = Vector2(float(facing), 0.0)
	_update_facing(move_axis)


func _update_facing(move_axis: float) -> void:
	## 朝向优先跟**攻击方向**：按住 ←/→ 时脸朝那边（这样可以一边后退一边朝后打）；
	## 没按攻击方向键时才跟着移动方向。
	if aim_override != Vector2.ZERO:
		facing = 1 if aim_override.x >= 0.0 else -1
		return
	var aim_x := Input.get_axis("aim_left", "aim_right")
	if absf(aim_x) > 0.15:
		facing = 1 if aim_x > 0.0 else -1
		return
	if absf(move_axis) > 0.15:
		facing = 1 if move_axis > 0.0 else -1


func _update_timers(delta: float) -> void:
	_swing_timer = maxf(0.0, _swing_timer - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_dash_timer = maxf(0.0, _dash_timer - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_flash = maxf(0.0, _flash - delta)
	_squash = maxf(0.0, _squash - delta * 4.5)
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_cast_timer = maxf(0.0, _cast_timer - delta)
	_land_timer = maxf(0.0, _land_timer - delta)
	_block_timer = maxf(0.0, _block_timer - delta)
	_feedback_timer = maxf(0.0, _feedback_timer - delta)
	_shield_time = maxf(0.0, _shield_time - delta)
	for i in range(_slows.size() - 1, -1, -1):
		_slows[i].left = maxf(0.0, float(_slows[i].left) - delta)
		if float(_slows[i].left) <= 0.0: _slows.remove_at(i)
	if _shield_time <= 0:
		shield_hp = 0
	PlayerDebuffs.advance(self,delta)
	queue_redraw()


func _try_dash() -> void:
	if not Input.is_action_just_pressed("dash"):
		return
	request_dash()


## 下面三个 request_* 是「动作接口」。
## 键盘、手柄、以后的手机虚拟按键、以及自动测试，全部调用同一组方法，
## 这样操作方式再多也只有一个真相来源。
func request_dash() -> void:
	if hp <= 0.0 or _dash_cd > 0.0:
		return
	_animation_request += 1
	_dash_timer = DASH_TIME
	_dash_cd = stats.get_value(&"dash_cooldown")
	_dash_dir = float(facing)
	_invuln = maxf(_invuln, DASH_TIME)
	velocity.y = 0.0
	AudioManager.play(&"dash", -5.0)
	Effects.dust(get_parent(), global_position, Palette.PLAYER_BODY, 6)


func request_attack() -> void:
	if hp <= 0.0 or _attack_cd > 0.0 or _dash_timer > 0.0:
		return
	_animation_request += 1
	_swing_timer = SWING_ACTIVE + SWING_RECOVER
	_attack_cd = ATTACK_COOLDOWN / maxf(0.25, stats.get_value(&"attack_speed"))
	_swing_hits.clear()
	_attack_receipt = BasicAttackReceipt.new(self)
	_update_hitbox_position()
	AudioManager.play(&"swing", -8.0, 0.18)
	if self is RoomPlayer:
		var roll:=Combat.roll_attack(stats,Rng.stream())
		_attack_receipt.critical=bool(roll.crit)
		var rp:=self as RoomPlayer
		if not is_instance_valid(rp.equipment_mechanics) or not rp.equipment_mechanics.fire_basic(aim_direction,roll,_attack_receipt):rp.fire(aim_direction,float(roll.damage),430,true,_attack_receipt)
		if is_instance_valid(rp.equipment_mechanics):rp.equipment_mechanics.on_basic_fired(aim_direction,_attack_receipt)


## ---------------- 技能（按等级解锁，消耗魔法值）----------------

const SKILL_ACTIONS := ["skill_1", "skill_2", "skill_3", "ultimate"]


func play_action_feedback(pose: StringName, duration := 0.32) -> void:
	# 表现层提示，绝不锁定移动或改变消耗与伤害结算。
	if hp <= 0.0 or not PixelHeroArt.ANIMATIONS.has(pose):
		return
	_feedback_pose = pose
	_feedback_duration = maxf(0.01, duration)
	_feedback_timer = _feedback_duration
	_update_animation()


func _try_potions() -> void:
	if hp <= 0.0:
		return
	for i in GameState.HOTBAR_SIZE:
		if Input.is_action_just_pressed("potion_%d" % (i + 1)):
			if not GameState.use_hotbar(i):
				Effects.text(get_parent(), global_position + Vector2(0.0, -56.0),
					"这个药水栏是空的", Palette.UI_TEXT_DIM, 16)
			return


func on_level_up(new_level: int) -> void:
	## 升级反馈：飘字 + 回一点血 + 音效
	Effects.text(get_parent(), global_position + Vector2(0.0, -70.0),
		"升级！Lv.%d" % new_level, Palette.UI_ACCENT, 26)
	Effects.spawn_marker(get_parent(), global_position, Palette.UI_ACCENT)
	heal_player(max_hp * 0.15)


func _update_visual(delta: float) -> void:
	if is_instance_valid(_held_staff):
		_held_staff.position=Vector2(facing*14,-24)
		_held_staff.flip_h=facing<0
		_held_staff.rotation=aim_direction.y*0.35*facing
		_held_staff.visible=extraction_pose==&"" and hp>0
	if visual == null:
		return
	# 像素画不做非整数缩放和旋转（会把像素揉糊），朝向只用 flip_h
	_update_animation()

	var color := Color.WHITE
	if hp <= 0.0:
		color = Color.WHITE
	elif _flash > 0.0:
		color = Color.WHITE.lerp(Color(1.0, 0.45, 0.45), float(SaveService.data.get("flash_strength", 1.0)))
	elif _invuln > 0.0:
		color.a = lerpf(0.8, 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() / 55.0)), float(SaveService.data.get("flash_strength", 1.0)))
	visual.modulate = color


func take_damage(amount: float, from: Vector2, source: Node = null) -> void:
	if extraction_controls_locked() or _invuln > 0.0 or hp <= 0.0 or amount<=0.0:
		return
	if extraction_pose == &"prayer": extraction_interrupted.emit()
	var cruel_part:=CruelDamage.portion(source,amount)
	var true_damage:=bloodbath_active() or cruel_part>0.0
	var protected_amount:=0.0 if bloodbath_active() else maxf(0.0,amount-cruel_part)
	if shield_hp > 0 and protected_amount>0.0:
		var absorbed := minf(shield_hp, protected_amount)
		shield_hp -= absorbed
		amount -= absorbed
		protected_amount-=absorbed
		if shield_hp <= 0.0 and absorbed > 0.0 and self is RoomPlayer:
			var mechanics: EquipmentMechanics = (self as RoomPlayer).equipment_mechanics
			if is_instance_valid(mechanics): mechanics.on_shield_broken()
		if self is RoomPlayer and is_instance_valid((self as RoomPlayer).holy_runtime):HolyFX.spawn(get_parent(),global_position,"cloud",30,.25)
		else:PaintedSpellFX.spawn(get_parent(), global_position, "res://assets/fx/painted/fx_fire_burst.png", 60, 0.32)
		if _shield_thorns>0.0 and is_instance_valid(source) and source.has_method("take_damage"):
			source.take_damage(_shield_thorns, false, global_position, DamageContext.reflection(self))
		if amount <= 0:
			_invuln = 0.18
			_block_timer = 0.22
			_animation_request += 1
			_update_animation()
			return
	if not bloodbath_active():amount=cruel_part+PassiveRuntime.share_damage(self,protected_amount)
	if amount<=0:
		_invuln=0.18;_block_timer=0.22;_animation_request+=1;_update_animation();return
	if bloodbath_active():
		bloodbath_hp_loss+=amount
	elif cruel_part>0.0:cruel_hp_loss+=cruel_part
	if true_damage:max_hp=maxf(0.0,stats.get_value(&"max_hp")-permanent_hp_loss())
	hp = minf(max_hp,maxf(0.0, hp - amount))
	if amount>0.0 and hp>0.0: PlayerDebuffs.from_source(self,source)
	_invuln = INVULN_TIME
	_flash = 0.28
	_hurt_timer = 0.35
	_animation_request += 1
	EventBus.player_damaged.emit(amount, hp, max_hp)
	EventBus.request_screen_shake.emit(8.0)
	Effects.damage_number(get_parent(), global_position + Vector2(0.0, -34.0), amount, false, Palette.UI_DANGER)

	var push := global_position - from
	if push.length() < 0.001:
		push = Vector2(float(-facing), -1.0)
	velocity = push.normalized() * CONTACT_PUSH

	# 荆棘反伤
	var thorns := Combat.thorns_damage(stats)
	if thorns > 0.0 and source != null and is_instance_valid(source) and source.has_method("take_damage"):
		source.take_damage(thorns, false, global_position, DamageContext.reflection(self))

	if hp <= 0.0:
		_die()


func heal_player(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0 or bloodbath_active():
		return
	var before := hp
	hp = minf(max_hp, hp + amount*PlayerDebuffs.multiplier(self,&"heal_received"))
	if hp > before:
		EventBus.player_healed.emit(hp - before, hp, max_hp)


func _die() -> void:
	# 死亡剧情会暂停场景；只让死亡精灵继续播放，物理与判定仍停止。
	_sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	_update_animation()
	Effects.death_burst(get_parent(), global_position, Palette.PLAYER_BODY, 22)
	EventBus.player_died.emit()
	set_physics_process(false)
	get_tree().create_timer(1.1).timeout.connect(func() -> void: visible = false)


func _on_stats_changed() -> void:
	var new_max := stats.get_value(&"max_hp")
	new_max=maxf(0.0,new_max-permanent_hp_loss())
	var was_alive:=hp>0.0
	var delta := new_max - max_hp
	max_hp = new_max
	if delta > 0.0 and not bloodbath_active():
		hp += delta
	hp = clampf(hp, 0.0, max_hp)
	EventBus.player_healed.emit(0.0, hp, max_hp)
	if was_alive and hp<=0.0:_die()

func bloodbath_active()->bool:return RunDifficulty.is_bloodbath(GameState.difficulty) and not CampSession.active
func permanent_hp_loss()->float:return maxf(0.0,bloodbath_hp_loss)+maxf(0.0,cruel_hp_loss)


func _build_hitbox() -> void:
	var body_shape := RectangleShape2D.new()
	body_shape.size = Vector2(24.0, 42.0)
	var body_collider := CollisionShape2D.new()
	body_collider.name = "BodyCollider"
	body_collider.shape = body_shape
	body_collider.position = Vector2.ZERO
	add_child(body_collider)

	_hitbox_shape = RectangleShape2D.new()
	_hitbox_shape.size = Vector2(38.0, 28.0)
	hitbox = Area2D.new()
	hitbox.name = "SwingHitbox"
	hitbox.collision_layer = Layers.PLAYER_ATTACK
	hitbox.collision_mask = Layers.ENEMY
	hitbox.monitoring = false
	var shape_node := CollisionShape2D.new()
	shape_node.shape = _hitbox_shape
	hitbox.add_child(shape_node)
	add_child(hitbox)
	_update_hitbox_position()


func _update_hitbox_position() -> void:
	if hitbox != null:
		# 判定框跟着瞄准方向旋转，近战/远程都按同一个方向结算
		hitbox.rotation = aim_direction.angle()
		hitbox.position = aim_direction * 24.0


func _build_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = PixelHeroArt.make_frames()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	add_child(_sprite)
	visual = _sprite
	_sprite.frame_changed.connect(func() -> void: PixelHeroArt.align(_sprite))
	_sprite.play(&"idle")
	PixelHeroArt.align(_sprite)


func _sync_companion() -> void:
	if is_instance_valid(_companion):_companion.queue_free();_companion=null
	if not is_instance_valid(equipment_aura):
		equipment_aura=EquipmentAura.new();equipment_aura.actor=self;add_child(equipment_aura)
	# Fallback sprite resources carry a staff; room sprites already include it.
	if self is RoomPlayer or Characters.current_id()==&"xixifu":return
	if not is_instance_valid(_held_staff):
		_held_staff=Sprite2D.new();_held_staff.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(_held_staff)
	var item:=GameState.equipped(&"weapon")
	_held_staff.texture=load(str(item.get("weapon",{}).get("sprite","res://assets/round5/items/wand_arcane.png")))
	_held_staff.scale=Vector2.ONE*0.6
	_held_staff.position=Vector2(23,2)


func _update_animation() -> void:
	pass # RoomPlayer owns directional animation.

func _draw() -> void:
	if shield_hp > 0 and hp > 0 and Characters.current_id()!=&"xixifu":
		draw_arc(Vector2(0, -4), 32, -PI * 0.8, PI * 0.8, 48, Color(1, 0.74, 0.34, 0.65), 2, false)



func _process(_delta: float) -> void:
	_update_hitbox_position()
	_update_shield_visual(_delta)

func _update_shield_visual(delta: float) -> void:
	if Characters.current_id()==&"xixifu":
		if is_instance_valid(_shield_visual):_shield_visual.queue_free();_shield_visual=null
		if shield_hp>0 and hp>0 and not is_instance_valid(_night_shelter_visual):
			_night_shelter_visual=NightShelterFX.new();add_child(_night_shelter_visual)
		return
	var active := shield_hp > 0 and hp > 0 and PixelSpellArt.strength() > 0
	if not active:
		if is_instance_valid(_shield_visual):
			_shield_visual.queue_free()
			_shield_visual = null
		return
	if not is_instance_valid(_shield_visual):
		_shield_visual = Sprite2D.new()
		_shield_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_shield_visual.position = Vector2(0, -4)
		_shield_visual.scale = Vector2.ONE * 78.0 / PixelSpellArt.LOGICAL_SIZE
		_shield_visual.z_index = -1
		_shield_visual.material = PixelSpellArt.material()
		add_child(_shield_visual)
	_shield_visual_age += delta
	_shield_visual.texture = PixelSpellArt.frames("fire")[[0, 1, 2, 1][int(_shield_visual_age * 7) % 4]]
	_shield_visual.modulate.a = 0.45 * PixelSpellArt.strength()


