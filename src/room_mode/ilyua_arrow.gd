class_name IlyuaArrow
extends RoomProjectile

## Character arrows keep their own travel distance and hit identity. A wall reflection
## uses the swept collision normal; neither the range nor the life timer is reset.
var runtime: IlyuaRuntime
var arrow_kind: StringName = &"basic"
var main_arrow := true
var natural := true
var bounce_left := 0
var bounce_count := 0
var pierce_left := 0
var strong_pierce:=false
var wind_skill_serial:=0
var wall_seek := false
var seek_after_bounce := false
var target_ref: WeakRef
var redirect_left := 0
var traveled := 0.0
var flight_left := 4.0
var repeat_target_cap := 0
var hit_counts: Dictionary = {}
var blades_spawned:=0
var damage_multiplier:=1.0
var volley_id:=""
var primary_skill:StringName=&""
var seed_ratio:=.18
var fate_direct_multiplier:=1.0
var pact_empowered:=false
var guided:=false
var _frame_elapsed := 0.0

func _ready() -> void:
	super._ready()
	refresh_art()

func _build_weapon_effect()->void:
	_sprite=Sprite2D.new();_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(_sprite)
	refresh_art()

func _build_orb()->void:
	_build_weapon_effect()

func refresh_art()->void:
	if is_instance_valid(runtime):
		var frames: Array[Texture2D] = IlyuaFX.frames(weapon_fx if is_basic_attack else str(arrow_kind), "flight")
		if not frames.is_empty() and _sprite != null:
			_weapon_frames = frames
			_sprite.texture = frames[0]
			_sprite.scale = Vector2.ONE * art_scale * 32.0 / maxf(1.0, float(frames[0].get_width()))
			_sprite.material=RedrawnHeroArt.material()
			_sprite.modulate=Color.WHITE
			color=Color("92ef9b")
			for child in get_children():
				if child is PointLight2D:child.color=color

func _physics_process(delta: float) -> void:
	flight_left -= delta
	_frame_elapsed += delta
	if _sprite != null and not _weapon_frames.is_empty() and _frame_elapsed >= 1.0 / 12.0:
		_frame_elapsed = 0.0
		_frame = (_frame + 1) % _weapon_frames.size()
		_sprite.texture = _weapon_frames[_frame]
	if flight_left <= 0.0 or traveled >= range_limit or (is_instance_valid(room) and not room.bounds().grow(-4.0).has_point(global_position)):
		_fizzle()
		return
	var target: EnemyBase = target_ref.get_ref() as EnemyBase if target_ref != null else null
	if not _valid_target(target):
		target = _nearest_enemy() if homing_turn > 0.0 else null
	if _valid_target(target) and homing_turn > 0.0:
		var desired: Vector2 = (target.global_position - global_position).normalized()
		direction = direction.rotated(clampf(direction.angle_to(desired), -homing_turn * delta, homing_turn * delta))
		rotation = direction.angle()
	velocity = direction * speed
	var origin := global_position
	var collision := move_and_collide(velocity * delta)
	traveled += origin.distance_to(global_position)
	if collision != null:
		var body := collision.get_collider()
		if body is EnemyBase:
			if _hit_enemy(body as EnemyBase): return
		elif body is RoomProp:
			(body as RoomProp).take_damage(damage, false, global_position, self)
			_fizzle()
			return
		elif bounce_left > 0 and (not wall_seek or _hit_ids.is_empty()):
			bounce_left -= 1
			bounce_count += 1
			direction = direction.bounce(collision.get_normal()).normalized()
			rotation = direction.angle()
			global_position += collision.get_normal() * 2.0
			if seek_after_bounce:
				seek_after_bounce = false
				homing_range = 144.0
				homing_turn = TAU * 2.0
				basic_tracking = false
				var candidate := _nearest_enemy()
				if candidate != null: target_ref = weakref(candidate)
			if is_instance_valid(runtime): runtime.on_arrow_bounce(self)
		else:
			_fizzle()
			return
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyBase
		if _valid_target(enemy) and global_position.distance_to(enemy.global_position) <= hit_radius:
			if _hit_enemy(enemy): return
	if flight_left <= 0.0 or traveled >= range_limit: _fizzle()

func _valid_target(enemy: EnemyBase) -> bool:
	return is_instance_valid(enemy) and not enemy._dead and not enemy.is_queued_for_deletion()

func _nearest_enemy() -> EnemyBase:
	var result: EnemyBase
	var best := homing_range * homing_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyBase
		if not _valid_target(enemy) or _hit_ids.has(enemy.get_instance_id()): continue
		var delta: Vector2 = enemy.global_position - global_position
		if delta.length_squared() >= best or delta.is_zero_approx(): continue
		if basic_tracking:
			if direction.dot(delta.normalized()) <= 0.0 or owner_aim.dot(delta.normalized()) < cos(PI / 6.0): continue
		if is_instance_valid(room) and (not room.sight(global_position, enemy.global_position) or not room.projectile_clear(global_position, enemy.global_position)): continue
		best = delta.length_squared()
		result = enemy
	return result

