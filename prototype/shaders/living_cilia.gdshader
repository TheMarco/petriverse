shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float motion = 1.0;
uniform float phase = 0.0;
uniform float energy = 1.0;
uniform float kind = 0.0;
uniform float lure = 0.0;
uniform float display_extent = 63.0;
uniform vec4 morphology = vec4(0.0);
uniform vec4 phenotype = vec4(1.0,1.0,0.0,0.0);
uniform vec2 flow_velocity = vec2(0.0);
varying float across;
varying float half_width;
varying vec4 strand_color;
varying vec4 inherited_tint;

float membrane_scale(float angle) {
	float amount = (0.08+cos(angle*3.0+0.5)*0.15)*morphology.x;
	amount += (0.135+cos(angle*5.0-0.2)*0.045)*morphology.y;
	amount += (0.03+cos(angle*2.0)*0.16+cos(angle*6.0)*0.045)*morphology.z;
	return 1.0/(1.0-clamp(amount+morphology.w*0.02,-0.22,0.34));
}

void vertex() {
	float index = INSTANCE_CUSTOM.x;
	float normal_count = kind==1.0 ? 34.0 : 16.0;
	float count = kind==2.0 ? 34.0 : kind==3.0 ? 6.0 : normal_count;
	float angle = TAU*index/count+phase*0.13;
	float growth = 1.0;
	if (kind<=1.0 && index>=normal_count) {
		angle = TAU*(index-normal_count)/(kind==1.0 ? 8.0 : 7.0)+phase*0.13+0.13;
		growth = lure;
	}
	float t = clock*motion*(0.91+0.09*sin(phase*1.71))+phase;
	float vigor = mix(0.24,1.0,energy);
	float beat_wave = pow(0.5+0.5*sin(t*1.38),3.0)-0.3125;
	float breath = (beat_wave*0.053+sin(t*0.49+1.3)*0.011)*motion*vigor;
	vec2 outward = vec2(cos(angle),sin(angle));
	vec2 tangent = vec2(-outward.y,outward.x);
	vec2 base = outward*(kind==2.0 ? vec2(0.385,0.168) : vec2(0.391))*(1.0-breath);
	if (kind<=1.0) {
		base *= membrane_scale(angle);
		if (kind==0.0) { base /= phenotype.xy; }
	}
	float strand_length = (0.042+0.019*sin(index*2.17+phase))*(kind==2.0 ? 1.5 : 1.0);
	if (kind<=1.0) { strand_length *= mix(1.0,2.15,lure)*growth; }
	float cycle = t*(kind==2.0 ? 7.2 : 2.4)-angle*2.0+sin(angle*3.0+phase)*0.25;
	float beat = (sin(cycle)+0.32*sin(cycle*2.0+0.4))*motion*vigor;
	float u = UV.x;
	float delayed = sin(cycle-u*1.9)*0.35*motion*vigor;
	float bend = (beat*0.64*u*u+delayed*u*u*u+sin(u*PI)*0.13)*strand_length;
	vec2 point = base+outward*strand_length*u+tangent*bend-flow_velocity*0.009*u*u*motion;
	float derivative = (beat*1.28*u+3.0*delayed*u*u-cos(cycle-u*1.9)*0.665*motion*vigor*u*u*u+cos(u*PI)*PI*0.13)*strand_length;
	vec2 direction = outward*strand_length+tangent*derivative-flow_velocity*0.018*u*motion;
	vec2 normal = length(direction)>0.00001 ? normalize(vec2(-direction.y,direction.x)) : tangent;
	float taper = u>4.0/7.0 ? 0.53 : 1.0;
	half_width = max(0.0010,0.56/display_extent)*0.5*taper;
	across = (UV.y*2.0-1.0)*(half_width+0.75/display_extent);
	VERTEX = point+normal*across;
	strand_color = vec4(0.68,0.85,0.90,(0.21+0.20*energy)*growth*(u>4.0/7.0 ? 0.72 : 1.0));
	inherited_tint = COLOR;
}

void fragment() {
	float aa = max(fwidth(across)*0.65,0.20/display_extent);
	float coverage = 1.0-smoothstep(half_width-aa,half_width+aa,abs(across));
	COLOR = vec4(strand_color.rgb,strand_color.a*coverage)*inherited_tint;
}
