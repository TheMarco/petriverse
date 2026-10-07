shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/pond_optics.gdshaderinc"
uniform sampler2D tissue_texture : filter_linear_mipmap, repeat_disable;
uniform sampler2D outline_texture : filter_linear, repeat_disable;
uniform vec2 extent = vec2(260.0);
uniform vec2 origin = vec2(130.0);
uniform vec2 target = vec2(80.0,0.0);
uniform float clock = 0.0;
uniform float crawl = 0.0;
uniform float motion = 1.0;
uniform float phase = 0.0;
uniform float arrival = 1.0;
uniform float extension = 0.0;
uniform float ingestion = 0.0;
uniform float closure = 0.0;
uniform float meal = 0.0;
uniform vec3 water_base = vec3(0.055,0.115,0.15);
varying vec4 tint;
const vec2 NUCLEUS = vec2(0.534,0.463);
const float SIZE = 152.0;
void vertex() { tint = COLOR; }
float capsule(vec2 p, vec2 a, vec2 b, float r) {
	vec2 ab = b-a;
	return length(p-a-ab*clamp(dot(p-a,ab)/max(dot(ab,ab),0.001),0.0,1.0))-r;
}
float merge(float a, float b, float k) {
	float h = clamp(0.5+0.5*(b-a)/k,0.0,1.0);
	return mix(b,a,h)-k*h*(1.0-h);
}
vec2 body_coordinate(vec2 p) {
	float cycle = crawl*motion;
	float surge = sin(cycle);
	float retract = sin(cycle-1.2);
	float mobile = smoothstep(9.0,29.0,length(p));
	vec2 q = p;
	float front = smoothstep(2.0,57.0,p.x);
	float rear = 1.0-smoothstep(-65.0,-4.0,p.x);
	q.x /= 1.0+(front*(0.08+0.27*surge)-rear*0.20*retract)*motion;
	q.y /= 1.0-0.12*surge*mobile*motion;
	q.y -= sin(cycle*0.71+phase)*12.0*exp(-pow((p.x+22.0)/29.0,2.0))*smoothstep(4.0,32.0,p.y)*motion;
	q.y += sin(p.x*0.048-cycle)*3.0*mobile*motion;
	// Drawing out the front feeds the cup from the whole cell. The rear and
	// flanks contract gently; a separate gripping body is never layered on top.
	q.x *= 1.0+extension*rear*0.12;
	q.y *= 1.0+extension*mobile*0.09;
	return mix(p,q,mobile);
}
float original_distance(vec2 uv) {
	vec2 bounded = clamp(uv,vec2(0.001),vec2(0.999));
	return texture(outline_texture,bounded).r*SIZE+length(uv-bounded)*SIZE;
}
vec2 reach(float t, float side, vec2 axis, vec2 normal) {
	float travel = smoothstep(0.0,0.72,t);
	vec2 at = mix(axis*9.0,target-axis*22.0,travel);
	float wrap = smoothstep(0.48,1.0,t)*(2.78+closure*0.36);
	at += axis*(1.0-cos(wrap))*22.0;
	at += normal*side*(sin(t*3.14159)*11.0+sin(wrap)*26.0);
	return at;
}
void fragment() {
	vec2 p = UV*extent-origin;
	vec2 q = body_coordinate(p);
	vec2 uv = NUCLEUS+q/SIZE;
	float distance = original_distance(uv);
	vec2 axis = normalize(target+vec2(0.001,0.0));
	vec2 normal = vec2(-axis.y,axis.x);
	// One signed-distance surface: its only optical rim is the final outer
	// boundary. No original sprite outline survives inside the growing cup.
	if (extension>0.001) {
		for(int side_index=0; side_index<2; side_index++) {
			float side = side_index==0 ? -1.0 : 1.0;
			vec2 a = axis*9.0;
			for(int i=1; i<=12; i++) {
				float progress = float(i)/12.0*extension;
				vec2 b = reach(progress,side,axis,normal);
				float radius = mix(18.0,7.0,progress)*smoothstep(0.0,0.14,extension);
				distance = merge(distance,capsule(p,a,b,radius),9.0);
				a = b;
			}
		}
	}
	// The cup first seals. Only then does its clear interior become a vacuole,
	// already inside the joined membrane, as the whole front folds back inward.
	float chamber_radius = mix(-32.0,27.0*(1.0-meal*0.20),closure);
	if (closure>0.001) distance = merge(distance,length(p-target)-chamber_radius,9.0);
	float t = clock*motion;
	float nuclear_pin = smoothstep(11.0,23.0,length(p));
	// The same material coordinates cover body, advancing lips and chamber.
	// Compress the material coordinates smoothly across the entire cell. Unlike
	// clamping/projecting UVs onto an edge, this keeps two-dimensional detail at
	// the lips instead of stretching one border texel into a visible streak.
	vec2 material_q = q-axis*extension*max(0.0,length(target)-43.0)*smoothstep(8.0,max(35.0,length(target)+24.0),dot(q,axis))*nuclear_pin;
	vec2 material_uv = NUCLEUS+vec2(atan(material_q.x/75.0)*0.27,atan(material_q.y/36.0)*0.12);
	material_uv = mix(NUCLEUS+p/SIZE,material_uv,smoothstep(12.0,35.0,length(p)));
	float stream_phase = fract(t*0.09+phase);
	float alternate_phase = fract(stream_phase+0.5);
	float stream_weight = pow(sin(stream_phase*3.14159265),2.0);
	float stream_strength = nuclear_pin*motion;
	vec2 flow = axis*(stream_phase-0.5)*0.07+normal*0.004*sin(q.x*0.08-t*0.61+phase);
	vec2 alternate_flow = axis*(alternate_phase-0.5)*0.07+normal*0.004*sin(q.x*0.08-t*0.61+phase);
	vec3 color = mix(texture(tissue_texture,material_uv-alternate_flow*stream_strength).rgb,texture(tissue_texture,material_uv-flow*stream_strength).rgb,stream_weight);
	// The nucleus is anatomical and stays fixed at the game's capture point.
	float core = 1.0-smoothstep(9.0,13.0,length(p));
	vec3 nucleus = texture(tissue_texture,NUCLEUS+p/SIZE).rgb*vec3(1.15,1.05,0.78);
	color = mix(color,nucleus,core);
	float clear_band = exp(-abs(distance+2.6)*0.43);
	float rim = exp(-abs(distance+0.9)*1.05);
	float inner_rim = exp(-abs(distance+3.4)*1.6);
	vec2 surface_normal = normalize(vec2(dFdx(distance),dFdy(distance))+vec2(0.00001));
	float lighting = dot(surface_normal,normalize(vec2(-0.65,-0.76)));
	// A refractive double membrane, like the colony cells. It follows the
	// final union, so the engulfing lips never acquire an internal seam.
	color = mix(color,vec3(0.40,0.56,0.59),clear_band*0.50);
	color += rim*(0.30+max(0.0,lighting)*0.28)*vec3(0.72,0.94,1.0);
	color += inner_rim*0.12*vec3(0.65,0.86,0.91);
	color = pond_focal_tone(color,water_base,0.19);
	float mask = 1.0-smoothstep(-0.65,0.7,distance);
	float alpha = mix(0.77,0.98,max(clear_band,rim))*mask;
	COLOR = vec4(color,alpha*smoothstep(0.0,0.65,arrival))*tint;
}
