class_name RoomEditorInvinciblePlayer
extends RoomPlayer

# Keep RoomPlayer's movement, collision, attacks, skills and visuals. Only
# suppress incoming damage for the isolated editor playtest.
func take_damage(_amount: float, _from: Vector2, _source: Node = null) -> void:
	pass
