class_name RoomProjectile
extends Projectile
const BASIC_TRACK_RANGE:=108.0
const BASIC_TRACK_HALF_ANGLE:=PI/6.0
const BASIC_TRACK_TURN:=PI/2.0
var room: RoomLevel
var damage_owner:StringName=&"ally"
var range_limit := 540.0
var owner_aim := Vector2.RIGHT
var homing_origin := Vector2.ZERO
var mechanic_tag: StringName = &""
var skill_damage_multiplier := 1.0
var damage_actor: Node2D
var basic_tracking:=false
var hostile_tracking:=false
var hostile_aim:=Vector2.RIGHT
var hostile_fx := ""
var hostile_width := 26.0
var cruel_damage := false
var hostile_effects: Array[Dictionary] = []

func player_debuffs() -> Array[Dictionary]:
	return [] if is_friendly else hostile_effects

func _build_orb() -> void:
	if not is_friendly and hostile_fx.is_empty():hostile_fx="dusk_acolyte";hostile_width=32
	if not hostile_fx.is_empty():
		_weapon_frames=HostileAttackFX.frames(hostile_fx,"flight")
		if not _weapon_frames.is_empty():
			_sprite=Sprite2D.new();_sprite.texture=_weapon_frames[0];_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;_sprite.material=ink
			add_child(_sprite);_frame_timer=1.0/12.0;_apply_art_scale();return
	super._build_orb()

func _hit_effect(hit_target: bool) -> void:
	if not hostile_fx.is_empty():
		HostileAttackFX.pulse(get_parent(),global_position,hostile_fx,"impact",40.0,.28,0.0,room)
		queue_free();return
	super._hit_effect(hit_target)

func enable_basic_tracking(aim:Vector2,origin:Vector2)->void:
	basic_tracking=true
	owner_aim=aim.normalized()
	homing_origin=origin
	homing_range=BASIC_TRACK_RANGE
	homing_turn=BASIC_TRACK_TURN

func _hit_enemy(enemy: EnemyBase) -> bool:
	var id := enemy.get_instance_id()
	if _hit_ids.has(id): return false
	_hit_ids[id] = true
	var before := enemy.hp
	var shield_before:=enemy.affix_shield
	var source: Node = self
	var critical := is_basic_attack and attack_receipt != null and attack_receipt.critical
	if mechanic_tag == &"equipment": source = DamageContext.equipment(GameState.player)
	elif mechanic_tag==&"character_proc":source=DamageContext.character_proc(GameState.player)
	elif damage_owner == &"player" and not is_basic_attack: source = DamageContext.skill(GameState.player)
	elif damage_owner == &"ally": source = DamageContext.ally(GameState.player)
	var amount := damage * skill_damage_multiplier
	if damage_owner == &"player" and not is_basic_attack and mechanic_tag not in [&"equipment",&"character_proc"] and GameState.player is RoomPlayer:
		amount *= (GameState.player as RoomPlayer).equipment_mechanics.skill_multiplier(enemy)
	enemy.take_damage(amount, critical, global_position, source)
	var effective := is_instance_valid(enemy) and (enemy.hp < before or enemy.affix_shield<shield_before)
	if effective and is_basic_attack and is_instance_valid(GameState.player):
		if attack_receipt != null: GameState.player.heal_player(attack_receipt.claim())
		if GameState.player is RoomPlayer and is_instance_valid((GameState.player as RoomPlayer).equipment_mechanics):
			(GameState.player as RoomPlayer).equipment_mechanics.on_basic_hit(enemy, attack_receipt, self)
	elif effective and damage_owner == &"player" and mechanic_tag not in [&"equipment",&"character_proc"] and GameState.player is RoomPlayer:
		(GameState.player as RoomPlayer).equipment_mechanics.on_skill_hit(enemy, true)
	elif effective and damage_owner == &"ally" and is_instance_valid(GameState.player) and GameState.player is RoomPlayer and is_instance_valid(damage_actor):
		(GameState.player as RoomPlayer).equipment_mechanics.on_ally_hit(enemy, damage_actor)
	if burn_dps > 0.0 and is_instance_valid(enemy): enemy.apply_burn(burn_dps, 3.0, DamageContext.dot(GameState.player))
	if pierce > 0:
		pierce -= 1
		add_collision_exception_with(enemy)
		Effects.hit_spark(get_parent(), global_position, color, 5)
		return false
	_hit_effect(true)
	return true

