class_name DialogueUI
extends CanvasLayer
## 共用对话界面：角色文案独立配置，回看不执行玩法效果。
signal finished
signal opened
signal review_finished
const CHARS_PER_SEC := 38.0
var _root: Control
var _bubble: PanelContainer
var _text_label: Label
var _name_label: Label
var _chapter: Label
var _progress: Label
var _choice_box: VBoxContainer
var _side: PanelContainer
var _choice_scroll: ScrollContainer
var _text_scroll: ScrollContainer
var _skip_hint: Label
var _skip_button: Button
var _role: Label
var _player_art: TextureRect
var _goddess_art: TextureRect
var _face_art: TextureRect
var _ribbon: Control
var _actor_id := ""
var _local_transaction := false
var _local_committed := false
var _local_commit: Callable
var _scene: Dictionary = {}
var _scene_id: StringName = &""
var _lines: Array = []
var _index := 0
var _full := ""
var _shown := 0.0
var _typing := false
var _choosing := false
var _mode := "scene"
var _pending_next: StringName = &""
var _tail_played := false
var _review := false
var _review_character:StringName=&""
var _choice_token := 0
var _offered: Array = []
var _origin_focus: WeakRef
var _reveal: Tween
var _portrait_cache: Dictionary = {}
var _closing := false
var _presentation_epoch := 0
var _last_speaker := ""
var _last_expression := ""
var _automatic_pending := false
var _repeat_read_only := false
var _compact_decision := false

func _ready() -> void:
	set_meta("blocking_screen", true)
	layer = 26
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build()
	_root.visible = false

func is_open() -> bool:
	return _root != null and _root.visible

func _open(review := false) -> void:
	_local_transaction = false
	_local_committed = false
	_local_commit = Callable()
	_presentation_epoch += 1
	_closing = false
	ComicMotion.cancel(_root)
	_root.modulate.a = 1.0
	_last_speaker = ""
	_last_expression = ""
	_review = review
	layer = 36 if review else 26
	var focus := get_viewport().gui_get_focus_owner()
	_origin_focus = weakref(focus) if focus != null else null
	_root.visible = true
	_player_art.visible = false
	_goddess_art.visible = false
	_face_art.visible = false
	UIFlow.push_screen(self)
	get_viewport().set_meta("dialogue_modal", get_instance_id())
	_layout()
	opened.emit()

func play_scene(id: StringName) -> void:
	if is_open() or _automatic_pending or not Story.has_scene(id): return
	_presentation_epoch += 1
	_automatic_pending = true
	# Room flow connects/awaits finished immediately after this call. Even a skip
	# must finish on a later frame, without briefly pausing or opening the modal.
	_dispatch_scene.call_deferred(id, _presentation_epoch)

func _dispatch_scene(id: StringName, ticket: int) -> void:
	if ticket != _presentation_epoch or not _automatic_pending: return
	_automatic_pending = false
	_review = false
	var target := _automatic_target(id)
	if target == &"":
		finished.emit()
		return
	_repeat_read_only = (_replay_enabled() or str(target).begins_with("city_")) and StoryState.completed(target) and target != Story.FINAL_SCENE
	_open()
	_enter_scene(target)

func _replay_enabled() -> bool:
	return bool(SaveService.data.get("replay_seen_dialogue", false))

func _automatic_target(id: StringName) -> StringName:
	if str(id).begins_with("city_"):return id
	if _review or _replay_enabled(): return id
	var visited: Array[StringName] = []
	while id != &"" and StoryState.completed(id) and id != Story.FINAL_SCENE:
		if id in visited: return &""
		visited.append(id)
		id = StoryState.scene_next(id, StringName(Story.get_scene(id).get("next", &"")))
	return id if id == &"" or Story.has_scene(id) else &""

func play_replay(id: StringName,character_id:StringName=&"") -> void:
	if is_open() or not Story.has_scene(id) or not StoryState.seen(id,character_id): return
	_review_character=Characters.current_id() if character_id==&"" else character_id
	_repeat_read_only = false
	_open(true)
	_enter_scene(id)

