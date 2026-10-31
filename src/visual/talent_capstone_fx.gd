class_name TalentCapstoneFX
extends Node2D
## Decorative capstone onset. Skill hit radii and warning geometry remain authoritative.
const ROOT:="res://assets/talents_v39/fx/"
static var textures:Dictionary={}
var texture:Texture2D
var radius:=72.0
var age:=0.0
var duration:=.68
static func spawn(parent:Node,at:Vector2,skill:StringName,radius_value:float=72)->TalentCapstoneFX:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or not PermanentTalents.active(skill):return null
	if parent.get_tree().get_nodes_in_group("talent_capstone_fx").size()>=32:return null
	var hero:=str(PermanentTalents.skill(skill).get("hero",""))
	if hero.is_empty():return null
	if not textures.has(hero):textures[hero]=load(ROOT+hero+"_capstone.png")
	if not textures[hero] is Texture2D:return null
	var fx:=TalentCapstoneFX.new();fx.texture=textures[hero];fx.radius=clampf(radius_value,36,240)
	fx.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(fx);fx.global_position=at;fx.z_index=0;fx.add_to_group("talent_capstone_fx")
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;fx.material=ink
	return fx
func _process(delta:float)->void:
	age+=delta
	if age>=duration:queue_free();return
	queue_redraw()
func _draw()->void:
	if texture==null:return
	var progress:=clampf(age/duration,0,1)
	var size_factor:=1.0 if ComicMotion.reduced() else lerpf(.74,1.0,smoothstep(0,.65,progress))
	var size_value:=radius*2.0*size_factor
	var strength:=clampf(float(SaveService.data.get("spell_fx_strength",1.0)),0,1)
	var opacity:=.72*strength*(1.0-smoothstep(.62,1.0,progress))
	draw_texture_rect(texture,Rect2(-Vector2.ONE*size_value*.5,Vector2.ONE*size_value),false,Color(1,1,1,opacity))
