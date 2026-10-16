class_name RewardCardFX
extends Control
## Native, bounded starlight drawing; no extra texture sheets or world lights.
static var _shader:Shader
var phase:="idle"
var progress:=0.0
var tint:=Color("edc881")
var duration:=0.4
var icon_center:=Vector2(162,82)
var reduced:=false
var _elapsed:=0.0
var _body:Control
var _material:ShaderMaterial
const DISSOLVE_SHADER:="""
shader_type canvas_item;
render_mode unshaded;
uniform vec4 card_bounds=vec4(0.0,0.0,300.0,488.0);
uniform vec2 viewport_size=vec2(1280.0,720.0);
uniform vec4 starlight : source_color=vec4(1.0,0.85,0.55,1.0);
uniform float reveal=1.0;
uniform float dissolve=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 local=(SCREEN_UV*viewport_size-card_bounds.xy)/max(card_bounds.zw,vec2(1.0));
 float opening=reveal>=0.999?1.0:(reveal<=0.001?0.0:1.0-smoothstep(reveal-0.045,reveal+0.045,local.y));
 float grain=hash(floor(local*vec2(50.0,80.0)));
 float threshold=0.08+0.84*(1.0-clamp(local.y,0.0,1.0))+grain*0.08;
 float remaining=dissolve>=0.999?0.0:smoothstep(dissolve-0.02,dissolve+0.02,threshold);
 float edge=(dissolve>0.001&&dissolve<0.999)?1.0-smoothstep(0.012,0.045,abs(threshold-dissolve)):0.0;
 COLOR.rgb=mix(COLOR.rgb,starlight.rgb,edge*0.55);
 COLOR.a*=opening*remaining;
}
"""
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_process(false)
func configure(body:Control,color:Color)->void:
	_body=body;tint=color.lightened(.2)
	if _shader==null:_shader=Shader.new();_shader.code=DISSOLVE_SHADER
	_material=ShaderMaterial.new();_material.shader=_shader;_material.set_shader_parameter("starlight",tint);body.material=_material
	for node in body.find_children("*","CanvasItem",true,false):node.use_parent_material=true
	_update_bounds()
func play(kind:String,seconds:float)->void:
	phase=kind;duration=maxf(.01,seconds);_elapsed=0;progress=0;reduced=ComicMotion.reduced();set_process(true);_update_bounds();queue_redraw()
	_material.set_shader_parameter("reveal",0.0 if kind=="appear" and not reduced else 1.0)
	_material.set_shader_parameter("dissolve",0.0)
func stop()->void:
	phase="idle";progress=1;set_process(false)
	if _material!=null:_material.set_shader_parameter("reveal",1.0);_material.set_shader_parameter("dissolve",0.0)
	queue_redraw()
func _process(delta:float)->void:
	_elapsed=minf(duration,_elapsed+delta);progress=_elapsed/duration
	_update_bounds()
	if not reduced:
		if phase=="appear":_material.set_shader_parameter("reveal",progress)
		elif phase=="dissolve":_material.set_shader_parameter("dissolve",progress)
	queue_redraw()
	if progress>=1:
		if phase=="appear":phase="idle"
		set_process(false)
func _update_bounds()->void:
	# Cards are configured before their holder enters the scene tree.
	if not is_inside_tree() or not is_instance_valid(_body) or _material==null:return
	var viewport:=get_viewport()
	if viewport==null:return
	var rect:=_body.get_global_rect();_material.set_shader_parameter("card_bounds",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y));_material.set_shader_parameter("viewport_size",viewport.get_visible_rect().size)
func _star(at:Vector2,radius:float,color:Color)->void:
	at=at.round()
	draw_colored_polygon(PackedVector2Array([at+Vector2(0,-radius),at+Vector2(radius*.3,-radius*.3),at+Vector2(radius,0),at+Vector2(radius*.3,radius*.3),at+Vector2(0,radius),at+Vector2(-radius*.3,radius*.3),at+Vector2(-radius,0),at+Vector2(-radius*.3,-radius*.3)]),color)
func _draw()->void:
	# Static celestial corners distinguish reward faces without covering the item
	# information. Idle cards never need a running animation or another texture.
	if is_instance_valid(_body) and _body.visible:
		var ink:=Color(tint,.32)
		for corner in [Vector2(24,24),Vector2(size.x-24,24),Vector2(24,size.y-24),Vector2(size.x-24,size.y-24)]:
			_star(corner,3,ink)
		draw_line(Vector2(34,23),Vector2(size.x-34,23),Color(tint,.14),1)
		draw_line(Vector2(34,size.y-23),Vector2(size.x-34,size.y-23),Color(tint,.14),1)
	if phase=="idle":return
	var flash:=clampf(float(SaveService.data.get("flash_strength",1.0)),0,1)
	var color:=Color(tint,flash*.8)
	if reduced:
		if phase=="selected":_confirmation(Color(tint,.85))
		return
	match phase:
		"appear":
			var frontier:=12+(size.y-24)*progress;color.a*=(1.0-progress)
			draw_line(Vector2(14,frontier),Vector2(size.x-14,frontier),color,2)
			for i in 8:_star(Vector2(20+(size.x-40)*float(i)/7,frontier+sin(float(i)*2.4)*7),2.0+float(i%3),color)
		"dissolve":
			var frontier:=size.y-12-(size.y-24)*progress
			for i in 28:
				var seed:=float(i)*2.399963;var travel:=maxf(0,progress-float(i%7)*.055)
				var at:=Vector2(18+fmod(float(i*67),maxf(1,size.x-36)),frontier+cos(seed)*10-travel*42)
				var dust:=Color(tint,flash*.8*(1-progress));_star(at,1.5+float(i%3)*.65,dust)
		"selected":
			color.a*=sin(progress*PI)
			draw_arc(icon_center,42+progress*26,0,TAU,48,color,2)
			for i in 8:
				var direction:=Vector2.RIGHT.rotated(float(i)*TAU/8-PI*.5)
				_star(icon_center+direction*(50+progress*44),3.5*(1-progress)+1,color)
			if progress>.22:_confirmation(Color(tint,clampf((progress-.22)*3,0,1)))
func _confirmation(color:Color)->void:
	var at:=Vector2(size.x*.5,size.y*.68)
	draw_line(at+Vector2(-12,0),at+Vector2(-3,9),color,3,true);draw_line(at+Vector2(-3,9),at+Vector2(15,-10),color,3,true)
