class_name RoomEnvironmentVisual
extends CanvasLayer
## Draw after the world, including all warning and effect z-indices, before HUD layer 10.
var main:Node
var world_clock:RoomWorldClock
var light_field:=RoomLightField.new()
var fog_density:=0.0
var lights:Array[Dictionary]=[]
var shade:ColorRect
var _material:ShaderMaterial
var _token:=-1

func _ready() -> void:
	layer=5
	process_mode=Node.PROCESS_MODE_PAUSABLE
	shade=ColorRect.new();shade.name="WorldEnvironmentComposite"
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material=ShaderMaterial.new()
	_material.shader=load("res://src/room_mode/room_environment_visual.gdshader")
	_material.set_shader_parameter("fog_texture",load(WeatherSurfaceArt.QUALITY_WEATHER_DIR+"Fog.png"))
	_material.set_shader_parameter("cloud_texture",load(WeatherSurfaceArt.QUALITY_WEATHER_DIR+"Clouds.png"))
	_material.set_shader_parameter("max_obscurity",RoomEnvironmentConfig.MAX_OBSCURITY)
	shade.material=_material
	add_child(shade)
	shade.hide()

func _process(delta:float) -> void:
	if not is_instance_valid(main) or main.is_queued_for_deletion() or (not GameState.run_active and not CampSession.active):
		if is_instance_valid(shade):shade.hide()
		return
	var actor:Variant=main.get("player")
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():shade.hide();return
	var token:=int(main.get("room_token"))
	if token!=_token:
		_token=token;light_field.clear()
	var state:Variant=main.get("room_weather")
	var target:=0.0
	if state is WeatherState:target=clampf(state.amount("fog")/maxf(0.001,state.intensity()),0,1)
	var seconds:=RoomEnvironmentConfig.FOG_BUILD_SECONDS if target>fog_density else RoomEnvironmentConfig.FOG_CLEAR_SECONDS
	fog_density=move_toward(fog_density,target,delta/maxf(0.01,seconds))
	light_field.refresh(main,delta)
	var darkness:=world_clock.darkness() if world_clock!=null else 0.0
	lights=light_field.sources(main,world_clock,fog_density)
	if darkness<=.0001 and fog_density<=.0001 and not lights.any(func(record:Dictionary)->bool:return bool(record.get("day_glow",false)) and float(record.strength)>.001):
		lights.clear();shade.hide();return
	var transform:=get_viewport().get_canvas_transform()
	var scale_factor:=maxf(absf(transform.get_scale().x),absf(transform.get_scale().y))
	_material.set_shader_parameter("fog_origin",transform.affine_inverse()*Vector2.ZERO)
	_material.set_shader_parameter("fog_world_scale",1.0/maxf(.001,scale_factor))
	_material.set_shader_parameter("weather_time",state.time if state is WeatherState else 0.0)
	var positions:=PackedVector4Array()
	var colors:=PackedVector4Array()
	var glow:=PackedFloat32Array();glow.resize(RoomEnvironmentConfig.MAX_LIGHTS)
	positions.resize(RoomEnvironmentConfig.MAX_LIGHTS);colors.resize(RoomEnvironmentConfig.MAX_LIGHTS)
	for index in lights.size():
		var record:=lights[index]
		var at:Vector2=transform*record.position
		positions[index]=Vector4(at.x,at.y,float(record.radius)*scale_factor,float(record.strength))
		var color:Color=record.color
		colors[index]=Vector4(color.r,color.g,color.b,1.0 if bool(record.dispels_fog) else 0.0)
		glow[index]=1.0 if bool(record.get("day_glow",false)) else 0.0
	_material.set_shader_parameter("lights",positions)
	_material.set_shader_parameter("light_colors",colors)
	_material.set_shader_parameter("light_glow",glow)
	_material.set_shader_parameter("light_count",lights.size())
	_material.set_shader_parameter("viewport_size",get_viewport().get_visible_rect().size)
	_material.set_shader_parameter("darkness",world_clock.darkness() if world_clock!=null else 0.0)
	_material.set_shader_parameter("fog_density",smoothstep(0,1,fog_density))
	shade.show()

func snapshot() -> Dictionary:
	return {"version":1,"fog_density":fog_density}

func restore(data:Dictionary) -> void:
	fog_density=clampf(float(data.get("fog_density",0)),0,1)

func _exit_tree() -> void:
	light_field.clear()
