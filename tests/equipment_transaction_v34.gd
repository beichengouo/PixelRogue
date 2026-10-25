extends Node
## Full autoload transaction probe, strictly limited to isolated E-drive data.
const ROOT := "E:/CodexWorkspace/PixelRogue/work/v34-gameplay-polish/"
var checks := 0
var failures := 0

func real_audio_wait(milliseconds:int)->void:
 # The audio mixer follows wall time even when --fixed-fps accelerates scene
 # timers. Give each transaction a real mix frame before replacing playback.
 var end_at:=Time.get_ticks_msec()+milliseconds
 while Time.get_ticks_msec()<end_at:await get_tree().process_frame

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL ", message)

func _ready() -> void:
 call_deferred("run")

func same_record(a: Dictionary, b: Dictionary) -> bool:
 for field in ["id", "uid", "enchant"]:
  if str(a.get(field, "")) != str(b.get(field, "")): return false
 for field in ["bound", "workshop_made"]:
  if bool(a.get(field, false)) != bool(b.get(field, false)): return false
 for field in ["base", "sale_value"]:
  if int(a.get(field, 0)) != int(b.get(field, 0)): return false
 return true

func run() -> void:
 if not OS.get_user_data_dir().replace("\\", "/").begins_with(ROOT):
  printerr("Unsafe equipment transaction user directory")
  get_tree().quit(1)
  return
 ErrorReporter.interactive = false
 AchievementTracker.set_process(false)
 Outpost.set_process(false)
 GameState.set_process(false)
 CampSession.active = false
 SaveService.data.control_setup_done = true
 for hero: StringName in [&"ilyua", &"xixifu", &"sylphiette"]:
  Characters.set_current(hero)
  Outpost.data.active = {}
  Outpost.data.inventory = {}
  Outpost.data.gold = 0
  SaveService.data.run = {}
  GameState.new_run(4501)
  check(Outpost.start_sortie([], 0, 0, 1, 1), "actual empty level1 departure " + str(hero))
  GameState.sortie_id = Outpost.active_id()
  GameState.coins = 10000
  Outpost.pending_checkpoint = false
  var set: Dictionary = LegendarySets.DATA[hero]
  for slot: StringName in ItemDB.SLOTS:
   # Keep distinct UI transactions on separate audio-mix frames, like real
   # clicks, rather than overwriting pending playback requests in one frame.
   await real_audio_wait(40)
   var item := ItemDB.by_id(StringName(set[slot])).duplicate(true)
   var enchant := str({"weapon":"ember", "armor":"moss", "accessory":"tide"}[str(slot)])
   check(str(MaterialWorkshopCatalog.ENCHANTS[enchant].slot) == str(slot), "legal enchant fixture " + str(slot))
   item.enchant = enchant
   item.sale_value = 137
   item.workshop_made = true
   GameState.add_item(item)
   GameState.add_item(item)
   var first: Dictionary = GameState.items[-2]
   var second: Dictionary = GameState.items[-1]
   check(str(first.uid) != str(second.uid), "same ID receives independent UID " + str(item.id))
   check(SaveService.save_run(GameState.snapshot()), "pre-failure checkpoint committed " + str(item.id))
   var disk_before := FileAccess.get_file_as_bytes(SaveService.SAVE_PATH)
   var save_before := SaveService.data.duplicate(true)
   var outpost_before := Outpost.data.duplicate(true)
   var bag_before := GameState.items.duplicate(true)
   var coins_before := GameState.coins
   var blocked := ProjectSettings.globalize_path(SaveService.SAVE_PATH) + ".tmp"
   check(blocked.replace("\\", "/").begins_with(ROOT), "disk blocker confined to isolated profile")
   check(DirAccess.make_dir_absolute(blocked) == OK, "actual atomic-save blocker created")
   check(not GameState.bind_inventory_equipment(first), "disk failure rejects paid binding " + str(item.id))
   check(GameState.coins == coins_before and GameState.items == bag_before, "failure restores entire bag and coins " + str(item.id))
   check(Outpost.data == outpost_before and SaveService.data == save_before, "failure restores complete outpost/save memory " + str(item.id))
   check(FileAccess.get_file_as_bytes(SaveService.SAVE_PATH) == disk_before, "failure leaves committed disk bytes unchanged " + str(item.id))
   check(DirAccess.remove_absolute(blocked) == OK, "disk blocker removed")
   var fee := BoundEquipment.binding_price(first)
   check(fee > 0 and GameState.bind_inventory_equipment(first), "retry succeeds once " + str(item.id))
   check(GameState.coins == coins_before-fee and BoundEquipment.is_bound(first) and not BoundEquipment.is_bound(second), "only chosen UID bound and charged " + str(item.id))
   check(not GameState.bind_inventory_equipment(first) and GameState.coins == coins_before-fee, "duplicate binding cannot charge twice " + str(item.id))
   var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveService.SAVE_PATH)).run
   var packed_first := ExpeditionData.pack(first)
   var packed_second := ExpeditionData.pack(second)
   var disk_records: Dictionary = {}
   for record: Dictionary in stored.expedition_items: disk_records[str(record.uid)] = record
   check(disk_records.has(str(first.uid)) and same_record(disk_records[str(first.uid)], packed_first), "paid UID binding/enchant/value serialized " + str(item.id))
   check(disk_records.has(str(second.uid)) and same_record(disk_records[str(second.uid)], packed_second), "same ID sibling remains separately unbound " + str(item.id))
   GameState.equip(first)
   check(SaveService.save_run(GameState.snapshot()), "equipped record committed " + str(item.id))
   stored = JSON.parse_string(FileAccess.get_file_as_string(SaveService.SAVE_PATH)).run
   GameState.restore(stored)
   check(same_record(ExpeditionData.pack(GameState.equipped(slot)), packed_first), "equipped UID/bound/legal enchant survives disk restore " + str(item.id))
   var sibling := {}
   for restored: Dictionary in GameState.items:
    if str(restored.uid) == str(packed_second.uid): sibling = restored
   check(not sibling.is_empty() and same_record(ExpeditionData.pack(sibling), packed_second), "unbound sibling survives equipped restore " + str(item.id))
   Outpost.pending_checkpoint = false
   await real_audio_wait(40)
 GameState.run_active = false
 # These synchronous disk transactions can issue play/stop before the first mix.
 # Allow the audio server to register playback before shutdown drains it.
 await real_audio_wait(100)
 AudioManager.shutdown()
 await real_audio_wait(250)
 print("V21_EQUIPMENT_TRANSACTION checks=%d failures=%d" % [checks, failures])
 get_tree().quit(1 if failures else 0)
