class_name EnemyCaster
extends EnemyBase
## Data-only archetype. RoomEnemy owns combat and navigation.
func _init() -> void:
	kind = &"caster"
	display_name = "死灵法师"
	base_hp = 26.0
	base_damage = 12.0
	base_speed = 74.0
	base_coins = 3
	body_color = Color("b06bff")
	body_size = Vector2(28.0, 34.0)
	sprite_name = "vampire"
	uses_gravity = false
	collides_with_world = true