func _apply_art_scale()->void:
	super._apply_art_scale();hit_radius=9
	if not hostile_fx.is_empty() and _sprite!=null:_sprite.scale=Vector2.ONE*hostile_width/maxf(1,_weapon_frames[0].get_width())
	if _collider!=null:(_collider.shape as CircleShape2D).radius=5

func _ready() -> void:
	super._ready()
	add_to_group("room_projectiles")
	hit_radius = 9.0
	(_collider.shape as CircleShape2D).radius = 5.0

func _physics_process(delta: float) -> void:
	if is_instance_valid(room) and (not room.bounds().grow(-4).has_point(global_position) or global_position.distance_to(_start)>range_limit):
		_fizzle(); return
	if hostile_tracking and not is_friendly and is_instance_valid(player):
		var offset:Vector2=player.global_position-global_position
		if offset.length()<=108 and offset.length()>1 and hostile_aim.dot(offset.normalized())>=cos(PI/6) and room.projectile_clear(global_position,player.global_position):
			direction=direction.rotated(clampf(direction.angle_to(offset.normalized()),-PI/2*delta,PI/2*delta));rotation=direction.angle()
	super._physics_process(delta)

func _on_body_hit(collider: Object) -> bool:
	if not is_friendly and collider is IlyuaDecoy:
		collider.take_damage(damage,global_position,self);_hit_effect(true);return true
	if not is_friendly and collider is RoomAlly:
		collider.take_damage(damage,global_position,self);_hit_effect(true);return true
	if collider is RoomProp:
		if is_friendly: collider.take_damage(damage,false,global_position,self)
		_hit_effect(false); return true
	return super._on_body_hit(collider)

func _nearest_enemy() -> EnemyBase:
	var result: EnemyBase
	var distance := homing_range*homing_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyBase
		if not is_instance_valid(enemy) or enemy._dead or _hit_ids.has(enemy.get_instance_id()): continue
		if basic_tracking:
			var toward:=enemy.global_position-global_position
			if toward.is_zero_approx():return enemy
			if toward.length_squared()>distance or direction.dot(toward.normalized())<=0:continue
			if owner_aim.dot(toward.normalized())<cos(BASIC_TRACK_HALF_ANGLE):continue
			if is_instance_valid(room) and (not room.sight(global_position,enemy.global_position,ghost) or (not ghost and not room.projectile_clear(global_position,enemy.global_position))):continue
			distance=toward.length_squared();result=enemy
			continue
		var offset := enemy.global_position-homing_origin
		if offset.length()>homing_range or owner_aim.dot(offset.normalized())<cos(PI/4): continue
		if room!=null and not room.sight(global_position,enemy.global_position,ghost): continue
		var d := global_position.distance_squared_to(enemy.global_position)
		if d<distance: distance=d; result=enemy
	return result

func _explode() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyBase
		if not is_instance_valid(enemy) or enemy._dead or _hit_ids.has(enemy.get_instance_id()): continue
		if global_position.distance_to(enemy.global_position)<=explosion_radius and room.sight(global_position,enemy.global_position,ghost):
			var splash_source: Node = DamageContext.equipment(GameState.player) if mechanic_tag==&"equipment" else DamageContext.basic_splash(GameState.player) if is_basic_attack else DamageContext.skill(GameState.player) if damage_owner==&"player" else DamageContext.ally(GameState.player)
			enemy.take_damage(damage*explosion_ratio,false,global_position,splash_source)

func enable_hostile_tracking(aim:Vector2)->void:
	hostile_tracking=true;hostile_aim=aim.normalized()
	trail=true;trail_color=Color("ff7189");trail_size=2.5
