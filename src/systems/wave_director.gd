class_name WaveDirector
extends Node
## 波次调度：什么时候刷怪、刷多少、什么时候休整。
##
## 节奏设计：
##   准备 3 秒（提示第 N 波来袭）→ 战斗（分段上限 6~9 只）
##   → 全清 → 三选一奖励 → 休整 8 秒（每十波 20 秒）（可以去商店）→ 下一波（更难）

enum Phase { IDLE, PREPARE, FIGHT, CLEARED, REST, OVER, COMPLETE }

const MAX_ALIVE := 6          # 缺省上限；正常波读取 WaveTable 的分段配置
const PREPARE_TIME := 3.0
const REST_TIME := 8.0
## Boss 波：第 10 / 20 / 30 场起按房间图生成
const BOSS_WAVES := WaveTable.BOSS_WAVES
## Boss 存活期间持续补小怪：间隔 + 场上小怪上限
const BOSS_MINION_INTERVAL := 4.5
const BOSS_MINION_CAP := 8

signal enemy_reward(enemy: EnemyBase)
var extraction_hold := false
var _reward_serial := 0
var boss: BossBase = null
var _minion_timer := 0.0
var _boss_wave := false

func is_boss_wave() -> bool:
	return _boss_wave

var _pending_minions: Array[Dictionary] = []
var _pending_spawns:Array[Dictionary]=[]
const VISIBLE_SPAWN_TIME:=0.9
const SPAWN_RETRY_TIME:=0.5

func _exit_tree() -> void:
	_clear_pending_spawns()
	_clear_pending_minions()

func _clear_pending_spawns() -> void:
	for entry:Dictionary in _pending_spawns:
		if is_instance_valid(entry.warning):entry.warning.queue_free()
		var enemy:EnemyBase=entry.enemy.get_ref() if entry.enemy!=null else null
		if is_instance_valid(enemy):enemy.set_meta("relocation_pending",false)
	_pending_spawns.clear()

func _clear_pending_minions() -> void:
	for pending:Dictionary in _pending_minions:
		for w:BossWarning in pending.warnings:
			if is_instance_valid(w):
				w.hide()
				w.queue_free()
	_pending_minions.clear()

const SPAWN_INTERVAL := 0.75
const PRESSURE_DELAY := 10.0  # 这么久没击杀，就判定为「僵持」，怪物集体暴怒
## 暴怒之后还是够不到玩家（比如被卡在跳不上去的坑里），就把它重新投放到屏外。
## 没有这道保险，某些地形会造出「永远打不完的一波」。
const RELOCATE_DELAY := 9.0
const RELOCATE_COOLDOWN := 4.0

var phase: Phase = Phase.IDLE
var wave := 0
var time_left := 0.0
var alive := 0
var total_this_wave := 0

var enemies_root: Node2D
var fx_root: Node2D
var chests_root: Node2D
var level: Level
var camera: Camera2D
var player: Node2D

var _queue: Array = []
var plan: Dictionary = {}
var _spawn_timer := 0.0
var _kill_timer := 0.0
var _enraged_this_wave := false
var _relocate_cd := 0.0
var _hp_scale := 1.0
var _damage_scale := 1.0
var _speed_scale := 1.0
var _attack_scale := 1.0


func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)


func on_player_died() -> void:
	phase = Phase.OVER
	_clear_pending_spawns()
	_clear_pending_minions()
	if is_instance_valid(boss): boss.cancel_attacks()


func _living_enemy_count() -> int:
	## 用"场上实际的敌人数量"判定是否清场，而不是自增自减的计数器 ——
	## 分裂怪、Boss 召唤、重投放都会让计数器对不上（症状：场上还有怪却宣布清场）。
	if enemies_root == null:
		return 0
	var n := 0
	for child in enemies_root.get_children():
		if child is EnemyBase and not (child as EnemyBase)._dead and child.loot_origin!="extraction":
			n += 1
	return n


func _clear_leftovers() -> void:
	_clear_pending_spawns()
	_clear_pending_minions()
	boss=null
	alive = 0
	if enemies_root == null:
		return
	for child in enemies_root.get_children():
		enemies_root.remove_child(child)
		child.queue_free()


func phase_title() -> String:
	match phase:
		Phase.PREPARE:
			return "第 %d 波来袭" % wave
		Phase.FIGHT:
			return "战斗中 · 剩余 %d" % (queued_count() + alive)
		Phase.CLEARED:
			return "清场！"
		Phase.REST:
			return "休整中"
		Phase.OVER:
			return "结束"
		_:
			return "准备"


func is_resting() -> bool:
	return phase == Phase.REST


func alive_count() -> int:
	return alive


func queued_count() -> int:
	return _queue.size()+_pending_spawn_count()


func seconds_since_kill() -> float:
	return _kill_timer


static func create_enemy(kind: StringName) -> EnemyBase:
	if kind in EnemyCombatPolicy.NEW_KINDS:return EnemyCombatPolicy.create(kind)
	match kind:
		&"flyer":
			return EnemyFlyer.new()
		&"charger":
			return EnemyCharger.new()
		&"caster":
			return EnemyCaster.new()
		&"bomber":
			return EnemyBomber.new()
		&"guard":
			return EnemyGuard.new()
		&"treant":
			return EnemyTreant.new()
		_:
			return EnemyWalker.new()







func reward_enemy(enemy: EnemyBase) -> void:
	if enemy.reward_uid.is_empty():
		_reward_serial+=1
		# Historical rooms may rewind serials, and instance IDs reset on restart.
		# An independent nonce leaves the gameplay RNG untouched and survives saves.
		enemy.reward_uid=GameState.sortie_id+":enemy:"+Crypto.new().generate_random_bytes(16).hex_encode()
	enemy_reward.emit(enemy)


func start_run()->void:pass

func start_run_at(_from_wave:int)->void:pass

func next_wave()->void:pass

func start_rest()->void:pass

func skip_rest()->void:pass

func spawn_boss_minion(_count:int)->void:pass

func clear_boss_minions()->void:pass


func queue_split_children(_source:EnemyBase)->void:pass

func _on_enemy_died(_kind:StringName,_where:Vector2,_coins:int)->void:pass

func _on_wave_cleared()->void:pass

func relocate_enemy(_enemy:EnemyBase)->bool:return false

func plan_boss_minions(count:int)->Array:
	var plans:Array=[]
	for i in count:plans.append({"at":Vector2.ZERO})
	return plans

func commit_boss_minions(plans:Array)->void:
	spawn_boss_minion(plans.size())

func _pending_spawn_count()->int:return _pending_spawns.size()
