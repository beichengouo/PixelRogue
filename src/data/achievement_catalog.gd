class_name AchievementCatalog
extends RefCounted
const ROOT:="res://assets/achievements_v01/"
const BASE:={
"first_room":{"name":"破晓之径","description":"首次清理一间战斗房间。穿越初战的阴影，让归途迎来第一缕晨光。","metric":"rooms","goal":1,"category":"探索"},
"rooms_ten":{"name":"林境巡守","description":"累计清理十间战斗房间。以脚下的道路为誓，守望林境深处未熄的星火。","metric":"rooms","goal":10,"category":"探索"},
"kills_hundred":{"name":"百战初铭","description":"累计击败一百名敌人。将初成的战意铭入长夜，留下属于旅人的战勋。","metric":"kills","goal":100,"category":"战斗"},
"kills_fivehundred":{"name":"群影终息","description":"累计击败五百名敌人。令徘徊林地的群影归于沉寂，续写不屈的征途。","metric":"kills","goal":500,"category":"战斗"},
"first_boss":{"name":"初碎王权","description":"首次击败一位首领。越过强敌的王座，让前路不再屈从于威压。","metric":"bosses","goal":1,"category":"战斗"},
"three_bosses":{"name":"三冠尽落","description":"在同次出征中击败三位章节首领。三座王冠相继坠落，旅人的誓言仍在回响。","metric":"three_bosses","goal":1,"category":"战斗"},
"boss_rush":{"name":"终境试剑","description":"完成一次BossRush连战。在三重强敌的试炼中，铸就终境之名。","metric":"rush","goal":1,"category":"挑战"},
"coins":{"name":"星金聚辉","description":"累计获得五千冒险金币。将征途中的收获汇聚为光，见证每一次前行。","metric":"gold","goal":5000,"category":"收集"},
"keys":{"name":"秘藏巡礼","description":"累计开启二十五个宝箱。踏遍遗迹与星庭，让沉眠的珍藏重见天光。","metric":"chests","goal":25,"category":"收集"},
"chests":{"name":"启封秘藏","description":"累计开启五个宝箱。拨开岁月的封印，寻得遗落在星辉之下的珍藏。","metric":"chests","goal":5,"category":"收集"},
"extraction":{"name":"星辉归航","description":"成功撤离一次。循女神的接引越过长夜，将未尽的故事带回回廊。","metric":"extractions","goal":1,"category":"探索"},
"bloodbath":{"name":"浴血之誓","description":"在浴血难度清理一间战斗房间。以不可复原的伤痕为证，守住立于危境的誓言。","metric":"bloodbath_rooms","goal":1,"category":"挑战"},
"legendary_set":{"name":"传承加冕","description":"出征中同时装备任意角色的专属传说三件套。承接完整传承，让沉眠的力量再度苏醒。","metric":"sets","goal":1,"category":"收集"},
"all_heroes":{"name":"三途同辉","description":"三位角色分别成功撤离。三条命运之路终在星辉回廊相会。","metric":"hero_extractions","goal":3,"category":"探索"},
"enrage":{"name":"逆怒破阵","description":"清理怪物至少成长三次的战斗房间。直面暴怒累积的威势，以决意终结战局。","metric":"enrage_best","goal":3,"category":"挑战"},
"holy_healing":{"name":"晨曦长佑","description":"希露媞雅在出征中累计实际恢复一百生命。让克制而温暖的圣光，庇佑漫长的归途。","metric":"holy_healing","goal":100,"category":"战斗"}}
const ORDINARY_NAMES:={"walker":"骸骨游荡者","flyer":"幽骨浮灵","charger":"兽人冲锋手","caster":"死灵法师","bomber":"烬骨法师","guard":"重装骸骨盾卫","treant":"林地兽人守卫","bell_snail":"铃壳蜗使","glimmer_spider":"荧纱蛛","moss_badger":"棘冠苔獾","bog_crab":"泥沼甲蟹","ruin_sentinel":"星冕残卫","thorn_mantis":"灰棘螳卫","lantern_toad":"沼灯囊蛙","dusk_acolyte":"暮钟侍祭"}
const EXPANSION:={
"fate_first":{"name":"命运初启","description":"在祭坛首次接纳一张命运牌。聆听星幕之后的回声，为未知的道路写下开端。","metric":"fate_claims","goal":1,"category":"探索"},
"fate_reverse":{"name":"逆星行者","description":"接纳一张逆位命运牌。知晓代价，仍以自己的意志回应群星。","metric":"fate_reverse","goal":1,"category":"挑战"},
"fate_pair":{"name":"双曜同契","description":"在一次出征中同时持有两张命运牌。让两道不同的星辉共同照亮前路。","metric":"fate_pair","goal":2,"category":"收集"},
"fate_replace":{"name":"改写星轨","description":"在一次出征中缔结三张命运牌。让不同的星轨共同编织前行的道路。","metric":"fate_replacements","goal":1,"category":"探索"},
"fate_three":{"name":"三问星穹","description":"在同次出征中完成三次占卜的接纳或放弃。星穹作答，最终的决定仍属于旅人。","metric":"fate_resolved_best","goal":3,"category":"挑战"},
"fate_archive":{"name":"八象全书","description":"跨出征累计接纳全部八种命运牌，正逆位均可。将八种命运的启示铭入旅途。","metric":"fate_seen","goal":8,"category":"收集"},
"star_paths":{"name":"群星择途","description":"分别选择明炬座、涌泉座与守灯座，成功开始三次正式出征。循不同星光，见证道路的万千可能。","metric":"stars_departed","goal":3,"category":"探索"},
"star_return":{"name":"携星归航","description":"在带有出发星象且持有命运牌的出征中成功撤离。将星辉与自己的选择一同带回回廊。","metric":"star_returns","goal":1,"category":"探索"},
"elite_five":{"name":"荆冠破阵","description":"累计清理五间精英房。越过残忍之锋，为险境中的旅人开辟通途。","metric":"elite_clears","goal":5,"category":"挑战"},
"trial_three":{"name":"碎星试炼者","description":"累计完成三间试炼房的全部轮次。穿越重重封印，将战意留在碎星之间。","metric":"trial_clears","goal":3,"category":"挑战"},
"event_three":{"name":"旅人拾遗","description":"累计处理三间异闻房的事件。让遗落的信与残页，重新成为有人回应的故事。","metric":"event_resolutions","goal":3,"category":"探索"},
"alchemy_ten":{"name":"战地炼金师","description":"在正式出征中累计成功制作十份炼金产物。以有限的补给，为漫长征途续燃生机。","metric":"field_alchemy","goal":10,"category":"收集"},
"enchant_three":{"name":"符印铸誓","description":"在正式出征中累计成功刻印装备三次。让材料中的余辉，成为迎战强敌的誓约。","metric":"field_enchants","goal":3,"category":"收集"},
"research_three":{"name":"薪火研习","description":"在营地完成三项不同的工坊研究。把带回的见闻，化为后来者手中的火种。","metric":"research_seen","goal":3,"category":"收集"},
"contracts_five":{"name":"回廊守约人","description":"累计成功交付五次营地委托，同一委托重复交付也计入。信赖因一次次归来而累积，承诺因践行而长存。","metric":"contracts_delivered","goal":5,"category":"探索"},
"bound_return":{"name":"传承无损","description":"成功撤离时累计将五件绑定装备存回仓库。令征途中的传承跨越险境，再度归于星灯之下。","metric":"bound_returned","goal":5,"category":"收集"},
"chapter_two":{"name":"失名城的明日","description":"击败失名星城三位章节首领后成功撤离。让被昨日封存的城市，重新拥有明天。","metric":"chapters_returned","contains":"chapter_2","goal":1,"category":"挑战"},
"two_chapters":{"name":"双境长歌","description":"分别通关苏醒林地与失名星城，并成功撤离。穿越两重命运，仍以自由之名续写长歌。","metric":"chapters_returned","goal":2,"category":"挑战"}}
static var DATA:Dictionary=_build()
static func ordinary_names()->Dictionary:
	# Catalog initialization must stay independent of actor/combat scripts:
	# EnemyCombatPolicy -> EnemyBase -> tracker -> catalog forms a cold-load cycle.
	return ORDINARY_NAMES.duplicate()
