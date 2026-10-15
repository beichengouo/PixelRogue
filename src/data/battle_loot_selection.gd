class_name BattleLootSelection
extends RefCounted
## Combat drops own a category roll; shop and three-choice weights are untouched.
const RELIC_CHANCE:=.65
static func pick(rng:RandomNumberGenerator,rarity_weights:Array=[])->Dictionary:
	var relics:Array[Dictionary]=[];var gear:Array[Dictionary]=[]
	for item in ItemDB.all():
		if not ItemDB.in_source(item,&"chest") or not ItemDB.can_refresh(item):continue
		if ItemDB.is_relic(item):relics.append(item)
		elif ItemDB.is_equippable(item):gear.append(item)
	var pool:Array[Dictionary]=relics if rng.randf()<RELIC_CHANCE else gear
	if pool.is_empty():pool=gear if relics.is_empty() else relics
	if pool.is_empty():return {}
	var chosen:Dictionary=pool[ItemDB._weighted_pick(pool,rng)].duplicate(true) if rarity_weights.is_empty() else LootSelection.pick(pool,rarity_weights,rng)
	if not chosen.is_empty():ItemDB.record_refresh(chosen)
	return chosen
