extends Node
signal changed
signal checkpoint_requested
const VERSION = 4
var _contract_poll:=0.0
const Stock = preload("res://src/data/camp_stock.gd")
var data: Dictionary = {}
var pending_checkpoint = false
var _terminal_retry = 0.0

func _ready() -> void:
	if "--room-editor" in OS.get_cmdline_user_args():return
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = SaveService.data.get("outpost",{}).duplicate(true)
	var defaults = {"version":VERSION,"gold":0,"danger":0,"inventory":{},"capacity":30,"expansions":0,"shop":{},"shop_seed":Time.get_ticks_usec(),"contracts":[],"bonds":{"sylphiette":0,"iris":0},"events":{},"best":{},"active":{},"last_result":{},"locks":{},"presets":{},"tracked_contract":"","contract_jobs":{},"contract_clock":0,"bond_daily":{}}
	var migrated = int(data.get("version",0)) < VERSION
	for key in defaults:
		if not data.has(key): data[key]=defaults[key]
	# Preserve old inventories, active sorties and historical progress.
	for npc in BondRules.NAMES:
		data.bonds[npc]=clampi(int(data.bonds.get(npc,0)),0,BondRules.MAX)
	data.version=VERSION
	if migrated: commit()

func gold() -> int: return int(data.get("gold",0))
func max_rarity() -> int: return mini(2,int(data.get("danger",0)))
func active_id() -> String: return str(data.get("active",{}).get("id",""))

func stored_item(id: String) -> Dictionary:
	# Warehouse equipment is implicitly bound; keep the existing ID/count save format.
	return BoundEquipment.from_camp(ExpeditionData.resolve(id))

func warehouse_capacity() -> int: return maxi(30,int(data.get("capacity",30)))
func warehouse_slots(candidate: Dictionary = {}) -> int:
	var inventory: Dictionary = data.get("inventory",{}).duplicate()
	for id in candidate: inventory[id]=int(inventory.get(id,0))+int(candidate[id])
	var used=0
	for id in inventory:
		var count=maxi(0,int(inventory[id]))
		if str(id).begins_with("glow_mushroom_"):continue
		var item=ExpeditionData.resolve(str(id))
		used+=count if ItemDB.is_equippable(item) else ceili(float(count)/999.0)
	return used
func overfull() -> bool: return warehouse_slots()>warehouse_capacity()
func expansion_cost() -> int: return 100 << mini(50,maxi(0,int(data.get("expansions",0))))
func _finish_mutation(before: Dictionary, old_save: Dictionary) -> bool:
	if commit(): return true
	data=before
	SaveService.data=old_save
	return false
func expand_warehouse() -> bool:
	var fee=expansion_cost()
	if fee>gold():return false
	var before=data.duplicate(true)
	var old=SaveService.data.duplicate(true)
	data.gold=gold()-fee
	data.capacity=warehouse_capacity()+10
	data.expansions=int(data.get("expansions",0))+1
	return _finish_mutation(before,old)
func buy_basic(id: String) -> bool:
	var item=ExpeditionData.resolve(id)
	if item.is_empty() or int(item.get("rarity",0))!=0 or not (ItemDB.is_equippable(item) or ItemDB.is_usable(item)):return false
	if not ItemDB.in_source(item,&"shop") or Stock.basic_price(item)>gold() or warehouse_slots({id:1})>warehouse_capacity():return false
	var before=data.duplicate(true)
	var old=SaveService.data.duplicate(true)
	data.gold=gold()-Stock.basic_price(item)
	data.inventory[id]=int(data.inventory.get(id,0))+1
	return _finish_mutation(before,old)
func sell_stored(id: String, count: int, extra:Dictionary={}) -> bool:
	var item=ExpeditionData.resolve(id)
	if item.is_empty() or count<=0 or count>sellable_count(id,extra):return false
	var value=ExpeditionData.sale_value(item)
	if value<=0:return false
	var before=data.duplicate(true)
	var old=SaveService.data.duplicate(true)
	data.inventory[id]=int(data.inventory[id])-count
	data.gold=gold()+value*count
	return _finish_mutation(before,old)
