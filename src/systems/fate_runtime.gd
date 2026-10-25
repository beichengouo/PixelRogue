class_name FateRuntime
extends RefCounted
var owner:EquipmentMechanics
var _target:WeakRef
var _room_id:=""
var _ally_poll:=0.0
var _last_position:=Vector2.INF
var _walk_distance:=0.0
var _moon_visual:Sprite2D
var _dash_points:Array=[]
static func runtime()->FateRuntime:
 var hero:=GameState.player as RoomPlayer
 return hero.equipment_mechanics.fate_runtime if is_instance_valid(hero) and is_instance_valid(hero.equipment_mechanics) else null
static func state()->Dictionary:
 if not GameState.fate.has("state"):GameState.fate.state={}
 return GameState.fate.state
static func combat_room()->Dictionary:
 var room:=FateService.record()
 return room if not room.is_empty() and not bool(room.get("cleared",true)) and RoomGraph.is_combat(str(room.kind)) else {}
static func direct_source(source:Node)->bool:
 if not is_instance_valid(source):return false
 if source is DamageContext:return source.owner_kind in [&"skill",&"player"] and source.report_channel!=&"dot"
 if source is RoomProjectile:
  return source.damage_owner==&"player" and source.mechanic_tag not in [&"equipment",&"character_proc",&"fate"] and (not source.is_basic_attack or source.attack_receipt!=null)
 return source is Player
static func disconnected()->bool:
 return FateCatalog.active() and float(state().get("alone",0))>=3 and not FateCatalog.allies_near(GameState.player)
static func _room_state()->Dictionary:
 var room:=FateService.record()
 if room.is_empty():return {}
 if not room.delta.get("fate_v2") is Dictionary:
  var legacy:Dictionary=room.delta.get("fate_repairs",{})
  var old_uses:=int(legacy.get("uses",0))
  # Legacy snapshots did not record actual repaired points; conservatively
  # reserve their spent allowance rather than granting a second room budget.
  room.delta.fate_v2={"blooms":mini(2,old_uses),"repair_used":minf(.05,old_uses*(.02 if FateCatalog.rank("empress")==2 else .01)),"migrated":true}
 return room.delta.fate_v2
static func repair(amount:float)->float:
 if not FateCatalog.active() or not is_instance_valid(GameState.player) or amount<=0:return 0
 var data:=_room_state()
 if data.is_empty() and FateService.record().is_empty():return 0
 var base:float=GameState.player.stats.get_value(&"max_hp")
 var remaining:=maxf(0,FateCatalog.RULES.repair_cap-float(data.get("repair_used",0)))
 var actual:float=GameState.player.repair_capacity(minf(amount,base*remaining))
 if actual>0:
  data.repair_used=float(data.get("repair_used",0))+actual/maxf(1,base)
  FateSpellFX.play(GameState.player,"flower",GameState.player.global_position,56)
  Effects.text(GameState.player.get_parent(),GameState.player.global_position-Vector2(0,62),"伤痕修复 +%.1f"%actual,Color("9be9bd"),14)
  AudioManager.play(&"scar_repair",-15,0)
 return actual
static func hurt_adjust(normal:float,scar:float,had_shield:bool)->Dictionary:
 if not FateCatalog.active():return {"normal":normal,"scar":scar}
 var data:=_room_state();var adjusted:=scar
 var guard:=float(GameState.fate.pending.get("foresight",0))>0
 if scar>0 and not combat_room().is_empty():
  if FateCatalog.star()=="lantern" and not bool(data.get("lantern_used",false)):
   adjusted*=.5;data.lantern_used=true
  if had_shield and FateCatalog.rank("emperor")>0:
   var rank:=FateCatalog.rank("emperor");var limit:=2 if rank==1 else 1
   if int(data.get("emperor_uses",0))<limit:
    adjusted*=.65 if rank==1 else .8;data.emperor_uses=int(data.get("emperor_uses",0))+1
 if guard and (normal>0 or scar>0):
  normal*=.75;adjusted*=.75;GameState.fate.pending.erase("foresight")
 if FateCatalog.rank("empress")==2:normal*=1.08
 if float(GameState.fate.pending.get("fool_risk",0))>0:normal*=1.08
 if adjusted<scar:
  FateSpellFX.play(GameState.player,"ward",GameState.player.global_position,58)
  Effects.text(GameState.player.get_parent(),GameState.player.global_position-Vector2(0,62),"伤痕减免 %.1f"%(scar-adjusted),Color("99ceef"),14)
 return {"normal":normal,"scar":adjusted}
