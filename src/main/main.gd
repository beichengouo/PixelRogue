extends Node2D
## 游戏入口：把关卡、角色、波次、界面拼起来，并负责「重开一局」。
##
## 场景树结构（全部由代码创建，方便直接读代码理解）：
##   Main
##   ├── Level          地形与背景
##   ├── Actors         玩家 / 商店 NPC
##   ├── Enemies        敌人
##   ├── FX             金币 / 飘字 / 粒子
##   ├── CameraRig      相机
##   ├── WaveDirector   波次调度
##   └── Hud / ShopUI / ItemChoiceUI / GameOverUI / PauseUI

var camp_ui: CampUI
var _reward_offers: Array = []
var _reward_wave = -1
var expedition: ExpeditionRuntime
var level: Level
var actors_root: Node2D
var enemies_root: Node2D
var fx_root: Node2D
var chests_root: Node2D
var player: Player
var npc: ShopNPC
var tavern: TavernNPC
## Shared room service UI.
var tavern_ui: TavernUI
var camera: CameraRig
var director: WaveDirector

var hud: Hud
var menu: MainMenu
var restart_gate: RestartGate
var shop_ui: ShopUI
var choice_ui: ItemChoiceUI
var inventory_ui: InventoryUI
var talent_ui: TalentUI
var dialogue: DialogueUI
## 三选一的延迟令牌：换局/重开时用来作废上一次还没弹出来的奖励
var _choice_delay_token := 0
var boss_intro: BossIntroUI
var boss_bar: BossBar
var game_over_ui: GameOverUI
var pause_ui: PauseUI
var chapter_end_ui: ChapterEndUI
var _checkpoint_wave := 0
var _flow_epoch := 0
var _last_store_effect := "return"
var _death_snapshot: Dictionary = {}
var _death_epoch := -1
var _checkpoint_epoch := -1
var _navigation_pending := false
var _resume_countdown:ResumeCountdown
var _call_goddess_axis_armed := true

const AUTOPLAY_FLAG := "--autoplay"
## 轻量入口先显示菜单，再在线程中载入本场景；F6 单独运行仍显示菜单。
var show_menu_on_ready := true


func _ready() -> void:
	randomize()
	get_tree().root.theme = UiFactory.make_theme()
	_build_world()
	_build_ui()
	_connect_events()
	if _autoplay_requested():
		_begin_run({})
	else:
		# 正式开局：先显示主菜单，等玩家点「开始游戏」再进关卡
		restart_gate.enabled = false
		if show_menu_on_ready:
			menu.open()
func _autoplay_requested() -> bool:
	return _has_flag(AUTOPLAY_FLAG)


func _has_flag(flag: String) -> bool:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return args.has(flag)


func _build_world() -> void:
	push_error("Room flow must implement _build_world")

func _build_ui() -> void:
	chapter_end_ui = ChapterEndUI.new()
	add_child(chapter_end_ui)
	chapter_end_ui.menu_requested.connect(_safe_exit)
	chapter_end_ui.restart_requested.connect(_continue_endless)
	chapter_end_ui.next_requested.connect(_on_next_chapter)
	hud = Hud.new()
	hud.name = "Hud"
	hud.director = director
	add_child(hud)
	UIFlow.bind_hud(hud)

	shop_ui = ShopUI.new()
	shop_ui.name = "ShopUI"
	add_child(shop_ui)

	choice_ui = ItemChoiceUI.new()
	choice_ui.name = "ItemChoiceUI"
	# 三选一打开时藏起 HUD：否则波次横幅会压到"选择一件奖励"标题上
	add_child(choice_ui)

	inventory_ui = InventoryUI.new()
	inventory_ui.name = "InventoryUI"
	# 背包 / 天赋树打开时也藏 HUD：这两页左边留着立绘和属性列，
	# 底下的血条、技能格、药水格会透出来和它们挤在一起（画面自查时被点出来了）
	add_child(inventory_ui)

	talent_ui = TalentUI.new()
	talent_ui.name = "TalentUI"
	add_child(talent_ui)

	dialogue = DialogueUI.new()
	dialogue.name = "DialogueUI"
	# 演剧情时把战斗 HUD（血条/技能栏/小地图）藏起来，画面上只留立绘和台词
	add_child(dialogue)

	boss_intro = BossIntroUI.new()
	add_child(boss_intro)
	boss_bar = BossBar.new()
	boss_bar.name = "BossBar"
	add_child(boss_bar)
	UIFlow.bind_hud(boss_bar)

	tavern_ui = TavernUI.new()
	tavern_ui.name = "TavernUI"
	tavern_ui.hire_requested.connect(_on_hire_requested)
	add_child(tavern_ui)

	game_over_ui = GameOverUI.new()
	game_over_ui.name = "GameOverUI"
	add_child(game_over_ui)

	pause_ui = PauseUI.new()
	pause_ui.name = "PauseUI"
	add_child(pause_ui)

	menu = MainMenu.new()
	menu.name = "MainMenu"
	menu.start_requested.connect(start_new_run)
	menu.story_replay_requested.connect(dialogue.play_replay)
	menu.continue_requested.connect(continue_run)
	menu.quit_requested.connect(func() -> void: SaveService.quit_game())
	add_child(menu)
	camp_ui = CampUI.new()
	camp_ui.world_mode=true
	add_child(camp_ui)
	camp_ui.departure_requested.connect(_transition_run)
	camp_ui.resume_requested.connect(_transition_run)
	camp_ui.back_requested.connect(menu.open)

	restart_gate = RestartGate.new()
	restart_gate.name = "RestartGate"
	restart_gate.restart_confirmed.connect(start_new_run)
	add_child(restart_gate)


