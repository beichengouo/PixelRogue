class_name RoomEnemyComposer
extends RefCounted
## Habitat owns species; formations mix front line, pursuit and support slots.
const POOLS:={
	"forest":[["moss_badger",1,4],["charger",1,3],["thorn_mantis",4,2],["glimmer_spider",8,2],["treant",9,1]],
	"wetland":[["bog_crab",1,5],["lantern_toad",1,2],["bell_snail",11,1]],
	"ruin":[["walker",1,5],["ruin_sentinel",1,2],["flyer",2,2],["bomber",5,1],["caster",6,1],["dusk_acolyte",6,2],["guard",7,2]],
}
const ROLES:={"walker":"walkers","moss_badger":"chargers","charger":"chargers","thorn_mantis":"chargers","glimmer_spider":"casters","treant":"treants","bog_crab":"walkers","lantern_toad":"bombers","bell_snail":"treants","ruin_sentinel":"guards","flyer":"flyers","bomber":"bombers","caster":"casters","dusk_acolyte":"casters","guard":"guards"}
static func compose(total:int,biome:String,wave:int,rng:RandomNumberGenerator,composition:int=-1)->Array[StringName]:
	var eligible:Array=POOLS.get(biome,POOLS.ruin).filter(func(entry:Array)->bool:return wave>=int(entry[1]))
	var result:Array[StringName]=[]
	if total<=0 or eligible.is_empty():return result
	var profile:Array=WaveTable.COMPOSITIONS[posmod(wave-1 if composition<0 else composition,WaveTable.COMPOSITIONS.size())]
	var selected:Array=[]
	var candidates:=eligible.duplicate()
	while selected.size()<mini(mini(4,total),eligible.size()):
		var index:=_pick(candidates,profile,rng);selected.append(candidates[index]);candidates.remove_at(index)
	for entry in selected:result.append(StringName(entry[0]))
	while result.size()<total:result.append(StringName(selected[_pick(selected,profile,rng)][0]))
	for index in range(result.size()-1,0,-1):
		var pick:=rng.randi_range(0,index);var swap:=result[index];result[index]=result[pick];result[pick]=swap
	# Reorder only: neither difficulty population nor the species counts change.
	for index in range(3,result.size()):
		if result[index]!=result[index-1] or result[index]!=result[index-2] or result[index]!=result[index-3]:continue
		for next in range(index+1,result.size()):
			if result[next]!=result[index]:
				var swap:=result[index];result[index]=result[next];result[next]=swap;break
	return result
static func _pick(entries:Array,profile:Array,rng:RandomNumberGenerator)->int:
	var weights:Array[int]=[];var total:=0
	for entry in entries:
		var role:int=WaveTable.KINDS.find(ROLES[str(entry[0])]);var weight:=maxi(1,int(entry[2])*int(profile[role]));weights.append(weight);total+=weight
	var roll:=rng.randi_range(0,total-1)
	for index in entries.size():
		roll-=weights[index]
		if roll<0:return index
	return entries.size()-1
