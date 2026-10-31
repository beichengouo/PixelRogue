class_name XixifuBasicChain
extends RefCounted
## Actor-owned, normalized attack time; never serialized or advanced while paused.
const DURATIONS := [0.60, 0.75, 0.90, 1.10, 1.45]
const STARTS := [0.0, 0.60, 1.35, 2.25, 3.35]
const CYCLE := 4.80
const SHOT_BUDGET := CYCLE / 5.5
const BUDGETS := [SHOT_BUDGET, SHOT_BUDGET*2, SHOT_BUDGET*3, SHOT_BUDGET*4, CYCLE]
const RELEASE := 0.24
const LOCK := RELEASE - 0.08
const RESUME := 0.35
var clock := 0.0
var budget_until := 0.0
var active := false
var stage := 0
var segment_start := 0.0
var released := false
var aim_locked := false
var locked_aim := Vector2.RIGHT
var _requested := false
var _resume_stage := -1
var _resume_until := 0.0

func request() -> void:
	if not active: _requested = true

func cancel() -> void:
	active = false; _requested = false; _resume_stage = -1

func restore_cooldown(seconds: float, haste: float) -> void:
	cancel()
	clock = 0.0; budget_until = maxf(0.0, seconds) * maxf(0.1, haste)

func remaining() -> float:
	return maxf(0.0, budget_until - clock)

func elapsed() -> float:
	return maxf(0.0, clock - segment_start)

func visual_aim(current: Vector2) -> Vector2:
	return locked_aim if active and aim_locked else current

func _start(index: int) -> void:
	stage = index; segment_start = clock
	active = true; released = false; aim_locked = false; _resume_stage = -1

func advance(delta: float, haste: float, held: bool, aim: Vector2, emit: Callable) -> void:
	var end := clock + maxf(0.0, delta) * maxf(0.1, haste)
	while true:
		if not active:
			if not held and not _requested: break
			_requested = false
			if _resume_stage >= 0 and clock <= _resume_until + 0.000001:
				_start(_resume_stage)
			else:
				if budget_until > end + 0.000001: break
				clock = maxf(clock, budget_until); _start(0)
		var event_time := segment_start + (LOCK if not aim_locked else RELEASE if not released else float(DURATIONS[stage]))
		if event_time > end + 0.000001: break
		clock = event_time
		if not aim_locked:
			locked_aim = aim.normalized() if not aim.is_zero_approx() else Vector2.RIGHT
			aim_locked = true
		elif not released:
			released = true
			# Delayed resume shifts the debt too, so late finishers still recover.
			budget_until = maxf(budget_until, segment_start - float(STARTS[stage]) + float(BUDGETS[stage]))
			if not bool(emit.call(stage + 1, locked_aim)):
				cancel(); break
		else:
			var next := (stage + 1) % 5
			if held: _start(next)
			else:
				active = false; _resume_stage = next; _resume_until = clock + RESUME
	clock = end
