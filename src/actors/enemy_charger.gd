class_name EnemyCharger
extends EnemyBase
## Data-only archetype. RoomEnemy owns combat and navigation.
func _init() -> void:
	kind = &"charger"
	display_name = "兽人冲锋手"
	base_hp = 60.0
	base_damage = 28.0
	base_speed = 59.0
	base_coins = 5
	body_color = Palette.CHARGER
	body_size = Vector2(38.0, 29.0)
	sprite_name = "vampire"
	uses_gravity = false
	collides_with_world = true



