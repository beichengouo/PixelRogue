class_name Characters
extends RefCounted
## 角色表。
##
## 后期会有多个可选角色，所以「主角是谁」这件事集中放在这里：
## 界面、剧情、头像都只问 Characters.current()，不要再把名字硬编码在 UI 里。
## 加新角色 = 往 DATA 里加一条，然后 set_current() 切过去。

const DEFAULT_ID := &"sylphiette"

const DATA := {
	&"sylphiette": {
		"id":&"sylphiette","name":"希露媞雅","job":"圣光祭司","class_id":"mage","story_profile":"sylphiette",
		"portrait":"res://assets/characters/sylphiette_holy_v01/portrait.png",
		"select_portrait":"res://assets/characters/sylphiette_holy_v01/portrait.png",
		"dialogue_portrait":"res://assets/characters/sylphiette_holy_v01/portrait.png",
		"portraits":{"stand":"res://assets/characters/sylphiette_holy_v01/portrait.png","thoughtful":"res://assets/characters/sylphiette_holy_v01/thoughtful.png","surprised":"res://assets/characters/sylphiette_holy_v01/surprised.png","determined":"res://assets/characters/sylphiette_holy_v01/determined.png","sad":"res://assets/characters/sylphiette_holy_v01/sad.png"},
		"dialogue_portraits":{"happy":"res://assets/characters/sylphiette_holy_v01/portrait.png","thoughtful":"res://assets/characters/sylphiette_holy_v01/thoughtful.png","surprised":"res://assets/characters/sylphiette_holy_v01/surprised.png","determined":"res://assets/characters/sylphiette_holy_v01/determined.png","sad":"res://assets/characters/sylphiette_holy_v01/sad.png"},
		"avatar":"res://assets/characters/sylphiette_holy_v01/avatar.png","icon":"res://assets/characters/sylphiette_holy_v01/avatar.png",
		"artbook":"res://assets/characters/sylphiette_holy_v01/artbook_v2.png","accent":"f3dda2",
		"themes":"圣辉 / 祈愿 / 圣云","intro":"银发如流云，圣光温暖而克制。\n她以祝祷守护旅伴，也以裁决驱散林地的暗影。",
		"battle_style":"祈光积累 · 圣辉强化\n天降圣裁 · 移动圣域 · 弹幕净化",
		"preview_skills":[&"flame_nova",&"fan_bolts",&"blink",&"meteor"],
		"appearance":"银色长发如流云般柔顺，蔚蓝眼眸澄澈；纯白祭袍镶嵌金丝圣云纹饰，蓝色祈光宝石扣在腰间。身形纤细端庄，头发自然垂落，金色圣云发饰点缀鬓边；没有巫师帽或兜帽。周身散发微弱温暖的圣光。",
		"profile":"她相信圣光应当先照见伤口，而不是只照亮胜者。失去记忆后，希露媞雅仍会在危急时伸出手，倾听晶石之下被压住的祈愿。她安静而坚定，不把温柔误认为退让。",
	},
	&"xixifu": {
		"story_profile":"xixifu", "id": &"xixifu", "name": "希希芙", "job": "召唤师", "class_id": "summoner",
		"portrait": "res://assets/characters/xixifu/portrait.png",
		"select_portrait": "res://assets/characters/xixifu/portrait.png",
		"dialogue_portrait": "res://assets/characters/xixifu/portrait.png",
		"portraits": {"stand":"res://assets/characters/xixifu/portrait.png"},
		"dialogue_portraits": {"happy":"res://assets/characters/xixifu/portrait.png", "thoughtful":"res://assets/characters/xixifu/portrait.png", "determined":"res://assets/characters/xixifu/portrait.png"},
		"avatar": "res://assets/characters/xixifu/avatar.png", "icon": "res://assets/characters/xixifu/skill_0.png", "accent": "c3a0ff",
		"artbook": "res://assets/characters/xixifu/artbook.png",
		"themes":"影契 / 守护 / 引导",
		"intro":"外表与人类无异的魔族少女。\n她不懂人们为何害怕魔物，只想和伙伴一起找到回家的路。",
		"battle_style":"召唤伙伴 · 指挥与召回\n夜幕庇护 · 契约共鸣",
		"preview_skills":[&"shadow_companions",&"ghost_lantern",&"homeward_light",&"forest_guardian"],
		"appearance":"柔顺的黑色长发垂过腰际，黑瞳清澈纯真，目光总带着迷茫与好奇。身形娇小，穿着朴素漆黑长袍；虽是魔族，却没有异于人类的角、尾或翅膀，看起来像个走失的平民女孩。",
		"profile":"在林地醒来的魔族少女，不知道自己为何能听见魔物的心声。她把骸灵、幽灯与树灵当作旅伴，以契约借来力量，从不以伙伴的生命为代价。慢热、善良，对日常事物充满好奇；每次召回伙伴，都轻声说一句：我们一起回去。",
	},
	&"ilyua": {
		"id":&"ilyua", "name":"伊露雅", "job":"弓箭手", "class_id":"archer", "story_profile":"ilyua",
		"portrait":"res://assets/characters/ilyua/portrait.png", "select_portrait":"res://assets/characters/ilyua/select_portrait.png",
		"dialogue_portrait":"res://assets/characters/ilyua/portrait.png",
		"dialogue_portraits":{"happy":"res://assets/characters/ilyua/portrait.png","thoughtful":"res://assets/characters/ilyua/portrait.png","determined":"res://assets/characters/ilyua/portrait.png"},
		"portraits":{"stand":"res://assets/characters/ilyua/portrait.png"},
		"avatar":"res://assets/characters/ilyua/avatar.png", "icon":"res://assets/characters/ilyua/avatar.png",
		"artbook":"res://assets/characters/ilyua/artbook.png", "accent":"a8d7a5",
		"themes":"疾风 / 荆棘 / 月影", "intro":"兜帽下的精灵弓手，循着风与树的低语寻找林地的答案。",
		"battle_style":"追踪箭与折返 · 荆棘种子\n月影防御 · 古树领域",
		"preview_skills":[&"ilyua_wind_arrow",&"ilyua_thorn_seed",&"ilyua_thousand_winds",&"ilyua_ancient_tree"],
		"appearance":"身形娇小而紧致有力的成年精灵，皮肤白皙，浅绿色长发从白色兜帽面部开口垂到胸前，后发收在兜帽与白色长袍内，湖蓝色双眼清澈。尖耳平时藏在兜帽中；施放大招时揭帽露出精灵特征。腰间佩着藤蔓金纹短弓。",
		"profile":"伊露雅擅长借风调整箭路，以荆棘和古树守护林地。她说话轻而坚定，观察每一片受晶石侵蚀的叶子。",
	},
}

