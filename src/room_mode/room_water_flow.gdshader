shader_type canvas_item;
uniform float flow_clock = 0.0;
void fragment(){
	vec4 base=texture(TEXTURE,UV);
	vec2 local=mod(UV*vec2(576.0),vec2(36.0));
	vec2 cell=floor(UV*vec2(576.0)/vec2(36.0))*36.0;
	// The four source frames supply actual waves. Keep the optional flow
	// shimmer subpixel, inside this mask cell, so shore pixels never drift.
	vec2 ripple=vec2(sin(flow_clock*.8+cell.x*.03)*.35,cos(flow_clock*.6+cell.y*.03)*.2);
	vec2 moving=clamp(local+ripple,vec2(.5),vec2(35.5));
	vec4 wave=texture(TEXTURE,(cell+moving)/576.0);
	bool wet=base.b>base.r*1.23 && base.g>base.r*1.18;
	bool wave_wet=wave.b>wave.r*1.23 && wave.g>wave.r*1.18;
	if(wet && wave_wet)base.rgb=mix(base.rgb,wave.rgb,.08);
	COLOR=base*COLOR;
}
