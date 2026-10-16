class_name MainMenu
extends CanvasLayer
## 像素星辉菜单。视频与原立绘保留；界面使用统一像素组件。
signal start_requested()
signal continue_requested(snapshot: Dictionary)
signal quit_requested()
signal story_replay_requested(scene_id: StringName, character_id:StringName)
var _record_chapter:StringName=ChapterCatalog.FIRST
var _record_character:StringName=&""
var _codex_kind := ""
var _codex_selected := ""
var _monster_category := "monsters"
var _achievement_filter:="全部"

enum View { MAIN, CHARACTER, SETTINGS, RECORD, ITEMS, MONSTERS }
const TITLE := "轮舞于星辉尽头"
const TITLE_LOGO := "res://assets/ui_drawn/title_logo.png"
const MENU_LETTERING := "res://assets/ui_art/main_menu_star/options/"
const VIDEO_BG := "res://assets/video/menu_starry_4k.ogv"
const VIDEO_MOBILE := "res://assets/video/menu_starry_mobile.ogv"
const VIDEO_SIZE := Vector2(3840, 2160)
var _root: Control
var _canvas: Control
var _page: Control
var _scroll_memory: Dictionary = {}
var _archive_positions:Dictionary={}
var _visible_archive_key:=""
var _content: VBoxContainer
var _backdrop: Panel
var _shade: TextureRect
var _selection_art: TextureRect
var _character_art: TextureRect
var _artbook: CharacterArtbook
var _monster_scroll:ScrollContainer
var _video: VideoStreamPlayer
var _view: View = View.MAIN
var _picked: StringName = Characters.DEFAULT_ID
var _transition: Tween
var _switching := false
var _activation_pending := false
var _activation_generation := 0
var _return_focus: Dictionary = {}
var _notice := ""
var _settings_only := false
var _settings_tab:=0
var _menu_closing := false
var _binding_capture:=""
var _binding_button:Button
var _binding_status:Label
var _binding_buttons:Dictionary={}
var _abandon_confirm:GlassConfirmUI
var _release_notes:ReleaseNotesUI
var _background_art:TextureRect

func open_release_notes()->void:
	if is_instance_valid(_release_notes):return
	_release_notes=ReleaseNotesUI.new();add_child(_release_notes)

func set_notice(text: String) -> void:
	_notice = text

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_abandon_confirm=GlassConfirmUI.new();_abandon_confirm.title="放弃当前出征？"
	_abandon_confirm.dialog_text="本局带出的装备、药剂、随身金币及尚未撤回的收获将遗失。营地金库、剩余仓库、关系与委托保留。是否放弃原存档并选择新角色？"
	_abandon_confirm.get_ok_button().text="放弃并选择角色";_abandon_confirm.get_cancel_button().text="取消"
	_abandon_confirm.about_to_popup.connect(func()->void:_abandon_confirm.get_cancel_button().grab_focus.call_deferred())
	_abandon_confirm.confirmed.connect(_confirm_new_game);add_child(_abandon_confirm)
	_root.visible = false

func is_open() -> bool:
	return _root.visible

func _exit_tree() -> void:
	_activation_generation += 1
	if _transition != null and _transition.is_valid(): _transition.kill()
	if _video != null:
		_video.stop()
		_video.stream = null

func open() -> void:
	if not UIFlow.can_open(self): return
	_menu_closing = false
	var migration:=SaveService.take_migration_notice()
	if not migration.is_empty():_notice=migration
	_settings_only = false
	_root.visible = true
	UIFlow.push_screen(self)
	_show_view(View.MAIN, true)
	if _video != null and not ComicMotion.reduced():
		_video.play()
	AudioManager.play(&"ui_click", -8.0)

func open_settings() -> void:
	if not UIFlow.can_open(self): return
	_menu_closing = false
	_settings_only = true
	_root.visible = true
	UIFlow.push_screen(self)
	_show_view(View.SETTINGS, true)

func close(immediate := true) -> void:
	if is_instance_valid(_abandon_confirm):_abandon_confirm.close()
	_binding_capture=""
	if not immediate and is_open():
		if _menu_closing: return
		_menu_closing = true
		_activation_generation += 1
		_activation_pending = false
		if _transition != null and _transition.is_valid(): _transition.kill()
		_transition = ComicMotion.dismiss(_page, func() -> void: close(true))
		return
	_menu_closing = false
	_activation_generation += 1
	_activation_pending = false
	_notice = ""
	if _transition != null and _transition.is_valid():
		_transition.kill()
	ComicMotion.cancel(_page)
	_switching = false
	_page.modulate.a = 1.0
	_root.visible = false
	if _video != null:
		_video.stop()
	UIFlow.pop_screen(self)

func _build() -> void:
	_root = UiFactory.full_rect()
	_root.theme = PixelUi.theme()
	add_child(_root)
	var art := TextureRect.new()
	_background_art=art
	art.texture = load("res://assets/backgrounds/main_menu.png")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(art)
	var video_path:=VIDEO_MOBILE if MobileControls.enabled() else VIDEO_BG
	if ResourceLoader.exists(video_path):
		_video = VideoStreamPlayer.new()
		_video.stream = load(video_path)
		_video.expand = true
		_video.loop = true
		_video.volume_db = -80.0
		_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_video)
		_root.resized.connect(_fit_video)
		_fit_video()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color(0.04, 0.08, 0.15, 0.12),
		Color(0.04, 0.08, 0.15, 0.10), Color(0.04, 0.08, 0.15, 0.90)])
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.width = 1024
	fade.height = 1
	fade.fill_from = Vector2.ZERO
	fade.fill_to = Vector2.RIGHT
	_shade = TextureRect.new()
	_shade.texture = fade
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_shade)
	_selection_art = TextureRect.new()
	_selection_art.texture = load("res://assets/art_phase4/forest_backdrop_v1.png")
	_selection_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_selection_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_selection_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_selection_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_selection_art)
	_canvas = StarUi.frame(_root, Vector2(1280, 720))
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character_art = TextureRect.new()
	var character: Dictionary = Characters.DATA[Characters.DEFAULT_ID]
	_character_art.texture = load(str(character.get("select_portrait", character.get("portrait", ""))))
	_character_art.position = Vector2(70, 80)
	_character_art.size = Vector2(480, 620)
	_character_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_character_art.size = Vector2(480, 620)
	_character_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_character_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_character_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_character_art)

	_page = Control.new()
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_page)
	_backdrop = Panel.new()
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_theme_stylebox_override("panel", PixelUi.plate(4))
	_page.add_child(_backdrop)
	_content = UiFactory.vbox(12)
	_page.add_child(_content)

