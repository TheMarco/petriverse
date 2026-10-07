uniform vec4 currents[4]; // world center, radial displacement, curl displacement
uniform vec4 strokes[6]; // world-space segment endpoints
uniform float stroke_strengths[6];
uniform sampler2D fluid_map : filter_linear, repeat_disable;
uniform bool fluid_enabled = false;

vec2 transported_water(vec2 at) {
	if (!fluid_enabled) { return vec2(0.0); }
	// Half-texel inset matches the CPU grid's bilinear world-space sampling.
	vec2 grid = clamp((at-vec2(248.0,58.0))/784.0,vec2(0.0),vec2(1.0));
	vec2 uv = (grid*27.0+vec2(0.5))/28.0;
	return (textureLod(fluid_map,uv,0.0).rg-vec2(0.5))*192.0;
}

vec2 water_displacement(vec2 at) {
	vec2 offset = vec2(0.0);
	for (int i=0; i<4; i++) {
		vec2 delta = at-currents[i].xy;
		float distance = length(delta);
		vec2 radial = delta/max(distance,1.0);
		float envelope = exp(-distance*distance/14400.0)*min(distance/24.0,1.0);
		offset += (radial*currents[i].z+vec2(radial.y,-radial.x)*currents[i].w)*envelope;
	}
	for (int i=0; i<6; i++) {
		if (stroke_strengths[i]>0.0) {
			vec2 segment = strokes[i].zw-strokes[i].xy;
			float fraction = clamp(dot(at-strokes[i].xy,segment)/max(dot(segment,segment),1.0),0.0,1.0);
			vec2 delta = at-strokes[i].xy-segment*fraction;
			float envelope = exp(-dot(delta,delta)/900.0)*stroke_strengths[i];
			offset += (delta/max(length(delta),4.0)*7.0+segment/max(length(segment),1.0)*2.0)*envelope;
		}
	}
	return offset*min(1.0,28.0/max(length(offset),0.001))+transported_water(at);
}