func sync_shop(now: int = -1) -> bool:
	if now<0:now=Stock.local_seconds()
	var before=data.duplicate(true)
	var old=SaveService.data.duplicate(true)
	var shop: Dictionary=Stock.advance(data.get("shop",{}),now,int(data.get("shop_seed",1)))
	if shop==data.get("shop",{}):return true
	data.shop=shop
	return _finish_mutation(before,old)
func reroll_cost(now: int = -1) -> int:
	if now<0:now=Stock.local_seconds()
	var shop=Stock.advance(data.get("shop",{}),now,int(data.get("shop_seed",1)))
	return Stock.fee(int(shop.get("rerolls",0)))
func reroll_shop(now: int = -1) -> bool:
	if now<0:now=Stock.local_seconds()
	if not sync_shop(now):return false
	var fee=reroll_cost(now)
	if fee>gold():return false
	var before=data.duplicate(true)
	var old=SaveService.data.duplicate(true)
	data.gold=gold()-fee
	data.shop.rerolls=int(data.shop.rerolls)+1
	data.shop.nonce=int(data.shop.get("nonce",0))+1
	data.shop.offers=Stock.offers(int(data.shop.batch),int(data.shop.nonce),int(data.get("shop_seed",1)))
	return _finish_mutation(before,old)
func buy_offer(index: int, now: int = -1, expected_batch: int = -1, expected_nonce: int = -1) -> bool:
	if not sync_shop(now):return false
	if expected_batch>=0 and (int(data.shop.batch)!=expected_batch or int(data.shop.nonce)!=expected_nonce):return false
	var offers: Array=data.shop.offers
	if index<0 or index>=offers.size() or bool(offers[index].sold):return false
	var item=ExpeditionData.resolve(str(offers[index].id))
	if item.is_empty():return false
	var price: Dictionary=Stock.price(item)
	if int(price.gold)>gold():return false
	var candidate: Dictionary={str(item.id):1}
	for id in price.materials:
		if int(data.inventory.get(id,0))<int(price.materials[id]):return false
		candidate[id]=int(candidate.get(id,0))-int(price.materials[id])
	if warehouse_slots(candidate)>warehouse_capacity():return false
	var before=data.duplicate(true)
	var old=SaveService.data.duplicate(true)
	data.gold=gold()-int(price.gold)
	for id in candidate:data.inventory[id]=int(data.inventory.get(id,0))+int(candidate[id])
	data.shop.offers[index].sold=true
	return _finish_mutation(before,old)

func commit() -> bool:
	SaveService.data["outpost"] = data.duplicate(true)
	var ok: bool = SaveService.save_data()
	if ok: changed.emit()
	return ok

func start_sortie(loadout: Array, carried: int, danger: int, difficulty:int=0, initial_level:int=1, chapter_id:StringName=ChapterCatalog.FIRST,constellation:String="") -> bool:
	if not constellation.is_empty() and not FateCatalog.STARS.has(constellation):return false
	if not ChapterCatalog.is_ready(chapter_id) or not ChapterCatalog.unlocked(chapter_id):return false
	if not DepartureLevels.valid(initial_level):return false
	if overfull() or not active_id().is_empty() or carried < 0:return false
	if difficulty==0:
		if danger<0 or danger>3:return false
		difficulty=RunDifficulty.from_legacy_danger(danger)
	if not RunDifficulty.valid(difficulty):return false
	danger=RunDifficulty.multiplier(difficulty)-1
	var price = carried+DepartureLevels.cost(initial_level)
	var slots = {}
	var potion_count = 0
	var required = {}
	for id in loadout:
		var item = ExpeditionData.resolve(str(id))
		if item.is_empty(): return false
		required[str(id)]=int(required.get(str(id),0))+1
		if int(required[str(id)])>int(data.inventory.get(str(id),0)):return false
		if ItemDB.is_equippable(item):
			if not ItemDB.can_equip(item):return false
			var slot = str(ItemDB.slot_of(item))
			if slots.has(slot): return false
			slots[slot] = true
		elif ItemDB.is_usable(item):
			potion_count += 1
			if potion_count > 15: return false
		else: return false
	if price > gold(): return false
	var previous = data.duplicate(true)
	var old_save = SaveService.data.duplicate(true)
	data.gold = gold()-price
	for key in required:data.inventory[key]=int(data.inventory.get(key,0))-int(required[key])
	var id = "%d-%d" % [Time.get_unix_time_from_system()*1000,Time.get_ticks_usec()]
	data.active = {"constellation":constellation,"chapter_id":str(chapter_id),"id":id,"status":"active","danger":danger,"difficulty":difficulty,"spent":price,"loadout":loadout.duplicate(),"carried":carried,"initial_level":initial_level,"level_cost":DepartureLevels.cost(initial_level)}
	SaveService.data.run = {"chapter_id":str(chapter_id),"sortie_id":id,"departure":data.active.duplicate(true),"character":str(Characters.current_id()),"passive_id":str(PassiveDefinitions.selected(Characters.current_id()))}
	var evidence:=AchievementTracker.stage("departure",{"star":constellation})
	if not commit():
		AchievementTracker.finish_stage(evidence,false)
		data = previous
		SaveService.data = old_save
		return false
	AchievementTracker.finish_stage(evidence,true)
	return true

