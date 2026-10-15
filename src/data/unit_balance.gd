class_name UnitBalance
extends RefCounted
## Authoring overrides contain base values only. Difficulty, growth and gear
## are still applied by their original systems after these values are read.
const PATH:="res://data/unit_balance.json"
static var _units:Dictionary={}
static var _loaded:=false
static func reload()->void:
	_loaded=true;_units={}
	if not FileAccess.file_exists(PATH):return
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if value is Dictionary and value.get("units") is Dictionary:_units=value.units.duplicate(true)
static func value(id:String,stat:String,fallback:float)->float:
	if not _loaded:reload()
	var entry:Variant=_units.get(id,{})
	if not entry is Dictionary:return fallback
	var number:Variant=entry.get(stat,fallback)
	return float(number) if (number is float or number is int) and is_finite(float(number)) else fallback
static func player_base(stat:StringName,fallback:float)->float:
	return value("hero:"+str(Characters.current_id()),str(stat),fallback)
static func apply_enemy(enemy:EnemyBase)->void:
	var id:="boss:"+str(enemy.boss_id) if enemy is BossBase else "enemy:"+str(enemy.kind)
	enemy.base_hp=value(id,"hp",enemy.base_hp);enemy.base_damage=value(id,"attack",enemy.base_damage)
	enemy.base_speed=value(id,"speed",enemy.base_speed);enemy.base_coins=roundi(value(id,"coins",enemy.base_coins))
static func snapshot()->Dictionary:
	if not _loaded:reload()
	return _units.duplicate(true)
static func save(units:Dictionary)->Error:
	var known:Dictionary={}
	for entry in catalog():known[entry.id]=entry.stats
	for id in units:
		if not known.has(id) or not units[id] is Dictionary:return ERR_INVALID_DATA
		for stat in units[id]:
			var number:Variant=units[id][stat]
			if not known[id].has(stat) or not (number is int or number is float) or not is_finite(float(number)) or float(number)<0 or float(number)>10000000:return ERR_INVALID_DATA
	var pending:=PATH+".writing";var file:=FileAccess.open(pending,FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version":1,"units":units},"\t"));file.flush();var error:=file.get_error();file.close()
	if error!=OK:return error
	error=DirAccess.rename_absolute(ProjectSettings.globalize_path(pending),ProjectSettings.globalize_path(PATH))
	if error==OK:reload()
	return error
static func catalog()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for id in Characters.DATA:
		var stats:Dictionary={}
		for stat in GameState.BASE_STATS:stats[str(stat)]=float(GameState.BASE_STATS[stat])
		result.append({"id":"hero:"+str(id),"name":"角色 · "+str(Characters.DATA[id].name),"stats":stats})
	var kinds:Array=[&"walker",&"flyer",&"charger",&"caster",&"bomber",&"guard",&"treant"]
	kinds.append_array(EnemyCombatPolicy.NEW_KINDS)
	for kind in kinds:
		var probe:=WaveDirector.create_enemy(kind)
		result.append({"id":"enemy:"+str(kind),"name":"怪物 · "+probe.display_name,"stats":{"hp":probe.base_hp,"attack":probe.base_damage,"speed":probe.base_speed,"coins":probe.base_coins}});probe.free()
	for id in BossRoster.DATA:
		var data:Dictionary=BossRoster.DATA[id]
		result.append({"id":"boss:"+str(id),"name":"首领 · "+str(data.title),"stats":{"hp":data.hp,"attack":data.damage,"speed":data.speed,"coins":data.coins}})
	for index in HireOffers.MERC_NAMES.size():result.append({"id":"merc:"+str(index),"name":"雇佣 · "+str(HireOffers.MERC_NAMES[index]),"stats":{"hp":95.0,"attack":15.0,"speed":118.0}})
	for kind in kinds:
		var probe:=WaveDirector.create_enemy(kind)
		result.append({"id":"ally:"+str(kind),"name":"友方怪物 · "+probe.display_name,"stats":{"hp":probe.base_hp*1.15,"attack":probe.base_damage*.8,"speed":maxf(70,probe.base_speed)}});probe.free()
	for id in ["skeleton","lantern","tree","guardian","procession"]:result.append({"id":"summon:"+id,"name":"召唤物 · "+{"skeleton":"近战骸灵","lantern":"远程幽灯","tree":"树灵守望者","guardian":"骸甲守卫","procession":"百灵夜行守卫"}[id],"stats":{"hp_multiplier":1.0,"attack_multiplier":1.0,"speed_multiplier":1.0}})
	return result