func _connect_events() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.story_checkpoint.connect(_on_story_checkpoint)
	EventBus.player_died.connect(_on_player_died)
	EventBus.shop_opened.connect(_on_shop_opened)
	EventBus.chest_spawned.connect(_on_chest_spawned)
	EventBus.tavern_opened.connect(func(offers: Array) -> void:
		_last_store_effect = "tavern"
		if is_instance_valid(tavern_ui):
			tavern_ui.open(offers)
	)

	choice_ui.item_chosen.connect(_on_item_chosen)
	game_over_ui.restart_requested.connect(start_new_run)
	game_over_ui.menu_requested.connect(_on_return_to_menu)
	pause_ui.restart_requested.connect(start_new_run)
	pause_ui.settings_requested.connect(func() -> void: menu.open_settings())
	pause_ui.save_requested.connect(_on_manual_save)
	pause_ui.menu_requested.connect(_on_return_to_menu)
	pause_ui.leave_chapter_requested.connect(leave_cleared_chapter)


func _on_manual_save() -> void:
	## 手动存档：和波间自动存档用同一个存档位
	var saved = SaveService.save_run(GameState.snapshot())
	pause_ui.set_status("已保存：第 %d 波 · %d 金币" % [GameState.wave, GameState.coins] if saved else "保存失败，请重试")
	AudioManager.play(&"ui_click", -6.0)


func open_talents() -> void:
	## 背包「天赋」页的按钮走这里：统一入口，避免和背包抢输入
	if is_instance_valid(inventory_ui) and inventory_ui.is_open():
		inventory_ui.close()
	if is_instance_valid(talent_ui):
		talent_ui.open()


func _on_return_to_menu() -> void:
	if _extraction_blocks_input(): return
	if TransitionLayer.busy: return
	if _navigation_pending: return
	_navigation_pending = true
	var ticket := _flow_epoch
	if not await TransitionLayer.cover("旅途暂歇", _last_store_effect, self):
		_navigation_pending = false
		return
	if ticket != _flow_epoch:
		TransitionLayer.cancel()
		_navigation_pending = false
		return
	_return_to_menu_now()
	await TransitionLayer.uncover()
	_navigation_pending = false

func _return_to_menu_now() -> bool:
	if GameState.run_active and is_instance_valid(player):
		if not SaveService.save_run(GameState.snapshot()):
			pause_ui.open()
			pause_ui.set_status("保存失败，请重试；本局继续保留。")
			return false
	_flow_epoch += 1
	_choice_delay_token += 1
	_close_run_screens()
	_clear_run_entities()
	director.phase = WaveDirector.Phase.IDLE
	GameState.run_active = false
	restart_gate.enabled = false
	menu.open()
	return true


func start_new_run() -> void:
	if _extraction_blocks_input(): return
	if TransitionLayer.busy:return
	if GameState.run_active and is_instance_valid(player):
		if not SaveService.save_run(GameState.snapshot()):
			pause_ui.open()
			pause_ui.set_status("保存失败，请重试；本局继续保留。")
			return
	_flow_epoch+=1
	_close_run_screens()
	_clear_run_entities()
	director.phase=WaveDirector.Phase.IDLE
	GameState.run_active=false
	restart_gate.enabled=false
	menu.close()
	get_tree().root.set_meta("pending_camp",{"reason":"suspended" if SaveService.has_run() else "new","character":str(Characters.current_id())})
	get_tree().call_deferred("change_scene_to_file","res://src/main/game_shell.tscn")