func request_checkpoint() -> void:
	if CampSession.active or active_id().is_empty() or not GameState.run_active: return
	pending_checkpoint = true

func _process(_delta: float) -> void:
	_contract_poll-=_delta
	if _contract_poll<=0:
		_contract_poll=2.0;sync_contracts()
	if str(data.get("active",{}).get("status",""))=="dead":
		_terminal_retry -= _delta
		if _terminal_retry<=0:
			_terminal_retry=2.0
			finalize_death()
	if pending_checkpoint:
		pending_checkpoint = false
		checkpoint_requested.emit()

func settle_sortie(outcome: String) -> Dictionary:
	var active: Dictionary = data.get("active",{})
	if active.is_empty() or str(active.get("id","")) != GameState.sortie_id: return {}
	var success = outcome == "extracted"
	if success and (not is_instance_valid(GameState.player) or float(GameState.player.hp) <= 0): return {}
	var before = data.duplicate(true)
	var old_save = SaveService.data.duplicate(true)
	var rows: Array = []
	var payout = GameState.coins if success else 0
	var all_items: Array = GameState.items.duplicate()
	for item in GameState.equipment.values():
		if not item.is_empty(): all_items.append(item)
	var counts = {}
	for item in all_items:
		var id = str(item.get("id",""))
		var keep = success and BoundEquipment.retained(item)
		if keep:
			data.inventory[id] = int(data.inventory.get(id,0))+1
		var value = ExpeditionData.sale_value(item) if success and not keep else 0
		payout += value
		if value > 0 or keep:
			var row_key:String=id+("|bound" if BoundEquipment.is_bound(item) else "|ordinary")
			if not counts.has(row_key): counts[row_key] = {"id":id,"name":str(item.name),"count":0,"gold":0,"stored":keep,"bound":BoundEquipment.is_bound(item)}
			counts[row_key].count += 1
			counts[row_key].gold += value
	for row in counts.values(): rows.append(row)
	var tier = str(GameState.danger)
	if success:
		data.gold = gold()+payout
		data.best[tier] = maxi(int(data.best.get(tier,0)),GameState.wave-(0 if GameState.wave_completed else 1))
	var material_report:=MaterialWorkshop.report(GameState.material_ledger,all_items,success)
	if success:
		if not data.has("material_known"):data.material_known={}
		for id in material_report.brought_back:data.material_known[id]=true
	var result = {"materials":material_report,"chapter_id":str(GameState.chapter_id),"chapter_cleared":GameState.chapter_cleared,"id":GameState.sortie_id,"outcome":outcome,"gold":payout,"spent":int(active.get("spent",0)),"wave":GameState.wave,"danger":GameState.danger,"difficulty":GameState.difficulty,"coins":GameState.coins,"coin_income":GameState.coins if success else 0,"sale_income":payout-GameState.coins if success else 0,"rows":rows,"build":_build_snapshot()}
	data.active = {}
	data.last_result = result
	SaveService.data.run = {}
	SaveService.data.runs = int(SaveService.data.get("runs",0))+1
	SaveService.data.best_wave = maxi(int(SaveService.data.get("best_wave",0)),GameState.wave)
	SaveService.data.meta_coins = int(SaveService.data.get("meta_coins",0))+payout
	var evidence:=AchievementTracker.stage("extraction",{"rows":rows}) if success else {}
	if not commit():
		if success:AchievementTracker.finish_stage(evidence,false)
		data = before
		SaveService.data = old_save
		return {}
	if success:AchievementTracker.finish_stage(evidence,true);AchievementTracker.extracted()
	return result

