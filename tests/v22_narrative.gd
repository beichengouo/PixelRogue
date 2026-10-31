extends Node
## Isolated V22 narrative and relationship transaction regression.
var checks := 0
var failures := 0
const HEROES: Array[StringName] = [&"sylphiette", &"xixifu", &"ilyua"]
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
func frames(count := 3) -> void:
	for index in count: await get_tree().process_frame
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")
func event_for(hero: String, id: String) -> Dictionary:
	for entry: Dictionary in CampStory.EVENTS[hero]:
		if str(entry.id) == id: return entry
	return {}
func inspect_lines(value: Variant, context: String) -> void:
	if value is Dictionary:
		if value.has("who") and value.has("text"):
			check(not str(value.text).strip_edges().is_empty(), "nonempty authored line " + context)
			var actor := DialogueCast.actor(str(value.who))
			if not actor.is_empty():
				check(value.has("expression"), "explicit scene emotion " + context)
				var face := DialogueCast.expression(str(value.get("expression", "")), str(value.text), str(value.get("portrait", "")))
				check(face != "angry", "no unmotivated anger " + context)
		for child in value.values(): inspect_lines(child, context)
	elif value is Array:
		for child in value: inspect_lines(child, context)
func reset_profile() -> void:
	Outpost.data.events = {}
	Outpost.data.relationships = {}
	Outpost.data.bonds = {"sylphiette":0,"xixifu":0,"ilyua":0,"iris":0}
	Outpost.data.inventory = {}
	Outpost.data.best = {"test":1}
	Outpost.data.contracts = ["survey"]
	Outpost.data.active = {}
	Outpost.data.conversation_days = {}
	Outpost.pending_checkpoint = false
	StoryState.flags["forest_cleared"] = true
	StoryState.flags["city_cleared"] = true
func unlock_prior(hero: String, last := "close") -> void:
	for id: String in ["meeting", "promise", "memory", "close"]:
		Outpost.data.events[hero + ":" + id] = true
		if id == last: break
