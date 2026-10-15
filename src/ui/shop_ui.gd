class_name ShopUI
extends CanvasLayer
## 商店界面。打开时会暂停游戏（这样休整倒计时也会停）。

const REST_HEAL := 30.0
## 钥匙：每次开张价格随机（这就是「随机刷新」），每买一把涨一点
const KEY_PRICE_MIN := 14
const KEY_PRICE_MAX := 34
const KEY_PRICE_STEP := 6
const KEY_MAX_PER_VISIT := 3
## 花金币重新抽一次货架
const REFRESH_COST := 8
const ACTION_INTERVAL_MS := 120
const OPEN_DURATION := 0.22
const BACKDROP := "res://assets/ui_art/shop/star_shop_backdrop.png"
const PORTRAIT := "res://assets/ui_art/shop/merchant_portrait.png"
var _npc_portrait:TextureRect

var _closing := false
var _exit_tween: Tween
var _root: Control
var _canvas: Control
var _status_label: Label
var _close_button: Button
var _grid: GridContainer
var _coins_label: Label
var _rest_button: Button
var _key_button: Button
var _refresh_button: Button
var _offers: Array[Dictionary] = []
var _sold: Dictionary = {}
var _rest_used := false
var _key_price := KEY_PRICE_MIN
var _key_bought := 0
var _visit_wave := -1
var _selected_index := -1
var _purchase_button: Button
var _detail_title: Label
var _detail_tag: Label
var _detail_quality:RarityWordmark
var _detail_description: Label
var _detail_scroll: ScrollContainer
var _detail_icon: Control
var _detail_price: Label
var _reason_label: Label
var _opening_until := 0
var _action_until := 0
var _reveal_tween: Tween
var _rest_hint: Label
var sale_ui: TradeSaleUI
var _panel: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build()
	_root.visible = false
	sale_ui=TradeSaleUI.new()
	add_child(sale_ui)
	var sell_button:=PixelUi.button("出售",17,0,42)
	sell_button.position=Vector2(785,639)
	sell_button.size=Vector2(195,61)
	sell_button.pressed.connect(sale_ui.open)
	sell_button.tooltip_text="出售行囊物资"
	_canvas.add_child(sell_button)
	InteractionSkin.apply_button(sell_button,"shop")
	EventBus.coins_changed.connect(_refresh_coins)
	EventBus.run_started.connect(func(_run_id:int)->void:_visit_wave=-1)


func is_open() -> bool:
	return _root.visible


func open(offers: Array) -> void:
	if not UIFlow.can_open(self): return
	var reopening := _closing
	_closing = false
	if _exit_tween != null and _exit_tween.is_valid(): _exit_tween.kill()
	if is_open() and not reopening: return
	# 同一休整期返回保留货架、购买记录和休整；新局由 run_started 重置。
	if _visit_wave != GameState.wave:
		_visit_wave = GameState.wave
		_offers = _with_wave_prices(offers)
		_sold.clear()
		_rest_used = false
		_key_bought = 0
		_selected_index = 0 if not _offers.is_empty() else -1
		_roll_key_price()
	_opening_until = Time.get_ticks_msec() + int((0.10 if ComicMotion.reduced() else OPEN_DURATION) * 1000)
	_action_until = 0
	_rest_button.disabled = _rest_used
	_rest_hint.text = "本次已休整" if _rest_used else "恢复最多 %d 生命" % int(REST_HEAL)
	(_rest_button as ShopArtButton).update_visual()
	_coins_label.text = "金币 %d" % GameState.coins
	_root.visible = true
	UIFlow.push_screen(self)
	Outpost.request_checkpoint()
	_rebuild()
	_set_status("")
	if _reveal_tween != null and _reveal_tween.is_valid(): _reveal_tween.kill()
	_canvas.modulate.a = 0.0
	_reveal_tween = _canvas.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_reveal_tween.tween_property(_canvas, "modulate:a", 1.0, 0.10 if ComicMotion.reduced() else OPEN_DURATION).set_trans(Tween.TRANS_SINE)
	_reveal_tween.tween_callback(func() -> void:
		_opening_until = 0
		_refresh_detail())
	_focus_selected()


func _can_transact() -> bool:
	return not _closing and UIFlow.is_top(self) and is_open() and Time.get_ticks_msec() >= _opening_until and Time.get_ticks_msec() >= _action_until


func _mark_transaction() -> void:
	_action_until = Time.get_ticks_msec() + ACTION_INTERVAL_MS


