class_name CombatContactFX
extends Node2D
## Small, pooled-texture contact artwork; no lights, RNG or gameplay callbacks.
static var _banks:Dictionary={}
static var active_count:=0
var frames:Array[Texture2D]=[]
var sprite:Sprite2D
var age:=0.0
var life:=.20
static func bank(style:String)->Array[Texture2D]:
	if _banks.has(style):return _banks[style]
	var result:Array[Texture2D]=[]
	if style=="arrow":result.assign(IlyuaFX.frames("spring_hit"))
	elif style=="contract":
		var texture:=load("res://assets/next_revision/fx/amethyst_guardian.png") as Texture2D
		var cell:=texture.get_width()/8.0
		for index in 4:
			var tile:=AtlasTexture.new();tile.atlas=texture;tile.region=Rect2(index*2*cell,cell,cell,cell);tile.filter_clip=true;result.append(tile)
	else:
		var texture:=load(HolyFX.ART_ROOT+("cloud" if style=="shield" else "feather")+".png") as Texture2D
		var cell:=texture.get_height()
		for index in 4:
			var tile:=AtlasTexture.new();tile.atlas=texture;tile.region=Rect2(index*cell,0,cell,cell);tile.filter_clip=true;result.append(tile)
	_banks[style]=result
	return result
static func spawn(parent:Node,at:Vector2,style:String,strong:=false)->CombatContactFX:
	if not is_instance_valid(parent) or active_count>=24:return null
	var fx:=CombatContactFX.new();fx.frames=bank(style);fx.sprite=Sprite2D.new();fx.sprite.texture=fx.frames[0]
	fx.sprite.scale=Vector2.ONE*(42 if strong else 28)/float(fx.frames[0].get_width());fx.sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;fx.sprite.material=ink;fx.add_child(fx.sprite)
	parent.add_child(fx);fx.global_position=at;fx.z_as_relative=false;fx.z_index=50
	fx.modulate.a=clampf(PixelSpellArt.strength(),0,1)
	return fx
func _enter_tree()->void:active_count+=1
func _exit_tree()->void:active_count=maxi(0,active_count-1)
func _process(delta:float)->void:
	age+=delta
	if age>=life:queue_free();return
	sprite.texture=frames[1 if ComicMotion.reduced() else mini(3,int(age/life*4))]
	modulate.a=clampf(PixelSpellArt.strength(),0,1)*(1-smoothstep(.5,1,age/life))