func start_intro() -> void:
	play_scene(Story.INTRO_FIRST)

func play_lines(lines: Array, _portrait := "", id: StringName = &"") -> void:
	if is_open() or _automatic_pending: return
	if id != &"" and StoryState.completed(id) and not _replay_enabled():
		_presentation_epoch += 1
		_automatic_pending = true
		_finish_skipped_lines.call_deferred(_presentation_epoch)
		return
	_repeat_read_only = id != &"" and StoryState.completed(id)
	_compact_decision = false
	_open()
	_scene_id = id
	if not _repeat_read_only: StoryState.begin_scene(id)
	_scene = {}
	_tail_played = true
	_pending_next = &""
	_chapter.text = "星辉之间"
	_skip_button.text = "跳过对白"
	_play_lines(lines, "scene")

func _finish_skipped_lines(ticket: int) -> void:
	if ticket != _presentation_epoch or not _automatic_pending: return
	_automatic_pending = false
	finished.emit()

## Camp teaching and resident conversations are presentation only. Skipping
## them must not set story flags, complete chapters or grant story rewards.
func play_local_lines(lines:Array,chapter:="营地故事")->void:
	play_lines(lines)
	_repeat_read_only=true
	_chapter.text=chapter

func play_local_scene(scene: Dictionary, commit: Callable) -> void:
	if is_open() or _automatic_pending: return
	_open()
	_local_transaction = true
	_local_commit = commit
	_repeat_read_only = true
	_scene_id = &""
	_scene = scene.duplicate(true)
	_tail_played = true
	_pending_next = &""
	_compact_decision = false
	_chapter.text = str(scene.get("title", "灯下交谈"))
	_skip_button.text = "略过对白"
	_play_lines(_scene.get("lines", []), "scene")

func _enter_scene(id: StringName) -> void:
	if not _review:
		id = _automatic_target(id)
		if id == &"":
			_finish()
			return
	_scene_id = id
	if not _review and (_replay_enabled() or str(id).begins_with("city_")) and id != Story.FINAL_SCENE and StoryState.completed(id):
		_repeat_read_only = true
	_scene = Story.get_scene(id, not _review and StoryState.seen(id),_review_character if _review else &"")
	_compact_decision = not _review and not _replay_enabled() and id == Story.FINAL_SCENE and StoryState.completed(id)
	if not _review and not _repeat_read_only: StoryState.begin_scene(id)
	_tail_played = false
	_pending_next = StringName(_scene.get("next", &""))
	_chapter.text = ("回看 · " if _review else "") + str(_scene.get("title", "星辉之间"))
	_skip_button.text = "关闭回看" if _review else ("跳过序章" if str(id).begins_with("intro_") else "跳过对白")
	_skip_button.tooltip_text = "跳过对白会保留需要你决定的选项与奖励。" if not _review else ""
	if _compact_decision:
		_play_lines([{"text": "星辉之门已经打开。继续探索，还是准备离开？"}], "scene")
		_typing = false
		_text_label.visible_characters = -1
		_show_choices(Story.choices_of(_scene))
	else: _play_lines(_scene.get("lines", []), "scene")

func _play_lines(lines: Array, mode: String) -> void:
	_mode = mode
	_lines = lines.duplicate(true)
	_index = 0
	_show_choices([])
	if _lines.is_empty(): _after_lines()
	else: _show_line(0)

