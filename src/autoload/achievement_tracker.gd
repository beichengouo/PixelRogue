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
	EventBus.keys_changed.connect(func(value:int)->void:if eligible():best("keys_best",value))
	EventBus.player_healed.connect(func(value:float,_hp:float,_maximum:float)->void:if eligible() and Characters.current_id()==&"sylphiette":add("holy_healing",value))
	call_deferred("_migrate")
func eligible()->bool:return GameState.run_active and not CampSession.active
func _migrate()->void:
	var stats:Dictionary=SaveService.data.achievement_stats
	# Existing bestiary counters predate species achievements. Import once;
	# future counters below exclude training and summoned/split children.
	if not bool(stats.get("species_migrated",false)):
		for kind in AchievementCatalog.ordinary_names():stats["species:"+str(kind)]=maxi(int(stats.get("species:"+str(kind),0)),int(SaveService.data.monster_kills.get(str(kind),0)))
		for kind in BossRoster.DATA:stats["species:boss:"+str(kind)]=maxi(int(stats.get("species:boss:"+str(kind),0)),int(SaveService.data.monster_kills.get("boss:"+str(kind),0)))
		stats.species_migrated=true;_evaluate(false);_dirty=true;_save_delay=1
	if bool(stats.get("migrated",false)):return
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
	if is_instance_valid(_toast) or _pending.is_empty():return
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
func set_equipped()->void:
	if eligible() and LegendarySets.complete():best("sets",1)
func extracted()->void:
	add("extractions",1)
	var heroes:Array=SaveService.data.achievement_stats.get("hero_extractions",[])
	if str(Characters.current_id()) not in heroes:heroes.append(str(Characters.current_id()));SaveService.data.achievement_stats.hero_extractions=heroes;_changed()
