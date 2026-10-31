class_name PermanentStats
extends RefCounted
## Camp purchases are stored per hero in the outpost ledger.
const PATH:="res://data/permanent_stats.json"
const MAX_RANK:=8
const ORDER:Array[StringName]=[&"vitality",&"might",&"focus",&"swiftness",&"tempo",&"precision"]
const DATA:={
	&"vitality":{"name":"生命锻炼","stat":&"max_hp","kind":"flat","step":20.0,"description":"最大生命每级增加20点。"},
	&"might":{"name":"力量锻炼","stat":&"attack","kind":"flat","step":3.0,"description":"自身攻击力每级增加3点。"},
	&"focus":{"name":"凝神吐息","stat":&"mp_regen","kind":"flat","step":.4,"description":"自身每秒回蓝每级增加0.4。"},
	&"swiftness":{"name":"轻捷步法","stat":&"move_speed","kind":"flat","step":5.0,"description":"自身移动速度每级增加5点。"},
	&"tempo":{"name":"稳健节奏","stat":&"attack_speed","kind":"flat","step":.03,"description":"自身普通攻击速度每级增加0.03。"},
	&"precision":{"name":"精准训练","stat":&"crit_chance","kind":"flat","step":.015,"description":"自身暴击率每级提高1.5个百分点。"},
}
static var _catalog:Dictionary={}
static func catalog()->Dictionary:
	if _catalog.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:_catalog=parsed
	return _catalog
static func ranks(hero:StringName=Characters.current_id())->Dictionary:
	var raw:Dictionary=Outpost.data.get("permanent_stats",{}).get(str(hero),{})
	var result:Dictionary={}
	for id in ORDER:
		var level:=clampi(int(raw.get(id,raw.get(str(id),0))),0,MAX_RANK)
		if level>0:result[id]=level
	return result
static func current_ranks()->Dictionary:
	return GameState.training_stat_preview if CampSession.training_active else ranks()
static func rank(id:StringName)->int:return int(current_ranks().get(id,0)) if DATA.has(id) else 0
static func apply_to(block:StatBlock)->void:
	for id in ORDER:
		var level:=rank(id)
		if level<=0:continue
		var definition:Dictionary=DATA[id]
		var amount:=float(definition.step)*level
		if definition.kind=="flat":block.add_flat(definition.stat,amount)
		else:block.add_mult(definition.stat,amount)
static func cost(id:StringName,next_rank:int)->Dictionary:
	if not DATA.has(id) or next_rank<1 or next_rank>MAX_RANK:return {}
	var source:=catalog()
	var hero:=str(Characters.current_id())
	var material:=str(source.materials[hero][str(id)])
	var materials:Dictionary={material:int(source.material_count[next_rank-1])}
	if next_rank==8:
		materials={str(source.final_material[hero]):4,"starbound_sigil":3}
	return {"gold":int(source.gold[next_rank-1]),"materials":materials}
static func gate(id:StringName,next_rank:int)->Dictionary:
	if next_rank not in [4,6,8]:return {"met":true,"text":""}
	var row:Dictionary=catalog().gates[str(next_rank)]
	var hero:=Characters.current_id()
	var boss:=str(catalog().gate_boss[str(id)][str(next_rank)])
	var achievement:=CharacterUnlocks.achieved(str(hero),str(row.achievement))
	var kills:=int(SaveService.data.get("achievement_stats",{}).get("hero_boss:%s:%s"%[hero,boss],0))
	var clears:=PermanentTalents.clear_count(hero,boss,int(row.difficulty))
	var text_value:="%s成就 %s · %s击杀 %d/%d · %s及以上完成章节并撤离 %d/%d"%[str(row.achievement),"完成" if achievement else "未完成",BossRoster.title_of(StringName(boss)),kills,int(row.boss_kills),RunDifficulty.title(int(row.difficulty)),clears,int(row.clears)]
	return {"met":achievement and kills>=int(row.boss_kills) and clears>=int(row.clears),"text":text_value}
static func affordable(id:StringName,next_rank:int)->bool:
	var price:=cost(id,next_rank)
	if price.is_empty() or Outpost.gold()<int(price.gold):return false
	for material in price.materials:
		if int(Outpost.data.get("inventory",{}).get(material,0))<int(price.materials[material]):return false
	return true
static func purchase(id:StringName)->bool:
	if not CampSession.active or CampSession.training_active or not DATA.has(id):return false
	var next_rank:=int(ranks().get(id,0))+1
	if next_rank>MAX_RANK or not gate(id,next_rank).met or not affordable(id,next_rank):return false
	var before:=Outpost.data.duplicate(true);var old_save:=SaveService.data.duplicate(true)
	var all:Dictionary=Outpost.data.get("permanent_stats",{}).duplicate(true)
	var updated:=ranks();updated[id]=next_rank;all[str(Characters.current_id())]=updated;Outpost.data.permanent_stats=all
	var price:=cost(id,next_rank)
	Outpost.data.gold=Outpost.gold()-int(price.gold)
	for material in price.materials:Outpost.data.inventory[material]=int(Outpost.data.inventory.get(material,0))-int(price.materials[material])
	if not Outpost.commit():Outpost.data=before;SaveService.data=old_save;return false
	GameState._reset_stats();EventBus.talents_changed.emit();EventBus.player_stats_changed.emit();return true
static func reset(hero:StringName)->bool:
	if not CampSession.active or CampSession.training_active:return false
	var before:=Outpost.data.duplicate(true);var old_save:=SaveService.data.duplicate(true)
	var all:Dictionary=Outpost.data.get("permanent_stats",{}).duplicate(true)
	all[str(hero)]={};Outpost.data.permanent_stats=all
	if not Outpost.commit():Outpost.data=before;SaveService.data=old_save;return false
	if hero==Characters.current_id():GameState._reset_stats();EventBus.talents_changed.emit();EventBus.player_stats_changed.emit()
	return true
