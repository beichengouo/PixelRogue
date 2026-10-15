class_name RoomLightField
extends RefCounted
## Shared descriptors power both night visibility and fog clearing.
## Weak references cannot retain destroyed room props or point-light owners.
var entries:Dictionary={}
var _scan_left:=0.0
var _room_token:=-1
var _simulation_time:=0.0

func register(source:Node2D, config:Dictionary={}) -> void:
	if not is_instance_valid(source) or source.is_queued_for_deletion():return
	# Room lighting is composited once over every world layer. Native point-light
	# addition otherwise brightens shaded props but misses unshaded floor planes.
	if source is PointLight2D:source.range_item_cull_mask=0
	entries[source.get_instance_id()]={"source":weakref(source),"config":config.duplicate()}

func unregister(source:Node2D) -> void:
	if is_instance_valid(source):entries.erase(source.get_instance_id())

func clear() -> void:
	entries.clear();_scan_left=0.0

func refresh(main:Node,delta:float) -> void:
	_simulation_time+=maxf(0,delta)
	if not is_instance_valid(main):clear();return
	_scan_left-=delta
	if _scan_left>0:return
	_scan_left=RoomEnvironmentConfig.LIGHT_SCAN_SECONDS
	for id in entries.keys():
		var source:Variant=entries[id].source.get_ref()
		if not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_inside_tree():entries.erase(id)
	for source in main.get_tree().get_nodes_in_group("room_point_lights"):
		if not is_instance_valid(source) or source.is_queued_for_deletion() or not main.is_ancestor_of(source):continue
		if not entries.has(source.get_instance_id()):register(source)
	for source in main.get_tree().get_nodes_in_group("room_environment_lights"):
		if is_instance_valid(source) and not source.is_queued_for_deletion() and main.is_ancestor_of(source):
			source.light_field=self
			if not entries.has(source.get_instance_id()):register(source,source.light_config())

func sources(main:Node,world_clock:RoomWorldClock,fog:float) -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if not is_instance_valid(main):return result
	var actor:Variant=main.get("player")
	var player_valid:bool=is_instance_valid(actor) and not actor.is_queued_for_deletion()
	if player_valid:
		result.append({"position":actor.global_position,"radius":RoomEnvironmentConfig.PLAYER_LIGHT_RADIUS,"strength":1.0,"color":Color("ffe8cd"),"dispels_fog":true})
	for ally in main.get_tree().get_nodes_in_group("allies"):
		if not is_instance_valid(ally) or ally.is_queued_for_deletion() or not ally is Node2D:continue
		if not main.is_ancestor_of(ally) or not ally.is_visible_in_tree():continue
		if ally.get("hp")!=null and float(ally.get("hp"))<=0:continue
		result.append({"position":ally.global_position,"radius":RoomEnvironmentConfig.PLAYER_LIGHT_RADIUS*RoomEnvironmentConfig.ALLY_LIGHT_RADIUS_RATIO,"strength":1.0,"color":Color("ffe8cd"),"dispels_fog":true})
	var protected_count:=result.size()
	var darkness:=world_clock.darkness() if world_clock!=null else 0.0
	var now:=_simulation_time
	for id in entries.keys():
		var source:Variant=entries[id].source.get_ref()
		if not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_inside_tree() or not source.is_visible_in_tree():continue
		# Player illumination is explicitly defined above, rather than the inherited 190px light.
		if player_valid and actor.is_ancestor_of(source):continue
		var config:Dictionary=entries[id].config
		var radius:=float(config.get("radius",128.0))
		var strength:=float(config.get("strength",1.0))
		var tint:Color=config.get("color",Color.WHITE)
		if source is PointLight2D:
			if not source.enabled:continue
			radius=64.0*source.texture_scale*maxf(absf(source.global_scale.x),absf(source.global_scale.y))
			strength=source.energy;tint=source.color
		if not bool(config.get("always_on",true)) and maxf(darkness,fog)<0.05:continue
		if bool(config.get("flicker",false)):
			strength*=0.94+sin(now*7.4+float(id%83))*0.04+sin(now*11.3)*0.02
		var at:Vector2=source.source_position() if source.has_method("source_position") else source.global_position
		result.append({"position":at,"radius":maxf(1,radius),"strength":clampf(strength,0,1.2),"color":tint,"dispels_fog":bool(config.get("dispels_fog",true)),"day_glow":bool(source.get_meta("day_glow",false))})
	# Preserve player and companion visibility before budgeting transient spell lights.
	if result.size()>RoomEnvironmentConfig.MAX_LIGHTS:
		var center:Vector2=actor.global_position if player_valid else Vector2.ZERO
		var transient:Array[Dictionary]=result.slice(protected_count)
		transient.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.position.distance_squared_to(center)<b.position.distance_squared_to(center))
		result.resize(mini(protected_count,RoomEnvironmentConfig.MAX_LIGHTS))
		for light in transient:
			if result.size()>=RoomEnvironmentConfig.MAX_LIGHTS:break
			result.append(light)
	return result

static func visibility_at(at:Vector2,lights:Array[Dictionary],fog_only:=false) -> float:
	var value:=0.0
	for light in lights:
		if fog_only and not bool(light.dispels_fog):continue
		var ratio:=at.distance_to(light.position)/maxf(1,float(light.radius))
		value=maxf(value,float(light.strength)*(1.0-smoothstep(0.62,1.0,ratio)))
	return clampf(value,0,1)
