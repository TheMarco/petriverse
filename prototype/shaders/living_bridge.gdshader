shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tissue_texture : filter_linear_mipmap, repeat_disable;
uniform vec2 bounds_size = vec2(180.0, 100.0);
uniform vec2 first = vec2(40.0, 50.0);
uniform vec2 second = vec2(140.0, 50.0);
uniform float width = 7.0;
uniform float clock = 0.0;
uniform float motion = 1.0;
uniform float boss = 0.0;
uniform float pulse = 0.0;

void fragment() {
	vec2 p = UV * bounds_size;
	vec2 axis = second - first;
	float extent = max(length(axis), 0.001);
	vec2 forward = axis / extent;
	vec2 side = vec2(-forward.y, forward.x);
	float along = dot(p - first, forward) / extent;
	float across = dot(p - first, side);
	float curve = sin(clamp(along, 0.0, 1.0) * PI) * sin(clock * 0.8) * 2.0 * motion;
	float neck = width * (0.72 + 0.48 * pow(abs(along - 0.5) * 2.0, 2.0));
	neck += sin(along * 18.0 - clock * 1.1) * 0.65 * motion;
	float distance_to_skin = abs(across - curve) - neck;
	float skin = exp(-abs(distance_to_skin) * 1.2);
	float inner_skin = exp(-abs(distance_to_skin + 2.2) * 1.1);
	vec2 tissue_uv = vec2(0.25 + along * 0.16, 0.3 + (across - curve) * 0.003);
	vec3 tissue = texture(tissue_texture, tissue_uv).rgb;
	vec3 color = tissue * mix(vec3(0.64, 0.83, 0.95), vec3(0.72, 0.69, 1.0), boss);
	color += vec3(0.46, 0.69, 0.8) * skin * 0.64 + vec3(0.14, 0.19, 0.23) * inner_skin;
	float flow = pow(0.5 + 0.5 * sin(along * 27.0 - clock * 1.7), 18.0);
	color += vec3(0.32, 0.20, 0.05) * flow * exp(-abs(across - curve) * 0.7) * motion;
	color += vec3(0.1, 0.14, 0.17) * pulse;
	float alpha = (1.0 - smoothstep(-0.4, 1.0, distance_to_skin)) * step(0.0, along) * step(along, 1.0);
	COLOR = vec4(color, alpha * 0.86);
}
