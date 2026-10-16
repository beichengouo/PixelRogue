class_name Hud
extends CanvasLayer
const SKILL_KEYS := ["Q", "F", "G", "V"]
## 战斗界面：血条、金币、波次、道具列表、提示横幅。

var _hud_root:Control
var _vitals:Control
var _resources_row:HBoxContainer
var director: WaveDirector

var _hp_bar: StatBar
var _hp_text: Label
var _coin_text: Label
var _key_text: Label
var _wave_text: Label
var _status_text: Label
var _time_text: Label
var _contract_text:Label
## 等级 / 经验 / 魔法值 / 技能栏 / 药水快捷栏
var _level_text: Label
var _mp_bar: StatBar
var _mp_text: Label
var _skill_bar: HBoxContainer
var _potion_bar: HBoxContainer
var _skill_slots: Array[Control] = []
var _skill_cd_labels: Array[Label] = []
var _skill_icons: Array[Control] = []
var _skill_meters: Array[ProgressBar] = []
var _skill_shades: Array[ColorRect] = []
var _dock: CenterContainer
var _potion_slots: Array[Control] = []
var _minimap: Minimap
var _top_backdrop: NinePatchRect
var _player_statuses: PlayerStatusStrip
var _speaker_box: Control
var _acquired: Label
var _acquired_timer := 0.0
var _banner: Label
var _prompt: Label
var _hint: Label
var _forecast: Label
var _guide: Label
var _skill_ready: Array[bool] = []
var _skill_states: Array[String] = []
var _banner_priority := 0
var _notices: Array[String] = []

var _banner_timer := 0.0
var _banner_duration := 0.0
var _hp_display := 100.0
var _hp_target := 100.0
var _max_hp := 100.0


func _ready() -> void:
	layer = 10
	_build()
	UIFlow.input_device_changed.connect(_refresh_input_hints)
	_refresh_input_hints()
	get_viewport().size_changed.connect(_fit_battle_guide)
	_fit_battle_guide()
	EventBus.mp_changed.connect(_on_mp_changed)
	EventBus.item_received.connect(notify_acquired)
	EventBus.run_started.connect(func(_id: int) -> void: _notices.clear(); _banner_timer = 0.0; _acquired_timer = 0.0)
	EventBus.player_stats_changed.connect(_refresh_progress)
	EventBus.run_started.connect(func(_id: int) -> void: _refresh_progress(); _on_mp_changed(GameState.mp, GameState.MAX_MP); _forecast.hide())
	EventBus.player_damaged.connect(_on_hp_changed)
	EventBus.player_healed.connect(_on_hp_changed)
	EventBus.coins_changed.connect(set_coins)
	EventBus.keys_changed.connect(set_keys)
	EventBus.equipment_changed.connect(_refresh_contract)
	EventBus.hotbar_changed.connect(refresh_potion_bar)
	EventBus.skills_changed.connect(refresh_skill_bar)
	EventBus.talents_changed.connect(refresh_skill_bar)
	EventBus.level_changed.connect(func(_lv: int, _g: int) -> void: refresh_skill_bar())
	EventBus.interact_prompt_show.connect(set_prompt)
	EventBus.interaction_failed.connect(func(message: String) -> void: show_banner(message, 2.0, Palette.UI_DANGER, 2))
	EventBus.interact_prompt_hide.connect(func() -> void: set_prompt(""))
	# 头像只在「和 NPC 对话」时出现（也就是商店界面打开时），
	# 单纯走近 NPC 或站在箱子旁边不再弹头像。
	EventBus.shop_opened.connect(func(_offers: Array) -> void: _set_speaker_visible(true))
	EventBus.shop_closed.connect(func() -> void: _set_speaker_visible(false))
	GameState.play_time_changed.connect(func(_seconds:int)->void:_time_text.text="旅途 "+GameState.play_time_text())
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.rest_started.connect(_on_rest_started)
	EventBus.rest_ended.connect(func() -> void: set_hint(""); _forecast.hide())
	EventBus.enemies_enraged.connect(_on_enemies_enraged)
	EventBus.item_acquired.connect(func(_item:Dictionary)->void:_refresh_contract())
	EventBus.run_started.connect(func(_id:int)->void:_refresh_contract())
	Outpost.changed.connect(_refresh_contract)
	_refresh_contract()
	set_coins(GameState.coins)
	set_keys(GameState.keys)


