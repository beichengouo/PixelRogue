extends RefCounted
## Authoring metadata mirrors the entry/room-clear/camp call sites. These are
## chronology/availability hints, never executable dialogue jumps or save state.
const FOREST := ["intro_wake","cp_10","cp_20","forest_king_before","cp_30","cp_40","cp_50","forest_mage_before","cp_60","cp_70","cp_80","forest_tide_before","cp_100","stage_echo_entry"]
const FOREST_TRIGGERS := ["苏醒林地新出征进入出生房后","第一阶段清理第2个普通／精英房后","第一阶段清理第4个普通／精英房后","进入林地王Boss房，战斗开始前","击败林地王后","第二阶段清理第2个普通／精英房后","第二阶段清理第4个普通／精英房后","进入晶纹术士Boss房，战斗开始前","击败晶纹术士后","第三阶段清理第2个普通／精英房后","第三阶段清理第4个普通／精英房后","进入潮汐之根Boss房，战斗开始前（包含旧cp_90内容）","击败潮汐之根后，本章收束","进入第四阶段后（两章均可触发）"]
const CITY_TRIGGERS := ["失名星城新出征进入出生房后","本次出征累计清理第2个普通／精英房后","本次出征累计清理第4个普通／精英房后","进入塞芙菈Boss房，战斗开始前","击败塞芙菈后","进入维蕾娜Boss房，战斗开始前","击败维蕾娜后","进入无名录仪Boss房，战斗开始前","击败无名录仪后","星城完成后成功撤回营地，当前角色归航标记尚未消费时"]

static func ids()->Array:
	var found:Dictionary={}
	for id in Story.SCENES:found[str(id)]=true
	var narrative:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/narrative_v11.json"))
	if narrative is Dictionary:
		for id in narrative:found[str(id)]=true
	for npc in CampStory.EVENTS:
		for event:Dictionary in CampStory.EVENTS[npc]:found["camp:"+str(npc)+":"+str(event.id)]=true
	for row:Dictionary in CampCommissionCatalog.DATA:
		for phase in ["offer","accepted","finished"]:found["commission:"+str(row.id)+":"+phase]=true
	for id in CityStories.IDS:found[str(id)]=true
	found["fate_observation"]=true
	var result:Array=found.keys();result.sort();return result

static func metadata()->Dictionary:
	var result:Dictionary={}
	for i in FOREST.size():
		result[FOREST[i]]=_row("chapter1","第一章 · 苏醒林地",i,FOREST_TRIGGERS[i],[] if i==0 else [FOREST[i-1]])
	for i in CityStories.IDS.size():
		var id:=str(CityStories.IDS[i])
		result[id]=_row("chapter2","第二章 · 失名星城",i,CITY_TRIGGERS[i],[] if i==0 else [str(CityStories.IDS[i-1])])
	result["stage_echo_entry"].categories=["chapter1","chapter2"]
	result["stage_echo_entry"].after=["cp_100","city_nameless_after"]
	result["stage_echo_entry"].order=99
	var titles:Dictionary={}
	for npc in CampStory.EVENTS:
		for event:Dictionary in CampStory.EVENTS[npc]:titles["camp:"+str(npc)+":"+str(event.id)]=str(event.title)
	for npc in CampStory.EVENTS:
		var who:=str(BondRules.NAMES.get(npc,npc))
		for i in CampStory.EVENTS[npc].size():
			var event:Dictionary=CampStory.EVENTS[npc][i]
			var previous:=str(event.get("previous",""));var after:Array=[]
			var when:="营地与"+who+"交谈；好感≥"+str(event.get("min",0))+"；未完成时可触发，完成后可回看"
			if not previous.is_empty():
				var prior:="camp:"+str(npc)+":"+previous;after.append(prior);when+="；先完成「"+str(titles.get(prior,previous))+"」"
			var required:=str(event.get("require",""))
			var gate:String={"extraction":"至少有一次成功撤离记录","forest_clue":"当前英雄看过cp_10或已完成采样委托survey","forest_clear":"苏醒林地已通关","city_clue":"当前英雄看过city_clue_2或失名星城已通关"}.get(required,"已完成委托 "+required)
			if not required.is_empty():when+="；"+gate
			if bool(event.get("gift",false)):when+="；仓库持有记忆礼物"
			result["camp:"+str(npc)+":"+str(event.id)]=_row("camp","营地 · "+who,i,when,after)
	for row:Dictionary in CampCommissionCatalog.DATA:
		var id:=str(row.id);var issuer:=CampResidents.issuer_name(row)
		var previous:=str(row.get("require",""));var prerequisite:="；先完成委托「"+previous+"」" if not previous.is_empty() else ""
		var group:="委托 · "+issuer
		result["commission:"+id+":offer"]=_row("commissions",group,0,"找"+issuer+"聊这份委托／接取时"+prerequisite,[] if previous.is_empty() else ["commission:"+previous+":finished"])
		result["commission:"+id+":accepted"]=_row("commissions",group,1,"接取委托并成功保存后；接取时依次播放洽谈与登记对白",["commission:"+id+":offer"])
		result["commission:"+id+":finished"]=_row("commissions",group,2,"在"+str(row.get("hours",72))+"小时内将材料成功撤离入库，找"+issuer+"交付且保存成功后；已完成时可回顾",["commission:"+id+":accepted"])
	result["fate_observation"]=_row("camp","营地 · 命运观测",0,"营地命运观测入口；看过后以重访演出",[])
	for id in ids():
		if not result.has(id):result[id]=_row("records","回廊／兼容记录",0,"旧流程兼容／回忆记录；不属于当前房间流程的固定触发节点",[])
	result["death_first"].trigger="第一次战败时（已完成后改用随机短句）"
	result["cp_90"].trigger="旧第三阶段检查点；当前内容并入forest_tide_before，不再单独排入清房队列"
	result["intro_weapon"].trigger="已移除的旧装备教学，仅保留兼容ID"
	return result

static func _row(category:String,group:String,order:int,trigger:String,after:Array)->Dictionary:
	return {"category":category,"group":group,"order":order,"trigger":trigger,"after":after}
