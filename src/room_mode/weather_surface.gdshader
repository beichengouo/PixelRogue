shader_type canvas_item;
render_mode unshaded;
uniform sampler2D snow_sprite : filter_nearest;
uniform float snow_amount : hint_range(0.0,1.0) = 0.0;
uniform float wet_amount : hint_range(0.0,1.0) = 0.0;
uniform bool ground_plane = false;
// Authored masks address only real luminous pixels baked into map models.
// Defaults leave every existing weather surface unchanged.
uniform int model_light_count = 0;
uniform vec4 model_light_ellipses[16];
uniform float model_light_frame = 0.0;
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
	float model_paint = 0.0;
 if(model_light_count>0 && original.a>.01){
  float bright=max(original.r,max(original.g,original.b));
  float chroma=bright-min(original.r,min(original.g,original.b));
  float luminous=max(smoothstep(.08,.24,chroma),smoothstep(.85,.99,bright)*.7);
  for(int i=0;i<16;i++){
   if(i>=model_light_count){break;}
   vec4 area=model_light_ellipses[i];
   if(any(greaterThan(abs(UV-area.xy),area.zw))){continue;}
   float region=1.0-smoothstep(.55,1.0,length((UV-area.xy)/max(area.zw,vec2(.00001))));
   model_paint=max(model_paint,region*smoothstep(.55,.90,bright)*luminous);
  }
 }
 float lamp_power=model_light_frame==1.0?.92:(model_light_frame==2.0?1.035:(model_light_frame==3.0?.98:1.0));
 vec3 model_color=original.rgb*mix(1.0,lamp_power,model_paint);
 vec3 wet = model_color * (1.0-wet_amount*0.16);
	vec3 settled_color = mix(vec3(0.83,0.90,0.94),snow.rgb,0.35) * (ground_plane ? 0.78 : 0.92);
	COLOR = vec4(mix(wet*tint.rgb,settled_color,coverage*snow_amount),original.a*tint.a);
}