func continue_run(snapshot_data: Dictionary) -> void:
	## 恢复同一趟出征的战斗、物资与撤离快照。
	_transition_run(snapshot_data)


func _transition_run(snapshot_data: Dictionary) -> void:
	if _extraction_blocks_input() or TransitionLayer.busy:return
	GameState.run_active=false
	get_tree().root.set_meta("pending_departure",snapshot_data)
	get_tree().call_deferred("change_scene_to_file","res://src/main/game_shell.tscn")

func prepare_resume_countdown(snapshot_data:Dictionary)->ResumeCountdown:
	var continuing=not snapshot_data.is_empty() and not (snapshot_data.has("departure") and not snapshot_data.has("expedition_items"))
	if continuing and GameState.run_active and not camp_ui.is_open():
		_resume_countdown=ResumeCountdown.new();add_child(_resume_countdown);_resume_countdown.open()
		return _resume_countdown
	return null

func _close_run_screens() -> void:
	if is_instance_valid(_resume_countdown):
		_resume_countdown.cancel();_resume_countdown.queue_free();_resume_countdown=null
	if dialogue.finished.is_connected(_on_checkpoint_finished): dialogue.finished.disconnect(_on_checkpoint_finished)
	if dialogue.finished.is_connected(_on_death_story_finished): dialogue.finished.disconnect(_on_death_story_finished)
	if expedition != null and is_instance_valid(expedition): expedition.motion.cancel()
	if camp_ui != null and camp_ui.is_open(): camp_ui.close()
	if boss_intro != null: boss_intro.cancel()
	choice_ui.cancel()
	inventory_ui._finish_close()
	for screen in [shop_ui, pause_ui, talent_ui, tavern_ui, chapter_end_ui]:
		if screen.is_open(): screen.close(true)
	game_over_ui.hide_ui()
	dialogue.cancel()

func _begin_run(snapshot_data: Dictionary) -> void:
	push_error("Room flow must implement _begin_run")

func _clear_run_entities() -> void:
	if expedition != null and is_instance_valid(expedition):
		expedition.motion.cancel()
		remove_child(expedition)
		expedition.queue_free()
		expedition = null
	GameState.runtime_node = null
	director.extraction_hold = false
	if level != null: level.stop_environment()
	_choice_delay_token += 1
	for container: Node2D in [actors_root, enemies_root, fx_root, chests_root]:
		if container == null:
			continue
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	player = null
	npc = null
	tavern = null
	GameState.player = null


func _spawn_player() -> void:
	push_error("Room flow must implement _spawn_player")

func _spawn_npc() -> void:
	push_error("Room flow must implement _spawn_npc")

func _spawn_hired_allies() -> void:
	for entry in GameState.hired:
		_spawn_ally(entry)


func _spawn_ally(entry: Dictionary) -> void:
	push_error("Room flow must implement _spawn_ally")

func _on_hire_requested(offer: Dictionary) -> void:
	## 酒馆雇佣：记进本局名单 + 立刻放到玩家身边
	var entry := offer.duplicate(true)
	entry["uid"] = "%d_%d" % [Time.get_ticks_msec(), GameState.hired.size()]
	entry["hp"] = 0.0
	GameState.add_hired(entry)
	_spawn_ally(entry)
	AudioManager.play(&"wave_clear", -8.0)


func _on_enemy_died(_kind: StringName, _where: Vector2, _coins: int) -> void:
	pass

func _on_chest_spawned() -> void:
	hud.show_banner("附近出现了一个补给箱！", 2.0, Palette.UI_ACCENT)
	hud.set_hint("补给箱要用钥匙打开　·　钥匙只能在商店购买")


func _on_wave_cleared(_progress:int)->void:
	push_error("Room flow must implement reward sequencing")

func _on_item_chosen(item: Dictionary) -> void:
	if not GameState.run_active:return
	if item.get("hire_token",false):
		var hire: Dictionary = item.get("hire_entry",{})
		if hire.is_empty(): hire = HireOffers.random_hire(Rng.stream())
		if not hire.is_empty():
			hire["uid"] = "%d_hire" % Time.get_ticks_usec()
			GameState.add_hired(hire)
			_spawn_ally(hire)
	elif not GameState.add_item(item):
		expedition.loot.drop([item],player.global_position+Vector2(0,-28))
		hud.show_banner("行囊已满，奖励留在脚边",2)
	_reward_offers.clear()
	_reward_wave=-1
	director.start_rest()
	expedition.checkpoint()

