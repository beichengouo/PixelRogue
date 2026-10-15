class_name GoddessExtractionFX
extends Node2D
## Clocks supplied by the director keep pause/restore synchronized with the sprite sequence.
var prayer: AnimatedSprite2D
var pillar: AnimatedSprite2D
var ground_rune: AnimatedSprite2D
var goddess: AnimatedSprite2D
var success: AnimatedSprite2D

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
	var height:=ExtractionSpriteArt.character_height(Characters.current_id())*RoomHeroArt.WORLD_HEIGHT/RedrawnHeroArt.ART_HEIGHT
	goddess = _make("goddess", height*float(ExtractionSpriteArt.SUCCESS_GODDESS_HEIGHT[Characters.current_id()])/float(ExtractionSpriteArt.SUCCESS_HEIGHT[Characters.current_id()]), material, false)
	success = _make("success", height, material, true)
	clear()

func _exit_tree()->void:
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
	for sprite in [prayer,pillar,ground_rune,goddess,success]:
		if is_instance_valid(sprite): sprite.hide()

func present(state: String, prayer_time: float, waiting_time: float, reception_time: float, at: Vector2, player: Player) -> void:
	if not is_node_ready(): return
	clear()
	var reduced := ComicMotion.reduced()
	var id:=Characters.current_id()
	# Read the real actor transform so room and legacy scenes share the same size.
	prayer.scale=player._sprite.scale
	var height:=ExtractionSpriteArt.character_height(id)*absf(player._sprite.scale.y)
	success.scale=Vector2.ONE*ExtractionSpriteArt.scale_for("success",height)
	goddess.scale=Vector2.ONE*ExtractionSpriteArt.scale_for("goddess",height*float(ExtractionSpriteArt.SUCCESS_GODDESS_HEIGHT[id])/float(ExtractionSpriteArt.SUCCESS_HEIGHT[id]))
	var feet := player._sprite.to_global(RedrawnHeroArt.FOOT-Vector2.ONE*RedrawnHeroArt.CELL*.5)
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
			var direction := -1.0 if flipped else 1.0
			if reception_time < 0.55:
				_place(goddess, feet + Vector2(direction * float(ExtractionSpriteArt.SUCCESS_GODDESS_OFFSET[id])*success.scale.x,-3), mini(2,int(reception_time / 0.55 * 3)), clampf(reception_time / 0.12,0,1), flipped)
				player.set_extraction_pose(&"receiving", false)
			else:
				player.set_extraction_pose(&"receiving", true)
				var progress := clampf((reception_time - 0.55) / 1.30,0,1)
				var fade := 1.0 - clampf((reception_time - 1.88) / 0.12,0,1)
				var count:=success.sprite_frames.get_frame_count(&"default")
				_place(success, feet, mini(count-1,int(progress*count)), fade, flipped)
