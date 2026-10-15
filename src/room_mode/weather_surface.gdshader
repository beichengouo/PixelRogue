shader_type canvas_item;
render_mode unshaded;
uniform sampler2D snow_sprite : filter_nearest;
uniform float snow_amount : hint_range(0.0,1.0) = 0.0;
uniform float wet_amount : hint_range(0.0,1.0) = 0.0;
uniform bool ground_plane = false;
varying vec4 vertex_tint;
varying vec2 world_position;
void vertex() {
	vertex_tint = COLOR;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec4 tint = vertex_tint;
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	float above = texture(TEXTURE, UV - vec2(0.0, pixel.y*2.0)).a;
	float upper_edge = step(above, 0.1);
	vec4 snow = texture(snow_sprite, fract(world_position / vec2(73.0,67.0)));
	
	vec2 cell = floor(world_position / 24.0);
	vec2 fraction = smoothstep(vec2(0.0),vec2(1.0),fract(world_position / 24.0));
	float a = fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);
	float b = fract(sin(dot(cell+vec2(1.0,0.0),vec2(12.9898,78.233)))*43758.5453);
	float c = fract(sin(dot(cell+vec2(0.0,1.0),vec2(12.9898,78.233)))*43758.5453);
	float d = fract(sin(dot(cell+vec2(1.0),vec2(12.9898,78.233)))*43758.5453);
	float grain = mix(mix(a,b,fraction.x),mix(c,d,fraction.x),fraction.y);
	float ledge = ground_plane ? 1.0 : max(upper_edge, smoothstep(0.72,0.05,UV.y)*0.65);
	float coverage = smoothstep(grain-0.18,grain+0.18,snow_amount) * ledge;
	vec3 wet = original.rgb * (1.0-wet_amount*0.16);
	vec3 settled_color = mix(vec3(0.83,0.90,0.94),snow.rgb,0.35) * (ground_plane ? 0.78 : 0.92);
	COLOR = vec4(mix(wet*tint.rgb,settled_color,coverage*snow_amount),original.a*tint.a);
}
