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
var _continue_button: Button
var _role: Label
var _player_art: TextureRect
var _goddess_art: TextureRect
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
	_skip_button.tooltip_text = "跳过序章将放弃本次初始道具" if not _review and str(id).begins_with("intro_") else ""
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
	var character:Dictionary=Characters.DATA.get(_review_character,Characters.current()) if _review else Characters.current()
	var player := who == "player" or who == str(character.name)
	var expression := str(line.get("expression", ""))
	var explicit_portrait:=str(line.get("portrait",""))
	var has_explicit_portrait:=explicit_portrait.begins_with("res://assets/") and ResourceLoader.exists(explicit_portrait)
	var other_speaker:=not player and (has_explicit_portrait or who == Story.GODDESS or who in ["merchant","tavern",BondRules.NAMES.merchant,BondRules.NAMES.tavern])
	_name_label.text = str(character.name) if who.is_empty() or player else str(BondRules.NAMES.get(who,who))
	_role.text = "心声" if who.is_empty() else "对话"
	_progress.text = "%02d / %02d" % [i + 1, _lines.size()]
	_skip_hint.text = "%s / 点击正文继续"%KeyBindings.label("ui_accept") if not _review else "回看不会改变选择、奖励或进度"
	DialogueButtonArt.set_show_full(_continue_button, true)
	if has_explicit_portrait:
		var art:=_player_art if player else _goddess_art
		art.texture=_portrait(explicit_portrait,player);art.visible=true
	elif player or (who.is_empty() and not expression.is_empty()):
		var portraits: Dictionary = character.get("dialogue_portraits", {})
		_player_art.texture = _portrait(str(portraits.get(expression, character.get("dialogue_portrait", character.get("portrait",Characters.portrait_path())))), true)
		_player_art.visible = true
	elif who in ["merchant","tavern",BondRules.NAMES.merchant,BondRules.NAMES.tavern]:
		var npc:="merchant" if who in ["merchant",BondRules.NAMES.merchant] else "tavern"
		_goddess_art.texture=_portrait(NpcArt.portrait_path(npc,expression if expression in ["welcome","inspect","success","shortage"] else "welcome"))
		_goddess_art.visible=true
	elif who == Story.GODDESS:
		_goddess_art.texture = _portrait(str(DialoguePortraits.GODDESS.get(expression, Story.P_GODDESS)))
		_goddess_art.visible = true
	if _reveal != null and _reveal.is_valid(): _reveal.kill()
	_reveal = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	var duration := 0.10 if ComicMotion.reduced() else 0.14
	_reveal.tween_property(_player_art, "modulate", Color.WHITE if player or who.is_empty() else Color(0.65, 0.72, 0.76), duration)
	_reveal.tween_property(_goddess_art, "modulate", Color.WHITE if other_speaker else Color(0.65, 0.72, 0.76), duration)
	if who != _last_speaker or expression != _last_expression:
		ComicMotion.reveal(_name_label, duration)
		var art := _goddess_art if other_speaker else _player_art
		if art.visible: ComicMotion.reveal(art, duration)
	_last_speaker = who
	_last_expression = expression
	_bubble.modulate.a = 0.6
	_reveal.tween_property(_bubble, "modulate:a", 1.0, duration)

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
	_portrait_cache[path] = crop
	return crop

func _process(delta: float) -> void:
	if not UIFlow.is_top(self) or not is_open() or not _typing: return
	_shown += delta * CHARS_PER_SEC
	_typing = _shown < _full.length()
	_text_label.visible_characters = int(_shown) if _typing else -1
	if not _typing: DialogueButtonArt.set_show_full(_continue_button, false)

func _advance() -> void:
	if not is_open() or _choosing or _closing: return
	if _typing:
		_typing = false
		_text_label.visible_characters = -1
		DialogueButtonArt.set_show_full(_continue_button, false)
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
	var next := _pending_next
	if not _review and not _repeat_read_only: StoryState.complete_scene(_scene_id, next)
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
	_offered = choices.duplicate(true)
	_choosing = not choices.is_empty()
	_side.visible = _choosing
	_continue_button.visible = not _choosing
	if not _choosing: return
	_typing = false
	_text_label.visible_characters = -1
	_skip_hint.text = "↑ ↓ 选择 · %s 确认"%KeyBindings.label("ui_accept") if not _review else "选择仅预览对应对白，不改变实际分支"
	var token := _choice_token
	for raw in choices:
		var option: Dictionary = raw
		var button := DialogueButtonArt.choice_button(str(option.get("text", "…")))
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
	if _choice_box.get_child_count() > 0: (_choice_box.get_child(0) as Button).grab_focus()

