class_name FateSpellFX
extends Node2D
## Painted frames, bounded transient population; no extra lights or collisions.
const ROOT:="res://assets/fate_v11/fx/"
static var _textures:Dictionary={}
static var active_count:=0
var frames:Array[Texture2D]=[]
var sprite:Sprite2D
var elapsed:=0.0
var duration:=.5
var effect:=""
var epoch:=0
var room_id:=""
var owner_ref:WeakRef
static func play(actor:Node2D,id:String,at:Vector2,width:float,lifetime:=.5)->void:
 if not is_instance_valid(actor) or not actor.is_inside_tree() or active_count>=16:return
 if ComicMotion.reduced() and active_count>=4:return
 var fx:=FateSpellFX.new();fx.effect=id;fx.position=at;fx.owner_ref=weakref(actor);fx.set_meta("cosmetic",true)
 fx.duration=lifetime;fx.set_meta("width",width);actor.get_parent().add_child(fx);fx.global_position=at
func _ready()->void:
 active_count+=1;epoch=GameState.run_epoch;z_index=-1
 var actor:Node=owner_ref.get_ref()
 if actor is RoomPlayer and is_instance_valid(actor.room):room_id=str(actor.room.record.get("id",""))
 if not _textures.has(effect):
  var sheet:=load(ROOT+effect+".png") as Texture2D
  var values:Array[Texture2D]=[]
  if sheet!=null:
   for i in 4:
    var frame:=AtlasTexture.new();frame.atlas=sheet;frame.region=Rect2(i*128,0,128,128);frame.filter_clip=true;values.append(frame)
  _textures[effect]=values
 frames.assign(_textures[effect])
 if frames.is_empty():queue_free();return
 sprite=Sprite2D.new();sprite.texture=frames[0];sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(sprite)
 sprite.scale=Vector2.ONE*float(get_meta("width",64))/128.0
 sprite.modulate.a=.55 if ComicMotion.reduced() else .75
 duration=minf(duration,.22) if ComicMotion.reduced() else duration
func _process(dt:float)->void:
 var actor:Node=owner_ref.get_ref()
 if not is_instance_valid(actor) or actor.hp<=0 or GameState.run_epoch!=epoch or actor is RoomPlayer and (not is_instance_valid(actor.room) or str(actor.room.record.get("id",""))!=room_id):queue_free();return
 elapsed+=dt
 if elapsed>=duration:queue_free();return
 if sprite!=null and not frames.is_empty():
  sprite.texture=frames[mini(3,int(elapsed/duration*4))];sprite.modulate.a=(.55 if ComicMotion.reduced() else .75)*(1.0-elapsed/duration*.5)
func _exit_tree()->void:active_count=maxi(0,active_count-1)
