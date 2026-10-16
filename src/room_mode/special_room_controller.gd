class_name SpecialRoomController
extends Node
## Each room owns its timers, hidden lottery answer, paid uses and deliveries.
var main
var state:Dictionary={}
var record:Dictionary={}
var panel:SpecialMachineUI
var validation_mode:=false
var _marks:Dictionary={}
var shadow:RoomShadowChaser
const MACHINES:=["machine_wheel","machine_lottery","machine_reserved"]
const TITLES:={"machine_wheel":"星运转盘","machine_lottery":"八星彩票","machine_reserved":"沉睡的星匣"}
const REWARD_CHEST_WEIGHTS:=[512,256,128,64,32,16,8,4,2,1]
static func is_shadow_room(value:Dictionary)->bool:
	return str(value.get("kind",""))=="game" and str(value.get("terrain_layout",{}).get("scene_art",""))=="normal_windbridge_v01"
func configure(room_record:Dictionary)->void:
	if is_instance_valid(shadow):shadow.queue_free()
	shadow=null
	for marker in _marks.values():
		if is_instance_valid(marker):marker.queue_free()
	_marks.clear()
	if is_instance_valid(panel):panel.close()
	record=room_record;state={}
	if record.kind not in ["reward","game","elite","trial"]:return
	if not record.delta.has("special"):
		var rng:=RandomNumberGenerator.new();rng.seed=int(record.seed)^0x6348a
		var answer:=""
		for index in 8:answer+=str(rng.randi_range(0,9))
		record.delta.special={"clock":0.0,"deliveries":[],"pending_prizes":[],"used":{},"answer":answer,"rng":str(rng.state),"reward_started":false}
	state=record.delta.special
	if is_shadow_room(record):
		if not state.has("chase"):state.chase={"prepare":5.0,"remaining":30.0,"contact":0.0,"at":[],"done":false}
		record.cleared=bool(state.chase.done);record.rewarded=bool(state.chase.done)
		main.level.doors_open=bool(state.chase.done)
		if not bool(state.chase.done) and float(state.chase.prepare)<=0:_spawn_shadow()
	if record.kind=="reward" and not state.reward_started:
		state.reward_started=true;var rng:=_rng();schedule_chests(reward_chest_count(rng),true,rng);state.rng=str(rng.state)
static func reward_chest_count(rng:RandomNumberGenerator)->int:
	var roll:=rng.randi_range(1,1023)
	for index in REWARD_CHEST_WEIGHTS.size():
		roll-=REWARD_CHEST_WEIGHTS[index]
		if roll<=0:return index+1
	return 10
func _rng()->RandomNumberGenerator:
	var rng:=RandomNumberGenerator.new();rng.state=int(state.get("rng","1"));return rng
func _visible_and_ready()->bool:
	return is_instance_valid(main.player) and main.player.hp>0 and not TransitionLayer.busy and not get_tree().paused and not UIFlow.has_screen() and not bool(main.get("_navigation_pending")) and not bool(main.get("_room_transfer"))
func _process(dt:float)->void:
	if state.is_empty() or not (GameState.run_active or validation_mode) or not _visible_and_ready():return
	if is_shadow_room(record):
		if main.player.extraction_controls_locked():
			if is_instance_valid(shadow):shadow.hide()
			return
		_advance_chase(maxf(0,dt))
	state.clock=float(state.clock)+maxf(0,dt)
	_update_amber_marks()
	if record.kind in ["elite","trial"] and record.cleared and not state.reward_started:
		state.reward_started=true;var rng:=_rng();schedule_chests(1 if record.kind=="trial" else rng.randi_range(1,3),true,rng);state.rng=str(rng.state);_checkpoint()
	for delivery in state.deliveries.duplicate():
		if bool(delivery.get("delivered",false)) or float(delivery.due)>float(state.clock):continue
		var point:=_delivery_point(delivery)
		if not point.is_finite():continue
		var chest:=RoomChest.new();chest.setup(main.level,main.player);chest.position=point;chest.free_opening=bool(delivery.free);chest.luxury=bool(delivery.free);chest.begin_delivery()
		chest.delivery_id=state.deliveries.find(delivery)
		main.chests_root.add_child(chest);delivery.delivered=true;_checkpoint()
		# At most one new delivery per frame; authored due times stagger the rest.
		break
	for prize in state.pending_prizes.duplicate():
		if not is_instance_valid(main.get("expedition")):break
		main.expedition.loot.burst_reward(prize.loot,Vector2(prize.at[0],prize.at[1]));state.pending_prizes.erase(prize);_checkpoint()

