class_name RoomWeatherVisual
extends Node2D
## A virtual fall height projects precipitation onto the top-down ground plane.
## Bounded data pools, no particle nodes. Only a completed fall emits a contact.
const NAMES:={"clear":"晴朗","rain":"小雨","storm":"风雨","fog":"雾","snow":"降雪"}
const RAIN_DIRECTION:=Vector2(-0.3303504,0.9438584)
const SNOW_DIRECTION:=Vector2(0.2148618,0.9766445)
const RAIN_ART_DIRECTIONS:=[Vector2(-1,3),Vector2(-3,7),Vector2(-3,5)]
const RAIN_ART_TIPS:=[Vector2(3.5,5.5),Vector2(2.5,7.5),Vector2(2.5,6.5)]
var weather:WeatherState
var main
var drops:Array[Dictionary]=[]
var impacts:Array[Dictionary]=[]
var _random:=RandomNumberGenerator.new()
var _credit:=0.0
var _room_id:=""
var _refresh:=0.0
var _rain_frames:Array[AtlasTexture]=[]
var _contact_frames:Array[AtlasTexture]=[]
var _snow_frames:Array[AtlasTexture]=[]
var _rain_audio:AudioStreamPlayer
var _rain_gain:=0.0
var contacts:=0
var footprints:Array[Dictionary]=[]
var _tracks:Dictionary={}
var _footprint_batch:MultiMeshInstance2D
func _ready()->void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	z_index=15
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_rain_frames=WeatherSurfaceArt.particle_frames("Rain")
	_contact_frames=WeatherSurfaceArt.particle_frames("RainOnFloor")
	_snow_frames=WeatherSurfaceArt.particle_frames("Snow")
	_rain_audio=AudioStreamPlayer.new();_rain_audio.name="WeatherRainAmbience"
	_rain_audio.stream=EnvironmentAudio.sound("rain");_rain_audio.volume_db=-80
	add_child(_rain_audio)
	_build_footprint_batch()
func _sync_rain_audio(dt:float,rain:float)->void:
	_rain_gain=move_toward(_rain_gain,clampf(rain,0,1),dt*.65)
	if _rain_gain<=.001:
		if _rain_audio.playing:_rain_audio.stop()
		return
	_rain_audio.volume_db=linear_to_db(maxf(.0001,_rain_gain*.28*AudioManager.sfx_volume()))
	if not _rain_audio.playing:_rain_audio.play()
func _build_footprint_batch()->void:
	var mesh:=QuadMesh.new();mesh.size=Vector2(6,3.3)
	var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_2D;instances.use_colors=true
	instances.mesh=mesh;instances.instance_count=RoomEnvironmentConfig.MAX_FOOTPRINTS;instances.visible_instance_count=0
	_footprint_batch=MultiMeshInstance2D.new();_footprint_batch.name="SnowFootprints";_footprint_batch.multimesh=instances;_footprint_batch.z_index=-1
	var material:=ShaderMaterial.new();material.shader=load("res://src/room_mode/room_footprint.gdshader");_footprint_batch.material=material
	add_child(_footprint_batch)

func _sync_footprint_batch()->void:
	if not is_instance_valid(_footprint_batch):return
	var instances:=_footprint_batch.multimesh;instances.visible_instance_count=mini(footprints.size(),RoomEnvironmentConfig.MAX_FOOTPRINTS)
	for index in instances.visible_instance_count:
		var footprint:Dictionary=footprints[index]
		var alpha:float=(1.0-smoothstep(0.35,1.0,float(footprint.age)/RoomEnvironmentConfig.FOOTPRINT_LIFETIME))*0.48
		instances.set_instance_transform_2d(index,Transform2D(float(footprint.angle),footprint.position))
		instances.set_instance_color(index,Color(.18,.24,.29,alpha))
	_footprint_batch.visible=GameState.run_active and world_valid()

func world_valid()->bool:
	if not is_instance_valid(main) or main.is_queued_for_deletion():return false
	if not is_instance_valid(main.level) or main.level.is_queued_for_deletion():return false
	if not is_instance_valid(main.level.props_root) or not is_instance_valid(main.level.decor_root):return false
	return is_instance_valid(main.player) and not main.player.is_queued_for_deletion()
