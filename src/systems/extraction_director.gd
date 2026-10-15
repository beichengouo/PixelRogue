class_name ExtractionDirector
extends Node
## Shared safe-room prayer/reception presentation and snapshot compatibility.
## No floor/gravity checks or hostile extraction spawning; RoomExtraction enforces clear-room access.
signal completed
const IDLE := "idle"
const PRAYING := "praying"
const WAITING := "waiting"
const RECEIVING := "receiving"
const SETTLING := "settling"
const PRAYER_SECONDS := 3.0
const WAIT_SECONDS := 30.0
const RECEPTION_SECONDS := 2.0
var main
var state := IDLE
var remaining := 0.0
var channel := 0.0
var cooldown := 0.0
var chase_stage := 0
var stable := false
var anchor := Vector2.ZERO
var reception_elapsed := 0.0
var waiting_elapsed := 0.0
var wait_duration:=WAIT_SECONDS
var wait_profile:="combat"
var _epoch := 0
var _sortie_id := ""
var _flow_epoch := -1
var _label: Label
var _overlay: CanvasLayer
var _fx: GoddessExtractionFX

func _ready() -> void:
	_sortie_id = GameState.sortie_id
	_flow_epoch = main._flow_epoch
	_overlay = CanvasLayer.new()
	_overlay.layer = 11
	add_child(_overlay)
	_label = PixelUi.label("", 16, PixelUi.GOLD)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_outline_color", Color("101b26"))
	_label.add_theme_constant_override("outline_size", 4)
	_overlay.add_child(_label)
	_fx = GoddessExtractionFX.new()
	_fx.name = "GoddessExtractionFX"
	add_child(_fx)
	main.player.extraction_interrupted.connect(_interrupt_prayer)
	EventBus.player_damaged.connect(_on_damaged)
	EventBus.player_died.connect(_on_death)
	UIFlow.stack_changed.connect(_sync_overlay)
	_render()

func _sync_overlay() -> void:
	if is_instance_valid(_overlay): _overlay.visible = not UIFlow.has_screen()

func is_current() -> bool:
	return is_inside_tree() and is_instance_valid(main) and main.expedition == get_parent() and GameState.run_active and GameState.sortie_id == _sortie_id and main._flow_epoch == _flow_epoch and is_instance_valid(main.player) and main.player.hp > 0

func blocks_input() -> bool:
	return state in [RECEIVING, SETTLING]

func completion_ticket() -> int:
	return _epoch

func can_complete(ticket: int) -> bool:
	return ticket == _epoch and is_current() and state == SETTLING

func request() -> bool:
	if not is_current() or UIFlow.has_screen() or get_tree().paused or TransitionLayer.busy: return false
	if blocks_input(): return false
	if state in [PRAYING, WAITING]:
		cancel(state == WAITING)
		return true
	if cooldown > 0:
		main.hud.show_banner("女神呼唤重连中 · %d秒" % ceili(cooldown), 1.2)
		return false
	if main.player._dash_timer > 0 or main.player.velocity.length() > 20:
		main.hud.show_banner("站稳后按 %s，合掌呼唤女神" % UIFlow.hint(&"call_goddess"), 1.5)
		return false
	_epoch += 1
	state = PRAYING
	channel = 0
	remaining = PRAYER_SECONDS
	anchor = main.player.global_position + Vector2(0, 21)
	main.player.set_extraction_pose(&"prayer")
	main.director.extraction_hold = true
	_render()
	Outpost.request_checkpoint()
	return true

func _interrupt_prayer() -> void:
	if state == PRAYING: cancel(false)

func _on_damaged(_amount: float, _hp: float, _max_hp: float) -> void:
	_interrupt_prayer()

func _on_death() -> void:
	cancel(false, false)

func _process(delta: float) -> void:
	if not is_current():
		if state != IDLE: cancel(false, false)
		_label.text = ""
		return
	if get_tree().paused: return
	cooldown = maxf(0, cooldown - delta)
	if state == PRAYING:
		if main.player.global_position.distance_to(anchor - Vector2(0, 21)) > 5:
			cancel(false)
		else:
			channel = minf(PRAYER_SECONDS, channel + delta)
			remaining = PRAYER_SECONDS - channel
			if remaining <= 0:
				state = WAITING
				remaining = WAIT_SECONDS
				waiting_elapsed = 0
				chase_stage = 0
				main.player.set_extraction_pose(&"")
				Outpost.request_checkpoint()
	elif state == WAITING:
		remaining = maxf(0, remaining - delta)
		waiting_elapsed += delta
		if remaining <= 0:
			state = RECEIVING
			reception_elapsed = 0
			main.player.set_extraction_pose(&"receiving")
			main._choice_delay_token += 1
			Outpost.request_checkpoint()
	elif state == RECEIVING:
		reception_elapsed = minf(RECEPTION_SECONDS, reception_elapsed + delta)
		if reception_elapsed >= RECEPTION_SECONDS:
			state = SETTLING
			main.player.set_extraction_pose(&"settling", true)
			completed.emit()
	_render()

