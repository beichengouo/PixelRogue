class_name BossBar
extends CanvasLayer
## 顶部 HUD 的中心区域，避开左侧属性与右侧地图。
const BAR_W := 720.0
const BAR_H := 30.0
const HUD_HEIGHT := 116.0
const LEFT_RESERVE := 360.0
const RIGHT_RESERVE := 200.0
var _root: Control
var _panel: PanelContainer
var _icon: TextureRect
var _name_label: Label
var _name_art:TextureRect
var _hp_label: Label
var _head: HBoxContainer
var _column: VBoxContainer
var _bar: StatBar
var _pressure_icon: TextureRect
var _pips: HBoxContainer
var _boss_id: StringName = &""
var _max_phase := 1
var _phase := 1
var _fade: Tween
var _await_reveal := false
var _last_layout_area:=Rect2()

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.resized.connect(_fit_layout)
	_fit_layout()
	_root.visible = false
	EventBus.boss_started.connect(_on_boss_started)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	UIFlow.stack_changed.connect(_reveal_when_ready)
	EventBus.player_died.connect(func() -> void:
		_cancel_fade()
		_boss_id = &""
		_await_reveal = false
		_root.hide())
	EventBus.run_started.connect(func(_id: int) -> void:
		_cancel_fade()
		_boss_id = &""
		_await_reveal = false
		_root.visible = false)

func _cancel_fade() -> void:
	if _fade != null and _fade.is_valid(): _fade.kill()
	if _root != null: ComicMotion.cancel(_root)

func _reveal_when_ready() -> void:
	if not _await_reveal or UIFlow.has_screen() or _boss_id == &"": return
	_await_reveal = false
	_fade = ComicMotion.reveal(_root)

func _build() -> void:
	_root = UiFactory.full_rect()
	_root.theme = PixelUi.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = PixelUi.inset_panel(12)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_root.add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var row := UiFactory.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = Vector2(88, 88)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(_icon)
	var column := UiFactory.vbox(4)
	_column = column
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var head := UiFactory.hbox(8)
	_head = head
	column.add_child(head)
	_name_label = PixelUi.label("", 21, PixelUi.GOLD)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_name_label)
	_name_art=TextureRect.new();_name_art.name="BossTitleArt";_name_art.mouse_filter=Control.MOUSE_FILTER_IGNORE;_name_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_name_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_name_art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;_name_art.custom_minimum_size=Vector2(0,42);_name_art.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(_name_art)
	var numbers:=UiFactory.hbox(8);numbers.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(numbers)
	_hp_label = PixelUi.label("100%", 15, PixelUi.INK.lightened(0.6))
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	numbers.add_child(_hp_label)
	_pips = UiFactory.hbox(4)
	numbers.add_child(_pips)
	_bar = BossVitalBar.new().setup(Palette.ENEMY_HEALTH, BAR_H, 0)
	_bar.custom_minimum_size.x = 0
	var health_row:=UiFactory.hbox(5);column.add_child(health_row)
	_pressure_icon=TextureRect.new();_pressure_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_pressure_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_pressure_icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;_pressure_icon.custom_minimum_size=Vector2(28,28);_pressure_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;_pressure_icon.hide();health_row.add_child(_pressure_icon)
	_bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;health_row.add_child(_bar)

func _fit_layout() -> void:
	if not is_instance_valid(_panel): return
	var area:=MobileControls.safe_rect() if MobileControls.enabled() else get_viewport().get_visible_rect()
	_last_layout_area=area
	var viewport := area.size
	# Canvas expansion can keep a portrait window's logical width at 1280.
	# Stack only when the central lane really is too narrow for the title.
	var stacked := viewport.x < LEFT_RESERVE + RIGHT_RESERVE + 440.0
	var left := 16.0 if stacked else LEFT_RESERVE + 16.0
	var available := maxf(96.0, viewport.x - 32.0 if stacked else viewport.x - LEFT_RESERVE - RIGHT_RESERVE - 32.0)
	var width := minf(BAR_W, available)
	var compact := width < 440
	_icon.visible = width >= 280
	_icon.custom_minimum_size = Vector2(72, 72) if compact else Vector2(88, 88)
	_name_art.custom_minimum_size.y=36 if compact else 42
	_name_label.add_theme_font_size_override("font_size", 20 if compact else 25)
	_panel.position = area.position+Vector2(left + (available - width) * 0.5, 240 if stacked else 14)
	_panel.size = Vector2(width, HUD_HEIGHT - 28)

func _on_boss_started(boss_id: StringName) -> void:
	_cancel_fade()
	_boss_id = boss_id
	var data := BossRoster.get_data(boss_id)
	_name_label.text = str(data["title"])
	# The very same cropped title resource is used by BossEntranceUI.
	_name_art.texture=BossEntranceArt.pack(str(boss_id)).title
	_name_art.visible=_name_art.texture!=null;_name_art.tooltip_text=_name_label.text
	_name_label.visible=_name_art.texture==null;_fit_layout()
	_icon.texture = BossStageArt.icon(boss_id,1)
	(_bar as BossVitalBar).configure(str(boss_id))
	_bar.fill_color = Palette.ENEMY_HEALTH
	_bar.set_max_value(1)
	_bar.set_value(1, true)
	_hp_label.text = "100%"
	_pressure_icon.hide();_pressure_icon.texture=null
	_phase = 1
	_refresh_pips(1)
	_root.visible = true
	_root.modulate.a = 0
	_await_reveal = true
	_reveal_when_ready()

func _on_boss_defeated(boss_id: StringName) -> void:
	if boss_id != _boss_id: return
	_cancel_fade()
	_boss_id = &""
	_await_reveal = false
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(_root, "modulate:a", 0.0, 0.10 if ComicMotion.reduced() else 0.14)
	_fade.tween_callback(func() -> void: _root.visible = false)

func _process(_delta: float) -> void:
	var area:=MobileControls.safe_rect() if MobileControls.enabled() else get_viewport().get_visible_rect()
	if area!=_last_layout_area:_fit_layout()
	if _boss_id == &"" or _bar == null: return
	for node in get_tree().get_nodes_in_group("bosses"):
		var boss := node as BossBase
		if boss == null or boss._dead or boss.boss_id != _boss_id: continue
		var health := boss.phase_health()
		var phase_changed := int(health.phase) != _phase or int(health.count) != _max_phase
		_bar.set_max_value(float(health.max_hp))
		_bar.set_value(float(health.hp), phase_changed)
		_pressure_icon.visible=boss.room_pressure_growth>0
		_pressure_icon.texture=UnitHealthArt.skull(boss.room_pressure_growth)
		_pressure_icon.tooltip_text="狂暴 %d/%d"%[clampi(boss.room_pressure_growth,0,RoomDirector.MAX_PRESSURE_LEVEL),RoomDirector.MAX_PRESSURE_LEVEL]
		_hp_label.text = "阶段 %d/%d · %d / %d" % [int(health.phase), int(health.count), ceili(float(health.hp)), ceili(float(health.max_hp))]
		if phase_changed:
			_icon.texture=BossStageArt.icon(boss.boss_id,int(health.phase))
			_phase = int(health.phase)
			_refresh_pips(int(health.count))
		return
	_bar.set_value(0)

func _refresh_pips(count: int) -> void:
	_max_phase = maxi(1, count)
	for child in _pips.get_children():
		_pips.remove_child(child)
		child.queue_free()
	for i in _max_phase:
		var pip := ColorRect.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2(8, 8)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.color = PixelUi.GOLD if i < _phase else PixelUi.LINE.darkened(0.35)
		_pips.add_child(pip)