func _fit_video() -> void:
	if _video == null:
		return
	var factor := maxf(_root.size.x / VIDEO_SIZE.x, _root.size.y / VIDEO_SIZE.y)
	_video.size = VIDEO_SIZE * factor
	_video.position = (_root.size - _video.size) * 0.5

func _show_view(view: View, immediate := false) -> void:
	if _settings_only and view == View.MAIN:
		close(false)
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button and _page.is_ancestor_of(focused):
		_return_focus[int(_view)] = focused.text
	var scrolls: Array = []
	for scroll in _page.find_children("*", "ScrollContainer", true, false):
		scrolls.append(Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical))
	_scroll_memory[int(_view)] = scrolls
	if _transition != null and _transition.is_valid(): _transition.kill()
	ComicMotion.cancel(_page)
	if immediate:
		_switching = false
		_render_view(view)
		_transition = ComicMotion.reveal(_page)
		_focus_first.call_deferred()
		return
	_switching = true
	_transition = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition.tween_property(_page, "modulate:a", 0.0, 0.04 if ComicMotion.reduced() else 0.06)
	_transition.tween_callback(func() -> void: _render_view(view))
	_transition.tween_property(_page, "modulate:a", 1.0, 0.06 if ComicMotion.reduced() else 0.10)
	_transition.tween_callback(func() -> void:
		_switching = false
		_focus_first())

func _restore_scroll(view: View) -> void:
	if _view != view: return
	var saved: Array = _archive_positions.get(_visible_archive_key,[]) if view in [View.ITEMS,View.MONSTERS,View.RECORD] else _scroll_memory.get(int(view), [])
	var scrolls := _page.find_children("*", "ScrollContainer", true, false)
	for i in mini(saved.size(), scrolls.size()):
		scrolls[i].scroll_horizontal = saved[i].x
		scrolls[i].scroll_vertical = saved[i].y

func _render_view(view: View) -> void:
	if _view in [View.ITEMS,View.MONSTERS,View.RECORD] and not _visible_archive_key.is_empty():
		var saved:Array=[]
		for scroll in _page.find_children("*","ScrollContainer",true,false):saved.append(Vector2i(scroll.scroll_horizontal,scroll.scroll_vertical))
		_archive_positions[_visible_archive_key]=saved
	InteractionSkin.unmount(_content);InteractionSkin.clear_surface(_backdrop)
	_backdrop.add_theme_stylebox_override("panel",PixelUi.plate(4))
	_view = view
	if view==View.RECORD and _record_character==&"":_record_character=Characters.current_id()
	_visible_archive_key="achievements:"+_achievement_filter if view==View.ITEMS else "codex:"+_monster_category+":"+_codex_kind if view==View.MONSTERS else "story:"+str(_record_chapter)+":"+str(_record_character) if view==View.RECORD else ""
	if not _settings_only and is_open(): AudioManager.play_menu(view != View.MAIN)
	if _artbook != null:
		_page.remove_child(_artbook)
		_artbook.queue_free()
		_artbook = null
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_place_content()
	match view:
		View.MAIN: _build_main()
		View.CHARACTER: _build_character()
		View.SETTINGS: _build_settings()
		View.RECORD: _build_record()
		View.ITEMS: _build_items()
		View.MONSTERS: _build_monsters()
	if view not in [View.MAIN,View.CHARACTER]:
		InteractionSkin.mount(_content,"menu");_backdrop.visible=true;InteractionSkin.surface(_backdrop,"menu")
	_restore_scroll.call_deferred(view)

