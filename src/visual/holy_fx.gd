class_name HolyFX
extends Node2D
const ART_ROOT:="res://assets/characters/sylphiette_holy_v01/fx_v03/"
const STYLES:=["pillar","feather","cloud","bell","court","step","judgment","sanctuary"]
## Normalized center of the ground ellipse, measured in the fixed 256px cells.
const GROUND_ANCHORS:={"pillar":.672,"cloud":.656,"bell":.703,"court":.508,"judgment":.711,"sanctuary":.594}
static func ground_rect(style:String,size_value:float,foot:=Vector2.ZERO)->Rect2:
	var height:=size_value*(2.7 if style=="pillar" else 2.4 if style=="judgment" else 2.0)
	return Rect2(foot-Vector2(size_value,height*float(GROUND_ANCHORS.get(style,.5))),Vector2(size_value*2,height))
static var textures:Dictionary={}
var kind:="ring"
var radius:=48.0
var duration:=.4
var age:=0.0
var facing:=Vector2.RIGHT
var warning_id:=""
static func warm()->void:
	for style in STYLES:
		if not textures.has(style):textures[style]=load(ART_ROOT+style+".png")
static func paint(canvas:CanvasItem,style:String,rect:Rect2,phase:float,opacity:float=1)->bool:
	if not STYLES.has(style):return false
	if not textures.has(style):textures[style]=load(ART_ROOT+style+".png")
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
	age+=delta
	if age>=duration:queue_free();return
	queue_redraw()
func star(at:Vector2,r:float,color:Color)->void:
	draw_colored_polygon(PackedVector2Array([at+Vector2(0,-r),at+Vector2(r*.25,-r*.25),at+Vector2(r,0),at+Vector2(r*.25,r*.25),at+Vector2(0,r),at+Vector2(-r*.25,r*.25),at+Vector2(-r,0),at+Vector2(-r*.25,-r*.25)]),color)
func _draw()->void:
	var p:=clampf(age/duration,0,1);var strength:=clampf(float(SaveService.data.get("spell_fx_strength",1)),0,1);var gold:=Color(1,.85,.45,strength*(1-p));var white:=Color(1,.98,.86,strength*(1-p));var blue:=Color(.55,.82,1,strength*(1-p))
	if kind=="warning":
		gold.a=strength*.65;draw_arc(Vector2.ZERO,radius,0,TAU,48,gold,2);draw_arc(Vector2.ZERO,radius*.75,0,TAU,40,blue,1)
		for i in 8:star(Vector2.RIGHT.rotated(i*TAU/8)*(radius*.86),3,gold)
		return
	if STYLES.has(kind):
		var rect:=ground_rect(kind,radius)
		if kind in ["step","feather"]:
			draw_set_transform(Vector2.ZERO,facing.angle())
			rect=Rect2(-radius,-radius*.5,radius*2,radius)
		paint(self,kind,rect,.4 if ComicMotion.reduced() else p,strength*(1-smoothstep(.7,1.0,p)))
		if kind in ["pillar","bell"]:
			draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(.24,.55,1,strength*(1-p)),2)
		return
	if kind=="pillar":
		var width:=maxf(6,radius*.25)*(1-p);var height:=radius*2.5
		draw_colored_polygon(PackedVector2Array([Vector2(-width,-height),Vector2(width,-height),Vector2(width*.65,0),Vector2(-width*.65,0)]),Color(gold,.35*(1-p)*strength))
		draw_line(Vector2(0,-height),Vector2.ZERO,white,4*(1-p)+1)
		for side in [-1,1]:draw_line(Vector2(side*width,-height),Vector2(side*width*.65,0),gold,2)
		draw_arc(Vector2.ZERO,radius*.7,0,TAU,40,gold,2);draw_arc(Vector2.ZERO,radius,0,TAU,48,blue,1)
	elif kind=="feather":
		var axis:=Vector2.RIGHT.rotated(p*PI*.15);var points:=PackedVector2Array([Vector2(-radius*.5,0),Vector2(-radius*.2,-radius*.22),Vector2(radius*.3,-radius*.15),Vector2(radius*.55,0),Vector2(radius*.2,radius*.16)])
		draw_colored_polygon(points,white);draw_line(-axis*radius*.4,axis*radius*.5,gold,2)
	elif kind=="cloud":
		for i in 6:
			var at:=Vector2.RIGHT.rotated(i*TAU/6)*radius*.65;draw_arc(at,radius*.25,PI*.25,PI*1.75,20,white,2)
		draw_arc(Vector2.ZERO,radius,0,TAU,48,gold,2)
	else:
		var r:=radius*(.35+.65*p);draw_arc(Vector2.ZERO,r,0,TAU,48,gold,2);draw_arc(Vector2.ZERO,r*.72,0,TAU,40,white,1)
		if not ComicMotion.reduced():
			for i in 8:star(Vector2.RIGHT.rotated(i*TAU/8+p*.25)*r,3*(1-p)+1,blue if i%2 else gold)
