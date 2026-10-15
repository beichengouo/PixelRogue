class_name RoomSceneOcclusion
extends RefCounted
## Use each living unit's current painted bounds, including large animated models.
var entries:Array[Dictionary]=[]
static var _frame_bounds:Dictionary={}
func clear()->void:
	entries.clear()
	if _frame_bounds.size()>4096:
		for key in _frame_bounds.keys():
			if _frame_bounds[key].texture.get_ref()==null:_frame_bounds.erase(key)
func register_sprite(sprite:Sprite2D,foot_world_y:float)->void:
	if sprite.texture==null:return
	var image:=TexturePixels.image(sprite.texture)
	if image!=null and MobileControls.enabled():
		if image.get_width()>256 or image.get_height()>256:image.resize(maxi(1,image.get_width()/2),maxi(1,image.get_height()/2),Image.INTERPOLATE_BILINEAR)
		image.convert(Image.FORMAT_LA8)
	entries.append({"sprite":weakref(sprite),"image":image,"foot_y":foot_world_y})
func update_for_units(units:Array,dt:float)->void:
	var bodies:Array[Dictionary]=[]
	for unit:Node2D in units:
		bodies.append({"foot_y":unit.global_position.y,"rect":unit_visual_rect(unit)})
	_update(bodies,dt)

func update_for_points(points:Array,dt:float)->void:
	# Compatibility for callers with no actor model (editor and older tests).
	var bodies:Array[Dictionary]=[]
	for point:Vector2 in points:
		bodies.append({"foot_y":point.y,"rect":Rect2(point+Vector2(-6,-24),Vector2(12,21))})
	_update(bodies,dt)

func unit_visual_rect(unit:Node2D)->Rect2:
	var visual:Variant=unit.get("visual")
	if not visual is Sprite2D and not visual is AnimatedSprite2D:visual=unit.get("_sprite")
	var texture:Texture2D
	if visual is AnimatedSprite2D and visual.sprite_frames!=null:
		texture=visual.sprite_frames.get_frame_texture(visual.animation,visual.frame)
	elif visual is Sprite2D:texture=visual.texture
	if texture!=null and visual.is_visible_in_tree():
		var size:=texture.get_size()
		var rect:=_painted_bounds(texture)
		if visual.flip_h:rect.position.x=size.x-rect.end.x
		if visual.flip_v:rect.position.y=size.y-rect.end.y
		rect.position+=visual.offset-(size*.5 if visual.centered else Vector2.ZERO)
		return _world_rect(visual,rect)
	var body:Variant=unit.get("body_size")
	var size:Vector2=body if body is Vector2 else Vector2.ONE*maxf(24,float(unit.get_meta("unit_radius",12))*2)
	return Rect2(unit.global_position+Vector2(-size.x*.5,-size.y),size)

func _painted_bounds(texture:Texture2D)->Rect2:
	var id:=texture.get_instance_id()
	if _frame_bounds.has(id) and _frame_bounds[id].texture.get_ref()==texture:return _frame_bounds[id].rect
	var image:=TexturePixels.image(texture)
	var rect:=Rect2(image.get_used_rect()) if image!=null else Rect2(Vector2.ZERO,texture.get_size())
	_frame_bounds[id]={"texture":weakref(texture),"rect":rect}
	return rect

func _world_rect(sprite:Node2D,local:Rect2)->Rect2:
	var rect:=Rect2(sprite.to_global(local.position),Vector2.ZERO)
	for corner in [Vector2(local.end.x,local.position.y),local.end,Vector2(local.position.x,local.end.y)]:
		rect=rect.expand(sprite.to_global(corner))
	return rect

func _update(bodies:Array[Dictionary],dt:float)->void:
	for entry in entries:
		var sprite:=entry.sprite.get_ref() as Sprite2D
		if not is_instance_valid(sprite) or sprite.is_queued_for_deletion():continue
		var painted:=_world_rect(sprite,sprite.get_rect())
		var occluded:=false
		for body in bodies:
			# Match Y-sort: scenery only covers units behind its floor anchor.
			if float(body.foot_y)>=float(entry.foot_y)-2:continue
			var overlap:Rect2=painted.intersection(body.rect)
			if not overlap.has_area():continue
			var columns:=clampi(ceili(overlap.size.x/3.0),1,48)
			var rows:=clampi(ceili(overlap.size.y/3.0),1,48)
			for y in rows:
				for x in columns:
					var point:=overlap.position+overlap.size*Vector2((x+.5)/columns,(y+.5)/rows)
					if _opaque_at(sprite,entry.image,point):occluded=true;break
				if occluded:break
			if occluded:break
		sprite.modulate.a=move_toward(sprite.modulate.a,0.4 if occluded else 1.0,maxf(0,dt)*4.0)
func _opaque_at(sprite:Sprite2D,image:Image,world_point:Vector2)->bool:
	if image==null:return false
	var local:=sprite.to_local(world_point)-sprite.offset
	if sprite.centered:local+=sprite.texture.get_size()*.5
	if sprite.flip_h:local.x=sprite.texture.get_width()-local.x-1
	if sprite.flip_v:local.y=sprite.texture.get_height()-local.y-1
	local*=Vector2(image.get_size())/sprite.texture.get_size()
	var pixel:=Vector2i(local.floor())
	if pixel.x<0 or pixel.y<0 or pixel.x>=image.get_width() or pixel.y>=image.get_height():return false
	return image.get_pixelv(pixel).a>0.2