func _show_line(i: int) -> void:
	var line: Dictionary = _lines[i]
	_full = str(line.get("text", ""))
	_shown = 0
	_typing = true
	# 完整文本先排版，逐字显示不会引发行间跳动。
	_text_label.text = _full
	_text_label.visible_characters = 0
	_text_scroll.scroll_vertical = 0
	var who := str(line.get("who", ""))
	var hero := _review_character if _review and _review_character != &"" else Characters.current_id()
	_actor_id = DialogueCast.actor(who, hero)
	var expression := DialogueCast.expression(str(line.get("expression", "")), _full, str(line.get("portrait", "")))
	var player := _actor_id in ["sylphiette", "xixifu", "ilyua"]
	_name_label.text = str(DialogueCast.NAMES.get(_actor_id, who)) if not who.is_empty() else "旅途纪事"
	_role.text = "" if not who.is_empty() else "叙述"
	_progress.text = "%02d / %02d" % [i + 1, _lines.size()]
	_skip_hint.text = "%s / 点击继续" % KeyBindings.label("ui_accept") if not _review else "回看不会改变选择、奖励或进度"
	_player_art.hide()
	_goddess_art.hide()
	_face_art.hide()
	var art := _player_art if player else _goddess_art
	art.texture = DialogueCast.portrait(_actor_id, expression, not _review)
	if art.texture == null and not _actor_id.is_empty():
		var legacy := str(line.get("portrait", ""))
		if legacy.begins_with("res://assets/") and ResourceLoader.exists(legacy): art.texture = _portrait(legacy, player)
	art.visible = art.texture != null
	_face_art.texture = DialogueCast.portrait(_actor_id, expression, not _review, true)
	_face_art.visible = _face_art.texture != null
	if _reveal != null and _reveal.is_valid(): _reveal.kill()
	var changed := _actor_id != _last_speaker
	# Faces share one framing and pose. Expression changes never squash or move art.
	art.modulate = Color.WHITE
	_face_art.modulate = Color.WHITE
	if changed and art.visible and not ComicMotion.reduced():
		art.modulate.a = 0.0
		_reveal = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_reveal.tween_property(art, "modulate:a", 1.0, 0.14)
	_last_speaker = _actor_id
	_last_expression = expression
	_layout()

func _portrait(path: String, player := false) -> Texture2D:
	if _portrait_cache.has(path): return _portrait_cache[path]
	var texture := load(path) as Texture2D
	if texture == null: return null
	var crop := AtlasTexture.new()
	crop.atlas = texture
	var extent := texture.get_size()
	var new_pose := path.contains("/dialogue/")
	var npc_pose:=path.contains("/next_revision/npcs/")
	crop.region = Rect2(extent * Vector2(0.02, 0.0 if new_pose or npc_pose else (0.02 if player else 0.08)), extent * Vector2(0.96, 0.64 if new_pose else (0.68 if player else 0.62)))
	if path.begins_with(CampResidents.ROOT):
		crop.region=Rect2(Vector2.ZERO,extent*Vector2(1,.7))
	if path.begins_with(CityStories.ROOT):
		# Verena's crown starts near the top edge; the legacy NPC inset cut it off.
		crop.region=Rect2(Vector2.ZERO,extent*Vector2(1,.70))
	_portrait_cache[path] = crop
	return crop

func _process(delta: float) -> void:
	if not UIFlow.is_top(self) or not is_open() or not _typing: return
	_shown += delta * CHARS_PER_SEC
	_typing = _shown < _full.length()
	_text_label.visible_characters = int(_shown) if _typing else -1

func _advance() -> void:
	if not is_open() or _choosing or _closing: return
	if _typing:
		_typing = false
		_text_label.visible_characters = -1
		return
	if _index + 1 < _lines.size():
		_index += 1
		_show_line(_index)
	else: _after_lines()

func _after_lines() -> void:
	if _mode == "reply":
		_play_tail_or_go()
		return
	if _mode == "tail":
		_goto_pending()
		return
	var choices := Story.choices_of(_scene)
	if not choices.is_empty(): _show_choices(choices)
	else: _play_tail_or_go()

func _play_tail_or_go() -> void:
	var tail: Array = _scene.get("tail", [])
	if not _compact_decision and not _tail_played and not tail.is_empty():
		_tail_played = true
		_play_lines(tail, "tail")
	else: _goto_pending()

