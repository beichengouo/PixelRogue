extends "res://tests/v21_gm_campaign.gd"
## Observation only: no AI controls, stats, RNG, enemy or reward modifications.
const DIAGNOSTIC := "E:/CodexWorkspace/PixelRogue/work/v22-narrative-tarot/v22-gm-diagnostic.jsonl"
var _diagnostic_file: FileAccess
var _attached := false
var _sample_left := 0.0
var _previous_at := Vector2.INF
var _walked := 0.0
var _basic_hits := 0
var _basic_damage := 0.0
var _direct_skill_hits := 0
var _last_cast := ""
var _recent: Array = []
func _ready() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").begins_with(OUTPUT_ROOT):
		get_tree().quit(2)
		return
	_diagnostic_file = FileAccess.open(DIAGNOSTIC, FileAccess.WRITE)
	EventBus.enemy_spawned.connect(_observe_enemy)
	EventBus.skill_cast.connect(_observe_cast)
	EventBus.player_damaged.connect(_observe_hurt)
	super._ready()
func _observe_enemy(node: Node) -> void:
	if node is EnemyBase and not node.damage_applied.is_connected(_observe_hit): node.damage_applied.connect(_observe_hit)
func _observe_hit(enemy: EnemyBase, amount: float, source: Node, kind: StringName) -> void:
	if kind == &"basic": _basic_hits += 1; _basic_damage += amount
	elif kind == &"skill": _direct_skill_hits += 1
func _emit_row(row: Dictionary) -> void:
	if _diagnostic_file == null: return
	_diagnostic_file.store_line(JSON.stringify(row))
	_diagnostic_file.flush()
func _observe_cast(id: StringName) -> void:
	_last_cast = str(id)
	if started and is_instance_valid(main) and is_instance_valid(main.player):
		var row := _snapshot("cast")
		row.skill = str(id)
		_emit_row(row)
func _observe_hurt(amount: float, hp: float, max_hp: float) -> void:
	if not started or not is_instance_valid(main) or not is_instance_valid(main.player): return
	var row := _snapshot("hurt")
	row.amount = amount; row.hp = hp; row.max_hp = max_hp; row.recent = _recent.duplicate(true)
	_emit_row(row)
func _snapshot(kind: String) -> Dictionary:
	var actor: RoomPlayer = main.player
	var pilot: GMPilot = main.gm_pilot
	var threats := pilot._visible_threats()
	var enemy_rows: Array = []
	for enemy: EnemyBase in threats.enemies:
		if actor.global_position.distance_to(enemy.global_position) > 500: continue
		var row := {"uid":str(enemy.reward_uid),"kind":str(enemy.kind),"position":str(enemy.global_position),"velocity":str(enemy.velocity),"hp":enemy.hp,"distance":actor.global_position.distance_to(enemy.global_position),"affixes":enemy.affixes,"pressure":enemy.room_pressure_growth,"raw_speed":enemy.move_speed,"chase_speed":enemy.effective_chase_speed(),"clear_shot":main.level.projectile_clear(actor.global_position,enemy.global_position)}
		if enemy is RoomEnemy: row.merge({"windup":enemy._windup,"rush":enemy._rush,"locked_aim":str(enemy._locked_direction),"target":str(enemy.aggro_position())})
		enemy_rows.append(row)
	var row := {"event":kind,"time":seconds,"stage":main.graph.stage_index,"room":str(main.graph.current),"room_kind":str(main.graph.rooms[main.graph.current].kind),"position":str(actor.global_position),"velocity":str(actor.velocity),"motion":str(actor.movement_override),"aim":str(actor.aim_override),"hp":actor.hp,"max_hp":actor.max_hp,"shield":actor.shield_hp,"mp":GameState.mp,"cooldowns":GameState.skill_cooldowns_by_id.duplicate(true),"danger":pilot._danger_at(actor.global_position,threats),"dash_timer":actor._dash_timer,"dash_cd":actor._dash_cd,"stuck":pilot._stuck,"basic_hits":_basic_hits,"basic_damage":_basic_damage,"skill_hits":_direct_skill_hits,"walked":_walked,"last_cast":_last_cast,"bullets":threats.bullets.size(),"enemies":enemy_rows}
	if is_instance_valid(actor.ilyua_runtime): row.merge({"forest_step_left":actor.ilyua_runtime.step_left,"forest_step_direction":str(actor.ilyua_runtime.step_direction)})
	return row
func _process(dt: float) -> void:
	super._process(dt)
	if not started or not is_instance_valid(main) or not is_instance_valid(main.player): return
	var actor: RoomPlayer = main.player
	if not _attached:
		_attached = true
		for node in main.enemies_root.get_children(): _observe_enemy(node)
	if not _previous_at.is_equal_approx(Vector2.INF) and _previous_at.distance_to(actor.global_position)<100: _walked += _previous_at.distance_to(actor.global_position)
	_previous_at = actor.global_position
	_sample_left -= dt
	if _sample_left > 0 or UIFlow.has_screen() or TransitionLayer.busy or main._navigation_pending: return
	_sample_left = .2
	if main.graph.stage_index < 3: return
	var row := _snapshot("sample")
	_recent.append(row)
	if _recent.size() > 10: _recent.pop_front()
	_emit_row(row)
func _exit_tree() -> void:
	if _diagnostic_file != null: _diagnostic_file.close()
