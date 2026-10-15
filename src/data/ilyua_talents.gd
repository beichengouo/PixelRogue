class_name IlyuaTalents
extends RefCounted

const GROUP_NAMES := ["疾风箭术", "荆棘秘术", "月影游猎", "精灵血脉"]
const ICON := "res://assets/characters/ilyua/talents/"
const DATA := {
	&"ilyua_wind_feathers":{"name":"风语箭羽","max_rank":3,"desc":"1级主普攻追踪范围144；2级首次命中有15%概率追加0.15倍风刃，冷却0.8秒；3级风刃追踪108范围敌人。","branch_name":"疾风箭术","branch":"hunt","tier":1,"icon":ICON+"ilyua_wind_feathers.png","requires":{}},
	&"ilyua_returning_arrow":{"name":"折返之矢","max_rank":3,"desc":"1级主普攻允许墙面折返1次；2级折返箭命中后转向另一名108范围目标一次；3级折返伤害+8%，最多+16%。","branch_name":"疾风箭术","branch":"hunt","tier":2,"icon":ICON+"ilyua_returning_arrow.png","requires":{"ilyua_wind_feathers":1}},
	&"ilyua_true_shot":{"name":"百步穿杨","max_rank":3,"desc":"1级命中伤害+3%，上限9%；2级同目标每第五次连续命中释放0.4倍贯穿箭，冷却1秒；3级贯穿命中引导两支附近未命中的主箭，每支只引导一次。","branch_name":"疾风箭术","branch":"hunt","tier":3,"icon":ICON+"ilyua_true_shot.png","requires":{"ilyua_returning_arrow":2}},
	&"ilyua_life_sprout":{"name":"生命萌芽","max_rank":3,"desc":"1级普攻有10%概率种下4秒新芽，每秒造成0.06倍攻击；2级成熟时在72范围造成0.2倍爆发；3级向最近1名目标传播一次。","branch_name":"荆棘秘术","branch":"blast","tier":1,"icon":ICON+"ilyua_life_sprout.png","requires":{}},
	&"ilyua_wild_growth":{"name":"野蛮生长","max_rank":3,"desc":"1级对受控目标伤害+8%；2级陷阱额外触发2次；3级受控目标死亡留下2秒、每秒0.08倍攻击的荆棘区，最多4个。","branch_name":"荆棘秘术","branch":"blast","tier":2,"icon":ICON+"ilyua_wild_growth.png","requires":{"ilyua_life_sprout":1}},
	&"ilyua_nature_resonance":{"name":"万物共鸣","max_rank":3,"desc":"1级自然直接命中使种子伤害+10%，同目标冷却1秒；2级种子与藤蔓重叠时伤害+10%；3级寄生爆发使附近最多两个自然区域追加0.1倍脉冲，冷却1秒。","branch_name":"荆棘秘术","branch":"blast","tier":3,"icon":ICON+"ilyua_nature_resonance.png","requires":{"ilyua_wild_growth":2}},
	&"ilyua_forest_shadow":{"name":"林间幽影","max_rank":3,"desc":"1级闪步后移动速度+10%，持续2秒；2级基础冲刺也留下2秒叶影，冷却6秒；3级诱饵消失时射出2枚各0.15倍的追踪叶刃。","branch_name":"月影游猎","branch":"nature","tier":1,"icon":ICON+"ilyua_forest_shadow.png","requires":{}},
	&"ilyua_light_body":{"name":"轻盈之躯","max_rank":3,"desc":"1级连续移动1.5秒后冲刺冷却恢复+10%，停下0.5秒结束；2级真实闪避近身伤害后，下一主箭3秒内伤害+25%；3级同时获得1秒穿过敌人的能力，仍受实体地形阻挡。","branch_name":"月影游猎","branch":"nature","tier":2,"icon":ICON+"ilyua_light_body.png","requires":{"ilyua_forest_shadow":1}},
	&"ilyua_moon_guard":{"name":"月华庇护","max_rank":3,"desc":"1级月影箭防御后再生时间6秒；2级格挡转化0.15倍攻击反击；3级闪避开始0.12秒内拒绝实际伤害时补充2支反击月箭，冷却4秒。","branch_name":"月影游猎","branch":"nature","tier":3,"icon":ICON+"ilyua_moon_guard.png","requires":{"ilyua_light_body":2}},
	&"ilyua_nature_favor":{"name":"自然眷顾","max_rank":3,"desc":"1级直接击杀后20%概率使下一次普攻+20%伤害；2级下一次自然技能+15%；3级6秒内获得3层祝福时触发4秒每秒0.12倍箭雨，冷却8秒。","branch_name":"精灵血脉","branch":"star","tier":1,"icon":ICON+"ilyua_nature_favor.png","requires":{}},
	&"ilyua_ancient_pact":{"name":"古老契约","max_rank":3,"desc":"1级小技能后4秒内下一次普攻追加0.12倍攻击；2级命中使小技能冷却减少0.2秒，间隔1秒；3级6秒内两种不同小技能有效命中触发0.4倍攻击，冷却5秒；追风箭每次强化施放的首次普攻命中计作该技能有效命中。","branch_name":"精灵血脉","branch":"star","tier":2,"icon":ICON+"ilyua_ancient_pact.png","requires":{"ilyua_nature_favor":1}},
	&"ilyua_forest_will":{"name":"森灵意志","max_rank":3,"desc":"1级生命低于30%时获得12%最大生命护盾3秒，冷却30秒；2级触发时72范围减速35%持续2秒；3级72范围造成0.3倍攻击推退，首领推力减半，技能伤害+10%持续4秒。","branch_name":"精灵血脉","branch":"star","tier":3,"icon":ICON+"ilyua_forest_will.png","requires":{"ilyua_ancient_pact":2}},
}