func _process(delta: float) -> void:
	if is_instance_valid(_player_statuses):
		_player_statuses.available_width = maxf(44.0, minf(336.0, get_viewport().get_visible_rect().size.x - 40.0))
		if _contract_text != null:
			_contract_text.position.y = maxf(222.0, _player_statuses.position.y + (_player_statuses.size.y if _player_statuses.visible else 0.0) + 12.0)
	if _banner_timer > 0.0:
		_banner_timer -= delta
		_banner.modulate.a = minf(clampf((_banner_duration - _banner_timer) / 0.12, 0.0, 1.0), clampf(_banner_timer / 0.18, 0.0, 1.0))
	elif not _notices.is_empty() and _acquired_timer <= 0.0:
		_acquired.text = _notices.pop_front()
		_acquired_timer = 1.6
	elif _banner.modulate.a > 0.0:
		_banner.modulate.a = 0.0

	_acquired_timer = maxf(0, _acquired_timer - delta)
	_acquired.modulate.a = minf(clampf((1.6 - _acquired_timer) / 0.1, 0, 1), clampf(_acquired_timer / 0.15, 0, 1)) if _banner_timer <= 0 else 0.0

	# 等级 / 经验 / 魔法值 / 技能冷却
	if _level_text != null:
		for i in _skill_cd_labels.size():
			var id := GameState.skill_for_slot(i)
			var left := GameState.skill_cooldowns[i] if i < GameState.skill_cooldowns.size() else 0.0
			var missing_mp := id != &"" and left <= 0 and GameState.mp < GameState.skill_cost(id)
			var state := ("empty" if _slot_has_choices(i) else "locked") if id == &"" else ("cooldown" if left > 0 else ("mana" if missing_mp else "ready"))
			while _skill_states.size() <= i: _skill_states.append("")
			if state != _skill_states[i]:
				if state == "ready" and _skill_states[i] != "": ComicMotion.emphasize(_skill_slots[i])
				_skill_states[i] = state
				_skill_icons[i].modulate = Color.WHITE if state == "ready" else (Color("7faacc") if state == "mana" else Color(0.52, 0.58, 0.65))
				_skill_shades[i].visible = state != "ready"
				_skill_cd_labels[i].add_theme_color_override("font_color", Color("a3d8fa") if state == "mana" else (Color("9ee6ab") if state == "ready" else PixelUi.INK))
				var plate := _skill_slots[i].get_node("Box/Plate") as Panel
				var style := plate.get_theme_stylebox("panel") as StyleBoxFlat
				style.border_color = Color("6da9c8") if state == "mana" else (Color("9ee6ab") if state == "ready" else Color("65748a"))
			# The padlock/empty-slot art communicates availability. Keep the icon
			# clear; detailed availability remains in the slot tooltip.
			var text := "" if state in ["locked", "empty", "ready"] else ("缺蓝" if state == "mana" else "%.0f" % ceilf(left))
			if _skill_cd_labels[i].text != text: _skill_cd_labels[i].text = text
			_skill_meters[i].value = 0.0 if id == &"" else clampf(1 - left / maxf(0.1, GameState.skill_cooldown(id)), 0, 1)

	if director != null:
		var wave_text := "第 %d 波" % maxi(1, director.wave)
		if _wave_text.text != wave_text: _wave_text.text = wave_text
		var status_text := director.phase_title()
		if director.phase == WaveDirector.Phase.REST or director.phase == WaveDirector.Phase.PREPARE:
			status_text += " · %d 秒" % int(ceilf(maxf(0.0, director.time_left)))
		if _status_text.text != status_text: _status_text.text = status_text