func abandon_saved() -> bool:
	if active_id().is_empty() and not SaveService.has_run():return true
	var before = data.duplicate(true)
	var old_save = SaveService.data.duplicate(true)
	data.last_result = {"id":active_id(),"outcome":"abandoned","gold":0,"spent":int(data.active.get("spent",0)),"difficulty":int(data.active.get("difficulty",SaveService.run_info().get("difficulty",1))),"rows":[]}
	data.active = {}
	SaveService.data.run = {}
	if commit(): return true
	data = before
	SaveService.data = old_save
	return false

func _contract_now(now:int=-1)->int:
	return maxi(BondRules.now() if now<0 else now,int(data.get("contract_clock",0)))
func _ensure_contract_data()->void:
	if not data.has("contract_jobs"):data.contract_jobs={}
	if not data.has("bond_daily"):data.bond_daily={}
	for npc in BondRules.NAMES:
		if not data.bonds.has(npc):data.bonds[npc]=0
func contract_needs(contract:Dictionary,stock:Dictionary={})->Dictionary:
	if str(contract.get("id",""))!="survey":return contract.get("needs",{}).duplicate(true)
	var bank:Dictionary=data.get("inventory",{}) if stock.is_empty() else stock
	var forest:Dictionary={"forest_sample":2,"wetland_sample":1};var city:Dictionary={"ruin_sample":3};var legacy:Dictionary={"forest_sample":1,"wetland_sample":1,"ruin_sample":1}
	var preferred_city:=str(data.get("contract_jobs",{}).get("survey",{}).get("chapter",""))==str(ChapterCatalog.NEXT)
	for option:Dictionary in [city,forest,legacy] if preferred_city else [forest,city,legacy]:
		var available:=true
		for id in option:available=available and int(bank.get(id,0))>=int(option[id])
		if available:return option.duplicate(true)
	return city if preferred_city else forest

func contract_status(contract:Dictionary,now:int=-1)->String:
	if not contract_unlocked(contract):return "locked"
	var job:Dictionary=data.get("contract_jobs",{}).get(str(contract.id),{})
	var clock:=_contract_now(now)
	if str(job.get("status",""))=="accepted":return "expired" if clock>=int(job.deadline) else "accepted"
	if data.get("contracts",[]).has(contract.id) and not bool(contract.get("repeatable",false)):return "completed"
	if not job.is_empty() and clock<int(job.get("next_accept",0)):return str(job.get("status","available"))
	return "available"
func sync_contracts(now:int=-1)->bool:
	var clock:=_contract_now(now)
	var expired:Array=[]
	for contract in ExpeditionData.CONTRACTS:
		var job:Dictionary=data.get("contract_jobs",{}).get(str(contract.id),{})
		if str(job.get("status",""))=="accepted" and clock>=int(job.get("deadline",0)):expired.append(contract)
	if expired.is_empty():return true
	var before=data.duplicate(true);var old=SaveService.data.duplicate(true);_ensure_contract_data()
	data.contract_clock=clock
	for contract in expired:
		var job:Dictionary=data.contract_jobs[str(contract.id)]
		job.status="expired";job.next_accept=int(job.deadline)+3600
		var npc:=str(contract.owner)
		data.bonds[npc]=maxi(0,int(data.bonds[npc])-int(contract.penalty))
		if str(data.get("tracked_contract",""))==str(contract.id):data.tracked_contract=""
	return _finish_mutation(before,old)