static func _build()->Dictionary:
	var result:=BASE.duplicate(true)
	result.merge(EXPANSION,true)
	var names:=ordinary_names()
	for kind:String in names:
		for tier in 3:
			var goal:int=[100,500,1000][tier]
			var id:="slayer_%s_%d"%[kind,goal]
			result[id]={"name":"%s·%s"%[names[kind],["初誓","战勋","终铭"][tier]],"description":"累计击败%d名%s。%s"%[goal,names[kind],["以初成之锋，铭下守望的誓约。","越过百战余烬，让群影知晓旅人的名字。","千战之志不息，此名永刻于征途。"][tier]],"metric":"species:"+kind,"goal":goal,"category":"战斗"}
	for kind in BossRoster.DATA:
		for tier in 3:
			var goal:int=[10,50,100][tier]
			var id:="boss_slayer_%s_%d"%[kind,goal]
			result[id]={"name":"%s·%s"%[BossRoster.title_of(kind),["破冠","镇界","永耀"][tier]],"description":"累计击败%d次%s。%s"%[goal,BossRoster.title_of(kind),["王座的威压，终将让位于不屈的意志。","屡越强敌之境，令命运再度向前。","百次终审已毕，征服之名长耀星穹。"][tier]],"metric":"species:boss:"+str(kind),"goal":goal,"category":"挑战"}
	return result
static func progress(id:String)->int:
	var value:Variant=SaveService.data.get("achievement_stats",{}).get(DATA[id].metric,0)
	if DATA[id].has("contains"):return 1 if value is Array and str(DATA[id].contains) in value else 0
	return mini(int(DATA[id].goal),value.size() if value is Array else int(value))
static func unlocked(id:String)->bool:return SaveService.data.get("achievements",{}).has(id)
static func icon(id:String)->Texture2D:
	if id=="keys":id="chests" # Keep old unlock IDs while retiring key imagery.
	var path:=ROOT+("mastery/" if id.begins_with("slayer_") or id.begins_with("boss_slayer_") else "")+id+".png"
	return load(path) if ResourceLoader.exists(path) else null
