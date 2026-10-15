class_name IlyuaStories
extends RefCounted

## Character-local chapters use the same shared triggers and choice consequences.
const CHAPTER := {
10:["被剪断的叶脉",[
["","伊露雅捡起一片新叶。叶尖还绿着，黑晶却沿叶脉把它钉在石头上。她没有扯，只用箭尖挑开最细的一缕晶丝。"],
["player","树没有让它留下。是这些东西不肯让它落下。"],
["goddess","你听见的低语，和别人听见的不同。"],
["player","不是每一句都清楚。但它疼的时候，我知道。"],
["","她把叶子放回湿土，记住晶丝伸来的方向。"]]],
20:["弓背上的藤纹",[
["","遗迹里的风吹响了弓背的刻纹。伊露雅用拇指遮住缺了一角的藤叶，声音便停了。"],
["player","有人教过我这样认路。风从叶纹里穿过去，就不会认错回家的方向。"],
["goddess","你想起那个人了吗？"],
["player","还没有。只记得他从不让我折活枝做箭。"],
["","她松开拇指。轻轻的一声长鸣，替墙上那些被划去的名字留出了位置。"]]],
30:["留给守卫的出口",[
["","骸王的指骨仍扣着门徽。伊露雅搭箭，最后却没有射向那只手，而是瞄准徽记背面的黑晶结。"],
["","晶结碎开，紧扣的骨指终于松了。门后吹来一缕凉风。"],
["goddess","它的守护被改成了不准任何人离开。"],
["player","连它自己也不能走，对吗？"],
["","伊露雅把门徽摆正，给守卫让出一条通往门外的小路。她不知道它还能不能看见。"]]],
40:["风不会催促",[
["","风中有人唤她的名字，像记忆里那位教她拉弓的人。每一声都催她摘下兜帽、走向晶石。"],
["player","以前的风，会等我把箭收好。"],
["goddess","你不想听完它说什么？"],
["player","想。所以更要先看清它从哪里来。"],
["","她朝声源射出一支光箭。晶丝应声断裂，树梢真正的风才迟迟赶到。"]]],
50:["可以离开的誓言",[
["","巨树从雾里露出。伊露雅记起自己曾在树下许过愿：只要林地需要，她就不会离开。"],
["player","如果这句话也成了一道锁呢？"],
["goddess","你现在可以重新想一想，它原本想保护什么。"],
["","她握住白色袍袖里的弓弦，没有答应风中传来的第二遍誓言。"],
["player","我会回来照顾它。但回来，应该是我自己愿意。"]]],
60:["树木的呼吸",[
["","巨影散去，藤蔓还裹着一截晶壳。伊露雅等了片刻，把光箭射进壳上的裂隙，避开仍然鲜活的根。"],
["player","它们没有在进攻。它们还以为自己在保护树。"],
["goddess","命令消失以后，旧的习惯不会立刻停下。"],
["","松开的藤须缓缓垂到地面。她退开几步，让根尖自己找到湿土。"],
["player","那就给它一点时间。别再拿新的命令替它呼吸。"]]],
70:["兜帽下面",[
["","潮湿的兜帽压住了耳尖。伊露雅抬手又放下，直到伊莉丝看向树梢，她才轻轻揭开帽沿。"],
["player","以前走进人多的地方，我总先把耳朵藏好。这样，问路的人会先看我的弓。"],
["goddess","在这里，你不用先证明自己像谁。"],
["","她理好脸侧的两缕浅绿头发，把兜帽重新搭回去，却没有再压得那么低。"],
["player","等记起回家的路，我也想记住那些肯替我指路的人。"]]],
80:["不借来的名字",[
["","晶石响起精灵的旧称，许诺只要回答，就能让她想起故乡。伊露雅没有应声，只在弓背刻下一道浅痕。"],
["goddess","你不怕错过自己的过去？"],
["player","怕。但今天是我挑断了那片叶子的晶丝。这个名字，已经有我记得的事了。"],
["","她把渐渐舒展的叶子夹在腰带内侧。"],
["player","伊露雅。先从这里认路。"]]],
90:["别把整座林地背走",[
["","深处的树根同时求救。伊露雅向前一步，白袍下摆就被晶丝牵住，弓弦也传出不属于她的震动。"],
["goddess","停下。它在把你的回应编进最后一道锁。"],
["player","我听见了。可我不能用自己，堵住它唯一的出口。"],
["","她割断袍角，退到能看清根结的位置。绿光沿弓弦亮起，没有指向求救的根尖。"],
["player","先剪开绑住它的东西。剩下的，我们慢慢来。"]]],
100:["第一片自由落下的叶",[
["","潮汐之根安静下来。一片叶子从枝头落下，没有晶丝把它拽回去。伊露雅接住它，终于听见完整的林风。"],
["player","它说，可以走了。也可以再回来。"],
["","她将叶子放进腰带内侧，那里已经收着一枚小种子。白色兜帽下，湖蓝的眼睛望向门外。"],
["goddess","你仍然没有想起故乡的方向。"],
["player","嗯。但我知道，认路的人不必一直一个人走。"],
["","她放低短弓，把空着的手递向星辉。门外的风没有催促她。"]]]
}

