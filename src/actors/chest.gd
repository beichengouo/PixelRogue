class_name Chest
extends CharacterBody2D
## One delivered supply chest. Flight and opening clocks are saved with the room.

const INTERACT_RADIUS := 82.0
const GROUND_OFFSET := Vector2(0.0,12.0)
const DISPLAY_WIDTH:=34.5
const FALL_DURATION := 0.68
const FALL_HEIGHT := 172.0
const OPEN_STEP := 0.15
const OPEN_LINGER := 2.5

var level: Level
var player: Node2D
var in_range := false
var is_open := false
var _landed := true
var _fall_elapsed := 0.0
var _opening := false
var _opening_elapsed := 0.0
var _pending_loot: Dictionary = {}
var _reward_dispatched := false
var _open_timer := 0.0

var _sprite: Sprite2D
var _area: Area2D
var _art_origin := Vector2.ZERO
var _art_state := ""
var _fade_tween: Tween
var _chest_light: PointLight2D

func glow_color()->Color:
	return Color("ffd27f")

func glow_radius()->float:
	return 104.0

func _build_glow()->void:
	_chest_light=LightUtil.make_point_light(glow_color(),0.78,glow_radius())
	_chest_light.name="ChestGlow"
	_chest_light.set_meta("day_glow",true)
	add_child(_chest_light)

func _update_glow()->void:
	if _chest_light==null or _sprite==null:return
	_chest_light.color=glow_color()
	_chest_light.texture_scale=glow_radius()/64.0
	_chest_light.position=_sprite.position
	if _fade_tween!=null and _fade_tween.is_running():return
	# Light follows the delivered chest; the empty chest no longer attracts attention.
	_chest_light.energy=0.22 if is_open and not _opening else 0.78
	_chest_light.enabled=not is_queued_for_deletion()

func required_keys() -> int:
	var wave := maxi(1, GameState.wave)
	if wave >= 25:
		return 3
	if wave >= 10:
		return 2
	return 1

func setup(level_node: Level, player_node: Node2D) -> void:
	level = level_node
	player = player_node

func landing_position()->Vector2:
	return to_global(GROUND_OFFSET)

func begin_delivery() -> void:
	_landed = false
	_fall_elapsed = 0.0
	velocity = Vector2.ZERO
	_update_fall_visual()

func _ready() -> void:
	z_index = 4
	collision_layer = 0
	collision_mask = Layers.WORLD
	_build_body()
	_build_visual()
	_build_glow()
	_build_interact_area()
	add_to_group("chests")
	_update_fall_visual()

func _build_body() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26.0, 22.0)
	shape.shape = rect
	shape.position = Vector2(0.0, 1.0)
	add_child(shape)

func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)
	set_art("closed")

func set_art(state: String) -> void:
	if _sprite == null:
		return
	_art_state = state
	var frame := 0
	if is_open:
		if _opening:
			frame = clampi(int(_opening_elapsed / OPEN_STEP), 0, 3)
		else:
			frame = 4 if _open_timer < 1.0 or state == "empty" else 3
	_sprite.texture = WorldPropArt.chest_texture(frame)
	if _sprite.texture == null:
		return
	_sprite.region_enabled = false
	var scale_factor := DISPLAY_WIDTH / maxf(1.0, float(_sprite.texture.get_width()))
	_sprite.scale = Vector2.ONE * scale_factor
	# The 64px frame touches the floor at source y=60.
	_art_origin = GROUND_OFFSET - Vector2(0.0,(60.0 - 32.0) * scale_factor)
	_update_fall_visual()

func _build_interact_area() -> void:
	_area = Area2D.new()
	_area.collision_layer = Layers.INTERACT
	_area.collision_mask = Layers.PLAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		in_range = _landed
		_refresh_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		in_range = false
		EventBus.interact_prompt_hide.emit()

func _physics_process(delta: float) -> void:
	# A restored mid-flight chest must wait for the room to be visible again.
	if TransitionLayer.busy or UIFlow.has_screen():
		return
	if not _landed:
		_fall_elapsed = minf(FALL_DURATION, _fall_elapsed + delta)
		_update_fall_visual()
		if _fall_elapsed >= FALL_DURATION:
			_land()
		return
	if not is_open:
		return
	if _opening:
		_opening_elapsed = minf(OPEN_STEP * 4.0, _opening_elapsed + delta)
		set_art("open")
		if _opening_elapsed >= OPEN_STEP * 3.0 and not _reward_dispatched:
			_burst_reward()
		if _opening_elapsed >= OPEN_STEP * 4.0 and _reward_dispatched:
			_opening = false
			_open_timer = OPEN_LINGER
			set_art("empty")
		return
	_open_timer -= delta
	if _open_timer < 1.0:
		set_art("empty")
	if _open_timer <= 0.0:
		_fade_out()