func _on_story_checkpoint(_progress:int)->void:
	pass

func _on_checkpoint_finished()->void:
	_checkpoint_wave=0

func _present_chapter_result(snapshot_data: Dictionary) -> void:
	var ticket := _flow_epoch
	var concealed := await TransitionLayer.cover("苏醒林地 · 旅途刻印", "boss", self)
	if ticket != _flow_epoch:
		if concealed: TransitionLayer.cancel()
		return
	chapter_end_ui.open(snapshot_data)
	if concealed: await TransitionLayer.uncover()

func leave_cleared_chapter()->void:
	if GameState.chapter_cleared and is_instance_valid(expedition):expedition.extraction.request()

func _on_next_chapter(id: StringName) -> void:
	if not ChapterCatalog.is_ready(id):
		return
	var path := str(ChapterCatalog.CHAPTERS[id].scene)
	chapter_end_ui.close()
	get_tree().change_scene_to_file(path)


func _on_shop_opened(offers: Array) -> void:
	_last_store_effect = "merchant"
	if GameState.run_active and UIFlow.can_open(shop_ui): shop_ui.open(offers)


func _try_harvest_mushroom() -> bool:
	## 遍历场上的蘑菇，谁在采集范围内就采掉谁（蘑菇自己判断距离）
	for node in get_tree().get_nodes_in_group("mushrooms"):
		var mushroom := node as GlowMushroom
		if mushroom == null or not is_instance_valid(mushroom):
			continue
		if mushroom.try_interact():
			if is_instance_valid(player): player.play_action_feedback(&"interact")
			return true
	return false


func _on_player_died() -> void:
	_navigation_pending = false
	_flow_epoch += 1
	_death_epoch = _flow_epoch
	_death_snapshot = GameState.snapshot().duplicate(true)
	if TransitionLayer.busy: TransitionLayer.cancel()
	_choice_delay_token += 1
	_close_run_screens()
	for group in ["pixel_spell_fx", "spell_fields"]:
		for effect in get_tree().get_nodes_in_group(group):
			effect.queue_free()
	GameState.end_run()
	director.on_player_died()
	# 第一次死亡：先走《第一次死亡》的剧情（回廊 + 选身份），演完再弹结算界面
	if is_instance_valid(dialogue) and not StoryState.completed(Story.DEATH_FIRST):
		StoryState.register_death()
		dialogue.finished.connect(_on_death_story_finished, CONNECT_ONE_SHOT)
		dialogue.play_scene(Story.DEATH_FIRST)
		return
	StoryState.register_death()
	# 之后每次死亡：只留一句伊莉丝的短句，再弹结算（不再重演整段回廊）
	if is_instance_valid(dialogue) and not _autoplay_requested():
		dialogue.finished.connect(_on_death_story_finished, CONNECT_ONE_SHOT)
		dialogue.play_lines(
			Story.random_death_line(StoryState.story_line, StoryState.affinity),
			Story.P_GODDESS, &"death_repeat"
		)
		return
	game_over_ui.show_result(GameState.wave, GameState.coins, _death_snapshot)


func _on_death_story_finished() -> void:
	if _death_epoch != _flow_epoch or GameState.run_active: return
	game_over_ui.show_result(int(_death_snapshot.get("wave", 1)), int(_death_snapshot.get("coins", 0)), _death_snapshot)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y and event.axis_value > -0.45:
		_call_goddess_axis_armed = true
	if _extraction_blocks_input():
		get_viewport().set_input_as_handled()
		return
	if TransitionLayer.busy or UIFlow.has_screen(): return
	if is_instance_valid(camp_ui) and camp_ui.is_open(): return
	if is_instance_valid(dialogue) and dialogue.is_open():
		return
	if game_over_ui.is_open():
		return
	if event.is_action_pressed("call_goddess") and not event.is_echo():
		if event is InputEventJoypadMotion:
			if not _call_goddess_axis_armed: return
			_call_goddess_axis_armed = false
		if is_instance_valid(expedition): expedition.extraction.request()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		if shop_ui.is_open() or choice_ui.is_open():
			return
		if inventory_ui.is_open():
			inventory_ui.close()
		else:
			inventory_ui.open()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("talents"):
		if shop_ui.is_open() or choice_ui.is_open():
			return
		if talent_ui.is_open():
			talent_ui.close()
		else:
			talent_ui.open()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause_menu"):
		if shop_ui.is_open():
			shop_ui.close()
		elif inventory_ui.is_open():
			inventory_ui.close()
		elif talent_ui.is_open():
			talent_ui.close()
		elif pause_ui.is_open():
			pause_ui.close()
		else:
			pause_ui.open()
		return
	if get_tree().paused:
		return
	if event.is_action_pressed("interact"):
		if is_instance_valid(expedition) and expedition.interact():
			get_viewport().set_input_as_handled()
			return
		# 采集发光蘑菇的优先级最高：它就长在脚下，别被旁边的商人抢走这次 E
		if _try_harvest_mushroom():
			return
		if _try_interact_chest():
			return
		var storefront := StorefrontInteraction.closest(get_tree(), player)
		if storefront != null:
			player.play_action_feedback(&"interact")
			storefront.try_interact()

	elif event.is_action_pressed("start_wave"):
		director.skip_rest()