static func effects(id:StringName, rank:int)->Dictionary:
	if rank<=0:return {}
	match id:
		&"ilyua_wind_feathers":return {"追踪范围":144.0,"首次风刃概率%":15.0 if rank>=2 else 0.0,"首次风刃伤害系数":0.15 if rank>=2 else 0.0,"风刃追踪范围":108.0 if rank>=3 else 0.0}
		&"ilyua_returning_arrow":return {"额外折返次数":1.0,"折返重选目标数":1.0 if rank>=2 else 0.0,"折返伤害加成%":8.0 if rank>=3 else 0.0}
		&"ilyua_true_shot":return {"命中伤害加成%":float(rank*3),"第五箭穿透伤害系数":0.4 if rank>=2 else 0.0,"引导箭数":2.0 if rank>=3 else 0.0}
		&"ilyua_life_sprout":return {"普攻新芽概率%":10.0,"新芽每秒伤害系数":0.06,"成熟爆发伤害系数":0.2 if rank>=2 else 0.0,"成熟传播目标数":1.0 if rank>=3 else 0.0}
		&"ilyua_wild_growth":return {"受控目标伤害加成%":8.0,"陷阱额外触发次数":2.0 if rank>=2 else 0.0,"死亡荆棘区伤害系数":0.08 if rank>=3 else 0.0}
		&"ilyua_nature_resonance":return {"种子伤害加成%":10.0,"重叠伤害加成%":10.0 if rank>=2 else 0.0,"重叠脉冲伤害系数":0.1 if rank>=3 else 0.0}
		&"ilyua_forest_shadow":return {"闪步后移动加成%":10.0,"诱饵持续秒数":2.0 if rank>=2 else 0.0,"结束追踪叶刃数":2.0 if rank>=3 else 0.0}
		&"ilyua_light_body":return {"冲刺恢复加成%":10.0,"近失后普攻加成%":25.0 if rank>=2 else 0.0,"穿过敌人秒数":1.0 if rank>=3 else 0.0}
		&"ilyua_moon_guard":return {"防御后再生秒数":6.0,"格挡反击伤害系数":0.15 if rank>=2 else 0.0,"完美闪避月影箭数":2.0 if rank>=3 else 0.0}
		&"ilyua_nature_favor":return {"击杀祝福概率%":20.0,"下次普攻加成%":20.0,"下次自然技能加成%":15.0 if rank>=2 else 0.0,"祝福箭雨伤害系数":0.12 if rank>=3 else 0.0}
		&"ilyua_ancient_pact":return {"小技能后普攻伤害系数":0.12,"小技能冷却减少秒数":0.2 if rank>=2 else 0.0,"异种技能共鸣伤害系数":0.4 if rank>=3 else 0.0}
		&"ilyua_forest_will":return {"低血护盾%":12.0,"触发减速%":35.0 if rank>=2 else 0.0,"触发推退伤害系数":0.3 if rank>=3 else 0.0,"触发技能伤害加成%":10.0 if rank>=3 else 0.0}
	return {}
