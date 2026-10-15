class_name HolyStories
extends RefCounted
## Share checkpoint IDs and choice effects; replace only this character's narrative.
const CHAPTER:={
10:["袖口里的第一盏光",[["","银发沾着细雨，祭袍的金丝却仍是暖的。希露媞雅在一块断裂路碑旁停下，把掌心的光压得很低。"],["player","这里有人等过归路。先把字照清楚，不必照亮整座森林。"],["goddess","你忘了许多事，却还记得怎样让别人安心。"],["player","若这是我能带走的记忆，我愿意把它留给需要的人。"]]],
20:["没有熄灭的祷词",[["","破损祭坛里没有供奉物，只剩几道被晶丝压住的刻痕。希露媞雅俯身，听见断续的求救。"],["player","他们祈求的不是胜利，是有人回来。"],["goddess","林地会把祈愿变成锁。温柔也会被它利用。"],["player","那就先解开锁。愿望应当属于说出它的人。"]]],
30:["裁决以前",[["","骸王倒下，盾牌下面露出几枚小小的名字。希露媞雅收起光柱，把散落的骨片移到树影里。"],["player","它曾守住过一扇门。不能因为最后一场战斗，就抹掉此前的日子。"],["goddess","你在为敌人祈祷？"],["player","我在为被命令困住的人祈祷。裁决已经结束，愿它终于可以休息。"]]],
40:["圣光也有阴影",[["","晶壁映出耀眼的祭司身影，光亮却把角落里的伤者遮得更深。希露媞雅放低了手。"],["player","太亮了。若连伤口都看不见，这不是我要的圣光。"],["goddess","你不想证明自己更强？"],["player","强弱可以以后再说。先让他们看见回来的路。"]]],
50:["金丝的旧针脚",[["","祭袍袖口开了一道线。那枚歪斜的云纹，让希露媞雅想起一双反复为她补衣的手。"],["player","她大概不愿我把衣服当作旗帜，只希望我别着凉。"],["goddess","那个人的名字呢？"],["player","还记不起。可这份关心是真的，我会好好穿着它。"]]],
60:["被借走的黎明",[["","裂开的晶壳里流出许多祷词。它们被拼成同一句话，命令人们献上永远的白昼。"],["player","白昼不该靠别人的生命延长。"],["goddess","它许诺过一个没有痛苦的世界。"],["player","没有拒绝的权利，安宁也只是另一种囚禁。"],["","她拨开最细的锁纹，让不同的声音重新分开。圣光没有追赶那些离去的祈愿。"]]],
70:["夜里也可以回家",[["","归路上有一盏熄灭的旧灯。希露媞雅只补上灯芯大小的光，给周围留下安静的暗。"],["player","不是所有黑夜都需要被赶走。有人正在休息。"],["goddess","你越来越清楚自己的光要照向哪里了。"],["player","先照亮脚边，再照亮下一步。这样就够了。"]]],
80:["永昼不是独自承担",[["","断桥两端传来不同的求援。她曾想把所有声音一起接住，祭袍上的云纹因此亮得发烫。"],["goddess","停一停。你不是他们唯一的晨曦。"],["player","我明白。让他们互相看见，比让我一直站在这里更好。"],["","她把微光分给桥边的星灯，没有把祈愿系在自己手上。"]]],
90:["证明温柔",[["","林地深处的晶丝问她：若不能拯救所有人，何必伸手？希露媞雅没有提高光亮。"],["player","因为眼前还有一个人。我不需要先许诺整个世界。"],["goddess","那你愿意为谁裁决？"],["player","为让他们能够拒绝，为让祈愿不再被迫发出。"]]],
100:["一场可以结束的祈祷",[["","最后一道锁纹落入静水，天边有了真正的晨光。希露媞雅合掌，把这一段祝祷完整地说完。"],["player","愿停留的人安稳，愿离去的人认得归路。也愿我自己，学会好好回来。"],["goddess","你不再要求自己照亮每个角落了？"],["player","不。只要光能被传下去，黑夜就不必由一个人面对。"],["","她把空着的手递给伊莉丝。祭袍上的圣云微微发亮，随后安静下来。"]]]}
static func lines(raw:Array,goddess:String)->Array:
	var result:Array=[]
	for entry in raw:result.append({"who":goddess if entry[0]=="goddess" else entry[0],"text":entry[1]})
	return result
static func apply(original:Dictionary,id:StringName,repeated:bool,goddess:String)->Dictionary:
	var scene:=original.duplicate(true);scene.erase("lines_repeat")
	match id:
		&"intro_wake":
			scene.title="希露媞雅 · 圣云醒来"
			scene.lines=lines([["","银色长发落在湿冷的苔藓上。希露媞雅睁开蔚蓝的眼睛，先感到祭袍金丝里那一点熟悉的暖。"],["player","光还在……这里有人需要我吗？"],["goddess","先顾好你自己。你刚从死亡那边回来。"],["","她慢慢收拢手掌，把圣光留在胸前。安宁并没有替她解开记忆的空白。"],["goddess","我是伊莉丝。这里是苏醒林地；别急着照亮每一道阴影，我们先找到能走的路。"]] if not repeated else [["","她再次醒来，先把呼吸放慢。银发、蓝眼与袖口那一枚旧云纹，都还认得她。"],["player","我回来了。上次没能听清的祈愿，这次我想再听一遍。"],["goddess","好。但别忘了，你也在这份祝祷里。"]],goddess)
		&"intro_weapon":
			scene.title="序章 · 掌心的祷光";scene.lines=lines([["","晶石牵着一具骸骨从灌木里站起。希露媞雅没有向它伸手，先看清了绕在骨节上的黑丝。"],["player","这不是它自己的意愿。请让我先解开束缚。"],["goddess","有些锁只能在战斗中打开。工具在手边，不必空着双手承担一切。"],["","她拾起旧法器，让温暖的祷光凝成一枚小小灵珠。光没有许诺无所不能，只陪她迈出第一步。"]],goddess)
		&"death_first",&"death_repeat":
			scene.title="余辉尚在";scene.lines=lines([["","最后的光没有熄灭，只从她的掌心缓缓退回祭袍。再睁眼时，伊莉丝已经伸出手。"],["player","我没能走到他们身边。"],["goddess","这不意味着你必须留在那里。回来，也是你答应过自己的事。"],["","她合掌，没有为失败找一个更宏大的名字。下一次，会先看清脚下。"]],goddess)
		&"death_hall",&"death_hall_intro",&"death_reenter":
			scene.title="圣云回廊";scene.lines=lines([["","回廊的风掠过金丝云纹。希露媞雅把掌心的圣光放进一盏空灯，让疲惫的人也能慢慢认路。"],["goddess","这里可以休息。你的祷词，也不必时时为别人而说。"],["player","那今晚，愿归来的人都睡得安稳。包括我。"]],goddess)
		_:
			var value:=int(str(id).trim_prefix("cp_"))
			if CHAPTER.has(value):scene.title=CHAPTER[value][0];scene.lines=lines(CHAPTER[value][1],goddess)
	# Keep the shared choices' effects/next IDs while removing obsolete persona.
	for choice in scene.get("choices",[]):
		if choice.has("text"):choice.text=str(choice.text).replace("火焰法器","祷光法器")
		if choice.has("reply"):
			for line in choice.reply:
				if str(line.get("text","")).contains("帽檐"):line.text="希露媞雅拢好银发，向门外的晨光迈出一步。"
	return scene
