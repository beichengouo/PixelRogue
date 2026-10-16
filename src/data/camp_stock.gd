class_name CampStock
extends RefCounted
const PERIOD=10800
const GOLD_MULTIPLIER=10
const WEIGHTS=[55,30,12,3]
static func local_seconds() -> int:
	return int(Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system(false)))
static func fee(count:int) -> int:return 10 << mini(56,maxi(0,count))
static func advance(saved: Dictionary, now:int, seed:int) -> Dictionary:
	var state=saved.duplicate(true)
	# High-water mark prevents clock rollback from restoring sold stock/resetting fees.
	var effective=maxi(now,int(state.get("clock",now)))
	var day=effective/86400
	var batch=effective/PERIOD
	if state.is_empty() or int(state.get("day",-1))!=day:
		state.day=day
		state.rerolls=0
	if int(state.get("batch",-1))!=batch or not state.has("offers"):
		state.batch=batch
		state.nonce=0
		state.offers=offers(batch,0,seed)
	# Persist only boundary changes, not every second the shop is open.
	state.clock=maxi(int(state.get("clock",0)),batch*PERIOD)
	return state
static func offers(batch:int, nonce:int, seed:int) -> Array:
	var rng=RandomNumberGenerator.new()
	rng.seed=hash("%d:%d:%d" % [seed,batch,nonce])
	var pool: Array[Dictionary]=[]
	for item in ItemDB.all():
		if (ItemDB.is_equippable(item) or ItemDB.is_usable(item)) and (ItemDB.in_source(item,&"shop") or ItemDB.in_source(item,&"camp_shop")):pool.append(item)
	var result:Array=[]
	while result.size()<8 and not pool.is_empty():
		var chosen:=LootSelection.pick(pool,WEIGHTS,rng)
		if chosen.is_empty():break
		result.append({"id":str(chosen.id),"sold":false})
		for i in range(pool.size()-1,-1,-1):
			if pool[i].id==chosen.id:pool.remove_at(i)
	return result
static func price(item:Dictionary) -> Dictionary:
	var id=str(item.id)
	if id.begins_with("camp_"):
		return {"gold":0,"materials":{"glow_mushroom_4":2} if int(item.rarity)==2 else {"glow_mushroom_7":1}}
	if id=="potion_starlight":return {"gold":0,"materials":{"glow_mushroom_2":3}}
	return {"gold":basic_price(item),"materials":{}}
static func basic_price(item:Dictionary)->int:return int(item.get("cost",0))*GOLD_MULTIPLIER
static func price_text(item:Dictionary) -> String:
	var required=price(item)
	if required.materials.is_empty():return "%d 金" % int(required.gold)
	var parts:PackedStringArray=[]
	for id in required.materials:parts.append("%s ×%d" % [ExpeditionData.resolve(id).name,int(required.materials[id])])
	return " / ".join(parts)
