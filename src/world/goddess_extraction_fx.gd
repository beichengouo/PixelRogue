class_name GoddessExtractionFX
extends Node2D
## Reception dissolves the exact current actor pose. Director clocks preserve pause/restore.
var prayer: AnimatedSprite2D
var pillar: AnimatedSprite2D
var ground_rune: AnimatedSprite2D
var dissolve:Sprite2D
var _dissolve_material:ShaderMaterial
var _source_actor:WeakRef
var _source_self_modulate:=Color.WHITE
var _last_reception_time:=-1.0
var _appearance_key:=""

func _ready() -> void:
	z_index = 12
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded; varying vec4 tint; void vertex(){tint=COLOR;} void fragment(){vec4 c=texture(TEXTURE,UV)*tint; c.a *= smoothstep(0.025,0.055,c.a); COLOR=c;}"
	var material := ShaderMaterial.new()
	material.shader = shader
	prayer = _make("prayer", RoomHeroArt.WORLD_HEIGHT, material, true)
	if ResourceLoader.exists("res://assets/next_revision/extraction/beam.png"):
		ground_rune=_make_beam_row(0,Vector2(64,74),1.0,material)
		ground_rune.z_as_relative=false;ground_rune.z_index=0
		# The level draws its floor at z=0. Place the rune as a level child,
		# after the floor and before GroundActors; a negative z hides it below tiles.
		var director:=get_parent()
		if "main" in director and is_instance_valid(director.main) and is_instance_valid(director.main.level):
			ground_rune.reparent(director.main.level)
		pillar=_make_beam_row(1,Vector2(64,100),1.0,material)
		pillar.scale=Vector2(1,2)
		pillar.z_as_relative=false;pillar.z_index=6
	else:pillar = _make("pillar", 280, material, false)
	dissolve=Sprite2D.new();dissolve.name="DepartingCharacter"
	_dissolve_material=ShaderMaterial.new();_dissolve_material.shader=preload("res://src/world/extraction_dissolve.gdshader")
	dissolve.material=_dissolve_material;add_child(dissolve)
	clear()

func _exit_tree()->void:
	_reset_dissolve()
	if is_instance_valid(ground_rune) and ground_rune.get_parent()!=self:ground_rune.queue_free()

func _make_beam_row(row:int,pivot:Vector2,scale_value:float,material:ShaderMaterial)->AnimatedSprite2D:
	var sprite:=AnimatedSprite2D.new()
	var frames:=SpriteFrames.new();frames.set_animation_loop(&"default",false)
	frames.set_animation_speed(&"default",8)
	var source:Texture2D=load("res://assets/next_revision/extraction/beam.png")
	for col in 8:
		var texture:=AtlasTexture.new();texture.atlas=source;texture.region=Rect2(col*128,row*128,128,128);texture.filter_clip=true
		frames.add_frame(&"default",texture)
	sprite.sprite_frames=frames;sprite.material=material
	sprite.set_meta("beam_pivot",pivot-Vector2(64,64))
	sprite.scale=Vector2.ONE*scale_value;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite);return sprite

func _make(kind: String, height: float, material: ShaderMaterial, pixel: bool) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = kind.capitalize()
	sprite.sprite_frames = ExtractionSpriteArt.frames(kind)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel else CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = RedrawnHeroArt.material() if kind=="prayer" else material
	if kind=="prayer" and HanddrawnHeroArt.available(Characters.current_id()):sprite.material=null;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * ExtractionSpriteArt.scale_for(kind, height)
	add_child(sprite)
	return sprite

func _place(sprite: AnimatedSprite2D, at: Vector2, frame_index: int, alpha := 1.0, flipped := false) -> void:
	var pivot := ExtractionSpriteArt.FOOT - ExtractionSpriteArt.LOGICAL_SIZE * 0.5
	if sprite.has_meta("beam_pivot"):pivot=sprite.get_meta("beam_pivot")
	if flipped: pivot.x = -pivot.x
	sprite.global_position = at - pivot * sprite.scale
	sprite.flip_h = flipped
	sprite.frame = clampi(frame_index, 0, sprite.sprite_frames.get_frame_count(&"default") - 1)
	sprite.modulate = Color(1,1,1,alpha)
	sprite.visible = alpha > 0.001

