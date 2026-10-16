extends Node
## Lifetime statistics survive expeditions. Run receipts prevent replayed rewards.
signal unlocked(id:String)
var _dirty:=false
var _save_delay:=0.0
var _pending:Array[String]=[]
var _toast:CanvasLayer
func _ready()->void:
	if "--room-editor" in OS.get_cmdline_user_args():set_process(false);return
	process_mode=Node.PROCESS_MODE_ALWAYS
	EventBus.boss_defeated.connect(_boss)
	EventBus.chest_opened.connect(func(_loot:Dictionary)->void:if eligible():add("chests",1))
	EventBus.player_healed.connect(func(value:float,_hp:float,_maximum:float)->void:if eligible() and Characters.current_id()==&"sylphiette":add("holy_healing",value))
	call_deferred("_migrate")
func eligible()->bool:return GameState.run_active and not CampSession.active
func _migrate()->void:
	var stats:Dictionary=SaveService.data.achievement_stats
	_dirty=true;_save_delay=1
	for id in Outpost.data.get("workshop",{}).get("unlocked",{}):
		if bool(Outpost.data.workshop.unlocked[id]):_unique(stats,"research_seen",str(id))
	# Existing bestiary counters predate species achievements. Import once;
	# future counters below exclude training and summoned/split children.
	if not bool(stats.get("species_migrated",false)):
		for kind in AchievementCatalog.ordinary_names():stats["species:"+str(kind)]=maxi(int(stats.get("species:"+str(kind),0)),int(SaveService.data.monster_kills.get(str(kind),0)))
		for kind in BossRoster.DATA:stats["species:boss:"+str(kind)]=maxi(int(stats.get("species:boss:"+str(kind),0)),int(SaveService.data.monster_kills.get("boss:"+str(kind),0)))
		stats.species_migrated=true;_evaluate(false);_dirty=true;_save_delay=1
	# New catalog entries must also evaluate on existing, already migrated saves.
	if bool(stats.get("migrated",false)):_evaluate(false);return
	var kills:=0;var bosses:=0
	for id in SaveService.data.monster_kills:
		if str(id).begins_with("boss:"):bosses+=int(SaveService.data.monster_kills[id])
		else:kills+=int(SaveService.data.monster_kills[id])
	stats.kills=maxi(kills,int(stats.get("kills",0)));stats.bosses=maxi(bosses,int(stats.get("bosses",0)));stats.migrated=true
	_evaluate(false);_dirty=true;_save_delay=1
func add(metric:String,value:float)->void:
	if value<=0:return
	var stats:Dictionary=SaveService.data.achievement_stats;stats[metric]=float(stats.get(metric,0))+value;_changed()
func best(metric:String,value:int)->void:
	var stats:Dictionary=SaveService.data.achievement_stats
	if value<=int(stats.get(metric,0)):return
	stats[metric]=value;_changed()
func _changed()->void:_evaluate();_dirty=true;_save_delay=1
func stage(kind:String,payload:Dictionary={})->Dictionary:
	# Called only by a real transaction, before its existing save. No toast or
	# unlock is published until the owner confirms that the save succeeded.
	var before:={"stats":SaveService.data.achievement_stats.duplicate(true),"run":GameState.achievement_run.duplicate(true)}
	var stats:Dictionary=SaveService.data.achievement_stats
	match kind:
		"fate_claim":
			if not eligible():return before
			stats.fate_claims=int(stats.get("fate_claims",0))+1
			if bool(payload.get("reverse",false)):stats.fate_reverse=int(stats.get("fate_reverse",0))+1
			if GameState.fate.cards.size()>=3:stats.fate_replacements=maxi(1,int(stats.get("fate_replacements",0)))
			stats.fate_pair=maxi(int(stats.get("fate_pair",0)),GameState.fate.cards.size())
			_unique(stats,"fate_seen",str(payload.get("id","")))
			_resolved_reading(stats)
		"fate_pass":
			if eligible():_resolved_reading(stats)
		"departure":
			var star:=str(payload.get("star",""))
			if FateCatalog.STARS.has(star):_unique(stats,"stars_departed",star)
		"alchemy":
			if eligible():stats.field_alchemy=int(stats.get("field_alchemy",0))+maxi(0,int(payload.get("quantity",0)))
		"enchant":
			if eligible():stats.field_enchants=int(stats.get("field_enchants",0))+1
		"research":_unique(stats,"research_seen",str(payload.get("id","")))
		"contract":stats.contracts_delivered=int(stats.get("contracts_delivered",0))+1
		"event":
			if eligible():stats.event_resolutions=int(stats.get("event_resolutions",0))+1
		"extraction":
			if not eligible():return before
			if not FateCatalog.star().is_empty() and not GameState.fate.cards.is_empty():stats.star_returns=int(stats.get("star_returns",0))+1
			var count:=0
			for row in payload.get("rows",[]):
				if bool(row.get("bound",false)) and bool(row.get("stored",false)):count+=int(row.get("count",0))
			stats.bound_returned=int(stats.get("bound_returned",0))+count
			if GameState.chapter_cleared:_unique(stats,"chapters_returned",str(GameState.chapter_id))
	return before
