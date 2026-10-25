extends "res://tests/v21_gm_extraction.gd"
## Actual RoomPlayer equipment signal and CombatArtWarmup form-key regression.
func run() -> void:
 if not OS.get_user_data_dir().replace("\\", "/").begins_with("E:/CodexWorkspace/PixelRogue/work/v21-combat-validation/"):
  printerr("Unsafe live costume profile"); get_tree().quit(1); return
 AchievementTracker.set_process(false); ErrorReporter.interactive = false
 SaveService.data.reduced_motion = true
 for hero: StringName in [&"ilyua", &"xixifu", &"sylphiette"]:
  CombatArtWarmup.clear()
  await begin(hero)
  main.gm_pilot.set_process(false)
  var sprite: AnimatedSprite2D = actor._sprite
  sprite.play(&"idle_s"); sprite.set_frame_and_progress(2,.375); sprite.pause()
  var normal := sprite.sprite_frames
  var normal_key := "hero:%s:%s" % [hero,false]
  var set_key := "hero:%s:%s" % [hero,true]
  check(not bool(normal.get_meta("set_form",false)), "actual player initially regular " + str(hero))
  check(await CombatArtWarmup.prepare(get_tree()), "regular warmup completes " + str(hero))
  check(CombatArtWarmup._done.has(normal_key) and not CombatArtWarmup._done.has(set_key), "regular warmup uses distinct form key " + str(hero))
  var original_position := actor.position
  var original_collider := (actor.get_node("BodyCollider") as CollisionShape2D).shape
  var set: Dictionary = LegendarySets.DATA[hero]
  var count := 0
  for slot: StringName in ItemDB.SLOTS:
   var item := ItemDB.by_id(StringName(set[slot])).duplicate(true)
   GameState.add_item(item); GameState.equip(GameState.items.back())
   count += 1
   if count < 3:
    check(sprite.sprite_frames == normal and not LegendarySets.form_unlocked(hero), "incomplete equipment does not switch costume " + str(hero))
  var current := sprite.sprite_frames
  check(LegendarySets.form_unlocked(hero) and current != normal and bool(current.get_meta("set_form",false)), "third piece refreshes actual player immediately " + str(hero))
  check(sprite.animation == &"idle_s" and sprite.frame == 2 and is_equal_approx(sprite.frame_progress,.375), "costume switch preserves active pose phase " + str(hero))
  var atlas := current.get_frame_texture(&"idle_s",0) as AtlasTexture
  check(atlas != null and atlas.atlas.resource_path == HanddrawnHeroArt.ROOT + str(hero) + "/set/s.png", "live model loads installed set atlas " + str(hero))
  check(actor.position == original_position and (actor.get_node("BodyCollider") as CollisionShape2D).shape == original_collider, "visual switch preserves actor and collider " + str(hero))
  check((sprite.position + (Vector2(224,392)-Vector2(224,224))*sprite.scale).is_equal_approx(Vector2(0,14)), "actual player preserves canonical feet anchor " + str(hero))
  check(await CombatArtWarmup.prepare(get_tree()), "set warmup completes " + str(hero))
  check(CombatArtWarmup._done.has(normal_key) and CombatArtWarmup._done.has(set_key), "set warmup cannot reuse regular form key " + str(hero))
  for slot: StringName in ItemDB.SLOTS: GameState.unequip(slot)
  check(not LegendarySets.complete() and LegendarySets.form_unlocked(hero) and sprite.sprite_frames == current, "removing gear retains earned live costume " + str(hero))
  HanddrawnHeroArt.clear(); RedrawnHeroArt._cache.clear(); CombatArtWarmup.clear()
  EventBus.equipment_changed.emit()
  check(sprite.sprite_frames != current and bool(sprite.sprite_frames.get_meta("set_form",false)), "actual actor reacquires correct frames after cache clear " + str(hero))
  check(await CombatArtWarmup.prepare(get_tree()) and CombatArtWarmup._done.has(set_key) and not CombatArtWarmup._done.has(normal_key), "reheated cache uses persistent unlocked set key " + str(hero))
  await settle_actor()
 AudioManager.shutdown()
 await get_tree().create_timer(.5,true,false,true).timeout
 print("V21_LIVE_COSTUME checks=%d failures=%d" % [checks,failures])
 get_tree().quit(1 if failures else 0)
