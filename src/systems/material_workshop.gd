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
	return str(cost_preview(needs,camp,protect,exclude_goal).error)
static func stock(camp:bool)->Dictionary:
	return Outpost.data.get("inventory",{}).duplicate() if camp else counts(GameState.items)
static func scale_cost(needs:Dictionary,quantity:int)->Dictionary:
	var result:Dictionary={}
	for id in needs:result[id]=int(needs[id])*quantity
	return result
static func cost_preview(needs:Dictionary,camp:bool,protect:=true,exclude_goal:="")->Dictionary:
	var inventory:=stock(camp);var reserved:=reserves(camp,exclude_goal);var rows:Array=[];var errors:PackedStringArray=[]
	for id in needs:
		var total:=int(inventory.get(id,0));var held:=mini(total,int(reserved.get(id,0)));var available:=maxi(0,total-(held if protect else 0));var need:=int(needs[id])
		rows.append({"id":str(id),"total":total,"reserved":held,"available":available,"need":need,"missing":maxi(0,need-available),"after":total-need,"used_reserved":maxi(0,need-maxi(0,total-held))})
		if need>available:errors.append("%s不足：需要%d，可用%d%s"%[str(ExpeditionData.resolve(str(id)).get("name",id)),need,available,"（保留%d份用于委托或目标研究）"%held if protect and held>0 else ""])
	return {"rows":rows,"error":"；".join(errors)}
static func _capacity_error(product:Dictionary,needs:Dictionary,camp:bool,quantity:int)->String:
	if camp:
		var delta:Dictionary={str(product.id):quantity}
		for id in needs:delta[id]=int(delta.get(id,0))-int(needs[id])
		return "制作后的仓库空间不足，未扣材料。" if Outpost.warehouse_slots(delta)>Outpost.warehouse_capacity() else ""
	var potions:Dictionary={str(product.id):quantity}
	for item in GameState.items:
		if ItemDB.is_usable(item):potions[str(item.id)]=int(potions.get(str(item.id),0))+1
	var slots:=0
	for value in potions.values():slots+=ceili(float(value)/5)
	return "药剂背包空间不足，未扣材料。" if slots>GameState.BAG_CATEGORY_CAPACITY else ""
static func preview(kind:String,id:String,variant:int,camp:bool,protect:=true,quantity:=1,service:Node=null)->Dictionary:
	var entry:Dictionary=MaterialWorkshopCatalog.research(id) if kind=="research" else MaterialWorkshopCatalog.ENCHANTS.get(id,{}) if kind=="enchant" else MaterialWorkshopCatalog.recipe(id) if kind=="craft" else {}
	var result:Dictionary={"error":"","rows":[],"needs":{},"quantity":quantity,"max_quantity":0,"product":{}}
	if entry.is_empty():result.error="此操作不存在。";return result
	var variants:Array=[entry.needs] if kind=="research" else entry.variants
	if variant<0 or variant>=variants.size():result.error="请选择有效的地区配方。";return result
	var product:=ExpeditionData.resolve(str(entry.product)) if kind=="craft" else {}
	var limit:=10 if kind=="craft" and ItemDB.is_usable(product) else 1
	if quantity<1 or quantity>limit:result.error="药剂每次可制作1至10份；装备与研究每次仅一份。";return result
	var unit:Dictionary=variants[variant];var needs:=scale_cost(unit,quantity);var costs:=cost_preview(needs,camp,protect,id if kind=="research" else "")
	result.merge({"needs":needs,"rows":costs.rows,"product":product,"error":costs.error},true)
	var context:=bank_error() if camp else field_error(service)
	if not context.is_empty():result.error=context
	elif kind=="research":
		if not camp:result.error="研究只能在营地进行。"
		elif MaterialWorkshopCatalog.unlocked(id):result.error="此研究已经完成。"
	elif kind=="enchant":
		var item:=GameState.equipped(StringName(entry.slot))
		if camp:result.error="刻印仅在局内安全商店或酒馆施加。"
		elif not MaterialWorkshopCatalog.unlocked(str(entry.research)):result.error="请先在营地研究此刻印。"
		elif item.is_empty():result.error="请先装备此部位的装备。"
		elif str(item.get("enchant",""))==id:result.error="这件装备已经拥有此刻印。"
	else:
		if not camp and id.begins_with("craft_"):result.error="当前地点不能制作此物品。"
		elif not MaterialWorkshopCatalog.unlocked(str(entry.research)):result.error="请先在营地研究此配方。"
		elif product.is_empty() or not ItemDB.can_equip(product):result.error="此产物不可用或与当前职业不符。"
		elif not camp and RunDifficulty.is_bloodbath(GameState.difficulty) and str(product.id)=="potion_health":result.error="浴血无法恢复生命，不能制作无效的治疗药剂。"
		elif str(result.error).is_empty():result.error=_capacity_error(product,needs,camp,quantity)
	if kind=="craft" and context.is_empty() and not product.is_empty() and ItemDB.can_equip(product) and MaterialWorkshopCatalog.unlocked(str(entry.research)) and (camp or not id.begins_with("craft_")) and (camp or not RunDifficulty.is_bloodbath(GameState.difficulty) or str(product.id)!="potion_health"):
		var possible:=limit
		for row in costs.rows:possible=mini(possible,int(int(row.available)/int(unit[row.id])))
		for count in range(possible,0,-1):
			var cost:=scale_cost(unit,count)
			if not _capacity_error(product,cost,camp,count).is_empty():continue
			result.max_quantity=count;break
	return result
