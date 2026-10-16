class_name Story
extends RefCounted
## 序章《第一次死亡》的剧本数据。
##
## 一个「场景」= 若干句台词/旁白 +（可选）一组选项：
##   portrait        立绘路径，空字符串 = 这一段不出现人
##   portrait_alpha  立绘透明度（画外音时压暗一点，像"只闻其声"）
##   lines           [{"who": "女神" / ""(旁白), "text": "..."}]
##   choices         [{"text": 选项, "reply": [台词…], "next": 下一个场景,
##                     "affinity": 好感增减, "flags": {标记}, "line": 分支线,
##                     "class": 职业身份, "give": 给的道具 id,
##                     "requires": 需要某个标记才显示}]
## 想改剧情/加分支，改这个文件就够了，不用碰界面代码。

## 她的名字：显示在名牌上，也决定"该亮谁的立绘"
const GODDESS := CharacterStories.GODDESS
const P_GODDESS := "res://assets/characters/goddess_portrait.png"

## 序章入口（第一次开新局时走这里）
const INTRO_FIRST := &"intro_wake"
## 第一次死亡后走的场景
const DEATH_FIRST := &"death_first"
## 各分支线名字（场景四的五个选项）
const LINE_CALM := "冷静"
const LINE_LOST := "迷茫"
const LINE_REBEL := "叛逆"
const LINE_DEVOUT := "虔诚"
const LINE_HIDDEN := "隐藏"

