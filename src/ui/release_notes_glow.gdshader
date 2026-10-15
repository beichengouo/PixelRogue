shader_type canvas_item;
render_mode unshaded;
uniform vec2 extent=vec2(960.0,660.0);
uniform float movement=1.0;
void fragment(){
	vec2 q=abs((UV-0.5)*extent)-(extent*0.5-vec2(15.0));
	float distance=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-15.0;
	float rim=exp(-abs(distance+2.0)*0.52)*(1.0-smoothstep(-0.5,1.0,distance));
	float arc=atan((UV.y-0.5)*extent.y,(UV.x-0.5)*extent.x);
	float wave=pow(0.5+0.5*cos(arc-TIME*0.48*movement),8.0);
	float second=pow(0.5+0.5*cos(arc+2.4+TIME*0.25*movement),12.0);
	vec3 hue=mix(vec3(0.45,0.80,0.96),vec3(1.0,0.84,0.53),wave);
	COLOR=vec4(hue,rim*(0.20+0.65*wave+0.23*second));
}
