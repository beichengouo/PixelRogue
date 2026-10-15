class_name RoomEnemyComposer
extends RefCounted
## Habitat owns species; formations mix front line, pursuit and support slots.
const POOLS:={
	"forest":[["moss_badger",1,4],["charger",1,3],["thorn_mantis",4,2],["glimmer_spider",8,2],["treant",9,1]],
	"wetland":[["bog_crab",1,5],["lantern_toad",1,2],["bell_snail",11,1]],
	"ruin":[["walker",1,5],["ruin_sentinel",1,2],["flyer",2,2],["bomber",5,1],["caster",6,1],["dusk_acolyte",6,2],["guard",7,2]],
}
static func compose(total:int,biome:String,wave:int,rng:RandomNumberGenerator)->Array[StringName]:
	var eligible:Array=POOLS.get(biome,POOLS.ruin).filter(func(entry:Array)->bool:return wave>=int(entry[1]))
	var result:Array[StringName]=[]
	# Reserve one of every currently available species before filling weighted roles.
	for entry in eligible:
		if result.size()>=total:break
		result.append(StringName(entry[0]))
	var weight:=0
	for entry in eligible:weight+=int(entry[2])
	while result.size()<total:
		var roll:=rng.randi_range(0,weight-1)
		for entry in eligible:
			roll-=int(entry[2])
			if roll<0:result.append(StringName(entry[0]));break
	for index in range(result.size()-1,0,-1):
		var pick:=rng.randi_range(0,index);var swap:=result[index];result[index]=result[pick];result[pick]=swap
	return result