func density()->float:
	var value:=0.35 if ComicMotion.reduced() else 1.0
	value*=[0.4,0.7,1.0][clampi(int(SaveService.data.get("environment_quality",2)),0,2)]
	if not is_instance_valid(main) or main.is_queued_for_deletion():return value
	if is_instance_valid(main.boss_intro) and not main.boss_intro.is_queued_for_deletion() and main.boss_intro._active:value*=0.4
	if is_instance_valid(main.director) and not main.director.is_queued_for_deletion():
		# A stale Object cannot even be cast: validate before checking its class.
		var candidate:Variant=main.director.boss
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion() and candidate is RoomBoss:
			if candidate.room_windup>0:value*=0.45
	return value
func roof_rect()->Rect2:
	if not world_valid():return Rect2()
	var candidate:Variant=main.level.service_building
	if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate is RoomServiceProp:return Rect2()
	var building:RoomServiceProp=candidate
	if not is_instance_valid(building.art):return Rect2()
	return art_rect(building.art)
func art_rect(sprite:Sprite2D)->Rect2:
	if not is_instance_valid(sprite) or sprite.is_queued_for_deletion():return Rect2()
	var rect:=sprite.get_rect()
	return Rect2(sprite.global_position+rect.position*sprite.global_scale,rect.size*sprite.global_scale)
func sample_surface(at:Vector2)->Dictionary:
	if not world_valid():return {"position":at,"material":"stone"}
	var roof:=roof_rect()
	if roof.has_point(at):
		return {"position":Vector2(at.x,roof.position.y+roof.size.y*0.35),"material":"roof"}
	var cell:Vector2i=main.level.world_to_cell(at)
	# Props catch precipitation before the ground beneath their solid footprint.
	for prop in main.level.props_root.get_children():
		if not is_instance_valid(prop) or prop.is_queued_for_deletion() or not prop is RoomProp or not is_instance_valid(prop.art):continue
		var on_prop:bool=Rect2i(prop.cell,prop.footprint).has_point(cell) if prop.scene_object_id.is_empty() else (prop.collision_polygon.size()>=3 and Geometry2D.is_point_in_polygon(at,main.level.scene_polygons.get(prop.scene_object_id,PackedVector2Array())))
		if on_prop:
			var top:=art_rect(prop.art)
			return {"position":Vector2(clampf(at.x,top.position.x+3,top.end.x-3),top.position.y+top.size.y*.2),"material":"wood" if prop.prop_kind=="crate" else "stone"}
	if main.level.water_surface_at(at):return {"position":at,"material":"water"}
	var material:String=main.level.service_material(cell)
	return {"position":at,"material":"grass" if material.is_empty() or material=="garden" else material}
func spawn_drop(at:Vector2,snowflake:bool,height:=120.0)->void:
	if drops.size()>=RoomEnvironmentConfig.MAX_DROPS or not world_valid():return
	var hit:=sample_surface(at)
	var direction:=SNOW_DIRECTION if snowflake else RAIN_DIRECTION
	drops.append({"position":hit.position-direction*height,"contact":hit.position,"height":height,"snow":snowflake,"material":hit.material})
func land(drop:Dictionary)->void:
	contacts+=1
	if impacts.size()>=RoomEnvironmentConfig.MAX_IMPACTS:impacts.pop_front()
	var water:bool=drop.material=="water"
	var row:=1 if water else (2 if drop.snow else (3 if drop.material in ["roof","wood"] else 0))
	impacts.append({"position":drop.contact,"material":drop.material,"row":row,"age":0.0,"life":0.65 if water else 0.34,"snow":drop.snow})
