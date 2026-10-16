class_name BossBase
extends EnemyBase
## Shared Boss lifecycle; room progression gates are 10 / 20 / 30 encounters.
##
## 通用部分：
##   · 体型放大 + 专属图标（血条 UI 用）+ 出场/死亡广播 boss_started / boss_defeated
##   · 技能用「冷却表」驱动：子类只写 abilities() 就是一套招式表
##   · 提供骨刺 / 扇形弹幕 / 环形爆发 / 召唤 / 震地 / 扫射激光 / 落石等公共招式
##   · 存活期间由波次系统持续补小怪（见 WaveDirector）
##
## 招式特效素材来自 E:\素材\技能 的 KILN_FX（爆炸 × 火/冰、魔法阵 × 奥术/神圣），
## 已经拷到 assets/fx/boss_*.png，都是 64x64 的横条帧。

const FX_EXPLOSION := "res://assets/fx/boss_explosion_fire.png"
const FX_FROST := "res://assets/fx/boss_explosion_frost.png"
const FX_CIRCLE_ARCANE := "res://assets/fx/boss_circle_arcane.png"
const FX_CIRCLE_HOLY := "res://assets/fx/boss_circle_holy.png"
const FX_FRAME := Vector2i(64, 64)

var boss_id: StringName = &"king"
var boss_title := "BOSS"
var boss_icon := ""
## 体型放大倍数（只放大视觉，判定箱由 body_size 决定）
var art_scale := 2.4
var phase := 1
var max_phase := 1

var _ability_index := 0
var _ability_cd := 1.2
var _channel := 0.0
var _idle_dir := 1.0
var attack_serial := 0
var attack_id: StringName = &""
var attack_elapsed := 0.0
var _jobs: Array[Dictionary] = []
var _warning_serial = 0
var _warnings: Array[BossWarning] = []
var _owned_bullets: Array[Projectile] = []

func _ready() -> void:
	super._ready()
	if visual != null:
		if visual is AnimatedSprite2D:
			PixelBossArt.align(visual,boss_id,body_size)
		else:
			visual.scale = Vector2.ONE * art_scale
			visual.position = Vector2(0,-body_size.y*(art_scale-1)*0.5)
	EventBus.player_died.connect(cancel_attacks)
	EventBus.boss_started.emit(boss_id)
	if not is_instance_valid(GameState.runtime_node) or not GameState.runtime_node._restoring:
		Effects.text(_fx(),global_position+Vector2(0,-80),boss_title,EnemyAffixes.danger_color(9),30)
		EventBus.request_screen_shake.emit(10.0)

func _exit_tree() -> void:
	cancel_attacks()

func attack_valid(serial: int) -> bool:
	if serial!=attack_serial or _dead or not is_inside_tree() or is_queued_for_deletion(): return false
	if not is_instance_valid(player) or float(player.get("hp"))<=0: return false
	if is_instance_valid(director):
		return director.phase==WaveDirector.Phase.FIGHT and director.boss==self
	return true

func _remove_warning(w: BossWarning) -> void:
	if is_instance_valid(w):
		w.hide()
		w.queue_free()
	_warnings.erase(w)

func cancel_attacks(clear_bullets := true) -> void:
	attack_serial+=1
	_jobs.clear()
	_channel=0
	attack_id=&""
	telegraph=0
	for w in _warnings.duplicate(): _remove_warning(w)
	if clear_bullets:
		for bullet in _owned_bullets:
			if is_instance_valid(bullet):
				bullet.set_physics_process(false)
				bullet.hide()
				bullet.queue_free()
		_owned_bullets.clear()

func _warn(style: String, at: Vector2, time: float, radius: float, direction := Vector2.RIGHT, spread := 0.8) -> BossWarning:
	var w:=BossWarning.new()
	w.style=style
	w.duration=time
	w.radius=radius
	w.aim=direction
	w.spread=spread
	w.tint=body_color.lightened(0.15)
	w.extent=body_size
	_fx().add_child(w)
	w.global_position=at.round()
	w.set_meta("boss_owner",get_instance_id())
	w.set_meta("start",attack_elapsed)
	_warning_serial += 1
	w.set_meta("warning_key",str(_warning_serial))
	_warnings.append(w)
	return w

func _check_contact() -> void:
	if attack_id==&"phase": return
	super._check_contact()

func _request_relocate() -> void:
	reset_path()

func _update_aggro(_delta: float) -> void:
	# Boss 路径与招式保持同一玩家目标。
	if aggro != player:
		aggro=player
		reset_path()

func _update_visual() -> void:
	super._update_visual()
	if visual is AnimatedSprite2D:
		var sprite:=visual as AnimatedSprite2D
		var animation:StringName=boss_visual_animation()
		if sprite.animation!=animation:
			if animation==&"release": sprite.speed_scale=4.0/maxf(0.05,_channel)/12.0
			elif animation!=&"windup": sprite.speed_scale=1
			sprite.play(animation)
		PixelBossArt.align(sprite,boss_id,body_size)

func boss_visual_animation()->StringName:
	if attack_id!=&"":return &"windup" if not _warnings.is_empty() else &"release"
	return &"move" if absf(velocity.x)>12 else &"idle"

func _die() -> void:
	if _dead: return
	cancel_attacks()
	EventBus.boss_defeated.emit(boss_id)
	EventBus.request_screen_shake.emit(16.0)
	if is_instance_valid(director): director.clear_boss_minions()
	Effects.death_burst(_fx(),global_position,body_color,22)
	super._die()

# Serializable commands retain the remaining attack timeline across suspension.
