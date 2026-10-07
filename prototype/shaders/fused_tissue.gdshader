shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/organic_motion.gdshaderinc"
#include "res://shaders/pond_optics.gdshaderinc"

uniform sampler2D tissue_texture : filter_linear_mipmap, repeat_disable;
uniform vec2 bounds_size = vec2(128.0);
uniform vec2 members[10];
uniform int member_count = 3;
uniform float fusion = 0.0;
uniform float opacity = 0.0;
uniform float clock = 0.0;
uniform float feeding = 0.0;
uniform float mastery = 0.0;
uniform vec3 colony_grade = vec3(1.0);
uniform vec3 water_base = vec3(0.055,0.115,0.150);
uniform vec2 light_direction = vec2(-0.65,-1.0);
varying vec2 water_position;

void vertex() {
	water_position = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 n = sin(vec4(dot(i, vec2(127.1, 311.7)), dot(i + vec2(1, 0), vec2(127.1, 311.7)), dot(i + vec2(0, 1), vec2(127.1, 311.7)), dot(i + vec2(1, 1), vec2(127.1, 311.7)))) * 43758.5453;
	n = fract(n);
	return mix(mix(n.x, n.y, f.x), mix(n.z, n.w, f.x), f.y);
}

float joined(float a, float b, float softness) {
	float h = max(softness - abs(a - b), 0.0) / softness;
	return min(a, b) - h * h * softness * 0.25;
}

void fragment() {
	vec2 p = UV * bounds_size;
	float radius = mix(24.0, 19.0 * sqrt(float(member_count)), fusion);
	radius *= 1.0+organic_beat(clock*1.8)*0.022*fusion;
	float distance_to_body = 10000.0;
	float nearest = 10000.0;
	for (int i = 0; i < member_count; i++) {
		float d = length(p - members[i]);
		nearest = min(nearest, d);
		distance_to_body = joined(distance_to_body, d - radius, 12.0 + fusion * 8.0);
	}
	// Blend the cytoplasm's coordinates too: internal cell membranes must not
	// survive inside the union. Once joined this samples one continuous body.
	vec2 tissue_center = vec2(0.0);
	float total = 0.0;
	for (int i = 0; i < member_count; i++) {
		float w = exp(-(length(p - members[i]) - nearest) / mix(8.0, 80.0, fusion));
		tissue_center += members[i] * w;
		total += w;
	}
	tissue_center /= total;
	vec2 q = (p - tissue_center) / (radius + 5.0);
	float angle = atan(q.y, q.x);
	float ripple = (noise(p*0.10+vec2(clock*0.12,-clock*0.08))-0.5)*1.7;
	ripple += sin(angle*3.0-clock*1.2+sin(clock*0.39))*1.15*fusion;
	float d = distance_to_body + ripple;
	vec2 flow = organic_current(q,clock)*0.034;
	flow += vec2(-q.y,q.x)*sin(clock*0.71+length(q)*4.0)*0.013;
	vec4 tissue = texture(tissue_texture, vec2(0.5) + q * 0.31 + flow);
	float grain = noise(p * 0.65 + vec2(clock * 0.12, clock * 0.09));
	float membrane = exp(-abs(d + 1.0) * 0.65);
	float inner_rim = exp(-abs(d + 4.0) * 0.48);
	float core = 1.0 - smoothstep(0.1, 0.95, length(q));
	vec3 color = tissue.rgb * vec3(0.76, 0.94, 1.04);
	color += vec3(0.045, 0.095, 0.12) * grain;
	float grazing = 0.55+0.45*max(0.0,dot(normalize(q+vec2(0.001)),normalize(vec2(-0.7,-1.0))));
	color += vec3(0.48,0.76,0.83)*membrane*(0.65+grain*0.35)*grazing;
	color += vec3(0.08, 0.20, 0.24) * inner_rim;
	float folds = exp(-abs(d+7.0+sin(angle*9.0-clock*0.53)*1.2)*0.55);
	color += vec3(0.08,0.15,0.18)*folds*fusion;
	color += vec3(0.38, 0.22, 0.04) * feeding * core * (0.4 + grain * 0.6);
	// An exceptional capture warms the membrane from within, without confetti.
	float pearl = exp(-abs(d+5.0+sin(angle*3.0-clock)*2.0)*0.36);
	color += vec3(0.18,0.22,0.10)*pearl*mastery*feeding;
	float coverage = 1.0 - smoothstep(-0.5, 1.4, d);
	color *= mix(vec3(1.0), colony_grade, smoothstep(0.0, 0.12, color.b-color.r));
	color = pond_focal_tone(color,water_base,0.16)*pond_illumination(water_position,clock,light_direction);
	COLOR = vec4(color, coverage * opacity * (0.86 + membrane * 0.14));
}