func _goto_pending() -> void:
	if _local_transaction:
		if not _local_committed:
			if not _local_commit.is_valid() or not bool(_local_commit.call({})):
				_text_label.text = "这段交谈尚未保存，请稍后重试。点击正文可再次保存。"
				_text_label.visible_characters = -1
				_typing = false
				return
			_local_committed = true
		_finish()
		return
	var next := _pending_next
	if not _review and not _repeat_read_only:
		# Combined boss introductions keep their original replay records without
		# closing/reopening a second dialogue window.
		for source:StringName in _scene.get("source_scenes",[]):StoryState.complete_scene(source)
		StoryState.complete_scene(_scene_id,next)
	_pending_next = &""
	if next == &"": _finish()
	else: _enter_scene(next)

func cancel() -> void:
	_automatic_pending = false
	_presentation_epoch += 1
	if is_open(): _close()

func _close() -> void:
	_presentation_epoch += 1
	_closing = false
	_automatic_pending = false
	ComicMotion.cancel(_root)
	_choice_token += 1
	_root.visible = false
	_typing = false
	_choosing = false
	_offered.clear()
	if _reveal != null: _reveal.kill()
	UIFlow.pop_screen(self)
	if get_viewport().get_meta("dialogue_modal", 0) == get_instance_id(): get_viewport().remove_meta("dialogue_modal")
	if _origin_focus != null:
		var previous: Variant = _origin_focus.get_ref()
		if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()

func _exit_tree() -> void:
	if get_viewport().get_meta("dialogue_modal", 0) == get_instance_id():
		get_viewport().remove_meta("dialogue_modal")
		UIFlow.pop_screen(self)

func _finish() -> void:
	if not is_open() or _closing: return
	_closing = true
	var ticket := _presentation_epoch
	ComicMotion.dismiss(_root, func() -> void:
		if ticket != _presentation_epoch: return
		_close()
		if _review: review_finished.emit()
		else: finished.emit())

func _show_choices(choices: Array) -> void:
	_choice_token += 1
	for child in _choice_box.get_children():
		_choice_box.remove_child(child)
		child.queue_free()
	choices = choices.slice(0, Story.MAX_CHOICES)
	_offered = choices.duplicate(true)
	_choosing = not choices.is_empty()
	_side.visible = _choosing
	if not _choosing: return
	_typing = false
	_text_label.visible_characters = -1
	_skip_hint.text = "↑ ↓ 选择 · %s 确认"%KeyBindings.label("ui_accept") if not _review else "选择仅预览对应对白，不改变实际分支"
	var token := _choice_token
	for raw in choices:
		var option: Dictionary = raw
		var button := DialogueButtonArt.choice_button(str(option.get("text", "…")), 22, 64)
		button.disabled = bool(option.get("disabled", false))
		button.tooltip_text = str(option.get("unavailable_reason", ""))
		button.pressed.connect(func() -> void:
			if token == _choice_token: _pick(option)
		)
		_choice_box.add_child(button)
	_layout()
	_choice_scroll.scroll_vertical = 0
	ComicMotion.reveal(_side, 0.14)
	_focus_choices.call_deferred(token)

func _focus_choices(token: int) -> void:
	if token != _choice_token or not is_open() or not _choosing: return
	for child in _choice_box.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			break

func _pick(option: Dictionary) -> void:
	if not is_open() or not _choosing or not _offered.has(option) or bool(option.get("disabled", false)): return
	if _local_transaction and not _local_committed:
		if not _local_commit.is_valid() or not bool(_local_commit.call(option)):
			_text_label.text = "心意尚未记录：条件不满足或保存失败，原状态已保留。请重试。"
			_text_label.visible_characters = -1
			return
		_local_committed = true
	_choosing = false
	_choice_token += 1
	for child in _choice_box.get_children(): (child as Button).disabled = true
	AudioManager.play(&"ui_click", -6)
	if not _local_transaction and not _review and not _repeat_read_only: StoryState.apply_choice(option)
	_pending_next = StringName(option.get("next", _pending_next))
	var reply: Array = option.get("reply", [])
	if not _compact_decision and not reply.is_empty(): _play_lines(reply, "reply")
	else:
		_show_choices([])
		_play_tail_or_go()