func _input(event: InputEvent) -> void:
	if is_instance_valid(_abandon_confirm) and _abandon_confirm.visible:return
	if not UIFlow.is_top(self): return
	if get_viewport().has_meta("dialogue_modal"): return
	if not is_open():
		return
	if not _binding_capture.is_empty():
		if not is_instance_valid(_binding_button):_binding_capture="";return
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
			if event.pressed and not event.echo:
				var code:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
				var action:=_binding_capture
				var error:="" if code==KEY_ESCAPE else KeyBindings.bind(action,code)
				if error.is_empty():
					_binding_capture="";_binding_button.text=KeyBindings.label(action)
					_binding_status.text="已取消修改" if code==KEY_ESCAPE else "已保存键位 · "+str(KeyBindings.ACTIONS[action])
				else:_binding_status.text=error+" · Esc 取消"
		elif event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
			if event.pressed:
				var action:=_binding_capture
				var error:=KeyBindings.bind_mouse(action,event.button_index)
				if error.is_empty():
					_binding_capture="";_binding_button.text=KeyBindings.label(action)
					_binding_status.text="已保存键位 · "+str(KeyBindings.ACTIONS[action])
				else:_binding_status.text=error+" · Esc 取消"
		elif event is InputEventJoypadButton:get_viewport().set_input_as_handled()
		return
	if _menu_closing:
		get_viewport().set_input_as_handled()
		return
	if not _activation_pending and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")) and not event.is_echo() and (_view != View.MAIN or _switching):
		_show_view(View.MAIN)
		get_viewport().set_input_as_handled()
		return
	if _switching or _activation_pending:
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
		return
	if _view==View.MONSTERS and is_instance_valid(_monster_scroll):
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
			_monster_scroll.scroll_vertical+=64 if event.is_action_pressed("ui_down") else -64
			get_viewport().set_input_as_handled()
			return
	if (event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel")) and not event.is_echo() and _view != View.MAIN:
		_show_view(View.MAIN)
		get_viewport().set_input_as_handled()

func _focus_first() -> void:
	if get_viewport().has_meta("dialogue_modal"): return
	if not _root.visible or _switching:
		return
	if _view == View.CHARACTER and _artbook != null:
		var previous := str(_return_focus.get(int(_view), ""))
		for button in _artbook.find_children("*", "Button", true, false):
			if button.text == previous and not button.disabled:
				button.grab_focus()
				return
		_artbook.focus_first()
		return
	var previous := str(_return_focus.get(int(_view), ""))
	for node in _content.find_children("*", "Button", true, false):
		if not node.disabled and node.text == previous:
			node.grab_focus()
			return
	for node in _content.find_children("*", "Button", true, false):
		if not node.disabled:
			node.grab_focus()
			return

func _place_content() -> void:
	_content.add_theme_constant_override("separation", 8 if _view == View.MAIN else 12)
	# 纹理首次载入会延迟刷新最小尺寸，在控件入树后固定立绘展示区域。
	_character_art.set_deferred("size", Vector2(480, 620))
	_selection_art.visible = false
	_character_art.visible = false
	if _video != null:
		_video.visible = _view != View.CHARACTER and not _settings_only
	_background_art.visible=not _settings_only
	_shade.visible=not _settings_only
	_backdrop.visible = _view not in [View.MAIN, View.CHARACTER, View.SETTINGS, View.ITEMS, View.MONSTERS]
	_shade.modulate.a = 1.0 if _view == View.MAIN else 0.3
	match _view:
		View.MAIN:
			_content.position = Vector2(680, 18)
			_content.size = Vector2(548, 686)
		View.SETTINGS:
			_content.position=Vector2(100,40)
			_content.size=Vector2(1080,640)
		View.ITEMS,View.MONSTERS:
			_content.position=Vector2(100,40)
			_content.size=Vector2(1080,640)
		View.CHARACTER:
			_content.position = Vector2(614, 62)
			_content.size = Vector2(542, 584)
		_:
			_content.position = Vector2(280, 82)
			_content.size = Vector2(720, 556)
	_backdrop.position = _content.position - Vector2(40, 28)
	_backdrop.size = _content.size + Vector2(80, 56)

func _menu_button(text: String, on_press: Callable, disabled := false) -> Button:
	var button := PixelUi.button(text, 20, 0, 52)
	button.disabled = disabled
	button.pressed.connect(func() -> void:
		if is_open() and not _switching: on_press.call())
	return button

func _build_main() -> void:
	var field := Control.new()
	field.custom_minimum_size = Vector2(548, 686)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(field)
	var logo := PixelUi.art_graphic("title", Vector2(356, 122))
	if ResourceLoader.exists("res://assets/ui_art/main_menu_star/title_rondo.tres"):
		logo.texture=load("res://assets/ui_art/main_menu_star/title_rondo.tres")
	logo.position = Vector2(170, -6)
	field.add_child(logo)
	var chapter := PixelUi.art_graphic("chapter", Vector2(176, 25))
	chapter.position = Vector2(260, 139)
	chapter.tooltip_text = "第一章 / 苏醒林地"
	field.add_child(chapter)
	var has_save := SaveService.has_run()
	var continuing := "续写旅途"
	var entries := [
		["启程赴星", "星光所至，即是旅途", "start", Vector2(153,184), Vector2(390,52), _request_new_game],
		[continuing, "从上次驻足之处继续", "continue", Vector2(153,242), Vector2(390,52), _on_continue],
		["星遗录", "成就收藏 · 铭刻旅途的荣光", "codex", Vector2(153,300), Vector2(390,52), func() -> void: _show_view(View.ITEMS)],
		["异闻录", "装备、遗物、怪物、词条与雇佣图鉴", "gallery", Vector2(153,358), Vector2(390,52), func() -> void: _show_view(View.MONSTERS)],
		["旅途回响", "旅途进程与剧情回看", "record", Vector2(153,416), Vector2(390,52), func() -> void: _show_view(View.RECORD)],
		["设置", "操作 · 声音", "settings", Vector2(153,474), Vector2(390,52), func() -> void: _show_view(View.SETTINGS)],
		["暂别星辉", "离开当前游戏", "quit", Vector2(153,532), Vector2(390,52), func() -> void: quit_requested.emit()],
	]
	var focus_order: Array[Button] = []
	for index in entries.size():
		var entry: Array = entries[index]
		var button := _star_menu_button(str(entry[0]),entry[4],str(entry[2]))
		button.tooltip_text=str(entry[1])
		button.position = entry[3]
		if index == 1 and not has_save:
			button.disabled = true
			button.tooltip_text = "尚无可继续的旅途，请先开始新冒险。"
			button.modulate = Color("929eaa")
		var action: Callable = entry[5]
		button.pressed.connect(func() -> void:
			if not is_open() or _switching or _activation_pending: return
			_activation_pending = true
			var generation := _activation_generation
			await get_tree().create_timer(0.12, true).timeout
			if generation != _activation_generation: return
			if is_open() and not _switching: action.call()
			_activation_pending = false)
		field.add_child(button)
		if not button.disabled: focus_order.append(button)
	for index in focus_order.size():
		var button := focus_order[index]
		var previous := focus_order[posmod(index-1, focus_order.size())]
		var following := focus_order[(index+1) % focus_order.size()]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(following)
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(following)
	if has_save:
		var saved := SaveService.run_info()
		var progress := PixelUi.label("苏醒林地 · 第 %d 波 · Lv.%d" % [int(saved.get("wave", 1)), int(saved.get("level", 1))], 18, PixelUi.GOLD)
		progress.position = Vector2(153, 584)
		progress.size = Vector2(390, 24)
		progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress.tooltip_text="战斗难度 · "+RunDifficulty.title(int(saved.get("difficulty",saved.get("departure",{}).get("difficulty",1))))
		field.add_child(progress)
	# Enable wrapping before assigning text so a long migration notice cannot
	# enlarge the label's minimum width beyond the menu field.
	var hint := PixelUi.label("", 17, Color("ffaaa0") if not _notice.is_empty() else PixelUi.INK)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.position = Vector2(153, 610)
	hint.size = Vector2(390, 66)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = _notice if not _notice.is_empty() else "%s / %s 选择 · %s 确认"%[KeyBindings.label("ui_up"),KeyBindings.label("ui_down"),KeyBindings.label("ui_accept")]
	field.add_child(hint)


func _on_continue() -> void:
	var info := SaveService.run_info()
	if info.is_empty():
		return
	close()
	continue_requested.emit(info)

func _build_character() -> void:
	_artbook = CharacterArtbook.new()
	_artbook.selected = _picked
	_artbook.size = Vector2(1280, 720)
	_artbook.picked.connect(func(id: StringName) -> void:
		_picked = id
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button: _return_focus[int(View.CHARACTER)] = focused.text
		_render_view(View.CHARACTER)
		_focus_first.call_deferred()
	)
	_artbook.back_requested.connect(func() -> void: _show_view(View.MAIN))
	_artbook.start_requested.connect(func(id: StringName) -> void:
		if not is_open() or _switching: return
		Characters.set_current(id)
		close()
		start_requested.emit()
	)
	_page.add_child(_artbook)

func _title_logo(height: float) -> Control:
	## 标题图是浅色发光的书法字，直接压在明亮的天空背景上会"糊"在一起
	## （画面自查反馈：可读性不足）。这里在底下垫两层深色副本当投影，
	## 不改变原图、也不用额外素材，字就跳出来了。
	##
	## 注意：三个副本必须**手动**摆位置。之前用 set_anchors_and_offsets_preset
	## 在"还没进场景树、父节点尺寸还是 0"的时候算过一次居中，结果算出来的
	## 偏移是负的、进树后没再重算，标题直接飞出了可视区（实测不显示）。
	## 现在改成锚点钉在左上 + 用 resized 回调重算位置，尺寸一确定就摆正。
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0.0, height + 22.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = load(TITLE_LOGO)
	if tex == null:
		return holder
	var width := height * float(tex.get_width()) / float(tex.get_height())
	var layers: Array[TextureRect] = []
	for layer in 3:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
		rect.size = Vector2(width, height)
		if layer == 0:
			rect.modulate = Color(0.06, 0.04, 0.12, 0.50)
		elif layer == 1:
			rect.modulate = Color(0.08, 0.05, 0.16, 0.66)
		holder.add_child(rect)
		layers.append(rect)
	var place := func() -> void:
		var base := (holder.size - Vector2(width, height)) * 0.5
		for j in layers.size():
			var dy := 7.0 if j == 0 else (3.0 if j == 1 else 0.0)
			layers[j].position = base + Vector2(0.0, dy)
	holder.resized.connect(place)
	place.call()
	return holder


func _build_settings() -> void:
	_binding_capture="";_binding_buttons.clear();_binding_status=null;_binding_button=null
	_content.add_theme_constant_override("separation",16)
	var title:=PixelUi.title("设置",40);_content.add_child(title)
	var tabs:=UiFactory.hbox(10);tabs.name="SettingsCategories";_content.add_child(tabs)
	for index in 6:
		if MobileControls.enabled() and index==3:continue
		var button:=StarUi.button(["声音","画面","操作","按键","引导","公告"][index],22)
		button.name="SettingsTab"+str(index);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size.y=52
		button.set_meta("interaction_selected",index==_settings_tab);InteractionSkin.apply_button(button,"settings");tabs.add_child(button)
		button.pressed.connect(func()->void:_settings_tab=index;_scroll_memory.erase(int(View.SETTINGS));_render_view(View.SETTINGS))
	var panel:=PanelContainer.new();panel.name="SettingsGlass";panel.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.set_meta("ui_layout_canvas",true)
	panel.add_theme_stylebox_override("panel",InteractionSkin.style("settings"));_content.add_child(panel)
	var scroll:=ScrollContainer.new();scroll.name="SettingsScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;panel.add_child(scroll)
	var body:=UiFactory.vbox(16);body.name="SettingsBody";body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
	match _settings_tab:
		0:_settings_sound(body)
		1:_settings_graphics(body)
		2:_settings_controls(body)
		3:_settings_keys(body)
		4:_settings_guidance(body)
		5:_settings_announcements(body)
	InteractionSkin.apply_tree(panel,"settings");_style_settings_text(body)
	var back:=StarUi.button("返回",22);back.custom_minimum_size.y=52;InteractionSkin.apply_button(back,"settings");_content.add_child(back)
	back.pressed.connect(func()->void:_show_view(View.MAIN))

func _style_settings_text(node:Node)->void:
	if node is Label:
		node.add_theme_font_size_override("font_size",maxi(22,node.get_theme_font_size("font_size")))
		node.add_theme_constant_override("line_spacing",5);node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if node is Button:node.add_theme_font_size_override("font_size",22);node.custom_minimum_size.y=maxf(50,node.custom_minimum_size.y)
	if node is OptionButton:
		node.get_popup().add_theme_font_size_override("font_size",22);node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for child in node.get_children():
		if not child is FrostedGlass:_style_settings_text(child)

func _settings_announcements(body:VBoxContainer)->void:
	body.add_child(PixelUi.title("版本与更新公告",28))
	body.add_child(PixelUi.label("当前版本 V"+str(ProjectSettings.get_setting("application/config/version","0.4")),22,PixelUi.GOLD))
	var entry:=StarUi.button("查看更新公告",22);entry.name="OpenReleaseNotes";body.add_child(entry);entry.pressed.connect(open_release_notes)
	body.add_child(PixelUi.label("可在公告中回看历次更新内容。",22,PixelUi.MUTED))

func _settings_sound(body:VBoxContainer)->void:
	body.add_child(PixelUi.title("声音与音乐",28))
	body.add_child(_volume_row("主音量",AudioManager.master_volume(),AudioManager.set_master_volume))
	body.add_child(_volume_row("音效音量",AudioManager.sfx_volume(),AudioManager.set_sfx_volume))
	body.add_child(_volume_row("音乐音量",AudioManager.music_volume(),AudioManager.set_music_volume))

func _settings_graphics(body:VBoxContainer)->void:
	body.add_child(PixelUi.title("画面与动态效果",28))
	for entry in [["震屏强度","screen_shake_strength"],["受击闪光","flash_strength"],["法术特效","spell_fx_strength"]]:
		var key:=str(entry[1]);body.add_child(_volume_row(str(entry[0]),float(SaveService.data.get(key,1.0)),func(v:float)->void:SaveService.set_volume(key,v)))
	if not MobileControls.enabled():body.add_child(_setting_toggle("全屏",DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,func(on:bool)->void:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)))
	body.add_child(_setting_toggle("怪物血条",bool(SaveService.data.get("show_enemy_hp",true)),func(on:bool)->void:SaveService.data.show_enemy_hp=on;SaveService.save_data()))
	body.add_child(_setting_toggle("减少动效",bool(SaveService.data.get("reduced_motion",false)),func(on:bool)->void:
		SaveService.data.reduced_motion=on
		if _video!=null:
			if on:_video.stop()
			else:_video.play()
		SaveService.save_data()))
	body.add_child(PixelUi.label("环境质量",24,PixelUi.GOLD))
	var quality:=UiFactory.hbox(12);body.add_child(quality)
	for index in 3:
		var button:=StarUi.button(["低","中","高"][index],22);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.set_meta("interaction_selected",int(SaveService.data.get("environment_quality",2))==index);quality.add_child(button)
		button.pressed.connect(func()->void:SaveService.data.environment_quality=index;SaveService.save_data();_render_view(View.SETTINGS))

