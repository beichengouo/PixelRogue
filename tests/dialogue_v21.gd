extends Node
## Run only in the existing E: QA project with isolated APPDATA/LOCALAPPDATA.
const AUDIT_PATH := "E:/CodexWorkspace/PixelRogue/work/dialogue-v21-followup/portrait-audit.json"
var checks := 0
var failures := 0
var speakers: Dictionary = {}
var audit: Dictionary = {"matrix":[], "speakers":{}}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)

func frames(count := 3) -> void:
	for index in count: await get_tree().process_frame

func settled() -> void:
	# Headless frame counts do not measure the dismissal tween's wall time.
	await get_tree().create_timer(.12, true, false, true).timeout
	await frames()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func run() -> void:
	var user_dir := OS.get_user_data_dir().replace("\\", "/")
	if not user_dir.begins_with("E:/CodexWorkspace/PixelRogue/"):
		printerr("Unsafe user directory: ", user_dir)
		get_tree().quit(1)
		return
	print("DIALOGUE_V21_USER_DIR=", user_dir)
	ErrorReporter.interactive = false
	AchievementTracker.set_process(false)
	SaveService.data.reduced_motion = true
	Outpost.set_process(false)
	Outpost.pending_checkpoint = false
	await frames()
	normalization_checks()
	audit_resources()
	await presentation_checks()
	optional_set_art_checks()
	await local_transaction_checks()
	await restore_checks()
	var file := FileAccess.open(AUDIT_PATH, FileAccess.WRITE)
	check(file != null, "audit can be written")
	audit["checks"] = checks
	audit["failures"] = failures
	if file != null:
		file.store_string(JSON.stringify(audit, "\t"))
		file.close()
	AudioManager.shutdown()
	await get_tree().create_timer(.25, true, false, true).timeout
	await frames()
	print("DIALOGUE_V21 checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)

func normalization_checks() -> void:
	var source := [{"who":"", "text":"旁白"}, {"who":"iris", "text":"对白", "expression":"sad"}]
	var normalized := CampStory.dialogue_lines(source)
	check(normalized[0].who == "", "empty speaker remains narration")
	check(normalized[1].who == "iris" and normalized[1].expression == "sad", "explicit actor and expression preserved")
	normalized[0].text = "changed"
	check(source[0].text == "旁白", "normalization does not mutate authored data")
	check(CampStory.dialogue_lines("旧旁白") == [{"who":"", "text":"旧旁白"}], "legacy scalar prose remains narration")
	check(CampStory.dialogue_lines(["旧旁白"])[0].who == "", "legacy array prose remains narration")
	check(CampStory.dialogue_lines([]).is_empty(), "empty lines remain empty")
	for id: String in DialogueCast.NAMES:
		check(DialogueCast.actor(id) == id and DialogueCast.actor(DialogueCast.NAMES[id]) == id, "actor ID/name aliases " + id)
	check(DialogueCast.actor("") == "" and DialogueCast.actor("契约者") == "", "narrator and contractor have no battle actor")
	check(DialogueCast.actor("player", &"ilyua") == "ilyua", "legacy player alias uses explicit hero")
	check(DialogueCast.actor("希露提雅") == "sylphiette" and DialogueCast.actor("希露媞娅") == "sylphiette", "historical spelling aliases")
	check(DialogueCast.actor("执印巡卫·塞芙菈") == "sephra" and DialogueCast.actor("千页司书·维蕾娜") == "verena", "full boss title aliases")
	for hero: StringName in Characters.DATA:
		for path: String in Characters.DATA[hero].dialogue_portraits.values():
			check(ResourceLoader.exists(path), "declared hero differential exists " + path)
	for owner: String in CampStory.EVENTS:
		for event: Dictionary in CampStory.EVENTS[owner]:
			for line: Dictionary in CampStory.dialogue_lines(event.lines):
				check(line.who in ["", owner, "契约者"], "authored camp speaker " + owner + ":" + str(event.id))
			for option: Dictionary in event.get("choices", []):
				check(option.get("reply", []) is Array, "choice reply is dialogue array")
	var memory := CampStory.RETURN_MEMORIES.sylphiette.awakening_woods
	check(memory.lines.any(func(entry:Dictionary)->bool:return str(entry.who)=="iris") and memory.lines.any(func(entry:Dictionary)->bool:return str(entry.who)=="sylphiette"), "chapter memory alternates Iris and hero")
	check(CampStory.EVENTS.iris[1].lines[1].who == "契约者", "contractor question is not assigned to Iris")

func audit_resources() -> void:
	for id: String in DialogueCast.NAMES:
		for form: String in (["normal", "set"] if Characters.DATA.has(StringName(id)) else ["normal"]):
			var root := DialogueCast.ROOT + id + ("_set" if form == "set" else "") + "/"
			for face: String in DialogueCast.EXPRESSIONS:
				var path := ""
				var status := "missing"
				if ResourceLoader.exists(root + face + ".png"):
					path = root + face + ".png"
					status = "exact"
				else:
					var mapped := "happy" if face == "happy" else "neutral" if face == "neutral" else "concerned"
					if ResourceLoader.exists(root + mapped + ".png"):
						path = root + mapped + ".png"
						status = "mapped"
					elif ResourceLoader.exists(root + "neutral.png"):
						path = root + "neutral.png"
						status = "neutral"
				audit.matrix.append({"actor":id, "form":form, "expression":face, "status":status, "path":path})
	var ids: Array = Story.SCENES.keys()
	ids.append_array(CityStories.IDS)
	for checkpoint in range(10, 101, 10): ids.append(Story.checkpoint_id(checkpoint))
	ids.append_array([&"death_hall_intro", &"death_reenter", &"forest_king_before", &"forest_mage_before", &"forest_tide_before", &"stage_echo_entry", &"fate_observation"])
	var revised: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/narrative_v11.json"))
	if revised is Dictionary: ids.append_array(revised.keys())
	for hero: StringName in Characters.DATA:
		for id in ids:
			for repeated: bool in [false, true]: collect_speakers(Story.get_scene(StringName(id), repeated, hero), str(hero) + ":" + str(id))
	collect_speakers(CampStory.EVENTS, "camp")
	collect_speakers(CampStory.RETURN_MEMORIES, "memories")
	for id: String in CampResidents.DATA:
		# Resident data is converted to explicit actors by CampResidentPanel._talk.
		collect_speakers({"who":str(CampResidents.DATA[id].name), "text":CampResidents.story_chat(id)}, "resident:" + id)
	audit.speakers = speakers
	audit["note"] = "exact=independent named expression; mapped=legacy concerned art; neutral=neutral fallback; missing=no V21 portrait. Contractor is intentionally unillustrated."

func collect_speakers(value: Variant, location: String) -> void:
	if value is Dictionary:
		if value.has("who") and value.has("text"):
			var who := str(value.who)
			var record: Dictionary = speakers.get(who, {"count":0, "actor":DialogueCast.actor(who), "locations":[]})
			record.count += 1
			if location not in record.locations: record.locations.append(location)
			speakers[who] = record
		for key in value: collect_speakers(value[key], location)
	elif value is Array:
		for entry in value: collect_speakers(entry, location)

func presentation_checks() -> void:
	var dialogue := DialogueUI.new()
	add_child(dialogue)
	await frames()
	dialogue.play_local_lines(CampStory.dialogue_lines(["旁白", {"who":"iris", "text":"谢谢"}, {"who":"契约者", "text":"我会等待。"}]))
	check(dialogue._name_label.text == "旅途纪事" and not dialogue._face_art.visible and not dialogue._goddess_art.visible, "narration has no borrowed actor portrait")
	dialogue._show_line(1)
	check(dialogue._actor_id == "iris" and dialogue._name_label.text == "伊莉丝", "IDs display localized speaker names")
	check(dialogue._face_art.texture != null and dialogue._goddess_art.texture != null, "existing speaker has portrait and thumbnail")
	var crop := dialogue._face_art.texture as AtlasTexture
	check(crop != null and crop.atlas != null and Rect2(Vector2.ZERO, crop.atlas.get_size()).encloses(crop.region), "thumbnail crop remains within source")
	if crop != null:
		check(crop.region.size == crop.atlas.get_size() * Vector2(.68, .48), "thumbnail uses V21 head framing")
	dialogue._show_line(2)
	check(dialogue._name_label.text == "契约者" and not dialogue._face_art.visible and not dialogue._goddess_art.visible, "contractor keeps own name without a borrowed hero model")
	dialogue.cancel()
	for hero: StringName in Characters.DATA:
		Characters.set_current(hero)
		GameState.legendary_looks = {}
		check(not DialogueCast.set_form(str(hero)), "locked costume stays normal " + str(hero))
		GameState.legendary_looks[str(hero)] = {"weapon":true, "set":false, "selected":"set"}
		check(not DialogueCast.set_form(str(hero)), "portrait carousel cannot grant costume " + str(hero))
		GameState.legendary_looks[str(hero)] = {"weapon":true, "set":true, "selected":"weapon"}
		GameState.equipment = {}
		check(DialogueCast.set_form(str(hero)), "run unlock survives removing equipment and carousel changes " + str(hero))
		check(DialogueCast.portrait_path(str(hero)).contains("/" + str(hero) + "_set/"), "live dialogue uses unlocked costume " + str(hero))
		check(not DialogueCast.set_form(str(hero), false), "review ignores current run costume " + str(hero))
		check(not DialogueCast.portrait_path(str(hero), "neutral", false).contains("_set/"), "review portrait is normal " + str(hero))
		var other := "ilyua" if hero != &"ilyua" else "sylphiette"
		GameState.legendary_looks[other] = {"set":true}
		check(not DialogueCast.set_form(other), "off-run actor does not inherit costume " + other)
		var texture := DialogueCast.portrait(str(hero), "neutral", true, true)
		check(texture != null, "set-form thumbnail exists " + str(hero))
	check(DialogueCast.portrait_path("unknown") == "" and DialogueCast.portrait("unknown") == null, "unknown actor returns no fictional path")
	for id: String in ["king", "mage", "tide", "nameless"]:
		if not ResourceLoader.exists(DialogueCast.ROOT + id + "/neutral.png"):
			check(DialogueCast.portrait_path(id) == "", "missing actor returns empty path " + id)
	dialogue.queue_free()
	await frames()

func optional_set_art_checks() -> void:
	var root := DialogueCast.ROOT + "sylphiette_set/"
	var missing: Array[String] = []
	for face: String in DialogueCast.EXPRESSIONS:
		if not ResourceLoader.exists(root + face + ".png"): missing.append(face)
	if not missing.is_empty():
		audit["sylphiette_set_art"] = {"status":"skipped_incomplete", "missing":missing}
		return
	var previous_hero := Characters.current_id()
	var previous_looks := GameState.legendary_looks.duplicate(true)
	Characters.set_current(&"sylphiette")
	GameState.legendary_looks = {"sylphiette":{"set":true, "weapon":true}}
	DialogueCast.clear_cache()
	var common_extent := Vector2.ZERO
	var common_head_extent := Vector2.ZERO
	for face: String in DialogueCast.EXPRESSIONS:
		check(DialogueCast.portrait_path("sylphiette", face, true) == root + face + ".png", "complete set uses independent expression " + face)
		var portrait := DialogueCast.portrait("sylphiette", face, true)
		var head := DialogueCast.portrait("sylphiette", face, true, true) as AtlasTexture
		check(portrait != null and head != null and head.atlas != null, "complete set portrait and thumbnail load " + face)
		if portrait != null and head != null and head.atlas != null:
			if common_extent == Vector2.ZERO:
				common_extent = portrait.get_size()
				common_head_extent = head.get_size()
			check(portrait.get_size() == common_extent and head.get_size() == common_head_extent, "set expressions share portrait and thumbnail dimensions " + face)
			check(head.atlas.get_size() == portrait.get_size() and Rect2(Vector2.ZERO, portrait.get_size()).encloses(head.region), "set head crop stays inside matching expression canvas " + face)
		var review_path := DialogueCast.portrait_path("sylphiette", face, false)
		check(review_path.begins_with(DialogueCast.ROOT + "sylphiette/") and not review_path.contains("_set/"), "set expression review retains normal costume " + face)
		check(DialogueCast.portrait("sylphiette", face, false) != null and DialogueCast.portrait("sylphiette", face, false, true) != null, "normal review portrait and thumbnail load " + face)
	audit["sylphiette_set_art"] = {"status":"checked_complete", "expressions":DialogueCast.EXPRESSIONS, "portrait_extent":str(common_extent), "thumbnail_extent":str(common_head_extent)}
	Characters.set_current(previous_hero)
	GameState.legendary_looks = previous_looks
	DialogueCast.clear_cache()

func fresh_camp_data() -> void:
	Outpost.data.events = {}
	Outpost.data.relationships = {}
	Outpost.data.bond_daily = {}
	Outpost.data.conversation_days = {}
	Outpost.data.inventory = {"memory_gift":1}
	Outpost.data.best = {"wave":10}
	Outpost.data.contracts = ["survey", "deep", "echo"]
	for npc: String in Outpost.data.bonds: Outpost.data.bonds[npc] = 250
	Outpost.pending_checkpoint = false

func local_transaction_checks() -> void:
	fresh_camp_data()
	var camp := CampUI.new()
	camp.world_mode = true
	add_child(camp)
	await frames()
	camp.open_facility("relations")
	camp._npc = "sylphiette"
	var meeting: Dictionary = CampStory.EVENTS.sylphiette[0]
	camp._play_event(meeting, false)
	var dialogue := camp._conversation
	check(dialogue._lines == CampStory.dialogue_lines(meeting.lines), "CampUI forwards authored speaker distinctions")
	var before_story := StoryState.flags.duplicate(true)
	dialogue._skip_story()
	await settled()
	check(Outpost.data.events.has("sylphiette:meeting"), "local skip commits eligible event once")
	check(StoryState.flags == before_story, "local skip does not set global skipped-story flags")
	var after := Outpost.data.duplicate(true)
	camp._play_event(meeting, true)
	dialogue._skip_story()
	await settled()
	check(Outpost.data == after, "local event replay cannot repeat rewards")
	Outpost.data.events["sylphiette:promise"] = true
	Outpost.data.events["sylphiette:memory"] = true
	var close: Dictionary = CampStory.EVENTS.sylphiette[3]
	camp._play_event(close, false)
	dialogue._skip_story()
	check(dialogue._choosing and dialogue._offered.size() == 2, "skip retains relationship choice")
	var option: Dictionary = dialogue._offered[0]
	check(option.reply is Array and option.reply == CampStory.dialogue_lines(close.choices[0].reply), "choice keeps narration and spoken reply separate")
	var pending_path := ProjectSettings.globalize_path(SaveService.SAVE_PATH) + ".tmp"
	check(not FileAccess.file_exists(pending_path) and not DirAccess.dir_exists_absolute(pending_path), "failure fixture owns isolated temp path")
	DirAccess.make_dir_recursive_absolute(pending_path)
	var before_failure := Outpost.data.duplicate(true)
	var save_before := SaveService.data.duplicate(true)
	dialogue._pick(option)
	check(dialogue._choosing and not dialogue._local_committed, "failed choice stays retryable")
	check(Outpost.data == before_failure and SaveService.data == save_before, "failed choice rolls back all camp and save state")
	check(not camp._scene.get("committed", false), "failed choice does not consume local commit")
	DirAccess.remove_absolute(pending_path)
	dialogue._pick(option)
	check(dialogue._local_committed and CampStory.relationship("sylphiette") == "mutual_interest", "retry commits original relationship")
	check(dialogue._mode == "reply" and dialogue._lines == CampStory.dialogue_lines(option.reply), "reply begins with authored narration")
	dialogue._skip_story()
	await settled()
	after = Outpost.data.duplicate(true)
	camp._play_event(close, true)
	dialogue._skip_story()
	dialogue._pick(dialogue._offered[1])
	dialogue._skip_story()
	await settled()
	check(Outpost.data == after, "replayed relationship choice cannot change stored relation or rewards")
	var flower: Dictionary = CampStory.EVENTS.sylphiette.back()
	camp._play_event(flower, false)
	DirAccess.make_dir_recursive_absolute(pending_path)
	before_failure = Outpost.data.duplicate(true)
	save_before = SaveService.data.duplicate(true)
	dialogue._skip_story()
	check(dialogue.is_open() and not dialogue._local_committed, "failed no-choice skip remains open")
	check(Outpost.data == before_failure and SaveService.data == save_before, "failed gift save restores inventory, event, affection and save")
	DirAccess.remove_absolute(pending_path)
	dialogue._typing = false
	dialogue._index = dialogue._lines.size() - 1
	dialogue._advance()
	await settled()
	check(int(Outpost.data.inventory.memory_gift) == 0 and Outpost.data.events.has("sylphiette:memory_flower"), "gift retry consumes exactly one flower")
	after = Outpost.data.duplicate(true)
	camp._play_event(flower, true)
	dialogue._skip_story()
	await settled()
	check(Outpost.data == after, "gift replay cannot consume another flower")
	camp.close()
	camp.queue_free()
	await frames()

func restore_checks() -> void:
	Characters.set_current(&"sylphiette")
	GameState.legendary_looks = {"sylphiette":{"set":true, "weapon":true}}
	var run_snapshot := GameState.snapshot()
	GameState.legendary_looks = {}
	GameState.restore(JSON.parse_string(JSON.stringify(run_snapshot)))
	check(DialogueCast.set_form("sylphiette"), "serialized run restore preserves persistent costume unlock")
	var dialogue := DialogueUI.new()
	add_child(dialogue)
	await frames()
	dialogue.play_lines([{"who":"sylphiette", "text":"我会回来。", "expression":"determined"}], "", &"")
	var snapshot := dialogue.expedition_snapshot()
	dialogue.cancel()
	dialogue.expedition_restore(JSON.parse_string(JSON.stringify(snapshot)))
	check(dialogue._actor_id == "sylphiette" and dialogue._last_expression == "determined", "dialogue restore keeps actor and expression")
	check(dialogue._player_art.texture != null and dialogue._face_art.texture != null, "dialogue restore resolves costume portrait and thumbnail")
	dialogue.cancel()
	StoryState.mark_seen(&"city_entry", &"ilyua")
	dialogue.play_replay(&"city_entry", &"ilyua")
	await frames()
	dialogue._show_line(dialogue._lines.size() - 1)
	check(dialogue._actor_id == "ilyua" and dialogue._review_character == &"ilyua", "review uses requested hero independent of active run")
	check(dialogue.expedition_snapshot().is_empty(), "review is not captured as live expedition state")
	dialogue.cancel()
	dialogue.expedition_restore({"scene_id":"cp_50", "scene":{"title":"old"}, "lines":[{"who":"player", "text":"old 帽檐"}], "offered":[{"text":"old grant", "give":"iron_sword"}], "index":0, "mode":"reply"})
	check(int(dialogue._scene.get("narrative_revision", 0)) == ContractorNarrative.REVISION and not JSON.stringify(dialogue._lines).contains("帽檐"), "old embedded dialogue restores revised canonical narrative")
	check(dialogue._offered.is_empty(), "old restored reward payload cannot replay")
	dialogue.cancel()
	dialogue.queue_free()
	await frames()
