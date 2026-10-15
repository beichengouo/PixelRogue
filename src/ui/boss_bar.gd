class_name BossBar
extends CanvasLayer
## 顶部 HUD 的中心区域，避开左侧属性与右侧地图。
const BAR_W := 720.0
const BAR_H := 22.0
const HUD_HEIGHT := 116.0
const LEFT_RESERVE := 410.0
const RIGHT_RESERVE := 200.0
var _root: Control
var _panel: PanelContainer
var _icon: TextureRect
var _name_label: Label
var _sub_label: Label
var _hp_label: Label
var _head: HBoxContainer
var _column: VBoxContainer
var _bar: StatBar
var _pressure_label: Label
var _pips: HBoxContainer
var _boss_id: StringName = &""
var _max_phase := 1
var _phase := 1
var _fade: Tween
var _await_reveal := false

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
	_panel.add_theme_stylebox_override("panel", PixelUi.style(Color("111f2d"), PixelUi.GOLD, 0, 12, 2))
	_root.add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var row := UiFactory.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = Vector2(48, 48)
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
	_sub_label = PixelUi.label("", 14, PixelUi.MUTED)
	_sub_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_sub_label)
	_hp_label = PixelUi.label("100%", 15, PixelUi.INK.lightened(0.6))
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_hp_label)
	_pips = UiFactory.hbox(4)
	head.add_child(_pips)
	_bar = StatBar.new().setup(Palette.ENEMY_HEALTH, BAR_H, 0)
	_bar.custom_minimum_size.x = 0
	var health_row:=UiFactory.hbox(5);column.add_child(health_row)
	_pressure_label=PixelUi.label("",18,Color("ff4c59"));_pressure_label.hide()
	_pressure_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;health_row.add_child(_pressure_label)
	_bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;health_row.add_child(_bar)

func _fit_layout() -> void:
	if not is_instance_valid(_panel): return
	var viewport := get_viewport().get_visible_rect().size
	var available := maxf(96.0, viewport.x - LEFT_RESERVE - RIGHT_RESERVE - 32.0)
	var width := minf(BAR_W, available)
	var compact := width < 440
	_sub_label.visible = not compact and width >= 610
	_icon.visible = width >= 280
	_icon.custom_minimum_size = Vector2(32, 32) if compact else Vector2(48, 48)
	_name_label.add_theme_font_size_override("font_size", 17 if compact else 21)
	if compact and _hp_label.get_parent() == _head:
		_hp_label.reparent(_column)
		_column.move_child(_hp_label, 1)
	elif not compact and _hp_label.get_parent() == _column:
		_hp_label.reparent(_head)
		_head.move_child(_hp_label, _head.get_child_count() - 2)
	_panel.position = Vector2(LEFT_RESERVE + 16 + (available - width) * 0.5, 14)
	_panel.size = Vector2(width, HUD_HEIGHT - 28)

func _on_boss_started(boss_id: StringName) -> void:
	_cancel_fade()
	_boss_id = boss_id
	var data := BossRoster.get_data(boss_id)
	_name_label.text = str(data["title"])
	_sub_label.text = str(data.get("subtitle", ""))
	_icon.texture = PixelBossArt.icon(boss_id)
	_bar.fill_color = Palette.ENEMY_HEALTH
	_bar.set_max_value(1)
	_bar.set_value(1, true)
	_hp_label.text = "100%"
	_pressure_label.hide();_pressure_label.text=""
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
	if _boss_id == &"" or _bar == null: return
	for node in get_tree().get_nodes_in_group("bosses"):
		var boss := node as BossBase
		if boss == null or boss._dead or boss.boss_id != _boss_id: continue
		_bar.set_max_value(maxf(1, boss.max_hp))
		_bar.set_value(boss.hp)
		_pressure_label.visible=boss.room_pressure_growth>0
		_pressure_label.text=str(boss.room_pressure_growth) if boss.room_pressure_growth>0 else ""
		_hp_label.text = "%d%% · %d / %d" % [roundi(100 * clampf(boss.hp / maxf(1, boss.max_hp), 0, 1)), ceili(boss.hp), ceili(boss.max_hp)]
		if boss.phase != _phase or boss.max_phase != _max_phase:
			_phase = boss.phase
			_refresh_pips(boss.max_phase)
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
