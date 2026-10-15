class_name RoomSpellSpriteFX
extends Sprite2D
var age:=0.0
var lifetime:=.45
var row:=0
var looping:=false
var large_frames:Array[Texture2D]=[]
var shield_owner:WeakRef
static func spawn(parent:Node,at:Vector2,id:StringName,width:float,duration:float,loop:=false)->RoomSpellSpriteFX:
 if not LargeSkillArt.frames(str(id)).is_empty():
  var node:=RoomSpellSpriteFX.new();node.large_frames=LargeSkillArt.frames(str(id));node.texture=node.large_frames[0];node.lifetime=maxf(duration,.8) if not loop else duration;node.looping=loop;node.position=at;node.scale=Vector2.ONE*width/node.texture.get_width();node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;parent.add_child(node);return node
 var path:="res://assets/next_revision/fx/sylphiette_spells.png"
 if not ResourceLoader.exists(path):return null
 var index:=Skills.ORDER.find(id)
 if index<0:return null
 var node:=RoomSpellSpriteFX.new();node.texture=load(path);node.hframes=8;node.vframes=8;node.row=index;node.frame=index*8;node.lifetime=duration;node.looping=loop
 node.position=at;node.scale=Vector2.ONE*width/(node.texture.get_width()/8.0);node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 parent.add_child(node);return node
func _physics_process(dt:float)->void:
 age+=dt
 if shield_owner!=null:
  var actor:Node=shield_owner.get_ref()
  if not is_instance_valid(actor) or actor.hp<=0 or actor.shield_hp<=0:queue_free();return
 if age>=lifetime:queue_free();return
 if not large_frames.is_empty():
  texture=large_frames[int(age*4)%4 if looping and not ComicMotion.reduced() else 1 if looping else mini(3,int(age/lifetime*4))];return
 var col:=clampi(int(age/lifetime*8),0,7)
 if looping:col=3 if ComicMotion.reduced() else 3+int(age*7)%4
 frame=row*8+col
