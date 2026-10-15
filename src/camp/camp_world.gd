class_name CampWorld
extends "res://src/room_mode/room_main.gd"
signal departure_requested(payload:Dictionary)
signal resume_requested(snapshot:Dictionary)
signal back_requested
signal facility_opened(role:String)
signal facility_closed(role:String)
const TEMPLATE_ID:="camp_starlight_corridor"
const FACILITY_NAMES:={"shop":"星灯商铺","warehouse":"回廊仓库","contracts":"冒险者工会","prepare":"出发准备台","relations":"星灯酒馆","iris":"女神灯坛","result":"旅途记事台","training":"训练场"}
var preparation:=CampPreparation.new()
var dummy:TrainingDummy
var facilities:Dictionary={}
var camp_hud:CampHud
var training_ui:CampTrainingUI
var _pause:CanvasLayer
var _pause_root:Control
var _draft_signature:=""
var _departing:=false
var _camp_enter_clock:=0.0
var _gate_sprites:Dictionary={}
var document_override:Dictionary={}
var editor_validation:=false
var entry_reason:="new"
var loading_transition_epoch:=-1
var initialization_complete:=false
var initialization_success:=false
var tutorial:CampTutorial
var residents_root:Node2D
var resident_panel:CampResidentPanel
var _opened_facility:=""
func _ready()->void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	CampSession.begin(self);_build_world();world_clock.minutes=RoomEnvironmentConfig.DUSK_START+42;director.set_process(false);director.set_physics_process(false);_room_visual.set_process(false)
	var pool:=RoomTemplatePool.new();var document:Dictionary=document_override.duplicate(true)
	if document.is_empty():
		if loading_transition_epoch>=0:
			if not await pool.ensure_loaded_async(get_tree(),_camp_loading_valid):
				CampSession.end(self);initialization_complete=true;return
		else:pool.reload()
		for template in pool.templates:
			if str(template.id)==TEMPLATE_ID:document=template.duplicate(true);break
	if document.is_empty():push_error("营地模板缺失");CampSession.end(self);initialization_complete=true;return
	var layout:=RoomTemplateCodec.to_layout(document)
	var record:Dictionary={"id":"0,0","kind":"camp","biome":"forest","seed":20261012,"cleared":true,"rewarded":true,"delta":{},"doors":["0,-1","1,0","0,1","-1,0"],"terrain_layout":layout}
	if loading_transition_epoch>=0:
		if not await level.load_room_async(record,self,loading_transition_epoch):
			CampSession.end(self);initialization_complete=true;return
	else:level.load_room(record)
	if loading_transition_epoch>=0 and not await CombatArtWarmup.prepare(get_tree(),"",_camp_loading_valid):
		CampSession.end(self);initialization_complete=true;return
	level.doors_open=false;level.door_phase=0
	if str(layout.get("scene_art",""))=="camp_starlight_corridor_v02":camera.view_reference_size=level.illustration.camera_bounds().size*.5
	for marker in layout.markers:
		var role:=str(marker.asset_id).trim_prefix("camp:")
		if role in FACILITY_NAMES:facilities[role]=RoomLayout.center(Vector2i(int(marker.at[0]),int(marker.at[1])))
	_spawn_player();player.position=marker_position("player",level.room_rect.get_center());camera.snap_to_target()
	_spawn_dummy();_build_camp_ui();_build_gate_animations()
	_spawn_residents()
	tutorial=CampTutorial.new();tutorial.world=self;add_child(tutorial)
	Outpost.changed.connect(_on_camp_inventory_changed)
	AudioManager.play_context(&"camp")
	if entry_reason=="settled":camp_ui.open_facility("result")
	initialization_success=true;initialization_complete=true
	var return_key:=StringName("city_return_pending_"+str(Characters.current_id()))
	if not editor_validation and bool(StoryState.get_flag(return_key,false)):
		if camp_ui.is_open():camp_ui.close()
		dialogue.play_scene(&"city_return")
		await dialogue.finished
		if StoryState.completed(&"city_return"):StoryState.set_flag(return_key,false)
func _camp_loading_valid()->bool:
	return is_inside_tree() and TransitionLayer.busy and TransitionLayer._epoch==loading_transition_epoch
func marker_position(role:String,fallback:Vector2)->Vector2:
	for marker in level.record.get("terrain_layout",{}).get("markers",[]):
		if str(marker.asset_id)=="camp:"+role:return RoomLayout.center(Vector2i(int(marker.at[0]),int(marker.at[1])))
	return fallback
