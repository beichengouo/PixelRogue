class_name EnemyGuard
extends EnemyBase
## Data-only archetype. RoomEnemy owns combat and navigation.
func _init() -> void:
	kind = &"guard"
	display_name = "重装骸骨盾卫"
	base_hp = 234.0
	base_damage = 24.0
	base_speed = 52.0
	base_coins = 4
	body_color = Color("9fb6d6")
	body_size = Vector2(32.0, 36.0)
	sprite_name = "skeleton2"
	uses_gravity = false
	collides_with_world = true




