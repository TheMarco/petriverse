shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/organic_motion.gdshaderinc"
#include "res://shaders/pond_optics.gdshaderinc"

uniform float clock = 0.0;
uniform float phase = 0.0;
uniform float motion = 1.0;
uniform float energy : hint_range(0.0, 1.0) = 1.0;
uniform float selected = 0.0;
uniform float warmth = 0.0;
uniform float kind = 0.0; // 0: friendly, 1: mother, 2: Drifter
uniform float feeding = 0.0;
uniform float shock = 0.0;
uniform vec2 threat_direction = vec2(0.0);
uniform float threat_strength = 0.0;
uniform float dissolve = 0.0;
uniform float infection = 0.0;
uniform float division = 0.0;
uniform float bell_breath = 0.0;
uniform float visitor_open = 1.0;
uniform float visitor_glow = 0.0;
uniform float arrival = 1.0; // Explicitly enabled only on live incoming organisms.
uniform vec3 colony_grade = vec3(1.0);
uniform vec3 water_base = vec3(0.055,0.115,0.150);
uniform vec2 light_direction = vec2(-0.65,-1.0);
uniform float water_immersion = 0.0;
uniform vec4 phenotype = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec2 core_sites[7];
uniform float core_radii[7];
uniform float core_damage[7];
uniform vec2 injury_sites[7];
uniform float injury_pulse[7];
uniform float injury_opening[7];
uniform float injury_seal[7];
uniform float invading_depth = 0.0;
uniform sampler2D host_texture : filter_linear_mipmap, repeat_disable;
uniform vec2 host_center = vec2(0.0);
uniform vec2 host_extent = vec2(120.0);
uniform float host_rotation = 0.0;
uniform float fatal_damage = 0.0;
uniform float mother_response = 0.0; // positive: triumph, negative: collapse
uniform float armor_damage = 0.0;
uniform float protection_layers = 0.0;
uniform float evolution_layers = 0.0;
uniform float nourishment = 0.0;
uniform vec2 nucleus_uv = vec2(0.5);
uniform vec4 adaptations = vec4(0.0); // filter veil, catalyst, symbiosis, nursery
uniform vec4 traits = vec4(0.0); // budding, digestive vacuoles, elastic rim, cilia
uniform vec4 evolution_form = vec4(0.0); // budding, folded, ribbed, maturity
uniform float evolution_organs[12];
uniform vec2 flow_velocity = vec2(0.0);
uniform float growth_front = 1.0;
uniform float growth_pulse = 0.0;
varying vec4 tint;
varying vec2 water_position;

vec2 organ_site(int index, bool mother) {
	float angle = float(index)*2.399963 + 0.32;
	float orbit = mother ? 0.335 : 0.225;
	orbit += sin(float(index)*1.73)*0.025;
	return vec2(0.5)+vec2(cos(angle),sin(angle))*orbit;
}

