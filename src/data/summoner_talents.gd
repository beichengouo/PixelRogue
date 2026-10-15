class_name SummonerTalents
extends RefCounted
const GROUP_NAMES := ["影契同行", "灵魂共振", "夜幕守护", "归途引导"]
const DATA := {
	&"contract_might":{"name":"温柔契约","max_rank":3,"desc":"每级契约物攻击+8%。","branch_name":"影契同行","branch":"hunt","tier":1,"icon":"res://assets/next_revision/talents/contract_might.png","requires":{}},
	&"contract_vitality":{"name":"不孤单","max_rank":3,"desc":"每级契约物最大生命+10%，保留当前生命比例。","branch_name":"影契同行","branch":"hunt","tier":2,"icon":"res://assets/next_revision/talents/contract_vitality.png","requires":{"contract_might":1}},
	&"contract_duration":{"name":"多陪一会","max_rank":2,"desc":"每级新契约伙伴持续时间+5秒。","branch_name":"影契同行","branch":"hunt","tier":3,"icon":"res://assets/next_revision/talents/contract_duration.png","requires":{"contract_vitality":2}},
	&"power":{"name":"黑曜微光","max_rank":3,"desc":"每级攻击力+6%，同步强化普攻与契约物继承攻击。","branch_name":"灵魂共振","branch":"blast","tier":1,"icon":"res://assets/next_revision/talents/power.png","requires":{}},
	&"parade_power":{"name":"心声共鸣","max_rank":2,"desc":"每级百灵夜行的攻击加成额外+10%。","branch_name":"灵魂共振","branch":"blast","tier":2,"icon":"res://assets/next_revision/talents/parade_power.png","requires":{"power":1}},
	&"parade_duration":{"name":"长夜相伴","max_rank":2,"desc":"每级百灵夜行持续时间+1秒。","branch_name":"灵魂共振","branch":"blast","tier":3,"icon":"res://assets/next_revision/talents/parade_duration.png","requires":{"parade_power":1}},
	&"shadow_care":{"name":"掌心余温","max_rank":3,"desc":"每级契约技能治疗量+8%、夜幕护盾量+8%。","branch_name":"夜幕守护","branch":"nature","tier":1,"icon":"res://assets/next_revision/talents/shadow_care.png","requires":{}},
	&"shelter_duration":{"name":"安静夜幕","max_rank":2,"desc":"每级夜幕庇护护盾持续时间+1秒。","branch_name":"夜幕守护","branch":"nature","tier":2,"icon":"res://assets/next_revision/talents/shelter_duration.png","requires":{"shadow_care":1}},
	&"guardian_duration":{"name":"林间誓约","max_rank":2,"desc":"每级森影守望持续时间额外+2秒。","branch_name":"夜幕守护","branch":"nature","tier":3,"icon":"res://assets/next_revision/talents/guardian_duration.png","requires":{"shelter_duration":1}},
	&"arcane_reserve":{"name":"幽月流转","max_rank":3,"desc":"每级自然回蓝+0.4/秒、普通技能冷却-5%。","branch_name":"归途引导","branch":"star","tier":1,"icon":"res://assets/next_revision/talents/arcane_reserve.png","requires":{}},
	&"shadow_stride":{"name":"轻声远行","max_rank":2,"desc":"每级影契共鸣范围+18像素、冷却减少0.5秒。","branch_name":"归途引导","branch":"star","tier":2,"icon":"res://assets/next_revision/talents/shadow_stride.png","requires":{"arcane_reserve":1}},
	&"celestial_focus":{"name":"群灵呼应","max_rank":1,"desc":"大招冷却-20%，魔力消耗-10%。","branch_name":"归途引导","branch":"star","tier":3,"icon":"res://assets/next_revision/talents/celestial_focus.png","requires":{"shadow_stride":2}},
}
static func effects(id:StringName, rank:int)->Dictionary:
	match id:
		&"contract_might":return {"契约物攻击加成%":rank*8.0}
		&"contract_vitality":return {"契约物生命加成%":rank*10.0}
		&"contract_duration":return {"新契约额外秒数":rank*5.0}
		&"parade_power":return {"夜行额外攻击加成%":rank*10.0}
		&"parade_duration":return {"夜行额外秒数":rank*1.0}
		&"shadow_care":return {"契约治疗加成%":rank*8.0,"夜幕护盾加成%":rank*8.0}
		&"shelter_duration":return {"护盾额外秒数":rank*1.0}
		&"guardian_duration":return {"守望者额外秒数":rank*2.0}
		&"shadow_stride":return {"影步额外距离":rank*18.0,"影步冷却减少秒数":rank*0.5}
	return {}