func _try_interact_chest() -> bool:
	## 优先处理「玩家站在旁边、而且已经落地」的补给箱
	for node in get_tree().get_nodes_in_group("chests"):
		var chest := node as Chest
		if chest == null or not is_instance_valid(chest):
			continue
		if chest.in_range and not chest.is_open:
			if is_instance_valid(player): player.play_action_feedback(&"interact")
			chest.try_interact()
			return true
	return false

func _extracted_to_camp() -> void:
	_flow_epoch+=1
	_close_run_screens()
	_clear_run_entities()
	director.phase=WaveDirector.Phase.IDLE
	restart_gate.enabled=false
	menu.close()
	get_tree().root.set_meta("pending_camp",{"reason":"settled","character":str(Characters.current_id())})
	get_tree().call_deferred("change_scene_to_file","res://src/main/game_shell.tscn")

func _extraction_blocks_input() -> bool:
	return is_instance_valid(expedition) and expedition.extraction.blocks_input()

func _settle_extraction(runtime: ExpeditionRuntime, ticket: int) -> void:
	if _navigation_pending or not runtime.extraction.can_complete(ticket): return
	_navigation_pending = true
	var flow_ticket := _flow_epoch
	var cover_ticket := TransitionLayer._epoch + 1
	runtime._completion_cover_epoch = cover_ticket
	if not await TransitionLayer.cover("女神接引 · 满载而归", "goddess", self):
		if flow_ticket == _flow_epoch:
			_navigation_pending = false
			if is_instance_valid(runtime) and runtime.extraction.can_complete(ticket): runtime.extraction.retry_completion()
		return
	if flow_ticket != _flow_epoch or not is_instance_valid(runtime) or not runtime.extraction.can_complete(ticket):
		if TransitionLayer._epoch == cover_ticket: TransitionLayer.cancel()
		if flow_ticket == _flow_epoch: _navigation_pending = false
		return
	var completed_city:=GameState.chapter_id==ChapterCatalog.NEXT and GameState.chapter_cleared
	var result := Outpost.settle_sortie("extracted")
	if result.is_empty():
		runtime.extraction.retry_completion()
		await TransitionLayer.uncover()
		if flow_ticket == _flow_epoch: _navigation_pending = false
		return
	if completed_city:StoryState.set_flag(StringName("city_return_pending_"+str(Characters.current_id())),true)
	GameState.run_active = false
	runtime.motion.cancel()
	_extracted_to_camp()
	var arrival_ticket := _flow_epoch
	await TransitionLayer.uncover()
	if arrival_ticket == _flow_epoch: _navigation_pending = false

func _safe_exit() -> void:
	if GameState.chapter_cleared and is_instance_valid(expedition):
		chapter_end_ui.close()
		# Wait until the blocking result page releases its pause lease before prayer.
		var ticket := _flow_epoch
		while ticket == _flow_epoch and chapter_end_ui.is_open(): await get_tree().process_frame
		if ticket == _flow_epoch and is_instance_valid(expedition): expedition.extraction.request()
	else:_on_return_to_menu()

func _continue_endless() -> void:
	if not GameState.chapter_cleared:return
	chapter_end_ui.close()
	GameState.endless_mode=true
	director.phase=WaveDirector.Phase.CLEARED
	expedition.checkpoint()

func _restore_expedition_flow(_raw:Dictionary)->void:
	push_error("Room flow must implement restore sequencing")
