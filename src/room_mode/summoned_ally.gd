class_name SummonedAlly
extends RoomAlly
var is_contract:=true
var guardian:=false
var art_variant:=""
var _lantern_dodge_left:=0.0
var _lantern_dodge_direction:=Vector2.ZERO
var _appearance_duration:=0.334
var remaining:=22.0
var total_duration:=22.0
var attack_ratio:=0.55
var hp_ratio_base:=0.45
var speed_base:=160.0
var contract_epoch:=0
var rally_time:=0.0
var rally_attack:=0.35
var rally_haste:=0.3
var monster_base_attack:=0.0
var monster_base_hp:=0.0
var roots_cooldown:=2.4
var burst_cooldown:=5.0
var guardian_windup:=0.0
var guardian_spell:=""
var guardian_target:=Vector2.ZERO
var guardian_room_id:=""
var guardian_facing:=0
func body_radius()->float:return 18.0 if guardian else 12.0
func _ready()->void:
	super._ready();SummonRules.ready(self)
func _physics_process(dt:float)->void:
	if not SummonRules.tick(self,dt):return
	_lantern_dodge_left=maxf(0,_lantern_dodge_left-dt)
	if guardian and _tick_guardian(dt):return
	super._physics_process(dt)
	if _appearance_left>0 and _sprite.sprite_frames.has_animation(&"spawn"):
		_appearance_left=maxf(0,_appearance_left-dt)
		_sprite.play(&"spawn");_sprite.pause()
		_sprite.frame=clampi(int((1-_appearance_left/_appearance_duration)*_sprite.sprite_frames.get_frame_count(&"spawn")),0,_sprite.sprite_frames.get_frame_count(&"spawn")-1)
		if guardian:_align_guardian(_sprite);_sprite_origin=_sprite.position
func _play_pose(pose:StringName,facing_direction:Vector2)->void:
	if not guardian:
		super._play_pose(pose,facing_direction)
		if not art_variant.is_empty():SpectralCompanionArt.align(_sprite);_sprite_origin=_sprite.position
		elif enemy_kind==&"walker":SmallSpiritArt.align(_sprite);_sprite_origin=_sprite.position
		return
	if pose==&"walk" and velocity.length_squared()>100:facing_direction=velocity
	if facing_direction.length_squared()>.0025:
		guardian_facing=posmod(roundi((facing_direction.angle()-PI*.5)/(PI*.25)),8)
	var directional:=StringName("%s_d%d"%[pose,guardian_facing])
	if not _sprite.sprite_frames.has_animation(directional):directional=pose
	_sprite.flip_h=guardian_facing in [5,6,7]
	if _sprite.animation!=directional:_sprite.play(directional)
	elif not _sprite.is_playing():_sprite.play()
	_align_guardian(_sprite);_sprite_origin=_sprite.position
func _align_guardian(sprite:AnimatedSprite2D)->void:
	var frame:=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	var geometry:=RoomCreatureArt.guardian_geometry(frame,sprite.animation)
	sprite.scale=Vector2.ONE*112.0/geometry.x
	var foot_x:float=float(frame.get_meta("guardian_foot_x",frame.get_width()*.5))
	var correction_x:float=(frame.get_width()*.5-foot_x)*sprite.scale.x
	sprite.position=Vector2(-correction_x if sprite.flip_h else correction_x,14.0-(geometry.y-frame.get_height()*.5)*sprite.scale.y)
func _sync_guardian_anchor()->void:
	_align_guardian(_sprite);_sprite_origin=_sprite.position
func _refresh_bonus()->void:SummonRules.refresh(self)