func _render() -> void:
	if _label == null: return
	var view := get_viewport().get_visible_rect().size
	_label.position = Vector2(view.x * 0.5 - minf(300, view.x * 0.35), 236)
	_label.size = Vector2(minf(600, view.x * 0.7), 48)
	_label.visible = not UIFlow.has_screen()
	var key := UIFlow.hint(&"call_goddess")
	match state:
		PRAYING: _label.text = "合掌祈祷  %.1f / 3秒\n移动或受击打断 · %s 取消" % [channel, key]
		WAITING: _label.text = "星辉回应  %d秒\n可移动与战斗 · %s 取消呼唤" % [ceili(remaining), key]
		RECEIVING: _label.text = "女神接引 · 握住她的手"
		SETTLING: _label.text = "星辉归途"
		_: _label.text = "呼唤重连 %d秒" % ceili(cooldown) if cooldown > 0 else "%s  合掌呼唤女神" % key
	if is_instance_valid(main.player): _fx.present(state, channel, waiting_elapsed, reception_elapsed, anchor, main.player)

func cancel(with_cooldown := true, checkpoint := true) -> void:
	_epoch += 1
	state = IDLE
	remaining = 0
	channel = 0
	waiting_elapsed = 0
	reception_elapsed = 0
	if with_cooldown: cooldown = 60
	if is_instance_valid(main) and is_instance_valid(main.director): main.director.extraction_hold = false
	if is_instance_valid(main) and is_instance_valid(main.player): main.player.set_extraction_pose(&"")
	if is_instance_valid(_fx): _fx.clear()
	if checkpoint and is_current(): Outpost.request_checkpoint()
	if is_inside_tree(): _render()

func retry_completion() -> void:
	# Failed saving or acquiring the cover gives control back before another prayer.
	cancel(false, false)
	Outpost.request_checkpoint()
	main.hud.show_banner("撤离未完成，收获仍在本局 · 按 %s 重试" % UIFlow.hint(&"call_goddess"), 3)

func open_stable() -> void:
	stable = true

func snapshot() -> Dictionary:
	return {"version":3,"state":state,"remaining":remaining,"channel":channel,"cooldown":cooldown,"chase":chase_stage,"stable":stable,"anchor":[anchor.x,anchor.y],"waiting_elapsed":waiting_elapsed,"reception_elapsed":reception_elapsed,"wait_duration":wait_duration,"wait_profile":wait_profile}

func restore(data: Dictionary) -> void:
	cancel(false, false)
	stable = bool(data.get("stable", false))
	wait_duration=5.0 if float(data.get("wait_duration",WAIT_SECONDS))==5.0 else WAIT_SECONDS
	wait_profile="safe" if wait_duration==5.0 else "combat"
	cooldown = clampf(float(data.get("cooldown", 0)), 0, 60)
	var saved_state := str(data.get("state", IDLE))
	anchor = main.player.global_position + Vector2(0, 21)
	if int(data.get("version", 0)) < 2:
		if saved_state == "waiting":
			state = WAITING
			remaining = clampf(float(data.get("remaining", WAIT_SECONDS)), 0, WAIT_SECONDS)
			waiting_elapsed = WAIT_SECONDS - remaining
		elif saved_state in ["ready", "settling"]:
			state = WAITING
			remaining = 0
			waiting_elapsed = WAIT_SECONDS
	else:
		state = saved_state if saved_state in [IDLE, PRAYING, WAITING, RECEIVING, SETTLING] else IDLE
		var at: Array = data.get("anchor", [anchor.x, anchor.y])
		if at.size() == 2: anchor = Vector2(float(at[0]), float(at[1]))
		channel = clampf(float(data.get("channel", 0)), 0, PRAYER_SECONDS)
		remaining = clampf(float(data.get("remaining", 0)), 0, WAIT_SECONDS)
		waiting_elapsed = maxf(0, float(data.get("waiting_elapsed", 0)))
		reception_elapsed = clampf(float(data.get("reception_elapsed", 0)), 0, RECEPTION_SECONDS)
		# Pending terminal callbacks are not saved. Resume the last phase and submit once.
		if state == SETTLING: state = RECEIVING; reception_elapsed = RECEPTION_SECONDS - 0.05
	chase_stage = clampi(int(data.get("chase", 0)), 0, 3)
	main.director.extraction_hold = state in [RECEIVING,SETTLING]
	if state in [RECEIVING,SETTLING] and self is RoomExtraction:
		var saved_reception:=reception_elapsed
		(self as RoomExtraction).begin_reception();reception_elapsed=saved_reception
	if state == PRAYING: main.player.set_extraction_pose(&"prayer")
	elif state == RECEIVING: main.player.set_extraction_pose(&"receiving", reception_elapsed >= 0.55)
	else: main.player.set_extraction_pose(&"")
	_render()

func _exit_tree() -> void:
	cancel(false, false)
	if EventBus.player_damaged.is_connected(_on_damaged): EventBus.player_damaged.disconnect(_on_damaged)
	if EventBus.player_died.is_connected(_on_death): EventBus.player_died.disconnect(_on_death)
	if UIFlow.stack_changed.is_connected(_sync_overlay): UIFlow.stack_changed.disconnect(_sync_overlay)
	if is_instance_valid(main) and is_instance_valid(main.player) and main.player.extraction_interrupted.is_connected(_interrupt_prayer): main.player.extraction_interrupted.disconnect(_interrupt_prayer)
