class_name TavernUI
extends CanvasLayer
## 卡片属性来自实际雇佣公式；所有交易由局内状态处理。
signal hire_requested(offer: Dictionary)
var _closing := false
var _exit_tween: Tween
var _root: Control
var _canvas: Control
var _offers_box: VBoxContainer
var _hired_box: VBoxContainer
var _coins_label: Label
var _status_label: Label
var _offers: Array = []
var _bought: Dictionary = {}
var _visit_wave := -1
var _submit_until := 0
var _offers_scroll: ScrollContainer
var _backdrop: TextureRect
var _reaction: TextureRect
var _npc_state := ""
const NPC_ART := "res://assets/ui_art/tavern/"

func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build()
	_root.visible = false
	EventBus.coins_changed.connect(_refresh_coins)
	EventBus.hired_changed.connect(_refresh_hired)
	EventBus.run_started.connect(func(_id: int) -> void: _visit_wave = -1)

func is_open() -> bool:
	return _root.visible

func open(offers: Array) -> void:
	if not UIFlow.can_open(self): return
	_closing = false
	if _exit_tween != null and _exit_tween.is_valid(): _exit_tween.kill()
	if _visit_wave != GameState.wave:
		_visit_wave = GameState.wave
		_offers = offers
		_bought.clear()
	_refresh_offer_descriptions()
	_root.visible = true
	UIFlow.push_screen(self)
	_set_hostess("welcome")
	_status_label.text = "选择同行者，查看实际属性后雇佣。"
	Outpost.request_checkpoint()
	_rebuild()
	StarUi.reveal(_canvas)
	AudioManager.play(&"ui_click", -6.0)

func close(immediate := false) -> void:
	if not is_open(): return
	if immediate:
		_finish_close()
		return
	if _closing: return
	_closing = true
	ComicMotion.cancel(_canvas)
	ComicMotion.cancel(_reaction)
	_exit_tween = ComicMotion.dismiss(_canvas, _finish_close)

func _finish_close() -> void:
	ComicMotion.cancel(_reaction)
	_reaction.hide()
	_npc_state = ""
	_closing = false
	if _exit_tween != null and _exit_tween.is_valid(): _exit_tween.kill()
	if not is_open(): return
	_root.visible = false
	UIFlow.pop_screen(self)
	EventBus.tavern_closed.emit()