func _skip_story() -> void:
	if not is_open(): return
	if _review:
		_finish()
		return
	if _scene_id == Story.FINAL_SCENE:
		if _mode in ["reply", "tail"]:
			_finish()
			return
		_text_label.text = "星辉之门已经打开。我要留在林地继续挑战，还是离开？"
		_text_label.visible_characters = -1
		_show_choices(Story.choices_of(_scene))
		return
	if not _repeat_read_only:StoryState.set_flag(&"skipped_story",true)
	if _mode in ["reply","tail"]:
		_tail_played=true;_goto_pending();return
	var choices:=Story.choices_of(_scene)
	if not choices.is_empty():
		_typing=false;_text_label.visible_characters=-1;_tail_played=true
		_text_label.text="对白已略过，请决定这段旅途的回应。";_show_choices(choices);return
	_tail_played=true;_goto_pending()

func _input(event: InputEvent) -> void:
	if not UIFlow.is_top(self): return
	if not is_open(): return
	if _closing:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		if _review: _finish()
		get_viewport().set_input_as_handled()
		return
	if _choosing: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _skip_button.get_global_rect().has_point(event.position): return
		if _text_scroll.get_global_rect().has_point(event.position) and event.position.x > _text_scroll.get_global_rect().end.x - 22: return
		_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if get_viewport().gui_get_focus_owner() == _skip_button and event.is_action_pressed("ui_accept"): return
		_advance()
		get_viewport().set_input_as_handled()

func _build() -> void:
	_root = UiFactory.full_rect()
	_root.theme = InteractionSkin.theme()
	add_child(_root)
	var shade := UiFactory.dim_layer(0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	for is_player in [true, false]:
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(art)
		if is_player: _player_art = art
		else: _goddess_art = art
	_ribbon = load("res://src/ui/dialogue_ribbon.gd").new()
	_root.add_child(_ribbon)
	_bubble = PanelContainer.new()
	_bubble.name = "DialogueText"
	_bubble.set_meta("glass_exempt", true)
	var empty := StyleBoxEmpty.new()
	for edge in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]: empty.set_content_margin(edge, 12)
	_bubble.add_theme_stylebox_override("panel", empty)
	_root.add_child(_bubble)
	var column := UiFactory.vbox(8)
	_bubble.add_child(column)
	var heading := UiFactory.hbox(12)
	heading.custom_minimum_size.y = 32
	column.add_child(heading)
	_name_label = PixelUi.label("", 28, Color("f9e7bd"))
	heading.add_child(_name_label)
	_role = PixelUi.label("", 15, PixelUi.MUTED)
	heading.add_child(_role)
	heading.add_child(UiFactory.spacer())
	_progress = PixelUi.label("", 14, PixelUi.MUTED)
	heading.add_child(_progress)
	_text_scroll = ScrollContainer.new()
	_text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text_scroll)
	_text_label = PixelUi.label("", 28)
	_text_label.add_theme_constant_override("line_spacing", 8)
	_text_label.add_theme_constant_override("outline_size", 3)
	_text_label.add_theme_color_override("font_outline_color", Color(.025, .035, .065, .75))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_scroll.add_child(_text_label)
	_skip_hint = PixelUi.label("", 16, Color(.78, .84, .90))
	_skip_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_skip_hint)
	_face_art = TextureRect.new()
	_face_art.name = "SpeakerFace"
	_face_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_face_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_face_art)
	_chapter = PixelUi.label("", 18, PixelUi.MUTED)
	_chapter.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_root.add_child(_chapter)
	_skip_button = DialogueButtonArt.choice_button("跳过对白", 16, 44)
	_skip_button.pressed.connect(_skip_story)
	_root.add_child(_skip_button)
	_side = PanelContainer.new()
	_side.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_root.add_child(_side)
	_choice_scroll = ScrollContainer.new()
	_choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(_choice_scroll)
	_choice_box = UiFactory.vbox(8)
	_choice_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_scroll.add_child(_choice_box)
	_root.resized.connect(_layout)
	_layout.call_deferred()

