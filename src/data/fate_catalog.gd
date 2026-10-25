class_name FateCatalog
extends RefCounted
## Expedition-only cards. Timers are remaining active seconds, never wall time.
const IDS := ["magician","priestess","empress","emperor","chariot","hermit","star","moon","fool","world"]
const STARS := {
 "torch": {
  "name": "明炬座",
  "theme": "薪火轮回",
  "description": "主普攻有效命中积累薪火，每次攻击最多一层，上限三层；满层后的下一次主普攻首个命中消耗薪火，在两格内造成0.40倍攻击力灼击。冷却2.5秒，冷却期间不积层。"
 },
 "spring": {
  "name": "涌泉座",
  "theme": "回流之泉",
  "description": "自然MP回复增加8%。战斗中主动施法实际消耗累计达到最大MP的35%，获得一枚泉滴，最多两枚。成功施放小技能时消耗一枚，回复最大MP的7%，并获得3秒移速增加6%；释放冷却5秒。"
 },
 "lantern": {
  "name": "守灯座",
  "theme": "不灭灯火",
  "description": "首次进入未清战斗房获得完整生命上限8%的护盾，持续10秒；该房首次实际产生伤痕时，新增伤痕减少50%，不减少该次真实扣血。护盾与伤痕防护独立，每房一次。"
 }
}
const OWNERS := {"sylphiette":"priestess","xixifu":"magician","ilyua":"moon"}
const RESONANCE := {
 "priestess":"希露媞雅 · 小技能成功结算后获得8点祈光，冷却4秒，不改变本次强化判定。",
 "magician":"希希芙 · 小技能成功施放后，现存契约伙伴攻速增加12%，持续4秒，冷却8秒；不叠层。",
 "moon":"伊露雅 · 月蚀或血月主动引爆后，6秒内下一次主普攻追加0.35倍攻击力追猎箭；冷却8秒。到期不触发。"
}
const CARDS := {
 "fool": {
  "name":"愚者","theme":"重新起步",
  "upright":"敌方直击实际扣除生命且存活后，获得3秒启程：移速增加15%，下一次成功施放小技能返还实际MP消耗25%；冷却12秒。护盾吸收、自伤、持续伤害及致死伤害不触发。",
  "reverse":"敌方直击实际扣除生命且存活后，获得4秒险行：自身主普攻与主动技能直击伤害增加18%，受到的普通生命伤害增加8%；冷却12秒。护盾吸收、自伤、持续伤害及致死伤害不触发。"
 },
 "world": {
  "name":"世界","theme":"完整轮舞",
  "upright":"10秒内完成主普攻有效命中、小技能成功施放、基础闪避结束，获得完整生命上限6%护盾5秒，回复最大MP的5%；冷却12秒。每类行动记一次，超时或切房清空；冷却期间不积累。",
  "reverse":"10秒内完成主普攻有效命中、小技能成功施放、基础闪避结束，在自身三格内造成0.70倍攻击力冲击；冷却10秒。持牌期间新获得护盾量降低10%。每类行动记一次，超时或切房清空；冷却期间不积累。"
 },
 "magician": {
  "name": "魔术师",
  "theme": "秘术转化",
  "upright": "成功施放小技能，获得5秒秘术印记。下一次主普攻首个有效命中消耗印记，追加0.30倍攻击力伤害，对目标周围1.5格内其他敌人各溅射0.15倍攻击力。获得印记冷却3秒。",
  "reverse": "七秒内连续两次成功施放小技能，第二次在六格内最近可见敌人处引发两格秘术爆发，造成0.60倍攻击力伤害；连锁冷却6秒，无目标也消耗连锁。小技能最终MP消耗增加12%。"
 },
 "priestess": {
  "name": "女祭司",
  "theme": "静默预言",
  "upright": "保持静止0.9秒，获得6秒启示，获得冷却8秒。下一次成功施放小技能消耗启示，返还实际MP消耗的20%，获得4秒先见守护：下一次实际普通生命伤害减少25%，同次新增伤痕另减少25%。完全由护盾吸收的攻击不消耗守护。",
  "reverse": "保持静止1.3秒，获得6秒禁忌启示，获得冷却9秒。下一次成功施放小技能后，四秒内自身主普攻与主动技能直接伤害增加16%，移速降低10%。不强化召唤物、持续伤害和持续领域。"
 },
 "empress": {
  "name": "女皇",
  "theme": "丰饶花冠",
  "upright": "玩家直击积一点生长，四格内友军直击积两点。14点绽放，回复完整生命上限2%的生命并修复1%伤痕，返还等量生命；冷却10秒，每房最多两次。满血且无伤痕时保留满层。每次普攻或施法最多积一次，友军共用0.25秒计数间隔。普通治疗仍受浴血禁疗限制。",
  "reverse": "玩家直击积一点生长，四格内友军直击积两点。14点绽放，在自身三格内造成0.50倍攻击力冲击，并修复完整生命上限1.5%的伤痕，返还等量生命；冷却10秒，每房最多两次。每次普攻或施法最多积一次，友军共用0.25秒计数间隔。自身受到的普通生命伤害增加8%，不放大真实伤害或伤痕。"
 },
 "emperor": {
  "name": "皇帝",
  "theme": "律令壁垒",
  "upright": "首次进入未清战斗房获得完整生命上限6%的护盾，持续8秒。受击开始时持有护盾，新增伤痕减少35%，每房最多两次。护盾因承伤耗尽，释放2.5格、0.45倍攻击力震荡，冷却7秒。",
  "reverse": "首次进入未清战斗房获得完整生命上限4%的护盾，持续8秒。持盾时新增伤痕减少20%，每房一次。护盾因承伤耗尽，释放三格、0.75倍攻击力震荡，普通敌人减速20%持续2秒，冷却7秒。所有新获得护盾量减少10%，包括本牌护盾。"
 },
 "chariot": {
  "name": "战车",
  "theme": "破阵冲锋",
  "upright": "基础闪避结束获得4秒冲锋动能，下一次主普攻首个有效命中追加0.32倍攻击力，目标减速20%持续1.5秒，普通敌人受到小幅击退。每次闪避一次，成功触发冷却2秒。技能位移不触发。",
  "reverse": "基础闪避结束后，在实际经过的合法道路轨迹留下两秒战轮残影，每名敌人每条轨迹最多受到一次0.50倍攻击力伤害；不穿墙，无实体碰撞。基础闪避冷却增加18%，不获得正位普攻强化。"
 },
 "hermit": {
  "name": "隐者",
  "theme": "孤灯求索",
  "upright": "四格内无存活雇佣或召唤友军、持续4秒后，获得8秒孤灯，下一次主普攻或小技能直击追加0.35倍攻击力，冷却8秒。独行清理战斗房后，随机揭示当前阶段一间隐藏房间的位置及类型，每房一次；不揭示沿途房间，不打开房门。",
  "reverse": "四格内无存活雇佣或召唤友军、持续3秒后进入断联：独行时自身主普攻与主动技能直接伤害增加14%；玩家直接击杀回复最大MP的4%，冷却12秒。断联期间获得的护盾量减少15%。友军靠近立即终止，不强化持续领域、持续伤害或友军攻击。"
 },
 "star": {
  "name": "星星",
  "theme": "愈伤之愿",
  "upright": "首次进入未清战斗房回复最大MP的10%。首次清理该房修复完整生命上限2%的伤痕，返还等量生命；实际修复至少一点，储备下一间未清战斗房4%的护盾，持续6秒，最多储备一次。",
  "reverse": "首次进入未清战斗房回复最大MP的16%。首次清理该房修复完整生命上限3%的伤痕并返还等量生命。自然MP回复降低15%，不获得正位下一房护盾。"
 },
 "moon": {
  "name": "月亮",
  "theme": "朦胧月蚀",
  "upright": "主普攻首个有效命中施加4秒月蚀，冷却8秒，同时一个目标。正常走跑累计三格后引爆0.45倍攻击力，普通敌人减速20%持续2秒；到期仅造成0.20倍攻击力。闪避、瞬移、击退和切房不计距离。",
  "reverse": "主普攻首个有效命中施加4秒血月，冷却8秒，同时一个目标。下一次成功施放小技能后，该技能直击标记目标，引爆0.70倍攻击力，并向1.5格内其他敌人扩散0.25倍攻击力；到期仅造成0.20倍攻击力。主普攻直接伤害降低8%。"
 }
}
const RULES:={"torch_hits":3,"torch_ratio":.40,"torch_radius":72.0,"torch_cd":2.5,"spring_threshold":.35,"spring_refund":.07,"spring_cd":5.0,"repair_cap":.05}
static func empty()->Dictionary:
 return {"version":2,"cards":[],"readings":0,"star":"","star_pending":false,"cooldowns":{},"pending":{},"state":{},"still":0.0,"cast_factor":1.0}
