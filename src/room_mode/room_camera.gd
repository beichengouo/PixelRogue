class_name RoomCamera
extends CameraRig
const FRAME:=Rect2(-114,-90,912,576)
const VISIBLE_ROOM_FRACTION:=0.5
var room:RoomLevel
var view_reference_size:=Vector2.ZERO
func setup(_bounds:Rect2)->void:
	global_position=Vector2(342,198)
	process_priority=100
	position_smoothing_enabled=false
	# Clamp against the rendered background below, not gameplay collision walls.
	limit_left=-100000;limit_top=-100000;limit_right=100000;limit_bottom=100000
func snap_to_target()->void:
	_follow_position=_desired_position()
	global_position=_follow_position;offset=Vector2.ZERO;shake_amount=0;force_update_scroll()
func _background_frame()->Rect2:
	if not is_instance_valid(room):return FRAME
	if is_instance_valid(room.illustration) and room.illustration.active():
		return room.illustration.camera_bounds()
	return room.global_transform*room.visual_frame()
func _clamp_to_background(at:Vector2,frame:Rect2,view:Vector2,factor:float)->Vector2:
	var half_view:=view*.5/factor
	var center:=at
	var low:=frame.position+half_view
	var high:=frame.end-half_view
	center.x=clampf(center.x,low.x,maxf(low.x,high.x))
	center.y=clampf(center.y,low.y,maxf(low.y,high.y))
	return center
func _desired_position()->Vector2:
	var view:=get_viewport_rect().size
	if is_instance_valid(room):room.fit_to_view(view)
	var frame:=_background_frame()
	var reference:=view_reference_size if view_reference_size.x>0 and view_reference_size.y>0 else frame.size
	var factor:=minf(view.x/maxf(1,reference.x*VISIBLE_ROOM_FRACTION),maxf(1,view.y)/maxf(1,reference.y*VISIBLE_ROOM_FRACTION))
	# Very wide or tall windows still need the whole battle viewport covered.
	factor=maxf(factor,maxf(view.x/maxf(1,frame.size.x),maxf(1,view.y)/maxf(1,frame.size.y)))
	zoom=Vector2.ONE*factor
	var center:=target.global_position if is_instance_valid(target) else frame.get_center()
	# The HUD is transparent; the entire window is now a battle viewport.
	return _clamp_to_background(center,frame,view,factor)
func _process(dt:float)->void:
	if not is_instance_valid(target):return
	_follow_position=_desired_position();global_position=_follow_position
	shake_amount=maxf(0,shake_amount-dt*45);_shake_time+=dt*35
	var shake:=Vector2(sin(_shake_time*1.7),sin(_shake_time*2.3))*shake_amount*float(SaveService.data.get("screen_shake_strength",1))
	offset=_clamp_to_background(_follow_position+shake,_background_frame(),get_viewport_rect().size,zoom.x)-_follow_position
	# Camera2D's internal scroll can run before this late follow callback.
	# Apply the current transform now so fast movement has no one-frame lag.
	force_update_scroll()