func accept_contract(index:int,now:int=-1,issuer:String="",chapter:StringName=ChapterCatalog.FIRST)->bool:
	if index<0 or index>=ExpeditionData.CONTRACTS.size() or not sync_contracts(now):return false
	var contract:Dictionary=ExpeditionData.CONTRACTS[index]
	if str(contract.get("issuer",""))!=issuer:return false
	if contract_status(contract,now)!="available":return false
	var before=data.duplicate(true);var old=SaveService.data.duplicate(true);_ensure_contract_data()
	var clock:=_contract_now(now);data.contract_clock=clock
	data.contract_jobs[str(contract.id)]={"status":"accepted","accepted_at":clock,"deadline":clock+int(contract.hours)*3600,"chapter":str(chapter)}
	data.tracked_contract=str(contract.id)
	return _finish_mutation(before,old)
func contract_remaining(contract:Dictionary,now:int=-1)->int:
	var job:Dictionary=data.get("contract_jobs",{}).get(str(contract.id),{})
	return maxi(0,int(job.get("deadline",0))-_contract_now(now))
func _add_bond(npc:String,gain:int,now:int=-1)->int:
	_ensure_contract_data()
	if not BondRules.NAMES.has(npc):return 0
	var day:=BondRules.day_key(_contract_now(now))
	var budget:Dictionary=data.bond_daily.get(npc,{})
	var used:=int(budget.get("gain",0)) if int(budget.get("day",-1))==day else 0
	var amount:=mini(maxi(0,gain),maxi(0,BondRules.DAILY_GAIN-used))
	amount=mini(amount,maxi(0,BondRules.MAX-int(data.bonds[npc])))
	data.bonds[npc]=clampi(int(data.bonds[npc])+amount,0,BondRules.MAX)
	data.bond_daily[npc]={"day":day,"gain":used+amount}
	return amount
func claim_contract(index:int,now:int=-1,issuer:String="")->bool:
	if index<0 or index>=ExpeditionData.CONTRACTS.size() or not sync_contracts(now):return false
	var contract:Dictionary=ExpeditionData.CONTRACTS[index]
	if str(contract.get("issuer",""))!=issuer:return false
	if contract_status(contract,now)!="accepted":return false
	var needs:=contract_needs(contract)
	for id in needs:
		if int(data.inventory.get(id,0))<int(needs[id]):return false
	var before=data.duplicate(true);var old=SaveService.data.duplicate(true);_ensure_contract_data()
	var clock:=_contract_now(now);data.contract_clock=clock
	for id in needs:data.inventory[id]=int(data.inventory[id])-int(needs[id])
	if not data.contracts.has(contract.id):data.contracts.append(contract.id)
	data.danger=maxi(int(data.danger),int(contract.unlock));data.gold=gold()+int(contract.reward)
	var gained:=_add_bond(str(contract.owner),int(contract.bond),clock)
	data.contract_jobs[str(contract.id)]={"status":"completed","completed_at":clock,"next_accept":BondRules.next_day(clock),"bond_gained":gained}
	if str(data.get("tracked_contract",""))==str(contract.id):data.tracked_contract=""
	var evidence:=AchievementTracker.stage("contract")
	var success:=_finish_mutation(before,old);AchievementTracker.finish_stage(evidence,success)
	return success

func bond_event(npc: String, event: String, gain: int, gift = false) -> bool:
	var key = npc+":"+event
	if not data.bonds.has(npc) or data.events.has(key): return false
	if gift and int(data.inventory.get("memory_gift",0)) <= 0: return false
	var before = data.duplicate(true)
	var old_save = SaveService.data.duplicate(true)
	if gift: data.inventory.memory_gift = int(data.inventory.memory_gift)-1
	data.events[key] = true
	_add_bond(npc,clampi(gain,0,5))
	if commit(): return true
	data = before
	SaveService.data = old_save
	return false