func clear() -> void:
	_hide_layers()
	_reset_dissolve()

func _hide_layers()->void:
	for sprite in [prayer,pillar,ground_rune,dissolve]:
		if is_instance_valid(sprite): sprite.hide()

func _reset_dissolve()->void:
	var source:Player=_source_actor.get_ref() if _source_actor!=null else null
	if is_instance_valid(source):
		source.self_modulate=_source_self_modulate
		if source.extraction_pose==&"receiving":source.set_extraction_pose(&"receiving",false)
	_source_actor=null;_last_reception_time=-1.0
	if is_instance_valid(dissolve):dissolve.hide();dissolve.texture=null

func _capture_dissolve(player:Player)->void:
	_reset_dissolve()
	var sprite:=player._sprite
	dissolve.texture=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	dissolve.centered=sprite.centered;dissolve.offset=sprite.offset
	dissolve.flip_h=sprite.flip_h;dissolve.flip_v=sprite.flip_v
	dissolve.texture_filter=sprite.texture_filter;dissolve.global_transform=sprite.global_transform
	dissolve.modulate=Color(sprite.modulate.r,sprite.modulate.g,sprite.modulate.b,1)
	_source_actor=weakref(player);_source_self_modulate=player.self_modulate
	var origin:=Vector2.ZERO;var size:=Vector2.ONE
	var atlas:=dissolve.texture as AtlasTexture
	if atlas!=null:
		origin=atlas.region.position/atlas.atlas.get_size();size=atlas.region.size/atlas.atlas.get_size()
	_dissolve_material.set_shader_parameter("frame_origin",origin)
	_dissolve_material.set_shader_parameter("frame_size",size)

func present(state: String, prayer_time: float, waiting_time: float, reception_time: float, at: Vector2, player: Player) -> void:
	if not is_node_ready(): return
	_hide_layers()
	if state!="receiving":_reset_dissolve()
	var reduced := ComicMotion.reduced()
	var id:=Characters.current_id()
	var appearance:=str(id)+("_set" if LegendarySets.form_unlocked(id) else "_normal")
	if appearance!=_appearance_key:
		prayer.sprite_frames=ExtractionSpriteArt.frames("prayer")
		_appearance_key=appearance
	# Read the real actor transform so room and legacy scenes share the same size.
	prayer.scale=player._sprite.scale
	# Use the same logical cell and sole as the current handdrawn/set model.
	# The retired 96px anchor lifts the current 448px models far above ground.
	var model_frames:=player._sprite.sprite_frames
	var model_foot:Vector2=model_frames.get_meta("hd_foot",RedrawnHeroArt.FOOT)
	var model_cell:=float(model_frames.get_meta("hd_cell",RedrawnHeroArt.CELL))
	var feet := player._sprite.to_global(model_foot-Vector2.ONE*model_cell*.5)
	prayer.material=player._sprite.material
	var flipped := player.facing < 0
	match state:
		"praying":
			var index := mini(2, int(prayer_time * 7)) if prayer_time < 0.43 else 3 + int((prayer_time - 0.43) * (2 if reduced else 5)) % 3
			_place(prayer, feet, index, 1, flipped)
		"waiting":
			var index := mini(2,int(waiting_time * 6)) if waiting_time < 0.5 else 2 + int((waiting_time - 0.5) * (2 if reduced else 7)) % 4
			if is_instance_valid(ground_rune):
				index=int(waiting_time*(2 if reduced else 8))%8
				_place(ground_rune,at,index,0.65 if reduced else 0.82)
			_place(pillar, at, index, 0.65 if reduced else 0.82)
		"receiving":
			if _source_actor==null or _source_actor.get_ref()!=player or reception_time<_last_reception_time:_capture_dissolve(player)
			_last_reception_time=reception_time
			var progress:=clampf(reception_time/ExtractionDirector.RECEPTION_SECONDS,0,1)
			_dissolve_material.set_shader_parameter("progress",progress)
			_dissolve_material.set_shader_parameter("reduced_motion",reduced)
			dissolve.visible=progress<1
			var shadow:=_source_self_modulate;shadow.a*=1.0-progress;player.self_modulate=shadow
			player.set_extraction_pose(&"receiving",true)
