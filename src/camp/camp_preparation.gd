class_name CampPreparation
extends RefCounted
var chapter_id:StringName=ChapterCatalog.FIRST
var constellation:=""
var loadout:Array=[]
var carried:=0
var initial_level:=1
var difficulty:=1
var danger:int:
	get:return RunDifficulty.multiplier(difficulty)-1
	set(value):difficulty=RunDifficulty.from_legacy_danger(value)
var passive:StringName=&""
var confirmed:=false
var _signature:=""
func signature()->String:
	return JSON.stringify([constellation,str(chapter_id),loadout,carried,initial_level,difficulty,str(PassiveDefinitions.selected(Characters.current_id()))])
func error()->String:
	if not constellation.is_empty() and not FateCatalog.STARS.has(constellation):return "请选择有效的出发星象。"
	if not ChapterCatalog.is_ready(chapter_id) or not ChapterCatalog.unlocked(chapter_id):return "请先通关苏醒林地，解锁失名星城。"
	if not Outpost.active_id().is_empty() or SaveService.has_run():return "请继续原出征，或先确认放弃原存档。"
	if Outpost.overfull():return "仓库超量，请先整理或扩容。"
	if not DepartureLevels.valid(initial_level):return "初始等级必须在1至10级之间。"
	if carried<0:return "随身金币不能为负数。"
	if carried+DepartureLevels.cost(initial_level)>Outpost.gold():return "金币不足：随身%d金＋初始等级费用%d金，金库%d金，还差%d金。"%[carried,DepartureLevels.cost(initial_level),Outpost.gold(),carried+DepartureLevels.cost(initial_level)-Outpost.gold()]
	if not RunDifficulty.valid(difficulty):return "请选择有效的战斗难度。"
	var counts:Dictionary={};var slots:Dictionary={};var potions:=0
	for id in loadout:
		var item:=ExpeditionData.resolve(str(id))
		if item.is_empty() or not ItemDB.available_in_mode(item,"rooms"):return "准备物品不可用。"
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
