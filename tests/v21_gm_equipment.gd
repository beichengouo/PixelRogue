extends Node
class QuietPilot:
 extends GMPilot
 func _ready() -> void: pass
 func _exit_tree() -> void: pass
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL ", message)
func _ready() -> void:
 call_deferred("run")
func run() -> void:
 if not OS.get_user_data_dir().replace("\\", "/").begins_with("E:/CodexWorkspace/PixelRogue/work/v21-combat-validation/"):
  printerr("Unsafe GM equipment profile"); get_tree().quit(1); return
 AchievementTracker.set_process(false)
 Outpost.set_process(false)
 GameState.set_process(false)
 var pilot := QuietPilot.new()
 add_child(pilot)
 for hero: StringName in [&"ilyua", &"xixifu", &"sylphiette"]:
  for target_level in [1, 20, 30, 34, 35, 36, 37, 38, 39, 46]:
   Characters.set_current(hero)
   GameState.new_run(4502)
   while GameState.level < target_level: GameState.gain_exp(GameState.exp_needed(GameState.level))
   for id: StringName in [&"gem_crown", &"accessory_cadence_prism"]: GameState.add_item(ItemDB.by_id(id))
   GameState.equip(GameState.items[0])
   var sequence: Array = []
   var changes := 0
   var previous := str(GameState.equipped(&"accessory").id)
   for tick in 20:
    pilot._equip_upgrades()
    var current := str(GameState.equipped(&"accessory").id)
    sequence.append(current)
    if current != previous: changes += 1
    previous = current
   print("V21_GM_EQUIPMENT_SEQUENCE ", JSON.stringify({"hero":hero,"level":target_level,"changes":changes,"sequence":sequence}))
   check(changes <= 1, "unchanged legal equipment settles without oscillation %s level%d" % [hero,target_level])
 GameState.run_active = false
 pilot.queue_free()
 # Flush play requests from this synchronous fixture before stopping audio.
 await get_tree().create_timer(.1, true, false, true).timeout
 AudioManager.shutdown()
 await get_tree().create_timer(.25, true, false, true).timeout
 print("V21_GM_EQUIPMENT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(1 if failures else 0)
