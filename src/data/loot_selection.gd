class_name LootSelection
extends RefCounted
## Source -> category -> quality -> equipment slot -> item. Catalogue growth
## never changes a category/quality/slot's chance while it still has candidates.
const GEAR_QUALITY := [40.0, 35.0, 20.0, 5.0]
const RELIC_QUALITY := [30.0, 56.0, 13.0, 1.0]
const POTION_QUALITY := [55.0, 44.0, 0.0, 1.0]
const COMBAT_RELIC_CHANCE := 0.65
const CATEGORIES := [&"gear", &"relic", &"potion"]
const SLOTS := [&"weapon", &"armor", &"accessory"]

static func category_of(item:Dictionary)->StringName:
	var kind:=StringName(item.get("kind",&""))
	if kind in SLOTS:return &"gear"
	if kind==&"buff":return &"relic"
	return &"potion" if kind==&"potion" else &""

static func quality_weights(category:StringName)->Array:
	match category:
		&"gear":return GEAR_QUALITY.duplicate()
		&"relic":return RELIC_QUALITY.duplicate()
		_:return POTION_QUALITY.duplicate()

static func category_weights(source:StringName)->Array:
	match source:
		&"chest":return [100.0*(1.0-COMBAT_RELIC_CHANCE),100.0*COMBAT_RELIC_CHANCE,0.0]
		&"reward":return [40.0,60.0,0.0]
		_:return [35.0,52.0,13.0]

static func item_weight(item:Dictionary)->float:
	# Optional weight changes only this item's share inside its quality/slot.
	return maxf(0.0,float(item.get("weight",1.0)))

static func pick_for_source(pool:Array,source:StringName,rng:RandomNumberGenerator,override_quality:Array=[])->Dictionary:
	var categories:Array=[[],[],[]]
	for item:Dictionary in pool:
		var index:=CATEGORIES.find(category_of(item))
		if index<0 or item_weight(item)<=0:continue
		var weights:=quality_weights(CATEGORIES[index]) if override_quality.is_empty() else override_quality
		var rarity:=clampi(int(item.get("rarity",0)),0,3)
		if rarity<weights.size() and float(weights[rarity])>0:categories[index].append(item)
	var chances:=category_weights(source)
	for i in categories.size():
		if categories[i].is_empty():chances[i]=0.0
	var category:=_weighted_index(chances,rng)
	if category<0:return {}
	var weights:=quality_weights(CATEGORIES[category]) if override_quality.is_empty() else override_quality
	return pick(categories[category],weights,rng)

static func pick(pool:Array,weights:Array,rng:RandomNumberGenerator)->Dictionary:
	var buckets:Array=[[],[],[],[]]
	for item:Dictionary in pool:
		if item_weight(item)<=0:continue
		var quality:=clampi(int(item.get("rarity",0)),0,3)
		buckets[quality].append(item)
	var chances:Array=[]
	for i in buckets.size():
		chances.append(float(weights[i]) if i<weights.size() and not buckets[i].is_empty() else 0.0)
	var quality:=_weighted_index(chances,rng)
	if quality<0:return {}
	return _within_quality(buckets[quality],rng)

static func _within_quality(pool:Array,rng:RandomNumberGenerator)->Dictionary:
	var gear:Array=[];var other:Array=[]
	var chances:Array=[0.0,0.0]
	for item:Dictionary in pool:
		var index:=0 if category_of(item)==&"gear" else 1
		(gear if index==0 else other).append(item)
		chances[index]+=item_weight(item)
	var selected:=0 if other.is_empty() else 1 if gear.is_empty() else _weighted_index(chances,rng)
	if selected==1:return _item(other,rng)
	var slots:Array=[[],[],[]]
	for item:Dictionary in gear:slots[SLOTS.find(StringName(item.kind))].append(item)
	var slot_chances:Array=[]
	for entries:Array in slots:slot_chances.append(0.0 if entries.is_empty() else 1.0)
	var slot:=_weighted_index(slot_chances,rng)
	return {} if slot<0 else _item(slots[slot],rng)

static func _item(pool:Array,rng:RandomNumberGenerator)->Dictionary:
	var weights:Array=[]
	for item:Dictionary in pool:weights.append(item_weight(item))
	var index:=_weighted_index(weights,rng)
	return {} if index<0 else pool[index].duplicate(true)

static func _weighted_index(weights:Array,rng:RandomNumberGenerator)->int:
	var total:=0.0
	for weight in weights:total+=maxf(0.0,float(weight))
	if total<=0:return -1
	var roll:=rng.randf()*total
	var last:=-1
	for i in weights.size():
		var weight:=maxf(0.0,float(weights[i]))
		if weight<=0:continue
		last=i;roll-=weight
		if roll<=0:return i
	return last
