shader_type canvas_item;
render_mode unshaded;
uniform float fill_ratio : hint_range(0.0,1.0)=1.0;
uniform float flow_age=0.0;
uniform bool reduced_motion=false;
void fragment(){
 vec4 painted=texture(TEXTURE,UV);
 float edge_wave=(reduced_motion?0.0:sin(UV.y*17.0-flow_age*2.8)*0.009+sin(UV.y*39.0+flow_age*1.4)*0.004);
 float inside=(1.0-smoothstep(fill_ratio+edge_wave-0.007,fill_ratio+edge_wave+0.007,UV.x))*step(0.00001,fill_ratio);
 float wave=sin(UV.x*24.0+UV.y*4.0-flow_age*2.0)*.5+.5;
 float vein=pow(max(0.0,sin(UV.x*31.0-UV.y*7.0-flow_age*1.7)),6.0);
 float surface=1.0-smoothstep(0.0,0.018,abs(UV.x-fill_ratio-edge_wave));
 float motion=reduced_motion?0.0:(wave-.5)*.13+vein*.10;
 COLOR=vec4(painted.rgb*(1.0+motion+surface*.22),painted.a*inside)*COLOR;
}
