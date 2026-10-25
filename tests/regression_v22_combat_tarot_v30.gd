extends "res://tests/inventory_v17.gd"

func run()->void:
 if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
 AchievementTracker.set_process(false);SaveService.data.reduced_motion=true
 await begin(&"sylphiette")
 var room:Dictionary=main.graph.rooms[main.graph.current]
 room.kind="normal";room.cleared=false;room.rewarded=false
 await rule_checks(room)
 await settle_actor()
 await begin(&"xixifu")
 room=main.graph.rooms[main.graph.current];room.kind="normal";room.cleared=false
 await summoner_checks()
 await settle_actor()
 await begin(&"ilyua")
 room=main.graph.rooms[main.graph.current];room.kind="normal";room.cleared=false
 await archer_checks()
 await settle_actor()
 AudioManager.shutdown();await frames()
 print("V22_COMBAT_TAROT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)

func card(id:String,reversed:=false)->void:
 GameState.fate=FateCatalog.empty();GameState.fate.cards=[{"id":id,"reverse":reversed}]

func rule_checks(room:Dictionary)->void:
 var fate:=actor.equipment_mechanics.fate_runtime
 check(FateCatalog.IDS.size()==10,"ten distinct cards")
 for id:String in FateCatalog.IDS:
  for reversed in [false,true]:
   check(ResourceLoader.exists(FateCatalog.art(id,reversed)),"card art exists "+id+str(reversed))
   var texture:=load(FateCatalog.art(id,reversed)) as Texture2D
   var original:=Image.load_from_file(ProjectSettings.globalize_path(FateCatalog.art(id,reversed)))
   check(original.get_size()==Vector2i(1024,1536) and is_equal_approx(texture.get_width()/float(texture.get_height()),2.0/3.0),"all source canvases and displayed aspect match "+id)
   check(ResourceLoader.exists(FateCatalog.wordmark(id,reversed)),"wordmark exists "+id)
 card("world");GameState.mp=0;actor.shield_hp=0
 fate.world_action("basic");fate.world_action("basic")
 check(FateRuntime.state().world_marks.size()==1,"repeat action only one mark")
 fate.world_action("skill");check(actor.shield_hp==0,"two actions do not complete world")
 fate.world_action("dash")
 check(actor.shield_hp>0 and GameState.mp>0,"world positive grants shield and MP")
 var shield_before:=actor.shield_hp
 fate.world_action("basic");fate.world_action("skill");fate.world_action("dash")
 check(actor.shield_hp==shield_before and not FateRuntime.state().has("world_marks"),"cooldown blocks world farming")
 GameState.fate.cooldowns.clear();fate.world_action("basic");fate.tick(10.1)
 check(not FateRuntime.state().has("world_marks"),"world window expires")
 fate.world_action("basic");fate.room_enter("v22-other-room")
 check(not FateRuntime.state().has("world_marks"),"room change clears incomplete world")
 card("world",true)
 check(is_equal_approx(FateCatalog.shield_factor(),.9),"world reversed shield cost")
 card("fool");actor.shield_hp=0;actor._invuln=0;actor.hp=actor.max_hp
 var hostile:=EnemyBase.new()
 FateRuntime.hurt_after(hostile,10,9,false)
 check(not GameState.fate.pending.has("fool_start"),"continuous hostile damage excluded")
 FateRuntime.hurt_after(hostile,10,0)
 check(not GameState.fate.pending.has("fool_start"),"lethal hit excluded")
 actor.take_damage(1,actor.global_position,hostile)
 check(GameState.fate.pending.has("fool_start") and is_equal_approx(FateCatalog.move_factor(),1.15),"actual surviving hostile hit triggers fool")
 GameState.mp=0;FateRuntime.cast(&"flame_nova",20)
 check(is_equal_approx(GameState.mp,5) and not GameState.fate.pending.has("fool_start"),"one paid cost refund")
 FateRuntime.cast(&"flame_nova",20);check(is_equal_approx(GameState.mp,5),"refund cannot repeat")
 card("fool",true);FateRuntime.hurt_after(hostile,10,9)
 check(is_equal_approx(FateRuntime.hurt_adjust(10,5,false).normal,10.8),"reverse fool normal damage penalty")
 check(is_equal_approx(FateRuntime.hurt_adjust(0,5,false).scar,5),"reverse fool does not increase scars")
 check(is_equal_approx(FateCatalog.direct_factor(&"skill",DamageContext.skill(actor)),1.18),"reverse fool direct damage bonus")
 check(is_equal_approx(FateCatalog.direct_factor(&"skill",DamageContext._context(actor,&"fate")),1),"derived damage not amplified")
 hostile.free()
 card("priestess");actor.holy_runtime.prayer=97
 FateRuntime.cast(&"flame_nova",0)
 check(is_equal_approx(actor.holy_runtime.prayer,97),"prayer does not affect current cast")
 await frames()
 check(is_equal_approx(actor.holy_runtime.prayer,100),"prayer settles after cast and respects cap")
 var raw:=GameState.fate.duplicate(true);var normalized:=FateCatalog.normalize(raw)
 check(normalized.cooldowns.has("hero_priestess"),"resonance cooldown persists")
 var source:=EnemyBase.new();source.base_speed=100;source._speed_scale=1.20;source.room_pressure_growth=5;source.move_speed=300
 check(is_equal_approx(source.effective_chase_speed(),160),"sustained movement capped independently from raw buffs")
 check(is_equal_approx(source.move_speed,300),"cap does not destructively overwrite reversible buffs")
 var runtime:=RoomRuntime.new();var saved:Dictionary={"base_speed":100.0,"move_speed":200.0,"_speed_scale":2.0,"room_pressure_growth":5,"balance_revision":4}
 runtime._apply_fields(source,saved)
 check(is_equal_approx(source.move_speed,120) and is_equal_approx(source._speed_scale,1.2),"legacy pressure speed converted")
 var current:=runtime._fields(source);runtime._apply_fields(source,current)
 check(is_equal_approx(source.move_speed,120),"new snapshot does not convert twice")
 source.free();runtime.free()
 room.kind="altar";room.cleared=true;room.rewarded=true
 FateService.save_override=func()->bool:return true
 var hits:=0
 for seed_value in 3000:
  GameState.fate=FateCatalog.empty()
  var altar:Dictionary={"id":"sample","seed":seed_value,"kind":"altar","cleared":true,"rewarded":true,"delta":{}}
  var reading:=FateService.draw(altar)
  check(reading.offers.size()==3 and reading.offers[0]!=reading.offers[1] and reading.offers[1]!=reading.offers[2] and reading.offers[0]!=reading.offers[2],"weighted sample without replacement")
  if "priestess" in reading.offers:hits+=1
 check(absf(hits/3000.0-27.0/55.0)<.035,"own-card inclusion near 49.1 percent")
 var altar:Dictionary={"id":"fixed","seed":42,"kind":"altar","cleared":true,"rewarded":true,"delta":{}}
 GameState.fate=FateCatalog.empty();var reading:=FateService.draw(altar).duplicate(true)
 check(FateService.draw(altar)==reading and GameState.fate.readings==1,"same altar candidates do not reroll")
 var before:=GameState.fate.duplicate(true);var delta_before:Dictionary=altar.delta.duplicate(true)
 FateService.save_override=func()->bool:return false
 check(not FateService.claim(altar,str(reading.offers[0]),FateService.orientation(altar)),"failed save rejects claim")
 check(GameState.fate==before and altar.delta==delta_before,"failed claim fully rolls back")
 FateService.save_override=Callable()
 room.kind="normal";room.cleared=false;room.rewarded=false

func summoner_checks()->void:
 card("magician")
 var unit:=SummonedAlly.new();unit.room=actor.room;unit.player=actor;unit.contract_epoch=GameState.run_epoch
 main.add_child(unit);await frames()
 actor.equipment_mechanics.fate_runtime.hero_cast(GameState.run_epoch)
 check(is_equal_approx(unit.fate_haste_left,4),"magician buffs own existing contracts")
 check(is_equal_approx(unit.rally_time,0),"resonance does not overwrite rally")
 unit.queue_free()

func archer_checks()->void:
 card("moon")
 var fate:=actor.equipment_mechanics.fate_runtime
 fate.moon_resonance()
 check(is_equal_approx(float(GameState.fate.pending.get("ilyua_pursuit",0)),6),"moon stores pursuit arrow")
 fate.moon_resonance()
 check(is_equal_approx(float(GameState.fate.cooldowns.get("hero_moon",0)),8),"moon resonance cooldown")
 Characters.set_current(&"xixifu")
 check(not FateCatalog.resonance("moon"),"hero identity required for resonance")
 Characters.set_current(&"ilyua")

 await pursuit_tracking_checks()

func pursuit_tracking_checks()->void:
 var fate:=actor.equipment_mechanics.fate_runtime
 actor.equipment_mechanics.set_process(false)
 actor.ilyua_runtime.set_physics_process(false)
 var observations:Array=[]
 for direction:Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
  var origin:=Vector2.INF
  var bounds:=main.level.bounds().grow(-90)
  for y in range(int(bounds.position.y),int(bounds.end.y),36):
   for x in range(int(bounds.position.x),int(bounds.end.x),36):
    var candidate:=Vector2(x,y)
    var destination:=candidate+direction*72+direction.orthogonal()*12
    if candidate.length()>150 and main.level.body_clear(candidate,12) and main.level.body_clear(destination,12) and main.level.projectile_clear(candidate,destination) and main.level.segment_clear(candidate,destination,6,false):origin=candidate;break
   if origin.is_finite():break
  check(origin.is_finite(),"legal non-origin pursuit lane "+str(direction))
  if not origin.is_finite():continue
  actor.global_position=origin
  var enemy:=RoomEnemy.new();enemy.configure(&"walker");enemy.room=main.level;enemy.training_target=true
  enemy.setup(actor,main.level,1,1,1);main.enemies_root.add_child(enemy)
  enemy.set_physics_process(false);enemy.position=origin+direction*72;enemy.hp=100000;enemy.max_hp=100000
  enemy.damage_applied.connect(func(_enemy:EnemyBase,amount:float,source:Node,kind:StringName)->void:observations.append({"amount":amount,"kind":str(kind),"owner":str(source.owner_kind) if source is DamageContext else "other"}))
  GameState.fate=FateCatalog.empty()
  GameState.fate.cards=[{"id":"moon","reverse":false},{"id":"magician","reverse":false},{"id":"empress","reverse":false},{"id":"world","reverse":false}]
  GameState.fate.pending={"ilyua_pursuit":6.0,"magician":5.0}
  GameState.fate.state={"growth":0,"world_marks":["skill"],"room_id":str(main.graph.current)}
  GameState.fate.pending.world_window=10.0
  var old_projectiles:=get_tree().get_nodes_in_group("room_projectiles")
  fate.pursuit_arrow(enemy)
  var arrow:RoomProjectile
  for node in get_tree().get_nodes_in_group("room_projectiles"):
   if node not in old_projectiles and node is RoomProjectile and node.mechanic_tag==&"fate":arrow=node;break
  check(arrow!=null,"production pursuit spawns real projectile "+str(direction))
  if arrow==null:enemy.queue_free();await frames();continue
  arrow.set_physics_process(false)
  check(arrow._nearest_enemy()==enemy,"non-origin four-direction target selected "+str(direction))
  enemy.position+=direction.orthogonal()*12
  check(arrow._nearest_enemy()==enemy,"side-moving target remains tracked "+str(direction))
  var angle_before:=absf(arrow.direction.angle_to(arrow.global_position.direction_to(enemy.global_position)))
  arrow._physics_process(1.0/60)
  var angle_after:=absf(arrow.direction.angle_to(arrow.global_position.direction_to(enemy.global_position)))
  check(angle_after<angle_before,"real pursuit flight turns toward shifted target "+str(direction))
  var before_hp:=actor.hp;var enemy_before:=enemy.hp;var before_observations:=observations.size()
  for tick in 40:
   if arrow.is_queued_for_deletion():break
   arrow._physics_process(1.0/60)
  check(enemy.hp<enemy_before,"real swept pursuit flight hits target "+str(direction))
  check(observations.size()==before_observations+1 and observations.back().kind=="fate" and observations.back().owner=="fate","one derived fate hit with stable ownership "+str(direction))
  check(GameState.fate.pending.has("ilyua_pursuit") and GameState.fate.pending.has("magician") and int(GameState.fate.state.growth)==0 and GameState.fate.state.world_marks==["skill"],"derived hit cannot consume basic procs or grow/world recursively "+str(direction))
  check(is_equal_approx(actor.hp,before_hp),"derived hit grants no lifesteal "+str(direction))
  if not arrow.is_queued_for_deletion():arrow.queue_free()
  enemy.queue_free();await frames()