func _pick(option: Dictionary) -> void:
	if not is_open() or not _choosing or not _offered.has(option): return
	_choosing = false
	_choice_token += 1
	for child in _choice_box.get_children(): (child as Button).disabled = true
	AudioManager.play(&"ui_click", -6)
	if not _review and not _repeat_read_only: StoryState.apply_choice(option)
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
	if not _repeat_read_only: StoryState.set_flag(&"skipped_story", true)
	# A deliberate skip completes the current scene; cancellation does not.
	if not _repeat_read_only: StoryState.complete_scene(_scene_id)
	_finish()

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
		if _skip_button.get_global_rect().has_point(event.position) or _continue_button.get_global_rect().has_point(event.position): return
		if _text_scroll.get_global_rect().has_point(event.position) and event.position.x > _text_scroll.get_global_rect().end.x - 22: return
		_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if get_viewport().gui_get_focus_owner() == _skip_button and event.is_action_pressed("ui_accept"): return
		_advance()
		get_viewport().set_input_as_handled()

func _build() -> void:
	_root = UiFactory.full_rect()
	_root.theme = PixelUi.theme()
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.08, 0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_chapter = PixelUi.label("", 20, PixelUi.GOLD)
	_chapter.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_root.add_child(_chapter)
	_skip_button = DialogueButtonArt.choice_button("跳过对白", 16, 44)
	_skip_button.pressed.connect(_skip_story)
	_root.add_child(_skip_button)
	_bubble = PixelUi.panel()
	var bubble_style := PixelUi.plate(4)
	bubble_style.content_margin_left = 28
	bubble_style.content_margin_right = 28
	bubble_style.content_margin_top = 22
	bubble_style.content_margin_bottom = 22
	_bubble.add_theme_stylebox_override("panel", bubble_style)
	_root.add_child(_bubble)
	var column := UiFactory.vbox(10)
	_bubble.add_child(column)
	var heading := UiFactory.hbox(12)
	heading.custom_minimum_size.y = 32
	column.add_child(heading)
	_name_label = PixelUi.label("", 22, PixelUi.GOLD)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(_name_label)
	_role = PixelUi.label("心声", 15, PixelUi.MUTED)
	_role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(_role)
	heading.add_child(UiFactory.spacer())
	_progress = PixelUi.label("", 14, PixelUi.MUTED)
	heading.add_child(_progress)
	_text_scroll = ScrollContainer.new()
	_text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text_scroll)
	_text_label = PixelUi.label("", 22)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_scroll.add_child(_text_label)
	var footer := UiFactory.hbox(8)
	column.add_child(footer)
	_skip_hint = PixelUi.label("", 17, PixelUi.MUTED)
	_skip_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_skip_hint)
	_continue_button = DialogueButtonArt.action_button()
	_continue_button.pressed.connect(_advance)
	footer.add_child(_continue_button)
	_side = PanelContainer.new()
	var clear_panel := StyleBoxEmpty.new()
	for edge in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		clear_panel.set_content_margin(edge, 12)
	_side.add_theme_stylebox_override("panel", clear_panel)
	_root.add_child(_side)
	_choice_scroll = ScrollContainer.new()
	_choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(_choice_scroll)
	_choice_box = UiFactory.vbox(7)
	_choice_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_scroll.add_child(_choice_box)
	_root.resized.connect(_layout)
	_layout.call_deferred()
	InteractionSkin.mount(_root,"dialogue",_bubble);InteractionSkin.surface(_side,"dialogue",false)

func _layout() -> void:
	if _bubble == null: return
	var extent := _root.size
	var width := minf(1160.0, extent.x - 64.0)
	var left := (extent.x - width) * 0.5
	var height := minf(296.0, extent.y * 0.42)
	var top := extent.y - height - 28.0
	_bubble.position = Vector2(left, top)
	_bubble.size = Vector2(width, height)
	_chapter.position = Vector2(left, 28)
	_chapter.size = Vector2(width - 200, 36)
	_skip_button.position = Vector2(left + width - 188, 24)
	_skip_button.size = Vector2(188, 44)
	var art_height := maxf(100.0, top - 70.0)
	var art_width := minf(width * 0.41, 410)
	_player_art.position = Vector2(left + 24, 76)
	_player_art.size = Vector2(art_width, art_height)
	_goddess_art.position = Vector2(left + width - art_width - 24, 76)
	_goddess_art.size = Vector2(art_width, art_height)
	var choice_height := minf(float(_choice_box.get_child_count()) * 59.0 + 24.0, maxf(80, top - 108))
	_side.position = Vector2(left + (width - minf(620, width)) * 0.5, top - choice_height - 16)
	_side.size = Vector2(minf(620, width), choice_height)

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
	_lines=data.get("lines",[]).duplicate(true)
	_mode=str(data.get("mode","scene"))
	_pending_next=StringName(data.get("pending",""))
	_tail_played=bool(data.get("tail",false))
	_chapter.text=str(_scene.get("title","星辉之间"))
	_index=clampi(int(data.get("index",0)),0,maxi(0,_lines.size()-1))
	if not _lines.is_empty(): _show_line(_index)
	_show_choices(data.get("offered",[]))
