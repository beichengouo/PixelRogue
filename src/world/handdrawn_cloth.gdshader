shader_type canvas_item;
uniform int palette = 0;
uniform bool motion_enabled = true;
varying vec4 actor_tint;
varying vec2 local_position;
void vertex() {
 actor_tint = COLOR;
 local_position = VERTEX;
}
void fragment() {
 vec4 pixel = texture(TEXTURE, UV);
 float gold = smoothstep(0.12,0.3,pixel.r-pixel.b) * smoothstep(0.2,0.45,pixel.g);
 float violet = smoothstep(0.03,0.13,pixel.b-max(pixel.r,pixel.g));
 float leaf = smoothstep(0.015,0.1,pixel.g-max(pixel.r,pixel.b));
 float trim = palette==1 ? violet : palette==2 ? max(leaf,gold*0.55) : gold;
 // Cloth below the neck only. Geometry, alpha and actor tint stay intact.
 trim *= smoothstep(8.0,30.0,local_position.y);
 float sweep = motion_enabled ? pow(max(0.0,sin((local_position.y+local_position.x*0.25)*0.026-TIME*1.45)),12.0) : 0.16;
 vec3 hue = palette==1 ? vec3(0.55,0.32,0.9) : palette==2 ? vec3(0.55,0.85,0.52) : vec3(0.95,0.78,0.38);
 COLOR = vec4(pixel.rgb+hue*trim*(0.025+0.18*sweep),pixel.a)*actor_tint;
}
