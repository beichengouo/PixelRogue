shader_type canvas_item;
uniform float wetness : hint_range(0.0,1.0) = 0.0;
uniform float snow_amount : hint_range(0.0,1.0) = 0.0;
void fragment() {
	vec4 leaf = texture(TEXTURE, UV);
	float above = texture(TEXTURE, UV - vec2(0.0,TEXTURE_PIXEL_SIZE.y * 2.0)).a;
	float edge = step(0.4,leaf.a) * (1.0-step(0.4,above));
	COLOR.rgb *= mix(vec3(1.0),vec3(0.78,0.86,0.9),wetness * 0.6);
	COLOR.rgb = mix(COLOR.rgb,vec3(0.86,0.93,0.95),edge * snow_amount);
}
