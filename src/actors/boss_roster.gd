class_name BossRoster
extends RefCounted
## 三个 Boss 的数据表：模型 / 图标 / 招式 / 召唤物。
## 想加 Boss：往这里加一条 + 在 BossBase.create() 里挂一个类。

const KING := &"king"
const MAGE := &"mage"
const TIDE := &"tide"

const DATA := {
	&"sephra":{"title":"执印巡卫·塞芙菈","subtitle":"误将护送化为囚禁的归城巡卫","strip":"sephra","hp":900.0,"damage":32.0,"speed":68.0,"coins":70,"size":Vector2(44,50),"scale":1.0,"color":"bdcedd","gravity":true,"keep":210.0,"phases":2,"minions":[&"walker",&"guard"]},
	&"verena":{"title":"千页司书·维蕾娜","subtitle":"被归档职责接管的记录官","strip":"verena","hp":1150.0,"damage":30.0,"speed":74.0,"coins":80,"size":Vector2(46,56),"scale":1.0,"color":"e3b985","gravity":false,"keep":280.0,"phases":2,"minions":[&"flyer",&"caster"]},
	&"nameless":{"title":"无名录仪","subtitle":"禁止改变的星术记录核心","strip":"nameless","hp":1650.0,"damage":36.0,"speed":86.0,"coins":120,"size":Vector2(56,66),"scale":1.0,"color":"94cce8","gravity":false,"keep":170.0,"phases":3,"minions":[&"ruin_sentinel",&"dusk_acolyte"]},
	KING: {
		"title": "林之骸王",
		"subtitle": "被崩坏侵蚀的骷髅领主",
		"strip": "king",          # assets/characters/boss_king.png
		"hp": 900.0, "damage": 32.0, "speed": 68.0, "coins": 70,
		"size": Vector2(44.0, 50.0), "scale": 2.2,
		"color": "ffd166", "gravity": true, "keep": 210.0,
		"minions": [&"walker", &"guard", &"flyer", &"bomber"],
	},
	MAGE: {
		"title": "晶化巨影",
		"subtitle": "把森林晶化的术士",
		"strip": "mage",
		"hp": 1150.0, "damage": 30.0, "speed": 74.0, "coins": 80,
		"size": Vector2(46.0, 56.0), "scale": 1.35,
		"color": "c07bff", "gravity": false, "keep": 280.0,
		"minions": [&"crystal_familiar"],
	},
	TIDE: {
		"title": "潮汐之根",
		"subtitle": "森林中央那棵树的心脏",
		"strip": "tide",
		"hp": 1650.0, "damage": 36.0, "speed": 86.0, "coins": 120,
		"size": Vector2(56.0, 66.0), "scale": 1.6,
		"color": "8fffd8", "gravity": true, "keep": 170.0,
		"minions": [&"bog_crab", &"lantern_toad", &"glimmer_spider"],
	},
}


static func get_data(id: StringName) -> Dictionary:
	return (DATA.get(id, DATA[KING]) as Dictionary)


static func icon_path(id: StringName) -> String:
	if str(id) in ["sephra","verena","nameless"]:return "res://assets/chapter2/bosses/"+str(id)+"_portrait.png"
	return "res://assets/pixel_batch8/boss_%s_v1.png" % str(get_data(id)["strip"])


static func title_of(id: StringName) -> String:
	return str(get_data(id)["title"])