static func normalize(raw:Variant)->Dictionary:
 var result:=empty()
 if not raw is Dictionary:return result
 result.readings=clampi(int(raw.get("readings",0)),0,3)
 result.star=str(raw.get("star","")) if STARS.has(str(raw.get("star",""))) else ""
 result.star_pending=bool(raw.get("star_pending",false)) and result.star.is_empty()
 for card in raw.get("cards",[]):
  if not card is Dictionary or not CARDS.has(str(card.get("id",""))):continue
  if result.cards.any(func(held:Dictionary)->bool:return held.id==str(card.id)):continue
  result.cards.append({"id":str(card.id),"reverse":bool(card.get("reverse",false))})
 for key in ["cooldowns","pending"]:
  if key=="pending" and int(raw.get("version",0))<2:continue
  if raw.get(key) is Dictionary:
   for id in raw[key]:
    var value:Variant=raw[key][id]
    if (value is float or value is int) and is_finite(float(value)) and float(value)>0:result[key][str(id)]=minf(float(value),3600)
 if int(raw.get("version",0))>=2 and raw.get("state") is Dictionary:result.state=_clean(raw.state)
 result.still=clampf(float(raw.get("still",0)),0,1.3) if int(raw.get("version",0))>=2 else 0.0
 return result
static func _clean(value:Variant,depth:int=0)->Variant:
 if depth>8:return null
 if value is Dictionary:
  var output:Dictionary={}
  for key in value:
   if output.size()>=256:break
   var cleaned:Variant=_clean(value[key],depth+1)
   if cleaned!=null:output[str(key)]=cleaned
  return output
 if value is Array:
  var output:Array=[]
  for i in mini(value.size(),256):
   var cleaned:Variant=_clean(value[i],depth+1)
   if cleaned!=null:output.append(cleaned)
  return output
 if value is float:return value if is_finite(value) else 0.0
 if value is int or value is bool or value is String:return value
 return null
