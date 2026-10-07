shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/pond_optics.gdshaderinc"
uniform float clock = 0.0;
uniform float motion = 1.0;
uniform float phase = 0.0;
uniform float kind = 0.0;
uniform float blur = 0.004;
uniform float opacity = 0.35;
uniform vec3 water_grade = vec3(1.0);
uniform vec3 water_base = vec3(0.055,0.115,0.150);
uniform vec2 light_direction = vec2(-0.65,-1.0);
uniform float depth = 0.5;
uniform sampler2D pond_water : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 frame_origin = vec2(0.0);
varying vec2 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// UV refers to the whole 2x2 atlas; all deformation stays in this frame.
	vec2 p = (UV - frame_origin) * 2.0 - vec2(0.5);
	float t = clock * motion;
	vec2 uv = UV;
	if (kind > 0.5 && kind < 1.5) {
		// A travelling contraction along the ciliate's diagonal body axis.
		float along = dot(p,vec2(0.707,-0.707));
		float stroke = sin(t*2.3+along*10.0+phase);
		uv += (p*stroke*0.023+vec2(0.707,0.707)*sin(along*9.0-t*1.7+phase)*abs(along)*0.028)*motion;
	} else if (kind > 2.5) {
		// Amoebae creep by extending unequal lobes around circulating cytoplasm.
		float angle = atan(p.y,p.x);
		float lobe = sin(angle*3.0-t*0.55+phase)*0.044+sin(angle*5.0+t*0.31+phase*1.7)*0.021;
		uv += (p*lobe+vec2(-p.y,p.x)*sin(t*0.46+length(p)*11.0+phase)*0.016)*motion;
	}
	uv = clamp(uv,frame_origin+vec2(0.006),frame_origin+vec2(0.494));
	vec4 c = texture(TEXTURE, uv);
	vec4 tissue = vec4(c.rgb * c.a, c.a) * 0.44;
	for (int i = 0; i < 4; i++) {
		float angle = float(i) * TAU / 4.0 + 0.4;
		c = texture(TEXTURE, clamp(uv + vec2(cos(angle), sin(angle)) * blur,frame_origin+vec2(0.006),frame_origin+vec2(0.494)));
		tissue += vec4(c.rgb * c.a, c.a) * 0.14;
	}
	vec3 color = tissue.rgb / max(tissue.a, 0.001);
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	vec3 optical = mix(vec3(luma),color,0.52);
	float radius = length(world_point - vec2(640.0, 450.0));
	float dish = 1.0 - smoothstep(350.0, 389.0, radius);
	float calm_center = mix(0.20, 1.0, smoothstep(55.0, 132.0, radius));
	float focus = mix(1.0,0.72,depth);
	// Refract the actual water behind the specimen. This ties its transparent
	// tissue to the local sediment and illumination instead of pasting on a cutout.
	vec3 behind = textureLod(pond_water,SCREEN_UV+p*0.00055*(1.0-depth),depth*1.4).rgb;
	// A visible middle focal plane: photographic tissue detail survives, while
	// actual local water shows through it. Avoid double attenuation into darkness.
	vec3 lit_tissue = mix(behind,vec3(0.32,0.46,0.50)*water_grade,0.65);
	lit_tissue += (optical-vec3(0.48))*vec3(0.36,0.38,0.40);
	lit_tissue *= pond_illumination(world_point,t,light_direction);
	color = mix(behind,max(lit_tissue,behind*0.72),0.93-depth*0.24);
	COLOR = vec4(color, tissue.a * opacity * dish * calm_center * focus);
}
