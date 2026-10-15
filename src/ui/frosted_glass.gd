class_name FrostedGlass
extends Control
## Screen texture is captured once per canvas; all glass surfaces share that background.
static var _shader:Shader
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	show_behind_parent=true
	if _shader==null:
		_shader=Shader.new()
		_shader.code="""shader_type canvas_item;
render_mode unshaded;
uniform sampler2D backdrop : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 extent = vec2(400.0,300.0);
uniform float roundness = 12.0;
void fragment() {
	vec2 p=abs((UV-0.5)*extent)-(extent*0.5-vec2(roundness));
	float edge=length(max(p,vec2(0.0)))+min(max(p.x,p.y),0.0)-roundness;
	vec3 blurred=textureLod(backdrop,SCREEN_UV,2.2).rgb;
	blurred=mix(blurred,vec3(0.06,0.10,0.14),0.38);
	COLOR=vec4(blurred,0.76*(1.0-smoothstep(-1.0,1.0,edge)));
}"""
	var glass:=ShaderMaterial.new();glass.shader=_shader;material=glass
	resized.connect(_resize);_resize()
func _resize()->void:
	if material is ShaderMaterial:material.set_shader_parameter("extent",size)
	queue_redraw()
func _draw()->void:draw_rect(Rect2(Vector2.ZERO,size),Color.WHITE)