func _roll_key_price() -> void:
	_key_price = Rng.stream().randi_range(KEY_PRICE_MIN, KEY_PRICE_MAX)


func _wave_price_factor() -> float:
	## 商品、雇佣和清波收入使用同一波次配置。
	return WaveTable.shop_price_factor(GameState.wave)


func _with_wave_prices(offers: Array) -> Array[Dictionary]:
	## 注意返回类型必须是 Array[Dictionary]：_offers 是类型化数组，
	## 直接塞一个无类型 Array 进去会在运行时抛 "Trying to assign an array of type Array...".
	var out: Array[Dictionary] = []
	var factor := _wave_price_factor()
	for raw in offers:
		var item: Dictionary = (raw as Dictionary).duplicate(true)
		item["_base_cost"] = int(item.get("cost",10))
		item["cost"] = maxi(1, int(round(float(item.get("cost", 10)) * factor)))
		out.append(item)
	return out


func key_price() -> int:
	return _key_price + _key_bought * KEY_PRICE_STEP


func buy_key() -> void:
	if not _can_transact(): return
	if _key_bought >= KEY_MAX_PER_VISIT:
		_set_status("这次的钥匙已经售罄。", true)
		return
	var cost := key_price()
	if GameState.coins < cost:
		_set_status("金币不足，还需要 %d 金。" % (cost - GameState.coins), true)
		return
	_mark_transaction()
	GameState.spend_coins(cost)
	GameState.add_keys(1)
	_key_bought += 1
	AudioManager.play(&"coin", -6.0)
	_coins_label.text = "金币 %d" % GameState.coins
	if _key_bought >= KEY_MAX_PER_VISIT:
		_set_status("钥匙已售罄；本次已购 %d 把。" % _key_bought)
	else:
		_set_status("购得 1 把钥匙；下一把 %d 金。" % key_price())
	Outpost.request_checkpoint()
	_rebuild()


func refresh_offers() -> void:
	if not _can_transact(): return
	## 花钱换一批货（钥匙价格也跟着重新随机）
	if GameState.coins < REFRESH_COST:
		_set_status("金币不足，刷新需要 %d 金。" % REFRESH_COST, true)
		return
	_mark_transaction()
	GameState.spend_coins(REFRESH_COST)
	_offers = _with_wave_prices(ItemDB.roll_offers(3, Rng.stream(), 0.0, &"shop"))
	_sold.clear()
	_roll_key_price()
	_set_status("货架已刷新，商品按当前波次计价。")
	AudioManager.play(&"ui_click", -6.0)
	_coins_label.text = "金币 %d" % GameState.coins
	Outpost.request_checkpoint()
	_rebuild()


func close(immediate := false) -> void:
	if not is_open(): return
	if immediate:
		_finish_close()
		return
	if _closing: return
	_closing = true
	ComicMotion.cancel(_canvas)
	_exit_tween = ComicMotion.dismiss(_canvas, _finish_close)

func _finish_close() -> void:
	_closing = false
	if _exit_tween != null and _exit_tween.is_valid(): _exit_tween.kill()
	if not _root.visible:
		return
	_root.visible = false
	if sale_ui!=null: sale_ui.close()
	if _reveal_tween != null and _reveal_tween.is_valid(): _reveal_tween.kill()
	UIFlow.pop_screen(self)
	EventBus.shop_closed.emit()


