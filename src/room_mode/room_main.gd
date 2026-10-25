extends "res://src/main/main.gd"
var graph:=RoomGraph.new()
var room_weather:=WeatherState.new()
var room_token:=0
var _door_lock:=0.0
var map_screen:RoomMapScreen
var _room_rng:=RandomNumberGenerator.new()
var _room_visual:RoomWeatherVisual
## Story keys 30/60/100 remain stable replay IDs. Schema 3 uses fixed stage terminals.
var _story_queue:Array=[]
var _story_context:=""
var _active_room_story:StringName=&""
var _room_transfer:=false
var _room_cover_ticket:=-1
var world_clock:=RoomWorldClock.new()
var environment_visual:RoomEnvironmentVisual
var _reward_pending:Dictionary={}
var special_rooms:SpecialRoomController
var expansion:RoomExpansionController
var gm_pilot:GMPilot
var fate_ui:FateUI
var star_choice_ui:ItemChoiceUI
var fate_altar:FateAltar
var stage_gate:StageGate
var _stage_rollback:=false
var room_prefetch:RoomNeighbourPrefetch
var _room_reference_fields:Dictionary={}

func _create_level()->RoomLevel:return load("res://src/room_mode/room_level.tscn").instantiate()
func _create_director()->RoomDirector:return RoomDirector.new()

func _build_world()->void:
	RoomInput.install()
	var backdrop:=CanvasLayer.new();backdrop.layer=-100;add_child(backdrop)
	var shade:=ColorRect.new();shade.color=Color("0b141b");shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);backdrop.add_child(shade)
	level=_create_level();add_child(level)
	var sorting:=Node2D.new();sorting.name="GroundActors";sorting.y_sort_enabled=true;add_child(sorting)
	level.props_root.reparent(sorting)
	level.decor_root.reparent(sorting)
	actors_root=Node2D.new();actors_root.name="Actors";actors_root.y_sort_enabled=true;sorting.add_child(actors_root)
	enemies_root=Node2D.new();enemies_root.name="Enemies";enemies_root.y_sort_enabled=true;sorting.add_child(enemies_root)
	fx_root=Node2D.new();fx_root.name="FX";add_child(fx_root);fx_root.add_to_group("room_fx")
	chests_root=Node2D.new();chests_root.name="Chests";chests_root.y_sort_enabled=true;sorting.add_child(chests_root)
	camera=RoomCamera.new();camera.room=level;add_child(camera);camera.setup(level.bounds())
	var controller:RoomDirector=_create_director();controller.room=level;controller.graph=graph
	controller.level=level;controller.camera=camera;controller.enemies_root=enemies_root;controller.fx_root=fx_root;controller.chests_root=chests_root
	director=controller;add_child(director)
	_room_visual=RoomWeatherVisual.new();_room_visual.weather=room_weather;_room_visual.main=self;add_child(_room_visual)
	environment_visual=RoomEnvironmentVisual.new();environment_visual.main=self;environment_visual.world_clock=world_clock;add_child(environment_visual)
	special_rooms=SpecialRoomController.new();special_rooms.main=self;add_child(special_rooms)
	expansion=RoomExpansionController.new();expansion.main=self;add_child(expansion)
	room_prefetch=RoomNeighbourPrefetch.new();room_prefetch.main=self;add_child(room_prefetch)

func _build_ui()->void:
	super._build_ui()
	if UIFlow.has_method("unbind_hud"):UIFlow.call("unbind_hud",hud)
	remove_child(hud);hud.queue_free()
	var room_hud:=RoomHud.new();room_hud.graph=graph;room_hud.weather=room_weather;room_hud.world_clock=world_clock;room_hud.director=director;hud=room_hud;add_child(hud);UIFlow.bind_hud(hud)
	map_screen=RoomMapScreen.new();map_screen.graph=graph;add_child(map_screen)
	fate_ui=FateUI.new();add_child(fate_ui)
	star_choice_ui=preload("res://src/ui/star_choice_ui.gd").new();add_child(star_choice_ui)
	fate_altar=FateAltar.new();fate_altar.main=self;fate_altar.ui=fate_ui;actors_root.get_parent().add_child(fate_altar)
	stage_gate=StageGate.new();stage_gate.main=self;add_child(stage_gate)
	gm_pilot=GMPilot.new();gm_pilot.main=self;add_child(gm_pilot)
	var bot_test:=BotTestControl.new();bot_test.name="BotTestControl";bot_test.main=self;add_child(bot_test)

