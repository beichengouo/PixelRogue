class_name EnemyFlyer
extends EnemyBase
## Data-only archetype. RoomEnemy owns combat and navigation.
func _init() -> void:
	kind = &"flyer"
	display_name = "幽骨浮灵"
	base_hp = 22.0
	base_damage = 14.0
	base_speed = 135.0
	base_coins = 2
	body_color = Palette.FLYER
	body_size = Vector2(27.0, 27.0)
	sprite_name = "skull"
	uses_gravity = false
	collides_with_world = false




