extends "res://tests/boss_campaign_base_v30.gd"
## Extra observations use real hit signals; never alter a combat result.
var rooms:Array=[]
var hurt_events:Array=[]
var dealt:Dictionary={}
var mana_low_seconds:=0.0
var _room_key:=""
var _room_started:=0.0
var _rage_max:=0
var _last_boss_count:=0
var species_spawned:Dictionary={}
var room_species:Dictionary={}

func _ready()->void:
	EventBus.enemy_spawned.connect(_watch_enemy)
	EventBus.player_damaged.connect(_watch_hurt)
	super._ready()

func _watch_enemy(unit:Node)->void:
	if unit is EnemyBase:
		species_spawned[str(unit.kind)]=int(species_spawned.get(str(unit.kind),0))+1
		var key:=str(main.graph.current) if is_instance_valid(main) else "setup"
		var values:Dictionary=room_species.get(key,{});values[str(unit.kind)]=int(values.get(str(unit.kind),0))+1;room_species[key]=values
		unit.damage_applied.connect(_watch_damage)

func _watch_damage(_enemy:EnemyBase,amount:float,_source:Node,kind:StringName)->void:
	dealt[str(kind)]=float(dealt.get(str(kind),0))+amount

func _watch_hurt(amount:float,hp:float,_max_hp:float)->void:
	if not started:return
	hurt_events.append({"at":seconds,"room":main.graph.current,"stage":main.graph.stage_index,"amount":amount,"hp":hp,"max_hp":_max_hp,"scars":main.player.permanent_hp_loss(),"rage":main.director.room_pressure_step,"enemies":main.director._living_enemy_count(),"ui":UIFlow.has_screen(),"paused":get_tree().paused})

func _process(dt:float)->void:
	super._process(dt)
	if not started or not is_instance_valid(main):return
	var key:=str(main.graph.current)
	if key!=_room_key:
		if not _room_key.is_empty():rooms.append({"room":_room_key,"seconds":seconds-_room_started,"rage":_rage_max})
		_room_key=key;_room_started=seconds;_rage_max=0
	_rage_max=maxi(_rage_max,main.director.room_pressure_step)
	if not get_tree().paused and not TransitionLayer.busy and GameState.mp<10:mana_low_seconds+=dt

func state()->Dictionary:
	var result:=super.state()
	result.merge({"damage_by_kind":dealt.duplicate(true),"mana_low_seconds":mana_low_seconds,"rage":main.director.room_pressure_step,"species_spawned":species_spawned.duplicate(true),"room_species":room_species.duplicate(true)})
	var potions:Dictionary={}
	for item in GameState.items:
		if ItemDB.is_usable(item):potions[str(item.id)]=int(potions.get(str(item.id),0))+1
	result.merge({"potions":potions,"scars":main.player.permanent_hp_loss(),"full_hp":main.player.stats.get_value(&"max_hp"),"mp_regen":GameState.total_mp_regen(main.player.stats)})
	if not started:result.merge({"rooms":rooms.duplicate(true),"hurt_events":hurt_events.duplicate(true)})
	return result