func ready(id:String)->bool:return float(GameState.fate.cooldowns.get(id,0))<=0
func start(id:String,seconds:float)->void:GameState.fate.cooldowns[id]=seconds
func tick(delta:float)->void:
 if not FateCatalog.active() or not is_instance_valid(owner.actor):return
 for category in ["cooldowns","pending"]:
  for key in GameState.fate[category].keys():
   GameState.fate[category][key]=maxf(0,float(GameState.fate[category][key])-delta)
   if GameState.fate[category][key]<=0:GameState.fate[category].erase(key)
 var actor:=owner.actor;var data:=state()
 if float(GameState.fate.pending.get("world_window",0))<=0:data.erase("world_marks")
 var normal_motion:=actor._dash_timer<=0 and not actor._normal_dash_phase and actor._hurt_timer<=0 and (not is_instance_valid(actor.ilyua_runtime) or actor.ilyua_runtime.step_left<=0) and actor.extraction_pose==&""
 var still:=normal_motion and _walk_distance<=6.0*delta and actor.velocity.length()<=6
 if FateCatalog.rank("priestess")>0:
  GameState.fate.still=float(GameState.fate.get("still",0))+delta if still else 0.0
  var reversed:=FateCatalog.rank("priestess")==2
  if GameState.fate.still>=(1.3 if reversed else .9) and ready("priestess"):
   GameState.fate.pending.priestess=6.0;start("priestess",9 if reversed else 8)
   FateSpellFX.play(actor,"ward",actor.global_position,44)
 if FateCatalog.rank("hermit")>0:
  _ally_poll-=delta
  if _ally_poll<=0:
   _ally_poll=.2;data.near_allies=FateCatalog.allies_near(actor)
  data.alone=0.0 if bool(data.get("near_allies",false)) else float(data.get("alone",0))+delta
  if FateCatalog.rank("hermit")==1 and float(data.alone)>=4 and ready("hermit") and float(GameState.fate.pending.get("hermit",0))<=0:
   GameState.fate.pending.hermit=8.0;start("hermit",8)
 _tick_moon(delta)
 _tick_trails(delta)
 _walk_distance=0
func record_motion(from:Vector2,to:Vector2,normal:bool,dashing:bool)->void:
 if not FateCatalog.active():return
 if normal:_walk_distance+=from.distance_to(to)
 if dashing:
  if _dash_points.is_empty():_dash_points.append([from.x,from.y])
  if _dash_points.size()<128:_dash_points.append([to.x,to.y])
func motion_reset(clear_still:=true)->void:
 _last_position=Vector2.INF;_walk_distance=0;_dash_points.clear()
 if clear_still:GameState.fate.still=0
 _clear_moon_visual()
func _clear_moon_visual()->void:
 if is_instance_valid(_moon_visual):_moon_visual.queue_free()
 _moon_visual=null
