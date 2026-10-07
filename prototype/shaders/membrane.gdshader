shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/organic_motion.gdshaderinc"
uniform float clock = 0.0;
uniform float strength = 0.14;
uniform float motion = 1.0;
uniform float poison = 0.0;
varying vec2 point;
void vertex() {
	point = VERTEX;
}
void fragment() {
	float t = clock * motion;
	vec2 p = point*0.025;
	p += organic_current(p*0.24,t)*0.16*motion;
	float fold = sin(p.x * 1.3 + p.y * 0.7 + sin(p.y * 1.6 + t * 0.45)) * 0.5 + 0.5;
	float fiber = pow(0.5 + 0.5 * sin((p.x + p.y) * 5.0 + sin(p.y * 2.0 + t) * 1.4), 14.0);
	vec3 hue = mix(vec3(0.28, 0.61, 0.72), vec3(0.70, 0.79, 0.60), fold);
	hue = mix(hue, vec3(0.87, 0.36, 0.53), poison * 0.78);
	float sheen = pow(0.5+0.5*sin(p.x*0.6-p.y*0.4+t*0.25),12.0);
	COLOR = vec4(hue+fiber*0.12+vec3(0.10,0.16,0.17)*sheen,strength*(0.32+fold*0.4+fiber*0.20+sheen*0.08));
}
