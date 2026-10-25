extends RefCounted
## Local pilot policy. All inventory and fate mutations use player transactions.
var pilot
var retry:Dictionary={}
var _approach_key:=""
var _approach_seconds:=0.0
var _buff_at:=0
var _cached_at:=0
var _cached_recipe:Dictionary={}

func reset()->void:
	retry.clear();_approach_key="";_approach_seconds=0;_buff_at=0;_cached_at=0;_cached_recipe={}
func room_key(id:String)->String:
	return "%s:%s:%s"%[pilot.main.graph.stage_index,id,pilot.main.graph.rooms[id].get("seed",0)]
func ready(id:String)->bool:
	return Time.get_ticks_msec()>=int(retry.get(room_key(id),0))
func defer_room(seconds:=15.0)->void:
	retry[room_key(pilot.main.graph.current)]=Time.get_ticks_msec()+int(seconds*1000)

func use_buff()->void:
	if Time.get_ticks_msec()<_buff_at:return
	_buff_at=Time.get_ticks_msec()+800
	for item in GameState.items.duplicate():
		if not ItemDB.is_usable(item):continue
		var effect:Dictionary=item.get("effect",{})
		if str(effect.get("kind",""))!="buff":continue
		var covered:=false
		for buff in GameState.temp_buffs:
			if str(buff.stat)==str(effect.get("stat","")) and float(buff.value)>=float(effect.get("value",0)) and float(buff.remaining)>2:covered=true;break
		if not covered and GameState.use_item(item):return

func recipe(service:Node=null)->Dictionary:
	# Routing needs only a cheap, bounded intention; the service revalidates all
	# costs, quest reserves, capacity, unlocks and save results before crafting.
	if service==null and Time.get_ticks_msec()<_cached_at:return _cached_recipe
	var counts:Dictionary={}
	for item in GameState.items:
		if ItemDB.is_usable(item):counts[str(item.id)]=int(counts.get(str(item.id),0))+1
	var result:Dictionary={};var actor:RoomPlayer=pilot.main.player
	var order:Array=["alch_capacity","alch_health","alch_energy","alch_arcane","alch_focus","alch_wind","alch_frost"]
	for id in order:
		var entry:=MaterialWorkshopCatalog.recipe(id)
		if not MaterialWorkshopCatalog.unlocked(str(entry.research)):continue
		if id=="alch_health" and actor.bloodbath_active():continue
		if id=="alch_capacity" and actor.permanent_hp_loss()<=0:continue
		var target:=2 if id in ["alch_health","alch_energy"] else 1
		if int(counts.get(str(entry.product),0))>=target:continue
		var slots:=0
		for product_id in counts:
			slots+=ceili(float(int(counts[product_id])+(1 if product_id==str(entry.product) else 0))/5)
		if not counts.has(str(entry.product)):slots+=1
		if slots>GameState.BAG_CATEGORY_CAPACITY:continue
		var product:=ExpeditionData.resolve(str(entry.product));var effect:Dictionary=product.get("effect",{})
		if str(effect.get("kind",""))=="buff":
			var covered:=false
			for buff in GameState.temp_buffs:
				if str(buff.stat)==str(effect.get("stat","")) and float(buff.value)>=float(effect.get("value",0)) and float(buff.remaining)>8:covered=true;break
			if covered:continue
		for variant in entry.variants.size():
			var error:=MaterialWorkshop.cost_error(entry.variants[variant],false,true) if service==null else str(MaterialWorkshop.preview("craft",id,variant,false,true,1,service).error)
			if error.is_empty():result={"id":id,"variant":variant};break
		if not result.is_empty():break
	if service==null:_cached_at=Time.get_ticks_msec()+1000;_cached_recipe=result
	return result

func wants_altar(record:Dictionary)->bool:
	if not FateCatalog.active() or str(record.get("kind",""))!="altar":return false
	if bool(record.get("delta",{}).get("fate_guard",{}).get("dead",false)):return false
	var reading:Dictionary=record.get("delta",{}).get("fate_reading",{})
	return not bool(reading.get("done",false)) and (not reading.is_empty() or int(GameState.fate.get("readings",0))<3)

func priority(id:String)->float:
	if not ready(id):return 0
	var record:Dictionary=pilot.main.graph.rooms[id]
	if wants_altar(record):return 170
	if str(record.kind) in ["shop","tavern"] and not recipe().is_empty():
		return 205 if pilot.main.player.hp<pilot.main.player.max_hp*.65 or GameState.mp<35 else 155
	return 0

func visit(step:float)->bool:
	var main=pilot.main;var id:=str(main.graph.current)
	if not ready(id):return false
	var record:Dictionary=main.graph.rooms[id];var target:Node2D
	if wants_altar(record) and FateService.eligible(record) and is_instance_valid(main.fate_altar) and main.fate_altar.visible and main.fate_altar.hp>0:target=main.fate_altar
	elif str(record.kind) in ["shop","tavern"] and not recipe().is_empty():target=main.npc if str(record.kind)=="shop" else main.tavern
	if not is_instance_valid(target):return false
	var key:=room_key(id)
	if _approach_key!=key:_approach_key=key;_approach_seconds=0
	_approach_seconds+=step
	if _approach_seconds>12:defer_room(30);_approach_key="";return false
	if target is FateAltar:
		if target.try_interact():
			main.player.movement_override=Vector2.ZERO
			if not main.fate_ui.is_open():defer_room()
			return true
	elif target.in_range and target.is_open:
		target.try_interact();main.player.movement_override=Vector2.ZERO;return true
	main.player.movement_override=main.level.path_direction(main.player.global_position,main.level.nearest_clear(target.global_position,12),12,false)
	return true

func service_step(service:Node)->void:
	var choice:=recipe(service)
	if not choice.is_empty():
		var error:=MaterialWorkshop.craft(choice.id,int(choice.variant),false,true,service,1)
		_cached_at=0
		if error.is_empty():
			# Newly crafted healing follows the same use policy as owned potions.
			if pilot.main.player.hp<pilot.main.player.max_hp*.65:pilot._use_potion("heal")
			if GameState.mp<35:pilot._use_potion("mana")
			return
		print("BOT supply deferred: ",error)
	# A failed atomic write is not retried every UI tick, nor is it bypassed.
	defer_room(30);_approach_key="";service.close(true)

func choose_fate(choice:FateChoiceUI)->void:
	if not ready(pilot.main.graph.current):choice.cancel();return
	var best:=-INF;var selected:=0
	for index in choice.offers.size():
		var card:Dictionary=choice.offers[index];var id:=str(card.fate_id);var reverse:=bool(card.reverse)
		var score:=float({"star":80,"empress":75,"world":65,"emperor":60,"magician":55,"moon":55,"chariot":45,"fool":40,"hermit":35,"priestess":30}.get(id,0))
		if id==FateCatalog.owned_card():score+=40
		if id in ["star","empress"] and pilot.main.player.permanent_hp_loss()>0:score+=30
		if id=="hermit" and Characters.current_id()==&"xixifu":score-=45
		if reverse and id in ["empress","fool"] and pilot.main.player.hp<pilot.main.player.max_hp*.65:score-=40
		if reverse and id=="moon" and Characters.current_id()==&"ilyua":score-=15
		if score>best:best=score;selected=index
	choice._choose_from_input(selected,choice._selection_epoch,true)
func confirm_fate(choice:FateChoiceUI)->void:
	choice.confirmation._dismiss(true)
	if not choice._committing:defer_room(30);choice.cancel()
