class_name FateAltar
extends RoomAlly
## A room objective, never a hired/contract unit. Its state belongs to the room.
const HIT_LIMIT := 10
var main: Node
var ui: FateUI
var _room_id := ""
var _label: Label
var _model: RoomLightProp
var _collapse: AnimatedSprite2D
var _bar: UnitVitalBar
var _state: Dictionary = {}
var _collapse_left := 0.0

func _ready() -> void:
	collision_layer = 0; collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new(); circle.radius = 22; collider.shape = circle; add_child(collider)
	_model = RoomLightProp.new(); _model.kind = "crystal"
	_model.scene_texture = load("res://assets/fate_v01/altar/moonwell.png")
	_model.scene_width = 66; _model.scene_bottom_anchor = true
	_model.radius_override = 120; _model.strength_override = .65; _model.light_color = Color("c4d8ff"); add_child(_model)
	_label = PixelUi.label("", 14, Color("d9e9fb")); _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(300, 24); _label.z_index = 1000; _label.top_level = true; add_child(_label)
	_bar = UnitVitalBar.new(); _bar.style_id="ally"; _bar.size = Vector2(72, 16); _bar.position = Vector2(-36, -92);add_child(_bar)
	_collapse = AnimatedSprite2D.new(); _collapse.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := SpriteFrames.new(); frames.remove_animation(&"default"); frames.add_animation(&"collapse"); frames.set_animation_loop(&"collapse", false); frames.set_animation_speed(&"collapse", 8)
	if ResourceLoader.exists("res://assets/fate_v09/altar_collapse.png"):
		for index in 6:
			var frame := AtlasTexture.new(); frame.atlas = load("res://assets/fate_v09/altar_collapse.png"); frame.region = Rect2(index*192,0,192,192); frame.filter_clip = true; frames.add_frame(&"collapse",frame)
	_collapse.sprite_frames = frames; _collapse.scale = Vector2.ONE*.48; _collapse.position = Vector2(0,-38.4); _collapse.hide(); add_child(_collapse)
	visible = false

func _process(delta: float) -> void:
	sync_room()
	if not visible: return
	if _collapse_left > 0:
		_collapse_left = maxf(0,_collapse_left-delta)
		_collapse.modulate.a = minf(1,_collapse_left/.25)
		if _collapse_left <= 0: visible = false
		return
	var record: Dictionary = main.graph.rooms.get(main.graph.current,{})
	if bool(record.get("delta",{}).get("fate_reading",{}).get("done",false)):
		_unregister(); visible = false; return
	var can_read := FateService.eligible(record)
	var nearby := is_instance_valid(main.player) and global_position.distance_squared_to(main.player.global_position) <= 8100
	_label.global_position = global_position+Vector2(-150,-114)
	_label.text = (UIFlow.hint(&"interact")+" · 命运祭坛") if can_read and nearby and not UIFlow.has_screen() else ("命运祭坛" if can_read else "守护命运祭坛")
	_bar.max_value = max_hp; _bar.value = hp
	shield_time = maxf(0,shield_time-delta)
	if shield_time <= 0: shield_hp = 0

