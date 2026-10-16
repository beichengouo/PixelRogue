class_name FateService
extends RefCounted
## Every mutation commits once and rolls back on a failed disk write.
static var save_override:Callable
static func record()->Dictionary:
	var runtime:Node=GameState.runtime_node
	if not is_instance_valid(runtime) or not runtime is RoomRuntime:return {}
	var main:Node=runtime.main
	return main.graph.rooms.get(main.graph.current,{})
static func eligible(room:Dictionary)->bool:
	return FateCatalog.active() and room.get("kind","")=="altar" and bool(room.get("cleared",false)) and bool(room.get("rewarded",false))
static func _save()->bool:
	return bool(save_override.call()) if save_override.is_valid() else SaveService.save_run(GameState.snapshot())
static func _finish(room:Dictionary,old_state:Dictionary,old_delta:Dictionary)->bool:
	if not _save():
		GameState.fate=old_state;room.delta=old_delta
		return false
	GameState._reset_stats();EventBus.player_stats_changed.emit()
	return true
static func orientation(room:Dictionary)->bool:
	# Existing candidates keep their saved orientation; unopened altars use only
	# the room seed, never the gameplay random stream or the current UI selection.
	var reading:Dictionary=room.get("delta",{}).get("fate_reading",{})
	return bool(reading.get("reverse",posmod(int(room.get("seed",0)),2)==1))
static func draw(room:Dictionary)->Dictionary:
	if not eligible(room):return {"error":"请先领取本祭坛的原有誓约。"}
	if room.delta.has("fate_reading"):return room.delta.fate_reading
	if int(GameState.fate.get("readings",0))>=3:return {"error":"本次出征已完成三次占卜。"}
	var before:=GameState.fate.duplicate(true);var delta_before:Dictionary=room.delta.duplicate(true)
	var pool:Array=FateCatalog.IDS.duplicate()
	for card in GameState.fate.cards:pool.erase(str(card.id))
	var rng:=RandomNumberGenerator.new();rng.seed=int(room.get("seed",0))^0x5f74ab
	var offers:Array=[]
	while offers.size()<3 and not pool.is_empty():offers.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))
	room.delta.fate_reading={"offers":offers,"done":false,"reverse":orientation(room)}
	GameState.fate.readings=int(GameState.fate.readings)+1
	if not _finish(room,before,delta_before):return {"error":"保存失败，占卜尚未开始，请重试。"}
	return room.delta.fate_reading
static func claim(room:Dictionary,id:String,reverse:bool,replace_id:="")->bool:
	if not eligible(room):return false
	var reading:Dictionary=room.delta.get("fate_reading",{})
	if bool(reading.get("done",true)) or not id in reading.get("offers",[]):return false
	for card in GameState.fate.cards:
		if str(card.id)==id:return false
	if reverse!=orientation(room):return false
	var before:=GameState.fate.duplicate(true);var delta_before:Dictionary=room.delta.duplicate(true)
	GameState.fate.cards.append({"id":id,"reverse":reverse});reading.done=true
	var evidence:=AchievementTracker.stage("fate_claim",{"id":id,"reverse":reverse,"replace":false})
	var success:=_finish(room,before,delta_before);AchievementTracker.finish_stage(evidence,success)
	return success
static func _remove(id:String)->void:
	for i in range(GameState.fate.cards.size()-1,-1,-1):
		if str(GameState.fate.cards[i].id)==id:GameState.fate.cards.remove_at(i)
	GameState.fate.pending.erase(id)
	if id=="priestess":GameState.fate.still=0.0
static func discard(room:Dictionary,id:String)->bool:
	if not eligible(room):return false
	var owned:=false
	for card in GameState.fate.cards:
		if str(card.id)==id:owned=true
	if not owned:return false
	var before:=GameState.fate.duplicate(true);var delta_before:Dictionary=room.delta.duplicate(true)
	_remove(id)
	return _finish(room,before,delta_before)
static func pass_reading(room:Dictionary)->bool:
	if not eligible(room):return false
	var reading:Dictionary=room.delta.get("fate_reading",{})
	if reading.is_empty() or bool(reading.get("done",false)):return false
	var before:=GameState.fate.duplicate(true);var delta_before:Dictionary=room.delta.duplicate(true)
	reading.done=true
	var evidence:=AchievementTracker.stage("fate_pass")
	var success:=_finish(room,before,delta_before);AchievementTracker.finish_stage(evidence,success)
	return success
