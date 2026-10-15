class_name GMPilot
extends Node
## An opt-in local easter egg. No virtual input, stat changes or privileged rewards.
var main
var _banner:HBoxContainer
var _elapsed:=0.0
var _menu_elapsed:=0.0
var _gear_elapsed:=0.0
var _last_room:=""
var _last_position:=Vector2.INF
var _stuck:=0.0
var _ignored:Dictionary={}
var _loot_target:WeakRef
var _loot_seconds:=0.0

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var layer:=CanvasLayer.new();layer.layer=62;add_child(layer)
	var root:=UiFactory.full_rect();root.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(root)
	_banner=UiFactory.hbox(10);_banner.alignment=BoxContainer.ALIGNMENT_CENTER;root.add_child(_banner);_banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_banner.offset_left=-190;_banner.offset_right=190;_banner.offset_top=-151;_banner.offset_bottom=-119
	var label:=PixelUi.label("GM正在操作你的角色",18,Color("f2d68b"));label.add_theme_constant_override("outline_size",3);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;_banner.add_child(label)
	var exit_button:=PixelUi.compact_button("×",22);exit_button.name="StopGMPilot";exit_button.custom_minimum_size=Vector2(36,32);exit_button.tooltip_text="结束 GM 代行";_banner.add_child(exit_button);exit_button.pressed.connect(stop)
	InteractionSkin.apply_button(exit_button,"gm_pilot");_banner.hide()

func activate()->bool:
	if not GameState.run_active or CampSession.active or GameState.gm_pilot_used or not is_instance_valid(main.player) or main.player.hp<=0:return false
	GameState.gm_pilot_used=true;GameState.gm_pilot_active=true;_ignored.clear();_stuck=0;_last_room="";return true
func stop()->void:
	GameState.gm_pilot_active=false;_clear_controls();_banner.hide()
	if is_instance_valid(main.player) and RoomInput.using_mouse():main.player._mouse_attack_blocked=true
	if GameState.run_active:Outpost.request_checkpoint()
func _clear_controls()->void:
	if is_instance_valid(main.player):main.player.movement_override=Vector2.ZERO;main.player.aim_override=Vector2.ZERO
func _process(delta:float)->void:
	var active:bool=GameState.gm_pilot_active and GameState.run_active and not CampSession.active and is_instance_valid(main.player) and main.player.hp>0
	_banner.visible=active
	if not active:
		if GameState.gm_pilot_active:GameState.gm_pilot_active=false;_clear_controls()
		return
	_elapsed+=delta;_menu_elapsed+=delta;_gear_elapsed+=delta
	if _elapsed<.15:return
	var step:=_elapsed;_elapsed=0
	if TransitionLayer.busy or main._navigation_pending or main._room_transfer:_clear_controls();return
	if UIFlow.has_screen():
		_clear_controls()
		if _menu_elapsed>=.7:_menu_elapsed=0;_advance_screen()
		return
	if get_tree().paused or main.player.extraction_controls_locked():_clear_controls();return
	var actor:RoomPlayer=main.player
	if _last_room!=str(main.graph.current):_last_room=str(main.graph.current);_ignored.clear();_stuck=0;_last_position=actor.global_position;_loot_target=null;_loot_seconds=0
	_stuck=_stuck+step if actor.global_position.distance_to(_last_position)<2 and not actor.movement_override.is_zero_approx() else 0
	_last_position=actor.global_position
	if _gear_elapsed>=1:_gear_elapsed=0;_equip_upgrades()
	var enemies:=actor.equipment_mechanics.nearest_enemies(actor.global_position,1600,100)
	# A blocked enemy still needs to be approached, even without line of fire.
	var target:EnemyBase=enemies[0] if not enemies.is_empty() else null
	if target==null:
		var best:=INF
		for node in main.enemies_root.get_children():
			if node is EnemyBase and not node._dead and not node.is_queued_for_deletion() and node.hp>0:
				var distance:=actor.global_position.distance_squared_to(node.global_position)
				if distance<best:best=distance;target=node
	actor.aim_override=(target.global_position-actor.global_position).normalized() if target!=null else Vector2.ZERO
	if target!=null:
		_combat(target)
		return
	actor.movement_override=Vector2.ZERO
	if not main.safe_room():return
	if _collect_room_loot(step):return
	# Give scheduled deliveries and opened chest bursts time to resolve.
	for chest in main.chests_root.get_children():
		if chest is Chest and (not chest._landed or chest._opening):return
	for delivery in main.special_rooms.state.get("deliveries",[]):
		if not bool(delivery.delivered):return
	_go_to_next_room()

func _combat(target:EnemyBase)->void:
	var actor:RoomPlayer=main.player;var offset:=target.global_position-actor.global_position;var distance:=offset.length()
	actor.aim_direction=offset.normalized()
	var dodge:=Vector2.ZERO
	for bullet in get_tree().get_nodes_in_group("room_projectiles"):
		if not bullet is Projectile or bullet.is_friendly or bullet.is_queued_for_deletion():continue
		if actor.global_position.distance_squared_to(bullet.global_position)<80*80:dodge+=(actor.global_position-bullet.global_position).normalized()
	var goal:=target.global_position
	var clear_shot:bool=main.level.projectile_clear(actor.global_position,target.global_position)
	if not dodge.is_zero_approx():goal=actor.global_position+dodge.normalized()*100
	elif distance<125 and clear_shot:goal=actor.global_position-offset.normalized()*100+offset.orthogonal().normalized()*50
	elif distance<235 and clear_shot:goal=actor.global_position+offset.orthogonal().normalized()*50
	actor.movement_override=main.level.path_direction(actor.global_position,main.level.nearest_clear(goal,12),12,false)
	if (not dodge.is_zero_approx() or distance<65 or _stuck>2) and actor._dash_cd<=0:
		var direction:=actor.movement_override
		if direction.is_zero_approx():direction=-offset.normalized()
		actor.request_dash_direction(direction);_stuck=0
	if actor.hp<actor.max_hp*.5:_use_potion("heal")
	if GameState.mp<GameState.MAX_MP*.25:_use_potion("mana")
	for slot in [3,0,1,2]:
		if GameState.skill_ready(slot) and actor.caster.cast(slot):break

