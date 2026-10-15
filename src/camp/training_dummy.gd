class_name TrainingDummy
extends RoomEnemy
var meter:=CampDamageMeter.new()
var anchor:=Vector2.ZERO
var _damage_label:Label
func plays_entry_animation()->bool:return false
func _ready()->void:
	anchor=position
	training_target=true;kind=&"training_dummy";display_name="回廊稻草人";base_hp=1000000000.0;base_damage=0;base_speed=0;base_coins=0;body_size=Vector2(24,32)
	super._ready()
	if is_instance_valid(contact_area):contact_area.monitoring=false;contact_area.monitorable=false
	if is_instance_valid(visual):visual.queue_free()
	var sprite:=AnimatedSprite2D.new();var frames:=SpriteFrames.new()
	var texture:=load("res://assets/camp_v01/training_dummy.png") as Texture2D
	for row in 2:
		var animation:StringName=&"idle" if row==0 else &"hurt"
		if not frames.has_animation(animation):frames.add_animation(animation)
		frames.set_animation_speed(animation,6 if row==0 else 14);frames.set_animation_loop(animation,row==0)
		for column in 4:
			var cell:=AtlasTexture.new();cell.atlas=texture;cell.region=Rect2(column*96,row*96,96,96);cell.filter_clip=true;frames.add_frame(animation,cell)
	sprite.sprite_frames=frames;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.scale=Vector2.ONE*.5;sprite.position=Vector2(0,-6);add_child(sprite);visual=sprite;sprite.play(&"idle");_pixel_enemy_art=false
	damage_applied.connect(func(_enemy:EnemyBase,amount:float,_source:Node,type:StringName)->void:meter.record(amount,type))
	_damage_label=Label.new();_damage_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;_damage_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_damage_label.size=Vector2(160,60);_damage_label.add_theme_font_size_override("font_size",12);_damage_label.add_theme_color_override("font_color",Color.WHITE);_damage_label.add_theme_color_override("font_outline_color",Color("15271d"));_damage_label.add_theme_constant_override("outline_size",3);_damage_label.z_index=30;add_child(_damage_label);_damage_label.hide()
func _physics_process(dt:float)->void:
	position=anchor
	meter.advance(dt);_flash=maxf(0,_flash-dt);advance_slow(dt);advance_damage_status(dt);velocity=Vector2.ZERO;room_push=Vector2.ZERO
	if hp<1000000:hp=max_hp
	var sprite:=visual as AnimatedSprite2D
	if _flash<=0 and sprite.animation!=&"idle":sprite.play(&"idle")
	_update_damage_label()
func _update_damage_label()->void:
	if _damage_label==null:return
	_damage_label.visible=meter.total>0 and (meter.running or meter.clock-meter.last_hit<8)
	if not _damage_label.visible:return
	var zoom_value:=1.0;var camera:=get_viewport().get_camera_2d()
	if camera!=null:zoom_value=maxf(.1,camera.zoom.x)
	_damage_label.scale=Vector2.ONE/zoom_value;_damage_label.position=Vector2(-80/zoom_value,-32-60/zoom_value)
	_damage_label.text="DPS %.1f\n累计 %.0f · 峰值 %.0f"%[meter.recent_dps(),meter.total,meter.peak]
func take_damage(amount:float,is_crit:=false,from:=Vector2.ZERO,source:Node=null,_knockback:=true)->void:
	super.take_damage(amount,is_crit,from,source,false)
	(visual as AnimatedSprite2D).play(&"hurt");(visual as AnimatedSprite2D).set_frame_and_progress(0,0)
func _draw()->void:
	draw_set_transform(Vector2(0,10),0,Vector2(1,.35));draw_circle(Vector2.ZERO,13,Color(0,0,0,.22));draw_set_transform(Vector2.ZERO)
func _die()->void:pass

