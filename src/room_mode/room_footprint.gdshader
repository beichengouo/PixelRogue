shader_type canvas_item;
void fragment() {
	float radius = length((UV-vec2(0.5))*2.0);
	COLOR.a *= 1.0-smoothstep(0.72,1.0,radius);
}
