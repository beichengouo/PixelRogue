shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool reduced_motion = false;
uniform vec2 frame_origin = vec2(0.0);
uniform vec2 frame_size = vec2(1.0);
varying vec4 actor_tint;
void vertex() { actor_tint = COLOR; }
float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	if (pixel.a < 0.2) { discard; }
	pixel.a = 1.0;
	float p = clamp(progress, 0.0, 1.0);
	if (reduced_motion) {
		pixel.a *= 1.0 - p;
	} else {
		vec2 local = (UV - frame_origin) / max(frame_size, vec2(0.0001));
		float threshold = grain(floor(local * 48.0));
		float keep = p >= 0.999 ? 0.0 : step(p, threshold);
		float edge = p > 0.001 ? (1.0 - smoothstep(p, p + 0.10, threshold)) * keep : 0.0;
		pixel.rgb = mix(pixel.rgb, vec3(1.0, 0.87, 0.60), edge * 0.45);
		pixel.a *= keep * (1.0 - p * 0.45);
	}
	COLOR = pixel * actor_tint;
}
