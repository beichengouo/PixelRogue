class_name CampResident
extends CharacterBody2D
var world:Node
var room:RoomLevel
var hp:=1.0
var resident_id := ""
var home := Vector2.ZERO
var interacting := false
var _sprite:AnimatedSprite2D
var _badge:Sprite2D
var _rng:=RandomNumberGenerator.new()
var _goal:=Vector2.ZERO
var _rest_left:=1.0
var _walk_left:=0.0
var _nav_left:=0.0
var _status_left:=0.0
var _travel:=Vector2.ZERO
var _facing:=Vector2(1,1)
func _ready()->void:
	name="CampResident_"+resident_id;add_to_group("camp_residents")
	room=world.get("level");add_to_group("room_units")
	collision_layer=0;collision_mask=Layers.WORLD|Layers.DEEP_WATER;motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=9;shape.shape=circle;add_child(shape)
	_rng.seed=int(get_instance_id())^20261013;_rest_left=_rng.randf_range(1,3)
	_sprite=AnimatedSprite2D.new();_sprite.sprite_frames=CampResidentArt.frames(resident_id);_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;CampResidentArt.align(_sprite,resident_id);add_child(_sprite);_sprite.play(&"idle_south")
	_badge=Sprite2D.new();_badge.position=Vector2(0,-30);_badge.scale=Vector2.ONE*(14.0/96);_badge.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;_badge.z_index=8;add_child(_badge);refresh_badge()
	Outpost.changed.connect(refresh_badge)
func refresh_badge()->void:
	if _badge==null:return
	var progress:=CampResidents.progress(resident_id)
	_badge.visible=progress!="none"
	if _badge.visible:_badge.texture=load(CampResidents.ROOT+"quest_"+progress+".png") as Texture2D
func _physics_process(dt:float)->void:
	if not is_instance_valid(world) or bool(world.get("_departing")):return
	_status_left-=dt
	if _status_left<=0:_status_left=.5;refresh_badge()
	if interacting:velocity=Vector2.ZERO;_pose(&"talk");return
	if _rest_left>0:
		_rest_left-=dt;velocity=Vector2.ZERO;_pose(&"rest")
		if _rest_left<=0:_choose_goal()
		return
	_walk_left-=dt;_nav_left-=dt
	if position.distance_to(_goal)<16 or _walk_left<=0:
		_rest_left=_rng.randf_range(2.5,6);velocity=Vector2.ZERO;_pose(&"rest");return
	var room:RoomLevel=world.get("level")
	if _nav_left<=0:
		_nav_left=.25;_travel=room.path_direction(position,_goal,9,false)
	velocity=_travel*48
	if not velocity.is_zero_approx():_facing=velocity.normalized()
	var previous:=position;move_and_slide()
	if previous.distance_squared_to(position)<.05:_walk_left=minf(_walk_left,.6)
	_pose(StringName("walk_north" if _facing.y<-.1 else "walk_south") if velocity.length()>1 else StringName("idle_north" if _facing.y<-.1 else "idle_south"))
func _choose_goal()->void:
	var room:RoomLevel=world.get("level");_goal=position
	for trial in 24:
		var point:Vector2=home+Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(40,155)
		if not room.bounds().grow(-32).has_point(point) or not room.body_clear(point,9):continue
		var near_gate:=false
		for direction:Vector2i in RoomGraph.DIRECTIONS:
			if point.distance_to(room.door_point(direction))<110:near_gate=true
		if near_gate or room.path_direction(position,point,9,false).is_zero_approx():continue
		_goal=point;break
	_walk_left=_rng.randf_range(3,7);_nav_left=0
func _pose(action:StringName)->void:
	_sprite.flip_h=_facing.x<0
	if _sprite.animation!=action:_sprite.play(action)
func _draw()->void:
	draw_set_transform(Vector2(0,12),0,Vector2(1,.3));draw_circle(Vector2.ZERO,12,Color(0,0,0,.2));draw_set_transform(Vector2.ZERO)
