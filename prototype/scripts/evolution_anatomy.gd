extends RefCounted
## Anatomy is derived from owned traits, so it persists without new save fields.
const IDS := ["fission","elastic","symbiosis","enzyme","lure","filter","feast","grazer","catalyst","nursery","frenzy","residual"]
const CHANGES := {
	"fission":"A division network spreads through the Mother as her cells begin to bud.",
	"elastic":"Layered, flexible membranes grow around the colony.",
	"symbiosis":"A luminous network grows through the Mother's cytoplasm.",
	"enzyme":"Digestive sacs form inside the Mother and her cells.",
	"lure":"Long sensory hairs and fluid channels grow.",
	"filter":"A fine, porous veil forms over the living tissue.",
	"feast":"Large, folded storage chambers swell into shape.",
	"grazer":"Delicate feeding brushes and narrow channels develop.",
	"catalyst":"Dense catalytic granules gather in new vesicles.",
	"nursery":"Pale nursery chambers grow throughout the colony.",
	"frenzy":"Folded fluid channels develop throughout the colony.",
	"residual":"Soft trailing membrane folds grow along the cell edges.",
}

static func recipe(owned: Array, growing: String = "", progress: float = 1.0) -> Dictionary:
	var weights := PackedFloat32Array()
	var total := 0.0
	for id in IDS:
		var value := (smoothstep(0.0,1.0,progress) if id==growing else 1.0) if owned.has(id) else 0.0
		weights.append(value)
		total += value
	var form := Vector4(0,0,0,minf(total/6.0,1.0))
	# The first feeding specialization defines the silhouette. Additional traits
	# accumulate organs without replacing the identity the player chose.
	for id in owned:
		var index := IDS.find(id)
		if index>=0 and index<3:
			form[index] = weights[index]
			break
	# Related upgrades grow a mature silhouette; mixing specializations leaves
	# visible secondary anatomy rather than silently replacing the first form.
	var budding := (weights[7]+weights[4]+weights[9])/3.0
	var chambers := (weights[3]+weights[6]+weights[5])/3.0
	var ribs := (weights[3]+weights[10]+weights[11])/3.0
	form.x = form.x*(1.0+budding*0.55)+(0.23*weights[0] if form.x==0.0 else 0.0)
	form.y = form.y*(1.0+chambers*0.55)+(0.25*weights[1] if form.y==0.0 else 0.0)
	form.z = form.z*(1.0+ribs*0.55)+(0.23*weights[2] if form.z==0.0 else 0.0)
	return {"organs":weights,"form":form,
		"traits":Vector4(weights[0],weights[3],weights[1],weights[4]),
		"adaptations":Vector4(weights[5],weights[8],weights[2],weights[9]),
		"layers":total,"growth_front":progress,
		"growth_pulse":sin(clampf(progress,0.0,1.0)*PI) if owned.has(growing) else 0.0}

static func apply(sprite: Sprite2D, anatomy: Dictionary) -> void:
	var is_mother: bool = sprite.material.get_shader_parameter("kind") == 1.0
	for parameter in ["traits","adaptations"]:
		sprite.material.set_shader_parameter(parameter,anatomy[parameter])
	sprite.material.set_shader_parameter("evolution_form",Vector4.ZERO if is_mother else anatomy.form)
	sprite.material.set_shader_parameter("evolution_organs",PackedFloat32Array([0,0,0,0,0,0,0,0,0,0,0,0]) if is_mother else anatomy.organs)
	sprite.material.set_shader_parameter("evolution_layers",0.0 if is_mother else anatomy.layers)
	sprite.material.set_shader_parameter("growth_front",anatomy.growth_front)
	sprite.material.set_shader_parameter("growth_pulse",anatomy.growth_pulse)
	var life := sprite.get_node_or_null("Life")
	if life != null:
		life.lure = anatomy.traits.w
		life.morphology = Vector4.ZERO if is_mother else anatomy.form
	for i in 3:
		var bud := sprite.get_node_or_null("GrowthBud%d" % i)
		if bud != null:
			var growth: float = anatomy.organs[9] if i==2 else anatomy.traits.x
			var extent: float = 0.30 if i==2 else 0.32+0.025*anatomy.organs[9]
			var angle: float = [-0.35,2.55,-1.95][i]
			bud.position = Vector2.from_angle(angle)*sprite.texture.get_width()*(0.37*membrane_scale(angle,anatomy.form)+extent*0.15)
			bud.visible = growth>0.0
			bud.scale = Vector2.ONE*sprite.texture.get_width()*extent/bud.texture.get_width()*growth
			bud.modulate.a = growth

static func membrane_scale(angle: float, form: Vector4) -> float:
	# Matches living_tissue.gdshader so the living hairs stay on the new skin.
	var amount := (0.08+cos(angle*3.0+0.5)*0.15)*form.x
	amount += (0.135+cos(angle*5.0-0.2)*0.045)*form.y
	amount += (0.03+cos(angle*2.0)*0.16+cos(angle*6.0)*0.045)*form.z
	return 1.0/(1.0-clampf(amount+form.w*0.02,-0.22,0.34))