func _hit_enemy(enemy: EnemyBase) -> bool:
	if not _valid_target(enemy): return false
	var id := enemy.get_instance_id()
	var repeat_count := int(hit_counts.get(id, 0))
	if _hit_ids.has(id): return false
	if is_instance_valid(runtime) and not runtime.allow_volley_hit(self,enemy):
		_hit_ids[id]=true;add_collision_exception_with(enemy);return false
	_hit_ids[id] = true
	hit_counts[id] = repeat_count + 1
	var before := enemy.hp
	var shield_before := enemy.affix_shield
	var amount := damage * (1.0 + minf(0.16, 0.08 * bounce_count) if is_instance_valid(runtime) and runtime.rank(&"ilyua_returning_arrow") >= 3 else 1.0)
	if is_instance_valid(runtime): amount *= runtime.arrow_multiplier(self, enemy)
	amount*=damage_multiplier
	if not is_basic_attack and primary_skill!=&"" and is_instance_valid(runtime): amount *= runtime.actor.equipment_mechanics.skill_multiplier(enemy)*runtime.skill_bonus()*fate_direct_multiplier
	var source: Node = self if is_basic_attack else DamageContext.skill(runtime.actor) if primary_skill!=&"" and is_instance_valid(runtime) else DamageContext.character_proc(runtime.actor) if is_instance_valid(runtime) else self
	if is_instance_valid(runtime) and natural and primary_skill!=&"":runtime.natural_hits[id]=true
	enemy.take_damage(amount, is_basic_attack and attack_receipt != null and attack_receipt.critical, global_position, source, false)
	if is_instance_valid(runtime) and runtime.natural_hits.has(id) and (enemy.hp<before or enemy.affix_shield<shield_before):runtime.on_direct_natural_hit(enemy)
	if is_instance_valid(runtime):runtime.natural_hits.erase(id)
	var effective := is_instance_valid(enemy) and (enemy.hp < before or enemy.affix_shield < shield_before)
	if effective and is_instance_valid(runtime):
		if is_basic_attack and attack_receipt != null: runtime.actor.heal_player(attack_receipt.claim())
		if is_basic_attack and is_instance_valid(runtime.actor.equipment_mechanics): runtime.actor.equipment_mechanics.on_basic_hit(enemy, attack_receipt, self)
		elif primary_skill!=&"" and is_instance_valid(runtime.actor.equipment_mechanics): runtime.actor.equipment_mechanics.on_skill_hit(enemy, true)
		runtime.on_arrow_hit(self, enemy, effective)
	if strong_pierce or pierce_left > 0:
		if not strong_pierce:pierce_left -= 1
		pierce = pierce_left
		add_collision_exception_with(enemy)
		return false
	if redirect_left > 0 and bounce_count>0 and is_instance_valid(runtime):
		var other: EnemyBase = runtime.nearest_enemy(enemy.global_position, 108.0, enemy, _hit_ids)
		if other != null:
			redirect_left -= 1
			target_ref = weakref(other)
			homing_turn = TAU * 3.0
			_hit_ids[id] = true
			add_collision_exception_with(enemy)
			return false
	_hit_effect(true)
	return true

func _hit_effect(_strong:bool)->void:
	IlyuaFX.spawn(get_parent(),global_position,"spring_hit" if weapon_fx=="bow_spring_wind" else "arrow_hit",32,.25)
	queue_free()

func snapshot() -> Dictionary:
	var saved_hits:Array=[]
	for id in _hit_ids:saved_hits.append(str(id))
	var saved_receipt:Dictionary={}
	if attack_receipt!=null:saved_receipt={"id":str(attack_receipt.get_instance_id()),"claimed":attack_receipt.claimed,"critical":attack_receipt.critical,"effects":attack_receipt.effects.keys()}
	var target:EnemyBase=target_ref.get_ref() as EnemyBase if target_ref!=null else null
	return {"fate_direct_multiplier":fate_direct_multiplier,"strong_pierce":strong_pierce,"wind_skill_serial":wind_skill_serial,"kind": str(arrow_kind), "at": [global_position.x, global_position.y], "direction": [direction.x, direction.y], "owner_aim":[owner_aim.x,owner_aim.y],"damage": damage, "speed": speed, "range": range_limit, "traveled": traveled, "life": flight_left, "main": main_arrow, "natural": natural, "basic": is_basic_attack, "bounce_left": bounce_left, "bounce_count": bounce_count, "pierce_left": pierce_left, "wall_seek": wall_seek, "seek_after_bounce": seek_after_bounce, "redirect_left": redirect_left, "hit_ids": saved_hits, "hit_counts": hit_counts.duplicate(), "receipt":saved_receipt,"weapon_fx":weapon_fx,"seed_ratio":seed_ratio,"blades_spawned":blades_spawned,"volley_id":volley_id,"pact_empowered":pact_empowered,"guided":guided,"homing_range":homing_range,"homing_turn":homing_turn,"basic_tracking":basic_tracking,"primary_skill":str(primary_skill),"target":str(target.get_instance_id()) if is_instance_valid(target) else ""}