func _update_fall_visual() -> void:
	if _sprite != null:
		var progress := clampf(_fall_elapsed / FALL_DURATION, 0.0, 1.0)
		var height := (42.0 if ComicMotion.reduced() else FALL_HEIGHT) * pow(1.0 - progress, 2.0)
		_sprite.position = _art_origin + Vector2(0.0, -height if not _landed else 0.0)
	_update_glow()
	queue_redraw()

func _draw() -> void:
	if _landed or is_open:
		return
	var progress := clampf(_fall_elapsed / FALL_DURATION, 0.0, 1.0)
	var width:=_sprite.texture.get_width()*_sprite.scale.x if _sprite!=null and _sprite.texture!=null else DISPLAY_WIDTH
	var radius := lerpf(width*.18,width*.43,progress)
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(GROUND_OFFSET+Vector2(cos(angle)*radius,sin(angle)*radius*.28))
	draw_colored_polygon(points, Color(0.02, 0.04, 0.07, 0.12 + progress * 0.25))

func _land() -> void:
	_landed = true
	velocity = Vector2.ZERO
	_update_fall_visual()
	AudioManager.play(&"land", -6.0)
	if not ComicMotion.reduced():
		Effects.dust(get_parent(),landing_position(),Palette.TERRAIN_TOP,8)
		EventBus.request_screen_shake.emit(4.0)
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= INTERACT_RADIUS:
		in_range = true
	if in_range:
		_refresh_prompt()
	EventBus.chest_spawned.emit()
	Outpost.request_checkpoint()

func _refresh_prompt() -> void:
	if is_open or not _landed:
		return
	var cost := required_keys()
	if GameState.keys >= cost:
		EventBus.interact_prompt_show.emit("按 [%s] 打开补给箱（消耗 %d 把钥匙 · 你有 %d）" % [UIFlow.hint(&"interact"),cost, GameState.keys])
	else:
		EventBus.interact_prompt_show.emit("补给箱：需要 %d 把钥匙（姜糖有售）" % cost)

func try_interact() -> void:
	if is_open or not _landed or not in_range:
		return
	var cost := required_keys()
	if GameState.keys < cost:
		EventBus.interaction_failed.emit("钥匙不足：需要 %d 把，你有 %d 把。" % [cost, GameState.keys])
		_refresh_prompt()
		return
	for i in cost:
		GameState.spend_key()
	_open()

func _open() -> void:
	is_open = true
	_opening = true
	_opening_elapsed = 0.0
	_reward_dispatched = false
	_pending_loot = _roll_loot()
	set_art("open")
	AudioManager.play(&"wave_clear", -8.0)
	EventBus.interact_prompt_hide.emit()
	Outpost.request_checkpoint()

func _roll_loot() -> Dictionary:
	var rng := Rng.stream()
	var roll := rng.randf()
	if roll < 0.50:
		var item := ItemDB.roll_random(rng, false, &"chest")
		if not item.is_empty():
			return {"kind": &"item", "item": item}
	if roll < 0.88:
		var gear := ItemDB.roll_random(rng, true, &"chest")
		if not gear.is_empty():
			return {"kind": &"gear", "item": gear}
	return {"kind": &"coins", "amount": rng.randi_range(60, 140)}

func _burst_reward() -> void:
	if _reward_dispatched or _pending_loot.is_empty():
		return
	if not is_instance_valid(GameState.runtime_node) or not is_instance_valid(GameState.runtime_node.loot):
		return
	var loot := _pending_loot.duplicate(true)
	loot["coin_visual_scale"] = 2.0/3.0
	GameState.runtime_node.loot.burst_reward(loot, global_position)
	_reward_dispatched = true
	_pending_loot.clear()
	Effects.spawn_marker(get_parent(), global_position + Vector2(0.0, -10.0), Palette.COIN)
	EventBus.chest_opened.emit(loot)
	Outpost.request_checkpoint()

func _fade_out() -> void:
	if is_queued_for_deletion() or (_fade_tween != null and _fade_tween.is_running()):
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 1.2)
	if _chest_light!=null:_fade_tween.parallel().tween_property(_chest_light,"energy",0.0,1.2)
	_fade_tween.tween_callback(queue_free)