func _release_attack(melee:bool)->void:
	if enemy_kind in [&"walker",&"guard",&"treant"]:
		var center:=global_position+attack_direction*20
		var radius:=110.0 if enemy_kind==&"treant" else 76.0
		Effects.slash_arc(_fx(),center,attack_direction.angle(),radius*.82,Color("c5b3ff"),150,4,.25)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy._dead:continue
			var offset:Vector2=enemy.global_position-global_position
			if offset.length()<=radius and attack_direction.dot(offset.normalized())>=.15 and room.sight(global_position,enemy.global_position) and room.segment_clear(global_position,enemy.global_position,body_radius(),is_flying()):
				var before: float = enemy.hp
				enemy.take_damage(attack,false,global_position,self)
				if is_instance_valid(player) and player is RoomPlayer and enemy.hp<before:(player as RoomPlayer).equipment_mechanics.on_ally_hit(enemy,self)
	elif enemy_kind==&"caster":
		var aimed:Variant=attack_target.get_ref() if attack_target!=null else null
		if not is_instance_valid(aimed) or aimed._dead or not room.projectile_clear(global_position,aimed.global_position):return
		var ball:=ContractProjectile.new();ball.room=room;ball.is_friendly=true;ball.art_scale=.8;ball.explosion_radius=80;ball.color=Color("c7a6ff")
		ball.damage_actor=self
		_fx().add_child(ball);ball.setup(global_position+attack_direction*16,attack_direction,attack,330,room,null,Color("c7a6ff"))
	else:super._release_attack(melee)

func _tick_guardian(dt:float)->bool:
	var room_id:=str(room.record.get("id",""))
	if guardian_windup>0 and guardian_room_id!=room_id:guardian_windup=0;guardian_spell=""
	roots_cooldown=maxf(0,roots_cooldown-dt);burst_cooldown=maxf(0,burst_cooldown-dt)
	if guardian_windup>0:
		guardian_windup=maxf(0,guardian_windup-dt);velocity=Vector2.ZERO
		var pose:=StringName("root_cast" if guardian_spell=="roots" else "burst_cast")
		if not _sprite.sprite_frames.has_animation(pose):pose=&"attack"
		_play_pose(pose,attack_direction)
		if guardian_windup<=0:
			SummonRules.guardian_pulse(self,guardian_spell,guardian_target)
			guardian_spell="";attack_clock=-1
		queue_redraw();return true
	var target:=_choose_target()
	if target==null or not room.sight(global_position,target.global_position) or global_position.distance_to(target.global_position)>260:return false
	if roots_cooldown<=0:guardian_spell="roots";roots_cooldown=7.0;guardian_windup=.55
	elif burst_cooldown<=0:guardian_spell="burst";burst_cooldown=10.0;guardian_windup=.7
	else:return false
	guardian_room_id=room_id;guardian_target=target.global_position;attack_direction=(guardian_target-global_position).normalized();queue_redraw()
	return true
func _die()->void:SummonRules.dismiss(self)
func _draw()->void:
	if guardian:
		# The large guardian keeps its life bar above the head, outside the sprite.
		var head_y:=14.0-112.0
		draw_colored_polygon(PackedVector2Array([Vector2(0,head_y-12),Vector2(-4,head_y-18),Vector2(4,head_y-18)]),Color("72db8b"))
		draw_rect(Rect2(-21,head_y-8,42,4),Color("22132d"))
		draw_rect(Rect2(-20,head_y-7,40*clampf(hp/maxf(1,max_hp),0,1),2),Palette.ALLY_HEALTH)
	else:super._draw()
	SummonRules.draw_marker(self)
	if guardian_windup>0:
		var at:=to_local(guardian_target)
		var radius:=90.0 if guardian_spell=="roots" else 108.0
		draw_circle(at,radius,Color(.52,.25,.8,.09))
		draw_arc(at,radius,0,TAU,48,Color(.72,.44,1,.65),1.5)
func follow_goal()->Vector2:return super.follow_goal()
func _choose_target()->EnemyBase:return super._choose_target()

