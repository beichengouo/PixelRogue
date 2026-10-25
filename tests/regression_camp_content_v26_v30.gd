extends Node
var checks:=0
var failures:=0
var _base:Dictionary
var _save:Dictionary
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func frames(n:=4)->void:
	for i in n:await get_tree().process_frame
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
func fresh()->void:
	Outpost.data=_base.duplicate(true);SaveService.data=_save.duplicate(true)
	Outpost.data.contracts=[];Outpost.data.contract_jobs={};Outpost.data.contract_clock=0;Outpost.data.bond_daily={};Outpost.data.tracked_contract="";Outpost.data.inventory={};Outpost.data.gold=1000;Outpost.data.danger=0;Outpost.data.active={}
	SaveService.data.achievement_stats={};SaveService.data.achievements={};SaveService.data.run={}
	GameState.items.clear();GameState.equipment.clear();GameState.run_active=false;CampSession.active=false
	Outpost.pending_checkpoint=false;AchievementTracker._pending.clear()
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	AchievementTracker.set_process(false);ErrorReporter.interactive=false;TransitionLayer.boot_played=true
	await frames();_base=Outpost.data.duplicate(true);_save=SaveService.data.duplicate(true)
	fresh();catalog_checks();await transactions();achievement_checks();await ui_checks()
	GameState.run_active=false;AudioManager.shutdown();await frames()
	print("CAMP_CONTENT_V26 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
func catalog_checks()->void:
	check(ExpeditionData.CONTRACTS.size()==19,"seven legacy plus twelve new contracts")
	check(CampCommissionCatalog.DATA==JSON.parse_string(CampCommissionCatalog.FALLBACK).commissions,"story file and fallback parity")
	var seen:Array=[]
	for row:Dictionary in ExpeditionData.CONTRACTS:
		check(str(row.id) not in seen,"unique commission ID");seen.append(str(row.id))
		for id in row.needs:check(not ExpeditionData.resolve(str(id)).is_empty(),"existing material resolves "+str(id))
	for issuer:String in CampResidents.DATA:
		var count:=0
		for index in CampResidents.contract_indices(issuer):
			var row:Dictionary=ExpeditionData.CONTRACTS[index]
			if not bool(row.get("story",false)):continue
			count+=1;check(int(row.penalty)==0 and int(row.danger)==0 and int(row.unlock)==0,"friendly low-tier quests do not unlock difficulty")
			for phase in ["offer","accepted","finished"]:
				var lines:=CampCommissionCatalog.story(str(row.id),phase)
				check(lines.size()>=2,"authored story phase "+str(row.id)+phase)
				for line:Dictionary in lines:check(not str(line.text).is_empty() and str(line.expression)=="neutral","explicit calm dialogue")
		check(count==3,"three story stages per NPC "+issuer)
	var rows:=ItemDB.all();var fallback:=ItemDB._defaults();check(rows.size()==196 and fallback.size()==196,"196 item definitions")
	for i in rows.size():check(rows[i]==fallback[i],"full normalized item fallback parity "+str(rows[i].id))
	var added:=0
	for i in range(172,196):
		var row:Dictionary=rows[i];added+=1
		check(int(row.rarity)<2 and row.mult.is_empty() and row.mechanics.is_empty() and not row.has("summon"),"new low tiers use fixed stats")
		check(ItemDB.icon_texture(row)!=null and not str(row.flavor).is_empty(),"valid reused illustration and flavor")
		check(ExpeditionData.unpack(ExpeditionData.pack(row)).id==row.id,"new item serialization "+str(row.id))
	check(added==24,"24 new items")
	for hero:StringName in Characters.DATA:
		Characters.set_current(hero);var pool:Array=[]
		for row:Dictionary in rows:
			if ItemDB.in_source(row,&"reward"):pool.append(row)
		var rng:=RandomNumberGenerator.new();rng.seed=2601
		for i in 600:
			var pick:=LootSelection.pick_for_source(pool,&"reward",rng)
			check(not pick.is_empty() and ItemDB.can_equip(pick),"source/category/class filtering "+str(hero))
	check(CampAchievementExpansion.DATA.size()==24,"24 added achievements")
	for id:String in CampAchievementExpansion.DATA:check(AchievementCatalog.icon(id)!=null,"existing achievement symbol resolves "+id)
func index_for(id:String)->int:
	for i in ExpeditionData.CONTRACTS.size():
		if str(ExpeditionData.CONTRACTS[i].id)==id:return i
	return -1
func save_block()->String:
	var path:=ProjectSettings.globalize_path(SaveService.SAVE_PATH)+".tmp"
	check(DirAccess.make_dir_absolute(path)==OK,"create isolated save blocker")
	return path
func transactions()->void:
	fresh();check(SaveService.save_data(),"baseline saves")
	for source:Dictionary in CampCommissionCatalog.DATA:
		if str(source.require).is_empty():continue
		var index:=index_for(str(source.id))
		check(Outpost.contract_status(ExpeditionData.CONTRACTS[index])=="locked" and not Outpost.accept_contract(index,-1,str(source.issuer)),"uncompleted prerequisites block later story")
	for source:Dictionary in CampCommissionCatalog.DATA:
		var index:=index_for(str(source.id));var row:Dictionary=ExpeditionData.CONTRACTS[index];var issuer:=str(row.issuer)
		check(Outpost.contract_status(row)=="available","story prerequisite reachable "+str(row.id))
		check(not Outpost.accept_contract(index,-1,"wrong"),"wrong issuer rejected")
		if str(row.get("require",""))=="":
			var before:=Outpost.data.duplicate(true);var blocked:=save_block()
			check(not Outpost.accept_contract(index,-1,issuer) and Outpost.data==before,"accept failure rolls back")
			check(DirAccess.remove_absolute(blocked)==OK,"remove blocker")
		check(Outpost.accept_contract(index,-1,issuer),"accept story "+str(row.id))
		check(not Outpost.accept_contract(index,-1,issuer),"duplicate accept rejected")
		for id in row.needs:
			GameState.items.append(ExpeditionData.resolve(str(id)))
		check(not Outpost.claim_contract(index,-1,issuer),"run bag is not warehouse")
		GameState.items.clear()
		for id in row.needs:Outpost.data.inventory[id]=int(row.needs[id])
		check(CampResidents.progress(issuer)=="ready" and CampResidents.contract_index(issuer)==index,"ready story takes badge and selection priority")
		check(not Outpost.claim_contract(index,-1,"wrong"),"wrong issuer cannot claim ready materials")
		var before:Dictionary=Outpost.data.duplicate(true);var stats:Dictionary=SaveService.data.achievement_stats.duplicate(true);var achievements:Dictionary=SaveService.data.achievements.duplicate(true);var blocked:=save_block()
		var pending:=AchievementTracker._pending.duplicate()
		check(not Outpost.claim_contract(index,-1,issuer),"claim failure reports false")
		check(Outpost.data==before and SaveService.data.achievement_stats==stats and SaveService.data.achievements==achievements,"claim atomic stock/gold/bond/achievement rollback")
		check(AchievementTracker._pending==pending,"failed claim publishes no achievement toast")
		check(DirAccess.remove_absolute(blocked)==OK,"remove claim blocker")
		check(Outpost.claim_contract(index,-1,issuer),"successful claim "+str(row.id))
		check(Outpost.gold()==int(before.gold)+int(row.reward),"reward credited once")
		for id in row.needs:check(int(Outpost.data.inventory[id])==0,"materials consumed exactly once")
		check(not Outpost.claim_contract(index,-1,issuer) and not Outpost.accept_contract(index,-1,issuer),"finished story cannot repeat")
	check(Outpost.data.danger==0 and Outpost.data.contracts.size()==12,"stories preserve difficulty and completion IDs")
	check(AchievementCatalog.unlocked("commission_all"),"all story achievement only after twelve committed claims")
	check(SaveService.save_data(),"save completed stories")
	var disk:Variant=JSON.parse_string(FileAccess.get_file_as_string(SaveService.SAVE_PATH))
	check(disk is Dictionary,"saved profile remains valid JSON")
	SaveService.data.outpost={};SaveService.load_data();Outpost._ready()
	check(Outpost.data.contracts.size()==12 and AchievementCatalog.unlocked("commission_all"),"completed stories and achievement survive real disk reload")
	for source:Dictionary in CampCommissionCatalog.DATA:check(Outpost.contract_status(ExpeditionData.CONTRACTS[index_for(str(source.id))])=="completed","reloaded stories cannot pay twice")
	fresh();var first:=index_for("camp_minstrel_strap");check(Outpost.accept_contract(first,-1,"minstrel"),"accept expiry fixture")
	var row:Dictionary=ExpeditionData.CONTRACTS[first];var deadline:int=Outpost.data.contract_jobs[row.id].deadline;var bonds:Dictionary=Outpost.data.bonds.duplicate(true)
	check(Outpost.sync_contracts(deadline) and Outpost.data.bonds==bonds,"story expiry has zero bond penalty")
	check(not Outpost.accept_contract(first,deadline,"minstrel"),"expiry has cooldown")
	check(Outpost.accept_contract(first,deadline+3600,"minstrel"),"expired story can be retried")
	fresh();Outpost.data.contracts=["survey","deep","echo"];AchievementTracker._migrate();AchievementTracker._migrate()
	check(SaveService.data.achievement_stats.contract_seen.size()==3 and SaveService.data.achievement_stats.contracts_delivered==3,"legacy IDs migrate without duplicate counts")
	check(AchievementCatalog.unlocked("contract_first") and not AchievementCatalog.unlocked("commission_first"),"legacy achievement credit does not fabricate story completions")
func achievement_checks()->void:
	fresh();GameState.run_active=true;CampSession.active=true
	EventBus.item_acquired.emit(ItemDB.by_id(&"relic_practiceblade"));check(not SaveService.data.achievement_stats.has("low_relic_seen"),"training acquisition excluded")
	CampSession.active=false
	for i in range(184,190):EventBus.item_acquired.emit(ItemDB.all()[i])
	check(AchievementCatalog.unlocked("low_relic_six"),"six different low-tier relics tracked")
	var size:int=SaveService.data.achievement_stats.low_relic_seen.size();EventBus.item_acquired.emit(ItemDB.all()[184]);check(SaveService.data.achievement_stats.low_relic_seen.size()==size,"duplicate loot does not inflate collection")
	Characters.set_current(&"sylphiette")
	for id in [&"staff_softlight",&"armor_benchpad",&"accessory_bookclip"]:
		var item:=ItemDB.by_id(id);GameState.equipment[ItemDB.slot_of(item)]=item
	EventBus.equipment_changed.emit();check(AchievementCatalog.unlocked("low_gear_ready"),"three low-tier slots observed")
	GameState.run_active=false
func ui_checks()->void:
	fresh();SaveService.data.control_setup_done=true;SaveService.data.input_guide_seen=true;SaveService.data.camp_tutorial={"enabled":false,"completed":true};SaveService.data.reduced_motion=true;SaveService.data.replay_seen_dialogue=false
	var camp:=CampWorld.new();add_child(camp)
	while not camp.initialization_complete:await frames(1)
	check(camp.initialization_success,"actual camp initializes")
	if not camp.initialization_success:return
	var panel:CampResidentPanel=camp.resident_panel
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(8)
		for npc:CampResident in camp.residents_root.get_children():
			panel.resident=npc;npc.interacting=true;panel._selected=CampResidents.contract_index(npc.resident_id);panel._show();await frames()
			check(UIFlow.is_top(panel),"resident panel owns input")
			for index in CampResidents.contract_indices(npc.resident_id):
				panel._select(index);await frames()
				var button:=panel._body.find_child("Commission_"+str(ExpeditionData.CONTRACTS[index].id),true,false) as Button
				check(button!=null and button.button_pressed,"each commission selectable "+str(extent))
				check(button.get_global_rect().size.x<=panel._root.size.x,"long title fits viewport")
				check(get_viewport().gui_get_focus_owner()==button,"selection preserves keyboard/controller focus")
			var stock:Dictionary=Outpost.data.inventory.duplicate(true);var gold:=Outpost.gold();var jobs:Dictionary=Outpost.data.contract_jobs.duplicate(true)
			var first:int=CampResidents.contract_indices(npc.resident_id).back();panel._selected=first;panel._story(first,"offer");await frames(6)
			check(camp.dialogue.is_open() and UIFlow.is_top(camp.dialogue),"story uses existing dialogue screen")
			camp.dialogue._finish();await frames(12)
			check(panel.is_open() and UIFlow.is_top(panel),"story returns to commission list")
			check(Outpost.data.inventory==stock and Outpost.gold()==gold and Outpost.data.contract_jobs==jobs,"story preview does not accept or grant")
			panel.close();await frames()
	# A completed story can be replayed through the same screen without rewards.
	var npc:CampResident=camp.residents_root.get_child(3);panel.resident=npc;npc.interacting=true
	var index:int=CampResidents.contract_indices(npc.resident_id).back();var contract:Dictionary=ExpeditionData.CONTRACTS[index]
	Outpost.data.contracts.append(str(contract.id));panel._selected=index;panel._show();await frames()
	var gold:=Outpost.gold();var count:int=SaveService.data.achievement_stats.get("contracts_delivered",0)
	panel._story(index,"finished");await frames(6);check(camp.dialogue._lines==CampCommissionCatalog.story(str(contract.id),"finished").map(func(line:Dictionary)->Dictionary:
		var result:=line.duplicate(true);result.who=CampResidents.DATA[npc.resident_id].name;result.portrait=CampResidents.ROOT+npc.resident_id+"_portrait.png";return result),"completed replay uses authored ending")
	camp.dialogue._finish();await frames(12);check(Outpost.gold()==gold and int(SaveService.data.achievement_stats.get("contracts_delivered",0))==count,"replay cannot duplicate rewards or achievements")
	panel.close();await frames()
	camp.queue_free();await frames(8)
