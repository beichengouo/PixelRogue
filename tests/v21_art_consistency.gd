extends Node
var requests: Dictionary = {}
var lines_seen := 0
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)
func _ready() -> void:
	call_deferred("run")
func collect(value: Variant, hero: StringName, origin: String) -> void:
	if value is Dictionary:
		if value.has("text") and value.has("who"):
			var id := DialogueCast.actor(str(value.who), hero)
			if not id.is_empty() and id not in ["king", "mage", "tide", "nameless"]:
				lines_seen += 1
				var face := DialogueCast.expression(str(value.get("expression", "")), str(value.text), str(value.get("portrait", "")))
				for form: String in (["normal", "set"] if Characters.DATA.has(StringName(id)) else ["normal"]):
					var key := id + "/" + form + "/" + face
					if not requests.has(key): requests[key] = {"actor":id,"form":form,"expression":face,"locations":[],"examples":[]}
					var row: Dictionary = requests[key]
					if origin not in row.locations: row.locations.append(origin)
					if row.examples.size() < 3 and str(value.text) not in row.examples: row.examples.append(str(value.text))
		for key in value:
			if key == "choices":
				for choice in (value[key] as Array).slice(0, Story.MAX_CHOICES): collect(choice, hero, origin + "/choice")
			else: collect(value[key], hero, origin)
	elif value is Array:
		for entry in value: collect(entry, hero, origin)
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").begins_with("E:/CodexWorkspace/PixelRogue/"):
		get_tree().quit(2); return
	var ids: Array = Story.SCENES.keys()
	ids.append_array(CityStories.IDS)
	for n in range(10, 101, 10): ids.append(Story.checkpoint_id(n))
	ids.append_array([&"death_hall_intro", &"death_reenter", &"forest_king_before", &"forest_mage_before", &"forest_tide_before", &"stage_echo_entry", &"fate_observation"])
	var revised: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/narrative_v11.json"))
	ids.append_array(revised.keys())
	for hero: StringName in Characters.DATA:
		for id in ids:
			for repeated: bool in [false, true]: collect(Story.get_scene(StringName(id), repeated, hero), hero, str(hero) + "/" + str(id) + ("/repeat" if repeated else ""))
		collect(Story.random_death_line(), hero, "death/random")
		collect(CampStory.EVENTS, hero, "camp/events")
		collect(CampStory.RETURN_MEMORIES, hero, "camp/memories/replay")
		for resident: String in CampResidents.DATA:
			collect({"who":str(CampResidents.DATA[resident].name),"text":CampResidents.story_chat(resident)}, hero, "resident/" + resident)
			for category: String in ["greeting", "accepted", "finished"]:
				for text in CampResidents.DATA[resident].get(category, []):
					collect({"who":str(CampResidents.DATA[resident].name),"text":str(text)}, hero, "resident/" + resident + "/" + category)
		for step: Dictionary in CampTutorial.STEPS:
			collect({"who":"iris","text":str(step.text),"portrait":CampResidents.ROOT + "iris_" + str(step.pose) + ".png"}, hero, "camp/tutorial/" + str(step.role))
		for event_id: String in RoomExpansionController.EVENTS:
			collect({"who":"player","text":str(RoomExpansionController.REPLIES[str(hero)][event_id])}, hero, "room/event/" + event_id)
	var result: Array = []
	var keys := requests.keys(); keys.sort()
	for key in keys:
		var row: Dictionary = requests[key]
		row["path"] = DialogueCast.ROOT + str(row.actor) + ("_set" if row.form == "set" else "") + "/" + str(row.expression) + ".png"
		row["exact"] = FileAccess.file_exists(row.path)
		result.append(row)
	var f := FileAccess.open("E:/CodexWorkspace/PixelRogue/work/v21-consistency/actual-expression-usage.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"lines_seen":lines_seen,"requests":result},"\t")); f.close()
	print("ACTUAL_USAGE requests=",result.size()," lines=",lines_seen)
	var original_hero := Characters.current_id()
	var original_looks := GameState.legendary_looks.duplicate(true)
	for request: Dictionary in result:
		check(bool(request.exact),"actual request has independent file "+str(request.path))
		if not request.exact:continue
		if Characters.DATA.has(StringName(request.actor)):Characters.set_current(StringName(request.actor))
		GameState.legendary_looks = {str(request.actor):{"set":request.form=="set","weapon":true}}
		var image := Image.load_from_file(ProjectSettings.globalize_path(str(request.path)))
		check(image!=null and image.get_size()==Vector2i(1024,1536),"canonical portrait canvas "+str(request.path))
		check(image!=null and image.detect_alpha()!=Image.ALPHA_NONE,"transparent portrait "+str(request.path))
		check(DialogueCast.portrait_path(str(request.actor),str(request.expression),true)==str(request.path),"exact direct lookup, no fallback "+str(request.path))
		var head := DialogueCast.portrait(str(request.actor),str(request.expression),true,true) as AtlasTexture
		check(head!=null and Rect2(Vector2.ZERO,Vector2(1024,1536)).encloses(head.region),"head crop within canvas")
		if request.form=="set":
			check(not DialogueCast.portrait_path(str(request.actor),str(request.expression),false).contains("_set/"),"replay uses regular form")
	check(DialogueCast.portrait_path("iris","unused_future_face")==DialogueCast.ROOT+"iris/concerned.png","out-of-list fallback preserved")
	for hero: StringName in Characters.DATA:
		Characters.set_current(hero)
		GameState.legendary_looks={str(hero):{"set":true,"weapon":true,"selected":"set"}}
		check(RedrawnHeroArt.frames(hero).get_meta("set_form",false),"battle dispatcher selects unlocked set "+str(hero))
		check(LegendarySets.portrait().contains("legendary_sets_v21/"),"set illustration preview uses current resource "+str(hero))
		check(RoomHeroArt.make_frames().get_meta("set_form",false),"room dispatcher uses current set "+str(hero))
		check(HanddrawnHeroArt.frames(false,hero)!=HanddrawnHeroArt.frames(true,hero),"normal and set frames distinct")
		var animated := HanddrawnHeroArt.frames(true,hero)
		check(float(animated.get_meta("core_height"))==240.0 and int(animated.get_meta("hd_cell"))==448 and animated.get_meta("hd_foot")==Vector2(224,392),"unchanged animation geometry")
		var sprite := AnimatedSprite2D.new();sprite.sprite_frames=animated
		RoomHeroArt.align(sprite)
		check(sprite.scale.is_equal_approx(Vector2.ONE*(32.0/240.0)),"unchanged world display scale")
		check((sprite.position+(Vector2(224,392)-Vector2(224,224))*sprite.scale).is_equal_approx(Vector2(0,14)),"foot anchored at world floor")
		sprite.free()
		for direction: String in HanddrawnHeroArt.DIRECTIONS:
			check(RoomHeroArt.flip_for("attack",direction)==(direction in ["ne","e","se"]),"eight-direction mirror rule")
			for action: String in ["idle","walk","attack","move_attack","back_attack","skill_cast"]:
				var name := StringName(action+"_"+direction)
				check(animated.get_frame_count(name)==4,"frame count "+str(name))
				check(is_equal_approx(animated.get_animation_speed(name),5.0 if action=="idle" else 7.5 if action=="walk" else 12.5),"unchanged fps "+str(name))
				check(animated.get_animation_loop(name)==(action in ["idle","walk"]),"unchanged loop "+str(name))
		for spec: Array in [["prayer",8.0,true],["hurt",12.0,false],["death",5.0,false],["interact",12.5,false]]:
			check(animated.get_frame_count(spec[0])==4 and is_equal_approx(animated.get_animation_speed(spec[0]),float(spec[1])) and animated.get_animation_loop(spec[0])==bool(spec[2]),"utility interface "+str(spec[0]))
		var folder := HanddrawnHeroArt.ROOT+str(hero)+"/set/"
		var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"metadata.json"))
		for key: String in ["s","sw","w","nw","n","utility"]:
			var atlas := Image.load_from_file(ProjectSettings.globalize_path(folder+key+".png"))
			check(atlas!=null and atlas.get_size()==Vector2i(1792,1792),"4x4 atlas "+folder+key)
			if atlas==null:continue
			for index in 16:
				var used := atlas.get_region(Rect2i(index%4*448,index/4*448,448,448)).get_used_rect()
				var row: Array=metadata.bounds[key][index]
				check(used==Rect2i(int(row[0]),int(row[1]),int(row[2]),int(row[3])) and used.has_area(),"recomputed frame bounds "+key+str(index))
		var retained := animated
		HanddrawnHeroArt.clear()
		check(HanddrawnHeroArt._cache==null and HanddrawnHeroArt._materials.is_empty(),"cache cleanup releases current atlas/material")
		check(retained.get_frame_count(&"idle_s")==4,"living decoy snapshot survives cache clear")
		check(HanddrawnHeroArt.frames(true,hero)!=retained,"new preview loads after cache clear")
	Characters.set_current(&"ilyua")
	GameState.legendary_looks={"ilyua":{"set":true,"weapon":true}}
	var decoy := IlyuaDecoy.new();add_child(decoy)
	var costume := decoy.get_node_or_null("CostumeSprite") as Sprite2D
	check(costume!=null,"legendary elf decoy uses current costume sprite")
	if costume!=null:
		var atlas := costume.texture as AtlasTexture
		check(atlas!=null and atlas.atlas.resource_path==HanddrawnHeroArt.ROOT+"ilyua/set/s.png","decoy never loads old hooded spirit row")
		check((costume.position+(Vector2(224,392)-Vector2(224,224))*costume.scale).is_equal_approx(Vector2(0,14)),"decoy shares foot anchor")
	check(decoy.hp==1.0 and decoy.remaining==3.0 and decoy.collision_mask==0,"decoy gameplay remains unchanged")
	decoy.free()
	Characters.set_current(&"sylphiette")
	GameState.legendary_looks={"sylphiette":{"set":true,"weapon":true}}
	var holy_decoy := HolyDecoy.new();add_child(holy_decoy)
	var holy_sprites := holy_decoy.get_children().filter(func(child:Node)->bool:return child is Sprite2D)
	check(holy_sprites.size()==1,"holy decoy retains current battle frame")
	if not holy_sprites.is_empty():
		check((holy_sprites[0].texture as AtlasTexture).atlas.resource_path==HanddrawnHeroArt.ROOT+"sylphiette/set/s.png","holy decoy uses new hood atlas")
	holy_decoy.free()
	Characters.set_current(original_hero);GameState.legendary_looks=original_looks
	DialogueCast.clear_cache();HanddrawnHeroArt.clear()
	var report := FileAccess.open("E:/CodexWorkspace/PixelRogue/work/v21-consistency/art-regression.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"requests":result.size(),"lines":lines_seen,"atlases":18,"source_frames":288},"\t"));report.close()
	AudioManager.shutdown()
	print("V21_ART_CONSISTENCY checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

