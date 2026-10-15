extends Node
## Dedicated save-isolated copy only: clock, lifetime, shared visibility and effect budgets.
class FakeRoom extends Node2D:
	var record:Dictionary={"id":"test","seed":334,"biome":"forest"}
	var obstacles:Dictionary={}
	var deep_water:Dictionary={}
	var ground_materials:Dictionary={}
	var service_building:Variant
	var props_root:=Node2D.new()
	var decor_root:=Node2D.new()
	var shell_art:=Node2D.new()
	func _ready()->void:
		add_child(props_root);add_child(decor_root);add_child(shell_art)
	func bounds()->Rect2:return Rect2(0,0,684,396)
	func world_to_cell(at:Vector2)->Vector2i:return Vector2i((at/36).floor())
	func service_material(at:Vector2i)->String:return str(ground_materials.get(at,"grass"))
class FakeDirector extends Node:
	var boss:Variant
class FakeIntro extends Node:
	var _active:=false
class FakeMain extends Node:
	var player:CharacterBody2D
	var level:FakeRoom
	var director:FakeDirector
	var boss_intro:FakeIntro
	var room_token:=1
	var room_weather:=WeatherState.new()
class FlyingActor extends CharacterBody2D:
	func is_flying()->bool:return true
class FriendlyProbe extends Node2D:
	var hp:=100.0
	func _ready()->void:add_to_group("allies")
var checks:=0
var failures:=0
var root:Window
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("ROOM_ENVIRONMENT "+label)
func _ready()->void:
	root=get_tree().root
	call_deferred("run")
