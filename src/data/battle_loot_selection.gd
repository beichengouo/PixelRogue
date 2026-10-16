class_name BattleLootSelection
extends RefCounted
## Combat keeps its relic preference; every source shares the tier/slot picker.
const RELIC_CHANCE:=LootSelection.COMBAT_RELIC_CHANCE
static func pick(rng:RandomNumberGenerator,rarity_weights:Array=[])->Dictionary:
	var pool:Array[Dictionary]=[]
	for item in ItemDB.all():
		if not ItemDB.in_source(item,&"chest") or not ItemDB.can_refresh(item):continue
		if ItemDB.is_relic(item) or ItemDB.is_equippable(item):pool.append(item)
	var chosen:=LootSelection.pick_for_source(pool,&"chest",rng,rarity_weights)
	if not chosen.is_empty():ItemDB.record_refresh(chosen)
	return chosen
