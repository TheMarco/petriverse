shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
varying vec4 grain;
varying vec2 drift;
void vertex() {
	grain = INSTANCE_CUSTOM;
	drift = COLOR.rg;
}
void fragment() {
	vec2 p = (UV-vec2(0.5))*7.0;
	float speed = drift.x*60.0;
	float glint = pow(max(0.0,sin(clock*grain.w+grain.z*6.283185)),24.0)*drift.y;
	float alpha = (0.43+glint*0.55+smoothstep(5.0,24.0,speed)*0.18)*grain.y;
	float aa = max(0.28,fwidth(p.x)*0.6);
	float point = 1.0-smoothstep(grain.x-aa,grain.x+aa,length(p));
	float tail_length = clamp(speed*0.055,0.0,2.5);
	vec2 tail_at = vec2(clamp(p.x,-tail_length,0.0),0.0);
	float tail = (1.0-smoothstep(0.0,grain.x*0.6+aa,length(p-tail_at)))*smoothstep(0.0,-tail_length-0.01,p.x);
	float halo = exp(-dot(p,p)/1.1)*glint*0.10;
	vec3 tone = mix(vec3(0.76,0.89,0.94),vec3(0.94,0.98,0.98),glint);
	COLOR = vec4(tone,clamp(alpha*(point+tail*0.20)+halo,0.0,1.0));
}