func _layout() -> void:
	if _bubble == null: return
	var extent := _root.size
	var compact := extent.x < 900.0
	var margin := clampf(extent.x * .025, 16.0, 64.0)
	var height := clampf(extent.y * .28, 210.0, 320.0)
	if extent.y < 520: height = extent.y * .46
	var top := extent.y - height
	var face_width := clampf(extent.x * .155, 100.0, 230.0)
	_ribbon.position = Vector2(0, top - 38)
	_ribbon.size = Vector2(extent.x, height + 38)
	_face_art.position = Vector2(margin, top - 20)
	_face_art.size = Vector2(face_width, height + 12)
	var inset := margin + (face_width + 16 if _face_art.visible else 0.0)
	_bubble.position = Vector2(inset, top + 8)
	_bubble.size = Vector2(maxf(120, extent.x - inset - margin), height - 18)
	_text_label.add_theme_font_size_override("font_size", 24 if compact else 28)
	_name_label.add_theme_font_size_override("font_size", 25 if compact else 28)
	_chapter.position = Vector2(margin, 18)
	_chapter.size = Vector2(maxf(100, extent.x - 2 * margin - 190), 32)
	_skip_button.position = Vector2(extent.x - margin - 160, 14)
	_skip_button.size = Vector2(160, 44)
	# One centered half-body figure; the dialogue ribbon overlays the lower waist.
	var art_height := maxf(120, top + height * .30 - 64)
	var art_width := minf(extent.x * .78, art_height * .80)
	for art in [_player_art, _goddess_art]:
		art.position = Vector2((extent.x - art_width) * .5, 64)
		art.size = Vector2(art_width, art_height)
	var choice_height := minf(float(_choice_box.get_child_count()) * 78.0, maxf(80, top - 84))
	var choice_width := minf(640, extent.x - 2 * margin)
	_side.position = Vector2((extent.x - choice_width) * .5, top - choice_height - 16)
	_side.size = Vector2(choice_width, choice_height)

func expedition_snapshot() -> Dictionary:
	if not is_open() or _review: return {}
	return {"scene":_scene.duplicate(true),"scene_id":str(_scene_id),"lines":_lines.duplicate(true),"index":_index,"mode":_mode,"pending":str(_pending_next),"tail":_tail_played,"offered":_offered.duplicate(true),"repeat_read_only":_repeat_read_only,"compact_decision":_compact_decision}

func expedition_restore(data: Dictionary) -> void:
	if data.is_empty(): return
	_open()
	_repeat_read_only = bool(data.get("repeat_read_only", false))
	_compact_decision = bool(data.get("compact_decision", false))
	_scene=data.get("scene",{}).duplicate(true)
	_scene_id=StringName(data.get("scene_id",""))
	if _scene_id == &"intro_weapon":
		_scene = Story.get_scene(_scene_id)
		_show_choices([])
		_finish.call_deferred()
		return
	if int(_scene.get("narrative_revision",0))<ContractorNarrative.REVISION:
		var canonical:=Story.get_scene(_scene_id)
		if int(canonical.get("narrative_revision",0))>=ContractorNarrative.REVISION:
			# Old saves may contain entire obsolete lines/choices, not just an ID.
			# Replace their presentation without repeating their already committed effects.
			_scene=canonical;_mode="scene";_tail_played=false;_compact_decision=false
			_pending_next=StringName(_scene.get("next",&""));_chapter.text=str(_scene.title)
			_play_lines(_scene.get("lines",[]),"scene")
			return
	_lines=data.get("lines",[]).duplicate(true)
	_mode=str(data.get("mode","scene"))
	_pending_next=StringName(data.get("pending",""))
	_tail_played=bool(data.get("tail",false))
	_chapter.text=str(_scene.get("title","星辉之间"))
	_index=clampi(int(data.get("index",0)),0,maxi(0,_lines.size()-1))
	if not _lines.is_empty(): _show_line(_index)
	_show_choices(data.get("offered",[]))
