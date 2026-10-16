class_name MaterialWorkshop
extends RefCounted
## Shared material transactions. UI supplies IDs only; costs come from the catalog.
static func counts(bag:Array)->Dictionary:
	var result:Dictionary={}
	for item in bag:
		if ItemDB.is_material(item):result[str(item.id)]=int(result.get(str(item.id),0))+1
	return result
static func field_error(service:Node)->String:
	if CampSession.active:return "营地训练不能消耗真实背包材料；制作与研究请使用仓库工坊。"
	if not GameState.run_active or not is_instance_valid(GameState.player) or GameState.player.hp<=0:return "本次出征已结束。"
	if not is_instance_valid(service) or not service.has_method("is_open") or not bool(service.call("is_open")):return "请从局内商店或酒馆打开战地工坊。"
	var kind:StringName=service.get_script().get_global_name()
	if kind not in [&"ShopUI",&"TavernUI"]:return "当前地点没有战地工坊。"
	var runtime:Node=GameState.runtime_node
	if not is_instance_valid(runtime) or not is_instance_valid(runtime.get("main")):return "房间状态未就绪。"
	var main:Node=runtime.get("main");var graph:RoomGraph=main.get("graph")
	if graph==null or not graph.rooms.has(graph.current) or str(graph.rooms[graph.current].kind) not in ["shop","tavern"]:return "只能在商店或酒馆的安全房间制作。"
	var director:Node=main.get("director")
	if director._living_enemy_count()>0 or not director._queue.is_empty() or not director.room_pending.is_empty():return "仍有敌人或待生成队列，暂时不能制作。"
	var extraction:Node=runtime.get("extraction")
	if is_instance_valid(extraction) and str(extraction.state)!=ExtractionDirector.IDLE:return "请先取消女神呼唤，再使用战地工坊。"
	if TransitionLayer.busy:return "转场期间不能制作。"
	return ""
static func bank_error()->String:
	return "请在营地的回廊仓库打开制作与研究。" if not CampSession.active else ""
static func goal()->String:return str(Outpost.data.get("workshop",{}).get("goal",""))
static func reserves(camp:bool,exclude_goal:="")->Dictionary:
	var bank:Dictionary=Outpost.data.get("inventory",{});var combined:=bank.duplicate(true)
	if not camp:
		var carried:=counts(GameState.items)
		for id in carried:combined[id]=int(combined.get(id,0))+int(carried[id])
	var result:Dictionary={}
	for contract in ExpeditionData.CONTRACTS:
		if Outpost.contract_status(contract)!="accepted":continue
		var needs:=Outpost.contract_needs(contract,combined)
		for id in needs:result[id]=int(result.get(id,0))+int(needs[id])
	var key:=goal();var research:=MaterialWorkshopCatalog.research(key)
	if key!=exclude_goal and not MaterialWorkshopCatalog.unlocked(key) and not research.is_empty():
		for id in research.needs:result[id]=int(result.get(id,0))+int(research.needs[id])
	if not camp:
		for id in result:result[id]=maxi(0,int(result[id])-int(bank.get(id,0)))
	return result
static func cost_error(needs:Dictionary,camp:bool,protect:=true,exclude_goal:="")->String:
	var stock:Dictionary=Outpost.data.get("inventory",{}) if camp else counts(GameState.items)
	var reserved:=reserves(camp,exclude_goal) if protect else {}
	for id in needs:
		var have:=int(stock.get(id,0));var held:=mini(have,int(reserved.get(id,0)));var available:=maxi(0,have-held)
		if available<int(needs[id]):return "%s不足：需要%d，可用%d%s"%[str(ExpeditionData.resolve(str(id)).get("name",id)),int(needs[id]),available,"（保留%d份用于委托或目标研究）"%held if held>0 else ""]
	return ""
