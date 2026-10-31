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
var patrol:=PackedVector2Array()
var _patrol_index:=0
var _patrol_direction:=1
var _gesture_left:=25.0
var _rest_pose_left:=0.0
var _stalled:=0.0
var _rest_left:=1.0
var _status_left:=0.0
var _facing:=Vector2(1,1)
func _ready()->void:
	name="CampResident_"+resident_id;add_to_group("camp_residents")
	room=world.get("level");add_to_group("room_units")
	collision_layer=0;collision_mask=Layers.WORLD|Layers.DEEP_WATER;motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=9;shape.shape=circle;add_child(shape)
	_rng.seed=resident_id.hash()^20261013;_rest_left=_rng.randf_range(3,8);_gesture_left=_rng.randf_range(25,40)
	_sprite=AnimatedSprite2D.new();_sprite.sprite_frames=CampResidentArt.frames(resident_id);_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;CampResidentArt.align(_sprite,resident_id);add_child(_sprite);_pose(_idle_pose())
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
	_gesture_left=maxf(0,_gesture_left-dt)
	if _rest_left>0:
		_rest_left-=dt;_rest_pose_left=maxf(0,_rest_pose_left-dt);velocity=Vector2.ZERO
		_pose(&"rest" if _rest_pose_left>0 else _idle_pose())
		if _rest_left<=0:_choose_goal()
		return
	if patrol.size()<2:velocity=Vector2.ZERO;_pose(_idle_pose());return
	if position.distance_to(_goal)<1.5:
		_patrol_index+=_patrol_direction
		if _patrol_index>=patrol.size() or _patrol_index<0:
			_patrol_index=clampi(_patrol_index,0,patrol.size()-1);_patrol_direction=-_patrol_direction;_begin_rest();return
		_goal=patrol[_patrol_index]
	if not room.segment_clear(position,_goal,9):_begin_rest();return
	velocity=position.direction_to(_goal)*minf(48,position.distance_to(_goal)/maxf(dt,.001))
	if not velocity.is_zero_approx():_facing=velocity.normalized()
	var previous:=position;move_and_slide()
	_stalled=_stalled+dt if previous.distance_squared_to(position)<.01 else 0.0
	if _stalled>1.0:_begin_rest();return
	_pose(StringName("walk_north" if _facing.y<-.1 else "walk_south"))
func _idle_pose()->StringName:return &"idle_north" if _facing.y<-.1 else &"idle_south"
func _begin_rest()->void:
	_rest_left=_rng.randf_range(12,22);_stalled=0;velocity=Vector2.ZERO
	if _gesture_left<=0:
		_rest_pose_left=3.2;_gesture_left=_rng.randf_range(35,55)
	else:_rest_pose_left=0.0
func _choose_goal()->void:
	if patrol.size()<2:_rest_left=20;return
	# Resume the same road waypoint after a pause, including interrupted conversations.
	_patrol_index=clampi(_patrol_index,0,patrol.size()-1)
	_goal=patrol[_patrol_index]
	_stalled=0
func _pose(action:StringName)->void:
	CampResidentArt.pose(_sprite,resident_id,action,_facing)
func _draw()->void:
	draw_set_transform(Vector2(0,12),0,Vector2(1,.3));draw_circle(Vector2.ZERO,12,Color(0,0,0,.2));draw_set_transform(Vector2.ZERO)
