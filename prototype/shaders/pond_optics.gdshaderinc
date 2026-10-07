// One broad transmitted light field across sediment, suspended life and cells.
// All motion uses the host's pausable presentation clock.
float pond_illumination(vec2 point, float time, vec2 direction) {
	vec2 q = (point-vec2(640.0,450.0))/392.0;
	float directional = dot(q,normalize(direction))*0.025;
	float drifting = sin(q.x*2.1+q.y*1.3+time*0.085+sin(q.y*3.0-time*0.06)*0.7);
	return 1.0+directional+drifting*0.014;
}

vec3 pond_focal_tone(vec3 color, vec3 medium, float immersion) {
	// Roll off the foreground's near-white highlights instead of leaving a neon
	// rim against the water. Zero immersion preserves standalone specimen art.
	vec3 transmitted = color/(vec3(1.0)+max(color-vec3(0.16),vec3(0.0))*immersion*1.65);
	return mix(transmitted,medium+vec3(0.040,0.055,0.065),immersion);
}