func _process(dt:float)->void:
	if world_valid() and bool(main.level.record.get("indoor",false)):
		drops.clear();impacts.clear();footprints.clear();_sync_rain_audio(dt,0);queue_redraw();return
	if weather==null or not world_valid() or not GameState.run_active:
		if is_instance_valid(_footprint_batch):_footprint_batch.hide()
		if is_instance_valid(_rain_audio):_rain_audio.stop()
		_rain_gain=0.0
		return
	var current:=str(main.level.record.get("id",""))+":"+str(main.room_token)
	if current!=_room_id:
		_room_id=current;drops.clear();impacts.clear();footprints.clear();_tracks.clear();_credit=0;_refresh=0
		_random.seed=int(main.level.record.get("seed",0))^72514
	var rain:=weather.amount("rain")+weather.amount("storm")
	_sync_rain_audio(dt,rain)
	var snowfall:=weather.amount("snow")
	var bounds:Rect2=main.level.bounds()
	_credit=minf(24,_credit+dt*(rain*RoomEnvironmentConfig.RAIN_RATE+snowfall*RoomEnvironmentConfig.SNOW_RATE)*density()*bounds.size.x/828.0)
	var budget:=mini(24,int(_credit));_credit-=budget
	for i in budget:
		spawn_drop(Vector2(_random.randf_range(bounds.position.x,bounds.end.x),_random.randf_range(bounds.position.y,bounds.end.y)),_random.randf()<snowfall/maxf(.001,rain+snowfall),_random.randf_range(70,160))
	for i in range(impacts.size()-1,-1,-1):
		impacts[i].age+=dt
		if impacts[i].age>=impacts[i].life:impacts.remove_at(i)
	for i in range(drops.size()-1,-1,-1):
		var drop:=drops[i]
		var speed:=48.0 if drop.snow else 360.0+weather.amount("storm")*180
		var direction:=SNOW_DIRECTION if drop.snow else RAIN_DIRECTION
		drop.height=maxf(0,drop.height-dt*speed)
		drop.position=drop.contact-direction*drop.height
		if drop.height<=0:land(drop);drops.remove_at(i)
	_tick_footprints(dt)
	_sync_footprint_batch()
	_refresh-=dt
	if _refresh<=0:
		_refresh=.1
		var sector:=clampi(["forest","settlement","wetland","ruin"].find(str(main.level.record.get("biome","forest"))),0,3)
		var snow:float=weather.snow[sector];var wet:float=weather.wetness[sector]
		WeatherSurfaceArt.apply(main.level,snow,wet,true)
		if main.level.illustration!=null and main.level.illustration.active():main.level.illustration.apply_weather(snow,wet)
		if is_instance_valid(main.level.shell_art):WeatherSurfaceArt.apply(main.level.shell_art,snow,wet)
		var floor_layer:=main.level.get_node_or_null("FloorTiles") as CanvasItem
		if floor_layer!=null:WeatherSurfaceArt.apply(floor_layer,snow,wet,true)
		for prop in main.level.props_root.get_children():
			if is_instance_valid(prop) and not prop.is_queued_for_deletion() and prop is RoomProp and is_instance_valid(prop.art):WeatherSurfaceArt.apply(prop.art,snow,wet)
		for prop in main.level.decor_root.get_children():
			if not is_instance_valid(prop) or prop.is_queued_for_deletion():continue
			if prop is RoomServiceProp and is_instance_valid(prop.art):WeatherSurfaceArt.apply(prop.art,snow,wet)
			elif prop is Sprite2D:WeatherSurfaceArt.apply(prop,snow,wet)
		for chest in get_tree().get_nodes_in_group("chests"):
			if not is_instance_valid(chest) or chest.is_queued_for_deletion():continue
			var sprite:Variant=chest.get("_sprite")
			if is_instance_valid(sprite) and sprite is Sprite2D:WeatherSurfaceArt.apply(sprite,snow,wet)
	queue_redraw()
func surface_snow_at(at:Vector2)->float:
	if not RoomEnvironmentConfig.SNOW_ACCUMULATION_ENABLED:return 0.0
	if weather==null or not world_valid():return 0.0
	var cell:Vector2i=main.level.world_to_cell(at)
	if not main.level.bounds().has_point(at) or main.level.water_surface_at(at) or main.level.obstacles.has(cell):return 0.0
	for polygon:PackedVector2Array in main.level.scene_polygons.values():
		if Geometry2D.is_point_in_polygon(at,polygon):return 0.0
	if roof_rect().has_point(at):return 0.0
	var material:String=main.level.service_material(cell)
	if material not in ["","grass","garden","mud","earth","dirt"]:return 0.0
	var sector:=clampi(["forest","settlement","wetland","ruin"].find(str(main.level.record.get("biome","forest"))),0,3)
	return weather.snow[sector]
