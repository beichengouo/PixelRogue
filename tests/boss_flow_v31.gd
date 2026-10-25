extends "res://tests/boss_flow_base_v31.gd"
var boss_samples:Array=[]
var live:Dictionary={}
var _watched:RoomBoss
func save_boss_checkpoint(room:Node,destination:String,direction:Vector2i)->void:
	var key:="%s-%s-%d"%[hero,chapter,room.graph.stage_index]
	var path:=OUTPUT_ROOT+"checkpoints/"+key+".json"
	if FileAccess.file_exists(path):return
	var snapshot:=GameState.snapshot();snapshot.world_state=room.expedition.snapshot()
	var payload:={"hero":str(hero),"chapter":str(chapter),"stage":room.graph.stage_index,"seed":seed_value,"difficulty":challenge,"snapshot":snapshot,"save_data":SaveService.data.duplicate(true),"outpost":Outpost.data.duplicate(true),"destination":destination,"direction":[direction.x,direction.y],"level":GameState.level,"natural_campaign":true,"assisted_source":bot_assist}
	payload["navigation_assistance"]=bool(get_meta("navigation_assistance",false))
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(payload));file.close()
	print("V31_CHECKPOINT ",key," level=",GameState.level)
func _process(dt:float)->void:
	super._process(dt)
	if not started or not is_instance_valid(main):return
	var boss:=main.director.boss as RoomBoss
	if is_instance_valid(boss) and boss!=_watched:
		_watched=boss;live={"id":str(boss.boss_id),"stage":main.graph.stage_index,"strength":main.director.strength,"hero_level":GameState.level,"max_hp":boss.max_hp,"attack":boss.damage,"combat_seconds":0.0,"damage_to_player":0.0,"hits_to_player":0,"phases":{},"gear":GameState.equipment.duplicate(true)}
		boss.died.connect(func(_unit:EnemyBase,_source:Node,_type:StringName)->void:
			live["outcome"]="boss_defeated";boss_samples.append(live.duplicate(true));print("V31_FLOW_BOSS ",JSON.stringify(live));live={})
	if not live.is_empty() and not get_tree().paused and main.director.phase==WaveDirector.Phase.FIGHT:
		live.combat_seconds+=dt
		if is_instance_valid(boss):live.phases[str(boss.phase)]=true
func _ready()->void:
	EventBus.player_damaged.connect(func(amount:float,_hp:float,_max:float)->void:
		if not live.is_empty():live.damage_to_player+=amount;live.hits_to_player+=1)
	super._ready()
func state()->Dictionary:
	var data:=super.state();data["boss_samples"]=boss_samples.duplicate(true);data["current_boss"]=live.duplicate(true);return data