func set_hp(hp: float, max_hp: float) -> void:
	_hp_target = hp
	_max_hp = max_hp
	if _hp_bar is PlayerStatBar:(_hp_bar as PlayerStatBar).set_capacity_loss(GameState.player.permanent_hp_loss() if is_instance_valid(GameState.player) else 0)
	_hp_bar.set_max_value(maxf(1, max_hp))
	_hp_bar.set_value(hp)
	_hp_text.text = "%d / %d" % [int(round(hp)), int(round(max_hp))]
	_hp_bar.tooltip_text=_hp_text.text
	if _hp_bar is PlayerStatBar and (_hp_bar as PlayerStatBar).capacity_loss>0:_hp_bar.tooltip_text+="\n灰色伤痕：%.1f生命上限，可通过星星／女皇命运牌部分修复。"%(_hp_bar as PlayerStatBar).capacity_loss
	_hp_bar.fill_color = Color("ef596e")


func set_coins(coins: int) -> void:
	if _coin_text!=null:_coin_text.text = str(coins)


func set_keys(keys: int) -> void:
	if _key_text != null:
		_key_text.text = str(keys)


func _slot_has_choices(slot: int) -> bool:
	for unlocked in GameState.unlocked_skills:
		if Skills.is_ultimate(unlocked) != (slot == 3):
			continue
		if unlocked != GameState.ultimate_skill and not GameState.learned_skills.has(unlocked):
			return true
	return false


