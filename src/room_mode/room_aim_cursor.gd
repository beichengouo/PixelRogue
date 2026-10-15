class_name RoomAimCursor
extends Node2D
const IMAGE:="res://assets/ui/aim_cursor_v01.png"
static var _texture:Texture2D
static var _owner:WeakRef
var actor:RoomPlayer
var aiming:=false

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	show_behind_parent=true
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=ink
	if _texture==null:_texture=load(IMAGE) as Texture2D
	_process(0)

func should_aim()->bool:
	return is_instance_valid(actor) and actor.is_visible_in_tree() and actor.hp>0 and actor.extraction_pose==&"" and RoomInput.using_mouse() and not UIFlow.has_screen() and not get_tree().paused and not TransitionLayer.busy

func _process(_dt:float)->void:
	var wanted:=should_aim()
	visible=wanted and bool(SaveService.data.get("mouse_aim_guide",true)) and (MobileControls.attacking() if MobileControls.enabled() else get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position()))
	if visible:queue_redraw()
	if wanted:
		if aiming and _owner!=null and _owner.get_ref()==self:return
		aiming=true;_owner=weakref(self)
		if not MobileControls.enabled() and DisplayServer.get_name()!="headless":Input.set_custom_mouse_cursor(_texture,Input.CURSOR_ARROW,_texture.get_size()*.5)
	elif aiming:_release()

func _release()->void:
	aiming=false
	if _owner!=null and _owner.get_ref()==self:
		_owner=null
		if not MobileControls.enabled() and DisplayServer.get_name()!="headless":Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)

func _exit_tree()->void:_release()

func model_bounds()->Rect2:
	# Clip outside the complete current sprite cell, including held weapons.
	var sprite:=actor._sprite
	var size:Vector2=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame).get_size()
	var rect:=Rect2(sprite.offset-(size*.5 if sprite.centered else Vector2.ZERO),size)
	var corners:=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	var result:=Rect2(to_local(actor._sprite.to_global(corners[0])),Vector2.ZERO)
	for corner in corners:result=result.expand(to_local(actor._sprite.to_global(corner)))
	return result

func guide_segment(target:Vector2)->PackedVector2Array:
	var distance:=target.length()
	if distance<1:return PackedVector2Array()
	var direction:=target/distance;var scale_value:=maxf(.01,absf(get_global_transform_with_canvas().get_scale().x))
	var rect:=model_bounds().grow(4.0/scale_value);var exit:=INF
	if absf(direction.x)>.00001:exit=minf(exit,(rect.end.x if direction.x>0 else rect.position.x)/direction.x)
	if absf(direction.y)>.00001:exit=minf(exit,(rect.end.y if direction.y>0 else rect.position.y)/direction.y)
	var start:=maxf(0,exit)+3.0/scale_value;var end:=distance-16.0/scale_value
	if end<=start:return PackedVector2Array()
	return PackedVector2Array([direction*start,direction*end])

func _draw()->void:
	if not aiming or not is_instance_valid(actor):return
	var target:=MobileControls.pointer_world(actor) if MobileControls.enabled() else actor.get_global_mouse_position()
	var segment:=guide_segment(to_local(target))
	if segment.size()!=2:return
	var scale_value:=maxf(.01,absf(get_global_transform_with_canvas().get_scale().x))
	var direction:Vector2=(segment[1]-segment[0]).normalized();var length:float=segment[0].distance_to(segment[1])
	var dash:=12.0/scale_value;var gap:=8.0/scale_value;var progress:=0.0
	while progress<length:
		var start:Vector2=segment[0]+direction*progress;var end:Vector2=segment[0]+direction*minf(length,progress+dash)
		draw_line(start,end,Color(0.12,0.01,0.03,.9),7.0/scale_value,true)
		draw_line(start,end,Color("ff414a"),5.0/scale_value,true)
		progress+=dash+gap
	if MobileControls.enabled():draw_texture_rect(_texture,Rect2(to_local(target)-Vector2(20,20)/scale_value,Vector2(40,40)/scale_value),false)