func _begin_run(data:Dictionary)->void:
	if not _stage_rollback:SaveService._transition_checkpoint.clear()
	if _room_transfer:
		if TransitionLayer.busy and TransitionLayer._epoch==_room_cover_ticket:TransitionLayer.cancel()
		_room_transfer=false
	if str(Outpost.data.get("active",{}).get("status",""))=="dead" and not Outpost.finalize_death():start_new_run();return
	if not Outpost.active_id().is_empty() and (data.is_empty() or data.has("departure")):data=SaveService.run_info().duplicate(true)
	var fresh:=data.is_empty() or (data.has("departure") and not data.has("expedition_items"))
	var departure:Dictionary=data.get("departure",{})
	if fresh:
		var committed:=not Outpost.active_id().is_empty() and str(data.get("sortie_id",""))==Outpost.active_id()
		if not committed and not Outpost.start_sortie(departure.get("loadout",[]),int(departure.get("carried",0)),int(departure.get("danger",0)),RunDifficulty.from_record(departure),int(departure.get("initial_level",1)),ChapterCatalog.normalize(departure.get("chapter_id",ChapterCatalog.FIRST)),str(departure.get("constellation","")),departure.get("skill_loadout",null)):start_new_run();return
		departure=Outpost.data.active.duplicate(true)
	elif str(data.get("sortie_id",""))!=Outpost.active_id():start_new_run();return
	_flow_epoch+=1;room_token+=1;_choice_delay_token+=1;_navigation_pending=false
	if is_instance_valid(room_prefetch):room_prefetch.clear();room_prefetch._flow=_flow_epoch
	var begin_ticket:=_flow_epoch
	_close_run_screens();_clear_run_entities()
	_reward_offers.clear();_reward_wave=-1;_checkpoint_wave=0
	_story_queue.clear();_story_context="";_active_room_story=&"";_reward_pending.clear()
	restart_gate.enabled=true
	if fresh:
		GameState.new_run(hash(Outpost.active_id()));GameState.combat_mode="rooms";GameState.sortie_id=Outpost.active_id();GameState.add_coins(int(departure.get("carried",0)))
		GameState.fate.star="";GameState.fate.star_pending=true
		GameState.set_starting_skills(departure.get("skill_loadout",null))
		DepartureLevels.apply(int(departure.get("initial_level",1)))
		GameState.difficulty=RunDifficulty.from_record(departure)
		GameState.chapter_id=ChapterCatalog.normalize(departure.get("chapter_id",ChapterCatalog.FIRST))
		for id in departure.get("loadout",[]):
			var item:=Outpost.stored_item(str(id));GameState.add_item(item)
			if ItemDB.is_equippable(item):GameState.equip(GameState.items.back())
		graph.begin(Rng.run_seed,GameState.chapter_id)
	else:
		GameState.restore(data);GameState.combat_mode="rooms"
		if not graph.restore(data.get("world_state",{}).get("graph",{})):graph.begin(Rng.run_seed,GameState.chapter_id)
		GameState.chapter_id=graph.chapter_id
	room_weather.setup(Rng.run_seed,data.get("world_state",{}).get("weather",{}),maxi(1,graph.encounters))
	world_clock.setup(Rng.run_seed,data.get("world_state",{}).get("clock",{}))
	environment_visual.restore(data.get("world_state",{}).get("environment",{}))
	_room_rng.seed=Rng.run_seed^0x62418
	if TransitionLayer.busy:
		if not await level.load_room_async(graph.rooms[graph.current],self,TransitionLayer._epoch):return
		if begin_ticket!=_flow_epoch:return
	else:level.load_room(graph.rooms[graph.current])
	if not await CombatArtWarmup.prepare(get_tree(),BossEntranceArt.for_room(graph.rooms[graph.current],graph.chapter_id),func()->bool:return is_inside_tree() and begin_ticket==_flow_epoch):return
	_spawn_player();director.player=player
	if not fresh:player.hp=clampf(float(data.get("hp_ratio",1))*player.max_hp,1,player.max_hp)
	expedition=RoomRuntime.new();expedition.main=self;add_child(expedition)
	_spawn_hired_allies();director.enter_room(graph.rooms[graph.current]);fate_altar.sync_room();_sync_services()
	_spawn_template_chests()
	if not fresh:
		expedition.restore(data.get("world_state",{}));_restore_expedition_flow(data.get("world_state",{}).get("flow",{}))
	_notify_equipment_room_enter()
	level.ensure_clear_actors()
	camera.snap_to_target()
	hud.set_hp(player.hp,player.max_hp);hud.refresh_skill_bar();hud.set_hint("WASD 八向移动 · 方向键连射 · 清房后从门口进入下一房")
	AudioManager.sync_room_music(world_clock.minutes,room_weather.kind)
	_door_lock=1.2;expedition.checkpoint()
	if fresh:
		_story_queue=["city_entry" if GameState.chapter_id==ChapterCatalog.NEXT else "intro_wake"]
		_story_context="entry";_continue_room_story(begin_ticket,room_token)