func refresh_skill_bar() -> void:
	if _skill_bar == null:
		return
	for child in _skill_bar.get_children():
		_skill_bar.remove_child(child)
		child.queue_free()
	_skill_ready.clear()
	_skill_states.clear()
	_skill_slots.clear()
	_skill_cd_labels.clear()
	_skill_icons.clear()
	_skill_meters.clear()
	_skill_shades.clear()
	for slot in 4:
		var id := GameState.skill_for_slot(slot)
		var skill := Skills.get_skill(id,GameState.combat_mode) if id != &"" else {}
		var has_choices := _slot_has_choices(slot)
		var caption := str(skill.get("name", "未装配" if has_choices else "尚未解锁"))
		var column := PixelUi.hud_slot(56.0, UIFlow.hint([&"skill_1", &"skill_2", &"skill_3", &"ultimate"][slot]), caption, slot == 3)
		var box := column.get_node("Box") as Control
		var plate=box.get_node("Plate") as Panel
		var clear_style=(plate.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
		clear_style.bg_color=Color.TRANSPARENT
		clear_style.set_border_width_all(0)
		plate.add_theme_stylebox_override("panel",clear_style)
		var path := str(skill.get("icon", ""))
		var icon := UiFactory.texture_icon(path, 36.0)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 7.0
		icon.offset_top = 7.0
		icon.offset_right = -7.0
		icon.offset_bottom = -7.0
		icon.custom_minimum_size = Vector2.ZERO
		box.add_child(icon)
		var shade := ColorRect.new()
		shade.color = Color.TRANSPARENT
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.visible = false
		box.add_child(shade)
		_skill_shades.append(shade)
		var cooldown := _label("", 19, Color.WHITE)
		cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cooldown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(cooldown)
		var meter := ProgressBar.new()
		meter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		meter.offset_top = -6.0
		meter.offset_left = 5.0
		meter.offset_right = -5.0
		meter.offset_bottom = -2.0
		meter.max_value = 1.0
		meter.show_percentage = false
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meter.add_theme_stylebox_override("background", PixelUi.style(Color("243149"), Color.TRANSPARENT, 0, 0.0, 0))
		meter.add_theme_stylebox_override("fill", PixelUi.style(PixelUi.GOLD, Color.TRANSPARENT, 0, 0.0, 0))
		box.add_child(meter)
		if id == &"":
			icon.hide()
			meter.visible = false
		else:
			column.tooltip_text = "%s\n%s\n消耗 %d 魔法 · 冷却 %.1f 秒" % [caption,
				str(skill.get("desc", "")), int(GameState.skill_cost(id)), GameState.skill_cooldown(id)]
		column.mouse_filter = Control.MOUSE_FILTER_PASS
		_skill_slots.append(column)
		_skill_icons.append(icon)
		_skill_cd_labels.append(cooldown)
		_skill_meters.append(meter)
		_skill_bar.add_child(column)


func refresh_potion_bar() -> void:
	if _potion_bar == null:
		return
	for child in _potion_bar.get_children():
		_potion_bar.remove_child(child)
		child.queue_free()
	_potion_slots.clear()
	for i in GameState.HOTBAR_SIZE:
		var item: Dictionary = GameState.potion_hotbar[i] if i < GameState.potion_hotbar.size() else {}
		var column := PixelUi.hud_slot(42.0, UIFlow.hint(StringName("potion_%d" % (i + 1))), str(item.get("name", "空药剂槽")))
		var box := column.get_node("Box") as Control
		var plate=box.get_node("Plate") as Panel
		plate.add_theme_stylebox_override("panel",PixelUi.style(Color.TRANSPARENT,Color.TRANSPARENT,0,0,0))
		if not item.is_empty():
			var icon := UiFactory.item_icon(item, 26.0)
			icon.position = Vector2(8, 8)
			box.add_child(icon)
		column.mouse_filter = Control.MOUSE_FILTER_PASS
		_potion_slots.append(column)
		_potion_bar.add_child(column)


func set_prompt(text: String) -> void:
	_prompt.text = text


func _set_speaker_visible(value: bool) -> void:
	if _speaker_box != null:
		_speaker_box.visible = value


func bind_minimap(level: Level, player: Node2D) -> void:
	if _minimap == null:
		return
	_minimap.bind(level, player)


func set_hint(text: String) -> void:
	_hint.text = text


func _label(text: String, size: int, color: Color) -> Label:
	## 给文字加一圈深色描边。
	## 换成 Kenney 的明亮天空背景后，浅色文字直接铺在背景上会看不清，
	## 描边是最省事、又不会打乱布局的做法。
	## 注意描边要跟着字号走：字号小的时候 5 像素描边会把汉字糊成一个黑块
	## （「币」「匙」这种笔画密的字尤其明显），所以小字只给 3 像素。
	## 画面自查（截图给视觉模型读）时又发现：19px 上下的字给 3 像素描边还是偏厚，
	## 「币」被糊成了「中」。所以 20px 以下一律收到 2 像素。
	var node := StarUi.label(text, size, color)
	node.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	node.add_theme_constant_override("outline_size", 2 if size <= 20 else clampi(size / 6, 3, 6))
	return node


func show_banner(text: String, duration := 1.6, color := Palette.UI_TEXT, priority := 2) -> void:
	if _banner_timer > 0 and priority < _banner_priority: return
	_banner_priority = priority
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_duration = duration
	_banner_timer = duration
	_banner.modulate.a = 1.0


func _on_hp_changed(_amount: float, hp: float, max_hp: float) -> void:
	if hp > _hp_target:
		_hp_display = hp
	set_hp(hp, max_hp)


func _on_wave_started(wave: int, total: int) -> void:
	show_banner("第 %d 波来袭 · %d 只" % [wave, total], 0.9, Palette.UI_DANGER)
	set_hint("")


func _on_wave_cleared(wave: int) -> void:
	show_banner("第 %d 波清场！" % wave, 0.9, Palette.UI_GOOD)


func _on_rest_started(duration: float) -> void:
	show_banner("休整时间 %d 秒" % int(duration), 0.9, Palette.UI_ACCENT)
	var next_wave := GameState.wave + 1
	var data := WaveTable.build(next_wave)
	var preview: PackedStringArray = []
	var names := {"walkers":"骸骨游荡者", "flyers":"幽骨浮灵", "chargers":"兽人冲锋手", "casters":"死灵法师", "bombers":"自爆骷髅", "guards":"重装骸骨盾卫", "treants":"林地兽人守卫"}
	for key in WaveTable.KINDS:
		if int(data.get(key, 0)) > 0: preview.append(str(names[key]))
	if bool(data.boss):
		var boss_id := StringName(WaveTable.BOSS_WAVES.get(next_wave, &"king"))
		preview = PackedStringArray(["强敌 · " + str(BossRoster.get_data(boss_id).title)])
	_forecast.text = "下一波 · %d  /  %s\n%s" % [next_wave, str(data.stage_name), " · ".join(preview)]
	_forecast.show()
	ComicMotion.reveal(_forecast)
	set_hint("去姜糖处可以交易 / 回血　·　按 [空格] 提前开始下一波")


func _on_enemies_enraged() -> void:
	show_banner("怪物暴怒了，请尽快清理房间。", 3.0, Palette.UI_DANGER,4)


func _build() -> void:
	var root := UiFactory.full_rect()
	_hud_root=root
	root.theme = PixelUi.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)
	_top_backdrop = NinePatchRect.new()
	_top_backdrop.name = "TopHudBackdrop"
	_top_backdrop.texture = preload("res://assets/ui_art/top_hud/top_backdrop_v01.png")
	_top_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_backdrop.offset_left = 6.0
	_top_backdrop.offset_right = -6.0
	_top_backdrop.offset_top = 4.0
	_top_backdrop.offset_bottom = 156.0
	_top_backdrop.patch_margin_left = 48
	_top_backdrop.patch_margin_right = 48
	_top_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_top_backdrop)
	var backing := MarginContainer.new();_vitals=backing
	backing.position = Vector2(82, 18)
	backing.size = Vector2(390, 105)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backing)
	var left := UiFactory.vbox(7)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.add_child(left)
	var hp_row := UiFactory.hbox(8)
	left.add_child(hp_row)
	_hp_bar = PlayerStatBar.new()
	_hp_bar.setup(Color("ef596e"),26.0,0)
	(_hp_bar as PlayerStatBar).configure("hp")
	_hp_bar.custom_minimum_size.x = 232.0
	_hp_bar.warn_ratio = 0.32
	hp_row.add_child(_hp_bar)
	_hp_text = _label("100 / 100", 16, Palette.UI_TEXT)
	hp_row.add_child(_hp_text);_hp_text.hide()
	var mp_row := UiFactory.hbox(8)
	left.add_child(mp_row)
	_mp_bar = PlayerStatBar.new()
	_mp_bar.setup(Color("6db9ec"),20.0,0)
	(_mp_bar as PlayerStatBar).configure("mp")
	_mp_bar.custom_minimum_size.x = 232.0
	_mp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mp_row.add_child(_mp_bar)
	_mp_text = _label("100 / 100", 15, Palette.UI_TEXT_DIM.lightened(0.25))
	mp_row.add_child(_mp_text);_mp_text.hide()
	var level_row := UiFactory.hbox(8);_resources_row=level_row
	left.add_child(level_row)
	_level_text = _label("Lv.1", 15, Palette.UI_ACCENT)
	level_row.add_child(_level_text)
	var coin_icon := UiFactory.sheet_icon(ItemDB.ICON_COIN, 18.0)
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_row.add_child(coin_icon)
	_coin_text = _label(str(GameState.coins), 15, PixelUi.GOLD)
	level_row.add_child(_coin_text)
	# A hidden legacy label avoids breaking old HUD references; keys are retired.
	_key_text = _label("",15,Palette.UI_TEXT);_key_text.hide();level_row.add_child(_key_text)
	_player_statuses = PlayerStatusStrip.new()
	_player_statuses.position = Vector2(20, 92)
	root.add_child(_player_statuses)

	var wave := UiFactory.vbox(3)
	wave.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wave.offset_left = -155.0
	wave.offset_right = 155.0
	wave.offset_top = 20.0
	wave.offset_bottom = 108.0
	root.add_child(wave)
	_wave_text = _label("第 1 波", 24, Color("f4e5c6"))
	_wave_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave.add_child(_wave_text)
	_status_text = _label("", 16, Color("bcc8df"))
	_status_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave.add_child(_status_text)
	_time_text = _label("旅途 "+GameState.play_time_text(),14,PixelUi.MUTED)
	_time_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave.add_child(_time_text)
	_contract_text=_label("",14,PixelUi.GOLD)
	_contract_text.position=Vector2(20,112);_contract_text.size=Vector2(360,110)
	_contract_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_contract_text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(_contract_text)

	_dock = CenterContainer.new()
	root.add_child(_dock)
	_dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dock.offset_left = -240
	_dock.offset_right = 240
	_dock.offset_top = -108
	_dock.offset_bottom = -20
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dock := UiFactory.hbox(24)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(dock)
	_skill_bar = UiFactory.hbox(8)
	dock.add_child(_skill_bar)
	_potion_bar = UiFactory.hbox(6)
	_potion_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	dock.add_child(_potion_bar)
	refresh_skill_bar()
	refresh_potion_bar()
	_minimap = Minimap.new()
	_minimap.name = "Minimap"
	root.add_child(_minimap)
	_banner = UiFactory.outlined_label("", 26, Palette.UI_TEXT, 2)
	_banner.add_theme_font_override("font", StarUi.font())
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 112.0
	_banner.offset_bottom = 164.0
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	ComicMotion.accent(_banner, PixelUi.GOLD)
	_acquired = _label("", 18, PixelUi.GOLD)
	_acquired.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_acquired.offset_left = 240
	_acquired.offset_right = -240
	_acquired.offset_top = -202
	_acquired.offset_bottom = -170
	_acquired.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_acquired.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_acquired.modulate.a = 0
	root.add_child(_acquired)
	_prompt = _label("", 20, Palette.UI_ACCENT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -147.0
	_prompt.offset_bottom = -115.0
	root.add_child(_prompt)
	_hint = _label("", 16, Color("bac6db"))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 24.0
	_hint.offset_top = -81.0
	_hint.offset_right = 360.0
	_hint.offset_bottom = -22.0
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_hint)
	_forecast = _label("", 16, Color("ffe4ac"))
	_forecast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_forecast.offset_left = 240
	_forecast.offset_right = -240
	_forecast.offset_top = 166
	_forecast.offset_bottom = 232
	_forecast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_forecast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_forecast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_forecast)
	_forecast.hide()
	_speaker_box = UiFactory.hbox(10)
	_speaker_box.visible = false
	root.add_child(_speaker_box)



