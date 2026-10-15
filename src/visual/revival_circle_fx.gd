class_name RevivalCircleFX
extends Sprite2D
# All frames keep one painted floor anchor; never recenter individual frames.
const FLOOR_ANCHOR_Y:=104.0
const WORLD_FOOT_Y:=14.0
var age:=0.0
var cast_epoch:=0
var room_id:=""
var room_ref:WeakRef
static func spawn(parent:Node,at:Vector2)->void:
 var path:="res://assets/next_revision/fx/revival_circle.png"
 if not ResourceLoader.exists(path):Effects.cast_ring(parent,at,Color("af70ff"),36,.6);return
 var floor_parent:Node=parent
 if is_instance_valid(GameState.player) and GameState.player is RoomPlayer and is_instance_valid(GameState.player.room):floor_parent=GameState.player.room
 var node:=RevivalCircleFX.new();node.texture=load(path);node.hframes=8;node.position=at;node.z_index=0;node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;node.scale=Vector2.ONE*72/(node.texture.get_width()/8.0);floor_parent.add_child(node);node.global_position=at+Vector2(0,WORLD_FOOT_Y-(FLOOR_ANCHOR_Y-node.texture.get_height()*.5)*node.scale.y)
func _ready()->void:
 cast_epoch=GameState.run_epoch;add_to_group("revival_circles")
 if get_parent() is RoomLevel:room_ref=weakref(get_parent());room_id=str(get_parent().record.get("id",""))
 EventBus.run_started.connect(func(_id:int)->void:queue_free(),CONNECT_ONE_SHOT)
 EventBus.player_died.connect(queue_free,CONNECT_ONE_SHOT)
func _physics_process(dt:float)->void:
 var room:Node=room_ref.get_ref() if room_ref!=null else null
 if cast_epoch!=GameState.run_epoch or (not GameState.run_active and not CampSession.active) or (room_ref!=null and (not is_instance_valid(room) or str(room.record.get("id",""))!=room_id)):queue_free();return
 age+=dt;frame=clampi(int(age/.6*8),0,7)
 if age>=.6:queue_free()
