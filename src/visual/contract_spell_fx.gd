class_name ContractSpellFX
extends Sprite2D
var age:=0.0
var lifetime:=.52
static func spawn(parent:Node,at:Vector2,row:int,width:float,duration:float)->ContractSpellFX:
	var fx:=ContractSpellFX.new()
	fx.texture=load("res://assets/next_revision/fx/amethyst_guardian.png") if ResourceLoader.exists("res://assets/next_revision/fx/amethyst_guardian.png") else load("res://assets/fx/contract_guardian.png")
	fx.hframes=8;fx.vframes=2;fx.frame=row*8
	fx.set_meta("row",row);fx.lifetime=duration;fx.position=at
	fx.scale=Vector2.ONE*width/(fx.texture.get_width()/8.0)
	if fx.texture.resource_path=="res://assets/next_revision/fx/amethyst_guardian.png":
		# Both rows share a floor target; source anchors stay fixed across all frames.
		fx.position.y+=14.0;fx.offset.y=64.0-(96.0 if row==0 else 72.0)
	elif row==0:fx.offset.y=-fx.texture.get_height()/2.0*.32
	fx.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(fx);return fx
func _physics_process(dt:float)->void:
	age+=dt;frame=int(get_meta("row"))*8+clampi(int(age/lifetime*8),0,7)
	if age>=lifetime:queue_free()