func _spawn_player()->void:
	var unit:=RoomPlayer.new();unit.room=level;unit.level=level;unit.position=level.nearest_clear(level.room_rect.get_center()+Vector2(0,72));player=unit;actors_root.add_child(player)
	camera.target=player;camera.snap_to_target()

func _notify_equipment_room_enter()->void:
	if not is_instance_valid(player):return
	var mechanics:Node=player.get_node_or_null("EquipmentMechanics")
	if not is_instance_valid(mechanics) or not mechanics.has_method("on_room_enter"):return
	var record:Dictionary=graph.rooms.get(graph.current,{})
	mechanics.call("on_room_enter",str(graph.current),str(record.get("kind",""))=="normal" and not bool(record.get("cleared",false)))

func _spawn_ally(entry:Dictionary)->void:
	var ally:=RoomAlly.new();ally.room=level;ally.setup(entry,player,level,fx_root);actors_root.add_child(ally);ally.place_near_player()

func _sync_services()->void:
	if is_instance_valid(npc):actors_root.remove_child(npc);npc.queue_free();npc=null
	if is_instance_valid(tavern):actors_root.remove_child(tavern);tavern.queue_free();tavern=null
	var kind:=str(graph.rooms[graph.current].kind)
	if is_instance_valid(special_rooms):special_rooms.configure(graph.rooms[graph.current])
	if is_instance_valid(expansion):expansion.configure(graph.rooms[graph.current])
	if bool(level.record.get("terrain_layout",{}).get("service_layout",false)) and not is_instance_valid(level.service_building):return
	if kind=="shop":
		var store:=RoomShop.new();store.main=self;npc=store;npc.player=player;npc.position=level.service_anchor()+Vector2(0,34);actors_root.add_child(npc);npc._set_open(true)
	elif kind=="tavern":
		var inn:=RoomTavern.new();inn.main=self;tavern=inn;tavern.player=player;tavern.position=level.service_anchor()+Vector2(0,34);actors_root.add_child(tavern);tavern._set_open(true)

func open_room_shop()->void:
	if not safe_room() or graph.rooms[graph.current].kind!="shop":return
	if shop_ui._offers.is_empty():
		shop_ui._visit_wave=-1
		shop_ui.open(ItemDB.roll_offers(3,Rng.stream(),0,&"shop"))
	else:
		shop_ui._visit_wave=GameState.wave;shop_ui.open(shop_ui._offers)

func open_room_tavern()->void:
	if not safe_room() or graph.rooms[graph.current].kind!="tavern":return
	if tavern_ui._offers.is_empty():
		tavern_ui._visit_wave=-1;tavern_ui.open(HireOffers.roll_offers(Rng.stream()))
	else:
		tavern_ui._visit_wave=GameState.wave;tavern_ui.open(tavern_ui._offers)

func _process(dt:float)->void:
	if not GameState.run_active or not is_instance_valid(player):return
	_try_starting_star()
	if not str(graph.altar_pacing.notice).is_empty() and not UIFlow.has_screen() and not TransitionLayer.busy and _reward_pending.is_empty() and bool(graph.rooms[graph.current].rewarded):
		var notice:=graph.take_altar_notice()
		if not notice.is_empty():hud.show_banner(notice,3);expedition.checkpoint()
	_deliver_pending_chest()
	room_weather.tick(dt);world_clock.tick(dt)
	AudioManager.sync_room_music(world_clock.minutes,room_weather.kind)
	if not _reward_pending.is_empty():
		_reward_pending.remaining=maxf(0,float(_reward_pending.remaining)-dt/maxf(0.001,Engine.time_scale))
		if float(_reward_pending.remaining)<=0 and not expedition.motion.running and expedition.extraction.state==ExtractionDirector.IDLE:
			var pending:=_reward_pending.duplicate();_reward_pending.clear()
			_finish_room_clear(int(pending.progress),int(pending.epoch),int(pending.token))
	_door_lock=maxf(0,_door_lock-dt)
	if _door_lock<=0 and safe_room() and expedition.extraction.state==ExtractionDirector.IDLE:
		var direction:Vector2i=level.door_at(player.global_position)
		if direction!=Vector2i.ZERO:_change_room(direction)

func _try_grow_mushroom()->bool:
	# Compatibility hook for old tests/tools. Harvesting has been retired.
	return false
