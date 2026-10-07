shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/organic_motion.gdshaderinc"
#include "res://shaders/water_interaction.gdshaderinc"
#include "res://shaders/pond_optics.gdshaderinc"
uniform float clock = 0.0;
uniform float motion = 1.0;
uniform float detail = 2.0;
uniform float dish = 0.0;
uniform vec3 water_grade = vec3(1.0);
uniform vec3 water_base = vec3(0.075, 0.137, 0.181);
uniform float plate_turn = 0.0;
uniform float plate_scale = 1.0;
uniform vec2 plate_offset = vec2(0.0);
uniform vec2 light_direction = vec2(-0.65, -1.0);
uniform float sediment = 1.0;
uniform vec4 impulses[4]; // world x/y, age, strength
uniform sampler2D pond_plate : source_color, filter_linear_mipmap, repeat_disable;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = UV * vec2(1280.0, 900.0);
	vec2 q = (px - vec2(640.0, 450.0)) / 392.0;
	float r = length(q);
	// Settled material is almost stationary. Independent suspended organisms
	// supply the living motion; only slight optical refraction moves this plate.
	vec2 base_uv = q*0.45+vec2(0.5);
	base_uv = mat2(vec2(cos(plate_turn),sin(plate_turn)),vec2(-sin(plate_turn),cos(plate_turn))) * (base_uv-vec2(0.5)) * plate_scale + vec2(0.5) + plate_offset;
	float t = clock * motion;
	vec2 flow = vec2(sin(t * 0.024) * 0.0015, (cos(t * 0.021 + 1.3) - cos(1.3)) * 0.0012);
	vec2 shear = vec2(sin(base_uv.y * 7.0 + t * 0.055), cos(base_uv.x * 8.0 - t * 0.048)) * 0.0012;
	vec2 uv = base_uv + (flow + shear * (detail > 0.5 ? 1.0 : 0.35)) * motion;
	// Texture coordinates backtrace; particles move forward through this field.
	uv += (water_displacement(px)-transported_water(px)*2.0)/vec2(1176.0,784.0)*0.48*motion;
	// Captures displace the water optically. These are soft travelling pressure
	// fronts in the sediment, never luminous rings drawn over the organisms.
	for (int i=0;i<4;i++) {
		if (impulses[i].w>0.001) {
			vec2 delta = px-impulses[i].xy;
			float distance = length(delta);
			float front = (distance-18.0-impulses[i].z*34.0)/22.0;
			float pressure = exp(-front*front)*sin(front*2.2);
			uv += delta/max(distance,1.0)*pressure*0.0032*impulses[i].w*motion;
		}
	}
	// A shallow focal offset keeps sediment behind the playable tissue.
	vec3 plate = textureLod(pond_plate, uv, 1.2).rgb;
	if (detail > 0.5) {
		// Compress local contrast rather than burying dark outlines in black.
		vec3 soft = textureLod(pond_plate, uv + vec2(0.0018,0.0012), 3.3).rgb * 0.5;
		soft += textureLod(pond_plate, uv - vec2(0.0018,0.0012), 3.3).rgb * 0.5;
		plate = mix(soft,plate,0.52);
	}
	if (detail > 1.5) {
		// The deepest focal plane is optional; interactive tissue is always full detail.
		vec2 deep_uv = vec2(0.81 - base_uv.y * 0.62, 0.16 + base_uv.x * 0.62);
		deep_uv += vec2(-sin(t * 0.019) * 0.002, sin(t * 0.023 + 0.7) * 0.0016) * motion;
		vec3 deep = textureLod(pond_plate, deep_uv, 4.0).rgb * 0.34;
		deep += textureLod(pond_plate, deep_uv + vec2(0.018, 0.013), 4.0).rgb * 0.33;
		deep += textureLod(pond_plate, deep_uv - vec2(0.018, 0.013), 4.0).rgb * 0.33;
		plate = mix(deep, plate, 0.90);
	}
	float luma = dot(plate, vec3(0.2126, 0.7152, 0.0722));
	// Preserve the real specimen optics, graded into the game's dark blue water.
	vec3 optical = mix(vec3(luma), plate, 0.86);
	float plate_exposure = dish>1.5 ? 1.5 : 1.0;
	// Lift the water's middle values substantially. A dark floor underneath
	// bright photographic tissue makes the living cells read as separate cutouts.
	vec3 water = water_base*0.88+vec3(0.040,0.055,0.065)+optical*vec3(0.24,0.27,0.29)*sediment*plate_exposure;
	water = max(water, vec3(0.018, 0.035, 0.052));
	// Slightly quieter behind the focal mother, with natural optical falloff.
	water = mix(water, water_base*1.08+vec3(0.040,0.055,0.065), (1.0 - smoothstep(0.08, 0.30, r)) * 0.24);
	water *= 1.0 - smoothstep(0.68, 1.04, r) * 0.21;
	water *= pond_illumination(px,t,light_direction);
	float lens_edge = exp(-pow((r - 0.997) * 210.0, 2.0));
	float reflection = max(0.0, dot(normalize(q + vec2(0.0001)), normalize(light_direction)));
	water += vec3(0.06, 0.10, 0.12) * lens_edge * reflection;
	if (dish > 1.5) { water *= vec3(0.90,0.92,1.0); }
	water *= water_grade;
	vec3 outside = vec3(0.011, 0.022, 0.028);
	vec3 color = mix(water, outside, smoothstep(1.005, 1.035, r));
	color += (hash(floor(px * 1.4)) - 0.5) * 0.002;
	COLOR = vec4(color, 1.0);
}
