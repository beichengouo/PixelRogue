class_name HolyTalents
extends RefCounted
const ROOT:="res://assets/characters/sylphiette_holy_v01/talents/"
const DATA:={
&"holy_afterglow":{"name":"曙光余烬","max_rank":3,"desc":"圣光直击有15%概率追加余辉；二级对辉光目标扩大范围；三级第三次余辉化作天降圣裁。","branch_name":"晨曦圣典","branch":"dawn","tier":1,"icon":ROOT+"afterglow.png","requires":{}},
&"holy_brand":{"name":"裁决烙印","max_rank":3,"desc":"直击有15%概率附加辉光印记；二级共鸣散向邻敌；三级连续三次共鸣追加圣裁。","branch_name":"晨曦圣典","branch":"dawn","tier":2,"icon":ROOT+"brand.png","requires":{&"holy_afterglow":1}},
&"holy_harmony":{"name":"天光交响","max_rank":3,"desc":"不同小技能交替命中后，下一次普攻附带圣光波；二级追加打击；三级轮替产生协同圣裁。","branch_name":"晨曦圣典","branch":"dawn","tier":3,"icon":ROOT+"harmony.png","requires":{&"holy_brand":2}},
&"holy_feather_birth":{"name":"羽辉初生","max_rank":3,"desc":"四次主普攻命中凝聚追击圣羽；二级转向另一敌人；三级追击结束释放一代光羽碎片。","branch_name":"圣羽颂诗","branch":"feather","tier":1,"icon":ROOT+"birth.png","requires":{}},
&"holy_wings":{"name":"循光之翼","max_rank":3,"desc":"圣羽优先追击近期命中者；二级对辉光目标追加涟漪；三级连续五次追击同目标追加羽光斩。","branch_name":"圣羽颂诗","branch":"feather","tier":2,"icon":ROOT+"wings.png","requires":{&"holy_feather_birth":1}},
&"holy_chorus":{"name":"圣翼回响","max_rank":3,"desc":"小技能唤出短暂护身圣羽；二级结束飞出追击；三级不同小技能合奏扩散羽光。","branch_name":"圣羽颂诗","branch":"feather","tier":3,"icon":ROOT+"chorus.png","requires":{&"holy_wings":2}},
&"holy_veil":{"name":"白云纱幕","max_rank":3,"desc":"战斗中连续三次小技能获得临时护盾；二级护盾期间普攻附加光纹；三级此护盾结束释放冲击。","branch_name":"云庭恩泽","branch":"cloud","tier":1,"icon":ROOT+"veil.png","requires":{}},
&"holy_purity":{"name":"净光之环","max_rank":3,"desc":"受到生命伤害后净化近身普通弹幕；二级反击圣光；三级净环结束追击圣羽。冷却6秒。","branch_name":"云庭恩泽","branch":"cloud","tier":2,"icon":ROOT+"purity.png","requires":{&"holy_veil":1}},
&"holy_dew":{"name":"晨露恩泽","max_rank":3,"desc":"五次有效直击回复有限生命；二级在自身圣阵内更容易触发；三级低生命时有效直击触发庇护。","branch_name":"云庭恩泽","branch":"cloud","tier":3,"icon":ROOT+"dew.png","requires":{&"holy_purity":2}},
&"holy_devout":{"name":"虔诚共鸣","max_rank":3,"desc":"普攻与小技能交替直击补充祈光；二级圣辉强化后普攻追击微光；三级三次祈光循环释放圣光爆发。","branch_name":"祈愿圣律","branch":"prayer","tier":1,"icon":ROOT+"devout.png","requires":{}},
&"holy_word":{"name":"圣言余音","max_rank":3,"desc":"小技能有效直击有25%概率产生圣言波；二级减速并净弹；三级不同小技能连续命中触发圣钟回响。","branch_name":"祈愿圣律","branch":"prayer","tier":2,"icon":ROOT+"word.png","requires":{&"holy_devout":1}},
&"holy_flow":{"name":"流光之仪","max_rank":3,"desc":"移动中祈光衰减更慢；二级持续移动后小技能附带追踪圣羽；三级移动、直击与施法形成节奏，召唤协同圣影。","branch_name":"祈愿圣律","branch":"prayer","tier":3,"icon":ROOT+"light_ritual.png","requires":{&"holy_word":2}}}
const OLD_MAP:={"nova_shot":"holy_afterglow","nova_might":"holy_brand","nova_pierce":"holy_harmony","nova_ghost":"holy_harmony","power":"holy_feather_birth","blast":"holy_wings","ignite":"holy_chorus","chain_blast":"holy_chorus","nature_attune":"holy_veil","thorn_bind":"holy_purity","living_bloom":"holy_dew","sprout_return":"holy_dew","arcane_reserve":"holy_devout","star_step":"holy_word","quick_weave":"holy_flow","celestial_focus":"holy_flow"}
static func migrate(raw:Dictionary)->Dictionary:
	var result:Dictionary={};var spent:=0;var kept:=0
	for id in raw:
		spent+=maxi(0,int(raw[id]));var key:=StringName(OLD_MAP.get(str(id),str(id)))
		if DATA.has(key):result[key]=mini(3,int(result.get(key,0))+int(raw[id]))
	for rank in result.values():kept+=int(rank)
	return {"talents":result,"refund":maxi(0,spent-kept)}
