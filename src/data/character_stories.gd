class_name CharacterStories
extends RefCounted
## 角色剧情以第三人称旁白覆盖共享事件；选项效果、事件 ID 与 UI 不随文案复制。
const GODDESS := "伊莉丝"
const PROFILES := {
	"sylphiette": {
		&"intro_wake": {
			"title": "希露媞雅 · 林间苏醒",
			"lines": [
				{"text": "帽檐上挂着一滴露水。希露媞雅抬手去接，指尖却先冒出了一小簇火苗。她松了口气，至少施法的本事还在。"},
				{"text": "可她为什么会躺在这里？记忆里还有遗迹、发亮的符文……再往后，只剩一阵刺耳的断裂声。"},
				{"who": GODDESS, "text": "先别急着站起来。你刚从死亡那边回来。"},
				{"who": "player", "text": "死亡？等等，我只是去看看那座遗迹——我还没碰它的机关呢。"},
				{"who": GODDESS, "text": "我是伊莉丝。这里是苏醒林地。遗迹为什么把你带到这里，我们可以慢慢查。现在，先确认你还能握住魔法。"},
				{"text": "伊莉丝说得太平静了。希露媞雅把帽子扶正，悄悄感受脚边的草叶。它们还在回应她，却像在害怕林子深处的什么东西。"},
			],
			"lines_repeat": [
				{"text": "露水又挂在了帽檐上。希露媞雅揉揉发酸的手腕，试着点起一簇火苗。上一次吃过的亏，她这次可得记住。"},
				{"who": GODDESS, "text": "醒了，希露媞雅？你还记得自己的名字。"},
				{"who": "player", "text": "记得。还有那些晶石。我想再走一趟，这回看清楚它们的来路。"},
				{"who": GODDESS, "text": "好。工具还在手边，先选一件。"},
			],
			"choice_texts": ["“伊莉丝，你为什么能把我带回来？”", "“所以……我真的死过一次？”", "“先退后。我还不能相信你。”", "“那就告诉我，怎么离开这里。”", "（希露媞雅先检查草叶上的魔力痕迹）"],
			"choice_replies": {
				0: [{"who": GODDESS, "text": "星辉还能找到你的名字，我就能把你接住。但我无法替你走出林地。"}, {"text": "名字……希露媞雅。她在心里默念了一遍，提醒自己这回得把它记牢。"}],
				3: [{"who": GODDESS, "text": "林地深处有一扇门。先活过眼前的危险，我会陪你寻找打开它的办法。"}],
				4: [{"text": "希露媞雅蹲下身。草叶的伤口里不是泥土，而是细小的黑色晶丝。这景象让她皱起眉，怎么看都不像普通的诅咒。"}, {"who": GODDESS, "text": "你已经发现了。别碰那些晶丝，它们会把活物变成林地的锁。"}],
			},
		},
		&"intro_weapon": {
			"title": "序章 · 草叶中的异响",
			"lines": [
				{"text": "枯枝咔嚓一响。希露媞雅拨开帽檐，看见一具骷髅从灌木里站起来。黑色晶石嵌在它的肋骨间，藤蔓牵着它的手臂。"},
				{"who": "player", "text": "把自然魔力拧成这种样子……是谁干的？"},
				{"who": GODDESS, "text": "现在别靠近。晶石是困住它的锁，也会试着锁住你。"},
				{"text": "希露媞雅的魔力还不稳定。好在身边散着几件旧武器，足够先挑一件防身。她决定等安全了，再追查那些晶石的来路。"},
			],
			"choice_texts": ["铁剑 · 增强攻击", "断裂法杖 · 火焰法器", "沾血匕首 · 轻巧利刃"],
		},
	}
}

static func apply(scene: Dictionary, id: StringName, repeated: bool, profile: String) -> Dictionary:
	if profile=="sylphiette":return HolyStories.apply(scene,id,repeated,GODDESS)
	if profile=="xixifu":return SummonerStories.apply(scene,id,repeated,GODDESS)
	if profile=="ilyua":return IlyuaStories.apply(scene,id,repeated,GODDESS)
	var scenes: Dictionary = PROFILES.get(profile, {})
	var patch: Dictionary = scenes.get(id, {})
	if patch.is_empty():
		return scene
	if patch.has("title"):
		scene["title"] = patch["title"]
	# 重开使用共享的再次苏醒文本；回看由调用方请求原始版本。
	var line_key := "lines_repeat" if repeated and patch.has("lines_repeat") else "lines"
	if patch.has(line_key) and (not repeated or patch.has("lines_repeat")):
		scene["lines"] = (patch[line_key] as Array).duplicate(true)
	var choices: Array = scene.get("choices", [])
	var texts: Array = patch.get("choice_texts", [])
	var replies: Dictionary = patch.get("choice_replies", {})
	for index in choices.size():
		if index < texts.size(): choices[index]["text"] = texts[index]
		if replies.has(index): choices[index]["reply"] = (replies[index] as Array).duplicate(true)
	return scene