vec3 grown_organs(vec3 skin, vec3 detail, vec2 at, float time, float vitality, float protection) {
	for (int i=0; i<12; i++) {
		float growth = evolution_organs[i];
		if (growth>0.001) {
			vec2 site = organ_site(i,kind>0.5);
			vec2 q = at-site;
			float a = float(i)*2.399963+0.32;
			q = mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*q;
			vec2 size = vec2(0.069,0.085);
			if (i==3 || i==6) { size = vec2(0.096,0.114); }
			if (i==1 || i==4 || i==7 || i==10 || i==11) { size = vec2(0.037,0.124); }
			if (i==0 || i==9) { size = vec2(0.078,0.092); }
			// Mature feeding and nursery chambers become legible at dish scale.
			if (i==3 || i==6 || i==9) { size *= 1.0+evolution_form.w*0.30; }
			size *= mix(0.12,1.0,growth);
			q /= size;
			float angle = atan(q.y,q.x);
			float d = length(q)*(1.0+sin(angle*3.0+float(i))*0.065+sin(angle*7.0-time*0.25*motion)*0.025);
			float inside = 1.0-smoothstep(0.83,1.03,d);
			float rim = exp(-abs(d-0.89)*31.0);
			float fold = pow(0.5+0.5*sin(q.y*19.0+organic_noise(q*4.0+float(i))*3.0+time*0.6*motion),5.0);
			// Refracted photographic cytoplasm supplies real tissue detail beneath
			// the membrane, rather than flat colored circles.
			vec3 pigment = vec3(0.38,0.72,0.77);
			if (i==3 || i==6 || i==8) { pigment = vec3(0.65,0.43,0.22); }
			if (i==0 || i==9) { pigment = vec3(0.71,0.83,0.83); }
			if (i==2 || i==11) { pigment = vec3(0.43,0.53,0.77); }
			vec3 organ = mix(skin,detail,0.35)*(0.74+0.16*fold)+pigment*(0.045+0.10*fold);
			organ += pigment*rim*(0.42+0.23*max(0.0,-q.x-q.y));
			if (i==0 || i==9) {
				// Nested pale vesicles are distinct from the Mother's five gold cores.
				float pearls = exp(-length(q-vec2(-0.21,0.22))*12.0)+exp(-length(q-vec2(0.24,-0.23))*14.0);
				organ += vec3(0.32,0.49,0.53)*pearls;
			}
			if (i==2 || i==5 || i==7) { organ += pigment*fold*0.23; }
			if (i==8) { organ += pigment*pow(0.5+0.5*sin(q.x*42.0)*sin(q.y*37.0),6.0)*0.42; }
			skin = mix(skin,organ,inside*growth*protection*vitality*0.90);
		}
	}
	return skin;
}

void vertex() {
	// Extra transparent room for wide living membranes; the tissue and its
	// registered nuclei stay at their original world-space size and position.
	if (kind<1.5) { VERTEX *= 1.6; }
	water_position = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
	tint = COLOR;
}

