class_name PassiveRuntime
extends Node2D
var actor:RoomPlayer
var wisp_timer:=8.0
var room_id:=""
var serial:=0
var _circle_texture:Texture2D
const CIRCLE_SIZE:=Vector2(48,24)
func _ready()->void:
 # Draw on the ground before the character and its sprite children.
 show_behind_parent=true
static func share_damage(player_node:Node,amount:float)->float:
 if GameState.passive_id!=&"xixifu_shared_fate" or not is_instance_valid(player_node):return amount
 var allies:Array=player_node.get_tree().get_nodes_in_group("allies").filter(func(u)->bool:return is_instance_valid(u) and not u.is_queued_for_deletion() and u.hp>0 and not u is PassiveWisp and u.player==player_node and u.get("room")==player_node.get("room"))
 allies.sort_custom(func(a,b)->bool:return player_node.global_position.distance_squared_to(a.global_position)<player_node.global_position.distance_squared_to(b.global_position))
 for unit in allies:
  var absorbed:=minf(unit.hp,amount)
  unit.hp-=absorbed;amount-=absorbed;unit.queue_redraw()
  if unit.hp<=0:unit._die()
  if amount<=0:return 0.0
 return amount
static func report_kill(enemy:Node,source:Node)->void:
 if GameState.passive_id!=&"xixifu_revival" or enemy is BossBase or not DamageContext.player_owned(source):return
 if not is_instance_valid(GameState.player) or not GameState.player is RoomPlayer:return
 var runtime:PassiveRuntime=GameState.player.passive_runtime
 if not is_instance_valid(runtime):return
 var count:=runtime.get_tree().get_nodes_in_group("revived_allies").filter(func(u)->bool:return is_instance_valid(u) and not u.is_queued_for_deletion() and u.hp>0).size()
 if count>=3 or GameState.passive_rng.randf()>=.2:return
 var data:={"name":str(enemy.display_name),"kind":str(enemy.kind),"visual_kind":str(enemy.visual_art_kind()) if enemy.has_method("visual_art_kind") else str(enemy.kind),"visual_body":[enemy.body_size.x,enemy.body_size.y],"attack":enemy.base_damage*enemy._damage_scale*.5,"hp":enemy.max_hp*.5,"speed":enemy.move_speed,"attack_scale":enemy._attack_scale,"at":enemy.global_position}
 runtime._revive.call_deferred(data,GameState.run_epoch,str(runtime.actor.room.record.get("id","")))
func _revive(data:Dictionary,epoch:int,expected_room:String)->void:
 if not is_instance_valid(actor) or actor.hp<=0 or epoch!=GameState.run_epoch or (not GameState.run_active and not CampSession.active) or str(actor.room.record.get("id",""))!=expected_room:return
 var count:=get_tree().get_nodes_in_group("revived_allies").filter(func(u)->bool:return is_instance_valid(u) and not u.is_queued_for_deletion() and u.hp>0).size()
 if count>=3:return
 serial+=1
 var unit:=RevivedAlly.new();unit.room=actor.room;unit.player=actor;unit.level=actor.level;unit.fx_root=actor.get_parent();unit.uid="revived_%d_%d"%[epoch,serial]
 unit.enemy_kind=StringName(data.kind);unit.display_name="回响·"+str(data.get("name","同行者"));unit.base_attack=float(data.attack);unit.base_hp=float(data.hp);unit.base_speed=float(data.speed);unit.attack_scale=float(data.attack_scale);unit.epoch=epoch
 unit.appearance_kind=StringName(data.get("visual_kind",unit.enemy_kind));var appearance:Array=data.get("visual_body",[26,36]);unit.appearance_body=Vector2(appearance[0],appearance[1])
 unit.position=actor.room.nearest_clear(data.at,12);actor.get_parent().add_child(unit)
 RevivalCircleFX.spawn(actor.get_parent(),unit.global_position)
func _physics_process(dt:float)->void:
 if not is_instance_valid(actor) or actor.hp<=0 or (not GameState.run_active and not CampSession.active):return
 var current:=str(actor.room.record.get("id",""))
 if current!=room_id:
  room_id=current;wisp_timer=8.0
  for unit in get_tree().get_nodes_in_group("passive_wisps"):
   if is_instance_valid(unit):unit.queue_free()
 if GameState.passive_id==&"xixifu_wisps":
  var hostile:=false
  for enemy in get_tree().get_nodes_in_group("enemies"):
   if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy._dead:hostile=true;break
  if hostile:
   wisp_timer-=dt
   if wisp_timer<=0:
    wisp_timer+=8.0
    if get_tree().get_nodes_in_group("passive_wisps").size()<3:_spawn_wisp()
 queue_redraw()
func _spawn_wisp()->void:
 serial+=1
 var unit:=PassiveWisp.new();unit.room=actor.room;unit.player=actor;unit.level=actor.level;unit.fx_root=actor.get_parent();unit.uid="wisp_%d"%serial
 unit.position=actor.room.nearest_clear(actor.global_position+Vector2.RIGHT.rotated(GameState.passive_rng.randf()*TAU)*54,8,true)
 actor.get_parent().add_child(unit)