func _refresh_input_hints() -> void:
	refresh_skill_bar()
	refresh_potion_bar()
	if _guide != null:
		_guide.text = "%s 背包  %s 天赋  %s 暂停" % [UIFlow.hint(&"inventory"), UIFlow.hint(&"talents"), UIFlow.hint(&"pause_menu")]

func _refresh_progress() -> void:
	_level_text.text = "Lv.%d" % GameState.level

func _refresh_contract()->void:
	if _contract_text==null:return
	var progress=Outpost.contract_progress(GameState.items)
	_contract_text.visible=not progress.is_empty()
	if progress.is_empty():return
	var parts:PackedStringArray=[]
	for row in progress.rows:parts.append("%s %d＋%d/%d" % [row.name,row.warehouse,row.carried,row.need])
	_contract_text.text="委托 · %s%s\n%s\n仓库＋随身 / 所需" % [progress.title," · 营地可交付" if progress.bank_ready else (" · 撤回可交付" if progress.return_ready else "")," · ".join(parts)]

func _on_mp_changed(mp: float, maximum: float) -> void:
	_mp_bar.set_max_value(maximum)
	_mp_bar.set_value(mp)
	_mp_text.text = "%d/%d" % [int(round(mp)), int(maximum)]
	_mp_bar.tooltip_text=_mp_text.text

func notify_acquired(item: Dictionary) -> void:
	if _notices.size() >= 4: _notices.pop_front()
	_notices.append("获得 %s · %s" % [str(item.get("name", "道具")), "需装备" if ItemDB.is_equippable(item) else ("使用时生效" if ItemDB.is_usable(item) else ("撤回后入库" if ItemDB.is_material(item) else "立即生效"))])

func _fit_battle_guide()->void:
	if _guide==null:return
	var view:=get_viewport().get_visible_rect().size
	_guide.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_guide.offset_left=-minf(510,maxf(160,view.x-36));_guide.offset_right=-18
	_guide.offset_top=-minf(112,view.y*.25);_guide.offset_bottom=-16
	_guide.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_guide.clip_text=true
	_guide.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;_guide.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
	_guide.custom_minimum_size=Vector2.ZERO
