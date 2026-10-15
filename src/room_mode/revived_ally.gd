class_name RevivedAlly
extends RoomAlly
var appearance_kind:StringName=&""
var appearance_body:=Vector2.ZERO
func visual_art_kind()->StringName:return appearance_kind if not str(appearance_kind).is_empty() else enemy_kind
func visual_body()->Vector2:return appearance_body if appearance_body.y>0 else navigation_body()
var base_attack:=1.0
var base_hp:=1.0
var base_speed:=90.0
var attack_scale:=1.0
var remaining:=30.0
var epoch:=0
var rush_left:=0.0
var rush_hits:Dictionary={}
func _ready()->void:
 super._ready();add_to_group("revived_allies");_refresh_bonus();hp=max_hp;_cooldown=.4
 _unit_spawn_left=.55;_sprite.play(&"spawn")
func _refresh_bonus()->void:
 var ratio:=clampf(hp/maxf(1,max_hp),0,1)
 var bonus:=GameState.ally_bonus()
 max_hp=base_hp*float(bonus.hp);hp=max_hp*ratio
 attack=base_attack*float(bonus.attack);move_speed=base_speed*float(bonus.speed)
func _physics_process(dt:float)->void:
 if epoch!=GameState.run_epoch or (not GameState.run_active and not CampSession.active) or not is_instance_valid(player) or player.hp<=0:queue_free();return
 remaining-=dt
 if remaining<=0:queue_free();return
 if rush_left>0:
  rush_left=maxf(0,rush_left-dt);_cooldown=maxf(0,_cooldown-dt)
  var before:=global_position
  velocity=attack_direction*move_speed*3;move_and_slide()
  _rush_contact(before,global_position);return
 super._physics_process(dt)
func _die()->void:
 if is_queued_for_deletion():return
 hp=0;Effects.death_burst(_fx(),global_position,Color("bd94fc"),8);queue_free()
func passive_snapshot()->Dictionary:
 return {"uid":uid,"name":display_name,"kind":str(enemy_kind),"visual_kind":str(visual_art_kind()),"visual_body":[visual_body().x,visual_body().y],"attack":base_attack,"max_hp":base_hp,"speed":base_speed,"attack_scale":attack_scale,"hp_ratio":hp/maxf(1,max_hp),"remaining":remaining,"cooldown":_cooldown,"at":[global_position.x,global_position.y]}

func attack_is_melee()->bool:return not (EnemyCombatPolicy.ranged_affix_allowed(enemy_kind) or enemy_kind==&"treant")
func attack_windup()->float:return .65 if enemy_kind in [&"charger",&"bomber"] else .45
func attack_duration()->float:return attack_windup()+.15
func attack_cooldown()->float:return (2.4 if not attack_is_melee() else 1.6)/maxf(.2,attack_scale)
func _release_attack(melee:bool)->void:
 if enemy_kind==&"bomber":
  Effects.cast_ring(_fx(),global_position,Color("bb86f0"),100,.35)
  for enemy in get_tree().get_nodes_in_group("enemies"):
   if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy._dead and global_position.distance_to(enemy.global_position)<100 and room.sight(global_position,enemy.global_position):enemy.take_damage(attack*1.3,false,global_position,self)
 elif enemy_kind==&"charger":rush_left=.45;rush_hits.clear()
 elif not attack_is_melee():
  for angle in ([-.22,0.0,.22] if enemy_kind==&"treant" else [0.0]):
   var dir:=attack_direction.rotated(angle)
   var ball:=RoomProjectile.new();ball.room=room;ball.damage_owner=&"revived";ball.is_friendly=true;ball.art_scale=.7
   if enemy_kind in [&"lantern_toad",&"dusk_acolyte"]:ball.hostile_fx=str(enemy_kind)
   _fx().add_child(ball);ball.setup(global_position+dir*18,dir,attack,240,room,null,Color("b986f1"))
 else:super._release_attack(melee)


func _rush_contact(from:Vector2,to:Vector2)->void:
 for enemy in get_tree().get_nodes_in_group("enemies"):
  if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy._dead or rush_hits.has(enemy.get_instance_id()):continue
  var nearest:=Geometry2D.get_closest_point_to_segment(enemy.global_position,from,to)
  if nearest.distance_to(enemy.global_position)>24 or not room.sight(nearest,enemy.global_position):continue
  rush_hits[enemy.get_instance_id()]=true
  enemy.take_damage(attack,false,nearest,self)

