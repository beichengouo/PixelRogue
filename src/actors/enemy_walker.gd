class_name EnemyWalker
extends EnemyBase
## Data-only archetype. RoomEnemy owns combat and navigation.
func _init() -> void:
	kind = &"walker"
	display_name = "骸骨游荡者"
	base_hp = 30.0
	base_damage = 16.0
	base_speed = 83.0
	base_coins = 2
	body_color = Palette.WALKER
	body_size = Vector2(29.0, 32.0)
	sprite_name = "skeleton"
	uses_gravity = false
	collides_with_world = true



