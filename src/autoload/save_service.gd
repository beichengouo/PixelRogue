extends Node
## 原子保存营地账本与挂起出征。死亡后的终态不得恢复为活跃出征。

const CORE_MIGRATION := 1
var migration_notice := ""

const SAVE_PATH := "user://pixel_rogue_save.json"

var data := {
	"achievements": {},
	"achievement_stats": {},
	"best_wave": 0,
	"monster_seen": {},
	"monster_kills": {},
	"meta_coins": 0,
	"runs": 0,
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 0.9,
	## 显示类开关（设置页里改）
	"show_enemy_hp": true,
	"reduced_motion": false,
	"replay_seen_dialogue": false,
	"environment_quality": 2,
	"spell_fx_strength": 1.0,
	"screen_shake_strength": 1.0,
	"flash_strength": 1.0,
	"keyboard_bindings": {},
	"attack_mode": "keyboard",
	"mouse_aim_guide": true,
	"control_setup_done": false,
	"input_guide_seen": false,
	"release_notes_seen": "",
	"camp_tutorial": {"generation":1,"step":0,"completed":false,"enabled":true},
	## 活跃出征快照；包含战斗、掉落、天气与撤离状态。
	"run": {},
	"outpost": {},
	"version": 3,
	"rondo_core_migration": 0,
}


var _visual_cleanup:Script

func _ready() -> void:
	call_deferred("_prepare_visual_cleanup")
	if "--room-editor" in OS.get_cmdline_user_args():return
	load_data()
	EventBus.enemy_spawned.connect(_record_encounter)
	EventBus.boss_defeated.connect(func(id:StringName)->void:data.monster_kills["boss:"+str(id)]=int(data.monster_kills.get("boss:"+str(id),0))+1)
	EventBus.enemy_died.connect(func(kind:StringName,_at:Vector2,_coins:int)->void:data.monster_kills[str(kind)]=int(data.monster_kills.get(str(kind),0))+1)
	if not Engine.is_editor_hint(): get_tree().auto_accept_quit = false


func load_data() -> void:
	for path in [SAVE_PATH, SAVE_PATH+".bak"]:
		if not FileAccess.file_exists(path): continue
		var file = FileAccess.open(path,FileAccess.READ)
		if file == null: continue
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			for key in data.keys():
				if parsed.has(key): data[key] = parsed[key]
			# Existing profiles keep a previously chosen control scheme. Fresh
			# profiles have no file and receive the first-launch choice instead.
			if not parsed.has("control_setup_done"):
				data.control_setup_done=parsed.has("attack_mode") or int(parsed.get("runs",0))>0 or not parsed.get("outpost",{}).is_empty()
			_migrate_room_only(parsed,path)
			return


func _migrate_room_only(parsed:Dictionary,source_path:String) -> void:
	if int(parsed.get("rondo_core_migration",0))>=CORE_MIGRATION:return
	var backup:=ProjectSettings.globalize_path(SAVE_PATH)+".pre_rondo_core.bak"
	if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path),backup)!=OK:
		push_warning("旧存档备份失败，本次不执行迁移")
		return
	var before:=data.duplicate(true)
	var had_run:bool=not data.get("run",{}).is_empty() or not data.get("outpost",{}).get("active",{}).is_empty()
	data.run={}
	if data.outpost is Dictionary:data.outpost["active"]={}
	data.rondo_core_migration=CORE_MIGRATION
	data.version=3
	if not save_data():data=before;return
	if had_run:migration_notice="星辉旅途已更新：上一趟未完成出征已结束，营地物资与记录均已保留。"

func take_migration_notice() -> String:
	var message:=migration_notice;migration_notice="";return message


func save_data() -> bool:
	if "--room-editor" in OS.get_cmdline_user_args():return false
	var target := ProjectSettings.globalize_path(SAVE_PATH)
	var pending := target+".tmp"
	var file := FileAccess.open(pending,FileAccess.WRITE)
	if file==null:
		push_warning("存档暂时无法写入")
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK: return false
	if FileAccess.file_exists(target):
		if DirAccess.copy_absolute(target,target+".bak")!=OK: return false
	# rename replaces the destination atomically on the supported Windows filesystem.
	var result := DirAccess.rename_absolute(pending,target)
	if result!=OK:
		push_warning("存档替换失败：%d" % result)
		return false
	return true


func record_run(final_wave: int, coins: int) -> void:
	data["runs"] = int(data["runs"]) + 1
	data["meta_coins"] = int(data["meta_coins"]) + coins
	if final_wave > int(data["best_wave"]):
		data["best_wave"] = final_wave
	save_data()


## ---------------- 局内存档（单存档位）----------------

func save_run(snapshot: Dictionary) -> bool:
	if CampSession.active:return false
	if snapshot.is_empty() or str(snapshot.get("sortie_id","")) != Outpost.active_id(): return false
	if str(Outpost.data.get("active",{}).get("status","")) == "dead": return false
	if snapshot.has("hp_ratio") and float(snapshot.hp_ratio)<=0: return false
	var previous: Dictionary = data.get("run",{}).duplicate(true)
	data["run"] = snapshot
	if save_data(): return true
	data["run"] = previous
	return false


func has_run() -> bool:
	var run = data.get("run", {})
	return typeof(run) == TYPE_DICTIONARY and not (run as Dictionary).is_empty() and not (run as Dictionary).has("terminal")


func run_info() -> Dictionary:
	var run = data.get("run", {})
	return run if typeof(run) == TYPE_DICTIONARY else {}


func clear_run() -> void:
	if get_node_or_null("/root/Outpost") != null and not Outpost.active_id().is_empty():
		if not Outpost.abandon_saved(): return
	data["run"] = {}
	save_data()


func set_volume(key: String, value: float) -> void:
	data[key] = clampf(value, 0.0, 1.0)
	save_data()

var _quitting = false
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_game()

func quit_game() -> void:
	if _quitting: return
	if GameState.run_active and is_instance_valid(GameState.runtime_node):
		if not save_run(GameState.snapshot()):
			push_warning("出征尚未保存，暂不退出，请稍后重试")
			GameState.runtime_node.main.pause_ui.open()
			GameState.runtime_node.main.pause_ui.set_status("保存失败：本局仍保留，请稍后重试退出。")
			return
	_quitting=true
	get_tree().paused=true
	if is_instance_valid(GameState.runtime_node): GameState.runtime_node.motion.cancel()
	AudioManager.shutdown()
	await get_tree().create_timer(0.2,true).timeout
	get_tree().quit()

func _record_encounter(enemy:Node) -> void:
	if not is_instance_valid(enemy):return
	var id:=str(enemy.get("kind"))
	data.monster_seen[id]=true
	if enemy is BossBase:data.monster_seen["boss:"+str(enemy.get("boss_id"))]=true
	if enemy is EnemyBase:
		for affix in enemy.affixes:data.monster_seen["affix:"+str(affix)]=true

func _prepare_visual_cleanup() -> void:
	var path="res://src/visual/visual_cache_cleanup.gd"
	if ResourceLoader.exists(path):_visual_cleanup=load(path)

func _exit_tree() -> void:
	if _visual_cleanup!=null:_visual_cleanup.release()
	_visual_cleanup=null