func _lost_items()->Array:
	var result:Array=[];var counts:Dictionary={};var bag:Array=GameState.items.duplicate()
	for item in GameState.equipment.values():
		if not item.is_empty():bag.append(item)
	for item in bag:
		var id:=str(item.get("id",""))
		if not counts.has(id):counts[id]={"id":id,"name":str(item.get("name",id)),"count":0}
		counts[id].count+=1
	result.assign(counts.values());return result
func mark_dead(wave: int, carried: int) -> void:
	if active_id().is_empty(): return
	data.active["status"]="dead"
	data.active["wave"]=wave
	data.active["lost_coins"]=carried
	data.active["build"]=_build_snapshot()
	SaveService.data.run={"sortie_id":active_id(),"terminal":"dead"}
	data.active["lost_items"]=_lost_items()
	data.active["materials"]=MaterialWorkshop.report(GameState.material_ledger,GameState.items,false)
	finalize_death()

func finalize_death() -> bool:
	if str(data.get("active",{}).get("status",""))!="dead": return true
	var before=data.duplicate(true)
	var old_save=SaveService.data.duplicate(true)
	var active: Dictionary=data.active
	data.last_result={"id":active.id,"outcome":"dead","gold":0,"spent":int(active.spent),"difficulty":int(active.get("difficulty",1)),"wave":int(active.get("wave",1)),"coins":int(active.get("lost_coins",0)),"rows":[],"lost_items":active.get("lost_items",[]),"materials":active.get("materials",{}),"build":active.get("build",{})}
	data.active={}
	SaveService.data.run={}
	SaveService.data.runs=int(SaveService.data.get("runs",0))+1
	SaveService.data.best_wave=maxi(int(SaveService.data.get("best_wave",0)),int(active.get("wave",1)))
	if commit(): return true
	data=before
	SaveService.data=old_save
	SaveService.data.outpost=data.duplicate(true)
	SaveService.data.run={"sortie_id":active_id(),"terminal":"dead"}
	return false

func _build_snapshot() -> Dictionary:
	var build = GameState.snapshot()
	build.erase("world_state")
	build.erase("environment")
	return build

func is_locked(id:String)->bool:return bool(data.get("locks",{}).get(id,false))
func set_locked(id:String,locked:bool)->bool:
	if ExpeditionData.resolve(id).is_empty():return false
	var before=data.duplicate(true);var old=SaveService.data.duplicate(true)
	if not data.has("locks"):data.locks={}
	if locked:data.locks[id]=true
	else:data.locks.erase(id)
	return _finish_mutation(before,old)
func task_reserves()->Dictionary:
	var result:Dictionary={}
	for contract in ExpeditionData.CONTRACTS:
		if contract_status(contract)!="accepted":continue
		for id in contract_needs(contract):result[id]=int(result.get(id,0))+int(contract_needs(contract)[id])
	return result
func loadout_counts(loadout:Array)->Dictionary:
	var result:Dictionary={}
	for id in loadout:result[str(id)]=int(result.get(str(id),0))+1
	return result
func reserved_counts(extra:Dictionary={})->Dictionary:
	var result=task_reserves()
	var goal_entry:=MaterialWorkshopCatalog.research(MaterialWorkshop.goal())
	if not goal_entry.is_empty() and not MaterialWorkshopCatalog.unlocked(str(goal_entry.id)):
		for id in goal_entry.needs:result[id]=int(result.get(id,0))+int(goal_entry.needs[id])
	for preset in data.get("presets",{}).values():
		var counts=loadout_counts(preset.get("loadout",[]))
		for id in counts:result[id]=maxi(int(result.get(id,0)),int(counts[id]))
	for id in extra:result[str(id)]=maxi(int(result.get(str(id),0)),int(extra[id]))
	return result
func sellable_count(id:String,extra:Dictionary={})->int:
	if is_locked(id) or ExpeditionData.sale_value(ExpeditionData.resolve(id))<=0:return 0
	return maxi(0,int(data.get("inventory",{}).get(id,0))-int(reserved_counts(extra).get(id,0)))
