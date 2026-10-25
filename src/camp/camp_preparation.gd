class_name CampPreparation
extends RefCounted
signal changed
var memory_notice:=""
var memory_dirty:=false
var _remembered_signature:=""
var combat_mode:="rooms"
var chapter_id:StringName=ChapterCatalog.FIRST
var constellation:=""
var loadout:Array=[]
var skill_loadout:Array=Skills.default_loadout()
var carried:=0
var initial_level:=1
var difficulty:=1
var danger:int:
	get:return RunDifficulty.multiplier(difficulty)-1
	set(value):difficulty=RunDifficulty.from_legacy_danger(value)
var passive:StringName=&""
var confirmed:=false
var _signature:=""
func equipped_key(slot:StringName)->String:
	for key in loadout:
		if ItemDB.slot_of(Outpost.stored_item(str(key)))==slot:return str(key)
	return ""
func potion_count(key:="")->int:
	var total:=0
	for entry in loadout:
		if ItemDB.is_usable(Outpost.stored_item(str(entry))) and (key.is_empty() or str(entry)==key):total+=1
	return total
func equip_key(key:String)->bool:
	var item:=Outpost.stored_item(key)
	if not ItemDB.is_equippable(item) or not ItemDB.can_equip(item) or not ItemDB.available_in_mode(item,combat_mode) or int(Outpost.data.inventory.get(key,0))<=0:return false
	var slot:=ItemDB.slot_of(item)
	var old:=equipped_key(slot)
	if old==key:return true
	if not old.is_empty():loadout.erase(old)
	loadout.append(key);publish();return true
func unequip_slot(slot:StringName)->void:
	var old:=equipped_key(slot)
	if old.is_empty():return
	loadout.erase(old);publish()
func set_potion_count(key:String,count:int)->bool:
	var item:=Outpost.stored_item(key)
	if not ItemDB.is_usable(item) or not ItemDB.available_in_mode(item,combat_mode):return false
	var old:=potion_count(key)
	if count<0 or count>int(Outpost.data.inventory.get(key,0)) or potion_count()-old+count>15:return false
	if old==count:return true
	while loadout.has(key):loadout.erase(key)
	for index in count:loadout.append(key)
	publish(false);return true
func set_skill(id:StringName,slot:int)->bool:
	if not CharacterUnlocks.skill_available(id):return false
	var result:=Skills.equip_in_loadout(skill_loadout,id,slot)
	if result.is_empty():return false
	skill_loadout=result;publish();return true
func set_destination(id:StringName)->void:
	if not ChapterCatalog.is_ready(id) or not ChapterCatalog.unlocked(id):return
	chapter_id=id;publish()
func set_difficulty(value:int)->void:
	if not RunDifficulty.valid(value):return
	difficulty=value;publish()
func publish(remember:=true)->void:
	confirmed=false
	if remember:save_memory()
	changed.emit()
func memory_record()->Dictionary:
	var equipment:Dictionary={}
	for slot:StringName in ItemDB.SLOTS:equipment[str(slot)]=equipped_key(slot)
	return {"equipment":equipment,"skill_loadout":skill_loadout.duplicate(),"chapter_id":str(chapter_id),"difficulty":difficulty}
func save_memory()->bool:
	var record:=memory_record();var encoded:=JSON.stringify(record)
	if not memory_dirty and encoded==_remembered_signature:return true
	var before:Dictionary=SaveService.data.duplicate(true)
	var profiles:Dictionary=SaveService.data.get("camp_preparations",{}).duplicate(true) if SaveService.data.get("camp_preparations",{}) is Dictionary else {}
	profiles[str(Characters.current_id())]=record
	SaveService.data.camp_preparations=profiles
	if not SaveService.save_data():
		SaveService.data=before;memory_dirty=true;memory_notice="配置尚未保存，可重试；当前准备仍保留。";return false
	_remembered_signature=encoded;memory_dirty=false;memory_notice="";return true
func restore_memory()->void:
	loadout=[];carried=0;initial_level=1;constellation="";confirmed=false;memory_dirty=false;memory_notice=""
	skill_loadout=Skills.default_loadout();chapter_id=ChapterCatalog.FIRST;difficulty=1
	var profiles:Variant=SaveService.data.get("camp_preparations",{})
	var record:Variant=profiles.get(str(Characters.current_id()),{}) if profiles is Dictionary else {}
	if not record is Dictionary:record={}
	var gear:Variant=record.get("equipment",{})
	var missing:=0
	if gear is Dictionary:
		for slot:StringName in ItemDB.SLOTS:
			var key:=str(gear.get(str(slot),""))
			if key.is_empty():continue
			var item:=Outpost.stored_item(key)
			if int(Outpost.data.inventory.get(key,0))>0 and ItemDB.is_equippable(item) and ItemDB.can_equip(item) and ItemDB.slot_of(item)==slot:loadout.append(key)
			else:missing+=1
	var skills:Variant=record.get("skill_loadout",[])
	if skills is Array and CharacterUnlocks.valid_loadout(skills):skill_loadout=skills.duplicate()
	elif skills is Array and Skills.valid_loadout(skills):memory_notice="记忆配装包含尚未解锁的技能，已恢复初始技能。"
	var destination:=StringName(str(record.get("chapter_id",ChapterCatalog.FIRST)))
	if ChapterCatalog.is_ready(destination) and ChapterCatalog.unlocked(destination):chapter_id=destination
	var challenge:=int(record.get("difficulty",1))
	if RunDifficulty.valid(challenge):difficulty=challenge
	if missing>0:memory_notice+=("\n" if not memory_notice.is_empty() else "")+"%d件记忆装备缺货或不可用，已留空。"%missing
	_remembered_signature=JSON.stringify(memory_record());changed.emit()
