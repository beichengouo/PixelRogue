class_name RoomShadowChaser
extends CharacterBody2D
## A room challenge pursuer, never an enemy, summon, kill or loot source.
var controller:SpecialRoomController
var room:RoomLevel
var hp:=1.0
var visual:AnimatedSprite2D
var _direction:=Vector2.DOWN
var _route_left:=0.0
var _motion:=Vector2.ZERO
var flank_index:=0
var _stalled:=0.0
var _last_position:=Vector2.INF
const BODY_RADIUS:=12.0 # Reuse the player's graph prewarmed during room loading.
const ROUTE_RADIUS:=16.0 # Circumscribes the real 22x22 square, including its corners.
const CONTACT_SECONDS:=1.0

func dissolve()->void:
	set_physics_process(false)
	if ComicMotion.reduced():queue_free();return
	var fade:=create_tween();fade.tween_property(visual,"modulate:a",0.0,.35);fade.tween_callback(queue_free)

func _ready()->void:
	collision_layer=0;collision_mask=Layers.WORLD|Layers.DEEP_WATER
	motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(22,22);collider.shape=shape;add_child(collider)
	visual=AnimatedSprite2D.new();visual.sprite_frames=RoomHeroArt.make_frames();visual.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	visual.material=RedrawnHeroArt.material();visual.modulate=Color(0.015,0.018,0.025,.94)
	add_child(visual);visual.frame_changed.connect(func()->void:RoomHeroArt.align(visual));visual.play(&"idle_s");RoomHeroArt.align(visual)
	# Share scenery occlusion without occupying the physical crowd registry.
	add_to_group("room_units");z_index=1

func _physics_process(dt:float)->void:
	if not is_instance_valid(controller) or not controller.chase_running():
		velocity=Vector2.ZERO;return
	var actor:RoomPlayer=controller.main.player
	var data:Dictionary=controller.state.chase
	if _last_position.is_finite() and _motion.length_squared()>.1:
		_stalled=_stalled+dt if global_position.distance_to(_last_position)<.2 else 0.0
	_last_position=global_position
	_route_left-=dt
	if _route_left<=0 or _stalled>.3:
		_route_left=.12
		var goal:=pursuit_goal()
		if room.segment_clear(global_position,goal,BODY_RADIUS,false) and not test_move(global_transform,goal-global_position):
			_motion=(goal-global_position).normalized()
		else:
			_motion=room.path_direction(global_position,goal,ROUTE_RADIUS,false)
			if _motion.is_zero_approx():_motion=room.path_direction(global_position,goal,BODY_RADIUS,false)
		# Reject a route that is clear for the graph but blocked for the live body.
		if _stalled>.3 or (not _motion.is_zero_approx() and test_move(global_transform,_motion*18)):
			_motion=_recovery_direction(goal)
	velocity=_motion*actor.stats.get_value(&"move_speed")*actor.movement_slow_multiplier()
	move_and_slide();data["at" if flank_index==0 else "second_at"]=[global_position.x,global_position.y]
	if not velocity.is_zero_approx():_direction=velocity.normalized()
	var direction_name:=RoomHeroArt.direction_name(_direction)
	var action:="walk" if velocity.length_squared()>1 else "idle"
	visual.flip_h=RoomHeroArt.flip_for(action,direction_name);visual.play(StringName(action+"_"+direction_name));RoomHeroArt.align(visual)
	# One contact attempt per second; normal shields and invulnerability apply.
	# The 10% value does not inherit enemy/difficulty/room-pressure multipliers.
	if float(data.contact)<=0 and global_position.distance_squared_to(actor.global_position)<=24*24:
		data.contact=CONTACT_SECONDS;actor.take_damage(actor.max_hp*.1,global_position,self)

func pursuit_goal()->Vector2:
	var actor:RoomPlayer=controller.main.player
	var point:=actor.global_position
	if controller.active_shadows().size()>1 and global_position.distance_to(point)>90:
		var forward:=actor.velocity.normalized()
		if forward.is_zero_approx():
			var first:=controller.shadow
			forward=(point-first.global_position).normalized() if is_instance_valid(first) else Vector2.UP
		if forward.is_zero_approx():forward=Vector2.UP
		point+=forward*42+forward.orthogonal()*(80.0 if flank_index==0 else -80.0)
	return room.nearest_clear(point,BODY_RADIUS)

func _recovery_direction(goal:Vector2)->Vector2:
	var toward:=(goal-global_position).normalized()
	var best:=-INF;var result:=Vector2.ZERO
	for index in 16:
		var direction:=toward.rotated(index*TAU/16)
		var point:=global_position+direction*24
		if not room.segment_clear(global_position,point,BODY_RADIUS,false) or test_move(global_transform,direction*24):continue
		var onward:=room.path_direction(point,goal,ROUTE_RADIUS,false)
		if onward.is_zero_approx() and point.distance_to(goal)>24:continue
		var score:=direction.dot(toward)*20+onward.dot(direction)*8
		if score>best:best=score;result=direction
	return result
