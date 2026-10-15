class_name AltarBlessings
extends RefCounted
const LIMIT:=6
const RANK_LIMIT:=3
const DEFINITIONS:={
	"edge":{"name":"锋芒誓约","stat":&"attack","value":.04,"description":"攻击力增加4%"},
	"spring":{"name":"灵泉誓约","stat":&"mp_regen","value":.08,"description":"MP回复速度增加8%"},
	"step":{"name":"踏风誓约","stat":&"dash_cooldown","value":-.04,"description":"基础闪避冷却减少4%"}}
static func normalized(raw:Variant)->Dictionary:
	var result:Dictionary={};var available:=LIMIT
	for id:String in DEFINITIONS:
		var rank:=clampi(int(raw.get(id,0)),0,mini(RANK_LIMIT,available)) if raw is Dictionary else 0
		if rank>0:result[id]=rank;available-=rank
	return result
static func total(raw:Dictionary)->int:
	var count:=0
	for id in DEFINITIONS:count+=clampi(int(raw.get(id,0)),0,RANK_LIMIT)
	return count
static func apply_to(block:StatBlock,raw:Dictionary)->void:
	if CampSession.active:return
	for id in DEFINITIONS:
		var rank:=int(raw.get(id,0))
		if rank>0:block.add_mult(DEFINITIONS[id].stat,float(DEFINITIONS[id].value)*rank)
static func offers(raw:Dictionary,wave:int)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if total(raw)>=LIMIT:
		var bonus:=roundi(roundi(WaveTable.coin_reward(wave)*.6)*.5)
		result.append({"id":"altar_echo","altar_key":"echo","name":"祭坛回响","kind":&"buff","rarity":1,"flat":{},"mult":{},"cost":0,"icon":{"tex":"res://assets/room_expansion_v01/icons/altar.png","idx":-1},"desc":"本次出征已获得六级誓约。额外获得%d基础金币，沿用难度与操作模式收益规则。"%bonus})
		return result
	for id:String in DEFINITIONS:
		var rank:=int(raw.get(id,0))
		if rank>=RANK_LIMIT:continue
		var info:Dictionary=DEFINITIONS[id]
		result.append({"id":"altar_"+id,"altar_key":id,"name":str(info.name)+" · "+str(rank+1)+"级","kind":&"buff","rarity":1,"flat":{},"mult":{},"cost":0,"icon":{"tex":"res://assets/player_status_v01/altar_"+id+".png","idx":-1},"desc":str(info.description)+"／级\n本次出征永久，最高三级；所有誓约累计最多六级。\n当前 %d／3级 · 已获 %d／6级"%[rank,total(raw)]})
	return result