static func active()->bool:return GameState.run_active and not CampSession.active
static func rank(id:String)->int:
 if not active():return 0
 for card in GameState.fate.get("cards",[]):
  if str(card.id)==id:return 2 if bool(card.reverse) else 1
 return 0
static func star()->String:
 var id:=str(GameState.fate.get("star","")) if active() else ""
 return id if STARS.has(id) else ""
static func owned_card(hero:StringName=&"")->String:
 return str(OWNERS.get(str(Characters.current_id() if hero==&"" else hero),""))
static func resonance(id:String)->bool:return active() and owned_card()==id and rank(id)>0
static func resonance_description(id:String)->String:
 return "角色共鸣 · "+str(RESONANCE.get(id,"")) if owned_card()==id else ""
static func art(id:String,reverse:=false)->String:
 if id in ["fool","world","priestess","magician","moon"]:return "res://assets/fate_v22/cards/"+id+("_reverse" if reverse else "")+".png"
 return "res://assets/fate_v01/cards/"+id+("_reverse" if reverse and CARDS.has(id) else "")+".png"
static func icon(id:String)->String:
 if id in ["fool","world"]:return "res://assets/fate_v22/icons/"+id+".svg"
 return "res://assets/fate_v01/icons/"+id+".png"
static func description(id:String,reverse:=false)->String:
 if not CARDS.has(id):return ""
 var text:=str(CARDS[id].reverse if reverse else CARDS[id].upright)
 if id in ["empress","star"]:text+="\n伤痕修复：所有塔罗每房合计最多修复完整生命上限5%，仅返还实际修复的上限及等量生命；药剂不占额度，浴血中也生效。"
 if not resonance_description(id).is_empty():text+="\n"+resonance_description(id)
 return text+"\n命运派生伤害不暴击、不吸血，不触发装备或其他命运牌。本次出征生效。"
static func apply_stats(block:StatBlock)->void:
 if rank("chariot")==2:block.add_mult(&"dash_cooldown",.18)
static func regen_factor()->float:return 1.0+(.08 if star()=="spring" else 0.0)-(.15 if rank("star")==2 else 0.0)
static func shield_factor()->float:return (0.9 if rank("emperor")==2 else 1.0)*(0.85 if rank("hermit")==2 and FateRuntime.disconnected() else 1.0)*(0.9 if rank("world")==2 else 1.0)
static func move_factor()->float:
 if not active():return 1.0
 return 1.0+(.15 if float(GameState.fate.pending.get("fool_start",0))>0 else 0.0)+(.06 if float(GameState.fate.pending.get("spring_speed",0))>0 else 0.0)-(.10 if float(GameState.fate.pending.get("priestess_burst",0))>0 else 0.0)
static func allies_near(actor:Node2D)->bool:
 if not is_instance_valid(actor) or not actor.is_inside_tree():return false
 var room:RoomLevel=(actor as RoomPlayer).room if actor is RoomPlayer else ((actor as RoomAlly).room if actor is RoomAlly else null)
 var roster:Array=room.tactics.allies(room) if is_instance_valid(room) else actor.get_tree().get_nodes_in_group("allies")
 for unit in roster:
  if is_instance_valid(unit) and (unit is RoomAlly or unit is HiredAlly or unit is SummonedAlly) and not unit.is_queued_for_deletion() and unit.global_position.distance_squared_to(actor.global_position)<=20736 and (not "hp" in unit or float(unit.hp)>0):return true
 return false
static func direct_factor(kind:StringName,source:Node)->float:
 if not active() or not FateRuntime.direct_source(source):return 1.0
 var factor:=1.0
 if kind==&"basic" and rank("moon")==2:factor-=.08
 if kind in [&"basic",&"skill"]:
  if float(GameState.fate.pending.get("priestess_burst",0))>0:factor+=.16
  if rank("hermit")==2 and FateRuntime.disconnected():factor+=.14
  if float(GameState.fate.pending.get("fool_risk",0))>0:factor+=.18
 return factor

static func wordmark(id:String,reverse:bool=false)->String:
 return ("res://assets/fate_v22/names/" if id in ["fool","world"] else "res://assets/fate_v09/names/")+id+("_reverse" if reverse else "")+".png"

static func star_wordmark(id:String)->String:
 return "res://assets/fate_v10/star_names/"+id+".png" if STARS.has(id) else ""
