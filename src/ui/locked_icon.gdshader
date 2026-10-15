shader_type canvas_item;
void fragment() {
	vec4 pixel=COLOR;
	float gray=dot(pixel.rgb,vec3(0.2126,0.7152,0.0722));
	COLOR=vec4(vec3(gray*.72),pixel.a*.8);
}