func _input(event: InputEvent) -> void:
	if not UIFlow.is_top(self) or _closing: return
	if is_open() and (event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


func buy(index: int) -> void:
	if not _can_transact(): return
	if index < 0 or index >= _offers.size() or _sold.has(index):
		return
	var item := _offers[index]
	var cost := int(item["cost"])
	if GameState.coins < cost:
		_set_status("金币不足，还需要 %d 金。" % (cost - GameState.coins), true)
		return
	_mark_transaction()
	if not GameState.can_add_item(item):
		_set_status("行囊已满，先出售或整理物品。",true)
		return
	GameState.spend_coins(cost)
	var acquired:Dictionary=item.duplicate(true)
	acquired["cost"]=int(acquired.get("_base_cost",acquired.cost))
	GameState.add_item(acquired)
	_sold[index] = true
	_set_status("购得 %s。%s" % [str(item.name), "请在行囊中装备。" if ItemDB.is_equippable(item) else ("可在行囊中使用。" if ItemDB.is_usable(item) else "效果已生效。")])
	_coins_label.text = "金币 %d" % GameState.coins
	Outpost.request_checkpoint()
	_rebuild()
	ComicMotion.emphasize(_coins_label)
	if index+1 < _grid.get_child_count(): ComicMotion.emphasize(_grid.get_child(index+1))


func use_rest() -> void:
	if not _can_transact(): return
	if _rest_used:
		return
	var player := GameState.player
	if player != null and is_instance_valid(player) and player.has_method("heal_player"):
		player.heal_player(REST_HEAL)
	_rest_used = true
	_rest_button.disabled = true
	_rest_hint.text = "本次已休整"
	(_rest_button as ShopArtButton).update_visual()
	_set_status("完成休整，恢复最多 %d 生命。" % int(REST_HEAL))


func first_affordable_index() -> int:
	for i in _offers.size():
		if not _sold.has(i) and GameState.coins >= int(_offers[i]["cost"]):
			return i
	return -1


func _refresh_coins(coins: int) -> void:
	_coins_label.text = "金币 %d" % coins
	if not is_open(): return
	_update_row_prices()
	_refresh_detail()
	_update_refresh_button()


func _set_status(text: String, danger := false) -> void:
	if is_instance_valid(_npc_portrait):
		_npc_portrait.texture=NpcArt.portrait("merchant","shortage" if danger else "success" if text.begins_with("购得") or text.begins_with("完成休整") else "welcome")
	_status_label.text = text
	_status_label.visible=not text.is_empty()
	_status_label.tooltip_text = text
	ComicMotion.reveal(_status_label, 0.12)
	_status_label.add_theme_color_override("font_color", Color("ffaaa0") if danger else Color("d2d9e7"))


func _selected_data() -> Dictionary:
	if _selected_index >= 0 and _selected_index < _offers.size():
		var item := _offers[_selected_index]
		return {"name": str(item.name), "rarity": int(item.rarity), "tag": ItemDB.kind_label(item),
			"desc": str(item.get("desc", "")), "item": item, "cost": int(item.cost), "sold": _sold.has(_selected_index)}
	return {"name": "神秘钥匙", "rarity": 3, "tag": "补给箱钥匙", "item": ItemDB.key_icon(),
		"desc": "用于开启林地补给箱。\n\n每次休整最多购买 %d 把，已购买 %d 把。\n每买一把，下一把价格增加 %d 金币。刷新货架不会重置本次购买上限。" % [KEY_MAX_PER_VISIT, _key_bought, KEY_PRICE_STEP],
		"cost": key_price(), "sold": _key_bought >= KEY_MAX_PER_VISIT}


func _select_offer(index: int) -> void:
	if is_instance_valid(_npc_portrait):_npc_portrait.texture=NpcArt.portrait("merchant","inspect")
	if index < -1 or index >= _offers.size(): return
	var changed := _selected_index != index
	_selected_index = index
	if changed: _detail_scroll.scroll_vertical = 0
	_refresh_detail()
	_style_rows()


func _purchase_selected() -> void:
	if _selected_index < 0: buy_key()
	else: buy(_selected_index)


func _refresh_detail() -> void:
	if not is_open(): return
	var data := _selected_data()
	var tint := ItemDB.rarity_color(int(data.rarity))
	_detail_title.text = str(data.name)
	_detail_title.tooltip_text = str(data.name)
	_detail_tag.text = str(data.tag)
	_detail_quality.set_quality(int(data.rarity))
	_detail_tag.add_theme_color_override("font_color", tint)
	_detail_description.text = str(data.desc) + ("\n\n" + ItemInsight.describe(data.item) if _selected_index >= 0 else "")
	for child in _detail_icon.get_children():
		_detail_icon.remove_child(child)
		child.queue_free()
	var icon := UiFactory.item_icon(data.item, 84)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_icon.add_child(icon)
	_detail_price.text = "%d 金币" % int(data.cost)
	_purchase_button.disabled = bool(data.sold) or GameState.coins < int(data.cost) or Time.get_ticks_msec() < _opening_until
	(_purchase_button as ShopArtButton).set_art("key" if _selected_index < 0 else "purchase")
	if bool(data.sold):
		_reason_label.text = "本次钥匙已售罄" if _selected_index < 0 else "已购买 · 物品已放入行囊"
	elif GameState.coins < int(data.cost):
		_reason_label.text = "金币不足 · 还差 %d 金币" % (int(data.cost) - GameState.coins)
	elif Time.get_ticks_msec() < _opening_until:
		_reason_label.text = "星灯正在点亮…"
	else:
		_reason_label.text = "选择不会扣款，点击购买确认交易"
	_reason_label.add_theme_color_override("font_color", Color("ffaaa0") if GameState.coins < int(data.cost) and not bool(data.sold) else Color("a8b8d2"))
	_purchase_button.tooltip_text = _reason_label.text


func _rebuild() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var token := str(focus.get_meta("focus_token", "")) if focus != null and _root.is_ancestor_of(focus) else ""
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_key_button = _make_row(-1)
	_grid.add_child(_key_button)
	for i in _offers.size(): _grid.add_child(_make_row(i))
	_selected_index = clampi(_selected_index, -1, _offers.size() - 1)
	_refresh_detail()
	_update_refresh_button()
	_update_row_prices()
	_style_rows()
	_wire_navigation()
	if is_open():
		var restored := false
		for button in _focus_buttons():
			if str(button.get_meta("focus_token", "")) == token and not button.disabled:
				button.grab_focus()
				restored = true
				break
		if not restored: _focus_selected()


func _make_row(index: int) -> Button:
	var data: Dictionary
	if index < 0:
		data = {"name": "神秘钥匙", "rarity": 3, "tag": "补给箱钥匙", "item": ItemDB.key_icon(), "cost": key_price(), "sold": _key_bought >= KEY_MAX_PER_VISIT}
	else:
		var item := _offers[index]
		data = {"name": str(item.name), "rarity": int(item.rarity), "tag": ItemDB.kind_label(item), "item": item, "cost": int(item.cost), "sold": _sold.has(index)}
	var button := _button("", 18)
	button.custom_minimum_size = Vector2(358, 112)
	button.set_meta("index", index)
	button.set_meta("focus_token", "key" if index < 0 else "offer:" + str(index))
	button.set_meta("cost", int(data.cost))
	button.set_meta("sold", bool(data.sold))
	button.pressed.connect(func() -> void: _select_offer(index))
	button.mouse_entered.connect(func() -> void: _select_offer(index))
	button.focus_entered.connect(func() -> void:
		if not UIFlow.pointer_active: _select_offer(index))
	var icon := UiFactory.item_icon(data.item, 52)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(button, icon, Rect2(20,30,52,52))
	var title := _label(str(data.name), 21)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(button, title, Rect2(82,20,250,29))
	_place(button,RarityWordmark.line(int(data.rarity),str(data.tag),28,15,ItemDB.rarity_color(int(data.rarity))),Rect2(82,47,252,28))
	var price := _label("", 16, PixelUi.GOLD)
	_place(button, price, Rect2(82,78,250,22))
	button.set_meta("price_label", price)
	button.tooltip_text = ""
	return button


func _update_row_prices() -> void:
	for row: Button in _grid.get_children():
		var index := int(row.get_meta("index"))
		var cost := key_price() if index < 0 else int(_offers[index].cost)
		var sold := _key_bought >= KEY_MAX_PER_VISIT if index < 0 else _sold.has(index)
		row.set_meta("cost", cost)
		row.set_meta("sold", sold)
		var price: Label = row.get_meta("price_label")
		price.text = "已售罄 · 可查看" if sold else "%d 金币" % cost if GameState.coins >= cost else "%d 金币 · 还差 %d" % [cost, cost - GameState.coins]
		price.add_theme_color_override("font_color", Color("a8b8d2") if sold else PixelUi.GOLD if GameState.coins >= cost else Color("ffaaa0"))


func _style_rows() -> void:
	for row: Button in _grid.get_children():
		var selected := int(row.get_meta("index")) == _selected_index
		var box := _drawn_style(true, Color("ffe8b0") if selected else Color("b7c6c2"))
		row.add_theme_stylebox_override("normal", box)


func _focus_selected() -> void:
	var position := _selected_index + 1
	if position >= 0 and position < _grid.get_child_count():
		(_grid.get_child(position) as Button).grab_focus()


func _focus_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for row: Button in _grid.get_children(): buttons.append(row)
	buttons.append_array([_purchase_button, _rest_button, _refresh_button, _close_button])
	return buttons


func _wire_navigation() -> void:
	var buttons := _focus_buttons()
	for i in buttons.size():
		var previous := buttons[(i + buttons.size() - 1) % buttons.size()]
		var next := buttons[(i + 1) % buttons.size()]
		buttons[i].focus_previous = buttons[i].get_path_to(previous)
		buttons[i].focus_next = buttons[i].get_path_to(next)
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(previous)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(next)
		buttons[i].focus_neighbor_left = buttons[i].get_path_to(previous)
		buttons[i].focus_neighbor_right = buttons[i].get_path_to(next)


func _update_refresh_button() -> void:
	_refresh_button.disabled = GameState.coins < REFRESH_COST
	(_refresh_button as ShopArtButton).update_visual()
	_refresh_button.tooltip_text = "金币不足，还差 %d 金币" % (REFRESH_COST - GameState.coins) if _refresh_button.disabled else "更换商品，钥匙购买上限与休整次数保留。"


func _style(bg: Color, border := Color("596880"), width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _fixed_button(key: String) -> Button:
	var node := ShopArtButton.new()
	node.art_key = key
	return node


func _button(text: String, font_size := 18) -> Button:
	var node := Button.new()
	node.text = text
	node.add_theme_font_override("font", GameFonts.get_font("button"))
	node.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tint := Color("ffe8b0") if state == "hover" else Color("b8aa82") if state == "pressed" else Color("71857e") if state == "disabled" else Color.WHITE
		node.add_theme_stylebox_override(state, _drawn_style(false, tint))
	node.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, PixelUi.GOLD, 2))
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, Color("fff0d1"))
	node.add_theme_color_override("font_disabled_color", Color("8995aa"))
	ComicMotion.bind_button(node)
	return node


