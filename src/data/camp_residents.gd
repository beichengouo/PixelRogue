class_name CampResidents
extends RefCounted
const ROOT := "res://assets/camp_life_v01/"
const DATA := {
	"surveyor":{"name":"希尔薇娅","role":"林地采样员","home":"contracts","offset":[-90,60],"contract":"survey","rest":"翻阅采样手册","greeting":["这片森林的叶芽、琥珀和碎晶，会把不同地方的变化写在身上。","我叫希尔薇娅，负责替回廊记下这些变化。愿意在旅途中替我带回三份样本吗？"],"accepted":["我已经把你的名字记在采样册里。","样本带回仓库后，再来这里找我就好。一路上先照顾好自己。"],"finished":["叶芽还带着晨露，琥珀也没有破损……你把三个地方的声音都带回来了。","谢谢。这份记录会交给姜糖，后续调查也有了依据。报酬已存入金库。"],"chat":"等风停一停，我才能听清叶子的声音。"},
	"carpenter":{"name":"布琳娜","role":"回廊木匠","home":"warehouse","offset":[100,55],"contract":"daily_repairs","rest":"雕刻木片","greeting":["别踩那片木屑，我正给姜糖修新的货架。","布琳娜。回廊里会吱呀作响的东西，多半归我管。苔纹织片和林脂凝晶能让木架更结实。"],"accepted":["三份织片、两份凝晶，记得先带回仓库。","我会把榫头先做好。等你回来，我们就能把这一格货架装上。"],"finished":["刚刚好。你摸摸看，这个接头现在一点也不晃了。","姜糖答应的报酬已经存进金库。今天这份就到这里，明天若有新活，再来找我。"],"chat":"木头也会累，削得太急，反而容易裂开。"},
	"herbalist":{"name":"艾莉娅","role":"回廊采药师","home":"relations","offset":[200,-70],"contract":"daily_soup","rest":"辨认药草","greeting":["温阮的锅里还缺一味焰光菇。雨夜回来的旅人，喝一碗热汤能暖很久。","我叫艾莉娅，替她挑药草，也替旅人看一看那些不能逞强的小伤。"],"accepted":["两份焰光菇，撤回后放进仓库，再交给我。","别为了这锅汤冒险。温阮宁愿晚一点开火，也不愿少一个回来的人。"],"finished":["菌褶很完整，香气也对。谢谢，我这就送去温阮那里。","锅边的位置一直留着。报酬进金库了，今晚记得好好休息。"],"chat":"有些草药看起来很像。认不准，就别急着入口。"},
	"minstrel":{"name":"闻铃","role":"旅途吟游者","home":"result","offset":[130,95],"contract":"","rest":"吹奏短笛","greeting":["我是闻铃。每个回到这里的人，都会替我的曲子添一个音。","今天不收金币，也没有委托。若你暂时想不起下一步，就站在灯下听一会儿。"],"chat":"这段调子没有结尾，归来的人还在往里填故事。"}
}
static func contract_index(id:String)->int:
	for index in ExpeditionData.CONTRACTS.size():
		if str(ExpeditionData.CONTRACTS[index].id)==str(DATA.get(id,{}).get("contract","")):return index
	return -1
static func issuer_name(contract:Dictionary)->String:
	return str(DATA.get(str(contract.get("issuer","")),{}).get("name",BondRules.NAMES.get(str(contract.owner),str(contract.owner))))
static func progress(id:String)->String:
	var index:=contract_index(id)
	if index<0:return "none"
	var contract:Dictionary=ExpeditionData.CONTRACTS[index];var status:=Outpost.contract_status(contract)
	if status=="accepted":
		for item in contract.needs:
			if int(Outpost.data.get("inventory",{}).get(item,0))<int(contract.needs[item]):return "accepted"
		return "ready"
	return "available" if status=="available" else "none"