const SCENES := {

## ---------------- 场景一：林间醒来 ----------------
&"intro_wake": {
	"title": "序章 · 无名的清晨",
	"portrait": P_GODDESS,
	"lines": [
		{"who": "", "text": "叶隙里的光落在眼前。湿冷的苔藓、风声……还有一段怎么也抓不住的记忆。", "panel": 0},
		{"who": "", "text": "希露媞雅试着撑起身体。一个陌生的声音先一步叫住了她。", "panel": 1},
		{"who": GODDESS, "text": "“先别动。你刚从死亡那边回来，身体还没跟上。”", "panel": 1},
		{"who": GODDESS, "text": "“我是伊莉丝。这里叫苏醒林地。记住这个名字——它会试着让你忘记。”", "panel": 1},
		{"who": "", "text": "伊莉丝的语气很平静，像是已经等过许多个这样的清晨。", "panel": 1},
	],
	## 第二局以后：不再装"第一次醒来"，直接承认又回来了
	"lines_repeat": [
		{"who": "", "text": "又是那片苔藓。又是被树叶切碎的光。"},
		{"who": "", "text": "希露媞雅的身体已经先一步熟悉了这种感觉——骨头里的酸、喉咙里的铁锈味。"},
		{"who": GODDESS, "text": "“醒了？比我预计的快。”"},
		{"who": GODDESS, "text": "“身体还认得这里，这是好事。”"},
		{"who": GODDESS, "text": "“照旧：先活过今天。工具在你手边。”"},
	],
	"choices": [
		{
			"text": "“你是谁？”", "affinity": 0,
			"reply": [
				{"who": GODDESS, "text": "“一个还能把你带回来的人。”"},
				{"who": GODDESS, "text": "“其他答案，我会慢慢告诉你。”"},
			],
			"next": &"intro_weapon",
		},
		{
			"text": "“我死了？”", "affinity": 1,
			"reply": [
				{"who": GODDESS, "text": "“是。但你又醒来了。这件事，比死亡更值得记住。”"},
				{"who": GODDESS, "text": "“害怕也没关系。先把呼吸稳住。”"},
			],
			"next": &"intro_weapon",
		},
		{
			"text": "“滚开。”", "affinity": -1,
			"flags": {&"intro_rude": true}, "line": LINE_REBEL,
			"reply": [
				{"who": GODDESS, "text": "“……”"},
				{"who": GODDESS, "text": "“好，我退后一点。你不必现在就相信我。”"},
				{"who": GODDESS, "text": "“可森林里的东西，不会因为你生气就停下来。”"},
			],
			"next": &"intro_weapon",
		},
		{
			"text": "“我该做什么？”", "affinity": 1,
			"reply": [
				{"who": GODDESS, "text": "“问得好。至少你比大多数人清醒。”"},
				{"who": GODDESS, "text": "“先活下去。工具就在你手边。”"},
			],
			"next": &"intro_weapon",
		},
		{
			"text": "（希露媞雅沉默，观察四周）", "affinity": 2,
			"flags": {&"intro_silent": true}, "line": LINE_HIDDEN,
			"reply": [
				{"who": "", "text": "希露媞雅没有回答。风从林子深处吹来，她顺着风声，慢慢找回自己的呼吸。"},
				{"who": GODDESS, "text": "“……不说话。”"},
				{"who": GODDESS, "text": "“没关系。沉默的人，往往活得最久。”"},
			],
			"next": &"intro_weapon",
		},
	],
},

## ---------------- 场景二：第一次战斗教学（选初始武器） ----------------
&"intro_weapon": {
	"title": "序章 · 晶石的锁",
	"portrait": P_GODDESS,
	"lines": [
		{"who": "", "text": "枯枝断裂的声音逼近。黑色晶石嵌在骷髅的肋骨里，藤蔓牵动着它的手臂。", "panel": 2},
		{"who": "", "text": "它正盯着希露媞雅。或许，她身上藏着某样东西，连她自己也不曾察觉。", "panel": 2},
		{"who": GODDESS, "text": "“别让晶石碰到你。那不是它的骨头，是把它困在这里的锁。”", "panel": 2},
		{"who": "", "text": "希露媞雅手边散着三件旧武器。眼前的危险容不得犹豫，她只能先选一件。", "panel": 2},
		{"who": GODDESS, "text": "“带上它。活下来，我们才有时间把其他事说清楚。”", "panel": 2},
	],
	"lines_repeat": [
		{"who": "", "text": "骨头摩擦的咯吱声从灌木后面压过来，和上一次几乎同一个位置。"},
		{"who": "", "text": "那具被崩坏侵蚀的骷髅、黑色晶石、从肋骨缝里长出来的藤蔓——一模一样。"},
		{"who": GODDESS, "text": "“还是那三件东西。”"},
		{"who": GODDESS, "text": "“选你这次想用的。别重复上次的死法。”"},
	],
	"choices": [
		{
			"text": "短剑 · 携带一柄悬浮武器", "affinity": 0,
			"flags": {&"start_weapon": "sword"}, "give": &"iron_sword",
			"reply": [{"who": GODDESS, "text": "“铁片。握紧点，别被自己的手滑到。”"}],
			"next": &"",
		},
		{
			"text": "断裂法杖 · 携带火焰法器", "affinity": 0,
			"flags": {&"start_weapon": "staff"}, "give": &"staff_fire",
			"reply": [{"who": GODDESS, "text": "“晶石怕火。让它替你争取一点距离。”"}],
			"next": &"",
		},
		{
			"text": "沾血匕首 · 携带轻巧利刃", "affinity": 0,
			"flags": {&"start_weapon": "dagger"}, "give": &"dagger_iron",
			"reply": [{"who": GODDESS, "text": "“上面的血还没干。可能是别人的，也可能是你的。”"}],
			"next": &"",
		},
	],
},

## ---------------- 场景三：第一次死亡 ----------------
&"death_first": {
	"title": "轮回 · 光的另一侧",
	"portrait": "",
	"lines": [
		{"who": "", "text": "声音渐渐远去。希露媞雅视野边缘的黑暗合拢，林地却没有随她一起沉睡。", "panel": 2},
		{"who": "", "text": "她以为一切到此为止。直到那个声音再次响起。", "panel": 3},
		{"who": GODDESS, "text": "“听见的话，就沿着光走。这次我能接住你。”", "panel": 3},
	],
	"next": &"death_hall",
},

## ---------------- 场景四：星辉回廊 ----------------
&"death_hall": {
	"title": "轮回 · 星辉回廊",
	"portrait": P_GODDESS,
	"portrait_alpha": 1.0,
	"lines": [
		{"who": "", "text": "希露媞雅再次睁开眼。"},
		{"who": "", "text": "这里没有天空，没有地面，只有无数漂浮的星辉碎片。"},
		{"who": "", "text": "伊莉丝站在光里。白金色裙摆缓缓浮动，长发像流淌的银河。"},
		{"who": "", "text": "伊莉丝望向希露媞雅，终于松开了一直攥着的手，像确认什么珍贵的东西没有遗失。"},
		{"who": GODDESS, "text": "“欢迎回来。”"},
		{"who": GODDESS, "text": "“我叫伊莉丝。”"},
		{"who": GODDESS, "text": "“重要的是，你回来了。林地还没有夺走你的选择。”"},
	],
	"choices": [
		{
			"text": "“你是谁？这里是哪？”", "line": LINE_CALM,
			"reply": [
				{"who": GODDESS, "text": "“我是被困在这里的人。这里是星辉回廊——世界重置时唯一不会消失的地方。”"},
				{"who": GODDESS, "text": "“所以，别以为站在我面前是件容易的事。”"},
			],
			"next": &"death_hall_intro",
		},
		{
			"text": "“我为什么会死？”", "line": LINE_LOST, "affinity": 1,
			"reply": [
				{"who": GODDESS, "text": "“因为世界在崩坏。每一次潮汐，都会杀死所有人。”"},
				{"who": GODDESS, "text": "“你只是死得比较早。”"},
			],
			"next": &"death_hall_intro",
		},
		{
			"text": "“我不信你。”", "line": LINE_REBEL, "affinity": -1,
			"reply": [
				{"who": GODDESS, "text": "“真巧。我也不信我自己。”"},
				{"who": GODDESS, "text": "“不过没关系——你会信的。用你最不想用的那种方式。”"},
			],
			"next": &"death_hall_intro",
		},
		{
			"text": "“请告诉我该怎么做。”", "line": LINE_DEVOUT, "affinity": 2,
			"reply": [
				{"who": GODDESS, "text": "“去杀。去死。去变强。然后回到我这里。”"},
				{"who": GODDESS, "text": "“很好。你终于问对了一次问题。”"},
			],
			"next": &"death_hall_intro",
		},
		{
			"text": "（希露媞雅保持沉默）", "line": LINE_HIDDEN, "affinity": 1,
			"flags": {&"secret_route": true},
			"reply": [
				{"who": GODDESS, "text": "“沉默是好习惯。”"},
				{"who": GODDESS, "text": "“可惜，你已经答应了。”"},
			],
			"next": &"death_hall_intro",
		},
	],
},

## ---------------- 场景五：伊莉丝的自述（简短介绍） ----------------
&"death_hall_intro": {
	"title": "轮回 · 留在星辉中的人",
	"portrait": P_GODDESS,
	"lines": [
		{"who": "", "text": "伊莉丝抬起手。飘浮的星辉碎片像被牵住的萤火，绕着指尖转了一圈。"},
		{"who": GODDESS, "text": "“我不是神。”"},
		{"who": GODDESS, "text": "“名字、长裙、金色的眼睛——都是别人替我留下的东西。”"},
		{"who": GODDESS, "text": "“我只是一直留在这里的人。世界重置时，所有人都会被带走，只有我不会。”"},
		{"who": GODDESS, "text": "“很久，很久了。久到我快忘了外面的风是什么味道。”"},
		{"who": GODDESS, "text": "“直到你回来。”"},
		{"who": GODDESS, "text": "“所以别怕我。我们是同一类东西——都是本该消失、却还留着的人。”"},
	],
	"next": &"death_reenter",
},

## ---------------- 场景六：重新进入圣云大陆 ----------------
&"death_reenter": {
	"title": "轮回 · 再次出发",
	"portrait": P_GODDESS,
	"lines": [
		{"who": GODDESS, "text": "“你可以重新进入圣云大陆。”"},
		{"who": GODDESS, "text": "“下一次醒来，你要重新准备武器，从头走过林地。”"},
		{"who": "", "text": "这次找到的东西留不住，但希露媞雅会记住那些险路、晶石，还有怪物发动攻击前的动作。"},
		{"who": GODDESS, "text": "“去吧。”"},
		{"who": GODDESS, "text": "“这次，试着活得久一点。我不想那么快又见到你。”"},
	],
	"next": &"",
},

}