func chase_running()->bool:
	return not state.is_empty() and is_shadow_room(record) and state.has("chase") and not bool(state.chase.done) and float(state.chase.prepare)<=0 and (GameState.run_active or validation_mode) and _visible_and_ready() and not main.player.extraction_controls_locked()

func _advance_chase(dt:float)->void:
	var chase:Dictionary=state.chase
	if bool(chase.done):return
	if float(chase.prepare)>0:
		var elapsed:=minf(dt,float(chase.prepare));chase.prepare=maxf(0,float(chase.prepare)-elapsed);dt-=elapsed
		if float(chase.prepare)>0:return
		_spawn_shadow();_checkpoint()
	if not is_instance_valid(shadow):_spawn_shadow()
	if is_instance_valid(shadow):shadow.show()
	chase.remaining=maxf(0,float(chase.remaining)-dt)
	if float(chase.remaining)>0:return
	chase.done=true;record.cleared=true;record.rewarded=true
	if is_instance_valid(shadow):shadow.dissolve()
	shadow=null;main.level.doors_open=true;main.level.sync_door_links(record)
	if not bool(state.reward_started):
		state.reward_started=true;var rng:=_rng();schedule_chests(rng.randi_range(1,3),true,rng);state.rng=str(rng.state)
	main.hud.show_banner("追影消散 · 风铃为你送来星赐宝箱",3)
	_checkpoint()

func _spawn_shadow()->void:
	if is_instance_valid(shadow) or not is_instance_valid(main.player):return
	var chase:Dictionary=state.chase
	var at:=Vector2.INF
	var stored:Array=chase.get("at",[])
	if stored.size()==2:at=main.level.nearest_clear(Vector2(stored[0],stored[1]),RoomShadowChaser.BODY_RADIUS)
	if not at.is_finite():
		var bounds:Rect2=main.level.bounds().grow(-45)
		var away:Vector2=bounds.get_center()+(bounds.get_center()-main.player.position).normalized()*bounds.size.length()*.4
		at=main.level.scene_navigation.main_spawn_point(main.level,away,main.player.position,RoomShadowChaser.BODY_RADIUS,false)
	shadow=RoomShadowChaser.new();shadow.controller=self;shadow.room=main.level;shadow.position=at
	# Kept outside snapshot entity roots; the room delta stores its exact state.
	add_child(shadow);chase.at=[at.x,at.y]
func _checkpoint()->void:
	if not validation_mode:Outpost.request_checkpoint()
