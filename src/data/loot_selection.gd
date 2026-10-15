class_name LootSelection
extends RefCounted
## Quality weights are independent of the number of catalogue entries.
static func pick(pool:Array,weights:Array,rng:RandomNumberGenerator)->Dictionary:
	var buckets:Array=[[],[],[],[]]
	for item in pool:
		var quality=clampi(int(item.get("rarity",0)),0,3)
		buckets[quality].append(item)
	var total=0.0
	for i in buckets.size():
		if not buckets[i].is_empty():total+=maxf(0,float(weights[i]))
	if total<=0:return {}
	var roll=rng.randf()*total
	for i in buckets.size():
		if buckets[i].is_empty():continue
		roll-=maxf(0,float(weights[i]))
		if roll<=0:return buckets[i][rng.randi_range(0,buckets[i].size()-1)].duplicate(true)
	for i in range(3,-1,-1):
		if not buckets[i].is_empty() and float(weights[i])>0:return buckets[i].back().duplicate(true)
	return {}