func _input(event: InputEvent) -> void:
	if not UIFlow.is_top(self) or _closing: return
	if is_open() and (event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()

func _refresh_coins(coins: int) -> void:
	_coins_label.text = "金币 %d" % coins
	for candidate in _offers_box.find_children("*", "Button", true, false):
		var index := int(candidate.get_meta("offer_index", -1))
		if index < 0 or index >= _offers.size(): continue
		var price := int(_offers[index]["price"])
		candidate.disabled = _bought.has(index) or coins < price
		candidate.text = "已雇佣" if _bought.has(index) else ("雇佣" if coins >= price else "金币不足")
		InteractionSkin.apply_button(candidate,"tavern")

func _hire(index: int) -> void:
	if _closing or not UIFlow.is_top(self) or not is_open() or index < 0 or index >= _offers.size() or _bought.has(index): return
	if Time.get_ticks_msec() < _submit_until: return
	_submit_until = Time.get_ticks_msec() + 120
	var offer: Dictionary = _offers[index]
	if not GameState.spend_coins(int(offer["price"])):
		_set_hostess("shortage")
		_status_label.text = "金币不足，无法雇佣这位同行者。"
		return
	_set_hostess("success")
	_bought[index] = true
	hire_requested.emit(offer)
	_status_label.text = "%s 已加入本局队伍。" % str(offer["name"])
	ComicMotion.reveal(_status_label, 0.12)
	AudioManager.play(&"coin", -6.0)
	Outpost.request_checkpoint()
	_rebuild()
	ComicMotion.emphasize(_coins_label)
	if index < _offers_box.get_child_count(): ComicMotion.emphasize(_offers_box.get_child(index))

func _rebuild() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var token := str(focused.get_meta("focus_token", "")) if focused != null and _root.is_ancestor_of(focused) else ""
	for child in _offers_box.get_children():
		_offers_box.remove_child(child)
		child.queue_free()
	if _offers.is_empty():
		_offers_box.add_child(PixelUi.label("今日暂无可雇佣的同行者。", 16, PixelUi.MUTED))
	for i in _offers.size(): _offers_box.add_child(_build_offer_card(i, _offers[i]))
	_refresh_coins(GameState.coins)
	_refresh_hired()
	UiArtLayout.refresh(_canvas)
	InteractionSkin.apply_tree(_canvas,"tavern")
	var selected := int(token.trim_prefix("hire:")) if token.begins_with("hire:") else -1
	if selected >= 0 and _bought.has(selected):
		for offset in _offers.size():
			var index := (selected + offset + 1) % _offers.size()
			if not _bought.has(index) and GameState.coins >= int(_offers[index].price):
				token = "hire:%d" % index
				break
	PixelUi.focus_button(_root, token)

func _build_offer_card(index: int, offer: Dictionary) -> Control:
	var card := PixelUi.inset_panel(10)
	card.set_meta("interaction_asset","card_"+str(index%3))
	card.custom_minimum_size.y = 138
	var row := UiFactory.hbox(10)
	card.add_child(row)
	var unit_portrait:=HireOffers.portrait(offer)
	if unit_portrait!=null:
		var icon := TextureRect.new()
		icon.texture = unit_portrait
		icon.custom_minimum_size = Vector2(64, 64)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
	var info := UiFactory.vbox(5)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(PixelUi.chip(HireOffers.combat_label(offer), PixelUi.GOLD, 13))
	for pair in [[str(offer["name"]), 19, PixelUi.INK], [HireOffers.description(offer), 14, PixelUi.MUTED]]:
		var text := PixelUi.label(pair[0], pair[1], pair[2])
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(text)
	var stats := HireOffers.final_stats(offer, GameState.wave, GameState.ally_bonus())
	var values := PixelUi.label("生命 %.0f  ·  攻击 %.0f  ·  速度 %.0f" % [float(stats["hp"]), float(stats["attack"]), float(stats["speed"])], 14)
	values.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	values.tooltip_text = "品质倍率：生命 ×%.2f / 攻击 ×%.2f / 速度 ×%.2f\n属性已计入当前波次与队伍加成。" % [float(offer.get("hp_mul", 1)), float(offer.get("atk_mul", 1)), float(offer.get("spd_mul", 1))]
	info.add_child(values)
	var right := UiFactory.vbox(8)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	var price := PixelUi.label("%d 金币" % int(offer["price"]), 16, PixelUi.GOLD)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(price)
	var hire := PixelUi.compact_button("雇佣", 16)
	hire.custom_minimum_size = Vector2(108, 42)
	hire.set_meta("offer_index", index)
	hire.set_meta("focus_token", "hire:%d" % index)
	hire.pressed.connect(_hire.bind(index))
	right.add_child(hire)
	var inspect := PixelUi.compact_button("查看同行者", 15)
	inspect.custom_minimum_size = Vector2(108, 34)
	inspect.set_meta("focus_token", "inspect:%d" % index)
	inspect.pressed.connect(_inspect_offer.bind(index))
	right.add_child(inspect)
	return card

func _strip_of(kind: StringName) -> String:
	match kind:
		&"flyer": return "skull"
		&"caster": return "vampire"
		&"charger", &"guard": return "skeleton2"
		&"treant": return "treant"
		_: return "skeleton"

func _refresh_hired() -> void:
	if _hired_box == null: return
	for child in _hired_box.get_children():
		_hired_box.remove_child(child)
		child.queue_free()
	if GameState.hired.is_empty():
		var empty := PixelUi.label("队伍暂时空着。\n雇佣的同行者只在本局存在，阵亡后不会复活。", 18, PixelUi.MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_hired_box.add_child(empty)
		return
	for entry in GameState.hired:
		var card := PixelUi.inset_panel(8)
		card.set_meta("interaction_asset","card_0")
		_hired_box.add_child(card)
		var column := UiFactory.vbox(5)
		card.add_child(column)
		var title := PixelUi.label(str(entry.get("name", "同行者")), 16)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(title)
		var hp_now := _hp_of(entry)
		var hp_max := _hp_max_of(entry)
		column.add_child(PixelUi.label("HP %.0f / %.0f" % [hp_now, hp_max], 14, PixelUi.MUTED))
		var bar := StatBar.new().setup(Color("92c79b"), 10, 0)
		bar.set_max_value(hp_max)
		bar.set_value(hp_now, true)
		column.add_child(bar)

func _hp_of(entry: Dictionary) -> float:
	for node in get_tree().get_nodes_in_group("allies"):
		var ally := node as HiredAlly
		if ally != null and ally.uid == str(entry.get("uid", "")): return ally.hp
	return 0

func _hp_max_of(entry: Dictionary) -> float:
	for node in get_tree().get_nodes_in_group("allies"):
		var ally := node as HiredAlly
		if ally != null and ally.uid == str(entry.get("uid", "")): return maxf(1, ally.max_hp)
	return maxf(1, float(HireOffers.final_stats(entry, GameState.wave, GameState.ally_bonus())["hp"]))

func _inspect_offer(index: int) -> void:
	if _closing or not is_open() or not UIFlow.is_top(self): return
	if index < 0 or index >= _offers.size(): return
	var offer: Dictionary = _offers[index]
	var poor := GameState.coins < int(offer.price)
	_set_hostess("shortage" if poor else "inspect")
	_status_label.text = ("还差 %d 金币，攒够再来吧。" % (int(offer.price)-GameState.coins)) if poor else ("%s · 查看卡片上的实际属性，点击雇佣确认。" % str(offer.name))
	ComicMotion.reveal(_status_label, 0.12)

func _set_hostess(state: String) -> void:
	if _backdrop == null or state == _npc_state: return
	ComicMotion.cancel(_reaction)
	_npc_state = state
	_reaction.texture=NpcArt.portrait("tavern",state)
	_reaction.show()
	ComicMotion.reveal(_reaction,0.12)

func _place(node: Control, rect: Rect2) -> void:
	_canvas.add_child(node)
	UiArtLayout.register("tavern",node,rect)
	node.position = rect.position
	node.size = rect.size

func _background() -> TextureRect:
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(art, Rect2(0,0,1280,720))
	return art

func _build() -> void:
	_root = UiFactory.full_rect()
	_root.theme = PixelUi.theme()
	add_child(_root)
	_root.add_child(UiFactory.dim_layer(0.88))
	_canvas = StarUi.frame(_root, Vector2(1280, 720))
	_canvas.set_meta("ui_layout_canvas",true)
	_backdrop = _background()
	_backdrop.texture=NpcArt.background("tavern")
	_reaction = TextureRect.new();_reaction.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_reaction.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;_reaction.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_place(_reaction,Rect2(38,96,410,525))
	_reaction.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reaction.hide()
	_place(PixelUi.title("星灯酒馆", 35, PixelUi.GOLD), Rect2(490,26,745,48))
	_place(PixelUi.label("林间灯火 · 本局同行，阵亡不复活", 17, PixelUi.MUTED), Rect2(493,77,740,26))
	var offers_panel := PixelUi.inset_panel(16)
	_place(offers_panel, Rect2(490,112,745,320))
	var left := UiFactory.vbox(10)
	offers_panel.add_child(left)
	left.add_child(PixelUi.label("今日可雇佣 · 属性已计入波次与队伍加成", 18, PixelUi.GOLD))
	_offers_scroll = ScrollContainer.new()
	_offers_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_offers_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_offers_scroll.follow_focus = true
	left.add_child(_offers_scroll)
	_offers_box = UiFactory.vbox(8)
	_offers_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offers_scroll.add_child(_offers_box)
	var hired_panel := PixelUi.inset_panel(16)
	_place(hired_panel, Rect2(490,450,745,155))
	var right := UiFactory.vbox(8)
	hired_panel.add_child(right)
	right.add_child(PixelUi.label("我的队伍", 18, PixelUi.GOLD))
	var hired_scroll := ScrollContainer.new()
	hired_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hired_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(hired_scroll)
	_hired_box = UiFactory.vbox(8)
	_hired_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hired_scroll.add_child(_hired_box)
	_place(PixelUi.label("温阮", 23, PixelUi.GOLD), Rect2(100,624,280,35))
	_status_label = PixelUi.label("", 17, PixelUi.MUTED)
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(_status_label, Rect2(500,614,720,27))
	var coin:=UiFactory.sheet_icon(ItemDB.ICON_COIN,26);coin.mouse_filter=Control.MOUSE_FILTER_IGNORE;_place(coin,Rect2(490,659,28,28))
	_coins_label = PixelUi.label("", 23, PixelUi.GOLD)
	_place(_coins_label, Rect2(535,659,370,32))
	var leave := PixelUi.button("离开酒馆  [Esc]", 18, 0, 50)
	leave.set_meta("focus_token", "close")
	leave.pressed.connect(close)
	_place(leave, Rect2(995,639,240,61))
	UiArtLayout.refresh(_canvas)
	InteractionSkin.apply_tree(_canvas,"tavern")

func expedition_snapshot() -> Dictionary:
	var bought: Array = []
	for key in _bought: bought.append(int(key))
	return {"wave":_visit_wave,"offers":_offers.duplicate(true),"bought":bought}

func expedition_restore(data: Dictionary) -> void:
	_visit_wave = int(data.get("wave",-1))
	_offers = data.get("offers",[]).duplicate(true)
	_refresh_offer_descriptions()
	_bought.clear()
	for index in data.get("bought",[]): _bought[int(index)] = true

func _refresh_offer_descriptions()->void:
	# Rebuild stale saved copy without rerolling units, prices or attributes.
	for offer in _offers:
		if offer is Dictionary:offer["desc"]=HireOffers.description(offer)
