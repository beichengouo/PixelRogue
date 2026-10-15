class_name ContractProjectile
extends RoomProjectile
## One direct hit plus one equal-damage blast; no basic-attack/lifesteal flags.
func _hit_effect(_hit_target:bool)->void:
	PixelSpellFX.spawn(get_parent(),global_position,"star","impact",explosion_radius*2,.42)
	_explode();queue_free()
func _explode()->void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy._dead or _hit_ids.has(enemy.get_instance_id()):continue
		if global_position.distance_to(enemy.global_position)>explosion_radius:continue
		var clear:bool=room.sight(global_position,enemy.global_position) if is_instance_valid(room) else (not is_instance_valid(level) or level.clear_sight(global_position,enemy.global_position))
		if clear:
			var before: float = enemy.hp
			enemy.take_damage(damage,false,global_position,DamageContext.ally(GameState.player))
			if enemy.hp<before and is_instance_valid(damage_actor) and GameState.player is RoomPlayer:
				(GameState.player as RoomPlayer).equipment_mechanics.on_ally_hit(enemy,damage_actor)