func _label(text: String, font_size := 18, color := Color("e9eef8")) -> Label:
	var node := PixelUi.label(text, font_size, color)
	if font_size >= 25: node.add_theme_font_override("font", GameFonts.get_font("title"))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _place(parent: Control, node: Control, rect: Rect2) -> void:
	parent.add_child(node)
	if parent==_canvas:UiArtLayout.register("shop",node,rect)
	node.position = rect.position
	node.size = rect.size


func _plate(parent: Control, rect: Rect2, opacity := 0.94) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _drawn_style(true, Color(1, 1, 1, opacity)))
	_place(parent, panel, rect)
	return panel

func _drawn_style(_panel:bool,tint:=Color.WHITE)->StyleBoxFlat:
	var box:=InteractionSkin.style("shop")
	if tint!=Color.WHITE:box.bg_color=Color(.6,.76,.85,.12);box.border_color=Color(tint.r,tint.g,tint.b,.35)
	return box


func _art(parent: Control, path: String, rect: Rect2, cover := false) -> void:
	if not ResourceLoader.exists(path): return
	var image := TextureRect.new()
	image.texture = load(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(parent, image, rect)


func _build() -> void:
	_root = UiFactory.full_rect()
	_root.theme = PixelUi.theme()
	add_child(_root)
	_root.add_child(UiFactory.dim_layer(0.88))
	_canvas = StarUi.frame(_root, Vector2(1280,720))
	_canvas.set_meta("ui_layout_canvas",true)
	_panel = _canvas
	var sky := ShopSky.new()
	_place(_canvas, sky, Rect2(0,0,1280,720))
	_art(_canvas, BACKDROP, Rect2(0,0,1280,720), true)
	var veil := ColorRect.new()
	veil.color = Color(0.025,0.04,0.085,0.24)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_canvas, veil, Rect2(0,0,1280,720))
	_npc_portrait=TextureRect.new()
	_npc_portrait.texture=NpcArt.portrait("merchant")
	_npc_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_npc_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_npc_portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_place(_canvas,_npc_portrait,Rect2(839,22,400,548))
	_place(_canvas, _label("星灯商店", 35, PixelUi.GOLD), Rect2(45,26,180,48))
	_place(_canvas, _label("林地旅途中的一盏暖灯", 16, Color("bac9df")), Rect2(48,77,382,25))
	_place(_canvas, _label("今日货架", 23, PixelUi.GOLD), Rect2(465,66,358,32))
	# 左详情，标题和说明使用固定字号，说明可滚动完整中文。
	_plate(_canvas, Rect2(45,112,390,443))
	_detail_title = _label("", 25)
	_detail_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(_canvas, _detail_title, Rect2(66,127,348,37))
	_detail_tag = _label("", 16)
	var quality_row:=UiFactory.hbox(8)
	_detail_quality=RarityWordmark.make(0,34);quality_row.add_child(_detail_quality);quality_row.add_child(_detail_tag)
	_place(_canvas,quality_row,Rect2(66,166,348,34))
	_detail_icon = Control.new()
	_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_canvas, _detail_icon, Rect2(194,206,84,84))
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.follow_focus = true
	_place(_canvas, _detail_scroll, Rect2(66,304,348,126))
	_detail_description = _label("", 18, Color("d3dbea"))
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description.custom_minimum_size.x = 325
	_detail_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(_detail_description)
	_detail_price = _label("", 26, PixelUi.GOLD)
	_place(_canvas, _detail_price, Rect2(66,448,160,40))
	_purchase_button = _fixed_button("purchase")
	_purchase_button.set_meta("focus_token", "purchase")
	_purchase_button.pressed.connect(_purchase_selected)
	_place(_canvas, _purchase_button, Rect2(226,439,188,58))
	_reason_label = _label("", 15, Color("a8b8d2"))
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_canvas, _reason_label, Rect2(66,503,348,42))
	var shelf_scroll := ScrollContainer.new()
	shelf_scroll.name = "ShelfScroll"
	shelf_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shelf_scroll.follow_focus = true
	_place(_canvas, shelf_scroll, Rect2(460,112,369,443))
	_grid = GridContainer.new()
	_grid.columns = 1
	_grid.add_theme_constant_override("v_separation", 12)
	shelf_scroll.add_child(_grid)
	_place(_canvas, _label("姜糖", 22, PixelUi.GOLD), Rect2(890,529,288,35))
	_status_label = _label("", 18, Color("d2d9e7"))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(_canvas, _status_label, Rect2(70,577,1140,27))
	var coin := UiFactory.sheet_icon(ItemDB.ICON_COIN, 24)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_canvas, coin, Rect2(235,34,30,30))
	_coins_label = _label("金币 0", 22, PixelUi.GOLD)
	_coins_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_place(_canvas, _coins_label, Rect2(273,28,162,42))
	_rest_hint = _label("恢复最多 %d 生命" % int(REST_HEAL), 15)
	_place(_canvas, _rest_hint, Rect2(286,617,221,22))
	_place(_canvas, _label("消耗 %d 金币" % REFRESH_COST, 15), Rect2(547,617,211,22))
	_place(_canvas, _label("Esc 返回", 15), Rect2(1007,617,216,22))
	_rest_button = _fixed_button("rest")
	_rest_button.set_meta("focus_token", "rest")
	_rest_button.pressed.connect(use_rest)
	_place(_canvas, _rest_button, Rect2(274,639,245,61))
	_refresh_button = _fixed_button("refresh")
	_refresh_button.set_meta("focus_token", "refresh")
	_refresh_button.pressed.connect(refresh_offers)
	_place(_canvas, _refresh_button, Rect2(535,639,235,61))
	_close_button = _fixed_button("close")
	_close_button.set_meta("focus_token", "close")
	_close_button.pressed.connect(close)
	_place(_canvas, _close_button, Rect2(995,639,240,61))
	UiArtLayout.refresh(_canvas)
	InteractionSkin.apply_tree(_canvas,"shop")


