class_name DepartureLevels
extends RefCounted
const MAXIMUM := 10
static func valid(value:int)->bool:return value>=1 and value<=MAXIMUM
static func cost(value:int)->int:
	var levels:=clampi(value,1,MAXIMUM)-1
	return 25*levels*(levels+1)
static func apply(value:int)->void:
	GameState.level=clampi(value,1,MAXIMUM)
	GameState.exp=0.0
	GameState.talent_points=1+int(GameState.level/3)
	for id in Skills.order_for():
		if Skills.unlock_level(id)<=GameState.level and not GameState.unlocked_skills.has(id):GameState.unlocked_skills.append(id)
	GameState._reset_stats()
	EventBus.level_changed.emit(GameState.level,0)
	EventBus.player_stats_changed.emit()
	EventBus.skills_changed.emit()
	EventBus.talents_changed.emit()