func facility_guide_center(role:String)->Vector2:
	# scene_polygons contains the live world-space physics footprints after
	# template/editor overrides. Sprite origin, roof and alpha margins do not
	# describe the physical building center.
	var polygon:PackedVector2Array=level.scene_polygons.get(role,PackedVector2Array())
	if polygon.size()>=3:return RoomSceneGeometry.centroid(polygon)
	return facilities.get(role,level.room_rect.get_center())
func _build_camp_ui()->void:
	camp_ui=CampUI.new();camp_ui.world_mode=true;add_child(camp_ui)
	camp_ui.closed.connect(func()->void:
		if not _opened_facility.is_empty():facility_closed.emit(_opened_facility);_opened_facility="")
	camp_ui.departure_requested.connect(_confirm_preparation)
	camp_ui.resume_requested.connect(func(snapshot:Dictionary)->void:_leave_camp();resume_requested.emit(snapshot))
	inventory_ui=InventoryUI.new();add_child(inventory_ui);talent_ui=TalentUI.new();add_child(talent_ui)
	training_ui=CampTrainingUI.new();training_ui.world=self;add_child(training_ui)
	dialogue=DialogueUI.new();add_child(dialogue)
	resident_panel=CampResidentPanel.new();resident_panel.world=self;add_child(resident_panel)
	camp_hud=CampHud.new();camp_hud.world=self;add_child(camp_hud)
	menu=MainMenu.new();add_child(menu)
	_pause=CanvasLayer.new();_pause.layer=32;_pause.process_mode=Node.PROCESS_MODE_ALWAYS;_pause.set_meta("blocking_screen",true);add_child(_pause)
	_pause_root=UiFactory.full_rect();_pause.add_child(_pause_root);_pause_root.add_child(UiFactory.dim_layer(.45));var frame:=StarUi.frame(_pause_root,Vector2(480,350));var column:=UiFactory.vbox(14);column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);frame.add_child(column)
	column.add_child(PixelUi.title("星辉回廊",28))
	for option in [["继续营地",_close_pause],["设置",func()->void:_close_pause();menu.open_settings()],["返回主菜单",func()->void:_close_pause();_leave_camp();back_requested.emit()]]:
		var button:=PixelUi.button(str(option[0]),20);button.pressed.connect(option[1]);column.add_child(button)
	_pause_root.hide();_copy_trial_inventory();_draft_signature=preparation.signature()
	InteractionSkin.mount(_pause_root,"camp_pause",frame)

func _close_pause()->void:_pause_root.hide();UIFlow.pop_screen(_pause)
func _copy_trial_inventory()->void:
	GameState.items.clear()
	for id in Outpost.data.inventory:
		var item:=ExpeditionData.resolve(str(id));var count:=int(Outpost.data.inventory[id])
		if count<=0 or not (ItemDB.is_equippable(item) or ItemDB.is_usable(item)) or not ItemDB.can_equip(item):continue
		for index in mini(count,15):GameState.items.append(item.duplicate(true))
	for slot:StringName in ItemDB.SLOTS:
		var item:Dictionary=GameState.equipment.get(slot,{})
		if not item.is_empty() and int(Outpost.data.inventory.get(str(item.id),0))<=0:GameState.equipment[slot]={}
	GameState.potion_hotbar=[{},{},{}];GameState._reset_stats();EventBus.hotbar_changed.emit();EventBus.player_stats_changed.emit()
func _on_camp_inventory_changed()->void:
	_copy_trial_inventory();_sync_preparation();preparation.ready()
func _sync_preparation()->void:
	preparation.chapter_id=camp_ui.chapter_id;preparation.loadout=camp_ui.cart.duplicate();preparation.carried=camp_ui.carried;preparation.difficulty=camp_ui.difficulty;preparation.initial_level=camp_ui.initial_level
	var current_signature:=preparation.signature()
	if current_signature!=_draft_signature:
		_draft_signature=current_signature;preparation.confirmed=false;preview_preparation()
	if GameState.passive_id!=PassiveDefinitions.selected(Characters.current_id()):GameState.passive_id=PassiveDefinitions.selected(Characters.current_id());reset_training()
func preview_preparation()->void:
	GameState._clear_equipment()
	for id in preparation.loadout:
		var item:=ExpeditionData.resolve(str(id))
		if ItemDB.is_equippable(item):GameState.equipment[ItemDB.slot_of(item)]=item.duplicate(true)
	GameState._after_equipment_change()
func _confirm_preparation(_payload:Dictionary)->void:
	_sync_preparation();var error:=preparation.confirm()
	if not error.is_empty():camp_ui._feedback=error;camp_ui.open_facility("prepare");return
	var notice:="准备已确认 · 完成引导后开启大门" if is_instance_valid(tutorial) and tutorial.active else "准备完成 · 四门已开启"
	Effects.text(fx_root,player.position-Vector2(0,50),notice,PixelUi.GOLD,18)