class ShopSky extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size), Color("10192c"))
		for i in 76:
			var point := Vector2(fmod(float(i * 193 + 73),size.x),fmod(float(i * 127 + 31),size.y))
			draw_circle(point, 1.3 if i % 3 else 2.0, Color(0.65,0.73,0.87,0.36))
		for rect in [Rect2(8,8,size.x-16,size.y-16),Rect2(16,16,size.x-32,size.y-32)]:
			draw_rect(rect, Color(0.7,0.57,0.34,0.65), false, 1.0)

func expedition_snapshot() -> Dictionary:
	var sold: Array = []
	for key in _sold: sold.append(int(key))
	return {"wave":_visit_wave,"offers":_offers.duplicate(true),"sold":sold,"rest_used":_rest_used,"key_price":_key_price,"key_bought":_key_bought,"selected":_selected_index}

func expedition_restore(data: Dictionary) -> void:
	_visit_wave = int(data.get("wave",-1))
	_offers.assign(data.get("offers",[]))
	_sold.clear()
	for index in data.get("sold",[]): _sold[int(index)] = true
	_rest_used = bool(data.get("rest_used",false))
	_key_price = int(data.get("key_price",KEY_PRICE_MIN))
	_key_bought = int(data.get("key_bought",0))
	_selected_index = int(data.get("selected",-1))
