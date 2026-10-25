extends Node
## Real extraction state/settlement callbacks, using fixed simulated dt fixtures.
class ProbeRoom:
 extends "res://src/room_mode/room_main.gd"
 var returned := false
 func _ready() -> void: pass
 func _autoplay_requested() -> bool: return true
 func _extracted_to_camp() -> void: returned = true
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures += 1; printerr("FAIL ", message)
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 call_deferred("run")
func run() -> void:
 if not OS.get_user_data_dir().replace("\\", "/").begins_with("E:/CodexWorkspace/PixelRogue/work/v21-combat-validation/"):
  printerr("Unsafe extraction stage profile"); get_tree().quit(1); return
 ErrorReporter.interactive = false; AchievementTracker.set_process(false); Outpost.set_process(false)
 TransitionLayer.boot_played = true; SaveService.data.reduced_motion = true; SaveService.data.control_setup_done = true
 StoryState.flags.chapter_2_unlocked = true
 for chapter: StringName in [ChapterCatalog.FIRST, ChapterCatalog.NEXT]:
  for stage in range(1, 5):
   for safe: bool in [false, true]:
    await sample(chapter, stage, safe)
 AudioManager.shutdown()
 await get_tree().create_timer(.5, true, false, true).timeout
 print("V21_EXTRACTION_STAGES checks=%d failures=%d" % [checks, failures])
 get_tree().quit(1 if failures else 0)
func sample(chapter: StringName, stage: int, safe: bool) -> void:
 var label := "%s stage%d safe=%s" % [chapter, stage, safe]
 SaveService.data.run = {}; Outpost.data.active = {}; Outpost.data.inventory = {"forest_sample":5}; Outpost.data.gold = 0
 Outpost.pending_checkpoint = false
 Characters.set_current(&"ilyua"); GameState.new_run(4501); GameState.chapter_id = chapter
 check(Outpost.start_sortie([], 0, 0, 1, 1, chapter), "actual departure " + label)
 GameState.sortie_id = Outpost.active_id()
 GameState.fate.star_pending = false
 var graph := RoomGraph.new(); graph.begin(4501, chapter)
 for previous in range(1, stage):
  graph.enter(graph.stage_terminal); graph.clear_current(); graph.rooms[graph.current].rewarded = true
  check(graph.advance_stage(), "prior stage qualification " + label)
 # Withdrawal before the current terminal: stage4 keeps earned normal eligibility,
 # while stages1/2/3 are partial until that third terminal is actually completed.
 for id: String in graph.rooms:
  if str(graph.rooms[id].kind) == "normal": graph.enter(id); break
 graph.rooms[graph.current].cleared = safe
 graph.rooms[graph.current].rewarded = safe
 GameState.chapter_cleared = graph.normal_clear_eligible
 var snapshot := GameState.snapshot(); snapshot.world_state = {"graph":graph.snapshot()}
 var main := ProbeRoom.new(); main.process_mode = Node.PROCESS_MODE_PAUSABLE
 add_child(main); main._build_world(); main._build_ui(); main._connect_events()
 await main._begin_run(snapshot)
 var actor := main.player
 actor.set_physics_process(false); actor.caster.set_physics_process(false); actor.equipment_mechanics.set_process(false)
 if is_instance_valid(actor.ilyua_runtime): actor.ilyua_runtime.set_process(false)
 GameState.set_process(false)
 for node in [main.director, main.special_rooms, main.expansion, main.expedition, main.gm_pilot]: node.set_process(false)
 main._story_queue.clear(); main._story_context = ""; main._reward_offers.clear(); main._reward_pending.clear(); main.dialogue.cancel()
 main.director._queue.clear(); main.director.room_pending.clear()
 for node in main.enemies_root.get_children(): main.enemies_root.remove_child(node); node.queue_free()
 main.graph.rooms[main.graph.current].cleared = safe
 actor.velocity = Vector2.ZERO; actor._dash_timer = 0
 var material := ExpeditionData.material("forest_sample")
 GameState.add_item(material); GameState.add_item(material)
 check(int(Outpost.data.inventory.forest_sample) == 5, "loot still unbanked before reception " + label)
 var extraction: RoomExtraction = main.expedition.extraction
 extraction.set_process(false)
 check(extraction.request(), "real request accepted " + label)
 check(extraction.wait_duration == (5.0 if safe else 30.0), "real safe/combat duration " + label)
 for tick in 401:
  if extraction.state == ExtractionDirector.SETTLING: break
  extraction._process(.1)
 check(extraction.state == ExtractionDirector.SETTLING, "prayer wait reception completed " + label)
 var start := Time.get_ticks_msec()
 while (not main.returned or TransitionLayer.busy) and Time.get_ticks_msec()-start < 6000:
  await get_tree().process_frame
 check(main.returned, "original covered settlement callback returned " + label)
 var result: Dictionary = Outpost.data.get("last_result", {})
 check(str(result.get("outcome", "")) == "extracted" and int(result.get("stage_index", 0)) == stage, "extraction outcome and stage " + label)
 check(str(result.get("clear_tier", "")) == ("normal" if stage == 4 else "withdrawal"), "earned eligibility preserved on early return " + label)
 check(int(Outpost.data.inventory.get("forest_sample", 0)) == 7, "only successful extraction banks both materials " + label)
 var bank: Dictionary = Outpost.data.inventory.duplicate(true)
 check(Outpost.settle_sortie("extracted").is_empty() and Outpost.data.inventory == bank, "duplicate completion cannot bank twice " + label)
 print("V21_EXTRACTION_STAGE_OK ", label)
 GameState.run_active = false; main.queue_free()
 await get_tree().process_frame; await get_tree().process_frame
 Outpost.pending_checkpoint = false
