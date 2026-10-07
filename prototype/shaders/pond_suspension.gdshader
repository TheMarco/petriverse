shader_type canvas_item;
render_mode unshaded, skip_vertex_transform;
#include "res://shaders/water_interaction.gdshaderinc"
#include "res://shaders/pond_optics.gdshaderinc"
uniform float clock = 0.0;
uniform float motion = 1.0;
uniform float biome = 0.0;
uniform vec3 water_grade = vec3(1.0);
uniform vec3 water_base = vec3(0.055,0.115,0.150);
uniform vec2 light_direction = vec2(-0.65,-1.0);
varying vec4 tint;
varying vec2 world_point;
varying float kind;
varying float phase;
varying float depth;

void vertex() {
	tint = COLOR;
	phase = INSTANCE_CUSTOM.x * TAU;
	depth = INSTANCE_CUSTOM.y;
	kind = INSTANCE_CUSTOM.z;
	float t = clock * motion;
	// Gently tumble without rebuilding any instance transforms on the CPU.
	float turn = (sin(t*0.13+phase)*0.20+sin(t*0.083+phase*1.7)*0.12)*motion;
	vec2 local = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * VERTEX;
	VERTEX = (MODEL_MATRIX * vec4(local, 0.0, 1.0)).xy;
	float speed = 0.085 + INSTANCE_CUSTOM.w * 0.075;
	vec2 flow = vec2(sin(t * speed + phase), cos(t * speed * 0.76 + phase * 1.3)) * (18.0 + depth * 39.0);
	flow += vec2(sin(t * 0.24 + phase * 1.7), cos(t * 0.21 + phase)) * 3.0;
	if (kind > 1.5 && kind < 2.5) {
		flow += vec2(sin(t * 0.22 + phase), cos(t * 0.17 + phase)) * 18.0;
	}
	if (biome>0.5 && biome<1.5) {
		flow += vec2(sin(t*0.035)*8.0,cos(t*0.031)*3.0);
	} else if (biome>1.5) {
		flow += vec2(sin(t*0.022)*3.0,sin(t*0.029)*9.0);
	}
	// Brownian wandering is small; most debris travels with the shared water.
	flow *= fluid_enabled ? 0.24 : 1.0;
	VERTEX += flow * motion;
	// Advect the whole specimen at its center; never stretch particle quads.
	vec2 center = (MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xy+flow*motion;
	VERTEX += water_displacement(center)*motion*(1.05+depth*0.80);
	world_point = VERTEX;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float t = clock * motion;
	float alpha = 0.0;
	float refracted = 0.0;
	if (kind < 0.5) {
		float speck = exp(-dot(p, p) * (28.0 + depth * 16.0));
		float halo = exp(-pow((length(p + vec2(0.065, 0.045)) - 0.27) * 12.0, 2.0));
		alpha = max(speck, halo * 0.40);
		refracted = halo * (1.0 - speck) * 0.55;
	} else if (kind < 1.5) {
		alpha = 1.0 - smoothstep(0.25, 0.45, length(p * vec2(0.75, 1.8)));
		refracted = smoothstep(-0.12, 0.12, -p.y) * 0.6;
	} else if (kind < 2.5) {
		float d = length(p * vec2(0.86, 1.24));
		float rim = exp(-abs(d - 0.32) * 28.0);
		float inside = 1.0 - smoothstep(0.27, 0.43, d);
		float nucleus = exp(-length(p - vec2(0.11, 0.0)) * 17.0);
		alpha = inside * 0.28 + rim * 0.50 + nucleus * 0.30;
		refracted = rim * smoothstep(-0.25, 0.25, -p.x - p.y) * 0.65;
	} else if (kind < 3.5) {
		float angle = atan(p.y, p.x);
		float d = length(p) + sin(angle * 3.0 + phase) * 0.065;
		alpha = (1.0 - smoothstep(0.16, 0.43, d)) * (0.65 + sin(p.x * 21.0 + p.y * 17.0) * 0.25);
	} else {
		float curve = sin(p.x * 5.0 + phase + t * 0.13) * 0.17;
		alpha = exp(-abs(p.y - curve) * 58.0) * (1.0 - smoothstep(0.30, 0.48, abs(p.x)));
	}
	float r = length(world_point - vec2(640.0, 450.0));
	float dish = 1.0 - smoothstep(354.0, 389.0, r);
	float calm_center = mix(0.32, 1.0, smoothstep(57.0, 123.0, r));
	vec3 color = mix(tint.rgb, vec3(0.31, 0.42, 0.48), refracted);
	color = water_base+vec3(0.13,0.16,0.18)+(color-vec3(0.14))*0.55;
	color *= pond_illumination(world_point,t,light_direction);
	COLOR = vec4(color * water_grade, tint.a * alpha * dish * calm_center * 0.75);
}
