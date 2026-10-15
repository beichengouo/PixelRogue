class_name CampStory
extends RefCounted
const INTRO = "回廊的灯火亮起时，你听见伊莉丝叫你‘契约者’。\n\n她能把希露媞雅从死亡那边带回，却不能把遗落的装备和物资一并找回。你留在灯火之内，为她准备下一趟旅途；她替你走进那片会吞掉记忆的森林。\n\n金币只能由真正撤回的收获换来。记住约定，比记住收益更重要。"
const EVENTS = {
	"merchant":[
		{"id":"meeting","title":"货架与归路","gain":2,"min":0,"require":"","lines":["姜糖把一枚星纹扣放到你手心，又笑着收了回去：‘先看看，不买也没关系。’","‘我卖的东西要经得住旅途，不是只在货架上好看。布琳娜帮我补木架，希尔薇娅帮我辨认材料。你缺什么，就直接告诉我。’","她将行囊摆正：‘账本我会记清楚，回来的位置也会留好。下一次见面，希望你有新的故事。’"]}
	],
	"tavern":[
		{"id":"meeting","title":"杯中的灯火","gain":2,"min":0,"require":"","lines":["温阮将茶杯推到灯下，没有催你开口。杯沿的热气慢慢散开。","‘艾莉娅会替我把药草挑好，闻铃会吹一点不那么吵的曲子。你若今天不想谈冒险，也可以只坐一会儿。’","她温柔地笑了笑：‘这里不只留给勇敢的人。疲惫的时候，也记得回来。’"]}
	],
	"sylphiette": [
		{"id":"meeting","title":"出发之前","gain":3,"min":0,"require":"","lines":["希露媞雅：‘你就是伊莉丝说的契约者？’她扶了扶帽檐，目光落在还空着的装备台上。","‘装备可以慢慢攒。先说好，别因为仓库空了就把自己也当成没用的人。’","你答应替她守着回廊的灯。她笑起来：‘那我会认得回来的方向。’"]},
		{"id":"promise","title":"兑现的约定","gain":4,"min":20,"require":"extraction","lines":["她把沾着露水的行囊放在桌上。金币尚未清点，她先看向你。","希露媞雅：‘这次我记得了。桥边的风、黑晶里的声音，还有你让我回来。’","你问她下一次想带什么。她没有看装备台：‘一句同样的约定就够了。’"]},
		{"id":"memory","title":"未褪色的花","gain":5,"min":50,"require":"survey","gift":true,"lines":["你将从森林带回的记忆花递给她。花瓣上有一线不会熄灭的微光。","希露媞雅：‘原来我不是只能把东西带回来的人。也有人会替我留下一点什么。’","她把花别在帽带内侧，耳尖微红：‘别盯着看。下次回来，再给你看。’"]},
		{"id":"close","title":"灯火旁的名字","gain":4,"min":100,"require":"deep","lines":["她读完黑晶的记录，没有立刻离开。你们之间的沉默不再需要解释。","希露媞雅：‘森林想让我忘掉的，可能不是过去……是我为什么还想回来。’","‘如果有一天我连自己的名字也忘了，你要先叫住我。’她向你伸出手，‘从现在开始练习吧。’"]},
	],
	"iris": [
		{"id":"meeting","title":"契约的另一端","gain":3,"min":0,"require":"","lines":["伊莉丝：‘你留在这里，不是因为你比她安全。是因为回廊需要有人记住出口。’","你问她契约的代价。她望向空着的灯盏：‘每次归来，我们都要重新证明，她仍然属于活着的这一边。’","‘别急着相信我。先把她带回来，再慢慢问。’"]},
		{"id":"return","title":"女神也会等待","gain":4,"min":20,"require":"extraction","lines":["撤离结束，伊莉丝还站在灯边。你第一次看见她松开握紧的手。","‘女神不会担心吗？’你问。她停了一会儿：‘这个称呼，不会让等待变得更轻。’","你替她添上灯油。她低声道：‘那下一次，陪我一起等。’"]},
		{"id":"truth","title":"黑晶与旧约","gain":5,"min":50,"require":"deep","lines":["伊莉丝将黑晶物证翻到背面，那里刻着与你的契约相同的符号。","‘森林忘却的不是偶然。有人在用记忆偿还一场早已结束的战争。’","你追问她为什么知道。她没有躲开你的目光：‘因为曾经签下第一个约定的人，是我。’"]},
		{"id":"close","title":"尚未说出口的愿望","gain":4,"min":100,"require":"echo","lines":["回廊回响停下时，伊莉丝暂时收起了女神的称呼，只在你身旁坐下。","‘如果遗迹内真的藏着答案……’她看着尚未开放的城门，‘我希望走进去的，不只是背负契约的人。’","你答应在答案之外替她留一个位置。她轻轻握住你的手：‘那就别忘记今天。’"]},
	],
}

static func available(npc: String, scene: Dictionary) -> bool:
	if Outpost.data.events.has(npc+":"+str(scene.id)): return false
	if int(Outpost.data.bonds.get(npc,0))<int(scene.min): return false
	var required = str(scene.get("require",""))
	if required=="extraction" and Outpost.data.best.is_empty(): return false
	if not required.is_empty() and required!="extraction" and not Outpost.data.contracts.has(required): return false
	if bool(scene.get("gift",false)) and int(Outpost.data.inventory.get("memory_gift",0))<=0: return false
	return true
