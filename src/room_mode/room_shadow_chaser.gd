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
const BODY_RADIUS:=12.0 # Reuse the player's graph prewarmed during room loading.
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
	data.contact=maxf(0,float(data.get("contact",0))-dt)
	_route_left-=dt
	if _route_left<=0:
		_route_left=.12;_motion=room.path_direction(global_position,room.nearest_clear(actor.global_position,BODY_RADIUS),BODY_RADIUS,false)
	velocity=_motion*actor.stats.get_value(&"move_speed")*actor.movement_slow_multiplier()
	move_and_slide();data.at=[global_position.x,global_position.y]
	if not velocity.is_zero_approx():_direction=velocity.normalized()
	var direction_name:=RoomHeroArt.direction_name(_direction)
	var action:="walk" if velocity.length_squared()>1 else "idle"
	visual.flip_h=RoomHeroArt.flip_for(action,direction_name);visual.play(StringName(action+"_"+direction_name));RoomHeroArt.align(visual)
	# One contact attempt per second; normal shields and invulnerability apply.
	# The 10% value does not inherit enemy/difficulty/room-pressure multipliers.
	if float(data.contact)<=0 and global_position.distance_squared_to(actor.global_position)<=24*24:
		data.contact=CONTACT_SECONDS;actor.take_damage(actor.max_hp*.1,global_position,self)
