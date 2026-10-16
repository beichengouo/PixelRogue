class_name HolyFX
extends Node2D
const ART_ROOT:="res://assets/characters/sylphiette_holy_v01/fx_v03/"
const DETAIL_ROOT:="res://assets/characters/sylphiette_holy_v01/fx_v04/"
const DETAILS:=["ring","warning","mark","prayer","grace","bolt"]
const STYLES:=["pillar","feather","cloud","bell","court","step","judgment","sanctuary","ring","warning","mark","prayer","grace","bolt"]
## Normalized center of the ground ellipse, measured in the fixed 256px cells.
const GROUND_ANCHORS:={"pillar":.672,"cloud":.656,"bell":.703,"court":.508,"judgment":.711,"sanctuary":.594,"ring":.5,"warning":.5,"prayer":.5,"grace":.5}
static func ground_rect(style:String,size_value:float,foot:=Vector2.ZERO)->Rect2:
	var height:=size_value*(2.7 if style=="pillar" else 2.4 if style=="judgment" else 2.0)
	if style in DETAILS:return Rect2(foot-Vector2.ONE*size_value*256.0/224.0,Vector2.ONE*size_value*2*256.0/224.0)
	return Rect2(foot-Vector2(size_value,height*float(GROUND_ANCHORS.get(style,.5))),Vector2(size_value*2,height))
static var textures:Dictionary={}
var kind:="ring"
var radius:=48.0
var duration:=.4
var age:=0.0
var facing:=Vector2.RIGHT
var warning_id:=""
var _follow:WeakRef
static func around(actor:Node2D,style:String,size_value:float=48,seconds:float=.4)->HolyFX:
	if not is_instance_valid(actor):return null
	var fx:=spawn(actor.get_parent(),actor.global_position,style,size_value,seconds)
	if fx!=null:fx._follow=weakref(actor)
	return fx
static func warm()->void:
	for style in STYLES:
		if not textures.has(style):textures[style]=load((DETAIL_ROOT if style in DETAILS else ART_ROOT)+style+".png")
static func paint(canvas:CanvasItem,style:String,rect:Rect2,phase:float,opacity:float=1)->bool:
	if not STYLES.has(style):return false
	if not textures.has(style):textures[style]=load((DETAIL_ROOT if style in DETAILS else ART_ROOT)+style+".png")
	var texture:=textures[style] as Texture2D
	if texture==null:return false
	var frame:=clampi(int(phase*4),0,3)
	canvas.draw_texture_rect_region(texture,rect,Rect2(frame*256,0,256,256),Color(1,1,1,opacity))
	return true
static func spawn(parent:Node,at:Vector2,style:String,size_value:float=48,seconds:float=.4)->HolyFX:
	if not is_instance_valid(parent) or not parent.is_inside_tree():return null
	if parent.get_tree().get_nodes_in_group("holy_visuals").size()>=48 and style!="warning":return null
	var fx:=HolyFX.new();fx.kind=style;fx.radius=size_value;fx.duration=maxf(.08,seconds);fx.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;parent.add_child(fx);fx.global_position=at+(Vector2(0,14) if GROUND_ANCHORS.has(style) or style=="step" else Vector2.ZERO);fx.z_index=7;fx.add_to_group("holy_visuals")
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;fx.material=ink;return fx
func _process(delta:float)->void:
	if _follow!=null:
		var actor:=_follow.get_ref() as Node2D
		if not is_instance_valid(actor) or not actor.is_inside_tree():queue_free();return
		global_position=actor.global_position+(Vector2(0,14) if GROUND_ANCHORS.has(kind) or kind=="step" else Vector2.ZERO)
	age+=delta
	if age>=duration:queue_free();return
	queue_redraw()
func _draw()->void:
	var p:=clampf(age/duration,0,1)
	var strength:=clampf(float(SaveService.data.get("spell_fx_strength",1)),0,1)
	var rect:=ground_rect(kind,radius)
	if kind in ["step","feather"]:
		draw_set_transform(Vector2.ZERO,facing.angle());rect=Rect2(-radius,-radius*.5,radius*2,radius)
	# Telegraphs retain their boundary for their full lifetime, even in low motion.
	var opacity:=strength if kind=="warning" else strength*(1-smoothstep(.7,1.0,p))
	paint(self,kind,rect,.4 if ComicMotion.reduced() else p,opacity)
