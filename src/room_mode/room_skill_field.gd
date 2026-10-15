class_name RoomSkillField
extends Node2D
var caster: WeakRef
var skill_id: StringName = &""
var room: RoomLevel
var family := "nature"
var kind := "bloom"
var direction := Vector2.RIGHT
var radius := 108.0
var length_value := 144.0
var width_value := 72.0
var remaining := 5.0
var damage := 0.0
var interval := 0.75
var timer := 0.0
var delay := 0.0
var hit: Dictionary = {}
var _tint := Color("91dab0")

func _ready() -> void:
	add_to_group("spell_fields")
	z_index = 0
	set_meta("run_epoch",GameState.run_epoch);set_meta("room_id",str(room.record.get("id","")))
	EventBus.run_started.connect(func(_id:int)->void:queue_free(),CONNECT_ONE_SHOT)
	EventBus.player_died.connect(queue_free,CONNECT_ONE_SHOT)
	_tint = Color("ffb777") if kind == "meteor" else Color("91dab0")
	if kind=="bloom":RoomSpellSpriteFX.spawn(self,Vector2.ZERO,&"starfall",radius*2,remaining,true)
	elif kind=="snare":
		var roots_fx:=RoomSpellSpriteFX.spawn(self,direction*length_value*.5,&"frost_nova",length_value,remaining,true)
		if roots_fx!=null:
			roots_fx.rotation=direction.angle();roots_fx.scale.y*=width_value/length_value
	queue_redraw()

func contains(at: Vector2) -> bool:
	var offset := at-global_position
	if kind == "snare":
		return absf(offset.dot(direction.orthogonal()))<=width_value/2 and offset.dot(direction)>=0 and offset.dot(direction)<=length_value
	return offset.length()<=radius

func _physics_process(dt: float) -> void:
	var actor: Node = caster.get_ref() if caster!=null else null
	if not is_instance_valid(actor) or actor.hp<=0 or (not GameState.run_active and not CampSession.active) or int(get_meta("run_epoch",-1))!=GameState.run_epoch or str(room.record.get("id",""))!=str(get_meta("room_id","")): queue_free(); return
	if delay>0:
		delay = maxf(0,delay-dt)
		if delay>0: return
		pulse(); queue_free(); return
	remaining -= dt
	if kind == "snare":
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy._dead or not contains(enemy.global_position) or not room.sight(global_position,enemy.global_position): continue
			enemy.apply_slow(0.3 if enemy is BossBase else 0.6,0.5)
			if not hit.has(enemy.get_instance_id()):
				hit[enemy.get_instance_id()] = true
				var before: float = enemy.hp
				var mechanics: EquipmentMechanics=(actor as RoomPlayer).equipment_mechanics
				enemy.take_damage(damage*mechanics.skill_multiplier(enemy),false,global_position,DamageContext.skill(actor))
				if enemy.hp<before:mechanics.on_skill_hit(enemy,true)
	else:
		timer -= dt
		if timer<=0: timer+=interval; pulse()
	if remaining<=0: queue_free()

func pulse() -> void:
	var actor: Node = caster.get_ref() if caster!=null else null
	if not is_instance_valid(actor): return
	if kind=="meteor":
		var impact_fx:=RoomSpellSpriteFX.spawn(get_parent(),global_position,&"meteor",radius*2,.45)
		if impact_fx==null:PixelSpellFX.spawn(get_parent(),global_position,"fire","impact",radius*2,.4)
	elif not ResourceLoader.exists("res://assets/next_revision/fx/sylphiette_spells.png"):PixelSpellFX.spawn(get_parent(),global_position,"nature","impact",radius*2,.4)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy._dead or not contains(enemy.global_position) or not room.sight(global_position,enemy.global_position): continue
		var mechanics: EquipmentMechanics=(actor as RoomPlayer).equipment_mechanics
		var before: float = enemy.hp
		enemy.take_damage(damage*(mechanics.skill_multiplier(enemy) if skill_id==&"meteor" else 1.0),false,global_position,DamageContext.skill(actor))
		if skill_id==&"meteor" and enemy.hp<before:mechanics.on_skill_hit(enemy,true)
		if kind == "bloom": enemy.apply_slow(0.3,1.0)
	if kind == "bloom":
		var heal_scale := 1.0+GameState.talent_effect(&"nature_attune","自然治疗加成%")/100
		if contains(actor.global_position): actor.heal_player(actor.max_hp*0.02*heal_scale)
		for ally in get_tree().get_nodes_in_group("allies"):
			if is_instance_valid(ally) and contains(ally.global_position) and room.sight(global_position,ally.global_position): ally.heal(ally.max_hp*0.01*heal_scale)

func _draw() -> void:
	var tint := _tint; tint.a = 0.14
	if kind=="snare":
		var points := PackedVector2Array([direction.orthogonal()*width_value/2,-direction.orthogonal()*width_value/2,direction*length_value-direction.orthogonal()*width_value/2,direction*length_value+direction.orthogonal()*width_value/2])
		draw_colored_polygon(points,tint); tint.a=0.7
		points.append(points[0]); draw_polyline(points,tint,1.5)
	else:
		draw_circle(Vector2.ZERO,radius,tint); tint.a=0.65
		draw_arc(Vector2.ZERO,radius,0,TAU,48,tint,2)