func _close_run_screens()->void:
	if is_instance_valid(star_choice_ui) and star_choice_ui.is_open():star_choice_ui.cancel()
	if is_instance_valid(stage_gate):stage_gate.close();stage_gate.confirm.close()
	if is_instance_valid(map_screen):map_screen.close()
	if is_instance_valid(expansion) and is_instance_valid(expansion.panel):expansion.panel.close(true)
	super._close_run_screens()

func _try_starting_star()->void:
	if not bool(GameState.fate.get("star_pending",false)) or CampSession.active or not graph.staged or graph.stage_index!=1:return
	if str(graph.rooms.get(graph.current,{}).get("kind",""))!="spawn" or not _story_queue.is_empty() or not _story_context.is_empty():return
	if UIFlow.has_screen() or TransitionLayer.busy or _navigation_pending or _room_transfer:return
	if is_instance_valid(star_choice_ui):star_choice_ui.call("open_stars")

func safe_room()->bool:
	return graph.rooms.has(graph.current) and bool(graph.rooms[graph.current].cleared) and (bool(graph.rooms[graph.current].rewarded) or graph.rooms[graph.current].kind=="spawn") and not UIFlow.has_screen() and _reward_offers.is_empty() and not _navigation_pending

func _change_room(direction:Vector2i)->void:
	if bool(GameState.fate.get("star_pending",false)) and graph.staged and graph.stage_index==1:return
	var id:=graph.neighbour(direction)
	if id.is_empty() or _navigation_pending:return
	id=graph.entry_destination(id)
	if id==graph.current:return
	_navigation_pending=true
	player.stop_room_travel_motion()
	_room_transfer=true;_room_cover_ticket=TransitionLayer._epoch+1
	var ticket:=_flow_epoch;var old_room:=room_token
	if not TransitionLayer.cover_room(direction,self):
		if ticket==_flow_epoch:_navigation_pending=false;_room_transfer=false
		return
	if ticket!=_flow_epoch or old_room!=room_token:return
	var rollback:=GameState.snapshot()
	PassiveRuntime.on_room_exit(player)
	if player is RoomPlayer and is_instance_valid(player.ilyua_runtime):player.ilyua_runtime.on_room_exit()
	if player is RoomPlayer and is_instance_valid(player.holy_runtime):player.holy_runtime.on_room_exit()
	expedition.persist_room();clear_hostile_effects();room_token+=1
	for parent in [enemies_root,fx_root,chests_root]:
		for child in parent.get_children():parent.remove_child(child);child.queue_free()
	var previous_progress:=graph.encounters
	graph.enter(id)
	id=graph.current
	var prepared:=await room_prefetch.obtain(id)
	if ticket!=_flow_epoch or old_room+1!=room_token:
		if is_instance_valid(prepared):prepared.queue_free()
		return
	if prepared==null:
		await _begin_run(rollback)
		hud.show_banner("房间准备中断，已返回原房间",2)
		return
	_install_prepared_level(prepared,graph.rooms[id])
	player.global_position=level.entry_point(direction);player.stop_room_travel_motion()
	director.enter_room(graph.rooms[id])
	fate_altar.sync_room()
	_spawn_template_chests()
	for ally in get_tree().get_nodes_in_group("allies"):ally.place_near_player()
	var saved:Dictionary=graph.rooms[id].delta.get("runtime",{})
	if not saved.is_empty():expedition.restore_room(saved)
	else:shop_ui.expedition_restore({});tavern_ui.expedition_restore({})
	_notify_equipment_room_enter()
	level.ensure_clear_actors()
	camera.snap_to_target()
	if graph.encounters!=previous_progress:room_weather.advance_wave(maxi(1,graph.encounters))
	_sync_services();_door_lock=1.0
	_room_visual._process(0.0)
	environment_visual._process(0.0)
	_navigation_pending=false;expedition.checkpoint()
	await TransitionLayer.uncover_room()
	if ticket!=_flow_epoch or not GameState.run_active:return
	_room_transfer=false
	var record:Dictionary=graph.rooms[graph.current]
	if record.kind=="boss" and not record.delta.get("pre_story",false):
		record.delta.pre_story=true
		_story_queue=["city_"+str(record.boss)+"_before"] if GameState.chapter_id==ChapterCatalog.NEXT else ["forest_"+str(record.boss)+"_before"]
		record.delta.boss_story_intro=not _story_queue.is_empty()
		_story_context="entry";_continue_room_story(ticket,room_token)

func _set_room_query_groups(root:Node,active:bool)->void:
	if root is RoomProp:
		if active:root.add_to_group("room_props")
		else:root.remove_from_group("room_props")
	if root is RoomLightProp:
		if active:root.add_to_group("room_environment_lights")
		else:root.remove_from_group("room_environment_lights")
	for child in root.get_children():_set_room_query_groups(child,active)

