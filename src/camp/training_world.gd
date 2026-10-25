class_name TrainingWorld
extends "res://src/room_mode/room_main.gd"
## A separate sandbox map; never creates or settles a sortie.
signal return_requested
var preparation:CampPreparation
var dummy:TrainingDummy
var training_ui:CampTrainingUI
var initialization_complete:=false
var initialization_success:=false
var _meter_label:Label
var _leaving:=false

func _ready()->void:
	CampSession.begin(self,true);world_clock.minutes=720;_build_world();director.set_process(false);director.set_physics_process(false);_room_visual.set_process(false)
	var source:=FileAccess.get_file_as_string("res://assets/training/training_ground.json")
	var document:Variant=JSON.parse_string(source)
	if not document is Dictionary:initialization_complete=true;return
	var layout:=RoomTemplateCodec.to_layout(document)
	level.load_room({"id":"training","kind":"training","biome":"forest","seed":20261024,"cleared":true,"rewarded":true,"doors":[],"delta":{},"terrain_layout":layout})
	level.doors_open=false
	preview_preparation();restore_training_skills();_spawn_player();player.position=level.nearest_clear(level.room_rect.get_center()+Vector2(-120,55),12);_spawn_dummy();camera.snap_to_target()
	inventory_ui=InventoryUI.new();add_child(inventory_ui);talent_ui=inventory_ui.talent_view
	training_ui=CampTrainingUI.new();training_ui.world=self;add_child(training_ui)
	_build_training_hud();AudioManager.play_context(&"camp")
	initialization_success=true;initialization_complete=true
func _build_training_hud()->void:
	var layer_node:=CanvasLayer.new();layer_node.layer=5;add_child(layer_node)
	var root:=UiFactory.full_rect();root.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer_node.add_child(root)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);margin.add_theme_constant_override("margin_left",16);margin.add_theme_constant_override("margin_right",16);margin.add_theme_constant_override("margin_top",14);root.add_child(margin)
	var panel:=PixelUi.inset_panel(12);margin.add_child(panel);var column:=UiFactory.vbox(8);panel.add_child(column)
	var row:=UiFactory.hbox(10);column.add_child(row)
	var title:=PixelUi.label("星辉演武场 · 独立训练",23,PixelUi.GOLD);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title)
	for entry in [["设置",func()->void:training_ui.open()],["背包",func()->void:inventory_ui.open()],["返回营地",request_return]]:
		var button:=PixelUi.compact_button(entry[0],18);button.custom_minimum_size=Vector2(80,44);row.add_child(button);button.pressed.connect(entry[1])
	_meter_label=PixelUi.label("",17);_meter_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(_meter_label)
	InteractionSkin.mount(root,"training",panel)
	var safe:=MobileControls.safe_rect() if MobileControls.enabled() else get_viewport().get_visible_rect()
	margin.offset_left=safe.position.x; margin.offset_top=safe.position.y
func _spawn_dummy()->void:
	dummy=TrainingDummy.new();dummy.room=level;dummy.setup(player,level,1,1,1);dummy.fx_root=fx_root;dummy.position=level.nearest_clear(level.room_rect.get_center()+Vector2(105,-25),14);enemies_root.add_child(dummy)
func preview_preparation()->void:
	GameState._clear_equipment()
	if preparation!=null:
		for key in preparation.loadout:
			var item:=Outpost.stored_item(str(key))
			if ItemDB.is_equippable(item) and int(Outpost.data.inventory.get(str(key),0))>0:GameState.equipment[ItemDB.slot_of(item)]=item.duplicate(true)
	GameState._after_equipment_change()
func restore_training_skills()->void:
	if preparation!=null and Skills.valid_loadout(preparation.skill_loadout):GameState._assign_skill_loadout(preparation.skill_loadout);EventBus.skills_changed.emit()
func reset_training()->void:
	if not is_instance_valid(player):return
	var at:=player.position
	for field in get_tree().get_nodes_in_group("spell_fields"):
		if field.get("room")==level:field.get_parent().remove_child(field);field.queue_free()
	for parent in [actors_root,enemies_root,fx_root]:
		for child in parent.get_children():parent.remove_child(child);child.queue_free()
	GameState.temp_buffs.clear();GameState.skill_cooldowns_by_id.clear();GameState._sync_skill_cooldowns();GameState.mp=GameState.MAX_MP;GameState._reset_stats()
	_spawn_player();player.position=level.nearest_clear(at,12);player.hp=player.max_hp;_spawn_dummy();camera.snap_to_target();EventBus.skills_changed.emit();EventBus.mp_changed.emit(GameState.mp,GameState.MAX_MP)
func _process(_dt:float)->void:
	if is_instance_valid(dummy) and is_instance_valid(_meter_label):
		_meter_label.text="训练 Lv.%d   ·   近5秒DPS %.1f   ·   平均DPS %.1f   ·   累计 %.0f\nHP %.0f / %.0f   ·   MP %.0f / %.0f   ·   临时试配不影响正式出征。"%[GameState.level,dummy.meter.recent_dps(),dummy.meter.average_dps(),dummy.meter.total,player.hp,player.max_hp,GameState.mp,GameState.MAX_MP]
func _unhandled_input(event:InputEvent)->void:
	if UIFlow.has_screen() or _leaving:return
	if event.is_action_pressed("inventory"):inventory_ui.open()
	elif event.is_action_pressed("talents"):talent_ui.open()
	elif event.is_action_pressed("interact") or event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel"):training_ui.open()
	else:return
	get_viewport().set_input_as_handled()
func request_return()->void:
	if _leaving:return
	_leaving=true;return_requested.emit()
func shutdown()->void:
	_leaving=true;set_process(false);set_physics_process(false)
	for panel in [inventory_ui,training_ui]:
		if is_instance_valid(panel) and panel.is_open():panel.close()
	for field in get_tree().get_nodes_in_group("spell_fields"):
		if field.get("room")==level:field.get_parent().remove_child(field);field.queue_free()
	CampSession.end(self)
func _exit_tree()->void:CampSession.end(self)
