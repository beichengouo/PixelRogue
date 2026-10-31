class_name HostileAttackFX
extends Node2D
const ROOT := "res://assets/enemy_expansion_v02/fx/"
const CELL := 192
const FAMILIES := ["king","mage","tide","thorn_mantis","lantern_toad","dusk_acolyte"]
const VECTOR_AREA_BOSSES := ["king","mage","tide","sephra","verena","nameless"]
const VECTOR_BOSS_STAGES := ["area","slash","radial","flight"]
const RASTER_BOSS_STAGES := {"king":["cast","impact"],"mage":["cast","impact","construct"],"tide":["cast","impact","construct"],"sephra":["cast","impact"],"verena":["cast","impact"],"nameless":["cast","impact"]}
static var _frames: Dictionary = {}
static var _shader: Shader
static var active_count:=0
var textures: Array[Texture2D] = []
var sprite: Sprite2D
var age := 0.0
var duration := 0.35
var geometry:Dictionary={}
var _segments:Array[Sprite2D]=[]
var _outline:=PackedVector2Array()
const STRIKE_SHADER:="""shader_type canvas_item;
render_mode unshaded;
uniform vec4 arena=vec4(0.0);
uniform vec2 origin=vec2(0.0);
uniform vec2 axis=vec2(1.0,0.0);
uniform int shape_kind=0;
uniform float radius=60.0;
uniform float length_value=60.0;
uniform float half_width=18.0;
uniform float half_angle=.5;
varying vec2 world_xy;
void vertex(){world_xy=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
 vec2 d=world_xy-origin;float along=dot(d,axis);float side=d.x*axis.y-d.y*axis.x;
 bool legal=world_xy.x>=arena.x&&world_xy.y>=arena.y&&world_xy.x<=arena.z&&world_xy.y<=arena.w;
 if(shape_kind==1){legal=legal&&along>=0.0&&along<=length_value&&abs(side)<=half_width;}
 else if(shape_kind==2){legal=legal&&length(d)<=radius&&(length(d)<10.0||abs(atan(side,along))<=half_angle);}
 else if(shape_kind==3){legal=legal&&length(d)<=radius&&abs(atan(side,along))>=half_angle;}
 else{legal=legal&&length(d)<=radius;}
 if(!legal){COLOR.a=0.0;}
}"""
static var _strike_shader:Shader


func _enter_tree()->void:active_count+=1
func _exit_tree()->void:active_count=maxi(0,active_count-1)

static func frames(family: String, stage: String) -> Array[Texture2D]:
	if family=="goblin_mage":return frames("dusk_acolyte",stage)
	if family=="goblin_scout" or (family=="goblin_spearman" and stage!="flight"):return frames("thorn_mantis",stage)
	var key := family + "_" + stage
	if _frames.has(key): return _frames[key]
	var result: Array[Texture2D] = []
	var path := "res://assets/combat_revision_v04/fx/"+key+".png"
	if stage in VECTOR_BOSS_STAGES and family in VECTOR_AREA_BOSSES:path="res://assets/boss_fx_v40/"+key+".png"
	if family=="goblin_spearman":path=ForestUnitArt.ROOT+"goblin_spearman_flight.png"
	if family in ["sephra","verena","nameless"] and not (stage in VECTOR_BOSS_STAGES and family in VECTOR_AREA_BOSSES):path="res://assets/chapter2/fx/"+key+".png"
	if family in ["bell_snail","glimmer_spider"]:path="res://assets/content_v05/fx/"+key+".png"
	var raster_path:="res://assets/boss_fx_v42/"+key+".png"
	if stage in RASTER_BOSS_STAGES.get(family,[]) and ResourceLoader.exists(raster_path):path=raster_path
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

static func texture_filter_for(family:String,stage:String)->CanvasItem.TextureFilter:
	return CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if (stage in VECTOR_BOSS_STAGES and family in VECTOR_AREA_BOSSES) or stage in RASTER_BOSS_STAGES.get(family,[]) else CanvasItem.TEXTURE_FILTER_NEAREST

static func pulse(parent: Node, at: Vector2, family: String, stage: String, width: float, seconds := 0.35, direction := 0.0, room: RoomLevel = null) -> HostileAttackFX:
	if not is_instance_valid(parent): return null
	# A crowded battle may simplify hit particles, but never hide a teleport cue.
	if active_count>=32 and stage not in ["area","cast"] and not (family=="affix" and stage in ["departure","arrival"]): return null
	var textures_value := frames(family,stage)
	if textures_value.is_empty(): return null
	var effect := HostileAttackFX.new();effect.textures=textures_value;effect.duration=seconds
	effect.sprite=Sprite2D.new();effect.sprite.texture=textures_value[0];effect.sprite.texture_filter=texture_filter_for(family,stage)
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