static func cast(id:StringName,paid:float=0.0)->void:
 var self_runtime:=runtime()
 if not FateCatalog.active() or self_runtime==null:return
 var data:=state();data.cast_serial=int(data.get("cast_serial",0))+1;data.small_cast=not Skills.is_ultimate(id)
 var small:=not Skills.is_ultimate(id)
 if FateCatalog.star()=="spring" and not combat_room().is_empty() and paid>0:
  data.spring_progress=float(data.get("spring_progress",0))+paid/maxf(1,GameState.MAX_MP)
  while float(data.spring_progress)>=FateCatalog.RULES.spring_threshold:
   data.spring_progress=float(data.spring_progress)-FateCatalog.RULES.spring_threshold
   data.drops=mini(2,int(data.get("drops",0))+1)
 if not small:return
 self_runtime.world_action("skill")
 if float(GameState.fate.pending.get("fool_start",0))>0:
  GameState.fate.pending.erase("fool_start");GameState.add_mp(paid*.25)
 self_runtime.call_deferred("hero_cast",GameState.run_epoch)
 if FateCatalog.star()=="spring" and int(data.get("drops",0))>0 and self_runtime.ready("spring"):
  data.drops=int(data.drops)-1;GameState.add_mp(GameState.MAX_MP*FateCatalog.RULES.spring_refund)
  GameState.fate.pending.spring_speed=3.0;self_runtime.start("spring",5)
  FateSpellFX.play(self_runtime.owner.actor,"water",self_runtime.owner.actor.global_position,52)
 if float(GameState.fate.pending.get("priestess",0))>0:
  GameState.fate.pending.erase("priestess");RunBuildMetrics.trigger("fate:priestess")
  if FateCatalog.rank("priestess")==1:
   GameState.add_mp(paid*.2);GameState.fate.pending.foresight=4.0
  elif FateCatalog.rank("priestess")==2:GameState.fate.pending.priestess_burst=4.0
 if FateCatalog.rank("magician")==1 and self_runtime.ready("magician"):
  GameState.fate.pending.magician=5.0;self_runtime.start("magician",3)
 elif FateCatalog.rank("magician")==2 and self_runtime.ready("magician_chain"):
  if float(GameState.fate.pending.get("magician_chain",0))>0:
   GameState.fate.pending.erase("magician_chain");self_runtime.start("magician_chain",6)
   var targets:=self_runtime.owner.nearest_enemies(self_runtime.owner.actor.global_position,216,1)
   if not targets.is_empty():RunBuildMetrics.trigger("fate:magician");self_runtime.area(targets[0].global_position,72,.6,"arcane")
   else:FateSpellFX.play(self_runtime.owner.actor,"arcane",self_runtime.owner.actor.global_position,46)
  else:GameState.fate.pending.magician_chain=7.0
 # A blood moon requires a small skill cast AFTER applying its mark.
 if data.get("moon") is Dictionary and not data.moon.is_empty():data.moon.skill_armed=true
static func cast_factor()->float:return 1.0 # Old per-cast snapshots no longer carry fate bonuses.
func basic_hit(enemy:EnemyBase,receipt:BasicAttackReceipt)->void:
 if not FateCatalog.active() or receipt==null or not receipt.claim_effect(&"fate_v2_main") or not is_instance_valid(enemy):return
 var data:=state()
 world_action("basic")
 if float(GameState.fate.pending.get("ilyua_pursuit",0))>0:
  GameState.fate.pending.erase("ilyua_pursuit");pursuit_arrow(enemy)
 if FateCatalog.star()=="torch" and ready("torch"):
  if int(data.get("fire",0))>=3:
   data.fire=0;start("torch",2.5);area(enemy.global_position,72,.4,"fire")
  else:data.fire=int(data.get("fire",0))+1
 if FateCatalog.rank("magician")==1 and float(GameState.fate.pending.get("magician",0))>0:
  GameState.fate.pending.erase("magician");RunBuildMetrics.trigger("fate:magician");damage(enemy,.3);area(enemy.global_position,54,.15,"arcane",enemy)
 if FateCatalog.rank("chariot")==1 and float(GameState.fate.pending.get("chariot",0))>0 and ready("chariot"):
  GameState.fate.pending.erase("chariot");RunBuildMetrics.trigger("fate:chariot");start("chariot",2);damage(enemy,.32)
  if not enemy._dead:
   enemy.apply_slow(.20,1.5)
   if not enemy is BossBase:enemy.velocity+=owner.actor.global_position.direction_to(enemy.global_position)*90
 _consume_hermit(enemy)
 _grow(1)
 if FateCatalog.rank("moon")>0 and ready("moon") and not enemy._dead:
  start("moon",8);data.moon={"uid":_uid(enemy),"left":4.0,"distance":0.0,"reverse":FateCatalog.rank("moon")==2,"skill_armed":false,"cast_serial":int(data.get("cast_serial",0))}
  _walk_distance=0;_target=weakref(enemy);FateSpellFX.play(owner.actor,"moon",enemy.global_position,44)