func run()->void:
	var clock:=RoomWorldClock.new();clock.setup(924)
	var duplicate:=RoomWorldClock.new();duplicate.setup(924)
	check(clock.minutes==duplicate.minutes and clock.phase()=="day","seeded new game starts within daylight")
	var start:=clock.minutes;clock.tick(1.0)
	check(is_equal_approx(clock.minutes,start+1),"one real second advances one world minute")
	clock.minutes=1439.5;clock.tick(1)
	check(is_equal_approx(clock.minutes,.5) and clock.elapsed_days==1,"midnight wraps without losing fractional minutes")
	clock.tick(2880)
	check(clock.elapsed_days==3 and is_equal_approx(clock.minutes,.5),"large delta preserves full days")
	for data in [[300.0,"dawn",1.0],[360.0,"day",0.0],[1080.0,"dusk",0.0],[1200.0,"night",1.0],[0.0,"night",1.0]]:
		clock.minutes=data[0];check(clock.phase()==data[1] and is_equal_approx(clock.darkness(),data[2]),"phase boundary "+str(data[0]))
	clock.minutes=1140;check(clock.darkness()>.49 and clock.darkness()<.51,"dusk midpoint smoothly half dark")
	clock.minutes=330;check(clock.darkness()>.49 and clock.darkness()<.51,"dawn midpoint smoothly half dark")
	clock.minutes=735.5;clock.minutes_per_second=2.0
	var restored:=RoomWorldClock.new();restored.setup(0,clock.snapshot())
	check(restored.snapshot()==clock.snapshot() and restored.time_label()=="12:15","clock state and speed round trip")
	restored.setup(42,{})
	check(restored.phase()=="day" and restored.minutes_per_second==1,"missing old save clock initializes safely")
	var main:=FakeMain.new();root.add_child(main)
	main.level=FakeRoom.new();main.add_child(main.level)
	main.player=CharacterBody2D.new();main.add_child(main.player);main.player.position=Vector2(144,144)
	main.director=FakeDirector.new();main.add_child(main.director)
	main.boss_intro=FakeIntro.new();main.add_child(main.boss_intro)
	main.room_weather.setup(142);main.room_weather.snow.fill(.7)
	var visual:=RoomWeatherVisual.new();visual.main=main;visual.weather=main.room_weather;main.add_child(visual);visual.set_process(false)
	GameState.run_active=true
	var former_boss:=Node.new();main.director.boss=former_boss;former_boss.free()
	check(visual.density()>0,"weather validates freed boss before cast")
	var former_roof:=RoomServiceProp.new();main.level.service_building=former_roof;former_roof.free()
	check(not visual.roof_rect().has_area(),"weather validates freed service prop before cast")
	check(visual.surface_snow_at(Vector2(144,144))>.1,"snow accumulates on natural ground")
	var cell:=main.level.world_to_cell(Vector2(144,144))
	for material in ["stone","wood","carpet","cobble"]:
		main.level.ground_materials[cell]=material
		check(visual.surface_snow_at(Vector2(144,144))==0,"no snow footprints on "+material)
	main.level.ground_materials.clear();main.level.deep_water[cell]=true
	check(visual.surface_snow_at(Vector2(144,144))==0,"no footprints on water")
	main.level.deep_water.clear();visual._tick_footprints(0)
	main.player.velocity=Vector2(60,0);main.player.position.x+=21;visual._tick_footprints(.35)
	check(visual.footprints.size()==1,"moving player creates one spaced snow footprint")
	main.player.position.x+=2;visual._tick_footprints(.03)
	check(visual.footprints.size()==1,"small movements do not form a continuous line")
	main.player.position.x+=150;visual._tick_footprints(.1)
	check(visual.footprints.size()==1,"teleports do not create a footprint trail")
	var flyer:=FlyingActor.new();main.add_child(flyer);flyer.add_to_group("enemies")
	flyer.position=Vector2(80,80);flyer.velocity=Vector2(60,0)
	visual._tick_footprints(0);flyer.position.x+=40;visual._tick_footprints(.1)
	check(visual.footprints.size()==1,"flying monsters never generate footprints")
	visual._tick_footprints(13)
	check(visual.footprints.is_empty(),"footprints expire after configured lifetime")
	for index in 300:visual.spawn_drop(Vector2(40,40),index%2==0)
	check(visual.drops.size()==RoomEnvironmentConfig.MAX_DROPS,"precipitation pool bounded")
	for index in 150:visual.land(visual.drops[0])
	check(visual.impacts.size()==RoomEnvironmentConfig.MAX_IMPACTS,"impact pool bounded")
	for index in 200:
		main.player.position=Vector2(342,198)+Vector2.RIGHT.rotated(index*.26)*84
		visual._tick_footprints(.01)
	check(visual.footprints.size()==RoomEnvironmentConfig.MAX_FOOTPRINTS,"footprint pool evicts oldest at configured cap")
	main.room_token+=1;visual._process(.01)
	check(visual.footprints.is_empty(),"room change clears historical footprints")
	var field:=RoomLightField.new()
	var light:=Node2D.new();main.add_child(light);light.position=Vector2(450,144)
	field.register(light,{"radius":90.0,"strength":1.0,"color":Color.WHITE,"dispels_fog":false})
	clock.minutes=0
	var sources:=field.sources(main,clock,1)
	check(sources.size()==2 and sources[0].radius==144,"shared field includes guaranteed player radius and registered light")
	check(RoomLightField.visibility_at(main.player.global_position,sources)==1,"player remains readable")
	check(RoomLightField.visibility_at(Vector2(680,380),sources)==0,"outside light radius all world content is obscured")
	check(RoomLightField.visibility_at(light.position,sources)>0 and RoomLightField.visibility_at(light.position,sources,true)==0,"non-clearing lamp lights night but leaves fog intact")
	var id:=light.get_instance_id();light.free();field.refresh(main,1)
	check(not field.entries.has(id),"freed sources are removed from weak registry")
	for kind:String in RoomEnvironmentConfig.LIGHT_KINDS:
		var lamp:=RoomLightProp.new();lamp.kind=kind
		check(lamp.light_config().radius==RoomEnvironmentConfig.LIGHTS[kind].radius,"authored radius preset "+kind)
		lamp.configure({"kind":kind,"radius":72,"strength":.4,"dispels_fog":false,"always_on":false,"flicker":false})
		check(lamp.light_config().radius==72 and not lamp.light_config().dispels_fog,"editable light parameters "+kind)
		lamp.free()
	for size:Vector2i in RoomEnvironmentConfig.LIGHT_SIZES:
		var lamp:=RoomLightProp.new();lamp.kind="torch";lamp.footprint=size;main.add_child(lamp)
		var path:="res://assets/room_mode/lights/torch_%dx%d.png"%[size.x,size.y]
		if ResourceLoader.exists(path):
			check(lamp.art.texture.get_size()*lamp.art.scale==Vector2(size)*36,"dedicated lamp matches actual footprint "+str(size))
		lamp.free()
	var env:=RoomEnvironmentVisual.new();env.main=main;env.world_clock=clock;main.add_child(env);env.set_process(false)
	main.room_weather.kind="fog";main.room_weather.previous="fog";main.room_weather.blend=1
	env._process(1)
	check(env.fog_density>0 and env.fog_density<.1 and env.layer<10,"fog begins thin below HUD")
	env._process(RoomEnvironmentConfig.FOG_BUILD_SECONDS)
	check(env.fog_density==1,"dense fog reaches white independently of early-wave intensity")
	check(env.shade.mouse_filter==Control.MOUSE_FILTER_IGNORE,"environment cannot intercept UI input")
	var env_saved:=env.snapshot();env.fog_density=0;env.restore(env_saved)
	check(env.fog_density==1,"fog concentration round trips for run resume")
	main.room_weather.kind="clear";main.room_weather.previous="clear"
	env._process(RoomEnvironmentConfig.FOG_CLEAR_SECONDS)
	check(env.fog_density==0,"fog clears smoothly within configured duration")
	if DisplayServer.get_name()!="headless":await render_checks(main,env,clock)
	main.director.free();main.boss_intro.free()
	check(visual.density()>0,"weather density tolerates destroyed director and intro")
	main.player.free();visual._process(.01);visual._draw()
	check(not visual.world_valid(),"weather stops safely after player destruction")
	visual.reparent(root);main.free();visual._process(.01);visual._draw()
	check(not visual.world_valid(),"detached weather tolerates a freed main owner")
	visual.free();visual=null
	GameState.run_active=false
	print("ROOM_ENVIRONMENT checks=",checks," failures=",failures)
	AudioManager.shutdown()
	await get_tree().create_timer(.15,true).timeout
	get_tree().quit(0 if failures==0 else 1)

