shader_type canvas_item;
render_mode unshaded;
varying vec4 instance_tint;

void vertex() {
	instance_tint = COLOR;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	// Runtime palette steps keep enlarged magic crisp; original PNG/alpha stay intact.
	art.rgb = floor(art.rgb * 15.0 + 0.5) / 15.0;
	art.a = floor(art.a * 6.0 + 0.5) / 6.0;
	COLOR = art * instance_tint;
}