func _process(dt:float)->void:
	if not is_instance_valid(player) or _departing:return
	_camp_enter_clock+=dt;_sync_preparation();level.doors_open=preparation.ready() and (not is_instance_valid(tutorial) or not tutorial.active)
	for side in _gate_sprites:
		var gate:Dictionary=_gate_sprites[side]
		var closed:=maxf(.001,1.0-level.door_phase)
		gate.left.scale=gate.scale*Vector2(closed,1)
		gate.right.scale=gate.scale*Vector2(closed,1)
		gate.right.position.x=float(gate.width)-float(gate.right_width)*closed
		gate.root.visible=level.door_phase<.999
	if _camp_enter_clock>1 and not UIFlow.has_screen() and level.doors_open and level.door_at(player.position)!=Vector2i.ZERO:_depart_camp()
func nearest_facility()->String:
	if not is_instance_valid(player):return ""
	var best:=72.0;var result:=""
	for role in facilities:
		var distance:=facility_interaction_distance(str(role))
		if distance<best:best=distance;result=str(role)
	return result
func player_collision_center()->Vector2:
	var collider:=player.get_node_or_null("BodyCollider") as CollisionShape2D
	return level.to_local(collider.global_position if collider!=null else player.global_position)
func facility_interaction_distance(role:String)->float:
	if not is_instance_valid(player) or not facilities.has(role):return INF
	var from:=player_collision_center();var marker:Vector2=facilities[role];var best:=INF
	var marker_distance:=from.distance_to(marker)
	if marker_distance<72 and level.sight(from,marker):best=marker_distance
	var polygon:PackedVector2Array=level.scene_polygons.get(role,PackedVector2Array())
	if polygon.size()>=3:
		var boundary:=RoomSceneGeometry.closest_boundary_point(from,polygon)
		var boundary_distance:=from.distance_to(boundary)
		# A boundary point belongs to the building itself. Stop the visibility
		# segment just outside it; other scenery still blocks interactions.
		if boundary_distance<72 and level.sight(from,boundary.move_toward(from,1.0)):best=minf(best,boundary_distance)
	return best
func _unhandled_input(event:InputEvent)->void:
	if UIFlow.has_screen() or _departing:return
	if event.is_action_pressed("inventory"):inventory_ui.open()
	elif event.is_action_pressed("talents"):talent_ui.open()
	elif event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel"):
		_pause_root.show();UIFlow.push_screen(_pause);PixelUi.focus_button(_pause_root)
	elif event.is_action_pressed("interact"):
		var role:=nearest_facility()
		var npc:=nearest_resident()
		if npc!=null and (role.is_empty() or player_collision_center().distance_to(level.to_local(npc.global_position))<facility_interaction_distance(role)):resident_panel.open_for(npc)
		else:interact_facility(role)
	else:return
	get_viewport().set_input_as_handled()
func interact_facility(role:String)->void:
	if UIFlow.has_screen() or role.is_empty():return
	if role=="training":training_ui.open()
	elif role=="iris":camp_ui._npc="iris";camp_ui.open_facility("relations")
	elif role=="relations":camp_ui._npc="tavern";camp_ui.open_facility("relations")
	else:
		if role=="shop":camp_ui._npc="merchant"
		camp_ui.open_facility(role)
	if role!="training" and camp_ui.is_open():_opened_facility=role;facility_opened.emit(role)
	elif role=="training" and training_ui.is_open():facility_opened.emit(role)

func _spawn_residents()->void:
	residents_root=Node2D.new();residents_root.name="CampResidents";residents_root.y_sort_enabled=true;actors_root.get_parent().add_child(residents_root)
	for id in CampResidents.DATA:
		var info:Dictionary=CampResidents.DATA[id];var home:Vector2=facilities.get(str(info.home),level.room_rect.get_center())+Vector2(info.offset[0],info.offset[1])
		home=level.nearest_clear(home,9)
		var npc:=CampResident.new();npc.world=self;npc.resident_id=str(id);npc.home=home;npc.position=home;residents_root.add_child(npc)
func nearest_resident()->CampResident:
	if not is_instance_valid(residents_root) or not is_instance_valid(player):return null
	var best:=66.0;var result:CampResident
	for node in residents_root.get_children():
		var npc:=node as CampResident
		if npc==null:continue
		var distance:=player.position.distance_to(npc.position)
		if distance<best and level.sight(player.position,npc.position):best=distance;result=npc
	return result
func _input(event:InputEvent)->void:
	if is_instance_valid(_pause_root) and _pause_root.visible and UIFlow.is_top(_pause) and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):_close_pause();get_viewport().set_input_as_handled()