func render_checks(main:FakeMain,env:RoomEnvironmentVisual,clock:RoomWorldClock)->void:
	# An unshaded test-world card proves that the final composite covers snow and spell materials.
	var world:=ColorRect.new();world.position=Vector2.ZERO;world.size=Vector2(1280,720);world.z_index=-100
	var shader:=Shader.new();shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){COLOR=vec4(0.2,0.6,0.3,1.0);}"
	var material:=ShaderMaterial.new();material.shader=shader;world.material=material;main.add_child(world)
	var warning:=ColorRect.new();warning.position=Vector2(950,380);warning.size=Vector2(80,80);warning.color=Color("ff3281");warning.z_index=4090;main.add_child(warning)
	var hud:=CanvasLayer.new();hud.layer=10;main.add_child(hud)
	var badge:=ColorRect.new();badge.position=Vector2(1100,20);badge.size=Vector2(100,80);badge.color=Color("3388ff");hud.add_child(badge)
	main.player.position=Vector2(144,144)
	clock.minutes=0;env.fog_density=0;env._process(0)
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	check(image.get_pixel(990,420).r<.02,"GL final night composite hides highest-z enemy warning")
	check(image.get_pixel(1000,500).g<.02,"GL night covers unshaded world outside lamps")
	check(image.get_pixel(144,144).g>.45,"GL player light preserves its visible area")
	check(image.get_pixel(1150,40).b>.9,"GL night does not dim HUD")
	var friend:=FriendlyProbe.new();friend.position=Vector2(650,420);main.add_child(friend)
	env._process(0);await RenderingServer.frame_post_draw
	image=get_viewport().get_texture().get_image()
	var friend_radius:=0.0
	for light in env.lights:
		if light.position==friend.global_position:friend_radius=float(light.radius)
	check(is_equal_approx(friend_radius,RoomEnvironmentConfig.PLAYER_LIGHT_RADIUS*.5),"Friendly light radius exactly half of player")
	check(image.get_pixel(650,420).g>.45 and image.get_pixel(723,420).g<.02,"GL friendly self light covers own center but not beyond half radius")
	friend.position=Vector2(850,420);env._process(0);await RenderingServer.frame_post_draw
	image=get_viewport().get_texture().get_image()
	check(image.get_pixel(650,420).g<.02 and image.get_pixel(850,420).g>.45,"GL friendly light follows movement without trail")
	friend.hp=0;env._process(0);await RenderingServer.frame_post_draw
	image=get_viewport().get_texture().get_image()
	check(image.get_pixel(850,420).g<.02,"GL dead friendly unit stops emitting immediately")
	friend.queue_free();await get_tree().process_frame
	clock.minutes=720;env._process(0)
	await RenderingServer.frame_post_draw
	image=get_viewport().get_texture().get_image()
	check(absf(image.get_pixel(1000,500).g-.6)<.03,"GL daylight keeps the authored world color")
	clock.minutes=0;env.fog_density=1;main.room_weather.kind="fog";main.room_weather.previous="fog";env._process(0)
	await RenderingServer.frame_post_draw
	image=get_viewport().get_texture().get_image()
	var covered:=image.get_pixel(990,420)
	check(covered.r<.02 and covered.g<.02 and covered.b<.02,"GL night takes priority over dense fog and hides warnings in black")
	check(image.get_pixel(144,144).g>.45 and image.get_pixel(144,144).r<.5,"GL shared player lamp clears fog while lighting night")
	check(image.get_pixel(1150,40).b>.9 and image.get_pixel(1150,40).r<.3,"GL dense fog leaves HUD colors unchanged")
	var edge:=image.get_pixel(260,144)
	check(edge.g>.02 and edge.g<.95,"GL light edge transitions smoothly into black foggy night")
	image.save_png("E:/CodexWorkspace/PixelRogue/temp/fog-night-priority.png")
	clock.minutes=720;env._process(0)
	await RenderingServer.frame_post_draw
	image=get_viewport().get_texture().get_image();covered=image.get_pixel(990,420)
	check(covered.r>.97 and covered.g>.97 and covered.b>.97,"GL daylight dense fog remains white outside lamps")
	check(image.get_pixel(144,144).g>.45 and image.get_pixel(1150,40).b>.9,"GL daytime fog preserves player light and HUD")
	world.queue_free();warning.queue_free();hud.queue_free()
