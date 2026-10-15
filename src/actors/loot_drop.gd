class_name LootDrop
extends Coin
var contents: Array[Dictionary] = []
var _texture: Texture2D
var _pulse = 0.0
var _rarity = 0
var _motion_reduced=false
var _picking_up:=false

func _ready() -> void:
	kind = &"loot"
	_life = 1000000.0
	super._ready()
	add_to_group("expedition_loot")
	z_index=7

func _build_visual() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	refresh_visual()

func refresh_visual() -> void:
	if contents.is_empty() or _sprite == null: return
	var display:Dictionary=contents[0]
	for item in contents:
		if int(item.get("rarity",0))>int(display.get("rarity",0)):display=item
	_rarity=int(display.get("rarity",0))
	var icon = UiFactory.item_icon(display,28)
	_texture = icon.texture
	icon.free()
	_sprite.texture = _texture
	_sprite.scale = Vector2.ONE*28.0/maxf(1.0,maxf(_texture.get_width(),_texture.get_height())) if _texture != null else Vector2.ONE
	queue_redraw()

func _animate(delta: float) -> void:
	var reduced=bool(SaveService.data.get("reduced_motion",false))
	if reduced and _motion_reduced:return
	_motion_reduced=reduced
	if not get_viewport_rect().grow(220).has_point(get_global_transform_with_canvas().origin):return
	_pulse += delta if not reduced else 0.0
	queue_redraw()

func _draw() -> void:
	if contents.is_empty(): return
	var color = ItemDB.rarity_color(_rarity)
	var height=92.0+_rarity*26.0
	var pulse=0.88+sin(_pulse*2.0)*0.12
	# Draw tapered light behind the sprite without allocating effect nodes.
	for strip in 12:
		var t=float(strip)/12.0
		var spread=7.0+_rarity*1.2+t*9.0
		var c=color;c.a=(1.0-t)*0.28*pulse
		draw_rect(Rect2(-spread,-height*(t+1.0/12.0),spread*2.0,height/12.0),c)
		c.a=(1.0-t)*0.78*pulse
		draw_rect(Rect2(-1.5,-height*(t+1.0/12.0),3.0,height/12.0),c)
	for i in 3:
		var t=fposmod(_pulse*0.25+i*0.33,1.0)
		var c=color;c.a=sin(t*PI)*0.8
		draw_circle(Vector2(sin(i*2.1+_pulse)*8.0,-height*t),1.4,c)
	if contents.size()>1:
		draw_string(ThemeDB.fallback_font,Vector2(7,-9),str(contents.size()),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)

func _update_magnet(delta: float) -> bool:
	if flight_left > 0.0 or landing_wait > 0.0: return false
	if _collected or _picking_up or not is_instance_valid(player) or player.is_queued_for_deletion():
		_set_world_collision(true);return false
	var offset:=player.global_position-global_position
	if offset.length()>=MAGNET_RANGE:
		_set_world_collision(true);return false
	var available:=false
	for item in contents:
		if GameState.can_add_item(item):available=true;break
	if not available:
		_set_world_collision(true);return false
	# Attracted loot follows the player through props, just like coins.
	_set_world_collision(false)
	if offset.length()<PICKUP_RANGE:
		try_pickup(true)
		return _collected
	var speed:=minf(420.0,offset.length()/maxf(delta,.001))
	velocity=velocity.lerp(offset.normalized()*speed,1-exp(-10*delta))
	return true

func _physics_process(delta: float) -> void:
	_life = 1000000.0
	if level != null and global_position.y > level.kill_floor_y()-10:
		global_position = level.player_spawn+Vector2(0,-20)
		velocity = Vector2.ZERO
	super._physics_process(delta)

func try_pickup(automatic:=false) -> bool:
	if _collected or _picking_up or flight_left > 0.0 or landing_wait > 0.0 or not is_instance_valid(player) or global_position.distance_to(player.global_position)>85: return false
	_picking_up=true
	var acquired = false
	var index:=0
	while index<contents.size():
		var item: Dictionary = contents[index]
		if not GameState.add_item(item):index+=1;continue
		contents.remove_at(index)
		acquired = true
	if contents.is_empty():
		_collected = true
		queue_free()
	else:
		refresh_visual()
		if not acquired and not automatic: Effects.text(get_parent(),global_position+Vector2(0,-32),"行囊已满 · 物资留在原地",Palette.UI_ACCENT,16)
	if acquired: AudioManager.play(&"coin",-6)
	if acquired:Outpost.request_checkpoint()
	_picking_up=false
	return true

func record() -> Dictionary:
	return {"at":[global_position.x,global_position.y],"velocity":[velocity.x,velocity.y],"items":contents.map(func(i:Dictionary)->Dictionary:return ExpeditionData.pack(i))}