func finish_stage(before:Dictionary,success:bool)->void:
	if not success:
		SaveService.data.achievement_stats=before.stats;GameState.achievement_run=before.run
		return
	if before.stats!=SaveService.data.achievement_stats:_changed()
func _unique(stats:Dictionary,key:String,value:String)->void:
	if value.is_empty():return
	var values:Array=stats.get(key,[])
	if value not in values:values.append(value)
	stats[key]=values
func _resolved_reading(stats:Dictionary)->void:
	GameState.achievement_run.fate_resolved=int(GameState.achievement_run.get("fate_resolved",0))+1
	stats.fate_resolved_best=maxi(int(stats.get("fate_resolved_best",0)),int(GameState.achievement_run.fate_resolved))
func _evaluate(notify:=true)->void:
	for id:String in AchievementCatalog.DATA:
		if AchievementCatalog.unlocked(id) or AchievementCatalog.progress(id)<int(AchievementCatalog.DATA[id].goal):continue
		SaveService.data.achievements[id]=int(Time.get_unix_time_from_system())
		if notify:_pending.append(id);unlocked.emit(id)
func _process(delta:float)->void:
	if _dirty:
		_save_delay-=delta
		if _save_delay<=0:
			_dirty=not SaveService.save_data();_save_delay=5 if _dirty else 0
	if is_instance_valid(_toast) or _pending.is_empty() or UIFlow.has_screen() or TransitionLayer.busy:return
	_toast=AchievementToast.new();_toast.achievement_id=_pending.pop_front();add_child(_toast)
func enemy_defeated(enemy:EnemyBase)->void:
	if not eligible() or enemy.training_target or enemy.loot_origin!="normal" or enemy is BossBase:return
	add("kills",1)
	if AchievementCatalog.ordinary_names().has(str(enemy.kind)):add("species:"+str(enemy.kind),1)
func _boss(id:StringName)->void:
	if not eligible():return
	add("bosses",1)
	if BossRoster.DATA.has(id):add("species:boss:"+str(id),1)
	var ids:Array=GameState.achievement_run.get("bosses",[])
	if str(id) not in ids:ids.append(str(id));GameState.achievement_run.bosses=ids
	if ids.size()>=3:best("three_bosses",1)
func room_cleared(record:Dictionary,growth:int)->void:
	if not eligible():return
	var rooms:Array=GameState.achievement_run.get("rooms",[]);var room_id:=str(record.get("id",""));var key:=room_id+"|"+str(record.get("seed",""))
	if room_id.is_empty() or key in rooms:return
	rooms.append(key);GameState.achievement_run.rooms=rooms;add("rooms",1);best("enrage_best",growth)
	if RunDifficulty.is_bloodbath(GameState.difficulty):add("bloodbath_rooms",1)
	if str(record.get("kind",""))=="boss_rush":add("rush",1)
	if str(record.get("kind",""))=="elite":add("elite_clears",1)
	if str(record.get("kind",""))=="trial":add("trial_clears",1)
func set_equipped()->void:
	if eligible() and LegendarySets.complete():best("sets",1)
func extracted()->void:
	add("extractions",1)
	var heroes:Array=SaveService.data.achievement_stats.get("hero_extractions",[])
	if str(Characters.current_id()) not in heroes:heroes.append(str(Characters.current_id()));SaveService.data.achievement_stats.hero_extractions=heroes;_changed()