func _settings_guidance(body:VBoxContainer)->void:
	body.add_child(PixelUi.title("对白与营地引导",28))
	body.add_child(_setting_toggle("重复播放已看对白",bool(SaveService.data.get("replay_seen_dialogue",false)),func(on:bool)->void:SaveService.data.replay_seen_dialogue=on;SaveService.save_data()))
	body.add_child(PixelUi.label("默认跳过已经完成的对白；旅途回响中可以随时回看。",22,PixelUi.MUTED))
	var replay:=StarUi.button("重新开启营地引导",22);body.add_child(replay)
	replay.pressed.connect(func()->void:
		var notice:=CampNotice.new();notice.message="营地引导已重新开启。返回营地后，伊莉丝会再次带你认识各处设施。" if CampTutorial.restart() else "暂时无法保存，引导设置未修改，请重试。";add_child(notice))

func _settings_controls(body:VBoxContainer)->void:
	body.add_child(PixelUi.title("攻击与瞄准",28))
	var attack_row:BoxContainer=UiFactory.vbox(12);body.add_child(attack_row)
	attack_row.add_child(PixelUi.label("攻击方式",18,PixelUi.GOLD))
	var attack_mode := OptionButton.new();attack_mode.name="AttackMode"
	if MobileControls.enabled():attack_mode.custom_minimum_size.y=60
	attack_mode.add_item("键盘方向键 / 手柄");attack_mode.add_item("鼠标指向 · 左键连续攻击");attack_mode.add_item("自动攻击 · 战斗金币减半")
	if MobileControls.enabled():
		attack_mode.set_item_text(0,"八向瞄准 · 双摇杆")
		attack_mode.set_item_text(1,"自由瞄准 · 右摇杆 360° 连射")
	attack_mode.selected=maxi(0,RoomInput.ATTACK_MODES.find(str(SaveService.data.get("attack_mode","keyboard"))))
	attack_mode.disabled=not RoomInput.can_change_attack_mode();attack_mode.tooltip_text="仅能在营地或安全房间更换。自动模式只释放普攻，获得「手残党」：战斗金币收益减半。"
	attack_row.add_child(attack_mode)
	attack_mode.item_selected.connect(func(index:int)->void:
		var error:=RoomInput.set_attack_mode(RoomInput.ATTACK_MODES[index])
		if not error.is_empty():set_notice(error)
		_render_view(View.SETTINGS))
	var aim_guide:=CheckButton.new();aim_guide.name="MouseAimGuide";aim_guide.text="红色虚线瞄准指引（鼠标模式）"
	if MobileControls.enabled():aim_guide.text="红色虚线瞄准指引（自由瞄准）"
	aim_guide.button_pressed=bool(SaveService.data.get("mouse_aim_guide",true));aim_guide.disabled=attack_mode.selected!=1
	body.add_child(aim_guide)
	aim_guide.toggled.connect(func(enabled:bool)->void:
		var before:bool=bool(SaveService.data.get("mouse_aim_guide",true));SaveService.data.mouse_aim_guide=enabled
		if not SaveService.save_data():
			SaveService.data.mouse_aim_guide=before;aim_guide.set_pressed_no_signal(before);set_notice("保存失败，瞄准指引未修改"))
	if MobileControls.enabled():
		body.add_child(PixelUi.label("左侧拖动移动，右侧拖动瞄准连射。技能、闪避、药剂、撤离和各功能使用独立触屏按钮。",18,PixelUi.MUTED))
		body.add_child(PixelUi.label("背包点按查看详情，在详情中装备或卸下。天赋点按查看，再点投入。列表支持手指滑动，安卓返回键可关闭面板或暂停。",18,PixelUi.MUTED))
		for node in body.get_children():
			if node is Label:node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var layout_button:=StarUi.button("调整触控轮盘与按钮布局",18);body.add_child(layout_button)
		layout_button.pressed.connect(func()->void:add_child(MobileLayoutEditor.new()))
		var fps:=OptionButton.new();fps.add_item("流畅 · 60 FPS",60);fps.add_item("省电 · 30 FPS",30)
		fps.select(1 if int(SaveService.data.get("mobile_fps",60))==30 else 0);body.add_child(fps)
		fps.item_selected.connect(func(index:int)->void:
			var before:int=int(SaveService.data.get("mobile_fps",60));SaveService.data.mobile_fps=fps.get_item_id(index)
			if SaveService.save_data():Engine.max_fps=int(SaveService.data.mobile_fps)
			else:SaveService.data.mobile_fps=before;fps.select(1 if before==30 else 0);set_notice("保存失败，帧率未修改"))
		return

