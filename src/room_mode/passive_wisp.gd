class_name PassiveWisp
extends RoomAlly
const EXPLOSION_RADIUS:=108.0
var remaining:=20.0
var origin_room_id:=""
var age:=0.0
var dying:=false
var wander_goal:=Vector2.ZERO
var wander_ready:=false
var wander_seconds:=0.0
var wander_pause:=0.0
var wander_rng:=RandomNumberGenerator.new()
var wander_seed:=0
func is_flying()->bool:return true
func body_radius()->float:return 8.0
func _ready()->void:
 enemy_kind=&"flyer";display_name="迷途浮灵";super._ready()
 if origin_room_id.is_empty():origin_room_id=str(room.record.get("id",""))
 add_to_group("passive_wisps");hp=1;max_hp=1;attack=0;move_speed=95
 if wander_seed==0:wander_seed=int(GameState.passive_rng.randi())+1
 wander_rng.seed=wander_seed
func _build_visual()->void:
 super._build_visual()
 var path:="res://assets/next_revision/creatures/lost_wisp.png"
 if ResourceLoader.exists(path):
  var sheet:Texture2D=load(path);var cell:=Vector2(sheet.get_width()/8.0,sheet.get_height()/3.0);var frames:=SpriteFrames.new()
  for row in 3:
   var action:StringName=[&"spawn",&"walk",&"death"][row];frames.add_animation(action);frames.set_animation_speed(action,10);frames.set_animation_loop(action,row==1)
   for col in 8:
    var image:=AtlasTexture.new();image.atlas=sheet;image.filter_clip=true;image.region=Rect2(Vector2(col,row)*cell,cell);frames.add_frame(action,image)
  _sprite.sprite_frames=frames;_sprite.scale=Vector2.ONE*28/cell.y;_sprite.position=Vector2(0,-13);_sprite.play(&"spawn")
 else:_sprite.modulate=Color("cb99ff");_sprite.scale*=.6
func _refresh_bonus()->void:pass
func _physics_process(dt:float)->void:
 if dying:return
 if not is_instance_valid(player) or player.hp<=0 or (not GameState.run_active and not CampSession.active):queue_free();return
 remaining-=dt;age+=dt
 if remaining<=0:_die();return
 if age<.8:return
 if not is_instance_valid(room) or room.is_queued_for_deletion():queue_free();return
 wander_seconds-=dt
 if not wander_ready or wander_seconds<=0 or global_position.distance_to(wander_goal)<12:_choose_wander_goal()
 wander_pause=maxf(0,wander_pause-dt)
 velocity=Vector2.ZERO if wander_pause>0 else room.path_direction(global_position,wander_goal,body_radius(),true)*move_speed
 move_and_slide()
 if absf(velocity.x)>1:_sprite.flip_h=velocity.x<0
 if _sprite.sprite_frames.has_animation(&"walk") and _sprite.animation!=&"walk":_sprite.play(&"walk")
func _choose_wander_goal()->void:
 var bounds:=room.room_rect.grow(-24)
 wander_goal=room.nearest_clear(global_position,body_radius(),true)
 for attempt in 48:
  var candidate:=Vector2(wander_rng.randf_range(bounds.position.x,bounds.end.x),wander_rng.randf_range(bounds.position.y,bounds.end.y))
  if candidate.distance_to(global_position)<48 or not room.body_clear(candidate,body_radius(),true):continue
  if room.path_direction(global_position,candidate,body_radius(),true).is_zero_approx():continue
  wander_goal=candidate;break
 wander_ready=true;wander_seconds=wander_rng.randf_range(4,8);wander_pause=wander_rng.randf_range(.2,.65)
func wander_snapshot()->Dictionary:
 return {"seed":str(wander_seed),"rng":str(wander_rng.state),"goal":[wander_goal.x,wander_goal.y],"ready":wander_ready,"seconds":wander_seconds,"pause":wander_pause}
func restore_wander(data:Dictionary)->void:
 if data.is_empty():return
 wander_seed=int(data.get("seed",wander_seed));wander_rng.seed=wander_seed
 wander_rng.state=int(data.get("rng",wander_rng.state))
 var saved:Array=data.get("goal",[global_position.x,global_position.y])
 wander_goal=Vector2(saved[0],saved[1]);wander_ready=bool(data.get("ready",false))
 wander_seconds=float(data.get("seconds",0));wander_pause=float(data.get("pause",0))
func _die()->void:
 if dying or is_queued_for_deletion():return
 dying=true;hp=0;collision_layer=0
 remove_from_group("allies");remove_from_group("passive_wisps")
 _explode()
 if _sprite.sprite_frames.has_animation(&"death"):
  _sprite.play(&"death");_sprite.animation_finished.connect(queue_free,CONNECT_ONE_SHOT)
 else:queue_free()

func _explode()->void:
 var owner:=player as Player
 if (not GameState.run_active and not CampSession.active) or not is_instance_valid(owner) or owner.is_queued_for_deletion() or owner.hp<=0 or owner.stats==null:return
 if not is_instance_valid(room) or room.is_queued_for_deletion() or origin_room_id!=str(room.record.get("id","")):return
 var damage:=owner.stats.get_value(&"attack")*2.0
 ContractSpellFX.spawn(_fx(),global_position,1,EXPLOSION_RADIUS*2.0,.52)
 for enemy in get_tree().get_nodes_in_group("enemies"):
  if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy._dead or enemy.get("room")!=room:continue
  if global_position.distance_to(enemy.global_position)>EXPLOSION_RADIUS or not room.sight(global_position,enemy.global_position):continue
  enemy.take_damage(damage,false,global_position,self)