func apply_preset(index:int)->PackedStringArray:
	var value:=Outpost.use_preset(index)
	if value.is_empty():return PackedStringArray(["方案不存在"])
	loadout=value.loadout.duplicate();carried=int(value.carried);difficulty=int(value.difficulty);publish()
	return PackedStringArray(value.missing)
func signature()->String:
	return JSON.stringify([combat_mode,constellation,str(chapter_id),loadout,skill_loadout,carried,initial_level,difficulty,str(PassiveDefinitions.selected(Characters.current_id()))])
func error()->String:
	if not CharacterUnlocks.valid_loadout(skill_loadout):return "请配置三个不同的小技能和一个大招。"
	if not constellation.is_empty() and not FateCatalog.STARS.has(constellation):return "请选择有效的出发星象。"
	if combat_mode!="rooms":return "请选择有效的出征方式。"
	if (not ChapterCatalog.is_ready(chapter_id) or not ChapterCatalog.unlocked(chapter_id)):return "请先通关苏醒林地，解锁失名星城。"
	if not Outpost.active_id().is_empty() or SaveService.has_run():return "请继续原出征，或先确认放弃原存档。"
	if Outpost.overfull():return "仓库超量，请先整理或扩容。"
	if not DepartureLevels.valid(initial_level):return "初始等级必须在1至10级之间。"
	if carried<0:return "随身金币不能为负数。"
	if carried+DepartureLevels.cost(initial_level)>Outpost.gold():return "金币不足：随身%d金＋初始等级费用%d金，金库%d金，还差%d金。"%[carried,DepartureLevels.cost(initial_level),Outpost.gold(),carried+DepartureLevels.cost(initial_level)-Outpost.gold()]
	if not RunDifficulty.valid(difficulty):return "请选择有效的战斗难度。"
	var counts:Dictionary={};var slots:Dictionary={};var potions:=0
	for id in loadout:
		var item:=ExpeditionData.resolve(str(id))
		if item.is_empty() or not ItemDB.available_in_mode(item,combat_mode):return "准备物品不可用。"
		counts[str(id)]=int(counts.get(str(id),0))+1
		if counts[str(id)]>int(Outpost.data.inventory.get(str(id),0)):return "%s库存不足：清单%d件，仓库%d件。"%[str(item.name),int(counts[str(id)]),int(Outpost.data.inventory.get(str(id),0))]
		if ItemDB.is_equippable(item):
			if not ItemDB.can_equip(item):return "装备与角色职业不符。"
			var slot:=str(ItemDB.slot_of(item))
			if slots.has(slot):return "每个装备槽只能携带一件装备。"
			slots[slot]=true
		elif ItemDB.is_usable(item):potions+=1
		else:return "只能准备装备和药剂。"
	if potions>15:return "药剂最多携带15瓶。"
	return ""
func confirm()->String:
	var message:=error()
	confirmed=message.is_empty()
	if confirmed:passive=PassiveDefinitions.selected(Characters.current_id());_signature=signature()
	return message
func ready()->bool:
	if confirmed and (_signature!=signature() or not error().is_empty()):confirmed=false
	return confirmed


static func advice(loadout:Array)->PackedStringArray:
	var slots:Dictionary={};var potions:=0;var notes:PackedStringArray=[]
	for id in loadout:
		var item:=ExpeditionData.resolve(str(id))
		if ItemDB.is_equippable(item):slots[str(ItemDB.slot_of(item))]=true
		elif ItemDB.is_usable(item):potions+=1
	var missing:PackedStringArray=[]
	for slot in ItemDB.SLOTS:
		if not slots.has(str(slot)):missing.append(str(ItemDB.SLOT_NAMES.get(slot,slot)))
	if not missing.is_empty():notes.append("空装备槽："+"、".join(missing)+"；可直接出发，也可前往仓库补充。")
	if potions==0:notes.append("未携带药剂；可自行决定是否准备。")
	for contract in ExpeditionData.CONTRACTS:
		if Outpost.contract_status(contract)!="accepted":continue
		var needs:=Outpost.contract_needs(contract);var ready:=true
		for id in needs:ready=ready and int(Outpost.data.inventory.get(id,0))>=int(needs[id])
		if ready:notes.append("仓库已有可交付委托："+str(contract.title)+" · 找"+CampResidents.issuer_name(contract))
	return notes
