extends Node
## Self-contained E-isolated regression for the GM extraction toggle bug.
class ProbeRoom:
 extends "res://src/room_mode/room_main.gd"
 func _ready() -> void: pass
var main: ProbeRoom
var actor: RoomPlayer
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures += 1; printerr("FAIL ", message)
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 call_deferred("run")
func begin(hero: StringName) -> void:
 SaveService.data.control_setup_done = true; SaveService.data.run = {}; Outpost.data.active = {}
 Characters.set_current(hero)
 main = ProbeRoom.new(); add_child(main); main._build_world(); main._build_ui(); main.set_process(false)
 await main._begin_run({"departure":{"loadout":[],"carried":0,"difficulty":1,"initial_level":1}})
 GameState.fate.star_pending = false
 actor = main.player
 GameState.set_process(false); actor.set_physics_process(false); actor.caster.set_physics_process(false)
 actor.equipment_mechanics.set_process(false)
 for node in [main.director, main.special_rooms, main.expansion, main.expedition]: node.set_process(false)
 if is_instance_valid(actor.ilyua_runtime): actor.ilyua_runtime.set_process(false)
func settle_actor() -> void:
 GameState.run_active = false; actor.caster.clear_input_buffer()
 main.queue_free()
 await get_tree().process_frame; await get_tree().process_frame
 Outpost.pending_checkpoint = false
func run() -> void:
 check(OS.get_user_data_dir().replace("\\", "/").begins_with("E:/CodexWorkspace/PixelRogue/work/v21-combat-validation/"), "isolated GM extraction regression")
 if failures: get_tree().quit(1); return
 AchievementTracker.set_process(false); ErrorReporter.interactive = false
 await begin(&"ilyua")
 main._story_queue.clear(); main._story_context = ""; main._reward_pending.clear(); main._reward_offers.clear()
 main.dialogue.cancel(); main.chapter_end_ui.close(); main.choice_ui.cancel()
 main.graph.stage_index = 3
 main.graph.enter(main.graph.stage_terminal)
 main.graph.clear_current(); main.graph.rooms[main.graph.current].rewarded = true
 main.level.load_room(main.graph.rooms[main.graph.current])
 main.director.enter_room(main.graph.rooms[main.graph.current]); main.director._queue.clear(); main.director.room_pending.clear()
 for root in [main.enemies_root, main.chests_root, main.fx_root]:
  for node in root.get_children(): root.remove_child(node); node.queue_free()
 actor.position = main.level.nearest_clear(main.level.room_rect.get_center(), 12)
 actor.velocity = Vector2.ZERO; actor._dash_timer = 0
 GameState.mp = GameState.MAX_MP
 check(main.safe_room() and main.graph.stage_boss_cleared, "fixture is cleared third terminal")
 check(main.gm_pilot.activate(), "actual GM activates without privileged stats")
 var extraction: RoomExtraction = main.expedition.extraction
 for tick in 20:
  main.gm_pilot._process(.1)
  extraction._process(.1)
 print("GM_EXTRACTION_CHANNEL state=", extraction.state, " channel=", extraction.channel, " epoch=", extraction._epoch)
 check(extraction.state == ExtractionDirector.PRAYING and extraction.channel >= 1.9, "GM must not toggle-cancel its pending extraction")
 for tick in 20:
  main.gm_pilot._process(.1)
  extraction._process(.1)
 check(extraction.state == ExtractionDirector.WAITING and extraction.remaining > 3, "GM preserves the normal extraction wait instead of cancelling it")
 main.gm_pilot.stop(); extraction.cancel(false, false)
 await settle_actor()
 AudioManager.shutdown()
 await get_tree().create_timer(.25, true, false, true).timeout
 print("V21_GM_EXTRACTION checks=", checks, " failures=", failures)
 get_tree().quit(1 if failures else 0)