func sale_plan(ids:Array,max_rarity:int=1,extra:Dictionary={})->Dictionary:
	var rows:Array=[];var gold_value=0;var total=0;var delta:Dictionary={}
	var ordered=ids.duplicate();ordered.sort()
	var seen:Dictionary={}
	for raw in ordered:
		var id=str(raw)
		if seen.has(id):continue
		seen[id]=true
		var item=ExpeditionData.resolve(id)
		if item.is_empty() or id.begins_with("glow_mushroom_") or int(item.get("rarity",0))>max_rarity:continue
		var amount=sellable_count(id,extra)
		if amount<=0:continue
		var value=ExpeditionData.sale_value(item)*amount
		rows.append({"id":id,"name":str(item.name),"count":amount,"gold":value})
		gold_value+=value;total+=amount;delta[id]=-amount
	return {"rows":rows,"gold":gold_value,"count":total,"slots_freed":warehouse_slots()-warehouse_slots(delta),"ids":ordered,"max_rarity":max_rarity,"extra":extra.duplicate(true),"state":[data.get("inventory",{}).duplicate(true),data.get("locks",{}).duplicate(true),data.get("contracts",[]).duplicate(),data.get("presets",{}).duplicate(true),data.get("contract_jobs",{}).duplicate(true)]}
func sell_batch(plan:Dictionary)->bool:
	if plan.is_empty() or plan.get("rows",[]).is_empty():return false
	if sale_plan(plan.get("ids",[]),int(plan.get("max_rarity",1)),plan.get("extra",{}))!=plan:return false
	var before=data.duplicate(true);var old=SaveService.data.duplicate(true)
	for row in plan.rows:data.inventory[row.id]=int(data.inventory[row.id])-int(row.count)
	data.gold=gold()+int(plan.gold)
	return _finish_mutation(before,old)
func tracked_contract()->Dictionary:
	var chosen=str(data.get("tracked_contract",""))
	for contract in ExpeditionData.CONTRACTS:
		if contract.id==chosen and contract_status(contract)=="accepted":return contract
	for contract in ExpeditionData.CONTRACTS:
		if contract_status(contract)=="accepted":return contract
	return {}
func contract_unlocked(contract:Dictionary)->bool:
	var requirement:=str(contract.get("require",""))
	return ExpeditionData.CONTRACTS.has(contract) and int(data.get("danger",0))>=int(contract.danger) and (requirement.is_empty() or data.get("contracts",[]).has(requirement))

func track_contract(id:String)->bool:
	for contract in ExpeditionData.CONTRACTS:
		if contract.id!=id:continue
		if contract_status(contract)!="accepted":return false
		var before=data.duplicate(true);var old=SaveService.data.duplicate(true)
		data.tracked_contract=id
		return _finish_mutation(before,old)
	return false
func contract_progress(bag:Array=[])->Dictionary:
	var contract=tracked_contract()
	if contract.is_empty():return {}
	var carried:Dictionary={}
	for item in bag:
		var id=str(item.get("id",""));carried[id]=int(carried.get(id,0))+1
	var combined:Dictionary=data.get("inventory",{}).duplicate(true)
	for id in carried:combined[id]=int(combined.get(id,0))+int(carried[id])
	var needs:=contract_needs(contract,combined)
	var rows:Array=[];var bank_ready=true;var return_ready=true
	for id in needs:
		var bank=int(data.get("inventory",{}).get(id,0));var run=int(carried.get(id,0));var need=int(needs[id])
		bank_ready=bank_ready and bank>=need;return_ready=return_ready and bank+run>=need
		rows.append({"id":id,"name":str(ExpeditionData.resolve(id).name),"warehouse":bank,"carried":run,"need":need})
	return {"id":contract.id,"title":contract.title,"rows":rows,"bank_ready":bank_ready,"return_ready":return_ready,"owner":str(contract.owner),"remaining":contract_remaining(contract)}
