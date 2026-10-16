class_name WaveTable
extends RefCounted
## 第一章四段配置；无尽从终局强度另行增长，不再循环教学或堆数百只怪。
const MAX_SPEED_SCALE := 1.5
const MAX_ATTACK_SCALE := 1.9
const BOSS_WAVES := {10: &"king", 20: &"mage", 30: &"tide"}
const KINDS := ["walkers", "flyers", "chargers", "casters", "bombers", "guards", "treants"]
const UNLOCK_WAVES := [1, 2, 4, 6, 5, 7, 9]
const STAGES := [
	{"end":5,"name":"初识林地","from":6,"to":10,"cap":6,"interval":1.15},
	{"end":10,"name":"交错追击","from":11,"to":15,"cap":7,"interval":0.95},
	{"end":20,"name":"遗迹交锋","from":16,"to":20,"cap":8,"interval":0.80},
	{"end":30,"name":"林地深处","from":21,"to":26,"cap":9,"interval":0.70},
]
## 冲锋、弹幕、包夹、守卫组合；最终分配到有限人数。
const COMPOSITIONS := [
	[6,2,4,1,2,1,1], [3,4,1,4,1,2,1],
	[3,2,3,2,4,1,1], [4,1,1,2,1,4,3],
]

static func build(wave: int) -> Dictionary:
	wave = maxi(1,wave)
	var first_wave := mini(wave,30)
	var stage_index := 0
	var start := 1
	while first_wave > int(STAGES[stage_index].end):
		start = int(STAGES[stage_index].end)+1
		stage_index += 1
	var stage:Dictionary = STAGES[stage_index]
	var progress := float(first_wave-start)/maxf(1,float(int(stage.end)-start))
	var count := int(round(lerpf(float(stage.from),float(stage.to),progress)))
	var extra := maxi(0,wave-30)
	if extra>0:count = mini(48,26+int(extra/5))
	var cycle := wave
	var is_boss := false # Boss allocation belongs exclusively to RoomGraph.
	var result := {
		"stage":stage_index+1, "stage_name":"无尽林地" if extra>0 else stage.name,
		"composition":(wave-1)%COMPOSITIONS.size(), "boss":is_boss,
		"max_alive":mini(12,int(stage.cap)+int(extra/20)),
		"spawn_interval":maxf(0.55,float(stage.interval)-float(extra)*0.001),
		"rest_seconds":rest_seconds(wave),
		"hp_scale":_curve(first_wave,[1.0,2.0,3.5,7.5,12.0])*(1.0+float(extra)*0.012),
		"damage_scale":_curve(first_wave,[1.0,1.15,1.6,2.3,3.0])*(1.0+float(extra)*0.007),
		"speed_scale":minf(MAX_SPEED_SCALE,_curve(first_wave,[1.0,1.12,1.22,1.32,1.4])+float(extra)*0.0005),
		"attack_scale":minf(MAX_ATTACK_SCALE,_curve(first_wave,[1.0,1.12,1.25,1.42,1.6])+float(extra)*0.001),
		"boss_hp_scale":float({10:4.5,20:10.0,30:15.0}.get(cycle,1.0))*(1.0+float(extra)*0.012),
		"total":0,
	}
	var weights:Array = COMPOSITIONS[int(result.composition)].duplicate()
	var total_weight := 0
	for i in KINDS.size():
		if first_wave<int(UNLOCK_WAVES[i]):weights[i]=0
		total_weight+=int(weights[i])
		result[KINDS[i]]=0
	if is_boss:
		result.total=1
		return result
	# 最大余数法：不会因独立四舍五入丢失人数。
	var remainders:Array[float]=[]
	for i in KINDS.size():
		var share := float(count*int(weights[i]))/float(total_weight)
		result[KINDS[i]]=int(floorf(share))
		result.total+=int(result[KINDS[i]])
		remainders.append(share-floorf(share))
	while int(result.total)<count:
		var best := remainders.find(remainders.max())
		result[KINDS[best]]+=1
		result.total+=1
		remainders[best]=-1.0
	return result

static func _curve(wave:int,values:Array)->float:
	var points := [1,5,10,20,30]
	for i in range(1,points.size()):
		if wave<=int(points[i]):
			return lerpf(float(values[i-1]),float(values[i]),float(wave-int(points[i-1]))/float(int(points[i])-int(points[i-1])))
	return float(values.back())

static func rest_seconds(wave:int)->float:
	return 20.0 if wave%10==0 else 8.0

static func coin_reward(wave:int)->int:
	return 12+int(float(mini(maxi(wave,1),30))*0.35)+int(float(maxi(0,wave-30))*0.12)

static func shop_price_factor(wave:int)->float:
	return 1.0+0.03*float(clampi(wave-1,0,29))+0.012*float(maxi(0,wave-30))

static func hire_price_factor(wave:int)->float:
	return 1.0+0.05*float(clampi(wave-1,0,29))+0.025*float(maxi(0,wave-30))

static func experience_needed(level:int)->float:
	return round(12.0+3.2*pow(float(maxi(1,level)),1.85))

static func experience_pool(wave:int)->float:
	# 每波对应一级成长预算。召唤与分裂共享，避免靠拖延 Boss 无限刷经验。
	return experience_needed(clampi(wave,1,100)) if wave>=1 else 0.0

static func elite_policy(wave:int)->Dictionary:
	if wave<=5:return {"chance":0.18 if wave>=4 else 0.0,"max":1}
	# A continuous progression curve; difficulty applies its existing modifier.
	var chance:=minf(.85,.26+float(maxi(0,wave-6))*.02)
	return {"chance":chance,"max":1 if wave<=10 else 2 if wave<=20 else 4 if wave>50 else 3}