func skill_hit(enemy:EnemyBase,source:Node)->void:
 if not FateCatalog.active() or not direct_source(source) or not is_instance_valid(enemy):return
 var data:=state();var serial:=int(source.get_meta("fate_serial",data.get("cast_serial",0)))
 var seen:Array=data.get("growth_casts",[])
 if serial not in seen:
  seen.append(serial)
  if seen.size()>64:seen.pop_front()
  data.growth_casts=seen;_grow(1)
 if bool(source.get_meta("fate_small",false)):_consume_hermit(enemy)
 var moon:Dictionary=data.get("moon",{})
 if not moon.is_empty() and bool(moon.get("reverse",false)) and bool(moon.get("skill_armed",false)) and bool(source.get_meta("fate_small",false)) and serial>int(moon.get("cast_serial",0)) and str(moon.uid)==_uid(enemy):
  data.erase("moon");_target=null;_clear_moon_visual();RunBuildMetrics.trigger("fate:moon");moon_resonance();damage(enemy,.70);area(enemy.global_position,54,.25,"moon",enemy)
func _consume_hermit(enemy:EnemyBase)->void:
 if FateCatalog.rank("hermit")==1 and float(GameState.fate.pending.get("hermit",0))>0:
  GameState.fate.pending.erase("hermit");RunBuildMetrics.trigger("fate:hermit");damage(enemy,.35);FateSpellFX.play(owner.actor,"ward",enemy.global_position,42)
func ally_hit(ally:Node2D)->void:
 if FateCatalog.rank("empress")==0 or not is_instance_valid(ally) or ally.global_position.distance_to(owner.actor.global_position)>144 or not ready("empress_ally"):return
 start("empress_ally",.25);_grow(2)
func _grow(points:int)->void:
 if FateCatalog.rank("empress")==0 or combat_room().is_empty():return
 var data:=state();data.growth=mini(14,int(data.get("growth",0))+points)
 var room:=_room_state()
 if int(data.growth)<14 or not ready("empress") or int(room.get("blooms",0))>=2:return
 var rank:=FateCatalog.rank("empress");var actor:=owner.actor
 if rank==1 and actor.hp>=actor.max_hp and actor.permanent_hp_loss()<=0:return
 RunBuildMetrics.trigger("fate:empress");data.growth=0;room.blooms=int(room.get("blooms",0))+1;start("empress",10)
 var base:=actor.stats.get_value(&"max_hp")
 if rank==1:actor.heal_player(base*.02)
 else:area(actor.global_position,108,.5,"flower")
 repair(base*(.01 if rank==1 else .015));FateSpellFX.play(actor,"flower",actor.global_position,70)
func enemy_died(enemy:EnemyBase,source:Node,kind:StringName)->void:
 if not FateCatalog.active():return
 if FateCatalog.rank("hermit")==2 and disconnected() and kind in [&"basic",&"skill"] and direct_source(source) and ready("hermit_kill"):
  start("hermit_kill",12);GameState.add_mp(GameState.MAX_MP*.04)
 var moon:Dictionary=state().get("moon",{})
 if not moon.is_empty() and str(moon.uid)==_uid(enemy):state().erase("moon");_target=null;_clear_moon_visual()
