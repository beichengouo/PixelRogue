class_name RoomLootDrop
extends LootDrop
func _physics_process(dt:float)->void:
	if _collected:return
	_animate(dt)
	if _advance_scatter(dt):return
	var magnetized:=_update_magnet(dt)
	if _collected:return
	if not magnetized:velocity=velocity.move_toward(Vector2.ZERO,420*dt)
	move_and_slide()
	if not magnetized and level is RoomLevel and not level.body_clear(global_position,8):
		global_position=level.nearest_clear(global_position,8)