void fragment() {
	vec2 body_uv = kind<1.5 ? (UV-vec2(0.5))*1.6+vec2(0.5) : UV;
	body_uv = nucleus_uv+(body_uv-nucleus_uv)*(1.0+bell_breath*0.18*smoothstep(0.06,0.3,length(body_uv-nucleus_uv)));
	vec2 visitor_delta = body_uv-nucleus_uv;
	// Fold the outer lace inward, keeping the actual pearl target registered.
	body_uv += visitor_delta*(1.0-visitor_open)*0.48*smoothstep(0.065,0.26,length(visitor_delta));
	vec2 p = body_uv - nucleus_uv;
	float radius = length(p);
	float theta = atan(p.y, p.x);
	float t = clock*(0.91+0.09*sin(phase*1.71)) + phase;
	float vigor = mix(0.24, 1.0, energy);
	float pinned_core = smoothstep(0.055, 0.18, radius);
	float health_pin = 1.0;
	if (kind>0.5 && kind<1.5) {
		for (int i=0; i<7; i++) {
			health_pin *= smoothstep(core_radii[i]+0.01,core_radii[i]+0.045,length(body_uv-core_sites[i]));
		}
	}
	vec2 displacement;
	if (kind > 7.5) {
		// A firm bacterial capsule with a flexing trailing flagellum.
		displacement = vec2(0.0,sin(p.x*19.0-t*3.0)*0.016*smoothstep(0.12,0.36,-p.x));
		displacement += p*sin(t*0.9)*0.007;
	} else if (kind > 6.5) {
		displacement = p * sin(t * 0.8 + theta * 7.0) * 0.012;
	} else if (kind > 5.5) {
		displacement = p * (sin(t * 1.1 + theta * 3.0) * 0.025 + sin(t * 0.6) * 0.015);
	} else if (kind > 4.5) {
		// The colony's pseudopods extend in slow, independent breaths.
		displacement = p * (sin(t * 0.65 + theta * 3.0) * 0.05 + sin(theta * 5.0 - t * 0.43) * 0.035);
		displacement += vec2(sin(p.y * 12.0 + t * 0.5), cos(p.x * 10.0 - t * 0.6)) * 0.012;
	} else if (kind > 3.5) {
		// Slender flagellated bodies flex along a traveling wave.
		displacement = vec2(p.x * sin(t * 2.4) * 0.025, sin(p.x * 10.0 - t * 3.2) * abs(p.x) * 0.05);
	} else if (kind > 2.5) {
		// The faceted carapace stays firm; only its living hinges breathe.
		displacement = p * (sin(t * 0.9) * 0.012 + sin(theta * 6.0 + t * 0.6) * 0.008);
	} else if (kind > 1.5) {
		// A stroke passes from head to tail. The capture nucleus stays fixed.
		float stroke = sin(t * 4.8 - p.x * 11.0);
		displacement = vec2(p.x * stroke * 0.075, p.y * -stroke * 0.11);
		displacement.y += sin(p.x * 10.0 - t * 4.8) * abs(p.x) * 0.065;
		// Higher-frequency motion bends the cilia already present in the art.
		displacement += vec2(sin(theta * 22.0 - t * 10.0), cos(theta * 19.0 - t * 10.0)) * 0.006 * smoothstep(0.16, 0.37, radius);
	} else {
		float breath = organic_beat(t*1.38)*0.053 + sin(t*0.49+1.3)*0.011;
		float lobe = sin(theta*3.0-t*0.72+sin(t*0.31))*0.024 + sin(theta*5.0+t*0.39)*0.009;
		float squeeze = sin(t*0.64+theta)*0.015;
		displacement = p * (breath + lobe - feeding * 0.045 + shock * 0.055);
		displacement += vec2(p.x, -p.y) * squeeze;
	}
	// Cytoplasm circulates under the membrane, with a quiet anchored nucleus.
	float interior = 1.0 - smoothstep(0.25, 0.43, radius);
	displacement += organic_current(p*2.0+vec2(phase),t)*0.016*interior;
	displacement += vec2(-p.y,p.x)*sin(t*0.57+radius*10.0)*0.025*interior;
	// The skin yields to its own velocity, without moving the capture nucleus.
	float flow_speed = min(length(flow_velocity),1.0);
	vec2 flow_axis = flow_velocity/max(length(flow_velocity),0.001);
	displacement += (p-2.0*flow_axis*dot(p,flow_axis))*flow_speed*0.027;
	if (kind > 0.5 && kind < 1.5) {
		// Keep the five organelles registered to the invading mouth and wound.
		float facing = smoothstep(-0.35,0.8,dot(p/max(radius,0.001),threat_direction));
		float brace = 0.8+0.2*organic_beat(t*(1.5+threat_strength));
		displacement -= threat_direction*facing*0.065*threat_strength*brace;
		float organelle_pin = 1.0;
		for (int i = 0; i < 7; i++) {
			organelle_pin *= smoothstep(core_radii[i], core_radii[i] + 0.035, length(body_uv - core_sites[i]));
			vec2 wound_delta = body_uv-injury_sites[i];
			// Local tension pulls the surrounding skin inward as a core is eaten.
			displacement += wound_delta*exp(-dot(wound_delta,wound_delta)*46.0)*injury_pulse[i]*0.09;
			vec2 inward = normalize(core_sites[i]-injury_sites[i]+vec2(0.0001));
			displacement -= inward*exp(-dot(wound_delta,wound_delta)*100.0)*injury_opening[i]*0.045;
		}
		displacement *= organelle_pin;
	}
	vec2 uv = body_uv + displacement * pinned_core * motion * vigor;
	if (kind<1.5) {
		float budding = (0.08+cos(theta*3.0+0.5)*0.15)*evolution_form.x;
		float folded = (0.135+cos(theta*5.0-0.2)*0.045)*evolution_form.y;
		float ribbed = (0.03+cos(theta*2.0)*0.16+cos(theta*6.0)*0.045)*evolution_form.z;
		uv -= p*clamp(budding+folded+ribbed+evolution_form.w*0.02,-0.22,0.34)*pinned_core*health_pin;
	}
	if (kind < 0.5) {
		// Seeded oval / fluted / scalloped membranes retain the exact nucleus.
		uv += p * (phenotype.xy - vec2(1.0)) * pinned_core;
		uv += p * sin(theta * phenotype.z + phase) * phenotype.w * pinned_core;
	}
	uv.y += p.y * exp(-abs(p.x) * 16.0) * division * 1.6 * motion * smoothstep(0.05, 0.1, radius);
	// Tissue rises through the focal plane and unfurls from its registered
	// nucleus. Keep its colored silhouette visible even at birth: a forming
	// cyst is still poison, and the logical capture center never moves.
	float born = smoothstep(0.0, 1.0, arrival);
	float unfurl = smoothstep(0.10, 0.88, arrival);
	float fold = (1.0 - unfurl) * motion * pinned_core;
	uv = nucleus_uv + (uv - nucleus_uv) * (1.0 + fold * (0.30 + 0.10 * sin(theta * 3.0 + phase)));
	uv += organic_current(p*2.0,phase+born*2.0)*fold*0.022;
	vec4 tissue = texture(TEXTURE, uv);
	if (arrival < 1.0 && motion > 0.0) {
		float blur = (1.0 - born) * 0.026 * pinned_core;
		vec4 soft_tissue = (texture(TEXTURE, uv + vec2(blur, 0.0)) + texture(TEXTURE, uv - vec2(blur, 0.0)) + texture(TEXTURE, uv + vec2(0.0, blur)) + texture(TEXTURE, uv - vec2(0.0, blur))) * 0.25;
		tissue = mix(tissue, soft_tissue, (1.0 - born) * pinned_core * 0.85);
	}
	float luminance = dot(tissue.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 dormant = vec3(luminance) * vec3(0.36, 0.49, 0.58);
	vec3 alive = tissue.rgb * vec3(0.87 + warmth * 0.15, 0.99 - warmth * 0.03, 1.04 - warmth * 0.16);
	float caustic = pow(0.5+0.5*sin(p.x*13.0+p.y*9.0+sin(p.y*11.0-t*0.38)*1.3+t*0.41),7.0);
	alive += vec3(0.055,0.10,0.12)*caustic*luminance*motion;
	// Directional phase-contrast highlights travel across the actual membrane.
	vec2 normal = vec2(texture(TEXTURE,uv+vec2(0.006,0)).a,texture(TEXTURE,uv+vec2(0,0.006)).a)-vec2(tissue.a);
	vec2 light = normalize(vec2(-0.7+sin(t*0.23)*0.2*motion,-0.9));
	float wet = max(0.0,dot(normal,light))*0.34;
	alive += vec3(0.57,0.80,0.85)*wet;
	float core = 1.0 - smoothstep(0.06, 0.34, radius);
	alive += vec3(0.38, 0.23, 0.055) * feeding * core * luminance;
	alive += vec3(0.24, 0.045, 0.012) * shock * luminance;
	if (kind>0.5 && kind<1.5) {
		float facing = smoothstep(0.0,0.85,dot(p/max(radius,0.001),threat_direction));
		float pulse = mix(1.0,0.65+organic_beat(t*(1.5+threat_strength))*0.35,motion);
		alive += vec3(0.20,0.13,0.035)*facing*threat_strength*pulse*luminance;
	}
	float shimmer = (0.96 + sin(t * 2.3) * 0.04) * motion + (1.0 - motion);
	vec3 color = mix(dormant, alive, energy) * (1.0 + selected * 0.17 * shimmer);
	float growth_wave = exp(-abs(radius-0.07-growth_front*0.39-sin(theta*4.0+phase)*0.014)*52.0);
	color += vec3(0.08,0.17,0.15)*growth_wave*growth_pulse*luminance*motion;
	if (armor_damage > 0.0) {
		float shell = smoothstep(0.40, 0.69, length(p / vec2(0.42)));
		float seam = abs(sin(theta * 6.0 + sin(radius * 51.0) * 0.25));
		float fracture = 1.0 - smoothstep(0.0, 0.11, seam);
		color *= 1.0 - shell * armor_damage * (0.34 + fracture * 0.55);
		color += vec3(0.22, 0.29, 0.34) * shell * armor_damage * exp(-abs(seam - 0.15) * 55.0);
	}
	if (protection_layers > 0.0) {
		for (int layer = 0; layer < 3; layer++) {
			float fold = 0.29 + float(layer) * 0.025 + sin(theta * 7.0 + float(layer)) * 0.006;
			float ridge = exp(-abs(radius - fold) * 440.0);
			color += vec3(0.18, 0.12, 0.23) * ridge * step(float(layer) + 0.5, protection_layers);
		}
	}
	if (kind < 0.5) {
		// Additional wet vesicles retain the texture's cytoplasm and highlights.
		for (int i = 0; i < 3; i++) {
			vec2 site = vec2(0.5) + vec2(cos(float(i) * 2.1 + 0.3), sin(float(i) * 2.1 + 0.3)) * 0.20;
			float d = length(body_uv - site);
			float sac = (1.0 - smoothstep(0.033, 0.044, d)) * traits.y;
			vec3 fluid = tissue.rgb * vec3(1.2, 0.88, 0.4) + vec3(0.11, 0.055, 0.005);
			fluid += vec3(0.4, 0.24, 0.10) * exp(-abs(d - 0.033) * 420.0);
			color = mix(color, fluid, sac * energy);
		}
		float elastic = exp(-abs(radius - 0.36 - sin(theta * 5.0 + t * 0.3) * 0.009 * motion) * 270.0);
		color += vec3(0.12, 0.23, 0.24) * elastic * traits.z * energy;
	}
	if (kind > 0.5 && kind < 1.5) {
		// The Mother carries authored tissue instead of attached generated pieces.
		for (int layer = 0; layer < 3; layer++) {
			float fold_radius = 0.36 + float(layer) * 0.014 + sin(theta * 5.0 + float(layer) + t * 0.28 * motion) * 0.014;
			float fold = exp(-abs(radius - fold_radius) * 400.0) * smoothstep(float(layer),float(layer)+1.0,evolution_layers);
			color += vec3(0.11, 0.17, 0.19) * fold * energy;
		}
		color = grown_organs(color,texture(TEXTURE,vec2(0.56,0.27)+(body_uv-vec2(0.5))*0.13).rgb,body_uv,t,energy,health_pin*pinned_core);
		float mantle = smoothstep(0.23,0.33,radius)*(1.0-smoothstep(0.43,0.54,radius))*tissue.a;
		float triumph = max(mother_response,0.0);
		float collapse = max(-mother_response,0.0);
		color += vec3(0.32,0.39,0.20)*mantle*triumph;
		color = mix(color,color*vec3(0.48,0.60,0.65),collapse*0.72);
		for (int i = 0; i < 7; i++) {
			float eaten = core_damage[i];
			vec2 q = uv - core_sites[i];
			float r = core_radii[i];
			float distance_to_core = length(q);
			float jagged = sin(atan(q.y, q.x) * 7.0 + float(i)) * 0.018;
			float region = 1.0 - smoothstep(r * 0.87, r * 1.18, distance_to_core + jagged * r);
			float collapse = mix(1.0, 0.03, eaten);
			vec2 feeding_direction = normalize(injury_sites[i]-core_sites[i]+vec2(0.0001));
			vec2 drawn_core = q-feeding_direction*sin(eaten*PI)*r*0.42;
			float remains = 1.0 - smoothstep(r * collapse * 0.75, r * collapse, length(drawn_core));
			vec3 contracting = texture(TEXTURE, core_sites[i] + drawn_core / max(collapse, 0.05)).rgb;
			// The emptied vesicle still contains the mother's fibrous cytoplasm.
			// Borrow a nucleus-free patch of the original material, with a faint
			// crumpled lip instead of painting a flat black circle over the core.
			vec3 cytoplasm = texture(TEXTURE, vec2(0.56, 0.27) + q * 0.82).rgb;
			vec3 cavity = cytoplasm * vec3(0.43, 0.57, 0.64);
			float lip = r * (0.88 + sin(atan(q.y, q.x) * 5.0 + float(i)) * 0.025);
			float scar_edge = exp(-abs(distance_to_core - lip) * 380.0);
			float glint = 0.45 + 0.55 * max(0.0, dot(normalize(q + vec2(0.0001)), normalize(vec2(-0.7, -1.0))));
			cavity += vec3(0.11, 0.17, 0.20) * scar_edge * glint;
			vec3 wound = mix(cavity, contracting, remains * (1.0 - eaten));
			float burning = sin(eaten * PI);
			wound += vec3(0.55, 0.29, 0.075) * burning * scar_edge;
			color = mix(color, wound, region * smoothstep(0.0, 0.16, eaten));
			float impact = exp(-dot(uv - injury_sites[i], uv - injury_sites[i]) * 100.0) * injury_pulse[i];
			color += vec3(0.32, 0.13, 0.045) * impact;
			// Two wet membrane folds embrace the intruder, then knit shut.
			vec2 entry = body_uv-injury_sites[i];
			vec2 axis = normalize(core_sites[i]-injury_sites[i]+vec2(0.0001));
			vec2 slit = vec2(dot(entry,axis),dot(entry,vec2(-axis.y,axis.x)));
			float opening = injury_opening[i];
			float aperture = length(slit/vec2(0.027+opening*0.012,0.011+opening*0.053));
			float fold_rim = exp(-abs(aperture-1.0)*11.0)*opening;
			color *= 1.0-(1.0-smoothstep(0.0,1.0,aperture))*opening*0.36;
			color += vec3(0.20,0.38,0.40)*fold_rim;
			float seal = exp(-abs(slit.x)*165.0)*exp(-slit.y*slit.y*230.0)*injury_seal[i];
			color += vec3(0.16,0.29,0.30)*seal;
		}
		// Food warms and fills the central reservoir; the five health cores stay separate.
		float reserve_radius = 0.04 + nourishment * 0.10;
		float reserve = (1.0 - smoothstep(reserve_radius - 0.025, reserve_radius, length(uv - vec2(0.502, 0.471)))) * nourishment;
		color += vec3(0.22, 0.24, 0.04) * reserve * (0.65 + luminance);
		float nucleus = 1.0 - smoothstep(0.10, 0.18, length(uv - vec2(0.502, 0.471)));
		color = mix(color, color * vec3(0.12, 0.22, 0.28), fatal_damage * nucleus);
	}
	float survival = 1.0;
	if (invading_depth>0.0) {
		// Real host cytoplasm overlays the intruder as it passes below the focal
		// membrane. This retains its silhouette without looking pasted on top.
		vec2 host_offset = water_position-host_center;
		float hc = cos(host_rotation);
		float hs = sin(host_rotation);
		vec2 host_uv = vec2(host_offset.x*hc+host_offset.y*hs,-host_offset.x*hs+host_offset.y*hc)/host_extent+vec2(0.5);
		vec4 host = texture(host_texture,host_uv);
		// The overlay must share the Mother's wounds, never repaint a spent
		// golden health organelle from the original, healthy texture.
		for (int i=0; i<7; i++) {
			vec2 q = host_uv-core_sites[i];
			float scar = (1.0-smoothstep(core_radii[i]*0.85,core_radii[i]*1.20,length(q)))*core_damage[i];
			vec3 cytoplasm = texture(host_texture,vec2(0.56,0.27)+q*0.82).rgb*vec3(0.43,0.57,0.64);
			host.rgb = mix(host.rgb,cytoplasm,scar);
		}
		float submerged = smoothstep(0.12,0.90,invading_depth)*host.a;
		color *= mix(vec3(1.0),vec3(0.75,0.87,0.95),submerged);
		color = mix(color,host.rgb*colony_grade,submerged*0.48);
		color += host.rgb*submerged*0.10;
		tissue.a *= 1.0-submerged*0.22;
	}
	color = mix(color,color*vec3(0.66,0.83,0.98)+vec3(0.09,0.12,0.17),infection*0.65);
	if (dissolve>0.0) {
		// Continuous cellular erosion. Large pockets open before the fine tissue
		// breaks down; no square pixel confetti or whole-sprite fade.
		vec2 erosion_uv = uv+organic_current(p*2.0,t)*0.018*motion;
		float pockets = organic_noise(erosion_uv*18.0+vec2(phase));
		float fine = organic_noise(erosion_uv*48.0-vec2(phase));
		float threshold = clamp(pockets*0.58+fine*0.20+(1.0-smoothstep(0.0,0.5,radius))*0.22,0.05,0.96);
		float erosion = dissolve*1.10;
		survival = smoothstep(erosion-0.055,erosion+0.055,threshold);
		float lip = exp(-abs(threshold-erosion)*55.0)*sin(dissolve*PI);
		color += vec3(0.19,0.26,0.13)*lip;
	}
	if (kind < 0.5) {
		color = grown_organs(color,texture(TEXTURE,(kind>0.5 ? vec2(0.56,0.27) : vec2(0.60,0.31))+(body_uv-vec2(0.5))*0.13).rgb,body_uv,t,energy,pinned_core);
		float r = length(uv - nucleus_uv);
		float veil = exp(-abs(r - 0.34) * 180.0) * adaptations.x;
		color += vec3(0.17, 0.28, 0.24) * veil;
		color += vec3(0.14, 0.035, 0.10) * adaptations.y * exp(-r * 8.0);
		color += vec3(0.015, 0.13, 0.075) * adaptations.z * exp(-abs(r - 0.19) * 70.0);
		color += vec3(0.12, 0.1, 0.025) * adaptations.w * exp(-r * 11.0);
	}
	// Poison must remain unmistakable even during its first forming frame.
	float first_opacity = kind > 6.5 ? 0.60 : 0.28;
	float emergence = mix(first_opacity + (0.82 - first_opacity) * (1.0 - pinned_core), 1.0, born);
	float front = 0.07 + 0.55 * unfurl + sin(theta * 5.0 + phase) * 0.012 * motion;
	float wet_edge = exp(-abs(radius - front) * 95.0) * sin(arrival * PI) * motion;
	color = mix(color * vec3(0.63, 0.78, 0.91), color, born);
	color += vec3(0.18, 0.28, 0.29) * wet_edge;
	if (kind < 1.5) {
		// Grade blue cytoplasm, preserving the gold organelles and health cores.
		color *= mix(vec3(1.0), colony_grade, smoothstep(0.0, 0.12, color.b-color.r));
	}
	color += vec3(0.025,0.16,0.18)*visitor_glow*(0.3+0.7*pinned_core);
	// A small amount of the same medium and transmitted light ties the focal
	// organisms to the dish while retaining sharp nuclei and distinct role hues.
	color = pond_focal_tone(color,water_base,water_immersion);
	color *= mix(1.0,pond_illumination(water_position,clock*motion,light_direction),step(0.001,water_immersion));
	COLOR = vec4(color, tissue.a * mix(0.50, 1.0, energy) * survival * emergence) * tint;
}
