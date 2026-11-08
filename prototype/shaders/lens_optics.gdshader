shader_type canvas_item;
render_mode unshaded;
// Final optical pass for the dish: objective-lens aberration, field-curvature
// softness at the rim, a restrained bloom on bright tissue, and the focus pull
// used behind dialogs. Interface layers draw above this pass and stay crisp.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec2 lens_center = vec2(640.0, 450.0); // logical pixels
uniform float lens_radius = 392.0;             // logical pixels
uniform vec2 canvas_size = vec2(1280.0, 900.0);    // logical size of this rect
uniform vec2 uv_per_logical = vec2(0.00078125, 0.00111111); // screen UV per logical pixel
uniform float aberration = 1.0;  // 0 disables lateral color
uniform float bloom = 1.0;       // 0 disables glow
uniform float softness = 1.0;    // rim field curvature
uniform float defocus = 0.0;     // 0 sharp, 1 fully defocused (dialogs, transitions)
uniform float grain = 1.0;
uniform float clock = 0.0;
uniform float saturation = 1.0; // loss drains color from the dish
uniform float exposure = 1.0;
uniform float lod_bias = 0.0; // log2(physical / logical pixels): blur is resolution independent

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Geometry uses this rect's own logical coordinates, so letterboxing and
	// high-DPI windows keep the lens exactly over the dish.
	vec2 px = UV * canvas_size;
	vec2 offset = px - lens_center;
	float r = length(offset) / lens_radius;
	vec2 radial = offset / max(length(offset), 1.0);
	// Lateral color grows toward the rim, as in a simple achromatic objective.
	float spread = aberration * smoothstep(0.62, 1.03, r) * 1.8;
	vec2 shift = radial * spread * uv_per_logical;
	// Playable cells reach r = 0.97; only the outermost band softens.
	float blur = softness * smoothstep(0.93, 1.04, r) * 1.3 + defocus * 3.2;
	float lod = blur > 0.001 ? blur + lod_bias : 0.0;
	vec3 color;
	color.r = textureLod(screen_texture, uv - shift, lod * 0.85).r;
	color.g = textureLod(screen_texture, uv, lod * 0.85).g;
	color.b = textureLod(screen_texture, uv + shift, lod * 0.85).b;
	if (defocus > 0.01) {
		// Mip blur alone is blocky; four rotated taps hide the texel grid.
		vec3 soft = vec3(0.0);
		float reach = defocus * 9.0;
		for (int i = 0; i < 4; i++) {
			float a = float(i) * 1.5708 + 0.39;
			soft += textureLod(screen_texture, uv + vec2(cos(a), sin(a)) * reach * uv_per_logical, lod).rgb;
		}
		color = mix(color, soft * 0.25, clamp(defocus * 1.4, 0.0, 1.0));
	}
	if (bloom > 0.0) {
		// Wide, low-threshold glow from coarse mips: organelles and food light
		// the water around them without washing the interface.
		vec3 wide = textureLod(screen_texture, uv, 3.5 + lod_bias).rgb * 0.55 + textureLod(screen_texture, uv, 5.0 + lod_bias).rgb * 0.45;
		float luma = dot(wide, vec3(0.2126, 0.7152, 0.0722));
		vec3 glow = wide * smoothstep(0.22, 0.66, luma);
		float inside = 1.0 - smoothstep(0.98, 1.06, r);
		color += glow * bloom * 0.24 * inside;
	}
	float grey = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(grey), color, saturation) * exposure;
	if (grain > 0.0) {
		float n = hash(floor(px * 1.5) + floor(clock * 24.0) * 17.0) - 0.5;
		color += n * grain * 0.012;
	}
	COLOR = vec4(color, 1.0);
}
