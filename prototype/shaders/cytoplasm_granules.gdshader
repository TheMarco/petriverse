shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
uniform float motion = 1.0;
uniform float phase = 0.0;
uniform float energy = 1.0;
uniform float feeding = 0.0;
uniform float kind = 0.0;
uniform float granule_count = 9.0;
uniform float texture_extent = 1254.0;
uniform float display_extent = 63.0;
varying vec2 grain_point;
varying float trail_length;
varying vec4 grain_color;
varying vec4 inherited_tint;

vec2 position_at(float index, float time) {
	float a = index*2.399+phase;
	float radius = 0.11+0.18*sqrt((index+1.0)/(granule_count+1.0));
	vec2 p = vec2(cos(a),sin(a))*radius;
	p += vec2(sin(time*0.31+a*1.3),cos(time*0.27+a*0.7))*0.032*motion;
	p += vec2(sin(time*0.53+p.y*9.0+a),cos(time*0.43-p.x*11.0+a))*0.012*motion;
	if (kind==2.0 || kind==4.0) { p.y *= 0.38; }
	return p;
}

void vertex() {
	float index = INSTANCE_CUSTOM.x;
	float t = clock*motion*(0.91+0.09*sin(phase*1.71))+phase;
	float vigor = mix(0.24,1.0,energy);
	vec2 head = position_at(index,t*vigor)*texture_extent;
	vec2 tail = position_at(index,(t-0.55*motion)*vigor)*texture_extent;
	vec2 delta = tail-head;
	trail_length = length(delta);
	vec2 along = trail_length>0.0001 ? delta/trail_length : vec2(1.0,0.0);
	float radius = max(texture_extent*0.003,texture_extent/display_extent*0.55);
	float edge = radius+texture_extent/display_extent*0.8;
	grain_point = vec2(UV.x*(trail_length+2.0*edge)-edge,(UV.y-0.5)*2.0*edge);
	VERTEX = head+along*grain_point.x+vec2(-along.y,along.x)*grain_point.y;
	float sparkle = 0.5+0.5*sin(t*0.64+index*2.1);
	grain_color = vec4(0.72,0.89,0.86,(0.16+sparkle*0.12)*energy);
	if (kind==1.0 && mod(index,3.0)==0.0) {
		grain_color = vec4(1.0,0.81,0.40,(0.18+feeding*0.35)*energy);
	}
	inherited_tint = COLOR;
}

void fragment() {
	float pixel = texture_extent/display_extent;
	float radius = max(texture_extent*0.003,pixel*0.55);
	float aa = max(fwidth(length(grain_point))*0.65,pixel*0.20);
	float bead = 1.0-smoothstep(radius-aa,radius+aa,length(grain_point));
	float width = max(texture_extent*0.0010,pixel*0.56)*0.30;
	vec2 nearest = vec2(clamp(grain_point.x,0.0,trail_length),0.0);
	float trail = 1.0-smoothstep(max(0.0,width-aa),width+aa,length(grain_point-nearest));
	float head_alpha = bead*grain_color.a;
	float tail_alpha = trail*0.08*energy*(1.0-head_alpha);
	float opacity = head_alpha+tail_alpha;
	vec3 pigment = (grain_color.rgb*head_alpha+vec3(0.72,0.89,0.86)*tail_alpha)/max(opacity,0.0001);
	COLOR = vec4(pigment,opacity)*inherited_tint;
}