func _uid(enemy:EnemyBase)->String:return str(enemy.reward_uid) if not str(enemy.reward_uid).is_empty() else "transient:"+str(enemy.get_instance_id())
func _moon_target()->EnemyBase:
 var moon:Dictionary=state().get("moon",{})
 if moon.is_empty():return null
 if _target!=null:
  var current:Node=_target.get_ref()
  if is_instance_valid(current) and current is EnemyBase and not current._dead and _uid(current)==str(moon.uid):return current
 for enemy in owner.actor.room.tactics.enemies(owner.actor.room):
  if is_instance_valid(enemy) and not enemy._dead and _uid(enemy)==str(moon.uid):_target=weakref(enemy);return enemy
 return null
func _tick_moon(delta:float)->void:
 var moon:Dictionary=state().get("moon",{})
 if moon.is_empty():_clear_moon_visual();return
 var enemy:=_moon_target()
 if not is_instance_valid(enemy):state().erase("moon");_target=null;_clear_moon_visual();return
 if not is_instance_valid(_moon_visual):
  _moon_visual=Sprite2D.new();_moon_visual.texture=load("res://assets/fate_v11/icons/moon.png");_moon_visual.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;_moon_visual.scale=Vector2.ONE*.19;_moon_visual.position=Vector2(0,-40);_moon_visual.modulate.a=.75;_moon_visual.z_index=1;enemy.add_child(_moon_visual)
 moon.left=float(moon.left)-delta
 if not bool(moon.reverse):moon.distance=float(moon.distance)+_walk_distance
 var moving:=not bool(moon.reverse) and float(moon.distance)>=108
 if moving or float(moon.left)<=0:
  if moving:moon_resonance()
  state().erase("moon");_target=null;_clear_moon_visual();RunBuildMetrics.trigger("fate:moon");damage(enemy,.45 if moving else .2)
  if moving and not enemy._dead and not enemy is BossBase:enemy.apply_slow(.2,2)
  FateSpellFX.play(owner.actor,"moon",enemy.global_position,58)
func dash_end()->void:
 if not FateCatalog.active():_dash_points.clear();return
 world_action("dash")
 if FateCatalog.rank("chariot")==1:GameState.fate.pending.chariot=4.0
 elif FateCatalog.rank("chariot")==2 and not _dash_points.is_empty():
  var trails:Array=state().get("trails",[])
  trails.append({"points":_dash_points.duplicate(true),"left":2.0,"hits":[],"visual_ready":true});state().trails=trails
  for i in _dash_points.size():
   if i%3==0:FateSpellFX.play(owner.actor,"trail",Vector2(_dash_points[i][0],_dash_points[i][1]),34,2.0)
 _dash_points.clear()
func _tick_trails(delta:float)->void:
 var trails:Array=state().get("trails",[])
 for i in range(trails.size()-1,-1,-1):
  var trail:Dictionary=trails[i];trail.left=float(trail.left)-delta
  if float(trail.left)<=0:trails.remove_at(i);continue
  if not bool(trail.get("visual_ready",false)):
   trail.visual_ready=true
   for index in trail.points.size():
    if index%3==0:FateSpellFX.play(owner.actor,"trail",Vector2(trail.points[index][0],trail.points[index][1]),34,float(trail.left))
  for enemy in owner.actor.room.tactics.enemies(owner.actor.room):
   if not is_instance_valid(enemy) or enemy._dead or _uid(enemy) in trail.hits:continue
   for j in range(1,trail.points.size()):
    var a:=Vector2(trail.points[j-1][0],trail.points[j-1][1]);var b:=Vector2(trail.points[j][0],trail.points[j][1])
    var at:=Geometry2D.get_closest_point_to_segment(enemy.global_position,a,b)
    if enemy.global_position.distance_to(at)<=18 and owner.actor.room.body_clear(at,2) and owner.actor.room.sight(at,enemy.global_position):
     if not bool(trail.get("counted",false)):RunBuildMetrics.trigger("fate:chariot");trail.counted=true
     trail.hits.append(_uid(enemy));damage(enemy,.5);break
 state().trails=trails
