class_name ContractSpellFX
extends Sprite2D
var age:=0.0
var lifetime:=.52
var detail:ShaderMaterial
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
	if width>=96:
		var pixels:=SizedSkillArt.screen_extent(parent,Vector2.ONE*width) if parent is CanvasItem else width*3
		var art:=SizedSkillArt.texture("contract_call" if row==0 else "contract_burst",pixels)
		if art!=null:
			fx.texture=art;fx.hframes=1;fx.vframes=1;fx.frame=0;fx.scale=Vector2.ONE*width/art.get_width()
			fx.offset.y=art.get_height()*(.5-(.75 if row==0 else .5625));fx.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			fx.detail=SizedSkillArt.material();fx.material=fx.detail
	parent.add_child(fx);return fx
func _physics_process(dt:float)->void:
	age+=dt
	if detail!=null:
		detail.set_shader_parameter("phase",age/maxf(.01,lifetime));detail.set_shader_parameter("still",ComicMotion.reduced());modulate.a=1-smoothstep(.72,1,age/maxf(.01,lifetime))
	else:frame=int(get_meta("row"))*8+clampi(int(age/lifetime*8),0,7)
	if age>=lifetime:queue_free()
