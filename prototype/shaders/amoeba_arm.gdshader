shader_type canvas_item;
render_mode unshaded;
uniform sampler2D tissue_texture : filter_linear_mipmap, repeat_disable;
uniform vec2 extent = vec2(240.0,150.0);
uniform vec2 start = vec2(0.0);
uniform vec2 target = vec2(80.0,0.0);
uniform float extension = 0.0;
uniform float clock = 0.0;
uniform float motion = 1.0;
float capsule(vec2 p, vec2 a, vec2 b, float r) {
	vec2 ab = b-a;
	return length(p-a-ab*clamp(dot(p-a,ab)/max(dot(ab,ab),0.001),0.0,1.0))-r;
}
float merge(float a, float b, float k) {
	float h = clamp(0.5+0.5*(b-a)/k,0.0,1.0);
	return mix(b,a,h)-k*h*(1.0-h);
}
vec2 reach(float t, float side, vec2 goal, vec2 axis, vec2 normal) {
	// Travel along two thickening tongues, then curl around opposite sides of the prey.
	float travel = smoothstep(0.0,0.70,t);
	vec2 at = mix(axis*20.0,goal-axis*20.0,travel);
	float wrap = smoothstep(0.55,1.0,t);
	at += axis*(1.0-cos(wrap*2.75))*20.0;
	at += normal*side*(sin(t*3.14159)*10.0+sin(wrap*2.75)*26.0);
	return at;
}
void fragment() {
	vec2 p = UV*extent-start;
	vec2 axis = normalize(target+vec2(0.001,0.0));
	vec2 normal = vec2(-axis.y,axis.x);
	float distance = 1000.0;
	for(int side_index=0; side_index<2; side_index++) {
		float side = side_index==0 ? -1.0 : 1.0;
		vec2 a = axis*20.0;
		for(int i=1; i<=14; i++) {
			float t = float(i)/14.0*extension;
			vec2 b = reach(t,side,target,axis,normal);
			float radius = mix(13.0,6.5,t)+sin(t*8.0-clock*1.4*motion+side)*1.2*motion;
			distance = merge(distance,capsule(p,a,b,radius),5.0);
			a = b;
		}
	}
	float mask = (1.0-smoothstep(-0.8,1.0,distance))*smoothstep(0.0,0.15,extension);
	vec2 uv = vec2(0.5)+vec2(dot(p,axis),dot(p,normal))/175.0;
	uv += vec2(sin(uv.y*18.0+clock*motion),cos(uv.x*21.0-clock*motion))*0.013;
	vec3 tissue = texture(tissue_texture,clamp(uv,vec2(0.27),vec2(0.73))).rgb;
	float edge = exp(-abs(distance+1.0)*0.85);
	float inner = exp(-abs(distance+3.4)*0.72);
	vec3 color = mix(tissue,vec3(0.33,0.39,0.36),0.2);
	color += edge*vec3(0.37,0.47,0.44)+inner*vec3(0.12,0.11,0.07);
	COLOR = vec4(color,mask*0.90);
}
