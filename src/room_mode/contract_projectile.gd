class_name ContractProjectile
extends RoomProjectile
## One direct hit plus one equal-damage blast; no basic-attack/lifesteal flags.
var capstone_lantern:=false
var capstone_direct_target:WeakRef
func _hit_enemy(enemy:EnemyBase)->bool:
	capstone_direct_target=weakref(enemy)
	return super._hit_enemy(enemy)
func _hit_effect(_hit_target:bool)->void:
	PixelSpellFX.spawn(get_parent(),global_position,"star","impact",explosion_radius*2,.42)
	_explode();queue_free()
func _explode()->void:
	var lantern_target:EnemyBase=capstone_direct_target.get_ref() as EnemyBase if capstone_direct_target!=null else null
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy._dead or _hit_ids.has(enemy.get_instance_id()):continue
		if global_position.distance_to(enemy.global_position)>explosion_radius:continue
		var clear:bool=room.sight(global_position,enemy.global_position) if is_instance_valid(room) else (not is_instance_valid(level) or level.clear_sight(global_position,enemy.global_position))
		if clear:
			var before: float = enemy.hp
			enemy.take_damage(damage,false,global_position,DamageContext.ally(damage_actor if is_instance_valid(damage_actor) else GameState.player))
			if enemy.hp<before and is_instance_valid(damage_actor) and GameState.player is RoomPlayer:
				(GameState.player as RoomPlayer).equipment_mechanics.on_ally_hit(enemy,damage_actor)
				if lantern_target==null:lantern_target=enemy
	if not capstone_lantern and lantern_target!=null and is_instance_valid(damage_actor) and damage_actor is SummonedAlly and damage_actor.source_skill==&"ghost_lantern" and PermanentTalents.active(&"ghost_lantern"):
		var target:EnemyBase=lantern_target
		var follow:=ContractProjectile.new();follow.room=room;follow.is_friendly=true;follow.damage_actor=damage_actor;follow.capstone_lantern=true;follow.explosion_radius=0;follow.art_scale=.55;follow.color=Color("dfc0ff");follow.homing_turn=TAU*2;follow.homing_range=180
		get_parent().add_child(follow)
		follow.setup(global_position,(target.global_position-global_position).normalized(),damage*.24,350,room,null,Color("dfc0ff"))
