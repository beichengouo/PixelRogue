class_name EnemyTreant
extends EnemyBase
## Data-only archetype. RoomEnemy owns combat and navigation.
func _init() -> void:
	kind = &"treant"
	display_name = "林地兽人守卫"
	base_hp = 92.0
	base_damage = 28.0
	base_speed = 54.0
	base_coins = 5
	body_color = Color("7fae5a")
	body_size = Vector2(29.0, 32.0)
	sprite_name = "treant"
	uses_gravity = false
	collides_with_world = true



