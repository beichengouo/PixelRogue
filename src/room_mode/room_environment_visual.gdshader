shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D fog_texture : repeat_enable, filter_nearest;
uniform sampler2D cloud_texture : repeat_enable, filter_nearest;
uniform vec2 fog_origin = vec2(0.0);
uniform float fog_world_scale = 1.0;
uniform float weather_time = 0.0;
uniform float darkness : hint_range(0.0,1.0) = 0.0;
uniform float fog_density : hint_range(0.0,1.0) = 0.0;
uniform float max_obscurity : hint_range(0.0,1.0) = 0.95;
uniform vec2 viewport_size = vec2(1280.0,720.0);
uniform int light_count = 0;
uniform vec4 lights[32];
uniform vec4 light_colors[32];
uniform float light_glow[32];
void fragment() {
	vec4 scene = texture(screen_texture,SCREEN_UV);
	vec2 pixel_position = SCREEN_UV * viewport_size;
	float lit = 0.0;
	float fog_lit = 0.0;
	vec3 warm = vec3(0.0);
	float glow = 0.0;
	vec3 glow_color = vec3(0.0);
	for (int i=0; i<32; i++) {
		if (i>=light_count) { break; }
		vec2 offset = pixel_position-lights[i].xy;
		float radius = max(1.0,lights[i].z);
		float distance_squared = dot(offset,offset);
		if (distance_squared>=radius*radius) { continue; }
		float distance_ratio = sqrt(distance_squared)/radius;
		float influence = (1.0-smoothstep(0.62,1.0,distance_ratio))*lights[i].w;
		// The strongest source wins; another nearby lamp never adds brightness.
		if (influence>lit) { lit=influence; warm=light_colors[i].rgb; }
		fog_lit = max(fog_lit,influence*light_colors[i].a);
		float aura = pow(1.0-distance_ratio,2.0)*lights[i].w*light_glow[i];
		if (aura>glow) { glow=aura; glow_color=light_colors[i].rgb; }
	}
	float illumination = clamp(lit,0.0,1.0);
	float clarity = clamp(fog_lit,0.0,1.0);
	// One final-world composite catches even unshaded snow, spells and enemy warnings.
	// Night suppresses fog; the configured veil always leaves some world detail visible.
	float night = darkness*(1.0-illumination);
	// Verified single images: Fog 320x180, Clouds 80x36. Both only shape
	// the existing veil, never add a second layer or obscure past its cap.
	vec2 fog_world = fog_origin+pixel_position*fog_world_scale;
	float wisps = texture(fog_texture,fract((fog_world+vec2(weather_time*3.0,0.0))/vec2(640.0,360.0))).a;
	float clouds = texture(cloud_texture,fract((fog_world+vec2(-weather_time*1.5,weather_time*0.7))/vec2(320.0,144.0))).a;
	float fog_profile = mix(0.88,1.0,max(wisps,clouds*0.7));
	float veil = max_obscurity*fog_density*fog_profile*(1.0-clarity)*(1.0-darkness);
	vec3 night_scene = mix(scene.rgb,vec3(1.0),veil) * (1.0-max_obscurity*night);
	vec3 tint = lit>0.001 ? warm : vec3(1.0);
	night_scene *= mix(vec3(1.0),mix(vec3(1.0),tint,0.14),darkness*illumination);
	// Chest aura remains visible by day, with one winning source instead of additive halos.
	night_scene = mix(night_scene,glow_color,clamp(glow*0.14,0.0,0.18));
	COLOR = vec4(night_scene,1.0);
}