var _appearance_left:=0.334
func _build_visual()->void:
	var frames:=RoomCreatureArt.frames("spirit_tree_v2" if guardian and ResourceLoader.exists("res://assets/room_mode/creatures/spirit_tree_v2.png") else RoomCreatureArt.spirit_id(enemy_kind))
	if not guardian:
		if art_variant.is_empty():art_variant="ghost_lantern" if enemy_kind==&"caster" else ("gate_guardian" if enemy_kind==&"guard" else "")
		if not art_variant.is_empty():frames=SpectralCompanionArt.frames(art_variant)
		elif enemy_kind==&"walker":frames=SmallSpiritArt.frames()
	if frames==null:
		super._build_visual();return
	_sprite=AnimatedSprite2D.new();_sprite.sprite_frames=frames;_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale=Vector2.ONE*(112.0/frames.get_frame_texture(&"idle",0).get_height() if guardian else .62);_sprite.position.y=-12;_sprite_origin=_sprite.position
	if not guardian and not art_variant.is_empty():
		SpectralCompanionArt.align(_sprite);_sprite_origin=_sprite.position
	elif not guardian and enemy_kind==&"walker":
		SmallSpiritArt.align(_sprite);_sprite_origin=_sprite.position
	if guardian and frames.has_animation(&"root_cast"):
		var idle_frame:=frames.get_frame_texture(&"idle",0) as AtlasTexture
		if idle_frame!=null and idle_frame.atlas.resource_path=="res://assets/next_revision/creatures/amethyst_guardian.png":
			_sprite.scale=Vector2.ONE*112.0/RoomCreatureArt.GUARDIAN_BODY_HEIGHT
			_sprite.position.y=14.0-(RoomCreatureArt.GUARDIAN_FOOT_Y-idle_frame.get_height()*.5)*_sprite.scale.y
		else:_sprite.position.y=-frames.get_frame_texture(&"idle",0).get_height()*.4*_sprite.scale.y
		_sprite_origin=_sprite.position
	add_child(_sprite)
	if guardian:_sprite.frame_changed.connect(_sync_guardian_anchor)
	_appearance_duration=.75 if art_variant=="parade_guardian" else .5
	_appearance_left=_appearance_duration
	_sprite.play(&"spawn")
	if guardian:_align_guardian(_sprite);_sprite_origin=_sprite.position
func _show_departure()->void:
	if _sprite==null or not _sprite.sprite_frames.has_animation(&"death"):return
	var image:=AnimatedSprite2D.new();image.sprite_frames=_sprite.sprite_frames;image.scale=_sprite.scale;image.flip_h=_sprite.flip_h
	image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;image.self_modulate=_sprite.self_modulate
	image.play(&"death")
	if guardian:_align_guardian(image)
	else:image.position=_sprite.position
	image.position+=global_position
	_fx().add_child(image);image.animation_finished.connect(image.queue_free,CONNECT_ONE_SHOT)

func combat_movement(target:EnemyBase,current:Vector2)->Vector2:
	if guardian or enemy_kind!=&"caster":return current
	var speed:=move_speed*movement_slow_multiplier()
	if _lantern_dodge_left>0 and _lantern_path_clear(_lantern_dodge_direction):return _lantern_dodge_direction*speed
	var threat:RoomProjectile;var shortest:=.50
	for node in get_tree().get_nodes_in_group("room_projectiles"):
		var ball:=node as RoomProjectile
		if ball==null or ball.is_friendly or ball.is_queued_for_deletion() or ball.room!=room:continue
		var relative:=global_position-ball.global_position
		if relative.length_squared()>260*260:continue
		var incoming:Vector2=ball.direction*ball.speed
		if incoming.length_squared()<1:continue
		var time:=relative.dot(incoming)/incoming.length_squared()
		if time<0 or time>shortest:continue
		if (relative-incoming*time).length()>body_radius()+ball.hit_radius+14:continue
		shortest=time;threat=ball
	if threat!=null:
		var perpendicular:=Vector2(-threat.direction.y,threat.direction.x)
		if perpendicular.dot(global_position-threat.global_position)<0:perpendicular=-perpendicular
		for direction:Vector2 in [perpendicular,-perpendicular,-threat.direction]:
			if _lantern_path_clear(direction):_lantern_dodge_direction=direction;_lantern_dodge_left=.22;return direction*speed
	if is_instance_valid(target) and global_position.distance_to(target.global_position)<180:
		var retreat:=_retreat_direction(target.global_position)
		if not retreat.is_zero_approx():return retreat*speed
	return current
func _lantern_path_clear(direction:Vector2)->bool:
	var destination:=global_position+direction*42
	return room.segment_clear(global_position,destination,body_radius(),is_flying()) and room.unit_position_clear(destination,body_radius(),self)