func run() -> void:
	var user_path := OS.get_user_data_dir().replace("\\", "/")
	if not user_path.begins_with("E:/CodexWorkspace/PixelRogue/"):
		printerr("V22 narrative requires isolated E: userdata")
		get_tree().quit(2)
		return
	AchievementTracker.set_process(false)
	ErrorReporter.interactive = false
	SaveService.data.reduced_motion = true
	var old_outpost := Outpost.data.duplicate(true)
	var old_save := SaveService.data.duplicate(true)
	var old_flags := StoryState.flags.duplicate(true)
	var old_character := Characters.current_id()
	var canonical: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/narrative_v11.json"))
	check(canonical.size() == 19, "all nineteen stable forest/death/echo hooks revised")
	check(ContractorNarrative.REVISION == 13, "presentation revision independent of game version")
	for hero: StringName in HEROES:
		Characters.set_current(hero)
		for id: String in canonical:
			for repeated: bool in [false, true]:
				var scene := Story.get_scene(StringName(id), repeated, hero)
				check(int(scene.get("narrative_revision", 0)) == ContractorNarrative.REVISION, "canonical revision " + str(hero) + "/" + id)
				check(scene.get("choices", []).size() <= Story.MAX_CHOICES, "choice count preserved " + id)
				inspect_lines(scene, str(hero) + "/" + id)
		for id: StringName in CityStories.IDS:
			for repeated: bool in [false, true]:
				var scene := CityStories.scene(id, repeated, hero)
				check(int(scene.get("narrative_revision", 0)) == ContractorNarrative.REVISION, "city revision " + str(id))
				inspect_lines(scene, str(hero) + "/" + str(id))
		inspect_lines(FateStory.scene(hero), str(hero) + "/fate")
		inspect_lines(CampStory.EVENTS[str(hero)], str(hero) + "/camp")
		inspect_lines(CampStory.daily_event(str(hero)), str(hero) + "/daily")
		inspect_lines(CampStory.RETURN_MEMORIES[str(hero)], str(hero) + "/commemoration")
		var intro := JSON.stringify(Story.get_scene(&"intro_wake", false, hero))
		check(intro.contains("契约者留在回廊") and intro.contains("想不起") and intro.contains("旧路标"), "independent contractor, amnesia, concrete opening goal")
		check(JSON.stringify(Story.get_scene(&"intro_wake", true, hero)).contains("不是重新忘掉"), "repeat journey retains new memories")
		check(JSON.stringify(CityStories.scene(&"city_nameless_before", false, hero)).contains("片段的真伪尚未核对，代价却已经写明"), "recorded memory cannot bypass corroboration")
		check(JSON.stringify(CampStory.EVENTS[str(hero)]).contains("以前") and JSON.stringify(CampStory.EVENTS[str(hero)]).contains("现在"), "past familiarity distinct from present relationship")
		var expected_ids := ["meeting", "promise", "memory", "close", "romance"]
		var expected_min := [0, 20, 50, 100, 200]
		for index in expected_ids.size():
			var entry := event_for(str(hero), expected_ids[index])
			check(not entry.is_empty() and int(entry.min) == expected_min[index], "stable affinity threshold " + str(hero) + "/" + expected_ids[index])
			check(not bool(entry.get("gift", false)), "core memories never require a paid gift")
		check(not str(event_for(str(hero), "memory").require) in ["echo", "bossrush"], "core memory never gated on fourth stage")
		await transaction_checks(str(hero))
	for step: Dictionary in CampTutorial.STEPS:
		check(FileAccess.file_exists(CampResidents.ROOT + "iris_" + str(step.pose) + ".png"), "tutorial uses existing Iris pose " + str(step.pose))
		check(not str(step.text).contains("走到大门"), "tutorial retains direct departure")
	check(CampTutorial.STEPS[7].role == "training" and str(CampTutorial.STEPS[7].text).contains("独立训练场"), "camp only offers separate training entrance")
	await snapshot_checks()
	Outpost.data = old_outpost
	SaveService.data = old_save
	StoryState.flags = old_flags
	Characters.set_current(old_character)
	AudioManager.shutdown()
	await frames()
	print("V22_NARRATIVE checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)
func transaction_checks(hero: String) -> void:
	reset_profile()
	Characters.set_current(StringName(hero))
	# Walk the friendship path through all five stages without gifts or BossRush.
	for id: String in ["meeting", "promise", "memory", "close", "romance"]:
		var entry := event_for(hero, id)
		Outpost.data.bonds[hero] = int(entry.min)
		var relation := "friendship" if id in ["close", "romance"] else ""
		check(CampStory.available(hero, entry), "friendship event available " + hero + "/" + id)
		check(Outpost.bond_event(hero, id, int(entry.gain), false, relation), "friendship stage commits " + hero + "/" + id)
		check(CampStory.relationship(hero) == "friendship", "memories never auto-select romance")
		check(not Outpost.bond_event(hero, id, int(entry.gain), false, relation), "stable event cannot reward twice " + id)
	check(int(Outpost.data.inventory.get("memory_gift", 0)) == 0, "full friendship path uses no flower")
	# Already-seen old events and confirmed romances survive optional recap.
	Outpost.data.relationships[hero] = "romance"
	var recap := event_for(hero, "memory_recap_v12")
	var before_bond := int(Outpost.data.bonds[hero])
	var before_inventory: Dictionary = Outpost.data.inventory.duplicate(true)
	var pending := ProjectSettings.globalize_path(SaveService.SAVE_PATH) + ".tmp"
	check(not FileAccess.file_exists(pending) and not DirAccess.dir_exists_absolute(pending), "fixture owns isolated atomic save blocker")
	check(DirAccess.make_dir_absolute(pending) == OK, "save failure injected in isolated userdata")
	var before := Outpost.data.duplicate(true)
	var save_before := SaveService.data.duplicate(true)
	check(not Outpost.bond_event(hero, str(recap.id), int(recap.gain)), "failed recap save rejected")
	check(Outpost.data == before and SaveService.data == save_before, "failed recap restores event, bonds, inventory and relationships")
	check(DirAccess.remove_absolute(pending) == OK, "isolated save blocker removed")
	check(Outpost.bond_event(hero, str(recap.id), int(recap.gain)), "optional recap commits through existing transaction")
	check(int(Outpost.data.bonds[hero]) == before_bond and Outpost.data.inventory == before_inventory, "recap carries no reward or inventory change")
	check(CampStory.relationship(hero) == "romance" and Outpost.data.events.has(hero + ":romance"), "old confirmed relationship and event remain")
	check(not Outpost.bond_event(hero, str(recap.id), 0), "recap completion cannot repeat")
	# Explicit romance and exclusive selection still use existing rules.
	reset_profile()
	unlock_prior(hero, "memory")
	Outpost.data.bonds[hero] = 200
	check(not CampStory.can_romance(hero), "high affection alone never establishes love")
	check(Outpost.bond_event(hero, "close", 5, false, "mutual_interest"), "new mutual interest requires explicit choice")
	var close := event_for(hero, "romance")
	check(close.choices.any(func(option: Dictionary) -> bool: return bool(option.get("defer", false))), "romance can be deferred")
	check(Outpost.bond_event(hero, "romance", 5, false, "romance"), "explicit romance confirmation")
	var other := "ilyua" if hero != "ilyua" else "xixifu"
	Outpost.data.relationships[other] = "mutual_interest"
	check(not CampStory.can_romance(other), "confirmed romance remains exclusive")
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveService.SAVE_PATH))
	check(disk is Dictionary and str(disk.outpost.relationships.get(hero, "")) == "romance", "relationship serialized atomically")
	# Legacy close without relationship record gets its existing opt-in invitation.
	reset_profile()
	unlock_prior(hero)
	Outpost.data.bonds[hero] = 200
	var invitation := CampStory.invitation_event(hero)
	check(not invitation.is_empty() and str(invitation.id) == "invitation", "legacy invitation preserved")
	check(Outpost.bond_event(hero, "invitation", int(invitation.gain), false, "friendship"), "legacy player may explicitly retain friendship")