func _spawn_dummy()->void:
	dummy=TrainingDummy.new();dummy.room=level;dummy.setup(player,level,1,1,1);dummy.fx_root=fx_root;dummy.position=marker_position("dummy",Vector2(870,520));enemies_root.add_child(dummy)
func reset_training()->void:
	if not is_instance_valid(player):return
	var position:Vector2=player.position
	for field in get_tree().get_nodes_in_group("spell_fields"):
		if is_instance_valid(field) and field.get("room")==level:
			field.get_parent().remove_child(field);field.queue_free()
	for parent in [actors_root,enemies_root,fx_root]:
		for child in parent.get_children():parent.remove_child(child);child.queue_free()
	GameState.temp_buffs.clear();GameState.skill_cooldowns_by_id.clear();GameState._sync_skill_cooldowns();GameState.mp=GameState.MAX_MP;GameState._reset_stats()
	_spawn_player();player.position=position;player.hp=player.max_hp;_spawn_dummy();camera.snap_to_target();EventBus.skills_changed.emit();EventBus.mp_changed.emit(GameState.mp,GameState.MAX_MP)
func _depart_camp()->bool:
	if _departing or not preparation.ready():return false
	if is_instance_valid(tutorial) and tutorial.active:return false
	if editor_validation:
		Effects.text(fx_root,player.position-Vector2(0,50),"编辑器验证：出口通路正常",PixelUi.GOLD,17);player.position=level.room_rect.get_center();return true
	_departing=true
	if not Outpost.start_sortie(preparation.loadout,preparation.carried,preparation.danger,preparation.difficulty,preparation.initial_level,preparation.chapter_id):
		_departing=false;preparation.confirmed=false;camp_ui._feedback="出发保存失败或物资变化，请重新确认。";camp_ui.open_facility("prepare");return false
	var payload:=SaveService.run_info().duplicate(true);_leave_camp();departure_requested.emit(payload);return true
func _leave_camp()->void:
	set_process(false);set_physics_process(false)
	if is_instance_valid(player):player.set_physics_process(false)
	if is_instance_valid(tutorial):tutorial.shutdown()
	if is_instance_valid(residents_root):residents_root.process_mode=Node.PROCESS_MODE_DISABLED
	if is_instance_valid(resident_panel):resident_panel.close()
	if is_instance_valid(dialogue):dialogue.cancel()
	for panel in [camp_ui,inventory_ui,talent_ui,training_ui]:
		if is_instance_valid(panel) and panel.is_open():panel.close()
	CampSession.end(self)
func _exit_tree()->void:CampSession.end(self)
func _build_gate_animations()->void:
	var art:Dictionary=level.illustration.data
	if art.is_empty():return
	var frame:Rect2=level.illustration.frame_rect();var floor:Array=art.floor_rect_px
	var scale_value:Vector2=level.illustration.visual_room_rect().size/Vector2(float(floor[2]),float(floor[3]))
	var origin:Array=art.get("gate_origin",[15,9])
	for side in art.get("gates",{}):
		var config:Dictionary=art.gates[side]
		if not bool(config.get("leaf_only",false)):continue
		var texture:Texture2D=load(RoomSceneArtCatalog.ROOT+str(art.id)+"/"+str(config.path))
		var box:Array=config.rect_px
		var rect:=Rect2(frame.position+Vector2(float(box[0]),float(box[1]))*scale_value+RoomSceneArtwork.gate_offset(side,level.record.terrain_layout.ports,Vector2(float(origin[0]),float(origin[1]))),Vector2(float(box[2]),float(box[3]))*scale_value)
		var pivot:=Node2D.new();pivot.position=rect.position;pivot.z_index=1;level.illustration.add_child(pivot)
		var left:=Sprite2D.new();var right:=Sprite2D.new()
		var half:=int(texture.get_width()/2);var widths:=[half,texture.get_width()-half]
		var sprite_scale:=rect.size/texture.get_size()
		for index in 2:
			var sprite:Sprite2D=left if index==0 else right
			var leaf:=AtlasTexture.new();leaf.atlas=texture;leaf.region=Rect2(0 if index==0 else half,0,widths[index],texture.get_height());leaf.filter_clip=true
			sprite.texture=leaf;sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.scale=sprite_scale;pivot.add_child(sprite)
		right.position.x=half*sprite_scale.x
		_gate_sprites[side]={"root":pivot,"left":left,"right":right,"scale":sprite_scale,"width":rect.size.x,"right_width":widths[1]*sprite_scale.x}
		if level.illustration.gates.has(side):level.illustration.gates[side].hide()
