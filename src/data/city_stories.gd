class_name CityStories
extends RefCounted
## Ten stable chapter-local checkpoints; choices change only dialogue.
const IDS:Array[StringName]=[&"city_entry",&"city_clue_2",&"city_clue_4",&"city_sephra_before",&"city_sephra_after",&"city_verena_before",&"city_verena_after",&"city_nameless_before",&"city_nameless_after",&"city_return"]
const ROOT:="res://assets/chapter2/portraits/verena_"
const TITLES:=["无人应门","灯下无名","完美的昨日","归城之印","被护送的囚徒","千页之下","不再归档的声音","无名录仪","允许明天到来","把明天带回回廊"]
const FACTS:=[
	["潮汐之根沉寂后，残留黑晶的微光仍指向一座银灰旧城。城门敞着，门牌上却没有一个名字。","旅人，请停在灯光里。我是记录官维蕾娜。归城名册记得每一个来过的人，却已经很久没有登记离开的人了。","这座城曾替逃难者保存姓名。我当年协助建立的撤离信标，也接入过这里。如今信标只接收，不再放行。"],
	["岗亭里放着三碗早已冷透的汤。墙上轮值表每日更新，笔迹与污痕却完全相同。","巡卫称离城者为‘遗失者’。它们把护送理解成送回城门，把归乡理解成永远停留。","请找到归城名册。也许其中还留着一条允许旅人自行填写的出城记录。"],
	["第四处街灯下，昨日破碎的花瓶再次完好。灾难没有重来，重来的只是关于灾难前一日的记录。","保存一个人，原本应当让她在废墟中找回家人。我们后来却写下了另一条指令：任何改变，都可能造成遗失。","我参与过那份承诺。现在，我自己的声音也被编入了回放。"],
	["归城关隘的门印逐格亮起。执印巡卫抬起长戟，刃口仍朝着曾经需要护送的人。","塞芙菈曾护送最后一批居民撤离。她记得‘不能留下任何人’，却忘了道路应当通向城外。","离城申请未通过。请返回姓名所属的居所。此次护送，不接受拒绝。"],
	["长戟垂落。门印失去命令，显露出下方早已磨损的撤离路线。","原来路还在……我把门守了这么久，却没有问过门后的人想去哪里。","你没有抹去她。只是让‘保护’重新听见了被保护者的回答。"],
	["静默藏名馆的书页自行翻动。维蕾娜的投影第一次拥有了实体，也第一次无法控制自己的双手。","归档职责接管中。未经批准的未来，将被视作记录损坏。","如果我的声音让你留下，请听清是谁在说话。请打断这条命令，不必毁掉所有书页。"],
	["封蜡裂开。司书俯身拾起散落的名册，没有再把其中的人压回原来的位置。","我记得自己的错，也想保留改正它的机会。那些录下来的声音，不应被当作他们永不改变的同意。","城心的无名录仪还在强制归档。关闭那条回路，愿意留下的记录仍可以保存。"],
	["穹顶中浮着无数没有署名的星页。录仪把每一条可能通向明日的轨迹，折回昨日的坐标。","交还你现在的名字，即可取回最初的归所。变化终将失去；保存不会背弃。","别让它替所有人回答。受损的记忆未必能修复，但选择不该因此一同被封存。"],
	["强制归档回路停止。损坏的页码没有奇迹般复原，但愿意留下的记录仍在灯下。","我选择记得，也允许别人选择遗忘。那些想走的人，现在可以走了。","我曾相信保存足够久，就能等到一切恢复。今天我才知道，希望也要给明天留出地方。"],
	["回廊的灯接住归来的旅人。带回来的不是完整的昨日，而是一页可以继续书写的空白。","维蕾娜已经重新署名。星城不再重复昨日，自愿保存的记录由居民自己决定如何开启。","名册背面记着更远地区的航路。那条路还需要准备；今天，先把自己的名字带回家。"]
]
const HERO:={
	"sylphiette":["希望应当照见每一个不同的祈愿。我会听她们亲口回答。","灯还亮着，但有人在灯下等得太久了。","保存过去不该成为拒绝明天的理由。","若守护使人无法离开，就让圣光先照清这道命令。","愿她记得自己救过的人，也能听见他们告别。","我会分清你的祈愿与它的命令。请等我。","你有权修正承诺，不必与错误一起被毁掉。","我不会替他们选择忘记，也不会替他们选择永远留下。","让每一种祈愿保留自己的声音。这才是我愿守护的希望。","我没能找回所有失去，但我会守住每个人选择如何面对失去的权利。"],
	"xixifu":["记录会回应呼唤，可回应不一定是自愿同行。我会仔细听。","这些回放没有休息。声音也需要被允许安静。","完整的声音，不等于一份永远有效的契约。","伙伴若想回家，我不会用‘保护’把她留下。","护送应有终点。告别不是背叛。","维蕾娜，和我说话。让命令知道你的名字还属于你。","如果你愿意，我们走到下一段；不愿意，也可以告别。","我不会把被记录下来的同意，当作永不结束的约定。","让同行出于愿意，让告别也被尊重。灯会为离开的人亮着。","我带回几段愿意被记住的声音。其余的，就让它们自由沉默。"],
	"ilyua":["名字不只是归处，也写在我今天结识的人心里。","街上没有脚步，却处处有人生活过的痕迹。","种子若必须长得和昨日一样，就不再算生长了。","故乡的门也不该把回来的人锁住。","路通了。愿她下一次守门，是为归来的人留灯。","你告诉我怎样进城。现在，换我陪你走出命令。","在记录之外长出一片新叶，也值得被允许。","故乡很珍贵，但我不会交出今天的名字。我还记得现在同行的人。","旧城的石缝里有一粒种子。它的明天，不必写在任何名册里。","我把那粒种子留在城里。等我们再去，愿它已长成记录里没有的新芽。"]
}
static func scene(id:StringName,repeated:=false,character_id:StringName=&"")->Dictionary:
	var index:=IDS.find(id)
	if index<0:return {}
	var character:Dictionary=Characters.DATA.get(character_id,Characters.current())
	var profile:=str(character.id)
	if not HERO.has(profile):profile="sylphiette"
	var pose:="controlled" if index in [5,7] else "regret" if index in [2,6] else "doubt" if index in [1,3] else "relief" if index>=8 else "calm"
	var lines:Array=[]
	if repeated:
		lines=[{"who":"","text":"再次来到失名星城。旧日的回声还在，但这一次，你知道自己为何前行。"}]
	else:
		lines.append({"who":"","text":FACTS[index][0]})
		var speaker:="塞芙菈" if index==4 else "无名录仪" if index==7 else "维蕾娜"
		lines.append({"who":speaker,"text":FACTS[index][1],"portrait":ROOT+pose+".png" if speaker=="维蕾娜" else ""})
		lines.append({"who":Story.GODDESS if index in [0,4,7,8,9] else "塞芙菈" if index==3 else "维蕾娜","text":FACTS[index][2],"portrait":ROOT+pose+".png" if index in [1,2,5,6] else ""})
	lines.append({"who":str(character.name),"text":HERO[profile][index],"expression":"determined"})
	var choices:Array=[]
	if index in [0,2,6,8]:
		choices=[{"text":"记下这份回答。","reply":[{"who":"维蕾娜","text":"这一次，记录由你自己署名。","portrait":ROOT+pose+".png"}],"next":&""},{"text":"让接下来的行动回答。","reply":[{"who":str(character.name),"text":"我们继续。","expression":"determined"}],"next":&""}]
	return {"title":"第二章 · "+TITLES[index],"portrait":ROOT+pose+".png","lines":lines,"choices":choices,"next":&""}
