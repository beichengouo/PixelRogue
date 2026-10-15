class_name RoomKey
extends Coin
var _rotation_clock := 0.0
func _build_visual()->void:
	_sprite=Sprite2D.new()
	_key_frames=load("res://assets/supplied_20261011/key/rotate.tres") as SpriteFrames
	_sprite.texture=_key_frames.get_frame_texture(&"default",0)
	_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale=Vector2.ONE*(26.0/_sprite.texture.get_height())
	add_child(_sprite)
func _animate(dt:float)->void:
	_rotation_clock+=dt
	_sprite.texture=_key_frames.get_frame_texture(&"default",posmod(floori(_rotation_clock*12),24))
	_sprite.position=Vector2(0,roundf(sin(_rotation_clock*4.5)*2))
func _physics_process(dt:float)->void:
	if _collected:return
	_animate(dt)
	velocity=velocity.move_toward(Vector2.ZERO,360*dt)
	var magnetized:=is_instance_valid(player) and not player.is_queued_for_deletion() and player.global_position.distance_to(global_position)<130
	_set_world_collision(not magnetized)
	if magnetized:
		velocity=(player.global_position-global_position).normalized()*220
		if player.global_position.distance_to(global_position)<24:_collect();return
	move_and_slide()