func sync_room() -> void:
	if not is_instance_valid(main) or not is_instance_valid(main.level) or not is_instance_valid(main.player): return
	var record: Dictionary = main.graph.rooms.get(main.graph.current,{})
	var location_key := "%s:%s:%s" % [GameState.run_epoch,main.graph.current,main.level._load_generation]
	if location_key == _room_id: return
	_room_id = location_key; _collapse_left = 0; _collapse.stop(); _collapse.hide(); _model.show(); _bar.show(); _label.show()
	_unregister()
	if record.get("kind","") != "altar": visible = false; return
	room = main.level; level = room; player = main.player; fx_root = main.fx_root; uid = "altar:"+str(main.graph.current)
	if not record.delta.has("fate_guard"):
		record.delta.fate_guard = {"hp":HIT_LIMIT,"max_hp":HIT_LIMIT,"dead":false,"hit_based":true}
	_state = record.delta.fate_guard
	if not bool(_state.get("hit_based",false)):
		# Preserve the remaining proportion of an already damaged old objective.
		_state.hp = 0 if bool(_state.get("dead",false)) else clampi(ceili(float(_state.get("hp",1))/maxf(1,float(_state.get("max_hp",1)))*HIT_LIMIT),0,HIT_LIMIT)
		_state.max_hp = HIT_LIMIT; _state.hit_based = true
	max_hp = HIT_LIMIT; hp = clampf(float(_state.get("hp",HIT_LIMIT)),0,HIT_LIMIT)
	_bar.tooltip_text = "命运祭坛 · 剩余 %d / %d 次承击\n免疫中毒、燃烧等持续伤害" % [int(hp),HIT_LIMIT]
	var reading: Dictionary = record.delta.get("fate_reading",{})
	visible = hp > 0 and not bool(_state.get("dead",false)) and not bool(reading.get("done",false))
	if not visible: return
	# Authored image anchor scales with the artwork, independent of collision edits.
	var picture := room.illustration
	global_position = room.bounds().get_center()
	if picture != null and picture.active():
		var frame := picture.frame_rect()
		var anchor: Array = picture.data.get("gameplay_anchors",{}).get("fate_altar_uv",[.5,514.0/1024.0])
		global_position = picture.to_global(frame.position+Vector2(float(anchor[0]),float(anchor[1]))*frame.size)
	var reverse := FateService.orientation(record)
	_model.scene_texture = load("res://assets/fate_v01/altar/moonwell_reverse.png" if reverse else "res://assets/fate_v01/altar/moonwell.png")
	_model.light_color = Color("d4b0ef") if reverse else Color("c4d8ff")
	_model.art.texture = _model.scene_texture; _model.art.scale = Vector2.ONE*66/_model.scene_texture.get_width(); _model.art.position.y = -_model.scene_texture.get_height()*_model.art.scale.y*.5
	_model.light_offset = Vector2(0,-_model.scene_texture.get_height()*_model.art.scale.y*.78)
	collision_layer = Layers.PLAYER; add_to_group("allies"); room.tactics.invalidate_roster()
	_bar.max_value = max_hp; _bar.value = hp

func _unregister() -> void:
	collision_layer = 0
	if is_in_group("allies"): remove_from_group("allies")
	if is_instance_valid(room): room.tactics.invalidate_roster()

func _physics_process(_delta: float) -> void: pass
func _draw() -> void: pass
func place_near_player() -> void: pass
func heal(_amount: float) -> void: pass
func _continuous_damage(source: Node) -> bool:
	if not is_instance_valid(source): return false
	if source is DamageContext: return source.report_channel == &"dot" or source.owner_kind in [&"dot",&"spread_burn"] or str(source.owner_kind).begins_with("continuous_")
	if source is CruelDamage.TickSource: return true
	return source is AffixHazard and source.mode in [&"trail",&"grave"]
func take_damage(amount: float, _from := Vector2.ZERO, source: Node = null) -> void:
	if not visible or hp <= 0 or amount <= 0 or _continuous_damage(source): return
	# The objective counts direct impacts; allied heals/shields cannot extend it.
	hp = maxf(0,hp-1); _state.hp = hp; _bar.value = hp
	_bar.tooltip_text = "命运祭坛 · 剩余 %d / %d 次承击\n免疫中毒、燃烧等持续伤害" % [int(hp),HIT_LIMIT]
	Effects.damage_number(main.fx_root,global_position-Vector2(0,80),1,false,Palette.UI_DANGER)
	if hp <= 0:
		_state.dead = true; _unregister(); _label.hide(); _bar.hide(); _model.hide()
		_collapse_left = 1; _collapse.modulate = Color.WHITE; _collapse.show(); _collapse.play(&"collapse")
		AudioManager.play(&"altar_collapse",-5,0)
		Effects.text(main.fx_root,global_position-Vector2(0,70),"命运祭坛已坍塌",Palette.UI_DANGER,19)
	Outpost.request_checkpoint()
func try_interact() -> bool:
	var record: Dictionary = main.graph.rooms.get(main.graph.current,{})
	if not visible or hp <= 0 or not FateService.eligible(record) or UIFlow.has_screen() or global_position.distance_squared_to(main.player.global_position) > 8100: return false
	ui.open_altar(record); return true
