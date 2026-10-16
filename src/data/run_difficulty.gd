class_name RunDifficulty
extends RefCounted
## One expedition setting owns combat and reward scaling. Legacy danger
## fields are read only when a saved record has no difficulty field.
const OPTIONS := [{"id":1,"name":"普通"},{"id":2,"name":"危险"},{"id":3,"name":"绝境"},{"id":4,"name":"浴血"}]
static func valid(value:int)->bool:return value>=1 and value<=4
static func multiplier(value:int)->int:return clampi(value,1,3)
static func gold_multiplier(value:int)->int:return 5 if value==4 else multiplier(value)
static func is_bloodbath(value:int)->bool:return value==4
static func from_legacy_danger(value:int)->int:return clampi(value+1,1,3)
static func from_record(record:Dictionary)->int:
	if record.has("difficulty"):return clampi(int(record.difficulty),1,4)
	return from_legacy_danger(int(record.get("danger",0)))
static func spawn_multiplier(value:int)->float:return [1.0,1.5,2.0][multiplier(value)-1]
static func spawn_count(count:int,value:int)->int:return ceili(maxi(0,count)*spawn_multiplier(value))
static func material_value_multiplier(value:int)->float:return [1.0,1.20,1.40][multiplier(value)-1]
static func title(value:int)->String:return str(OPTIONS[clampi(value,1,4)-1].name)
static func description(value:int)->String:
	var times:=multiplier(value)
	return "%s · 刷怪 ×%s · 生命/攻击 ×%d · 金币奖励 ×%d%s"%[title(value),str(spawn_multiplier(value)),times,gold_multiplier(value)," · 真实伤害留下灰色伤痕；普通回血无效，部分命运牌可修复" if is_bloodbath(value) else ""]
static func affix_chance(base:float,value:int)->float:
	return 1.0-pow(1.0-clampf(base,0,1),multiplier(value))
static func encounter(base:Dictionary,value:int)->Dictionary:
	var plan:=base.duplicate(true);var times:=multiplier(value)
	for attribute in ["hp_scale","damage_scale"]:
		plan[attribute]=float(plan.get(attribute,1.0))*times
	if bool(plan.get("boss",false)):
		plan.total=1
		plan.boss_hp_scale=float(plan.get("boss_hp_scale",1))*times
	else:
		# Largest remainders preserve the composition and exact rounded room total.
		var target:=spawn_count(int(plan.get("total",0)),value)
		var assigned:=0;var remainders:Array[float]=[]
		for kind in WaveTable.KINDS:
			var share:=int(plan.get(kind,0))*spawn_multiplier(value)
			plan[kind]=floori(share);assigned+=int(plan[kind])
			remainders.append(share-floorf(share))
		while assigned<target:
			var best:=remainders.find(remainders.max())
			plan[WaveTable.KINDS[best]]+=1;assigned+=1;remainders[best]=-1.0
		plan.total=assigned
	plan.max_alive=spawn_count(int(plan.get("max_alive",1)),value)
	plan.spawn_interval=float(plan.get("spawn_interval",1))/spawn_multiplier(value)
	return plan