func _rebind_room_references(node:Node,previous:RoomLevel,next:RoomLevel,skip:Array)->void:
	if node in skip:return
	# Persistent actor children (caster, companion weapon) and hidden HUDs can
	# own map references too. Rebind before freeing the previous map.
	var script:Script=node.get_script()
	if script!=null:
		if not _room_reference_fields.has(script):
			var names:Array[String]=[]
			for field in node.get_property_list():
				if str(field.name) in ["room","level"] and (int(field.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)!=0:names.append(str(field.name))
			_room_reference_fields[script]=names
		for field:String in _room_reference_fields[script]:
			var value:Variant=node.get(field)
			if typeof(value)==TYPE_OBJECT and is_instance_valid(value) and value==previous:node.set(field,next)
	for child in node.get_children():_rebind_room_references(child,previous,next,skip)

func _install_prepared_level(prepared:RoomLevel,record:Dictionary)->void:
	var started:=Time.get_ticks_usec()
	var previous:RoomLevel=level
	_rebind_room_references(self,previous,prepared,[previous,previous.props_root,previous.decor_root,prepared,room_prefetch])
	for root in [previous.props_root,previous.decor_root,previous]:_set_room_query_groups(root,false)
	for root in [previous.props_root,previous.decor_root]:
		if root.get_parent()!=previous:root.get_parent().remove_child(root);root.queue_free()
	previous.get_parent().remove_child(previous);previous.queue_free()
	for field in ["terrain_layout","biome","indoor"]:
		if prepared.record.has(field):record[field]=prepared.record[field]
	level=prepared;prepared.record=record;prepared.prefetching=false;prepared.prefetch_valid=Callable()
	# Equal-z CanvasItems follow tree order. Prepared floors must stay behind actors.
	move_child(prepared,actors_root.get_parent().get_index())
	prepared.process_mode=Node.PROCESS_MODE_INHERIT
	prepared.props_root.reparent(actors_root.get_parent(),false)
	prepared.decor_root.reparent(actors_root.get_parent(),false)
	_set_room_query_groups(prepared,true);_set_room_query_groups(prepared.props_root,true);_set_room_query_groups(prepared.decor_root,true)
	player.room=prepared;player.level=prepared;director.room=prepared;director.level=prepared;camera.room=prepared
	if is_instance_valid(player.caster):player.caster.room=prepared;player.caster.cancel_cast()
	prepared.register_unit_body(player,12.0)
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally is FateAltar:continue
		ally.room=prepared;ally.level=prepared
		prepared.register_unit_body(ally,float(ally.get_meta("unit_radius",12.0)),ally.is_flying() if ally is RoomAlly else false)
	prepared.sync_door_links(record)
	room_prefetch.last_install_ms=(Time.get_ticks_usec()-started)/1000.0

func clear_hostile_effects()->void:
	if is_instance_valid(expansion):expansion.clear_danger_fields()
	for node in get_tree().get_nodes_in_group("hostile_attack_fx"):
		node.set_process(false);node.hide();node.queue_free()
	for node in get_tree().get_nodes_in_group("room_projectiles"):
		if not node.is_friendly:node.set_physics_process(false);node.hide();node.queue_free()
	for node in get_tree().get_nodes_in_group("spell_fields"):
		node.set_physics_process(false);node.queue_free()
	for node in get_tree().get_nodes_in_group("affix_hazards"):
		node.set_physics_process(false);node.hide();node.queue_free()

func _on_wave_cleared(progress:int)->void:
	if not GameState.run_active or not _reward_pending.is_empty() or _reward_wave==progress:return
	level.sync_door_links(graph.rooms[graph.current])
	if expedition.loot is RoomLootDirector:expedition.loot.ensure_room_material()
	_reward_pending={"progress":progress,"remaining":RoomFlowConfig.REWARD_DELAY,"epoch":_flow_epoch,"token":room_token}
	expedition.checkpoint()

func _finish_room_clear(progress:int,epoch:int,token:int)->void:
	if epoch!=_flow_epoch or token!=room_token or not GameState.run_active:return
	clear_hostile_effects()
	if _reward_wave==progress and not _reward_offers.is_empty():return
	_story_queue.clear();_story_context="clear"
	var record:Dictionary=graph.rooms[graph.current]
	if GameState.chapter_id==ChapterCatalog.NEXT:
		if record.kind=="boss":_story_queue.append("city_"+str(record.boss)+"_after")
		elif record.kind in ["normal","elite"]:
			graph.normal_clears+=1
			if graph.normal_clears in [2,4]:_story_queue.append("city_clue_"+str(graph.normal_clears))
	elif record.kind=="boss":
		_story_queue.append({"king":30,"mage":60,"tide":100}.get(str(graph.rooms[graph.current].boss),0))
	elif record.kind in ["normal","elite"]:
		var stage_clears:=0
		for room:Dictionary in graph.rooms.values():
			if room.kind in ["normal","elite"] and bool(room.cleared):stage_clears+=1
		if graph.staged and graph.stage_index<=3 and stage_clears in [2,4]:
			_story_queue.append([10,40,70][graph.stage_index-1]+(10 if stage_clears==4 else 0))
		elif not graph.staged and graph.cleared_count in [2,4]:_story_queue.append(10 if graph.cleared_count==2 else 20)
	_reward_wave=progress;_reward_offers=expansion.altar_offers() if graph.rooms[graph.current].kind=="altar" else _roll_room_rewards(Rng.stream(),graph.rooms[graph.current].kind in ["boss","boss_rush"])
	_continue_room_story(epoch,token)

static func _roll_room_rewards(rng:RandomNumberGenerator,boss:=false)->Array[Dictionary]:
	return ItemDB.roll_offers(3,rng,0,&"reward",[],2 if boss else 0)

static func _upgrade_room_rewards(saved:Array,rng:RandomNumberGenerator,boss:=false)->Array[Dictionary]:
	var offers:Array[Dictionary]=[]
	var ids:Array[String]=[]
	for item:Dictionary in saved:
		if item.has("altar_key"):offers.assign(saved);return offers
		if (ItemDB.is_equippable(item) or ItemDB.is_relic(item)) and (not boss or int(item.get("rarity",0))>=2):
			offers.append(item);ids.append(str(item.get("id","")))
	if offers.size()<saved.size():offers.append_array(ItemDB.roll_offers(3-offers.size(),rng,0,&"reward",ids,2 if boss else 0))
	return offers

func _continue_room_story(epoch:int,token:int)->void:
	while not _story_queue.is_empty():
		var queued:Variant=_story_queue.pop_front();_checkpoint_wave=int(queued) if queued is int or queued is float else 0;_checkpoint_epoch=epoch
		var scene_id:StringName=StringName(queued) if queued is String else Story.checkpoint_id(_checkpoint_wave)
		_active_room_story=scene_id
		if not _autoplay_requested() and Story.has_scene(scene_id):
			dialogue.play_scene(scene_id);expedition.checkpoint()
			await dialogue.finished
			if epoch!=_flow_epoch or token!=room_token or not GameState.run_active:return
		_checkpoint_wave=0
		_active_room_story=&""
	_active_room_story=&""
	var context:=_story_context;_story_context=""
	if context=="clear":
		if graph.defeated.size()==3 and not GameState.chapter_cleared:
			GameState.chapter_cleared=true
			GameState.endless_mode=graph.staged or (false if GameState.chapter_id==ChapterCatalog.NEXT else not bool(StoryState.get_flag(&"go_next_scene",false)))
			StoryState.set_flag(&"city_cleared" if GameState.chapter_id==ChapterCatalog.NEXT else &"forest_cleared",true)
			if GameState.chapter_id==ChapterCatalog.FIRST:StoryState.set_flag(&"chapter_2_unlocked",true)
			expedition.extraction.open_stable()
			if GameState.first_chapter_seconds<0:GameState.first_chapter_seconds=GameState.active_play_seconds
		if not graph.staged and GameState.chapter_cleared and not GameState.endless_mode:
			_reward_offers.clear();_reward_pending.clear();expedition.checkpoint()
			if GameState.chapter_id==ChapterCatalog.NEXT:
				graph.rooms[graph.current].rewarded=true;chapter_end_ui.open(GameState.snapshot());return
			_request_chapter_exit.call_deferred();return
		choice_ui.open(_reward_offers)
	expedition.checkpoint()

func _on_item_chosen(item:Dictionary)->void:
	if not GameState.run_active or _reward_offers.is_empty():return
	if item.has("altar_key"):
		expansion.claim_altar(item);return
	super._on_item_chosen(item);_sync_services();expedition.checkpoint()

func _on_story_checkpoint(_progress:int)->void:pass
func _unhandled_input(event:InputEvent)->void:
	if event.is_action_pressed("room_map") and not event.is_echo():
		if GameState.run_active and not UIFlow.has_screen() and not TransitionLayer.busy and not _extraction_blocks_input():map_screen.open()
		get_viewport().set_input_as_handled();return
	if event.is_action_pressed("room_call_goddess"):
		if GameState.run_active and not UIFlow.has_screen():expedition.extraction.request()
		get_viewport().set_input_as_handled();return
	# The existing right-stick-up goddess binding cannot intercept eight-way aiming.
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:return
	super._unhandled_input(event)
func _on_checkpoint_finished()->void:_checkpoint_wave=0
func leave_cleared_chapter()->void:
	if not GameState.chapter_cleared and not (graph.staged and GameState.run_active):return
	pause_ui.close(true)
	_request_chapter_exit.call_deferred()
func _request_chapter_exit()->void:
	if not GameState.run_active or not is_instance_valid(player):return
	player.velocity=Vector2.ZERO;player._dash_timer=0
	expedition.extraction.request()
func _on_next_chapter(id:StringName)->void:
	if GameState.chapter_cleared and ChapterCatalog.unlocked(id):
		chapter_end_ui.close();leave_cleared_chapter()
func _continue_endless()->void:
	super._continue_endless()
	if GameState.chapter_cleared:
		graph.rooms[graph.current].rewarded=true;level.doors_open=true;_reward_offers.clear();_reward_pending.clear();expedition.checkpoint()
func _restore_expedition_flow(raw:Dictionary)->void:
	var saved:Dictionary=expedition._decode(raw)
	var epoch:=_flow_epoch;var token:=room_token
	_reward_pending=saved.get("reward_pending",{}).duplicate(true)
	if not _reward_pending.is_empty():
		_reward_pending.epoch=epoch;_reward_pending.token=token
	_reward_offers=_upgrade_room_rewards(saved.get("offers",[]).duplicate(true),Rng.stream(),graph.rooms[graph.current].kind in ["boss","boss_rush"]);_reward_wave=int(saved.get("reward_wave",-1));_checkpoint_wave=int(saved.get("checkpoint",0))
	_story_queue=saved.get("story_queue",[]).duplicate();_story_context=str(saved.get("story_context",""))
	_active_room_story=StringName(saved.get("active_story",""))
	if saved.get("dialogue",{}).is_empty() and _active_room_story!=&"":_story_queue.push_front(str(_active_room_story))
	if not saved.get("dialogue",{}).is_empty():
		dialogue.expedition_restore(saved.dialogue)
		await dialogue.finished
		if epoch!=_flow_epoch or token!=room_token or not GameState.run_active:return
		_active_room_story=&""
		_checkpoint_wave=0
	if not _story_context.is_empty() or not _story_queue.is_empty():_continue_room_story(epoch,token);return
	if not graph.staged and GameState.chapter_cleared and not GameState.endless_mode:
		_reward_offers.clear();_reward_pending.clear()
		if GameState.chapter_id==ChapterCatalog.NEXT and expedition.extraction.state==ExtractionDirector.IDLE:
			chapter_end_ui.open(GameState.snapshot());return
		if expedition.extraction.state==ExtractionDirector.IDLE:_request_chapter_exit.call_deferred()
		return
	if director.phase==WaveDirector.Phase.CLEARED:
		if _reward_offers.is_empty():_on_wave_cleared(GameState.wave)
		else:choice_ui.open(_reward_offers)

func _transition_run(data:Dictionary)->void:
	super._transition_run(data)

func _spawn_template_chests()->void:
	if graph.rooms[graph.current].kind in ["reward","game","elite","boss_rush","altar","trial","event"]:return
	var record:Dictionary=graph.rooms[graph.current]
	if record.delta.has("chest_delivery"):return
	# Old room snapshots already own their chest entities. Never reroll on migration.
	if not record.delta.get("runtime",{}).is_empty():
		record.delta["chest_delivery"]={"decided":true,"drop":false,"delivered":true}
		return
	var template_at:=_chest_template_position(record)
	var roll:=_room_rng.randf() if template_at==Vector2.INF and RoomGraph.is_combat(str(record.kind)) else 1.0
	var drop:=_chest_should_drop(record,roll)
	var at:Vector2=template_at if template_at!=Vector2.INF else (level.spawn_point(_room_rng,player.global_position) if drop else Vector2.ZERO)
	record.delta["chest_delivery"]={"decided":true,"drop":drop,"delivered":false,"at":[at.x,at.y]}

func _on_chest_spawned()->void:
	if graph.rooms.get(graph.current,{}).get("kind","") in ["elite","reward","trial"]:
		hud.show_banner("宝箱降临",1.5,Palette.UI_ACCENT);return
	super._on_chest_spawned()

static func _chest_template_position(record:Dictionary)->Vector2:
	for entry in record.get("terrain_layout",{}).get("entities",[]):
		if str(entry.get("asset_id",""))=="chest":
			return RoomLayout.center(Vector2i(entry.at[0],entry.at[1]))
	return Vector2.INF

static func _chest_should_drop(record:Dictionary,roll:float)->bool:
	if _chest_template_position(record)!=Vector2.INF:return true
	return RoomGraph.is_combat(str(record.get("kind",""))) and roll<0.20

func _deliver_pending_chest()->void:
	if _navigation_pending or _room_transfer or TransitionLayer.busy or get_tree().paused:return
	if UIFlow.has_screen() or (is_instance_valid(dialogue) and dialogue.is_open()):return
	if not _story_queue.is_empty() or not _story_context.is_empty():return
	var record:Dictionary=graph.rooms[graph.current]
	var plan:Dictionary=record.delta.get("chest_delivery",{})
	if not bool(plan.get("drop",false)) or bool(plan.get("delivered",false)):return
	var at:Array=plan.get("at",[])
	if at.size()!=2:return
	var chest:=RoomChest.new();chest.setup(level,player)
	chest.position=Vector2(float(at[0]),float(at[1]))
	chest.begin_delivery()
	plan["delivered"]=true
	chests_root.add_child(chest)
	expedition.checkpoint()

func _try_interact_chest()->bool:
	if is_instance_valid(stage_gate) and stage_gate.try_interact():return true
	if is_instance_valid(fate_altar) and fate_altar.try_interact():return true
	return super._try_interact_chest()


func advance_stage()->bool:
	if not graph.can_advance() or _navigation_pending or _room_transfer or UIFlow.has_screen() or expedition.extraction.state!=ExtractionDirector.IDLE:return false
	# First durable checkpoint retains all previous-stage loot if saving fails.
	var previous:=GameState.snapshot()
	if not SaveService.save_run(previous):hud.show_banner("保存失败，仍留在本阶段",3);return false
	SaveService._transition_checkpoint=previous.duplicate(true)
	_navigation_pending=true;_room_transfer=true;player.stop_room_travel_motion()
	if is_instance_valid(room_prefetch):room_prefetch.clear()
	_room_cover_ticket=TransitionLayer._epoch+1
	var epoch:=_flow_epoch
	if not await TransitionLayer.cover("前往第%d阶段"%(graph.stage_index+1),"continue",self):
		SaveService._transition_checkpoint.clear();_navigation_pending=false;_room_transfer=false;return false
	if epoch!=_flow_epoch:return false
	PassiveRuntime.on_room_exit(player)
	if is_instance_valid(player.ilyua_runtime):player.ilyua_runtime.on_room_exit()
	if is_instance_valid(player.holy_runtime):player.holy_runtime.on_room_exit()
	clear_hostile_effects()
	if not graph.advance_stage(int(GameState.fate.get("readings",0))):
		SaveService._transition_checkpoint.clear();_navigation_pending=false;_room_transfer=false;await TransitionLayer.uncover();return false
	room_token+=1;_reward_offers.clear();_reward_pending.clear();_reward_wave=-1
	for parent in [enemies_root,fx_root,chests_root]:
		for child in parent.get_children():parent.remove_child(child);child.queue_free()
	if not await level.load_room_async(graph.rooms[graph.current],self,_room_cover_ticket):
		await _restore_failed_stage(previous);return false
	if epoch!=_flow_epoch:return false
	player.global_position=level.nearest_clear(level.room_rect.get_center()+Vector2(0,72));player.stop_room_travel_motion()
	director.enter_room(graph.rooms[graph.current]);fate_altar.sync_room()
	for ally in get_tree().get_nodes_in_group("allies"):
		if not ally is FateAltar:ally.place_near_player()
	shop_ui.expedition_restore({});tavern_ui.expedition_restore({});_sync_services();_notify_equipment_room_enter()
	level.ensure_clear_actors();camera.snap_to_target();_door_lock=1.2
	if not SaveService.save_run(GameState.snapshot(),true):
		await _restore_failed_stage(previous);return false
	SaveService._transition_checkpoint.clear()
	_navigation_pending=false
	await TransitionLayer.uncover()
	_room_transfer=false
	if graph.stage_index==4:
		_story_queue=["stage_echo_entry"];_story_context="entry";_continue_room_story(_flow_epoch,room_token)
	return true

func _restore_failed_stage(previous:Dictionary)->void:
	_navigation_pending=false;_room_transfer=false
	_stage_rollback=true
	await _begin_run(previous)
	_stage_rollback=false;SaveService._transition_checkpoint.clear()
	if TransitionLayer.busy:await TransitionLayer.uncover()
	hud.show_banner("阶段切换未保存，已恢复原房间与物资",3)
