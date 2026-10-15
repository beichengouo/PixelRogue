class_name CameraRig
extends Camera2D
## 相机：跟随玩家 + 按朝向预瞄 + 边界限制 + 受击震屏。

var target: Node2D
var lookahead := 68.0
var follow_speed := 7.0
var shake_amount := 0.0

var _follow_position := Vector2.ZERO
var _shake_time := 0.0


func _ready() -> void:
	position_smoothing_enabled = false
	EventBus.request_screen_shake.connect(_on_shake_requested)


func setup(level_bounds: Rect2) -> void:
	limit_left = int(level_bounds.position.x)
	limit_top = int(level_bounds.position.y)
	limit_right = int(level_bounds.end.x)
	limit_bottom = int(level_bounds.end.y)
	global_position = level_bounds.get_center()
	_follow_position = global_position


func snap_to_target() -> void:
	if target != null and is_instance_valid(target):
		global_position = target.global_position + Vector2(0.0, -40.0)
		_follow_position = global_position
		shake_amount = 0.0
		offset = Vector2.ZERO
		force_update_scroll()


func _on_shake_requested(strength: float) -> void:
	if float(SaveService.data.get("screen_shake_strength", 1.0)) > 0:
		shake_amount = minf(16, maxf(shake_amount, strength))

