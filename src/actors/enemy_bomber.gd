class_name EnemyBomber
extends EnemyBase
## Data-only archetype. RoomEnemy owns combat and navigation.
func _init() -> void:
	kind = &"bomber"
	display_name = "烬骨法师"
	base_hp = 20.0
	base_damage = 20.0
	base_speed = 108.0
	base_coins = 3
	body_color = Color("ff8a5c")
	body_size = Vector2(28.0, 30.0)
	sprite_name = "skeleton"
	uses_gravity = false
	collides_with_world = true