static func get_scene(id: StringName, replay := false, character_id:StringName=&"") -> Dictionary:
	if id==&"fate_observation":return FateStory.scene(character_id,replay)
	if String(id).begins_with("city_"):return CityStories.scene(id,replay,character_id)
	var scene := _shared_scene(id, replay)
	if scene.is_empty(): return scene
	var character:Dictionary=Characters.DATA.get(character_id,Characters.current())
	scene = CharacterStories.apply(scene, id, replay, str(character.get("story_profile", "")))
	return DialoguePortraits.decorate(scene, id, replay,character_id)


static func _shared_scene(id: StringName, replay := false) -> Dictionary:
	# Stable checkpoint IDs are replay keys; room/Boss events decide when they play.
	if String(id).begins_with("cp_"):
		if id == FINAL_SCENE:
			return _final_scene()
		var wave := int(String(id).substr(3))
		if CHECKPOINTS.has(wave):
			return {
				"portrait": P_GODDESS,
				"title": str(CHECKPOINT_TITLES.get(wave, "林地回声")),
				"lines": (CHECKPOINTS[wave] as Array).duplicate(true),
				"next": &"",
			}
	if not SCENES.has(id):
		return {}
	var scene := (SCENES[id] as Dictionary).duplicate(true)
	# 重开一局时会再演一次序章：这时用"再次醒来"的版本，逻辑上才说得通
	if replay and scene.has("lines_repeat"):
		scene["lines"] = (scene["lines_repeat"] as Array).duplicate(true)
	return scene


