// Smooth, bounded fields shared by living tissue and its fluid environment.
// Time is always supplied by the paused simulation/presentation clock.
float organic_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*f*(f*(f*6.0-15.0)+10.0);
	vec4 h = fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1,1),vec2(127.1,311.7))))*43758.5453);
	return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}

vec2 organic_current(vec2 p, float t) {
	// Curl of two stream functions: circulating pockets, with no expansion.
	vec2 a = p*3.1+vec2(t*0.19,-t*0.13);
	vec2 b = p*5.3+vec2(-t*0.11,t*0.17)+vec2(1.7,0.8);
	return vec2(sin(a.x)*cos(a.y),-cos(a.x)*sin(a.y))*0.68
		+vec2(sin(b.x)*cos(b.y),-cos(b.x)*sin(b.y))*0.32;
}

float organic_beat(float t) {
	// A short contraction followed by a longer soft relaxation.
	float wave = 0.5+0.5*sin(t);
	return wave*wave*wave-0.3125;
}
