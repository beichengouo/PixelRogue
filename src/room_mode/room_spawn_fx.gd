class_name RoomSpawnFX
extends Node2D
## One bounded sprite animation per pending spawn, resumed from remaining warning time.
var duration:=0.75
var age:=0.0
var sprite:Sprite2D
func _ready()->void:
	sprite=Sprite2D.new();sprite.texture=load("res://assets/room_mode/fx/enemy_spawn.png")
	sprite.hframes=4;sprite.vframes=2;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position=Vector2(0,-28);sprite.scale=Vector2.ONE*0.85;add_child(sprite)
	z_index=2
func _process(dt:float)->void:
	age+=dt
	var phase:=age/maxf(0.1,duration)
	sprite.frame=mini(4,int(phase*5)) if phase<1 else mini(7,5+int((age-duration)/0.25*3))
	if age>=duration+0.25:queue_free()
static func spawn(parent:Node,at:Vector2,warning:=0.75,remaining:=-1.0)->RoomSpawnFX:
	var fx:=RoomSpawnFX.new();fx.position=at;fx.duration=warning
	fx.age=0 if remaining<0 else maxf(0,warning-remaining)
	parent.add_child(fx);return fx
