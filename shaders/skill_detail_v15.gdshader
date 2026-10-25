shader_type canvas_item;
render_mode unshaded;
uniform float phase=0.0;
uniform bool still=false;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
	vec4 ink=texture(TEXTURE,UV);
	float sweep=still?0.0:pow(max(0.0,sin(UV.x*18.0+UV.y*12.0-phase*6.2831853)),18.0)*0.16;
	COLOR=vec4(ink.rgb*(1.0+sweep),ink.a)*tint;
}