func _draw()->void:
 if GameState.passive_id!=&"xixifu_shared_fate" or not is_instance_valid(actor):return
 var visible_circle:=false
 for unit in get_tree().get_nodes_in_group("allies"):
  if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp>0 and not unit is PassiveWisp and unit.player==actor and unit.get("room")==actor.room:visible_circle=true;break
 if not visible_circle:return
 var path:="res://assets/next_revision/fx/revival_circle.png"
 if ResourceLoader.exists(path):
  # Draw commands retain only the RID; keep the resource alive beyond this callback.
  if _circle_texture==null:_circle_texture=load(path)
  var width:=_circle_texture.get_width()/8.0
  # Frame 2's floor ring is centered at y=72; exclude the rising revival flare.
  var top:=RevivalCircleFX.WORLD_FOOT_Y-CIRCLE_SIZE.y*.5
  draw_texture_rect_region(_circle_texture,Rect2(Vector2(-CIRCLE_SIZE.x*.5,top),CIRCLE_SIZE),Rect2(width*2,52,width,40),Color(1,1,1,.6));return
 draw_set_transform(Vector2(0,RevivalCircleFX.WORLD_FOOT_Y),0,Vector2(1,.45))
 draw_arc(Vector2.ZERO,22,0,TAU,48,Color("b183e0"),1.2)
 for shift in [0.0,PI]:
  var points:=PackedVector2Array()
  for i in 4:points.append(Vector2.UP.rotated(shift+(i%3)*TAU/3)*20)
  draw_polyline(points,Color(.67,.34,1,.72),1.2)
static func snapshot_units(actor_node:RoomPlayer)->Dictionary:
 var entries:Array=[]
 for unit in actor_node.get_tree().get_nodes_in_group("revived_allies"):
  if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp>0:entries.append(unit.passive_snapshot())
 var wisps:Array=[]
 for unit in actor_node.get_tree().get_nodes_in_group("passive_wisps"):
  if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp>0 and unit.origin_room_id==str(actor_node.room.record.get("id","")):wisps.append({"at":[unit.global_position.x,unit.global_position.y],"remaining":unit.remaining,"age":unit.age,"wander":unit.wander_snapshot()})
 return {"revived":entries,"wisps":wisps,"wisp_timer":actor_node.passive_runtime.wisp_timer,"serial":actor_node.passive_runtime.serial}
static func restore_units(actor_node:RoomPlayer,data:Dictionary)->void:
 for unit in actor_node.get_tree().get_nodes_in_group("revived_allies")+actor_node.get_tree().get_nodes_in_group("passive_wisps"):
  if is_instance_valid(unit):unit.get_parent().remove_child(unit);unit.queue_free()
 actor_node.passive_runtime.wisp_timer=float(data.get("wisp_timer",8));actor_node.passive_runtime.serial=int(data.get("serial",0));actor_node.passive_runtime.room_id=str(actor_node.room.record.get("id",""))
 for entry:Dictionary in data.get("revived",[]):
  var unit:=RevivedAlly.new();unit.player=actor_node;unit.room=actor_node.room;unit.level=actor_node.level;unit.fx_root=actor_node.get_parent();unit.enemy_kind=StringName(entry.kind);unit.display_name=str(entry.get("name","回响同行者"))
  unit.base_attack=float(entry.attack);unit.base_hp=float(entry.max_hp);unit.base_speed=float(entry.speed);unit.attack_scale=float(entry.attack_scale);unit.remaining=float(entry.remaining);unit.epoch=GameState.run_epoch;unit.uid=str(entry.uid)
  unit.appearance_kind=StringName(entry.get("visual_kind",unit.enemy_kind));var appearance:Array=entry.get("visual_body",[26,36]);unit.appearance_body=Vector2(appearance[0],appearance[1])
  unit.position=Vector2(entry.at[0],entry.at[1]);actor_node.get_parent().add_child(unit);unit.hp=unit.max_hp*float(entry.hp_ratio);unit._cooldown=float(entry.get("cooldown",.4))
 for entry:Dictionary in data.get("wisps",[]):
  var unit:=PassiveWisp.new();unit.player=actor_node;unit.room=actor_node.room;unit.level=actor_node.level;unit.fx_root=actor_node.get_parent();unit.remaining=float(entry.remaining);unit.age=float(entry.get("age",0));unit.position=Vector2(entry.at[0],entry.at[1])
  unit.wander_seed=int(entry.get("wander",{}).get("seed",0));actor_node.get_parent().add_child(unit);unit.restore_wander(entry.get("wander",{}))

static func on_room_exit(actor_node:RoomPlayer)->void:
 for group in ["revival_circles","spell_fields"]:
  for effect in actor_node.get_tree().get_nodes_in_group(group):
   if is_instance_valid(effect):effect.remove_from_group(group);effect.queue_free()
 for unit in actor_node.get_tree().get_nodes_in_group("passive_wisps"):
  if not is_instance_valid(unit):continue
  unit.remove_from_group("passive_wisps");unit.remove_from_group("allies");unit.queue_free()
 if is_instance_valid(actor_node.passive_runtime):actor_node.passive_runtime.wisp_timer=8.0

