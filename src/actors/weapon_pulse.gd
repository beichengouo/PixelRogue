class_name WeaponPulse
extends Node2D
var sprite:Sprite2D
var textures:Array[Texture2D]=[]
var duration:=0.38
var age:=0.0
static func spawn(parent:Node,at:Vector2,id:String,width:=64.0,rotation_value:=0.0,cell:=128)->WeaponPulse:
	if not is_instance_valid(parent):return null
	var fx:=WeaponPulse.new();fx.textures=WeaponArt.frames(id,cell)
	if fx.textures.is_empty():fx.free();return null
	fx.sprite=Sprite2D.new();fx.sprite.texture=fx.textures[0];fx.sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	fx.sprite.scale=Vector2.ONE*width/cell;fx.add_child(fx.sprite);parent.add_child(fx);fx.global_position=at;fx.rotation=rotation_value;fx.z_index=7
	fx.modulate.a=float(SaveService.data.get("spell_fx_strength",1.0))*0.85
	return fx
func _process(dt:float)->void:
	age+=dt
	if age>=duration:queue_free();return
	sprite.texture=textures[mini(3,int(age/duration*4))]
	if age>duration*0.75:modulate.a*=maxf(0.0,1.0-dt*12.0)