func _tick_footprints(dt:float)->void:
	if not RoomEnvironmentConfig.SNOW_ACCUMULATION_ENABLED:
		footprints.clear();_tracks.clear()
		return
	for index in range(footprints.size()-1,-1,-1):
		footprints[index].age+=dt
		if footprints[index].age>=RoomEnvironmentConfig.FOOTPRINT_LIFETIME:footprints.remove_at(index)
	var actors:Array=[main.player]
	actors.append_array(get_tree().get_nodes_in_group("enemies"))
	var living:Dictionary={}
	for actor in actors:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor is CharacterBody2D:continue
		if actor is EnemyBase and actor._dead:continue
		if actor.has_method("is_flying") and actor.is_flying():continue
		if actor is EnemyBase and actor.kind==&"flyer":continue
		var id:int=actor.get_instance_id();living[id]=true
		var at:Vector2=actor.global_position+Vector2(0,8)
		var track:Dictionary=_tracks.get(id,{"position":at,"distance":0.0,"side":1.0})
		var moved:float=at.distance_to(track.position)
		var snowy:=surface_snow_at(at)>RoomEnvironmentConfig.FOOTPRINT_SNOW_THRESHOLD
		if moved>RoomEnvironmentConfig.FOOTPRINT_TELEPORT_DISTANCE or not snowy:
			track.distance=0.0
		elif moved>0.2 and actor.velocity.length()>2:
			track.distance+=moved
			if track.distance>=RoomEnvironmentConfig.FOOTPRINT_DISTANCE:
				track.distance=fmod(track.distance,RoomEnvironmentConfig.FOOTPRINT_DISTANCE)
				var heading:Vector2=(at-track.position).normalized()
				if footprints.size()>=RoomEnvironmentConfig.MAX_FOOTPRINTS:footprints.pop_front()
				footprints.append({"position":at+heading.orthogonal()*3.0*float(track.side),"angle":heading.angle(),"age":0.0})
				track.side=-float(track.side)
		track.position=at;_tracks[id]=track
	for id in _tracks.keys():
		if not living.has(id):_tracks.erase(id)
func _draw()->void:
	if weather==null or not world_valid() or not GameState.run_active:return
	var bounds:Rect2=main.level.bounds()
	var rain:=weather.amount("rain")+weather.amount("storm")
	if rain>0:draw_rect(bounds,Color(.24,.42,.58,rain*.07))
	for drop in drops:
		if drop.snow:
			if _snow_frames.is_empty():continue
			var frame:=posmod(int(weather.time*8)+int(drop.contact.x+drop.contact.y),_snow_frames.size())
			draw_texture_rect(_snow_frames[frame],Rect2(drop.position-Vector2.ONE*5,Vector2.ONE*10),false,Color(.94,.98,1,RoomEnvironmentConfig.SNOW_ALPHA))
		else:
			if _rain_frames.is_empty():continue
			# Align each inspected source streak to the fixed physical direction
			# and anchor its final opaque pixel at the simulated falling head.
			var frame:=posmod(int(drop.contact.x+drop.contact.y),_rain_frames.size())
			var art_direction:Vector2=RAIN_ART_DIRECTIONS[frame]
			var angle:float=RAIN_DIRECTION.angle()-art_direction.angle()
			var anchor:Vector2=RAIN_ART_TIPS[frame]*1.5
			draw_set_transform(drop.position,angle)
			draw_texture_rect(_rain_frames[frame],Rect2(-anchor+Vector2(1,0),Vector2(12,12)),false,Color(.12,.26,.40,.70))
			draw_texture_rect(_rain_frames[frame],Rect2(-anchor,Vector2(12,12)),false,Color(.26,.72,1,RoomEnvironmentConfig.RAIN_ALPHA))
			draw_set_transform(Vector2.ZERO)
	for hit in impacts:
		var frames:Array[AtlasTexture]=_snow_frames if hit.snow and hit.material!="water" else _contact_frames
		if frames.is_empty():continue
		var frame:=clampi(int(hit.age/hit.life*frames.size()),0,frames.size()-1)
		var size:=Vector2(13,8) if hit.material=="water" else Vector2(9,9)
		if hit.snow and hit.material=="water":size*=.5
		draw_texture_rect(frames[frame],Rect2(hit.position-size*.5,size),false,Color(.72,.88,1,.65) if not hit.snow else Color(1,1,1,.65))
	# Fog belongs to the final shared-light environment composite, never a second veil here.
	var clear:=weather.amount("clear")
	for i in int(24*clear*density()):
		var at:=bounds.position+Vector2(fposmod(i*93.73+sin(weather.time*.2+i)*8,bounds.size.x),fposmod(i*51.27+cos(weather.time*.3+i)*6,bounds.size.y))
		draw_circle(at,.8,Color(.79,.92,.64,.3+sin(weather.time*1.3+i)*.18))
