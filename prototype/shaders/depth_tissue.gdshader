shader_type canvas_item;
render_mode unshaded;
uniform float blur = 0.03;
uniform float clock = 0.0;
uniform float motion = 1.0;
uniform float phase = 0.0;
varying vec4 tint;
varying vec2 world_point;
void vertex() {
	tint = COLOR;
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec2 p = UV - vec2(0.5);
	vec2 uv = UV + p * sin(clock * 0.7 + phase) * 0.045 * motion;
	vec4 tissue = texture(TEXTURE, uv) * 0.20;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * TAU / 8.0;
		tissue += texture(TEXTURE, uv + vec2(cos(a), sin(a)) * blur) * 0.10;
	}
	float luma = dot(tissue.rgb, vec3(0.2, 0.7, 0.1));
	float mask = 1.0 - smoothstep(350.0, 388.0, length(world_point - vec2(640.0, 450.0)));
	COLOR = vec4(vec3(0.36, 0.65, 0.78) * luma, tissue.a * mask) * tint;
}
