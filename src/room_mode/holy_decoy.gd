class_name HolyDecoy
extends IlyuaDecoy
var holy:HolyRuntime
var empowered:=false
var fire_clock:=.5
func _ready()->void:
	add_to_group("ilyua_decoys");add_to_group("holy_decoys");collision_layer=Layers.PLAYER;collision_mask=0
	var collider:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=10;collider.shape=circle;add_child(collider)
	var frames:=RedrawnHeroArt.frames(&"sylphiette");var factor:=32.0/float(frames.get_meta("core_height",64));var sprite:=Sprite2D.new();sprite.texture=frames.get_frame_texture(&"idle_s",0);sprite.scale=Vector2.ONE*factor;sprite.position.y=14-32*factor;sprite.modulate=Color(1,.94,.75,.45);add_child(sprite)
func _physics_process(delta:float)->void:
	remaining-=delta;fire_clock-=delta
	if fire_clock<=0 and is_instance_valid(holy):
		fire_clock+=1;var targets:=holy.targets(global_position,216,1)
		if not targets.is_empty():holy.feather_at(global_position,targets[0],.18,1)
	if remaining<=0:expire()
func expire(_killed:=false)->void:
	if exploded:return
	exploded=true;hp=0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is EnemyBase and enemy.aggro==self:enemy.aggro=null;enemy._aggro_timer=0;enemy.reset_path()
	if empowered and is_instance_valid(holy):
		for target in holy.targets(global_position,216,3):holy.feather_at(global_position,target,.22,1)
	HolyFX.spawn(get_parent(),global_position,"cloud",28,.3);queue_free()