static func _final_scene() -> Dictionary:
	return {
		"title": "第一章终幕 · 林地之外",
		"lines": [
			{"who": "", "panel": 0, "text": "潮汐之根停止搏动。晶石从树皮上剥落，风终于穿过了这片林地。"},
			{"who": "", "panel": 3, "text": "希露媞雅走到门前。伊莉丝伸出手，这一次，她没有再叮嘱希露媞雅先活过今天。"},
			{"who": GODDESS, "panel": 3, "text": "“你做到了。林地再也留不住你的名字。”"},
			{"who": GODDESS, "panel": 3, "text": "“门外还有很长的路。但下一次醒来，你会知道自己为什么出发。”"},
			{"who": "", "text": "希露媞雅停在门前。继续留在林地迎接新的挑战，还是带着记忆离开？这一次，她可以自己选择。"},
		],
		"choices": [
			{"text": "留在苏醒林地 · 继续无尽战斗", "flags": {&"forest_cleared": true, &"stay_in_forest": true, &"go_next_scene": false, &"chapter_2_unlocked": true}, "reply": [{"who": GODDESS, "panel": 1, "text": "“好。门会一直为你留着。等你想出发时，再来找我。”"}], "next": &""},
			{"text": "离开苏醒林地 · 结束本章", "flags": {&"forest_cleared": true, &"stay_in_forest": false, &"go_next_scene": true, &"chapter_2_unlocked": true}, "reply": [{"who": "", "text": "希露媞雅回望渐渐安静的树影，扶正帽檐，向门外的光迈出一步。"}], "next": &""},
		],
	}

const CHECKPOINT_TITLES := {
	10: "树影下的名字",
	20: "不肯熄灭的灯",
	30: "骸王的守望",
	40: "回声的代价",
	50: "门后的约定",
	60: "被缚的巨影",
	70: "女神的沉默",
	80: "自己的声音",
	90: "最后一道锁",
}
const CHECKPOINTS := {
	10: [
		{"who": "", "text": "希露媞雅拾起一片没有枯萎的叶子。叶脉里，黑色晶丝正缓慢地生长。", "panel": 0},
		{"who": GODDESS, "text": "“崩坏不是从外面闯进来的。它已经在这片林地里很久了。”", "panel": 1},
		{"who": GODDESS, "text": "“记住你看见的东西。这里最先吞掉的，往往是记忆。”", "panel": 1},
	],
	20: [
		{"who": "", "text": "遗迹墙上刻满名字。有的被树根遮住，有的被人反复划去。", "panel": 0},
		{"who": GODDESS, "text": "“他们也曾在这里醒来。也曾问过你刚才问我的问题。”", "panel": 1},
		{"who": GODDESS, "text": "“我没能把每一个人带出去。那些名字，是我留下的灯。”", "panel": 1},
	],
	30: [
		{"who": "", "text": "骸王倒下时，指骨仍紧扣着一枚残破的徽记。它守着的不是王座，而是一道门。", "panel": 2},
		{"who": GODDESS, "text": "“它曾是林地的守卫。晶石把守护的誓言，变成了不准任何人离开的命令。”", "panel": 1},
		{"who": GODDESS, "text": "“你刚刚替它结束了很长的一次守夜。”", "panel": 1},
	],
	40: [
		{"who": "", "text": "风里夹着陌生的呼喊。每当希露媞雅停下，那些声音就向她靠近，仿佛早已认得她。", "panel": 0},
		{"who": GODDESS, "text": "“别回答。晶石能留下声音，也能把听见它的人留下。”", "panel": 1},
		{"who": GODDESS, "text": "“如果你忘了自己的名字，就先记住一件事：你想离开。”", "panel": 1},
	],
	50: [
		{"who": "", "text": "巨树的轮廓终于从雾里显现。树冠下，有一道像裂痕一样细的光。", "panel": 0},
		{"who": GODDESS, "text": "“那是星辉之门。它没有消失，只是一直被树根压着。”", "panel": 1},
		{"who": GODDESS, "text": "“斩断三处束缚，门就会打开。最后一处，在古树的心脏里。”", "panel": 1},
	],
	60: [
		{"who": "", "text": "巨影散去，遗迹深处亮起第二枚星纹。希露媞雅的呼吸，第一次没有被森林吞没。", "panel": 0},
		{"who": GODDESS, "text": "“第二道锁开了。现在，它已经知道你真的能走到门前。”", "panel": 1},
		{"who": GODDESS, "text": "“接下来的回声会学着说我的话。看着星纹，别只相信声音。”", "panel": 1},
	],
	70: [
		{"who": "", "text": "“你为什么还留在这里？”希露媞雅终于问出口。伊莉丝沉默了很久。", "panel": 1},
		{"who": GODDESS, "text": "“因为有人还没回来。”", "panel": 1},
		{"who": GODDESS, "text": "“我答应过，门关闭之前，最后一个醒来的人不会独自面对黑暗。”", "panel": 1},
	],
	80: [
		{"who": "", "text": "林子里响起与希露媞雅一模一样的声音，催她转身。可那声音越急切，她越清楚自己真正想去哪里。", "panel": 0},
		{"who": GODDESS, "text": "“很好。它能学会你的声音，学不会你的选择。”", "panel": 1},
		{"who": GODDESS, "text": "“前面就是祭坛。这一次，由你决定故事在哪里结束。”", "panel": 1},
	],
	90: [
		{"who": "", "text": "古树根部的晶石缓慢起伏。每一次搏动，都让林地里那些死去的影子重新站起。", "panel": 2},
		{"who": GODDESS, "text": "“潮汐之根。所有回声都从这里回来。”", "panel": 1},
		{"who": GODDESS, "text": "“我会守住门。去打断它的最后一次心跳，然后——带着自己的记忆过来。”", "panel": 1},
	],
}

