class_name ItemChoiceUI
extends CanvasLayer
## 通关一波后的三选一奖励 —— 肉鸽的成长就靠这里。
##
## 整张卡片可选择；长说明保留滚动，拖动不会被当成领奖。
## 三张卡依次星光显现；选中确认后收拢，未选卡片化为光点。

signal item_chosen(item: Dictionary)
## 打开/关闭时通知外部（用来把战斗 HUD 藏起来，免得 HUD 的波次横幅压在三选一上）
signal opened
signal closed

const CARD_SIZE := Vector2(300.0, 488.0)
const GLOW_PAD := 12.0
const OPEN_GUARD_MS := 250
const APPEAR_SECONDS := 0.38
const APPEAR_STAGGER := 0.07
const CHOICE_SECONDS := 0.64
const REDUCED_CHOICE_SECONDS := 0.16

## 品质流光：一圈会转的亮弧（和背包里那套一致）
const GLOW_SHADER := """
shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(0.5, 0.7, 1.0, 1.0);
uniform float speed = 1.2;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = max(abs(uv.x), abs(uv.y)) * 2.0;
	float ang = atan(uv.y, uv.x);
	float ring = step(0.94, d) * (1.0 - step(0.965, d));
	float sweep = pow(max(0.0, cos(ang - floor(TIME * 8.0) / 8.0 * speed)), 5.0);
	float a = ring * (0.06 + 0.45 * sweep);
	COLOR = vec4(glow_color.rgb, glow_color.a * a * COLOR.a);
}
"""

static var _glow_shader: Shader = null

var offers: Array[Dictionary] = []

var _root: Control
var _canvas: Control
var _enter_tween: Tween
var _selection_epoch := 0
var _cards_box: HBoxContainer
var _column: VBoxContainer
var _input_ready_at := 0
var _choosing := false
var _commit_tween: Tween
var _card_enter_tweens:Array[Tween]=[]
var _card_effects:Array[RewardCardFX]=[]
var _visuals:Array[Control]=[]
var _reward_icons:Array[Control]=[]
var _cards: Array[Button] = []
var _scrolls: Array[ScrollContainer] = []
var _pointer_id := -2
var _pointer_card := -1
var _pointer_start := Vector2.ZERO
var _pointer_last := Vector2.ZERO
var _pointer_dragged := false
var _ignore_mouse_until := 0


func _ready() -> void:
	set_meta("blocking_screen", true)
	layer = 25
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open(offers: Array) -> void:
	_stop_card_animation()
	_pointer_id = -2
	_choosing = false
	_selection_epoch += 1
	var entrance_ms:=OPEN_GUARD_MS if ComicMotion.reduced() else maxi(OPEN_GUARD_MS,ceili((APPEAR_SECONDS+APPEAR_STAGGER*maxi(0,offers.size()-1))*1000))
	_input_ready_at = Time.get_ticks_msec() + entrance_ms
	self.offers.assign(offers)
	_rebuild()
	_root.visible = true
	UIFlow.push_screen(self)
	opened.emit()
	_animate_panel_in()
	_animate_cards_in.call_deferred(_selection_epoch)
	PixelUi.focus_button(_root)


func cancel() -> void:
	_stop_card_animation()
	_pointer_id = -2
	_choosing = false
	if _commit_tween != null and _commit_tween.is_valid(): _commit_tween.kill()
	_selection_epoch += 1
	_root.visible = false
	if _enter_tween != null and _enter_tween.is_valid(): _enter_tween.kill()
	UIFlow.pop_screen(self)
	closed.emit()


func _animate_panel_in() -> void:
	if _enter_tween != null and _enter_tween.is_valid(): _enter_tween.kill()
	_enter_tween = StarUi.reveal(_canvas)