func schedule_chests(count:int,free:bool,rng:RandomNumberGenerator)->void:
	var occupied:Array[Vector2]=[]
	for prior in state.deliveries:occupied.append(Vector2(prior.at[0],prior.at[1]))
	var due:=float(state.clock)+2.5
	for index in count:
		var point:=Vector2.INF
		if str(record.get("terrain_layout",{}).get("scene_art",""))=="reward_glowcave_v01":
			var effects:Dictionary=record.terrain_layout.get("scene_effects",{})
			var lane:Array=effects.get("lane_left" if index%2==0 else "lane_right",[])
			for offset in lane.size():
				var pair:Array=lane[(int(index/2)+offset)%lane.size()];var candidate:=Vector2(pair[0],pair[1])
				if candidate.distance_to(main.player.position)>=72 and not occupied.any(func(other:Vector2)->bool:return other.distance_to(candidate)<70) and RoomExpansionRules.safe_point(main.level,candidate,14):point=candidate;break
		for attempt in 180:
			if point.is_finite():break
			var bounds:Rect2=main.level.bounds().grow(-60)
			var candidate:=Vector2(rng.randf_range(bounds.position.x,bounds.end.x),rng.randf_range(bounds.position.y,bounds.end.y))
			if candidate.distance_to(main.player.position)<72 or occupied.any(func(other:Vector2)->bool:return other.distance_to(candidate)<70):continue
			if main.level.door_at(candidate)!=Vector2i.ZERO or not main.level.scene_navigation.spawn_reachable(main.level,candidate,14,false):continue
			point=candidate;break
		if not point.is_finite():continue
		occupied.append(point);state.deliveries.append({"at":[point.x,point.y],"due":due,"free":free,"delivered":false});due+=rng.randf_range(.65,1.10)

func _delivery_point(delivery:Dictionary)->Vector2:
	var stored:=Vector2(float(delivery.at[0]),float(delivery.at[1]))
	var point:Vector2=main.level.nearest_clear(stored,14)
	if not main.level.scene_navigation.spawn_reachable(main.level,point,14,false):return Vector2.INF
	if not point.is_equal_approx(stored):
		delivery.at=[point.x,point.y];_checkpoint()
	return point

func _update_amber_marks()->void:
	if str(record.get("terrain_layout",{}).get("scene_art",""))!="reward_amber_v01":return
	for index in state.deliveries.size():
		var delivery:Dictionary=state.deliveries[index]
		var needed:=not bool(delivery.delivered) and float(delivery.due)-float(state.clock)<=1
		var landing:=Vector2.INF
		if delivery.delivered:
			for chest in main.chests_root.get_children():
				if chest is RoomChest and chest.delivery_id==index and not chest._landed:
					needed=true;landing=chest.landing_position();break
		elif needed:
			var point:=_delivery_point(delivery)
			if point.is_finite():landing=main.chests_root.to_global(point+Chest.GROUND_OFFSET)
		needed=needed and landing.is_finite()
		if _marks.has(index) and (not is_instance_valid(_marks[index]) or _marks[index].is_queued_for_deletion() or not _marks[index].is_inside_tree()):_marks.erase(index)
		if needed:
			if not _marks.has(index):
				var marker:=RoomDropMark.new();main.fx_root.add_child(marker);_marks[index]=marker
			_marks[index].global_position=landing
		elif _marks.has(index):
			_marks[index].queue_free();_marks.erase(index)
static func lottery_matches(guess:String,answer:String)->int:
	if guess.length()!=8 or answer.length()!=8:return -1
	var count:=0
	for index in 8:
		if not guess.substr(index,1).is_valid_int():return -1
		if guess[index]==answer[index]:count+=1
	return count
static func lottery_payout(stake:int,matches:int)->int:return int(stake*maxi(0,matches)/2.0)
func machine_distance(id:String)->float:
	var polygon:PackedVector2Array=main.level.scene_polygons.get(id,PackedVector2Array())
	if polygon.size()<3:return INF
	var from:Vector2=main.player.position
	var boundary:=RoomSceneGeometry.closest_boundary_point(from,polygon)
	return from.distance_to(boundary) if main.level.sight(from,boundary.move_toward(from,1)) else INF
func nearest_machine()->String:
	if record.get("kind","")!="game" or is_shadow_room(record):return ""
	var best:=82.0;var found:=""
	for id in MACHINES:
		var distance:=machine_distance(id)
		if distance<best:best=distance;found=id
	return found
func _unhandled_input(event:InputEvent)->void:
	if not event.is_action_pressed("interact") or event.is_echo() or state.is_empty() or not _visible_and_ready():return
	# A falling wheel prize must remain openable beside the machine.
	for node in get_tree().get_nodes_in_group("chests"):
		if node is Chest and node.in_range and node._landed and not node.is_open:return
	var id:=nearest_machine()
	if id.is_empty():return
	panel=SpecialMachineUI.new();panel.controller=self;panel.machine=id;add_child(panel);get_viewport().set_input_as_handled()
