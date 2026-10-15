class_name ExpeditionReport
extends RefCounted
static func preview(bag:Array,gear:Dictionary,coins:int)->Dictionary:
	var gold=coins
	var stored:Dictionary={}
	var sell_count=0
	var all=bag.duplicate()
	for item in gear.values():
		if not item.is_empty():all.append(item)
	for item in all:
		if BoundEquipment.retained(item):
			var id=str(item.get("id",""));stored[id]=int(stored.get(id,0))+1
		else:
			var value=ExpeditionData.sale_value(item)
			gold+=value
			if value>0:sell_count+=1
	return {"gold":gold,"stored":stored,"stored_count":stored.values().reduce(func(a:int,b:Variant)->int:return a+int(b),0),"sold_count":sell_count,"slots":Outpost.warehouse_slots(stored),"capacity":Outpost.warehouse_capacity()}
static func summary()->String:
	var report=preview(GameState.items,GameState.equipment,GameState.coins)
	return "成功撤回预计到账 %d 金 · 非绑定物品出售 %d 件\n绑定装备、材料与蘑菇入库 %d 份 · 仓库预计 %d/%d 格%s\n%s\n绑定装备撤离保留，战斗死亡仍丢失；仓库已有物品不受影响。" % [report.gold,report.sold_count,report.stored_count,report.slots,report.capacity," · 将超容，下次出发前需清理" if report.slots>report.capacity else "",Outpost.contract_text(GameState.items)]
static func compact()->String:
	var report=preview(GameState.items,GameState.equipment,GameState.coins)
	var task=Outpost.contract_progress(GameState.items)
	var status="委托全部完成" if task.is_empty() else "%s · %s" % [task.title,"营地可交付" if task.bank_ready else ("撤回后可交付" if task.return_ready else "收集中")]
	return "成功撤回预计到账 %d 金 · 绑定装备/材料入库 %d 份\n仓库预计 %d/%d 格%s · %s" % [report.gold,report.stored_count,report.slots,report.capacity,"（超容）" if report.slots>report.capacity else "",status]