static func set_goal(id:String)->String:
	var error:=bank_error()
	if not error.is_empty():return error
	if not id.is_empty() and (MaterialWorkshopCatalog.research(id).is_empty() or MaterialWorkshopCatalog.unlocked(id)):return "此研究不存在或已经完成。"
	var before:=Outpost.data.duplicate(true);var saved:=SaveService.data.duplicate(true)
	if not Outpost.data.has("workshop"):Outpost.data.workshop={"unlocked":{},"goal":""}
	Outpost.data.workshop.goal=id
	if Outpost._finish_mutation(before,saved):return ""
	return "保存失败，研究目标未改变。"
static func research(id:String,protect:=true)->String:
	var error:=bank_error()
	if not error.is_empty():return error
	var entry:=MaterialWorkshopCatalog.research(id)
	if entry.is_empty() or MaterialWorkshopCatalog.unlocked(id):return "此研究不存在或已经完成。"
	error=cost_error(entry.needs,true,protect,id)
	if not error.is_empty():return error
	var before:=Outpost.data.duplicate(true);var saved:=SaveService.data.duplicate(true)
	_spend_bank(entry.needs)
	if not Outpost.data.has("workshop"):Outpost.data.workshop={"unlocked":{},"goal":""}
	if not Outpost.data.workshop.has("unlocked"):Outpost.data.workshop.unlocked={}
	Outpost.data.workshop.unlocked[id]=true
	if goal()==id:Outpost.data.workshop.goal=""
	if Outpost._finish_mutation(before,saved):return ""
	return "研究保存失败，材料已完整返还。"
static func craft(id:String,variant:int,camp:bool,protect:bool,service:Node=null)->String:
	var error:=bank_error() if camp else field_error(service)
	if not error.is_empty():return error
	var entry:=MaterialWorkshopCatalog.recipe(id)
	if entry.is_empty() or (not camp and id.begins_with("craft_")):return "当前地点不能制作此物品。"
	if not MaterialWorkshopCatalog.unlocked(str(entry.research)):return "请先在营地研究此配方。"
	if variant<0 or variant>=entry.variants.size():return "请选择有效的地区配方。"
	var needs:Dictionary=entry.variants[variant];error=cost_error(needs,camp,protect)
	if not error.is_empty():return error
	var product:=ExpeditionData.resolve(str(entry.product))
	if product.is_empty() or not ItemDB.can_equip(product):return "此产物不可用或与当前职业不符。"
	if not camp and RunDifficulty.is_bloodbath(GameState.difficulty) and str(entry.product)=="potion_health":return "浴血无法恢复生命，不能制作无效的治疗药剂。"
	if camp:
		var before:=Outpost.data.duplicate(true);var saved:=SaveService.data.duplicate(true)
		_spend_bank(needs);Outpost.data.inventory[str(product.id)]=int(Outpost.data.inventory.get(str(product.id),0))+1
		if Outpost.overfull():Outpost.data=before;return "制作后的仓库空间不足，未扣材料。"
		if Outpost._finish_mutation(before,saved):return ""
		return "制作保存失败，材料与仓库已回滚。"
	var bag:=GameState.items.duplicate();var ledger:=GameState.material_ledger.duplicate(true);var sequence:int=GameState.item_sequence
	_spend_run(needs,"alchemy")
	if not GameState.can_add_item(product):GameState.items.assign(bag);GameState.material_ledger=ledger;return "药剂背包空间不足，未扣材料。"
	GameState.item_sequence+=1;product.uid=GameState.sortie_id+":"+str(GameState.item_sequence);product.workshop_made=true
	var input_value:=0
	for key in needs:input_value+=ExpeditionData.sale_value(ExpeditionData.resolve(str(key)))*int(needs[key])
	product.sale_value=mini(ExpeditionData.sale_value(product),maxi(0,input_value-1))
	GameState.items.append(product)
	var outputs:Dictionary=GameState.material_ledger.get("crafted",{});outputs[str(product.id)]=int(outputs.get(str(product.id),0))+1;GameState.material_ledger.crafted=outputs
	if not SaveService.save_run(GameState.snapshot()):GameState.items.assign(bag);GameState.material_ledger=ledger;GameState.item_sequence=sequence;return "制作保存失败，材料与产物已回滚。"
	EventBus.item_acquired.emit(product);EventBus.item_received.emit(product);EventBus.player_stats_changed.emit();EventBus.hotbar_changed.emit()
	return ""