func contract_text(bag:Array=[])->String:
	var progress=contract_progress(bag)
	if progress.is_empty():return "暂无已接委托 · 可在营地接取"
	var parts:PackedStringArray=[]
	for row in progress.rows:parts.append("%s 仓库%d＋随身%d/%d" % [row.name,row.warehouse,row.carried,row.need])
	return "委托 · %s · %s · %02d:%02d:%02d%s\n%s" % [progress.title,BondRules.NAMES.get(progress.owner,progress.owner),progress.remaining/3600,(progress.remaining%3600)/60,progress.remaining%60," · 可在营地交付" if progress.bank_ready else (" · 撤回后可交付" if progress.return_ready else ""),"\n".join(parts)]
func save_preset(index:int,name:String,loadout:Array,carried:int,danger:int,difficulty:int=0)->bool:
	if index<0 or index>=3 or carried<0:return false
	if difficulty==0:
		if danger<0 or danger>3:return false
		difficulty=RunDifficulty.from_legacy_danger(danger)
	if not RunDifficulty.valid(difficulty):return false
	danger=RunDifficulty.multiplier(difficulty)-1
	var slots:Dictionary={};var pots=0
	for raw in loadout:
		var item=ExpeditionData.resolve(str(raw))
		if ItemDB.is_equippable(item):
			if not ItemDB.can_equip(item):return false
			var slot=str(ItemDB.slot_of(item))
			if slots.has(slot):return false
			slots[slot]=true
		elif ItemDB.is_usable(item):pots+=1
		else:return false
	if pots>15:return false
	var required=loadout_counts(loadout)
	for id in required:
		if int(required[id])>int(data.inventory.get(id,0)):return false
	var before=data.duplicate(true);var old=SaveService.data.duplicate(true)
	if not data.has("presets"):data.presets={}
	var label=name.strip_edges().left(20)
	data.presets[str(index)]={"name":label if not label.is_empty() else "方案%d" % (index+1),"loadout":loadout.duplicate(),"carried":carried,"danger":danger,"difficulty":difficulty}
	return _finish_mutation(before,old)
func delete_preset(index:int)->bool:
	if not data.get("presets",{}).has(str(index)):return false
	var before=data.duplicate(true);var old=SaveService.data.duplicate(true)
	data.presets.erase(str(index));return _finish_mutation(before,old)
func use_preset(index:int)->Dictionary:
	var preset:Dictionary=data.get("presets",{}).get(str(index),{})
	if preset.is_empty():return {}
	var cart:Array=[];var missing:PackedStringArray=[];var used:Dictionary={}
	for raw in preset.get("loadout",[]):
		var id=str(raw);var item=ExpeditionData.resolve(id)
		if item.is_empty():missing.append("失效道具 "+id);continue
		if not ItemDB.can_equip(item):missing.append(str(item.name)+"不适用于当前职业");continue
		if int(used.get(id,0))>=int(data.inventory.get(id,0)):
			missing.append(str(item.name));continue
		used[id]=int(used.get(id,0))+1;cart.append(id)
	var money=mini(gold(),int(preset.get("carried",0)))
	if money<int(preset.get("carried",0)):missing.append("随身金币不足，已降至%d金" % money)
	var selected:=RunDifficulty.from_record(preset)
	return {"loadout":cart,"carried":money,"danger":RunDifficulty.multiplier(selected)-1,"difficulty":selected,"missing":missing}
func preview_loadout(loadout:Array)->StatBlock:
	var result=StatBlock.new()
	for stat in GameState.BASE_STATS:result.set_base(stat,UnitBalance.player_base(stat,float(GameState.BASE_STATS[stat])))
	var bag=loadout.map(func(id:Variant)->Dictionary:return ExpeditionData.resolve(str(id)))
	for item in bag:
		if not ItemDB.is_equippable(item) or not ItemDB.can_equip(item):continue
		for stat in item.get("flat",{}):
			if StringName(stat)!=&"lifesteal":result.add_flat(StringName(stat),float(item.flat[stat]))
		for stat in item.get("mult",{}):
			if StringName(stat)!=&"lifesteal":result.add_mult(StringName(stat),float(item.mult[stat]))
		if str(item.get("id",""))=="life_ampoule":result.add_flat(&"lifesteal",1.0)
	return result
