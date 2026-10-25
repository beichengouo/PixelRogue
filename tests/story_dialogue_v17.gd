extends Node
var checks := 0
var failures := 0
func check(value: bool, caption: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("FAIL " + caption)
func _ready() -> void:
	run.call_deferred()
func frames(count := 3) -> void:
	for index in count: await get_tree().process_frame
func run() -> void:
	if not OS.get_user_data_dir().begins_with("E:/CodexWorkspace/PixelRogue/"):
		push_error("Isolated saves required");get_tree().quit(1);return
	AchievementTracker.set_process(false)
	var output: Dictionary = {"characters": Characters.DATA, "chapters": ChapterCatalog.CHAPTERS, "camp_intro": CampStory.INTRO, "camp_events": CampStory.EVENTS, "memories": CampStory.RETURN_MEMORIES, "residents": CampResidents.DATA, "tutorial": CampTutorial.STEPS, "event_titles": RoomExpansionController.TITLES, "event_intro": RoomExpansionController.INTRO, "event_replies": RoomExpansionController.REPLIES, "scenes": {}}
	var ids: Array = Story.SCENES.keys()
	for wave in Story.CHECKPOINTS: ids.append(Story.checkpoint_id(wave))
	ids.append_array([Story.FINAL_SCENE, &"forest_mage_before", &"forest_tide_before", &"fate_observation"])
	ids.append_array(CityStories.IDS)
	for hero: StringName in Characters.DATA:
		Characters.set_current(hero)
		output.scenes[hero] = {}
		for id: StringName in ids:
			var scene := Story.get_scene(id, false, hero)
			var repeat := Story.get_scene(id, true, hero)
			output.scenes[hero][id] = {"first": scene, "repeat": repeat}
			check(scene.get("choices", []).size() <= 3, "choice maximum " + str(hero) + ":" + str(id))
			if id == &"intro_wake":
				check(scene.choices.size() == 3, "three intro replies")
				for option: Dictionary in scene.choices: check(option.next == &"" and not option.has("give"), "intro no weapon handout")
			if id == &"intro_weapon": check(scene.lines.is_empty() and scene.choices.is_empty(), "retired weapon teaching")
	var file := FileAccess.open("E:/CodexWorkspace/PixelRogue/outputs/story-review-v17/runtime_story.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t")); file.close()
	var ui := DialogueUI.new(); add_child(ui); await frames()
	ui.play_local_lines([{"who": "伊莉丝", "text": "回廊的灯会等你归来。"}, {"who": "player", "text": "我们继续。"}])
	await frames()
	check(ui._text_label.get_theme_font_size("font_size") >= 25, "larger dialogue font")
	check(ui._root.find_children("*", "Button", true, false).size() == 1, "skip is only button during normal lines")
	ui._advance(); check(not ui._typing and ui._index == 0, "first confirm reveals text")
	ui._advance(); check(ui._index == 1, "second confirm advances")
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = ui._bubble.global_position + Vector2(50, 70)
	ui._input(click); check(not ui._typing, "click dialogue reveals text")
	ui._show_choices([{"text":"A"},{"text":"B"},{"text":"C"},{"text":"D"}])
	check(ui._choice_box.get_child_count() == 3 and ui._offered.size() == 3, "restored/external payload maximum")
	ui.cancel(); await frames()
	ui.expedition_restore({"scene_id":"intro_weapon","scene":{"choices":[{"text":"old","give":"staff_apprentice"}]},"offered":[{"text":"old","give":"staff_apprentice"}]})
	await get_tree().create_timer(.4, true).timeout; check(not ui.is_open(), "old weapon teaching snapshot closes without reward")
	ui.queue_free(); await frames()
	var camp := CampUI.new(); camp.world_mode = true; add_child(camp); await frames()
	camp.open_facility("relations"); camp._npc = "sylphiette"; camp._play_event(CampStory.EVENTS.sylphiette[0], true); await frames()
	check(is_instance_valid(camp._scene_label) and camp._scene_label.get_theme_font_size("font_size") == 28, "camp relationship larger text")
	var advance_buttons := 0
	for button: Node in camp._body.find_children("*", "Button", true, false):
		if button.text in ["继续", "记住这个约定"]: advance_buttons += 1
	check(advance_buttons == 0, "camp relationship has no continue button")
	var accept := InputEventAction.new(); accept.action = "ui_accept"; accept.pressed = true
	camp._input(accept); check(camp._line == 1, "camp confirm advances inline story")
	await frames(); var tap := InputEventScreenTouch.new(); tap.pressed = true; tap.position = camp._scene_label.global_position + Vector2(4, 4)
	camp._input(tap); check(camp._line == 2, "camp touch advances inline story")
	camp._input(tap); check(camp._line == 2, "touch plus emulated mouse cannot advance twice in one frame")
	camp.close(); camp.queue_free(); await frames()

	print("STORY_DIALOGUE_V17 checks=", checks, " failures=", failures)
	AudioManager.shutdown(); get_tree().quit(1 if failures else 0)