func _use_potion(kind:String)->void:
	for item in GameState.items.duplicate():
		if ItemDB.is_usable(item) and str(item.get("effect",{}).get("kind",""))==kind:
			GameState.use_item(item);return

func _collect_room_loot(delta:float)->bool:
	var actor:RoomPlayer=main.player;var target:Node2D;var best:=INF
	for parent in [main.chests_root,main.fx_root]:
		for node in parent.get_children():
			if not node is Node2D or node.is_queued_for_deletion() or _ignored.has(node.get_instance_id()):continue
			var eligible:bool=node is Chest and not node.is_open and node._landed and GameState.keys>=node.required_keys()
			eligible=eligible or node is RoomLootDrop and not node._collected or node is Coin and not node._collected
			if not eligible:continue
			var distance:=actor.global_position.distance_squared_to(node.global_position)
			if distance<best:best=distance;target=node
	if target==null:_loot_target=null;_loot_seconds=0;return false
	if _loot_target==null or _loot_target.get_ref()!=target:_loot_target=weakref(target);_loot_seconds=0
	_loot_seconds+=delta
	if _loot_seconds>8:_ignored[target.get_instance_id()]=true;_loot_target=null;return true
	if target is Chest and target.in_range:target.try_interact();return true
	actor.movement_override=main.level.path_direction(actor.global_position,main.level.nearest_clear(target.global_position,12),12,false)
	return true

func _go_to_next_room()->void:
	var graph:RoomGraph=main.graph
	var pending:Array=[{"id":graph.current,"first":""}];var seen:Dictionary={graph.current:true};var destination:=""
	var index:=0
	while index<pending.size():
		var entry:Dictionary=pending[index];index+=1
		if entry.id!=graph.current and not bool(graph.rooms.get(entry.id,{}).get("visited",true)):destination=str(entry.first);break
		for id in graph.rooms.get(entry.id,{}).get("doors",[]):
			if not graph.rooms.has(id) or seen.has(id):continue
			seen[id]=true;pending.append({"id":id,"first":id if entry.id==graph.current else entry.first})
	if destination.is_empty():return
	var direction:=RoomGraph.cell(destination)-RoomGraph.cell(graph.current)
	var point:Vector2=main.level.door_point(direction,0)
	var approach:=point-Vector2(direction)*30
	var actor:RoomPlayer=main.player
	actor.movement_override=(point-actor.global_position).normalized() if actor.global_position.distance_to(approach)<42 else main.level.path_direction(actor.global_position,approach,12,false)
	if _stuck>3:actor.movement_override=main.level.path_direction(actor.global_position,main.level.nearest_clear(approach,12),12,false)

func _advance_screen()->void:
	if main.choice_ui.is_open() and UIFlow.is_top(main.choice_ui):
		var best:=-INF;var selected:=0
		for index in main.choice_ui.offers.size():
			var item:Dictionary=main.choice_ui.offers[index];var score:=20.0+int(item.get("rarity",0))*10
			if ItemDB.is_equippable(item):score=_equipment_score(item)
			if score>best:best=score;selected=index
		main.choice_ui._choose_from_input(selected,main.choice_ui._selection_epoch,true)
	elif main.dialogue.is_open() and UIFlow.is_top(main.dialogue):
		if main.dialogue._choosing:
			var options:Array=main.dialogue._choice_box.get_children();var button:Button
			for candidate in options:
				if candidate is Button and candidate.visible and not candidate.disabled:
					if button==null:button=candidate
					if candidate.text.contains("继续") or candidate.text.contains("深入"):button=candidate;break
			if button!=null:button.pressed.emit()
		else:main.dialogue._advance()
	elif is_instance_valid(main.expansion.panel) and UIFlow.is_top(main.expansion.panel):
		var panel:RoomEventUI=main.expansion.panel
		if int(main.expansion.state.dialogue)<2:panel._advance()
		else:panel._claim(0)

func _equipment_score(item:Dictionary)->float:
	if not ItemDB.can_equip(item):return -1000
	var stats:=GameState.preview_with(item)
	var delta:=(stats.get_value(&"attack")-GameState.stats.get_value(&"attack"))*2+(stats.get_value(&"max_hp")-GameState.stats.get_value(&"max_hp"))*.15+(stats.get_value(&"attack_speed")-GameState.stats.get_value(&"attack_speed"))*35+(stats.get_value(&"mp_regen")-GameState.stats.get_value(&"mp_regen"))*8
	return delta+int(item.get("rarity",0))*3+5
func _equip_upgrades()->void:
	for slot in ItemDB.SLOTS:
		var best:Dictionary=GameState.equipped(slot);var score:=_equipment_score(best) if not best.is_empty() else 0.0
		var seen:Dictionary={}
		for item in GameState.items:
			if ItemDB.slot_of(item)!=slot or not ItemDB.can_equip(item):continue
			var id:=str(item.get("id",""))
			if seen.has(id):continue
			seen[id]=true
			var value:=_equipment_score(item)
			if value>score+.1:best=item;score=value
		if not best.is_empty() and not GameState.is_equipped(best):GameState.equip(best)

func _exit_tree()->void:_clear_controls()
