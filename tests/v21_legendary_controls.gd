extends Node2D
class ProbeMain:
	extends "res://src/room_mode/room_main.gd"
	func _ready()->void:pass
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func key(code:int)->InputEventKey:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;return event
func _ready()->void:call_deferred("run")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/work/v21-combat-validation/"):get_tree().quit(2);return
	await get_tree().process_frame;RoomInput.install();check(KeyBindings.reset(),"reset baseline settings")
	var controller_count:=InputMap.action_get_events("dash").filter(func(e:InputEvent)->bool:return e is InputEventJoypadButton).size()
	check(KeyBindings.bind("dash",KEY_P).is_empty(),"rebind dash")
	check(key(KEY_P).is_action_pressed("dash") and not key(KEY_SHIFT).is_action_pressed("dash"),"new dash key replaces old")
	check(InputMap.action_get_events("dash").filter(func(e:InputEvent)->bool:return e is InputEventJoypadButton).size()==controller_count,"controller binding retained")
	check(not KeyBindings.bind("inventory",KEY_P).is_empty() and KeyBindings.label("inventory")=="Tab","duplicate key rejected atomically")
	check(KeyBindings.bind("ui_accept",KEY_ENTER).is_empty() and key(KEY_ENTER).is_action_pressed("ui_accept") and not key(KEY_SPACE).is_action_pressed("ui_accept"),"confirm can be remapped")
	SaveService.load_data();KeyBindings.apply();check(KeyBindings.label("dash")=="P" and KeyBindings.label("ui_accept")=="Enter","keyboard mappings survive save load")
	check(KeyBindings.reset() and KeyBindings.label("dash")=="Shift" and KeyBindings.label("ui_accept")=="空格","defaults restored")
	check(KeyBindings.bind("ui_up",KEY_W).is_empty() and key(KEY_W).is_action_pressed("ui_up"),"menu movement remaps with separate combat context")
	check(not KeyBindings.bind("ui_down",KEY_W).is_empty(),"menu directions cannot collide with each other")
	KeyBindings.reset()
	var menu:=MainMenu.new();add_child(menu);menu.open_settings();(menu._content.get_node("SettingsCategories/SettingsTab3") as Button).pressed.emit();await get_tree().process_frame;await get_tree().process_frame
	check(menu._binding_buttons.size()==KeyBindings.ACTIONS.size(),"every keyboard action has a settings row")
	var settings_scroll:=menu._content.get_node("SettingsGlass/SettingsScroll") as ScrollContainer
	check(settings_scroll.follow_focus and settings_scroll.get_v_scroll_bar().max_value>settings_scroll.size.y,"long settings remain scrollable")
	settings_scroll.ensure_control_visible(menu._binding_buttons["restart"]);await get_tree().process_frame
	var last_bounds:Rect2=menu._binding_buttons["restart"].get_global_rect()
	check(settings_scroll.get_global_rect().intersects(last_bounds) and settings_scroll.scroll_vertical>0,"last keyboard action accessible without leaving window")
	menu._binding_buttons["skill_1"].pressed.emit();menu._input(key(KEY_P))
	check(KeyBindings.label("skill_1")=="P" and menu._binding_buttons["skill_1"].text=="P","settings capture saves displayed key")
	menu._binding_buttons["inventory"].pressed.emit();menu._input(key(KEY_P))
	check(menu._binding_capture=="inventory" and menu._binding_status.text.contains("技能 1"),"settings collision explains occupied action")
	menu._input(key(KEY_ESCAPE));check(menu._binding_capture.is_empty() and KeyBindings.label("inventory")=="Tab","Esc cancels key capture without changing action")
	menu.close();menu.queue_free();KeyBindings.reset();await get_tree().process_frame
	Characters.set_current(&"ilyua");GameState.new_run(452);GameState.sortie_id="legendary_test";GameState.combat_mode="rooms"
	var main:=ProbeMain.new();add_child(main);main._build_world();main._build_ui()
	main.graph.begin(452)
	main.level.load_room({"id":"0,0","kind":"normal","biome":"forest","seed":17,"delta":{},"doors":[],"cleared":false,"terrain_layout":{"room_rect":[0,0,828,468],"props":[],"water":[],"ground":[],"decor":[],"entities":[]}})
	main._spawn_player();var actor:=main.player;actor.position=Vector2(400,230);actor.set_physics_process(false);actor.ilyua_runtime.set_physics_process(false);main.set_process(false);main.set_physics_process(false);main.director.set_process(false)
	for movement in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized()]:
		for aim in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			await get_tree().physics_frame
			actor.position=Vector2(400,230);actor.velocity=movement*180;actor.movement_override=movement;actor.aim_override=aim;actor._attack_cd=0
			actor._physics_process(1.0/60)
			var arrows:=main.fx_root.get_children().filter(func(n:Node)->bool:return n is IlyuaArrow and not n.is_queued_for_deletion())
			var arrow:=arrows.back() as IlyuaArrow;arrow.set_physics_process(false)
			check(arrow._start.distance_to(actor.global_position+aim*14)<.001,"launch uses same-frame resolved position "+str(movement)+str(aim))
			var casts:=actor.get_children().filter(func(n:Node)->bool:return n is IlyuaFX)
			check(not casts.is_empty(),"bow flash attached to moving actor")
			if not casts.is_empty():
				var flash:=casts.back() as IlyuaFX;actor.position+=movement*17
				check(flash.global_position.distance_to(actor.global_position+aim*14)<.001,"nocking flash follows movement without lag")
	actor.aim_override=Vector2.ZERO;actor.movement_override=Vector2.ZERO;actor.velocity=Vector2.ZERO
	GameState.equipment[&"accessory"]=ItemDB.by_id(&"gem_crown");actor.equipment_aura._process(.1)
	var crown:=actor.equipment_aura._crown;check(is_instance_valid(crown) and crown.get_parent()==actor,"crown is worn, attached to character")
	if is_instance_valid(crown):
		check((crown.sprite_frames.get_frame_texture(&"default",0) as AtlasTexture).atlas.resource_path.ends_with("gem_crown_v03.png"),"new filigree crown art selected")
		var before:=crown.global_position;actor.position+=Vector2(21,0);check(crown.global_position.distance_to(before+Vector2(21,0))<.001,"crown follows wearer")
		check(crown.scale.x*128<=26 and crown.position.y<=-27,"small crown above head")
	GameState.equipment[&"accessory"]={};actor.equipment_aura._process(.1);check(actor.equipment_aura._crown==null,"unequip clears worn effect")
	for phase in ["cast","flight","impact"]:
		var frames:=IlyuaFX.frames("bow_spring_wind",phase);check(frames.size()==4,"spring bow phase has four frames "+phase)
		for index in 4:
			var cell:=frames[index] as AtlasTexture
			check(cell.atlas.resource_path.ends_with("spring_wind_v03.png") and cell.region==Rect2(index*128,["cast","flight","impact"].find(phase)*128,128,128),"distinct spring phases exact crop "+phase+str(index))
	check(IlyuaFX.frames("bow_vine_short")[0].atlas.resource_path.ends_with("green_light_arrows.png"),"ordinary bow retains green arrow appearance")
	GameState.run_active=false;main.queue_free();await get_tree().process_frame;await get_tree().process_frame
	AudioManager.shutdown();await get_tree().create_timer(.5,true,true).timeout
	print("LEGENDARY_CONTROLS_REGRESSION checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
