class_name PermanentTalents
extends RefCounted
## External skill tree metadata and capstone gates; ranks live only in GameState.
const PATH:="res://data/permanent_talents.json"
static var _data:Dictionary={}
static func catalog()->Dictionary:
	if _data.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:_data=parsed
	return _data
static func skill(id:StringName)->Dictionary:return catalog().get("skills",{}).get(str(id),{})
static func terminal_id(id:StringName)->StringName:return StringName("skill_tree_%s_terminal"%str(id))
static func chapter_for_boss(boss:String)->String:
	for chapter in ChapterCatalog.CHAPTERS:
		if ChapterCatalog.CHAPTERS[chapter].bosses.has(boss):return str(chapter)
	return ""
static func active(id:StringName)->bool:
	return SkillTalentCatalog.equipped(id) and bool(GameState.talents.get(terminal_id(id),false))
static func clear_count(hero:StringName,boss:String,difficulty:int)->int:
	var chapter:=chapter_for_boss(boss)
	var counts:Dictionary=Outpost.data.get("talent_clears",{})
	var total:=0
	for level in range(difficulty,5):total+=int(counts.get("%s|%s|%d"%[hero,chapter,level],0))
	return total
static func conditions(node:StringName)->Dictionary:
	var info:=TalentGraph.node(node)
	if info.is_empty() or not bool(info.get("terminal",false)):return {"met":true,"text":""}
	var row:=skill(info.skill)
	if row.is_empty():return {"met":false,"text":"技能目录缺失"}
	var tier:Dictionary=catalog().tiers[row.tier]
	var hero:=StringName(row.hero)
	var achievement:=CharacterUnlocks.achieved(str(hero),str(tier.achievement))
	var kills:=int(SaveService.data.get("achievement_stats",{}).get("hero_boss:%s:%s"%[hero,row.boss],0))
	var clears:=clear_count(hero,str(row.boss),int(tier.difficulty))
	var lines:=PackedStringArray([
		"%s成就：%s"%[str(tier.achievement),"完成" if achievement else "未完成"],
		"%s击杀：%d/%d"%[BossRoster.title_of(StringName(row.boss)),kills,int(tier.boss_kills)],
		"%s·%s及以上完成章节并撤离：%d/%d"%[ChapterCatalog.title(chapter_for_boss(str(row.boss))),RunDifficulty.title(int(tier.difficulty)),clears,int(tier.clears)]])
	return {"met":achievement and kills>=int(tier.boss_kills) and clears>=int(tier.clears),"text":"\n".join(lines)}