func shield_broken()->void:
 var rank:=FateCatalog.rank("emperor")
 if rank<=0 or not ready("emperor"):return
 RunBuildMetrics.trigger("fate:emperor");start("emperor",7);var radius:=90.0 if rank==1 else 108.0
 area(owner.actor.global_position,radius,.45 if rank==1 else .75,"crown",null,rank==2)
func damage(enemy:EnemyBase,ratio:float)->void:
 if not is_instance_valid(enemy) or enemy._dead:return
 enemy.take_damage(owner.attack()*ratio,false,owner.actor.global_position,DamageContext._context(owner.actor,&"fate"),false)
func area(at:Vector2,radius:float,ratio:float,effect:String,except:EnemyBase=null,slow:bool=false)->void:
 FateSpellFX.play(owner.actor,effect,at,radius*2)
 var targets:=owner.actor.room.tactics.enemies(owner.actor.room).duplicate()
 for enemy in targets:
  if not is_instance_valid(enemy) or enemy==except or enemy._dead or enemy.global_position.distance_to(at)>radius or not owner.actor.room.sight(at,enemy.global_position):continue
  damage(enemy,ratio)
  if slow and not enemy._dead and not enemy is BossBase:enemy.apply_slow(.2,2)
func room_enter(room_id:String)->void:
 if not FateCatalog.active():return
 var data:=state()
 if str(data.get("room_id",room_id))!=room_id:
  data.erase("moon");data.erase("trails");data.erase("world_marks");GameState.fate.pending.erase("world_window");GameState.fate.pending.erase("ilyua_pursuit");data.alone=0.0;data.growth=0
  GameState.fate.still=0
 _target=null;motion_reset(false);data.room_id=room_id
 for trail:Dictionary in data.get("trails",[]):trail.visual_ready=false;_room_id=room_id
 var room:=combat_room()
 if room.is_empty() or str(room.id)!=room_id:return
 var local:=_room_state()
 # A legacy already-entered room must not gain its entry rewards again.
 if bool(local.get("entry",false)) or bool(room.delta.get("fate_entry",false)):return
 local.entry=true;room.delta.fate_entry=true
 var base:=owner.actor.stats.get_value(&"max_hp");var rank:=FateCatalog.rank("star")
 if rank>0:GameState.add_mp(GameState.MAX_MP*(.1 if rank==1 else .16))
 if bool(data.get("star_shield",false)):
  data.star_shield=false;owner.grant_player_shield(base*.04,6)
 if FateCatalog.star()=="lantern":owner.grant_player_shield(base*.08,10)
 var emperor:=FateCatalog.rank("emperor")
 if emperor>0:owner.grant_player_shield(base*(.06 if emperor==1 else .04),8)
 if FateCatalog.star()=="lantern" or emperor>0:FateSpellFX.play(owner.actor,"ward",owner.actor.global_position,58)
static func room_clear()->void:
 if not FateCatalog.active():return
 var self_runtime:=runtime();var room:=FateService.record()
 if self_runtime==null or room.is_empty() or not RoomGraph.is_combat(str(room.kind)) or not bool(room.get("cleared",false)):return
 var local:=_room_state()
 if bool(local.get("cleared",false)):return
 local.cleared=true
 var rank:=FateCatalog.rank("star")
 if rank>0 and not bool(room.delta.get("fate_star_repair",false)):
  room.delta.fate_star_repair=true
  var actual:=repair(self_runtime.owner.actor.stats.get_value(&"max_hp")*(.02 if rank==1 else .03))
  if actual>0:RunBuildMetrics.trigger("fate:star")
  if rank==1 and actual>=1:state().star_shield=true
 if FateCatalog.rank("hermit")==1 and not FateCatalog.allies_near(self_runtime.owner.actor):
  var main:Node=GameState.runtime_node.main
  var pool:Array[String]=[]
  var visible:Array[String]=main.graph.visible_rooms()
  for id:String in main.graph.rooms:
   if not bool(main.graph.rooms[id].visited) and id not in visible:pool.append(id)
  if not pool.is_empty():
   var rng:=RandomNumberGenerator.new();rng.seed=int(room.seed)^0x631aed
   var selected:=pool[rng.randi_range(0,pool.size()-1)];main.graph.rooms[selected].delta.fate_revealed=true
   Effects.text(self_runtime.owner.actor.get_parent(),self_runtime.owner.actor.global_position-Vector2(0,62),"孤灯照见远路",Color("e6d496"),14)

