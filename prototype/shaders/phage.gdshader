shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float phase = 0.0;
uniform float motion = 1.0;
uniform float contraction = 0.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec2 uv = UV;
	// The rigid head descends as the sheath contracts toward its baseplate.
	float shift = contraction*0.085;
	float head_end = 0.36+shift;
	if (uv.y<head_end) uv.y -= shift;
	else if (uv.y<0.69) uv.y = mix(0.36,0.69,(uv.y-head_end)/(0.69-head_end));
	// Independent soft leg flexion fixes the roots at the baseplate. Landing
	// settles the fibres; the capsid never squashes like cellular tissue.
	float legs = smoothstep(0.62,0.83,UV.y);
	float side = sign(UV.x-0.5);
	float time = clock*motion;
	uv.x += side*sin(time*1.1+phase+UV.y*16.0+side)*0.020*legs*(1.0-contraction)*motion;
	uv.y += sin(time*0.8+phase+UV.x*12.0)*0.008*legs*(1.0-contraction)*motion;
	vec4 tissue = texture(TEXTURE,uv);
	// Suppress the source's diffuse optical haze, preserving the fine fibres.
	tissue.a *= smoothstep(0.05,0.28,tissue.a);
	vec3 color = mix(tissue.rgb,tissue.rgb*vec3(0.80,0.93,1.0),0.40);
	COLOR = vec4(color,tissue.a)*tint;
}