func choose(index: int, defer_resume := false) -> void:
	if not UIFlow.is_top(self) or _choosing or index < 0 or index >= offers.size() or not _root.visible:
		return
	_choosing = true
	var epoch := _selection_epoch
	var item := offers[index]
	for button in _root.find_children("*", "Button", true, false): button.disabled = true
	_stop_card_animation()
	if _enter_tween!=null and _enter_tween.is_valid():_enter_tween.kill()
	_canvas.modulate.a=1
	var reduced:=ComicMotion.reduced();var duration:=REDUCED_CHOICE_SECONDS if reduced else CHOICE_SECONDS
	_commit_tween=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	for i in _cards.size():
		var card:=_cards[i];card.scale=Vector2.ONE;card.modulate=Color.WHITE;_visuals[i].position=Vector2(12,12)
		if i==index:
			card.z_index=2;_card_effects[i].play("selected",duration)
			if not reduced:
				var pulse:=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				pulse.tween_property(card,"scale",Vector2.ONE*1.04,.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				pulse.tween_property(card,"scale",Vector2.ONE,.18).set_trans(Tween.TRANS_SINE)
				_card_enter_tweens.append(pulse)
				_reward_icons[i].pivot_offset=_reward_icons[i].size*.5
				_commit_tween.tween_property(_reward_icons[i],"scale",Vector2.ONE*1.18,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_commit_tween.tween_property(_visuals[i],"position:y",-12.0,.22).set_delay(.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_commit_tween.tween_property(card,"modulate:a",0.0,.10 if reduced else .22).set_delay(.06 if reduced else .42)
		else:
			_card_effects[i].play("dissolve",duration if reduced else .46)
			_commit_tween.tween_property(card,"modulate:a",0.0,duration if reduced else .46)
	_commit_tween.chain().tween_callback(_finish_choice.bind(epoch,item,defer_resume))

func _stop_card_animation()->void:
	if _commit_tween!=null and _commit_tween.is_valid():_commit_tween.kill()
	for tween in _card_enter_tweens:
		if tween!=null and tween.is_valid():tween.kill()
	_card_enter_tweens.clear()
	for effect in _card_effects:
		if is_instance_valid(effect):effect.stop()

func _animate_cards_in(epoch:int)->void:
	if epoch!=_selection_epoch or _choosing or not is_open():return
	for i in _cards.size():
		var holder:=_cards[i];var visual:=_visuals[i];var effect:=_card_effects[i]
		var duration:=.10 if ComicMotion.reduced() else APPEAR_SECONDS
		var delay:=0.0 if ComicMotion.reduced() else float(i)*APPEAR_STAGGER
		var icon:=_reward_icons[i];effect.icon_center=effect.get_global_transform().affine_inverse()*icon.get_global_rect().get_center()
		var tween:=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(delay)
		tween.tween_callback(effect.play.bind("appear",duration))
		tween.tween_property(holder,"modulate:a",1.0,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if not ComicMotion.reduced():tween.parallel().tween_property(visual,"position:y",12.0,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_card_enter_tweens.append(tween)

func _finish_choice(epoch: int, item: Dictionary, defer_resume: bool) -> void:
	if epoch != _selection_epoch: return
	_root.visible = false
	if not defer_resume: UIFlow.pop_screen(self)
	closed.emit()
	item_chosen.emit(item)
	if defer_resume: _resume_after_shortcut(_selection_epoch)

func _resume_after_shortcut(epoch: int) -> void:
	# action_release 不会清除同一帧的 just_pressed；等输入边沿过期后再恢复物理帧。
	await get_tree().process_frame
	await get_tree().process_frame
	if epoch != _selection_epoch or is_open(): return
	UIFlow.pop_screen(self)


func _input(event: InputEvent) -> void:
	if not UIFlow.is_top(self): return
	if is_open() and _handle_pointer(event): return
	if not is_open() or not event is InputEventKey: return
	# Confirm cannot inherit the key edge that opened this reward screen.
	if event.is_action_pressed("ui_accept") and Time.get_ticks_msec() < _input_ready_at:
		get_viewport().set_input_as_handled()
		return
	if not event.pressed or event.echo: return
	var index := [KEY_1, KEY_2, KEY_3].find(event.keycode)
	if index >= 0:
		# 数字键也绑定药剂。清掉这一帧的快捷栏动作，避免选奖励时误喝药。
		var action := "potion_%d" % (index + 1)
		if InputMap.has_action(action): Input.action_release(action)
		get_viewport().set_input_as_handled()
		_choose_from_input(index, _selection_epoch, true)

func _choose_from_input(index: int, epoch: int, defer_resume := false) -> void:
	if epoch != _selection_epoch or Time.get_ticks_msec() < _input_ready_at: return
	choose(index, defer_resume)

func _card_at(at: Vector2) -> int:
	for i in _cards.size():
		if _cards[i].get_global_rect().has_point(at): return i
	return -1

func _handle_pointer(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		_ignore_mouse_until = Time.get_ticks_msec() + 100
		UIFlow.set_pointer_active(true)
		if event.pressed: _begin_pointer(event.index, event.position)
		elif _pointer_id == event.index: _end_pointer(event.position)
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventScreenDrag:
		_ignore_mouse_until = Time.get_ticks_msec() + 100
		if _pointer_id == event.index:
			_drag_pointer(event.position)
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < _ignore_mouse_until:
			get_viewport().set_input_as_handled()
			return true
		if event.pressed: _begin_pointer(-1, event.position)
		elif _pointer_id == -1:
			if _end_pointer(event.position):
				get_viewport().set_input_as_handled()
				return true
	elif event is InputEventMouseMotion and _pointer_id == -1:
		_drag_pointer(event.position)
	return false

func _begin_pointer(id: int, at: Vector2) -> void:
	if _pointer_id != -2 or _choosing: return
	_pointer_card = _card_at(at)
	if _pointer_card < 0: return
	_pointer_id = id
	_pointer_start = at
	_pointer_last = at
	_pointer_dragged = false
	_cards[_pointer_card].grab_focus()
	var bar := _scrolls[_pointer_card].get_v_scroll_bar()
	if bar.visible and bar.get_global_rect().has_point(at): _pointer_dragged = true

func _drag_pointer(at: Vector2) -> void:
	if _pointer_card < 0: return
	if at.distance_to(_pointer_start) > 8: _pointer_dragged = true
	var scroll := _scrolls[_pointer_card]
	if _pointer_id >= 0 and _pointer_dragged and scroll.get_global_rect().has_point(_pointer_start):
		var factor := maxf(0.1, scroll.get_global_transform().get_scale().y)
		scroll.scroll_vertical -= roundi((at.y - _pointer_last.y) / factor)
	_pointer_last = at

func _end_pointer(at: Vector2) -> bool:
	var index := _pointer_card
	var select := not _pointer_dragged and at.distance_to(_pointer_start) <= 8 and _card_at(at) == index
	_pointer_id = -2
	_pointer_card = -1
	if select: _choose_from_input(index, _selection_epoch, true)
	return select


func _rebuild() -> void:
	_stop_card_animation()
	_card_effects.clear();_visuals.clear();_reward_icons.clear()
	_cards.clear()
	_scrolls.clear()
	for child in _cards_box.get_children():
		_cards_box.remove_child(child)
		child.queue_free()
	for i in offers.size():
		_cards_box.add_child(_build_card(i, offers[i]))


## ---------------- 单张卡 ----------------

func _build_card(index: int, item: Dictionary) -> Control:
	var rarity := int(item["rarity"])
	var color := ItemDB.rarity_color(rarity)

	# 外层 holder：不放容器里排版，方便挂"比卡片大一圈"的流光
	var holder := Button.new()
	holder.name = "RewardCard%d" % index
	holder.set_meta("glass_skip_style",true)
	holder.button_mask = 0 # Keyboard/gamepad use Button; pointer taps are guarded above.
	holder.focus_mode = Control.FOCUS_ALL
	holder.set_meta("focus_token", "reward:" + str(index))
	for state in ["normal", "hover", "pressed", "disabled"]:
		holder.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_cards.append(holder)
	holder.custom_minimum_size = CARD_SIZE + Vector2(GLOW_PAD, GLOW_PAD) * 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.pivot_offset = holder.custom_minimum_size * 0.5
	if rarity>=1 and not ComicMotion.reduced():holder.add_child(_build_glow(color))

	var card := PanelContainer.new()
	card.set_meta("glass_exempt",true)
	card.position = Vector2(GLOW_PAD, GLOW_PAD)
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := PixelUi.plate(4)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: frame.set_content_margin(side, 24)
	card.add_theme_stylebox_override("panel", frame)
	holder.add_child(card)

	var column := UiFactory.vbox(8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	var band := ColorRect.new()
	band.color = color
	band.custom_minimum_size = Vector2(0.0, 6.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(band)

	# 保持整数尺寸，避免缩放动画让像素边缘变软。
	var icon_row := UiFactory.hbox(0)
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(icon_row)
	var icon := UiFactory.item_icon(item, 64.0)
	icon_row.add_child(icon)
	_reward_icons.append(icon)

	# 一行小标签：先分类（装备/遗物/药水），再稀有度 —— 一眼看出这是什么东西
	var tag_row := UiFactory.hbox(8)
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(tag_row)
	tag_row.add_child(PixelUi.chip("祭坛誓约" if item.has("altar_key") else ItemDB.kind_label(item), ItemDB.kind_color(item), 14))
	if not item.has("altar_key"):tag_row.add_child(RarityWordmark.make(rarity,32))

	var name_label := PixelUi.label(str(item["name"]), 20, PixelUi.INK)
	name_label.tooltip_text = str(item["name"])
	name_label.max_lines_visible = 2
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)

	column.add_child(_rule(Palette.PARCHMENT_RULE))

	var activation := PixelUi.label("使用时生效" if ItemDB.is_usable(item) else ("需装备 · 在行囊中装配" if ItemDB.is_equippable(item) else "获得后立即生效"), 15, PixelUi.GOLD)
	activation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(activation)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 72
	scroll.follow_focus = false
	scroll.focus_mode = Control.FOCUS_NONE
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_scrolls.append(scroll)
	var desc := PixelUi.label(str(item["desc"]) + "\n\n" + ItemInsight.describe(item, false, false), 17, PixelUi.INK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 220
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(desc)

	# Presentation descendants pass through; the scroll remains an interactive child.
	for node in card.find_children("*", "Control", true, false):
		if node != scroll and not scroll.is_ancestor_of(node): node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	var update := func() -> void:
		if _choosing: return
		var active := holder.get_global_rect().has_point(get_viewport().get_mouse_position()) if UIFlow.pointer_active else holder.has_focus()
		_hover(holder, active)
	for event in [holder.focus_entered, holder.focus_exited, holder.mouse_entered, holder.mouse_exited, scroll.mouse_entered, scroll.mouse_exited]: event.connect(update)
	UIFlow.navigation_mode_changed.connect(update)
	holder.tree_exiting.connect(func() -> void:
		if UIFlow.navigation_mode_changed.is_connected(update): UIFlow.navigation_mode_changed.disconnect(update))
	var epoch := _selection_epoch
	holder.pressed.connect(func() -> void: _choose_from_input(index, epoch, true))

	var effect:=RewardCardFX.new();effect.name="RewardPresentation";holder.add_child(effect);effect.position=Vector2.ZERO;effect.size=holder.custom_minimum_size;effect.configure(card,color);_card_effects.append(effect)
	_visuals.append(card)
	holder.scale=Vector2.ONE;holder.modulate.a=0.0
	card.position.y=12 if ComicMotion.reduced() else 36
	return holder


func _build_glow(color: Color) -> ColorRect:
	var glow := ColorRect.new()
	glow.position = Vector2.ZERO
	glow.size = CARD_SIZE + Vector2(GLOW_PAD, GLOW_PAD) * 2.0
	glow.custom_minimum_size = glow.size
	glow.color = Color.WHITE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW_SHADER
	material.shader = _glow_shader
	material.set_shader_parameter("glow_color", color)
	if ComicMotion.reduced(): material.set_shader_parameter("speed", 0.0)
	glow.material = material
	return glow


func _hover(card: Control, on: bool) -> void:
	if is_instance_valid(card):
		card.modulate = Color(1.10, 1.10, 1.10, card.modulate.a) if on else Color(1, 1, 1, card.modulate.a)


func _rule(color: Color) -> Control:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## ---------------- 骨架 ----------------

func _build() -> void:
	_root = UiFactory.full_rect()
	_root.theme = PixelUi.theme()
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(UiFactory.dim_layer(0.42))

	_canvas = StarUi.frame(_root, Vector2(1060, 656))
	_column = UiFactory.vbox(18)
	var column := _column
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(column)

	var title := UiFactory.outlined_label("选择一件奖励", 40, Palette.UI_ACCENT, 8)
	title.custom_minimum_size = Vector2(0.0, 66.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_cards_box = UiFactory.hbox(10)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_cards_box)

	var tip := UiFactory.outlined_label("点击卡片领取 · 1 / 2 / 3 选择 · 方向键切换 · %s / A 确认"%KeyBindings.label("ui_accept"), 18, PixelUi.MUTED, 5)
	if MobileControls.enabled():tip.text="轻点卡片领取 · 滑动说明查看详情"
	tip.custom_minimum_size = Vector2(0.0, 38.0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tip)
	InteractionSkin.mount(_root,"reward")