static func hurt_after(source:Node,before:float,after:float,direct_hit:=true)->void:
 var current:=runtime()
 if not direct_hit or not FateCatalog.active() or current==null or combat_room().is_empty() or after<=0 or after>=before or FateCatalog.rank("fool")==0 or not current.ready("fool"):return
 var hostile:bool=source is EnemyBase or source is Projectile and not source.is_friendly or source is AffixHazard and source.mode not in [&"trail",&"grave"]
 if not hostile:return
 current.start("fool",12)
 GameState.fate.pending["fool_start" if FateCatalog.rank("fool")==1 else "fool_risk"]=3.0 if FateCatalog.rank("fool")==1 else 4.0
 RunBuildMetrics.trigger("fate:fool")

func world_action(kind:String)->void:
 if not FateCatalog.active() or FateCatalog.rank("world")==0 or combat_room().is_empty() or not ready("world"):return
 var data:=state()
 if not data.has("room_id"):data.room_id=str(combat_room().get("id",""))
 if float(GameState.fate.pending.get("world_window",0))<=0:
  data.world_marks=[];GameState.fate.pending.world_window=10.0
 var marks:Array=data.get("world_marks",[])
 if kind not in marks:marks.append(kind)
 data.world_marks=marks
 if marks.size()<3:return
 data.erase("world_marks");GameState.fate.pending.erase("world_window")
 var reversed:=FateCatalog.rank("world")==2
 start("world",10 if reversed else 12);RunBuildMetrics.trigger("fate:world")
 if reversed:area(owner.actor.global_position,108,.70,"arcane")
 else:
  owner.grant_player_shield(owner.actor.stats.get_value(&"max_hp")*.06,5);GameState.add_mp(GameState.MAX_MP*.05)
  FateSpellFX.play(owner.actor,"ward",owner.actor.global_position,64)

func hero_cast(epoch:int)->void:
 if not is_instance_valid(owner) or not is_instance_valid(owner.actor) or GameState.run_epoch!=epoch or not FateCatalog.active() or combat_room().is_empty():return
 if FateCatalog.resonance("priestess") and ready("hero_priestess") and is_instance_valid(owner.actor.holy_runtime):
  owner.actor.holy_runtime.add_prayer(8);start("hero_priestess",4)
 elif FateCatalog.resonance("magician") and ready("hero_magician"):
  for unit in owner.actor.room.tactics.allies(owner.actor.room):
   if unit is SummonedAlly and unit.player==owner.actor and unit.hp>0 and not unit.is_queued_for_deletion():unit.fate_haste_left=4.0
  start("hero_magician",8)

func moon_resonance()->void:
 if FateCatalog.resonance("moon") and ready("hero_moon"):
  GameState.fate.pending.ilyua_pursuit=6.0;start("hero_moon",8)

func pursuit_arrow(enemy:EnemyBase)->void:
 if not is_instance_valid(enemy) or enemy._dead:return
 var arrow:=RoomProjectile.new();arrow.room=owner.actor.room;arrow.is_friendly=true;arrow.damage_owner=&"player";arrow.mechanic_tag=&"fate"
 arrow.homing_origin=owner.actor.global_position;arrow.owner_aim=owner.actor.global_position.direction_to(enemy.global_position)
 arrow.homing_turn=PI*2;arrow.homing_range=360;arrow.range_limit=432;arrow.trail=true;arrow.trail_color=Color("bdddcf")
 owner.actor.get_parent().add_child(arrow)
 arrow.setup(owner.actor.global_position,owner.actor.global_position.direction_to(enemy.global_position),owner.attack()*.35,420,owner.actor.room,owner.actor,Color("bdddcf"))
