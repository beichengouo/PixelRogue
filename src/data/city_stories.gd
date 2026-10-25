class_name CityStories
extends RefCounted
## Stable chapter-local checkpoints; choices change presentation only.
const IDS:Array[StringName]=[&"city_entry",&"city_clue_2",&"city_clue_4",&"city_sephra_before",&"city_sephra_after",&"city_verena_before",&"city_verena_after",&"city_nameless_before",&"city_nameless_after",&"city_return"]
const ROOT:="res://assets/chapter2/portraits/verena_"
const TITLES:=["到城里核对编号", "城门没有出城记录", "被重复的一天", "先让守卫放行", "去书馆找登记原件", "打断控制维蕾娜的命令", "最后的控制装置", "记忆不是交换条件", "让居民自己填写去向", "带回能核对的记录"]
const FACTS:=[
	[
		"林地晶片上的编号与城门铭牌一致。失名星城曾登记逃难者的身份、安排撤离；此行要查登记原件，也找与四人过去相关的线索。",
		"我是记录官维蕾娜。这是我的投影，我本人在城里的藏名书馆。先提醒你：城门能进，守卫却不肯放人出去。",
		"藏名书馆就是保管姓名与迁移记录的地方。要进书馆，先找到城门守卫塞芙菈使用的门印。"
	],
	[
		"岗亭的登记本每天都写着同样的日期。入城栏有名字，出城栏却被一层晶纹盖住；守卫将所有想离开的人送回城内。",
		"以前我们用这本名册帮走散的人找家。后来加了一条“不能遗失任何人”，守卫就把出城也当成遗失。",
		"去前面的街灯看看，那边有归档装置送来的登记副本。我们需要知道规则究竟改了哪些地方。"
	],
	[
		"街灯下的花瓶反复恢复原样，摔碎的声音也一模一样。重演的是保存的记录，不是灾难重新发生，更不是她忘掉了刚才的经历。",
		"我参与加过“未经批准不得修改记录”的限制，当时想防止资料损坏。现在装置连人的新选择也当成错误。",
		"副本里有一条与你们旧物相似的路线标记，原件在书馆。先通过塞芙菈把守的关隘，不要把这里的回放直接当记忆。"
	],
	[
		"塞芙菈举起长戟，门印随动作亮起。她曾负责护送居民撤离，现在却按被改过的规则阻拦所有人。",
		"停止。离城登记未获批准，我必须把你送回住所。",
		"她在重复护送命令，没有读取新的申请。需要先击败她，解除门印的封锁，才能前往书馆。"
	],
	[
		"门印熄灭，墙上的旧撤离路线重新显出。塞芙菈放下长戟，第一次看向通往城外的箭头。",
		"我记得这里原本通向城外。我一直在把人送回去……先走吧，我得重新检查巡卫的命令。",
		"维蕾娜的投影指向书馆：原始名册在里面。先查路线和编号，也查谁删掉了停止条件。"
	],
	[
		"书馆的记录页自动翻动，维蕾娜的双手被晶纹牵住。她本人开始重复装置的命令，无法控制自己的攻击。",
		"归档规则正在接管我。别靠近我的手，先打断连着书架的晶纹！",
		"她仍能短暂提醒来人躲避。击败受控的维蕾娜即可打断接管，不需要毁掉名册或把她当成幕后主使。"
	],
	[
		"晶纹断开，维蕾娜放下武器。她取出两份原件，改动前后的文字、日期和笔迹都能相互对照。",
		"谢谢，我能自己动了。我修改过限制，这份责任我会记着。可后来删掉停止条件的人，原件上没有署名。",
		"最上层的无名录仪仍在强制执行旧命令。那是处理全城登记的装置，关闭强制回路后，居民才能自行改名和离城。"
	],
	[
		"无名录仪悬在穹顶中央，控制城里的登记回路。它播放与四人旧经历相似的片段，要求访客先放弃现在的身份和记录。",
		"接受原始登记，即可恢复旧日归属。请交回现有姓名与后续记录。",
		"片段的真伪尚未核对，代价却已经写明。她决定关闭强制回路，保留能够自愿查阅的资料，而不是拿今天的生活换一段不确定的过去。"
	],
	[
		"强制回路停止，街上的回放逐渐安静。名册仍在，居民可以留下记录，也可以修改登记后离开。损坏的记忆并没有自动恢复。",
		"我会把修改与离城的权限交还给登记人。你们的路线副本也整理好了，带回去和本人一起核对。",
		"她把副本收好。本章三个阶段已经完成；成功撤离才能带回本趟物资，也可以自愿进入第四阶段挑战三道首领旧影，风险仍由自己承担。"
	],
	[
		"成功归来后，契约者接过路线副本。你们分别写下想起的细节，再把吻合和不吻合的地方标出来。",
		"星城有些撤离信标确实由我参与建立。但共同标记只证明系统有联系，不能说明是谁改了命令。关于你们失忆的原因，也还需要更多证据。",
		"两章调查找到的记录已经能够继续核对，四人的共同经历可在营地逐步谈清。更远的航路尚待准备；今天先休息，不用立刻再出发。"
	]
]
const HERO:={
	"sylphiette": [
		"知道了，先找门印和原件。有关我们的事，我会带回去一起核对。",
		"原来这些人不是不想走，是一直没获准。我先查清楚怎么解除。",
		"你肯说明改过什么，很有帮助。先带我去关隘吧。",
		"我会停下门印的控制。受伤了我也会撤开，不会硬接。",
		"先休息一下。巡卫的事可以改，我们去找原件。",
		"我听见了。你尽量护住自己，我来打断晶纹。",
		"先坐好，别急着替所有人整理。我去关掉剩下的装置。",
		"我想找回以前的事，但不会为了未经核对的片段，抹掉现在认识的人。",
		"能自己填写就好。把副本收好，我们也该回去了。",
		"今天的茶还热吗？记录等会儿一起看，我先想和你坐一会儿。"
	],
	"xixifu": [
		"投影不是你本人，对吧？好，我会分清楚。小扣，先跟我去找门印。",
		"出门都算走失，难怪它们忙个不停。那条规则得改。",
		"我会先核对。再熟悉的声音，也得能回答我才行。",
		"我们不是走失的小孩。小扣，绕过长戟，看准再上。",
		"谢谢。等你理清命令，记得也让巡卫自己休息。",
		"听见了，我不会把它说的话都当成你。先躲远一点。",
		"等我回来再道谢吧。小扣已经找到往上的路了。",
		"我不会拿现在的伙伴换一份旧名单。想起以前，也不该这样交换。",
		"总算能自己说要去哪儿了。我们先把这份副本带回去。",
		"我记下好多事，得慢慢讲。先吃饭行吗？你也坐下。"
	],
	"ilyua": [
		"地图给我看一眼。先开路，再去书馆核对，顺序很清楚。",
		"路明明在，命令却不让走。先找控制它的装置。",
		"至少知道回放是怎么来的了。旧记忆还得另找证据。",
		"我不住这里，也没同意你替我登记。让开，或者我打断门印。",
		"走吧。能改就从今天改，不用站在这里一直道歉。",
		"我看到晶纹了。别动，我们先把你从它手里拉出来。",
		"资料留下，错字改掉。上面的装置我去处理。",
		"我会找故乡，也会找回过去。但今天认识的人，我一个也不拿去交换。",
		"出口通了。这次大家想去哪儿，都能自己走。",
		"副本带回来了。先确认我们都记得什么，别又空着肚子熬夜。"
	]
}
const HERO_EXPRESSIONS := ["neutral","thoughtful","thoughtful","determined","neutral","determined","neutral","determined","happy","happy"]
static func scene(id:StringName,repeated:=false,character_id:StringName=&"")->Dictionary:
	var index:=IDS.find(id)
	if index<0:return {}
	var character:Dictionary=Characters.DATA.get(character_id,Characters.current())
	var profile:=str(character.id)
	if not HERO.has(profile):profile="sylphiette"
	var pose:="controlled" if index==5 else "regret" if index in [2,6] else "doubt" if index in [1,3] else "relief" if index>=8 else "calm"
	var entries:Array=[]
	if repeated:
		entries=[{"who":"","text":"她回到回廊，和你补充核对星城记录；先前的关系选择仍然有效。" if index==9 else str(character.name)+"再次调查失名星城的残存记录。先前获释的人没有重新受困，她也记得之前的旅途；这次继续核对尚未查清的线索。"}]
	else:
		entries.append({"who":"","text":FACTS[index][0]})
		var speaker:="塞芙菈" if index in [3,4] else "无名录仪" if index==7 else Story.GODDESS if index==9 else "维蕾娜"
		var expression:="sad" if index in [2,5,6] else "happy" if index in [4,8,9] else "neutral"
		entries.append({"who":speaker,"text":FACTS[index][1],"expression":expression,"portrait":ROOT+pose+".png" if speaker=="维蕾娜" else ""})
		# Tactical goals are narration, not an omnipresent contractor or goddess voice.
		entries.append({"who":"","text":FACTS[index][2]})
	entries.append({"who":str(character.name),"text":HERO[profile][index],"expression":HERO_EXPRESSIONS[index]})
	var choices:Array=[]
	if index in [0,2,6,8]:
		choices=[{"text":"记下已确认的线索。","reply":[{"who":str(character.name),"text":"已确认和待核对的分开记，这样回去才说得清。","expression":"neutral"}],"next":&""},{"text":"按刚才的目标继续。","reply":[{"who":str(character.name),"text":"好，先做眼前这一步。","expression":"neutral"}],"next":&""}]
	return {"narrative_revision":ContractorNarrative.REVISION,"title":"第二章 · "+TITLES[index],"portrait":"","lines":entries,"choices":choices,"next":&""}