func play(id:String,stake:int=0,guess:String="")->Dictionary:
	if state.is_empty() or record.kind!="game" or is_shadow_room(record) or id not in MACHINES:return {"error":"装置不在当前房间。"}
	if id=="machine_lottery" and guess=="beicheng":return _gm_easter_egg()
	if bool(state.used.get(id,false)):return {"error":"这台装置在本房间已使用。"}
	if machine_distance(id)>90:return {"error":"请靠近装置。"}
	if id=="machine_reserved":return {"error":"星匣尚未苏醒，暂无游戏。"}
	if id=="machine_wheel":stake=500
	elif stake<50 or stake>100000000:return {"error":"彩票投入至少50金币。"}
	var matches:=lottery_matches(guess,str(state.answer)) if id=="machine_lottery" else 0
	if matches<0:return {"error":"请输入完整的八位数字，可保留开头的0。"}
	if stake>GameState.coins:return {"error":"随身金币不足。"}
	var before:=state.duplicate(true);var old_coins:=GameState.coins
	var rng:=_rng();var result:={"error":"","message":"","payout":0}
	GameState.spend_coins(stake);state.used[id]=true
	if id=="machine_lottery":
		var payout:=lottery_payout(stake,matches);GameState.add_coins(payout);result.payout=payout
		result.message="你的号码：%s\n揭晓号码：%s\n按位置猜中%d位 · 获得%d金币（投入%d）"%[guess,state.answer,matches,payout,stake]
	else:
		var outcome:=rng.randi_range(0,4);result.outcome=outcome
		match outcome:
			0:
				var pool:Array[Dictionary]=[]
				for item in ItemDB.all():
					if int(item.get("rarity",0))==3 and ItemDB.slot_of(item)==&"weapon" and ItemDB.in_source(item,&"chest"):pool.append(item)
				var weapon:=LootSelection.pick(pool,[0,0,0,1],rng)
				if weapon.is_empty():GameState.add_coins(1000);result.message="暂无适用的传说武器，获得1000金币补偿。"
				else:
					var point:Vector2=main.level.nearest_clear(main.player.position+Vector2(0,40),8)
					state.pending_prizes.append({"loot":{"kind":"gear","item":weapon},"at":[point.x,point.y]});result.message="获得传说武器："+str(weapon.name);result.weapon=weapon
			1:GameState.add_coins(1000);result.message="金币翻倍 · 获得1000金币！";result.payout=1000
			2:schedule_chests(3,false,rng);result.message="三只宝箱即将天降。"
			3:
				GameState.add_coins(500);result.payout=500
				result.message="获得500金币！"
			4:result.message="谢谢惠顾，本次没有奖励。"
	state.rng=str(rng.state)
	if not validation_mode and not SaveService.save_run(GameState.snapshot()):
		record.delta.special=before;state=record.delta.special;GameState.coins=old_coins
		EventBus.coins_changed.emit(old_coins)
		return {"error":"保存失败，金币与装置次数已退回，请重试。"}
	return result

func _gm_easter_egg()->Dictionary:
	if machine_distance("machine_lottery")>90:return {"error":"请靠近装置。"}
	if GameState.gm_pilot_used:return {"error":"本次旅途的 GM 已经回应过了。"}
	if not is_instance_valid(main.gm_pilot) or not main.gm_pilot.activate():return {"error":"现在无法接管角色。"}
	var was_used:bool=bool(state.used.get("machine_lottery",false));state.used.machine_lottery=true
	if not validation_mode and not SaveService.save_run(GameState.snapshot()):
		state.used.machine_lottery=was_used;GameState.gm_pilot_used=false;GameState.gm_pilot_active=false
		return {"error":"保存失败，彩蛋未触发，可以重试。"}
	return {"error":"","gm":true,"message":"GM正在操作你的角色"}
