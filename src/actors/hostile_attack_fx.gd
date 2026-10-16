class_name HostileAttackFX
extends Node2D
const ROOT := "res://assets/enemy_expansion_v02/fx/"
const CELL := 192
const FAMILIES := ["king","mage","tide","thorn_mantis","lantern_toad","dusk_acolyte"]
static var _frames: Dictionary = {}
static var _shader: Shader
var textures: Array[Texture2D] = []
var sprite: Sprite2D
var age := 0.0
var duration := 0.35

static func frames(family: String, stage: String) -> Array[Texture2D]:
	var key := family + "_" + stage
	if _frames.has(key): return _frames[key]
	var result: Array[Texture2D] = []
	var path := "res://assets/combat_revision_v04/fx/"+key+".png"
	if family in ["sephra","verena","nameless"]:path="res://assets/chapter2/fx/"+key+".png"
	if family in ["bell_snail","glimmer_spider"]:path="res://assets/content_v05/fx/"+key+".png"
	if not ResourceLoader.exists(path):path=ROOT+key+".png"
	if not ResourceLoader.exists(path): return result
	var source := load(path) as Texture2D
	var cell:=source.get_height()
	if source.get_width()!=cell*4:return result
	for index in 4:
		var texture := AtlasTexture.new(); texture.atlas=source;texture.region=Rect2(index*cell,0,cell,cell);texture.filter_clip=true
		result.append(texture)
	_frames[key]=result
	return result

static func pulse(parent: Node, at: Vector2, family: String, stage: String, width: float, seconds := 0.35, direction := 0.0, room: RoomLevel = null) -> HostileAttackFX:
	if not is_instance_valid(parent): return null
	# A crowded battle may simplify hit particles, but never hide a teleport cue.
	if parent.get_tree().get_nodes_in_group("hostile_attack_fx").size()>=32 and stage not in ["area","cast"] and not (family=="affix" and stage in ["departure","arrival"]): return null
	var textures_value := frames(family,stage)
	if textures_value.is_empty(): return null
	var effect := HostileAttackFX.new();effect.textures=textures_value;effect.duration=seconds
	effect.sprite=Sprite2D.new();effect.sprite.texture=textures_value[0];effect.sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	effect.sprite.scale=Vector2.ONE*width/textures_value[0].get_width();effect.add_child(effect.sprite)
	if _shader==null:
		_shader=Shader.new();_shader.code="shader_type canvas_item; render_mode unshaded; uniform bool clip_arena=false; uniform vec4 arena=vec4(0.0); uniform bool circle=false; uniform float circle_radius=96.0; varying vec2 world_xy; varying vec2 local_xy; void vertex(){ world_xy=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; local_xy=VERTEX; } void fragment(){ if(clip_arena && (world_xy.x<arena.x || world_xy.y<arena.y || world_xy.x>arena.z || world_xy.y>arena.w)){ COLOR.a=0.0; } if(circle && length(local_xy)>circle_radius){COLOR.a=0.0;} }"
	var ink:=ShaderMaterial.new();ink.shader=_shader
	ink.set_shader_parameter("circle",stage=="area");ink.set_shader_parameter("circle_radius",textures_value[0].get_width()*.5)
	if is_instance_valid(room):
		var bounds:=room.bounds();ink.set_shader_parameter("clip_arena",true);ink.set_shader_parameter("arena",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))
	effect.sprite.material=ink
	parent.add_child(effect);effect.global_position=at;effect.rotation=direction;effect.z_index=780 if stage in ["area","cast"] else 6;effect.z_as_relative=stage not in ["area","cast"]
	effect.add_to_group("hostile_attack_fx")
	effect.modulate.a=maxf(.3,PixelSpellArt.strength())
	return effect

func _process(delta: float) -> void:
	age+=delta
	if age>=duration:queue_free();return
	sprite.texture=textures[mini(3,int(age/maxf(.01,duration)*4))]
	if ComicMotion.reduced(): sprite.texture=textures[0 if age<duration*.25 else (3 if age>duration*.75 else 1)]

static func cell_size(family:String,stage:String)->float:
	var values:=frames(family,stage)
	return values[0].get_width() if not values.is_empty() else CELL