func snapshot_checks() -> void:
	var dialogue := DialogueUI.new()
	add_child(dialogue)
	await frames()
	for hero: StringName in HEROES:
		Characters.set_current(hero)
		for id: String in ["cp_50", "city_clue_4", "fate_observation"]:
			var before_flags := StoryState.flags.duplicate(true)
			var before_outpost := Outpost.data.duplicate(true)
			dialogue.expedition_restore({"scene_id":id, "scene":{"title":"old", "narrative_revision":11}, "lines":[{"who":"", "text":"OBSOLETE_PAYLOAD"}], "offered":[{"text":"OLD_REWARD", "give":"iron_sword"}], "repeat_read_only":true, "mode":"reply"})
			await frames()
			check(int(dialogue._scene.get("narrative_revision", 0)) == ContractorNarrative.REVISION, "old snapshot gets revised canonical presentation " + id)
			check(not JSON.stringify(dialogue._lines).contains("OBSOLETE_PAYLOAD") and dialogue._offered.is_empty(), "old embedded choices and lines discarded")
			check(StoryState.flags == before_flags and Outpost.data == before_outpost, "presentation migration never reapplies committed effects")
			dialogue.cancel()
			await frames()
	# The independent contractor has a nameplate, never the selected hero's body.
	dialogue.play_local_lines([{"who":"契约者","text":"这段往事，我们回来以后一起核对。","expression":"neutral"}])
	await frames()
	check(dialogue._name_label.text == "契约者" and dialogue._actor_id.is_empty(), "contractor retains independent spoken name")
	check(not dialogue._player_art.visible and not dialogue._goddess_art.visible and not dialogue._face_art.visible, "contractor never borrows heroine or Iris portrait")
	dialogue.cancel()
	await frames()
	dialogue.queue_free()
	await frames()