func _settings_keys(body:VBoxContainer)->void:
	for text in [
		KeyBindings.battle_hint(),
		"%s 确认 · %s/%s/%s 技能 · %s 大招 · %s/%s/%s 药剂"%[KeyBindings.label("ui_accept"),KeyBindings.label("skill_1"),KeyBindings.label("skill_2"),KeyBindings.label("skill_3"),KeyBindings.label("ultimate"),KeyBindings.label("potion_1"),KeyBindings.label("potion_2"),KeyBindings.label("potion_3")],
		"手柄：左摇杆移动 · 右摇杆瞄准连射 · B 冲刺 · Y 交互 · LB / RB / LT 技能 · RT 大招",
		"%s / 手柄十字键↓ 呼唤女神 · 祈祷3秒 → 安全回应5秒 / 战斗回应30秒 → 接引2秒"%KeyBindings.label("call_goddess"),
	]:
		var hint := PixelUi.label("", 17, PixelUi.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.text = text
		body.add_child(hint)
	body.add_child(_rule())
	body.add_child(PixelUi.label("键盘与鼠标按键",18,PixelUi.GOLD))
	_binding_status=PixelUi.label("选择操作后按键盘键或鼠标按键（支持侧键）· Esc 取消 · 手柄键位保持原样",15,PixelUi.MUTED)
	_binding_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(_binding_status)
	_binding_buttons.clear()
	var keys:=GridContainer.new();keys.columns=2;keys.add_theme_constant_override("h_separation",16);body.add_child(keys)
	for action:String in KeyBindings.ACTIONS:
		var row:=UiFactory.hbox(10);keys.add_child(row)
		var caption:=PixelUi.label(str(KeyBindings.ACTIONS[action]),16,PixelUi.INK);caption.custom_minimum_size.x=150;caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(caption)
		var button:=PixelUi.compact_button(KeyBindings.label(action),16);button.custom_minimum_size.x=120;button.set_meta("binding_action",action);row.add_child(button);_binding_buttons[action]=button
		button.pressed.connect(func()->void:
			_binding_capture=action;_binding_button=button;button.text="等待按键…";_binding_status.text="修改「%s」· 按键盘键或鼠标侧键 · Esc 取消"%str(KeyBindings.ACTIONS[action]))
	var reset:=PixelUi.compact_button("恢复默认键位",16);body.add_child(reset)
	reset.pressed.connect(func()->void:
		_binding_capture=""
		if KeyBindings.reset():
			for action:String in _binding_buttons:_binding_buttons[action].text=KeyBindings.label(action)
			_binding_status.text="已恢复默认键位"
		else:_binding_status.text="保存失败，键位未修改")

func _setting_toggle(caption: String, value: bool, change: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.custom_minimum_size.y = 60 if MobileControls.enabled() else 40
	check.add_theme_font_size_override("font_size", 18)
	check.text = caption + ("：开" if value else "：关")
	check.button_pressed = value
	check.toggled.connect(func(on: bool) -> void:
		check.text = caption + ("：开" if on else "：关")
		change.call(on))
	ComicMotion.bind_button(check)
	return check


func _volume_row(label: String, value: float, on_change: Callable) -> Control:
	var row := UiFactory.hbox(14)
	var name_label := PixelUi.label(label, 20, PixelUi.INK)
	name_label.custom_minimum_size = Vector2(120.0, 0.0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(80.0, 60.0 if MobileControls.enabled() else 48.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var percentage := PixelUi.label("%d%%" % roundi(value * 100), 17, PixelUi.GOLD)
	percentage.custom_minimum_size.x = 56
	percentage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percentage)
	slider.value_changed.connect(func(v: float) -> void:
		percentage.text = "%d%%" % roundi(v * 100)
		on_change.call(v))
	return row


## ---------------- 冒险记录 ----------------

func _build_record() -> void:
	if _record_character==&"":_record_character=Characters.current_id()
	var selector:=OptionButton.new()
	var ids:Array[StringName]=[]
	for character in Characters.all():
		ids.append(character.id);selector.add_item(character.name)
	selector.select(maxi(0,ids.find(_record_character)))
	selector.item_selected.connect(func(index:int)->void:_record_character=ids[index];_show_view(View.RECORD))
	_content.add_child(selector)
	var chapter_selector:=OptionButton.new()
	chapter_selector.add_item("第一关 · 苏醒林地");chapter_selector.add_item("第二关 · 失名星城")
	chapter_selector.select(1 if _record_chapter==ChapterCatalog.NEXT else 0)
	chapter_selector.item_selected.connect(func(index:int)->void:_record_chapter=ChapterCatalog.NEXT if index==1 else ChapterCatalog.FIRST;_show_view(View.RECORD))
	_content.add_child(chapter_selector)
	var title := PixelUi.title(str(Characters.DATA[_record_character].name)+" · "+ChapterCatalog.title(_record_chapter),28)
	title.custom_minimum_size = Vector2(0.0, 60.0)
	_content.add_child(title)
	_content.add_child(PixelUi.label("最高波次：第 %d 波" % int(SaveService.data.get("best_wave", 0)), 22, PixelUi.INK))
	_content.add_child(PixelUi.label("累计局数：%d 局" % int(SaveService.data.get("runs", 0)), 22, PixelUi.INK))
	_content.add_child(PixelUi.label("累计金币：%d" % int(SaveService.data.get("meta_coins", 0)), 22, PixelUi.INK))
	var journal := ScrollContainer.new()
	journal.custom_minimum_size.y = 180
	journal.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(journal)
	var entries := UiFactory.vbox(6)
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal.add_child(entries)
	var scenes: Array[StringName] = [Story.INTRO_FIRST, &"intro_weapon", Story.DEATH_FIRST, &"death_hall", &"death_hall_intro", &"death_reenter"]
	for wave in range(10, 101, 10): scenes.append(Story.checkpoint_id(wave))
	if _record_chapter==ChapterCatalog.NEXT:scenes.assign(CityStories.IDS)
	scenes.append(&"fate_observation")
	for scene_id in scenes:
		var unlocked := StoryState.seen(scene_id,_record_character)
		var scene := Story.get_scene(scene_id,false,_record_character)
		var caption := str(scene.get("title", "星辉回廊"))
		var entry := PixelUi.list_button(caption + (" · 回看" if unlocked else " · 尚未解锁"), 56)
		entry.disabled = not unlocked
		entries.add_child(entry)
		entry.pressed.connect(func() -> void: story_replay_requested.emit(scene_id,_record_character))

	_content.add_child(_rule())
	var info := SaveService.run_info()
	if info.is_empty():
		_content.add_child(PixelUi.label("没有可继续的存档", 18, PixelUi.MUTED))
	else:
		_content.add_child(PixelUi.label(
			"上次进度：第 %d 波 · %d 金币 · %d 件道具" % [
				int(info.get("wave", 1)), int(info.get("coins", 0)), (info.get("expedition_items",info.get("items", [])) as Array).size()],
			18, PixelUi.MUTED
		))
		_content.add_child(_menu_button("放弃挂起出征 · 带入物品与未撤收益丢失", func() -> void:
			if not Outpost.abandon_saved():_notice="放弃存档保存失败，原出征已保留。"
			_show_view(View.RECORD)
		))
	_content.add_child(UiFactory.spacer())
	_content.add_child(_menu_button("返回", func() -> void: _show_view(View.MAIN)))


func _rule() -> Control:
	var line := ColorRect.new()
	line.color = Color("567b85")
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## ---------------- 道具表（维护用）----------------

func _archive_panel()->VBoxContainer:
	var panel:=PanelContainer.new();panel.name="ArchiveGlass";panel.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.set_meta("ui_layout_canvas",true);_content.add_child(panel)
	panel.add_theme_stylebox_override("panel",InteractionSkin.style("archive"));InteractionSkin.attach_glass(panel)
	var body:=UiFactory.vbox(12);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.add_child(body);return body
func _archive_back()->void:
	var back:=StarUi.button("返回星辉",22);back.custom_minimum_size.y=48;InteractionSkin.apply_button(back,"archive");_content.add_child(back);back.pressed.connect(func()->void:_show_view(View.MAIN))
func _build_items()->void:
	var unlocked_count:int=SaveService.data.achievements.size();_content.add_child(PixelUi.title("星遗录 · %d／%d 成就"%[unlocked_count,AchievementCatalog.DATA.size()],34))
	var tabs:=UiFactory.hbox(10);_content.add_child(tabs)
	for category in ["全部","未完成","已完成","探索","战斗","收集","挑战"]:
		var button:=StarUi.button(category,20);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.set_meta("interaction_selected",category==_achievement_filter);InteractionSkin.apply_button(button,"archive");tabs.add_child(button);button.pressed.connect(func()->void:_achievement_filter=category;_render_view(View.ITEMS))
	var body:=_archive_panel();var scroll:=ScrollContainer.new();scroll.name="AchievementsScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;body.add_child(scroll)
	var list:=UiFactory.vbox(10);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for id:String in AchievementCatalog.DATA:
		var spec:Dictionary=AchievementCatalog.DATA[id];var done:=AchievementCatalog.unlocked(id)
		if _achievement_filter=="未完成" and done or _achievement_filter=="已完成" and not done or _achievement_filter not in ["全部","未完成","已完成"] and str(spec.category)!=_achievement_filter:continue
		var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",InteractionSkin.style("archive"));list.add_child(panel)
		var row:=UiFactory.hbox(18);panel.add_child(row)
		var icon:=TextureRect.new();icon.texture=AchievementCatalog.icon(id);icon.custom_minimum_size=Vector2(70,70);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not done:
			var gray:=ShaderMaterial.new();gray.shader=preload("res://src/ui/locked_icon.gdshader");icon.material=gray
		row.add_child(icon)
		var text:=UiFactory.vbox(4);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
		text.add_child(PixelUi.label(str(spec.name),24,Color("fff0c1") if done else Color("e1eaf2")))
		var desc:=PixelUi.label(str(spec.description),20);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.add_child(desc)
		var progress:="已解锁" if done else "%d／%d"%[AchievementCatalog.progress(id),int(spec.goal)]
		if done:
			var date:=Time.get_datetime_dict_from_unix_time(int(SaveService.data.achievements[id])+8*3600);progress+=" · %04d-%02d-%02d"%[date.year,date.month,date.day]
		text.add_child(PixelUi.label(str(spec.category)+" · "+progress,17,Color("a8c4d5")))
	_archive_back()

func _build_item_catalogue(body:VBoxContainer)->void:
	body.add_child(PixelUi.title("道具收藏 · %d 件" % ItemDB.all().size(), 30))
	var tabs := UiFactory.hbox(8)
	body.add_child(tabs)
	for entry in [["", "全部"], ["weapon", "武器"], ["armor", "护甲"], ["accessory", "饰品"], ["buff", "遗物"], ["potion", "药剂"]]:
		var kind := str(entry[0])
		var tab := PixelUi.compact_button(str(entry[1]) + (" ✓" if _codex_kind == kind else ""), 17)
		tabs.add_child(tab)
		tab.pressed.connect(func() -> void:
			_codex_kind = kind
			_render_view(View.MONSTERS))
	var detail := PixelUi.label("选择道具查看效果与获取途径", 18)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.y = 100
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size.y = 116
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(detail_scroll)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 240
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := UiFactory.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var shown: Array[Dictionary] = []
	for item in ItemDB.all():
		if _codex_kind == "" or str(item.kind) == _codex_kind: shown.append(item)
	if not shown.is_empty() and not shown.any(func(item: Dictionary) -> bool: return str(item.id) == _codex_selected): _codex_selected = str(shown[0].id)
	for item in shown:
		var button := PixelUi.list_button("", 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(button)
		var row := _build_item_row(item)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 34
		row.offset_right = -34
		button.add_child(row)
		var choose := func() -> void:
			_codex_selected = str(item.id)
			detail.text = "%s · %s\n%s\n%s" % [item.name, ItemDB.kind_label(item), item.desc, "需装备后生效" if ItemDB.is_equippable(item) else "背包使用" if ItemDB.is_usable(item) else "获得后立即生效"]
			for node in list.get_children(): node.modulate = Color.WHITE if node == button else Color(0.85, 0.88, 0.92)
		button.pressed.connect(choose)
		if str(item.id) == _codex_selected: choose.call()


func _build_item_row(item: Dictionary) -> Control:
	var row := UiFactory.hbox(8)
	row.add_child(UiFactory.item_icon(item, 26.0))

	var name_label := PixelUi.label(str(item["name"]), 17, PixelUi.INK)
	name_label.custom_minimum_size = Vector2(150.0, 0.0)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = str(item["name"])
	row.add_child(name_label)

	var kind := String(ItemDB.KIND_NAMES.get(item.get("kind", &"buff"), "?"))
	var rarity := ItemDB.rarity_color(int(item["rarity"]))
	row.add_child(PixelUi.label(kind, 15, rarity))
	row.add_child(RarityWordmark.make(int(item.rarity),30))

	row.add_child(UiFactory.spacer())
	# 产出信息：渠道 + 权重（权重越大越常出）
	var sources: Array = item.get("sources", [])
	var source_text := "全部渠道" if sources.is_empty() else "、".join(sources.map(func(source: Variant) -> String: return {"shop":"商店", "chest":"宝箱", "reward":"奖励"}.get(str(source),str(source))))
	var source_label := PixelUi.label("获取：%s" % source_text, 14, PixelUi.MUTED)
	source_label.custom_minimum_size.x = 160
	source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_label.max_lines_visible = 2
	source_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	source_label.tooltip_text = "获取：" + source_text
	row.add_child(source_label)
	return row

func _build_monsters()->void:
	_content.add_child(PixelUi.title("异闻录 · 旅途中的回声",30))
	_content.add_child(PixelUi.label("模型、习性与遭遇记录 · 未知亦有名字",17,PixelUi.MUTED))
	var filters := UiFactory.hbox(12);_content.add_child(filters)
	for category in [["items","装备与遗物"],["monsters","怪物与首领"],["affixes","怪物词条"],["allies","友方雇佣单位"]]:
		var id: String=category[0]
		var button := PixelUi.compact_button(str(category[1])+(" ✓" if _monster_category==id else ""),18)
		filters.add_child(button);button.pressed.connect(func()->void:_monster_category=id;_render_view(View.MONSTERS))
	var body:=_archive_panel()
	if _monster_category=="items":
		_build_item_catalogue(body);InteractionSkin.apply_tree(body,"archive");_archive_back();return
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.y=180
	_monster_scroll=scroll
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list:=UiFactory.vbox(8);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for entry:Dictionary in MonsterCodex.entries(_monster_category):
		var row:=PanelContainer.new();row.add_theme_stylebox_override("panel",InteractionSkin.style("archive"));list.add_child(row)
		var line:=UiFactory.hbox(14);row.add_child(line)
		var icon:=TextureRect.new();icon.texture=MonsterCodex.icon(entry)
		icon.custom_minimum_size=Vector2(76,76);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		line.add_child(icon)
		var text:=UiFactory.vbox(4);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(text)
		text.add_child(PixelUi.label(str(entry.name),20,PixelUi.GOLD))
		var desc:=PixelUi.label(str(entry.desc),20);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.add_child(desc)
		var seen:bool=SaveService.data.get("monster_seen",{}).has(str(entry.id))
		var record: String="酒馆雇佣 · %s"%HireOffers.merc_description(int(entry.kind)) if entry.type=="merc" else "危险度 %d · %s"%[EnemyAffixes.danger_of(StringName(entry.kind)),"已遭遇" if seen else "尚未遭遇"] if entry.type=="affix" else "已遭遇 · 击败 %d 次"%int(SaveService.data.get("monster_kills",{}).get(str(entry.id),0)) if seen else "尚未遭遇"
		text.add_child(PixelUi.label(record,17,PixelUi.MUTED))
	InteractionSkin.apply_tree(body,"archive");_archive_back()

func _star_menu_button(text:String,extent:Vector2,art_id := "")->Button:
	var button:=Button.new();button.text=text;button.size=extent
	button.add_theme_font_override("font",GameFonts.get_font("title"))
	button.add_theme_font_size_override("font_size",30)
	button.add_theme_color_override("font_color",Color("ead6b0"))
	button.add_theme_color_override("font_hover_color",Color("fff1cd"))
	button.add_theme_color_override("font_focus_color",Color("fff1cd"))
	button.add_theme_color_override("font_pressed_color",Color("ffe2a0"))
	button.add_theme_color_override("font_disabled_color",Color("8893a6"))
	button.add_theme_color_override("font_outline_color",Color(.025,.035,.09,.92))
	button.add_theme_constant_override("outline_size",4)
	for state in ["normal","hover","pressed","disabled"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus",StarUi.style(Color.TRANSPARENT,Color(.92,.80,.56,.5),8,0,1))
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var art_path := MENU_LETTERING + art_id + ".tres"
	if not art_id.is_empty() and ResourceLoader.exists(art_path):
		# Keep the semantic caption for focus restoration and accessibility.
		# The painted child is presentation only and cannot intercept input.
		for state in ["font_color","font_hover_color","font_hover_pressed_color","font_focus_color","font_pressed_color","font_disabled_color","font_outline_color"]:
			button.add_theme_color_override(state,Color.TRANSPARENT)
		button.add_theme_constant_override("outline_size",0)
		var lettering := TextureRect.new()
		lettering.name = "MenuLettering"
		lettering.texture = load(art_path)
		lettering.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lettering.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lettering.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		lettering.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lettering.material = PixelUi.art_material()
		button.add_child(lettering)
		lettering.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lettering.offset_left = 24
		lettering.offset_right = -24
		var padding:float = 6.0 if art_id=="settings" else (0.0 if art_id in ["record","continue"] else 3.0)
		lettering.set_meta("vertical_padding",padding)
		lettering.offset_top = padding
		lettering.offset_bottom = -padding
		var update := func() -> void: _update_menu_lettering(button,lettering)
		for event in [button.ready,button.mouse_entered,button.mouse_exited,button.focus_entered,button.focus_exited,button.button_down,button.button_up]:
			event.connect(update)
		UIFlow.navigation_mode_changed.connect(update)
		button.tree_exiting.connect(func() -> void:
			if UIFlow.navigation_mode_changed.is_connected(update):UIFlow.navigation_mode_changed.disconnect(update))
	var sparks:=PixelUi.MenuLetterSpark.new();sparks.size=extent;sparks.letter_width=180
	sparks.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(sparks)
	button.pressed.connect(sparks.fire)
	ComicMotion.bind_button(button)
	return button

func _update_menu_lettering(button:Button,lettering:TextureRect)->void:
	var highlighted := not button.disabled and (button.is_hovered() if UIFlow.pointer_active else button.has_focus())
	lettering.self_modulate = Color(0.78,0.80,0.86,0.75) if button.disabled else (Color(1.14,1.10,1.01,1.0) if highlighted else Color(0.92,0.94,1.0,0.96))
	var padding:float = lettering.get_meta("vertical_padding",3.0)
	var pressed_shift:=1.0 if button.is_pressed() and not button.disabled else 0.0
	lettering.offset_top = padding+pressed_shift
	lettering.offset_bottom = -padding+pressed_shift

func _request_new_game()->void:
	if str(Outpost.data.get("active",{}).get("status",""))=="dead" and not Outpost.finalize_death():
		set_notice("死亡结算尚未保存成功，请重试。");_render_view(View.MAIN);return
	if SaveService.has_run() or not Outpost.active_id().is_empty():
		_abandon_confirm.popup_centered(Vector2i(580,220));return
	_show_view(View.CHARACTER)
func _confirm_new_game()->void:
	if not Outpost.abandon_saved():set_notice("放弃存档保存失败，原出征仍保留，请重试。");_render_view(View.MAIN);return
	_show_view(View.CHARACTER)