static func cost_text(rows:Array,protect:=true)->String:
	var lines:PackedStringArray=[]
	for row in rows:lines.append("%s：总量%d · 保留%d · 可用%d · 消耗%d · 剩余%d%s"%[str(ExpeditionData.resolve(str(row.id)).get("name",row.id)),int(row.total),int(row.reserved),int(row.available),int(row.need),maxi(0,int(row.after))," · 缺%d"%int(row.missing) if int(row.missing)>0 else " · 将占用保留%d份"%int(row.used_reserved) if not protect and int(row.used_reserved)>0 else ""])
	return "\n".join(lines)
static func uses_text(id:String,camp:bool)->String:
	var groups:Dictionary={"alchemy":"炼金","enchant":"刻印","research":"研究","craft":"制作"};var lines:PackedStringArray=[]
	for use in MaterialWorkshopCatalog.uses(id):
		var done:=MaterialWorkshopCatalog.unlocked(str(use.research));var state:="已完成" if use.kind=="research" and done else "已解锁" if done else "未解锁"
		if use.kind=="research" and done:lines.append("研究 · %s · 已完成，无需再次消耗。"%str(use.name));continue
		var costs:=cost_preview(use.needs,camp,true,str(use.id) if use.kind=="research" else "");var gaps:PackedStringArray=[]
		for row in costs.rows:
			if int(row.missing)>0:gaps.append("%s%d"%[str(ExpeditionData.resolve(str(row.id)).get("name",row.id)),int(row.missing)])
		lines.append("%s · %s · %s\n需要：%s\n%s"%[groups[use.kind],str(use.name),state,MaterialWorkshopCatalog.cost_text(use.needs),"缺少："+"、".join(gaps) if not gaps.is_empty() else "材料已齐（保留委托及目标用量后）"])
	return "\n\n".join(lines) if not lines.is_empty() else "此材料暂不用于工坊配方；现有委托、赠礼与兑换用途保持原样。"
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
	var view:=preview("research",id,0,true,protect)
	if not str(view.error).is_empty():return str(view.error)
	var entry:=MaterialWorkshopCatalog.research(id)
	var before:=Outpost.data.duplicate(true);var saved:=SaveService.data.duplicate(true)
	_spend_bank(entry.needs)
	if not Outpost.data.has("workshop"):Outpost.data.workshop={"unlocked":{},"goal":""}
	if not Outpost.data.workshop.has("unlocked"):Outpost.data.workshop.unlocked={}
	Outpost.data.workshop.unlocked[id]=true
	if goal()==id:Outpost.data.workshop.goal=""
	if Outpost._finish_mutation(before,saved):return ""
	return "研究保存失败，材料已完整返还。"
static func craft(id:String,variant:int,camp:bool,protect:bool,service:Node=null,quantity:=1)->String:
	var view:=preview("craft",id,variant,camp,protect,quantity,service)
	if not str(view.error).is_empty():return str(view.error)
	var needs:Dictionary=view.needs;var product:Dictionary=view.product
	if camp:
		var before:=Outpost.data.duplicate(true);var saved:=SaveService.data.duplicate(true)
		_spend_bank(needs);Outpost.data.inventory[str(product.id)]=int(Outpost.data.inventory.get(str(product.id),0))+quantity
		if Outpost._finish_mutation(before,saved):return ""
		return "制作保存失败，整批材料与仓库已回滚。"
	var bag:=GameState.items.duplicate();var ledger:=GameState.material_ledger.duplicate(true);var sequence:int=GameState.item_sequence;var made:Array[Dictionary]=[]
	_spend_run(needs,"alchemy")
	var input_value:=0
	for key in needs:input_value+=ExpeditionData.sale_value(ExpeditionData.resolve(str(key)))*int(needs[key])
	for index in quantity:
		var copy:Dictionary=product.duplicate(true);GameState.item_sequence+=1;copy.uid=GameState.sortie_id+":"+str(GameState.item_sequence);copy.workshop_made=true
		copy.sale_value=mini(ExpeditionData.sale_value(copy),maxi(0,int(input_value/quantity)-1));GameState.items.append(copy);made.append(copy)
	var outputs:Dictionary=GameState.material_ledger.get("crafted",{});outputs[str(product.id)]=int(outputs.get(str(product.id),0))+quantity;GameState.material_ledger.crafted=outputs
	if not SaveService.save_run(GameState.snapshot()):GameState.items.assign(bag);GameState.material_ledger=ledger;GameState.item_sequence=sequence;return "制作保存失败，整批材料与产物已回滚。"
	for item in made:EventBus.item_acquired.emit(item);EventBus.item_received.emit(item)
	EventBus.player_stats_changed.emit();EventBus.hotbar_changed.emit()
	return ""
static func enchant(id:String,variant:int,protect:bool,service:Node)->String:
	var view:=preview("enchant",id,variant,false,protect,1,service)
	if not str(view.error).is_empty():return str(view.error)
	var entry:Dictionary=MaterialWorkshopCatalog.ENCHANTS[id];var slot:=StringName(entry.slot);var item:=GameState.equipped(slot);var needs:Dictionary=view.needs
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
