class_name IlyuaFX
extends Node2D
const ROOT:="res://assets/characters/ilyua/fx/"
const ROWS:={"basic":0,"bow_vine_short":0,"bow_lake_light":0,"bow_wood":0,"bow_cast":0,"ultimate_basic":0,"wind_arrow":0,"wind":0,"piercing":0,"ultimate_pierce":0,"true_pierce":0,"precision":0,"blade":1,"wind_blade":1,"feather":1,"favor":1,"leaf":1,"tree_shot":1,"seed":2,"mark":3,"forest_mark":3,"trap":4,"spread_vine":4,"zone":4,"wild_zone":4,"tree":5,"moon":6,"moon_reflect":6,"moon_reaction":6,"moon_arrow":6,"moon_block":6,"decoy":7,"step":7,"decoy_burst":8,"finish":8,"ultimate_finish":1,"ultimate":8,"ultimate_end":8,"wind_burst":8,"seed_burst":9,"tree_end":9,"thorn":9,"arrow_hit":8,"spring_cast":10,"spring_flight":11,"spring_hit":12}
static var _cache:Dictionary={}
var remaining:=.4
var duration:=.4
var sprite:AnimatedSprite2D
var _field_owner:WeakRef
var _field_offset:=Vector2(0,14)
var _hd_id:=""
var _detail_material:ShaderMaterial
static func frames(kind:String,phase:="flight")->Array[Texture2D]:
	if phase=="flight" and LargeSkillArt.ELF.has(kind):return LargeSkillArt.frames(LargeSkillArt.ELF[kind])
	var key:=kind+"_"+phase
	if _cache.has(key):return _cache[key]
	if kind in ["bow_spring_wind","spring_cast","spring_flight","spring_hit"]:
		var spring:=load(ROOT+"spring_wind_v03.png") as Texture2D
		var spring_row:int=0 if kind=="spring_cast" or phase=="cast" else 2 if kind=="spring_hit" or phase in ["hit","impact"] else 1
		var spring_frames:Array[Texture2D]=[]
		for column in 4:
			var cell:=AtlasTexture.new();cell.atlas=spring;cell.region=Rect2(column*128,spring_row*128,128,128);cell.filter_clip=true;spring_frames.append(cell)
		_cache[key]=spring_frames;return spring_frames
	if kind in ["basic","bow_vine_short","bow_lake_light","bow_wood","bow_cast","ultimate_basic","wind_arrow","wind","piercing","ultimate_pierce","true_pierce","precision","bow_spring_wind","spring_flight"] and phase=="flight":
		var green:=load(ROOT+"green_light_arrows.png") as Texture2D
		var green_frames:Array[Texture2D]=[]
		var green_row:=1 if kind in ["bow_spring_wind","spring_flight"] else 0
		for column in 4:
			var cell:=AtlasTexture.new();cell.atlas=green;cell.region=Rect2(column*128,green_row*128,128,128);cell.filter_clip=true;green_frames.append(cell)
		_cache[key]=green_frames;return green_frames
	var row:int=ROWS.get(kind,1)
	if kind=="bow_spring_wind":row={"cast":10,"flight":11,"hit":12,"impact":12}.get(phase,11)
	var result:Array[Texture2D]=[]
	var path:=ROOT+("nature.png" if row<7 else "spirit.png")
	if not ResourceLoader.exists(path):return result
	var texture:=load(path) as Texture2D
	var rows:=7 if row<7 else 6
	var width:=float(texture.get_width())/4.0;var height:=float(texture.get_height())/rows
	var source_row:=row if row<7 else row-7
	for index in 4:
		var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2(index*width,source_row*height,width,height);atlas.filter_clip=true;result.append(atlas)
	_cache[key]=result;return result
static func spawn(parent:Node,at:Vector2,kind:String,size:=72.0,lifetime:=.4)->IlyuaFX:
	var textures:=frames(kind)
	if textures.is_empty() or not is_instance_valid(parent):return null
	var impact:=kind in ["spring_hit","arrow_hit","seed_burst","decoy_burst","tree_end","ultimate_end"]
	if impact and parent.get_tree().get_nodes_in_group("legendary_full_impact").size()>=24:
		Effects.hit_spark(parent,at,Color("c8e59d"),2);return null
	var fx:=IlyuaFX.new();fx.position=at;fx.remaining=maxf(lifetime,.65) if size>=144 else lifetime;fx.duration=fx.remaining
	var hd:Texture2D
	if size>=120 and SizedSkillArt.ELF.has(kind):
		fx._hd_id=str(SizedSkillArt.ELF[kind])
		var pixels:=SizedSkillArt.screen_extent(parent,Vector2.ONE*size) if parent is CanvasItem else size*3
		hd=SizedSkillArt.texture(fx._hd_id,pixels)
		if hd!=null:textures.assign([hd,hd,hd,hd])
	fx.sprite=AnimatedSprite2D.new();var animation:=SpriteFrames.new()
	animation.set_animation_speed(&"default",4 if size>=144 and lifetime>.6 else (4/maxf(.65,lifetime) if size>=144 else 12 if lifetime>.6 else 16));animation.set_animation_loop(&"default",lifetime>.6)
	for texture in textures:animation.add_frame(&"default",texture)
	if kind in ["trap","spread_vine","zone","wild_zone"]:fx.sprite.modulate.a=.42
	fx.sprite.sprite_frames=animation;fx.sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	fx.sprite.material=RedrawnHeroArt.material()
	if hd!=null:
		fx.sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;fx._detail_material=SizedSkillArt.material();fx.sprite.material=fx._detail_material
	fx.sprite.scale=Vector2.ONE*size/maxf(textures[0].get_width(),textures[0].get_height())
	if kind=="tree":fx.sprite.position.y=-size*.4375
	if ComicMotion.reduced():animation.set_animation_speed(&"default",6)
	fx.add_child(fx.sprite)
	if parent is IlyuaField and is_instance_valid(parent.runtime) and is_instance_valid(parent.runtime.actor.room):
		# Keep gameplay fields in FX for saves/cleanup, but render their art on
		# the ground plane so the caster and hostile telegraphs stay readable.
		var owner_field:IlyuaField=parent
		fx._field_owner=weakref(owner_field);fx._field_offset=at+Vector2(0,14)
		owner_field.runtime.actor.room.add_child(fx)
		fx.global_position=owner_field.to_global(fx._field_offset)
	else:parent.add_child(fx)
	if impact:fx.add_to_group("legendary_full_impact")
	fx.sprite.play();return fx
func _process(dt:float)->void:
	if _detail_material!=null:_detail_material.set_shader_parameter("phase",1-remaining/maxf(.01,duration));_detail_material.set_shader_parameter("still",ComicMotion.reduced())
	if _field_owner!=null:
		var field:=_field_owner.get_ref() as Node2D
		if not is_instance_valid(field) or field.is_queued_for_deletion():queue_free();return
		global_position=field.to_global(_field_offset)
	remaining-=dt
	if remaining<=0:queue_free()
	elif sprite!=null and duration<1:sprite.modulate.a=minf(1,remaining/maxf(.08,duration*.3))