static var _current: StringName = DEFAULT_ID


static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in DATA:
		out.append(DATA[id])
	return out


static func current_id() -> StringName:
	return _current


static func set_current(id: StringName) -> void:
	if DATA.has(id):
		_current = id


static func current() -> Dictionary:
	return DATA.get(_current, DATA[DEFAULT_ID])


static func current_name() -> String:
	return str(current().get("name", "主角"))


static func current_job() -> String:
	return str(current().get("job", ""))


static func portrait_path(expression := "") -> String:
	## expression 为空 = 用默认立绘；给了名字就在差分表里找，找不到也回落到默认。
	var data := current()
	var set: Dictionary = data.get("portraits", {})
	if expression != "" and set.has(expression):
		return str(set[expression])
	return str(data.get("portrait", ""))


static func select_portrait_path() -> String:
	## 选人界面用的立绘：没配就回落到默认立绘
	var data := current()
	var p := str(data.get("select_portrait", ""))
	return p if p != "" else portrait_path()


static func random_portrait_path() -> String:
	## 随机挑一张差分：背包、结算这类"多看几眼也不腻"的地方用。
	## 每次打开背包换一张脸，比永远同一张更有生气。
	var set: Dictionary = current().get("portraits", {})
	if set.is_empty():
		return portrait_path()
	var keys: Array = set.keys()
	return str(set[keys[randi() % keys.size()]])


static func avatar_path() -> String:
	return str(current().get("avatar", ""))


static func class_id()->String:
	return str(current().get("class_id","mage"))
static func class_name_of(id:String)->String:
	return {"mage":"魔法师","warrior":"战士","archer":"弓箭手","summoner":"召唤师"}.get(id,id)