const FINAL_SCENE := &"cp_100"


static func checkpoint_id(wave: int) -> StringName:
	if wave == 100:
		return FINAL_SCENE
	if CHECKPOINTS.has(wave):
		return StringName("cp_%d" % wave)
	return &""


static func random_death_line(line := "", affinity := 0) -> Array:
	if Characters.current_id()==&"xixifu":return SummonerStories.death_line(GODDESS)
	if Characters.current_id()==&"ilyua":return IlyuaStories.death_line(GODDESS)
	## 第一次死亡之后的每一次死亡：只留一句女神短句，避免重复演整段回廊
	var pool: Array = [
		[{"who": GODDESS, "text": "“又回来了。”"}],
		[{"who": GODDESS, "text": "“这次比上次久一点。”"}],
		[{"who": GODDESS, "text": "“记住了吗？那就别再用同一种方式死。”"}],
		[{"who": GODDESS, "text": "“别急着道歉。你不欠我什么——目前还不欠。”"}],
	]
	if line == LINE_REBEL:
		pool.append([{"who": GODDESS, "text": "“还是不肯听我的话。”"}])
	elif line == LINE_DEVOUT:
		pool.append([{"who": GODDESS, "text": "“回来就好。我一直在这儿。”"}])
	elif line == LINE_HIDDEN:
		pool.append([{"who": GODDESS, "text": "“……你还是不说话。”"}])
	elif line == LINE_CALM:
		pool.append([{"who": GODDESS, "text": "“冷静的人死得慢，但不会不死。”"}])
	elif line == LINE_LOST:
		pool.append([{"who": GODDESS, "text": "“迷路的人，最后都会回到我这里。”"}])
	if affinity >= 5:
		pool.append([{"who": GODDESS, "text": "“辛苦你了。……这句不是客套。”"}])
	elif affinity <= -3:
		pool.append([{"who": GODDESS, "text": "“你越恨我，回来得越勤。”"}])
	return (pool[Rng.stream().randi_range(0, pool.size() - 1)] as Array).duplicate(true)


static func has_scene(id: StringName) -> bool:
	return not get_scene(id).is_empty()


static func choices_of(scene: Dictionary) -> Array:
	## 过滤掉前置没满足的隐藏选项
	var out: Array = []
	for raw in scene.get("choices", []) as Array:
		var option: Dictionary = raw
		var need := StringName(option.get("requires", &""))
		if need != &"" and not StoryState.has_flag(need):
			continue
		out.append(option)
	return out