static func strike(parent:Node,room:RoomLevel,family:String,data:Dictionary,seconds:=.65)->HostileAttackFX:
	var shape:=str(data.get("shape","circle"));var stage:="flight" if shape=="line" else "slash" if shape=="fan" else "area"
	var fx:=pulse(parent,data.at,family,stage,96,seconds,0,room)
	if fx==null:return null
	fx.geometry=data.duplicate(true);fx.z_as_relative=false;fx.z_index=780
	var direction:Vector2=data.get("dir",Vector2.RIGHT);var radius:=float(data.get("radius",60))
	var span:Vector2=data.get("end",data.at+direction*radius)-data.at
	if shape=="line" and not span.is_zero_approx():direction=span.normalized()
	if direction.is_zero_approx():direction=Vector2.RIGHT
	fx.rotation=direction.angle() if shape in ["line","fan"] else 0.0
	if _strike_shader==null:_strike_shader=Shader.new();_strike_shader.code=STRIKE_SHADER
	var ink:=ShaderMaterial.new();ink.shader=_strike_shader
	var bounds:=room.bounds();ink.set_shader_parameter("arena",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))
	ink.set_shader_parameter("origin",data.at);ink.set_shader_parameter("axis",direction)
	ink.set_shader_parameter("shape_kind",1 if shape=="line" else 2 if shape=="fan" else 0)
	ink.set_shader_parameter("radius",radius);ink.set_shader_parameter("half_angle",float(data.get("spread",1))*.5)
	ink.set_shader_parameter("length_value",span.length());ink.set_shader_parameter("half_width",float(data.get("width",18)))
	fx.sprite.material=ink
	var cell:=float(fx.textures[0].get_width())
	if shape=="line":
		# Repeated horizontal flight art retains its authored direction instead of stretching a square eruption.
		var count:=clampi(ceili(span.length()/64.0),1,24);var length_value:=span.length()/count
		for index in count:
			var part:=fx.sprite if index==0 else Sprite2D.new()
			if index>0:part.texture=fx.textures[0];part.material=ink;part.texture_filter=fx.sprite.texture_filter;fx.add_child(part)
			part.position=Vector2((index+.5)*length_value,0);part.scale=Vector2(length_value*1.08,float(data.get("width",18))*2.0)/cell
			fx._segments.append(part)
	else:fx.sprite.scale=Vector2.ONE*radius*2/cell
	for point in AttackGeometry.outline(data):
		if room.bounds().has_point(data.at+point):fx._outline.append(point.rotated(-fx.rotation))
	fx.modulate.a=maxf(.4,PixelSpellArt.strength())
	return fx

static func radial(parent:Node,room:RoomLevel,family:String,at:Vector2,gap:Vector2,opening:float)->HostileAttackFX:
	var fx:=pulse(parent,at,family,"radial",144,.65,0,room)
	if fx==null:return null
	if _strike_shader==null:_strike_shader=Shader.new();_strike_shader.code=STRIKE_SHADER
	var ink:=ShaderMaterial.new();ink.shader=_strike_shader
	var bounds:=room.bounds();ink.set_shader_parameter("arena",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))
	ink.set_shader_parameter("origin",at);ink.set_shader_parameter("axis",gap.normalized());ink.set_shader_parameter("shape_kind",3)
	ink.set_shader_parameter("radius",72.0);ink.set_shader_parameter("half_angle",opening*.5);fx.sprite.material=ink
	return fx

func _draw()->void:
	if geometry.is_empty():return
	# This exact footprint remains readable even when the decorative texture is reduced.
	var opacity:=.7*(1-clampf(age/duration,0,1))
	for point in _outline:draw_rect(Rect2(point-Vector2.ONE,Vector2.ONE*2),Color(1,.43,.32,opacity))

func _process(delta: float) -> void:
	age+=delta
	if age>=duration:queue_free();return
	sprite.texture=textures[mini(3,int(age/maxf(.01,duration)*4))]
	if ComicMotion.reduced(): sprite.texture=textures[0 if age<duration*.25 else (3 if age>duration*.75 else 1)]
	for part in _segments:part.texture=sprite.texture
	if not geometry.is_empty():queue_redraw()

static func cell_size(family:String,stage:String)->float:
	var values:=frames(family,stage)
	return values[0].get_width() if not values.is_empty() else CELL
