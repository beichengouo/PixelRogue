class_name BossPhaseRules
extends RefCounted
## One threshold/skill source shared by AI, snapshots, model and HUD.
const REVISION:=30
const NAMES:={"king":["枯冠守门","断冠王令"],"mage":["封存晶声","晶核显露"],"tide":["沉根","潮冠苏醒","深海花开"],"sephra":["归城巡卫","封门执印"],"verena":["藏名司书","昨日归档"],"nameless":["留名","校验","闭环终止"]}
const SKILLS:={"king":["枯冠剑舞","断骨飞矛","崩坏骨刺","亡骸征召","崩坏王令","枯骨环葬","骸王葬礼"],"mage":["晶刺突生","棱镜折光","碎晶星雨","浮晶环阵","晶镜幻身","晶牢封界","终焉晶爆"],"tide":["深根突袭","腐海孢雨","寄生根群","沧澜横潮","深渊涡眼","逆潮回响","根海绞杀","深海花葬","终潮·深渊归寂"],"sephra":["执印三连","归城突进","分段门印","交叉封街","巡卫点名"],"verena":["飞页扇射","延迟蜡印","书架投影","昨日复写","空白批注"],"nameless":["交错星环","星轨依次扫射","落印圆阵","双轨逆行","校验卫星","闭环回响","未署名出口"]}
static func thresholds(id:StringName)->Array:
	if id==&"nameless":return [1.0,.65,.30,0.0]
	if id==&"tide":return [1.0,2.0/3.0,1.0/3.0,0.0]
	return [1.0,.5,0.0]
static func phase_at(id:StringName,ratio:float)->int:
	var cuts:=thresholds(id);var result:=1
	while result<cuts.size()-1 and ratio<=float(cuts[result]):result+=1
	return result
static func title(id:StringName,phase:int)->String:return str(NAMES[str(id)][clampi(phase-1,0,NAMES[str(id)].size()-1)])
static func skills(id:StringName,phase:int)->Array:
	var all:Array=SKILLS[str(id)]
	if id==&"king":return all if phase>=2 else [all[1],all[0],all[2],all[3],all[1],all[0],all[5]]
	if id==&"mage":return all.slice(0,6 if phase==1 else 7)
	if id==&"tide":return all.slice(0,phase*3)
	return all.slice(0,3 if phase==1 else 5 if phase==2 else 7)
static func action(id:StringName,skill:String,releasing:bool)->StringName:
	var index:int=SKILLS[str(id)].find(skill)
	return StringName("skill_%d_%s"%[index,"release" if releasing else "windup"]) if index>=0 else (&"release" if releasing else &"windup")
