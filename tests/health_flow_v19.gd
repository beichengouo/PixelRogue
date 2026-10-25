extends "res://tests/inventory_v17.gd"
func clear_enemies()->void:
 main.boss_intro.cancel();main.director.boss=null
 for child in main.enemies_root.get_children():main.enemies_root.remove_child(child);child.queue_free()
 await frames()
func run()->void:
 if not OS.get_user_data_dir().begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(1);return
 AchievementTracker.set_process(false);SaveService.data.reduced_motion=true
 for character in [&"sylphiette",&"xixifu",&"ilyua"]:
  await begin(character);var director:=main.director as RoomDirector
  for difficulty in range(1,5):
   await clear_enemies();GameState.difficulty=difficulty;GameState.run_active=true
   var record:Dictionary=main.graph.rooms[main.graph.current].duplicate(true)
   record.kind="normal";record.encounter=10;record.strength=10;record.boss="";record.boss_stats={};record.cleared=false;record.rewarded=false;record.encounter_mode="spawned"
   main.graph.rooms[main.graph.current]=record;director.enter_room(record);director.phase=WaveDirector.Phase.FIGHT
   check(director.room_pressure_step==0 and director.room_pressure_elapsed==0,"each real room resets pressure")
   var unit:=director._spawn_room_enemy(&"walker",main.level.nearest_clear(main.level.bounds().get_center(),14));unit.set_physics_process(false)
   var damage:=unit.damage;var speed:=unit.move_speed
   var grace:float=director.pressure_grace()
   director.advance_room_pressure(grace+80)
   check(unit.room_pressure_growth==5 and is_equal_approx(unit.damage,damage*1.65) and is_equal_approx(unit.move_speed,speed*1.20),"real spawn reaches capped attack/movement")
   var late:=director._spawn_room_enemy(&"walker",unit.position+Vector2(42,0),false,"boss_minion");late.set_physics_process(false)
   check(late.room_pressure_growth==5 and is_equal_approx(late.damage,late.base_damage*director._damage_scale*1.65),"reinforcement inherits capped growth exactly once")
   var saved:Dictionary=JSON.parse_string(JSON.stringify(main.expedition.capture_room()))
   main.expedition.restore_room(saved);unit=main.enemies_root.get_child(0);unit.set_physics_process(false)
   check(director.room_pressure_step==5 and unit.room_pressure_growth==5 and is_equal_approx(unit.damage,damage*1.65),"real room snapshot restores fifth level without additional multiplication")
   director.advance_room_pressure(999)
   check(unit.room_pressure_growth==5 and is_equal_approx(unit.damage,damage*1.65),"restored room remains capped")
   for enemy:Dictionary in saved.entities:
    if int(enemy.fields.get("room_pressure_growth",0))!=5:continue
    enemy.fields.erase("combat_balance_revision")
    enemy.fields.move_speed=float(enemy.fields.move_speed)*1.3/1.2
    enemy.fields._speed_scale=float(enemy.fields._speed_scale)*1.3/1.2
    enemy.fields.room_pressure_growth=9
    enemy.fields.damage=float(enemy.fields.damage)*10/1.65/(RunDifficulty.attack_multiplier(difficulty)/float([1.0,1.25,1.5,2.0][difficulty-1]))
    enemy.fields._damage_scale=float(enemy.fields._damage_scale)*10/1.65/(RunDifficulty.attack_multiplier(difficulty)/float([1.0,1.25,1.5,2.0][difficulty-1]))
   saved.director.room_pressure_step=9
   main.expedition.restore_room(saved);unit=main.enemies_root.get_child(0);unit.set_physics_process(false)
   check(director.room_pressure_step==5 and unit.room_pressure_growth==5 and is_equal_approx(unit.damage,damage*1.65),"legacy snapshot normalized through actual room restoration")
   await frames()
  var companion:=SummonedAlly.new();companion.player=actor;companion.room=main.level;companion.level=main.level;companion.fx_root=main.fx_root;companion.contract_epoch=GameState.run_epoch;companion.enemy_kind=&"walker"
  main.actors_root.add_child(companion);companion.set_physics_process(false);companion.hp=companion.max_hp*.5;companion.queue_redraw()
  var guardian:=SummonedAlly.new();guardian.player=actor;guardian.room=main.level;guardian.level=main.level;guardian.fx_root=main.fx_root;guardian.contract_epoch=GameState.run_epoch;guardian.enemy_kind=&"treant";guardian.guardian=true
  main.actors_root.add_child(guardian);guardian.set_physics_process(false);guardian.hp=guardian.max_hp*.5;guardian.queue_redraw();await frames(3)
  check(is_instance_valid(companion._sprite) and is_instance_valid(guardian._sprite),"normal and large summons render shared friendly health model")
  check(UnitHealthArt._profiles.has("ally"),"real allied draw uses shared artwork")
  companion.queue_free();guardian.queue_free();await settle_actor()
 AudioManager.shutdown();await frames();print("HEALTH_FLOW_V19 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
