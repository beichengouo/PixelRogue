extends "res://tests/balance_combat_v25.gd"
## Additional provisioned combat fixture, separate from level1 campaign results.
class TalentPlanner:
	extends GMPilot
	func _ready()->void:pass
func provision(_wave:int,_total:int)->void:
	if GameState.gm_pilot_used:return
	var planner:=TalentPlanner.new();planner._develop_character();planner.free()
	for id:StringName in [&"potion_health",&"potion_capacity",&"potion_energy"]:
		for i in (3 if id==&"potion_energy" else 6):GameState.add_item(ItemDB.by_id(id))

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true;Engine.max_fps=0
	EventBus.wave_started.connect(provision)
	EventBus.player_damaged.connect(func(amount:float,_hp:float,_max:float)->void:
		if measuring:damage_taken+=amount)
	EventBus.enemy_spawned.connect(func(enemy:EnemyBase)->void:
		if not measuring:return
		var key:=str(enemy.kind)+":"+enemy.loot_origin;origins[key]=int(origins.get(key,0))+1
		enemy.damage_applied.connect(func(_a:EnemyBase,amount:float,_source:Node,kind:StringName)->void:
			if measuring:damage_kinds[str(kind)]=float(damage_kinds.get(str(kind),0))+amount))
	for hero:StringName in [&"sylphiette",&"xixifu",&"ilyua"]:
		await sample(hero,1,"boss_rush",3,60)
		var row:Dictionary=results.back();row["spent_talent_points"]=GameState.spent_talent_points();row["talent_budget"]=GameState.talent_budget(60);row["fixture_supplies"]={"potion_health":6,"potion_capacity":6,"potion_energy":3}
		check(bool(row.cleared) and int(row.rush_index)==2,"provisioned full three-boss combat "+str(hero))
	var file:=FileAccess.open("E:/CodexWorkspace/PixelRogue/work/v25-balance/provisioned-rush.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	AudioManager.shutdown();await frames();print("BALANCE_RUSH_V25 samples=",results.size()," checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
