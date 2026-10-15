class_name PassiveDefinitions
extends RefCounted
const DATA := {
 &"xixifu_shared_fate":{"id":&"xixifu_shared_fate","name":"共命影契","desc":"护盾之后的伤害优先由最近的同行伙伴承担，溢出才扣自身生命。诱饵不参与。"},
 &"xixifu_revival":{"id":&"xixifu_revival","name":"未尽的同行","desc":"本人击杀普通怪有20%概率复活为伙伴，继承50%攻击与最大生命；最多3只，持续30秒。"},
 &"xixifu_wisps":{"id":&"xixifu_wisps","name":"迷途引灯","desc":"战斗中每8秒出现一只1血浮灵，在房间内随机游荡并吸引仇恨；最多3只，各持续20秒。被击杀或持续时间结束时爆炸，对3格范围内未被障碍遮挡的敌人造成自身当前攻击力2倍的伤害；离房消失，不触发爆炸。"},
 &"sylphiette_hymn":{"id":&"sylphiette_hymn","name":"黎明颂歌","desc":"普攻及小技能直击同目标三次降下0.45倍攻击圣裁；有效共鸣补充祈光，目标死亡时将一层圣歌传给附近两敌。4秒内三次共鸣强化下一小技能余辉。衍生伤害不递归积累。"},
 &"sylphiette_grace":{"id":&"sylphiette_grace","name":"永恒恩典","desc":"有效普攻或战斗中小技能积累五层恩泽，生成6秒护身圣环，冷却8秒。圣环抵消一枚普通弹幕或使一次攻击减伤35%，随后圣光反击并补充祈光；同次伤害有护盾时不额外消耗圣环。真实伤害绕过圣环。"},
 &"ilyua_wind_rhythm":{"id":&"ilyua_wind_rhythm","name":"风之律动","desc":"主箭普攻首次命中叠加1层风律，最多5层；每层攻击速度+2%、箭矢速度+4%。未攻击2秒后每秒失去1层，移动中的宽限延至3秒。受生命伤害失去2层；满层时有20%概率对另一名108范围敌人射出0.2倍风刃，冷却0.6秒。"},
 &"ilyua_forest_whisper":{"id":&"ilyua_forest_whisper","name":"森之低语","desc":"普攻首次命中有20%概率种下4秒森林印记，每秒造成0.08倍攻击；目标死亡时向72范围内最近2名敌人各以40%概率传播一次。自然技能直接命中有印记目标时，对72范围造成0.12倍攻击，冷却1秒；2秒内击杀3名印记目标后，在72范围生成持续3秒、每秒0.12倍攻击的自然领域，冷却6秒。"},
}
static var _selected:Dictionary={}
static func for_character(character:StringName)->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 for id:StringName in DATA:
  if str(id).begins_with(str(character)+"_"):
   var entry:Dictionary=DATA[id].duplicate(true)
   entry["icon"]=("res://assets/characters/ilyua/passives/" if character==&"ilyua" else "res://assets/next_revision/passives/")+str(id)+".png"
   if character==&"sylphiette":entry.icon=HolySkills.ROOT+"passives/"+str(id)+".png"
   result.append(entry)
 return result
static func default_for(character:StringName)->StringName:
 if character==&"xixifu":return &"xixifu_shared_fate"
 if character==&"ilyua":return &"ilyua_wind_rhythm"
 return &"sylphiette_hymn"
static func migrate_id(id:StringName)->StringName:
 return &"sylphiette_hymn" if id==&"sylphiette_arcane" else &"sylphiette_grace" if id==&"sylphiette_aoe" else id
static func selected(character:StringName)->StringName:
 if _selected.has(character):return migrate_id(_selected[character])
 var saved:=migrate_id(StringName(StoryState.flags.get("character:%s:passive_selection"%character,"")))
 for entry:Dictionary in for_character(character):
  if entry.id==saved:
   _selected[character]=saved
   return saved
 return default_for(character)
static func select(character:StringName,id:StringName,persist:=true)->bool:
 for entry:Dictionary in for_character(character):
  if entry.id==id:
   _selected[character]=id
   if persist:
    StoryState.flags["character:%s:passive_selection"%character]=str(id)
    StoryState.save_story()
   return true
 return false