static func _lines(entries:Array,goddess:String)->Array:
	var result:Array=[]
	for entry in entries:result.append({"who":goddess if entry[0]=="goddess" else entry[0],"text":entry[1]})
	return result

static func _choices(scene:Dictionary,texts:Array,replies:Array,goddess:String)->void:
	for index in mini(scene.get("choices",[]).size(),texts.size()):
		scene.choices[index].text=texts[index]
		scene.choices[index].reply=_lines(replies[index],goddess)
static func apply(original:Dictionary,id:StringName,repeated:bool,goddess:String)->Dictionary:
	var scene:=original.duplicate(true)
	_replace_identity(scene)
	scene.erase("lines_repeat")
	match id:
		&"intro_wake":
			scene.title="伊露雅 · 林风苏醒"
			scene.lines = [
				{"text":"白色兜帽上落了一片叶子。伊露雅坐起身，先摸到腰间的藤纹短弓，再顺着树梢寻找风的来处。"},
				{"who":goddess,"text":"先别走。你刚从死亡那边回来。"},
				{"who":"player","text":"风还在，可我不记得自己怎么来到这里。我的弓呢？"},
				{"who":goddess,"text":"我是伊莉丝。这里是苏醒林地。先确认你能握住弓，之后我们再找答案。"},
				{"text":"伊露雅把兜帽拉低。林间的气息熟悉，树根下的黑色晶丝却让她停住了脚步。"},
			]
			if repeated:
				scene.lines = [
					{"text":"伊露雅又在同一片苔藓旁醒来。她扶住白色兜帽，指尖先摸到熟悉的弓弦。"},
					{"who":goddess,"text":"你回来了。还记得路吗？"},
					{"who":"player","text":"记得。那些晶丝藏在哪里，我也记得。这回让箭先找到它们。"},
					{"who":goddess,"text":"好。先拿上弓，照你记得的方向走。"},
				]
			_choices(scene,["你为什么认得我的名字？","我听见的低语是真的吗？","先别靠近，我需要看清这里。","怎样回到安全的地方？","分辨树梢和树根的声音。"],[
				[["goddess","星辉留住了你的名字。它找到你，我才能把你接住。"]],
				[["goddess","有些是真的，有些被晶石借走了。先看它把你引向哪里。"]],
				[["goddess","我会退后。你可以慢慢确认，也请留意灌木里的动静。"]],
				[["goddess","站稳后呼唤我。危险还在时要等得久一些；确认安全后，我会很快来。"]],
				[["","她听见叶子掠过枝梢，却听不见根须之间该有的呼吸。"],["player","先去看那片没有声音的地方。"]]],goddess)
		&"intro_weapon":
			scene.title="序章 · 第一支箭"
			scene.lines = [
				{"text":"枯枝折断。一具嵌着黑晶的骷髅从灌木里站起，藤蔓牵动它的手臂。"},
				{"who":"player","text":"那不是树木原本的力量。先挡住它，再看晶丝从哪里来。"},
				{"who":goddess,"text":"弓就在你手边。瞄准晶石，别让它靠近。"},
				{"text":"伊露雅拿起缠着藤纹的短弓。她拉开弦，一束浅绿的光取代了实体箭杆。"},
			]
			scene.choices=[{"text":"藤纹短弓 · 随风起箭","affinity":0,"flags":{&"start_weapon":"bow"},"give":&"bow_vine_short","reply":[{"text":"伊露雅搭上第一支箭，箭尖稳稳指向晶石。"}],"next":&""}]
		&"death_first":
			scene.title="断弦之后 · 还有风在"
			scene.lines=_lines([["","箭尖的绿光灭了。伊露雅伸手护住短弓，倒下时仍避开了脚边的嫩芽。"],["player","还没看清……晶丝从哪一根下面来。"],["","金色的光接住她。林风远去，另一个声音没有催她站起来。"],["goddess","先回来，伊露雅。那根弦，可以等你休息以后再拉。"]],goddess)
		&"death_hall":
			scene.title="星辉回廊 · 认路的人也会迷路"
			scene.lines=_lines([["","回廊里没有树木。伊露雅握着短弓，几次侧耳，才承认自己听不见熟悉的声音。"],["player","我一直靠它们认路。这里没有风，我该相信什么？"],["goddess","先相信你看见过的事。还有，愿意等你问完的人。"],["","她松开弓弦。兜帽的边缘没有再遮住全部视线。"]],goddess)
			_choices(scene,["树的记忆，也被取走了吗？","我是不是来得太迟了？","我不会把自己交给晶石。","怎样保护它们，又活着回来？","把走过的路刻在弓背上。"],[
				[["goddess","晶石留住了回声，却不让树木自己回应。你已经分辨过一次。"]],
				[["goddess","还有新芽在生长。先养好你的伤，才有机会看见它们舒展。"]],
				[["player","我会剪开晶结。但不会再答应一个不许我退后的声音。"]],
				[["goddess","留出能撤回的路，别把魔力用尽。呼唤我时，也需要先站稳。"]],
				[["","箭尖在旧藤纹旁刻下一道浅痕。她只记路，不用新的纹路盖住旧的。"]]],goddess)
		&"death_hall_intro":
			scene.title="回廊的窗 · 带给你一点林风"
			scene.lines=_lines([["","回廊的衣摆从来不被风吹动。伊露雅把袍袖里的小叶片放到伊莉丝手边。"],["player","你在这里等了很久吗？"],["goddess","久到我有时要靠别人告诉我，外面的树是什么样子。"],["player","下次回来，我会记住叶子落下的声音。告诉你，哪片林地又能呼吸了。"],["","伊莉丝接过叶片，没有要求她一定回来，只让她先坐下来。"]],goddess)
		&"death_reenter":
			scene.title="再搭一支箭 · 不急着回答"
			scene.lines=_lines([["","藤纹仍然完整。伊露雅检查新刻的路标，把兜帽搭好，给耳尖留下一点余地。"],["player","如果有声音催我，我就先停下来。"],["goddess","也给自己留一条回来的路。危险中可以呼唤我，只是要等得久一点。"],["player","我知道。这次，也把你的名字记在路上。"]],goddess)
		_:
			if str(id).begins_with("cp_"):
				var chapter:=int(str(id).trim_prefix("cp_"))
				if CHAPTER.has(chapter):scene.title=CHAPTER[chapter][0];scene.lines=_lines(CHAPTER[chapter][1],goddess)
				if chapter==100:_choices(scene,["留在林地 · 照看尚未舒展的新芽","握住伊莉丝的手 · 带着种子回去"],[
					[["player","还有几处根没有松开。我想再走一段。"],["goddess","好。门一直开着，你不必再许一个不能离开的愿。"]],
					[["","她把弓收到腰侧，伸出空着的手。这次，离开没有违背任何誓言。"],["player","等种子长出叶子，我们再来认这条路。"]]],goddess)
	return scene

static func death_line(goddess:String)->Array:
	var pool:=["风没有责怪你。先把手上的伤养好。","弓背上的路还在。你不必今天就走完。","新芽在等一场雨，不是在催你独自回来。","迷路也可以问人，伊露雅。我会等你把话说完。"]
	return [{"who":goddess,"text":pool[Rng.stream().randi_range(0,pool.size()-1)]}]

static func _replace_identity(scene:Dictionary)->void:
	for key in ["lines","lines_repeat","choices"]:
		if not scene.has(key):continue
		for entry in scene[key]:
			if not entry is Dictionary:continue
			_replace_line(entry)
			if entry.has("reply"):
				for reply in entry.reply:
					if reply is Dictionary:_replace_line(reply)

static func _replace_line(entry:Dictionary)->void:
	if not entry.has("text"):return
	entry.text=str(entry.text).replace("希露媞雅","伊露雅").replace("帽檐","兜帽边").replace("魔法师","弓箭手").replace("法杖","短弓")