static func enchant(id:String,variant:int,protect:bool,service:Node)->String:
	var error:=field_error(service)
	if not error.is_empty():return error
	var entry:Dictionary=MaterialWorkshopCatalog.ENCHANTS.get(id,{})
	if entry.is_empty() or not MaterialWorkshopCatalog.unlocked(str(entry.research)):return "此刻印尚未研究。"
	var slot:=StringName(entry.slot);var item:=GameState.equipped(slot)
	if item.is_empty():return "请先装备此部位的装备。"
	if str(item.get("enchant",""))==id:return "这件装备已经拥有此刻印。"
	if variant<0 or variant>=entry.variants.size():return "请选择有效的刻印配方。"
	var needs:Dictionary=entry.variants[variant];error=cost_error(needs,false,protect)
	if not error.is_empty():return error
	var bag:=GameState.items.duplicate();var ledger:=GameState.material_ledger.duplicate(true)
	_spend_run(needs,"enchant");var changed:=item.duplicate(true);changed.enchant=id;GameState.equipment[slot]=changed
	var mechanics:EquipmentMechanics=GameState.player.get_node_or_null("EquipmentMechanics") as EquipmentMechanics
	var cooldowns:Dictionary=mechanics.cooldowns.duplicate() if is_instance_valid(mechanics) else {}
	# The persisted snapshot must already drop the previous accessory's charge.
	if slot==&"accessory" and is_instance_valid(mechanics):mechanics.cooldowns.erase(&"material_accessory_pending")
	if not SaveService.save_run(GameState.snapshot()):
		GameState.items.assign(bag);GameState.material_ledger=ledger;GameState.equipment[slot]=item
		if is_instance_valid(mechanics):mechanics.cooldowns=cooldowns
		return "附魔保存失败，原装备和材料已保留。"
	GameState._after_equipment_change();return ""
static func _spend_bank(needs:Dictionary)->void:
	for id in needs:Outpost.data.inventory[id]=int(Outpost.data.inventory.get(id,0))-int(needs[id])
static func _spend_run(needs:Dictionary,category:String)->void:
	var consumed:Dictionary=GameState.material_ledger.get(category,{})
	for id in needs:
		var left:=int(needs[id])
		for index in range(GameState.items.size()-1,-1,-1):
			if left<=0:break
			if str(GameState.items[index].get("id",""))==str(id):GameState.items.remove_at(index);left-=1
		consumed[id]=int(consumed.get(id,0))+int(needs[id])
	GameState.material_ledger[category]=consumed
static func report(ledger:Dictionary,carried:Array,success:bool)->Dictionary:
	var stock:=counts(carried);var first:Array=[]
	if success:
		for id in stock:
			if not bool(Outpost.data.get("material_known",{}).get(id,false)):first.append(id)
	return {"collected":ledger.get("collected",{}).duplicate(true),"alchemy":ledger.get("alchemy",{}).duplicate(true),"enchant":ledger.get("enchant",{}).duplicate(true),"crafted":ledger.get("crafted",{}).duplicate(true),"brought_back":stock if success else {},"lost":{} if success else stock,"first":first}
static func usage(id:String)->String:
	var notes:PackedStringArray=[]
	for contract in ExpeditionData.CONTRACTS:
		if Outpost.contract_status(contract)=="accepted" and Outpost.contract_needs(contract).has(id):notes.append("委托需要："+str(contract.title))
	var goal_entry:=MaterialWorkshopCatalog.research(goal())
	if not goal_entry.is_empty() and goal_entry.needs.has(id):notes.append("目标研究需要："+str(goal_entry.name))
	if MaterialWorkshopCatalog.BOSS_MATERIALS.has(id):notes.append("首领专属 · 无购买或普通材料兑换来源")
	return "\n".join(notes)
