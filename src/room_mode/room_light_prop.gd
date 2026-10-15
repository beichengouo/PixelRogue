@tool
class_name RoomLightProp
extends Node2D
## Painted scenery plus a shared light descriptor; no extra additive lamp in daylight.
@export_enum("torch","lamp","plant","crystal","fire") var kind:="torch"
@export var footprint:=Vector2i.ONE
@export var radius_override:=0.0
@export var strength_override:=-1.0
@export var light_color:=Color(0,0,0,0)
@export var flicker:=true
@export var always_on:=true
@export var dispels_fog:=true
@export var use_kind_defaults:=true
var light_field:RoomLightField
var art:Sprite2D
var scene_texture:Texture2D
var scene_width:=24.0
var scene_bottom_anchor:=false
var light_offset:=Vector2.ZERO
const ATLAS:="res://assets/room_mode/environment/lights.png"

func _ready() -> void:
	art=Sprite2D.new();art.name="PaintedLight"
	art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var dedicated:="res://assets/room_mode/lights/%s_%dx%d.png"%[kind,footprint.x,footprint.y]
	if scene_texture!=null:
		art.texture=scene_texture;art.scale=Vector2.ONE*scene_width/scene_texture.get_width()
		art.position.y=footprint.y*18.0-scene_texture.get_height()*art.scale.y*.5
		light_offset=Vector2(0,footprint.y*18.0-scene_texture.get_height()*art.scale.y*.78)
		if scene_bottom_anchor:
			art.position.y=-scene_texture.get_height()*art.scale.y*.5
			light_offset=Vector2(0,-scene_texture.get_height()*art.scale.y*.78)
	elif ResourceLoader.exists(dedicated):
		art.texture=load(dedicated)
		art.scale=Vector2.ONE*(36.0*footprint.x/maxf(1,art.texture.get_width()))
		art.position.y=footprint.y*18.0-art.texture.get_height()*art.scale.y*.5
	elif ResourceLoader.exists(ATLAS):
		var texture:=AtlasTexture.new();texture.atlas=load(ATLAS)
		var column:=maxi(0,RoomEnvironmentConfig.LIGHT_KINDS.find(kind))
		var row:=maxi(0,RoomEnvironmentConfig.LIGHT_SIZES.find(footprint))
		texture.region=Rect2(column*128,row*128,128,128);texture.filter_clip=true
		art.texture=texture
		# Each atlas cell is normalized to its footprint, never upscaled from another variant.
		art.scale=Vector2.ONE*(36.0*maxi(footprint.x,footprint.y)/128.0)
		art.position.y=footprint.y*18.0-64.0*art.scale.y
	add_child(art)
	if not Engine.is_editor_hint():
		add_to_group("room_environment_lights")
		if light_field!=null:light_field.register(self,light_config())

func light_config() -> Dictionary:
	var value:Dictionary=RoomEnvironmentConfig.LIGHTS.get(kind,RoomEnvironmentConfig.LIGHTS.torch).duplicate()
	if radius_override>0:value.radius=radius_override
	if strength_override>=0:value.strength=strength_override
	if light_color.a>0:value.color=light_color
	# Kind defaults remain meaningful; export overrides can be applied explicitly through configure().
	if not use_kind_defaults:
		value.flicker=flicker;value.always_on=always_on;value.dispels_fog=dispels_fog
	return value

func configure(data:Dictionary) -> void:
	kind=str(data.get("kind",kind))
	var defaults:Dictionary=RoomEnvironmentConfig.LIGHTS.get(kind,RoomEnvironmentConfig.LIGHTS.torch)
	radius_override=float(data.get("radius",0));strength_override=float(data.get("strength",-1))
	flicker=bool(data.get("flicker",defaults.flicker));always_on=bool(data.get("always_on",defaults.always_on));dispels_fog=bool(data.get("dispels_fog",defaults.dispels_fog))
	if data.has("color"):light_color=data.color if data.color is Color else Color(str(data.color))
	use_kind_defaults=false
	if light_field!=null:light_field.register(self,light_config())

func _exit_tree() -> void:
	if light_field!=null:light_field.unregister(self)

func source_position()->Vector2:return global_position+light_offset
