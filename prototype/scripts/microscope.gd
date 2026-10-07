extends Node2D
## Presentation only. Live node positions, nuclei, timing and capture stay in Run.

const EnemyData = preload("res://scripts/drifter.gd")
const Arrival = preload("res://scripts/organism_arrival.gd")
const Forms = preload("res://scripts/creature_forms.gd")
const Appearance = preload("res://scripts/mission_appearance.gd")
const Anatomy = preload("res://scripts/evolution_anatomy.gd")
const CELL = preload("res://assets/organisms/cell.png")
const MOTHER = preload("res://assets/organisms/mother.png")
const FOOD = preload("res://assets/organisms/desmid.png")
const BELLWETHER = preload("res://assets/organisms/bellwether.png")
const REGENT = preload("res://assets/organisms/glass-regent.png")
const BACTERIUM = preload("res://assets/organisms/copper-bacterium.png")
const PhageVisual = preload("res://scripts/phage_visual.gd")
const GRAZER = preload("res://assets/organisms/grazer.png")
const PARASITE = preload("res://assets/organisms/parasite.png")
const DIVIDER = preload("res://assets/organisms/divider.png")
const ECOLOGY_UVS := {"bacterium":Vector2(0.636,0.5), "amoeba": Vector2(0.534,0.463), "grazer": Vector2(0.5,0.485), "parasite": Vector2(0.425,0.405), "divider": Vector2(0.492,0.516), "warden": Vector2(0.501,0.505)}
const SPORE = preload("res://assets/organisms/pearl-spore.png")
const CYST = preload("res://assets/organisms/toxic-cyst.png")
const HarvestFlow = preload("res://scripts/harvest_flow.gd")
const DRIFTER = preload("res://assets/organisms/drifter.png")
const SHELLBACK = preload("res://assets/organisms/shellback-v2.png")
const TWINSPORE = preload("res://assets/organisms/twinspore-lobe-v2.png")
const CONJOINED = preload("res://assets/organisms/conjoined-lobe-v2.png")
const BRIDGE = preload("res://shaders/living_bridge.gdshader")
const TISSUE = preload("res://shaders/living_tissue.gdshader")
const FIELD = preload("res://shaders/microscope_field.gdshader")
const POND_PLATE = preload("res://assets/organisms/pond-brightfield.png")
const FILM = preload("res://shaders/membrane.gdshader")
const FUSED = preload("res://shaders/fused_tissue.gdshader")
const TissueMotion = preload("res://scripts/tissue_motion.gd")
const PondLife = preload("res://scripts/pond_life.gd")
const MotherDamage = preload("res://scripts/mother_damage.gd")
const InjuryMotes = preload("res://scripts/injury_motes.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
const Water = preload("res://scripts/water_interaction.gd")
const MotherAlert = preload("res://scripts/mother_alert.gd")
const AmoebaVisual = preload("res://scripts/amoeba_visual.gd")
const WaterTracers = preload("res://scripts/water_tracers.gd")
var water := Water.new()
var alert: Dictionary = {}
var game: Node2D
var field: ColorRect
var pond: Node2D
var water_tracers: Node2D
var phage_visual: Node2D
var traveller: Sprite2D
var cells: Array[Sprite2D] = []
var mother: Sprite2D
var enemies: Dictionary = {}
var preview: Polygon2D
var pulses: Array[Node2D] = []
var invaders: Dictionary = {}
var injury_motes: Node2D
var buds: Array[Sprite2D] = []
var harvest_flow: Node2D
var appearance: Dictionary = {}
var growing_trait := ""
var growth_started := 0.0
var anatomy: Dictionary = {}

func growth_progress() -> float:
	return 1.0 if growing_trait.is_empty() or game.reduced_motion else clampf((game.visual_time-growth_started)/3.2,0.0,1.0)

func start_growth(id: String) -> void:
	growing_trait = id
	growth_started = game.visual_time

func finish_growth() -> void:
	growing_trait = ""

func sync_appearance() -> void:
	var presentation_stage: int = 0 if game.run.state=="home" and game.home_pond_open else game.run.stage_index
	var seed_value: int = game.run.run_seed if game.run.state=="home" else game.run.appearance_seed()
	var key := "%d:%d:%s" % [seed_value,presentation_stage,str(game.run.journey)]
	var habitat: String = game.run.habitat_choice if game.run.journey and game.run.state!="home" and game.run.Habitats.available(game.run) else "bloom"
	if habitat=="refuge":
		key += ":refuge"
	if appearance.get("key", "") == key:
		return
	appearance = Appearance.make(seed_value,presentation_stage,game.run.journey,habitat)
	water.wakes.clear()
	for parameter in ["water_grade","water_base","plate_turn","plate_offset","plate_scale","light_direction","sediment"]:
		field.material.set_shader_parameter(parameter,appearance[parameter])
	field.material.set_shader_parameter("pond_plate",load(appearance.plate))
	pond.configure_appearance(appearance)
	for i in cells.size():
		var shape: Vector4 = appearance.cells[i] if not appearance.cells.is_empty() else Vector4(1,1,0,0)
		for sprite in [cells[i],buds[i]]:
			sprite.material.set_shader_parameter("colony_grade",appearance.colony_grade)
			sprite.material.set_shader_parameter("phenotype",shape)
	mother.material.set_shader_parameter("colony_grade",appearance.colony_grade)

func _ready() -> void:
	game = get_parent()
	z_index = -5
	field = ColorRect.new()
	field.size = Vector2(1280, 900)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.z_index = -10
	field.material = material_for(FIELD)
	field.material.set_shader_parameter("pond_plate", POND_PLATE)
	add_child(field)
	pond = PondLife.new()
	pond.z_index = -4
	add_child(pond)
	phage_visual = PhageVisual.new()
	phage_visual.z_index = 5
	add_child(phage_visual)
	water_tracers = WaterTracers.new()
	water_tracers.z_index = -2
	add_child(water_tracers)
	traveller = Sprite2D.new()
	traveller.texture = PondLife.SPECIMENS
	traveller.hframes = 2
	traveller.vframes = 2
	traveller.frame = 1
	traveller.scale = Vector2.ONE*360.0/(PondLife.SPECIMENS.get_width()*0.5)
	traveller.rotation = PI*0.26
	traveller.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	traveller.material = ShaderMaterial.new()
	traveller.material.shader = PondLife.SPECIMEN
	traveller.material.set_shader_parameter("frame_origin",Vector2(0.5,0.0))
	traveller.material.set_shader_parameter("kind",1.0)
	traveller.material.set_shader_parameter("blur",0.012)
	traveller.z_index = -3
	traveller.visible = false
	add_child(traveller)
	preview = Polygon2D.new()
	preview.material = material_for(FILM)
	preview.z_index = -1
	preview.visible = false
	add_child(preview)
	for i in game.run.board.anchors.size():
		var sprite := organism(CELL, 63.0 + (i % 3 - 1) * 2.0, float(i) * 1.7)
		sprite.position = game.run.board.anchors[i]
		sprite.rotation = float(i) * 2.399
		cells.append(sprite)
		var bud := organism(CELL, 18.0, float(i) * 1.7 + 1.0, false)
		bud.z_index = 3
		bud.visible = false
		buds.append(bud)
	mother = organism(MOTHER, 120.0, 0.3)
	mother.position = game.run.board.center
	mother.z_index = 5
	mother.material.set_shader_parameter("warmth", 0.20)
	injury_motes = InjuryMotes.new()
	injury_motes.z_index = 7
	add_child(injury_motes)
	harvest_flow = HarvestFlow.new()
	harvest_flow.z_index = 6
	add_child(harvest_flow)
	sync()

func material_for(shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func organism(texture: Texture2D, extent: float, phase: float, living_details: bool = true) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * extent / texture.get_width()
	sprite.material = material_for(TISSUE)
	sprite.material.set_shader_parameter("phase", phase)
	sprite.material.set_shader_parameter("nucleus_uv", Vector2.ONE * 0.5)
	# The headless renderer does not return shader defaults through get_shader_parameter.
	# These two values also drive the CPU-drawn cilia, so initialize them explicitly.
	sprite.material.set_shader_parameter("phenotype",Vector4(1,1,0,0))
	sprite.material.set_shader_parameter("flow_velocity",Vector2.ZERO)
	var kind := 1 if texture == MOTHER else (0 if texture == CELL else 2)
	var family: String = Forms.definition(texture.resource_path.get_file().get_basename()).get("kind", "")
	if texture==BACTERIUM:
		kind = 8
	elif texture == FOOD or family == "food":
		kind = 6
	elif texture == CYST or family == "cyst":
		kind = 7
	elif texture == SHELLBACK:
		kind = 3
	elif texture == TWINSPORE:
		kind = 4
	elif texture == DIVIDER or family == "divider":
		kind = 4
	elif texture == PARASITE or family == "parasite":
		kind = 5
	elif texture == CONJOINED:
		kind = 5
	sprite.material.set_shader_parameter("kind", float(kind))
	if kind == 1:
		sprite.material.set_shader_parameter("core_sites", PackedVector2Array(MotherDamage.CORE_UVS))
		sprite.material.set_shader_parameter("core_radii", PackedFloat32Array(MotherDamage.CORE_RADII))
	sprite.set_meta("phase", phase)
	sprite.set_meta("extent", extent)
	if living_details:
		var details := TissueMotion.new()
		details.name = "Life"
		details.kind = kind
		details.phase = phase
		details.texture_extent = texture.get_width()
		details.display_extent = extent
		sprite.add_child(details)
	sprite.z_index = 1
	add_child(sprite)
	if kind == 1:
		for i in 3:
			var bud := organism(CELL,24.0,phase+float(i),false)
			bud.reparent(sprite)
			bud.name = "GrowthBud%d" % i
			bud.position = Vector2.from_angle([-0.35,2.55,-1.95][i])*MOTHER.get_width()*(0.43 if i==2 else 0.405)
			bud.scale = Vector2.ONE*MOTHER.get_width()*0.20/CELL.get_width()
			bud.z_index = -1
			bud.visible = false
	return sprite

func animate_organism(sprite: Sprite2D, time: float, movement: float, vitality: float, meal: float = 0.0, shock: float = 0.0) -> void:
	var mat: ShaderMaterial = sprite.material
	if not appearance.is_empty() and sprite.get_meta("water_key","")!=appearance.key:
		mat.set_shader_parameter("water_base",appearance.water_base*appearance.water_grade)
		mat.set_shader_parameter("light_direction",appearance.light_direction)
		mat.set_shader_parameter("water_immersion",0.16)
		var filaments := sprite.get_node_or_null("Life")
		if filaments!=null:
			filaments.self_modulate = Color(0.90,0.94,0.95,1.0)
		sprite.set_meta("water_key",appearance.key)
	mat.set_shader_parameter("clock", time)
	mat.set_shader_parameter("motion", movement)
	mat.set_shader_parameter("energy", vitality)
	mat.set_shader_parameter("feeding", meal)
	mat.set_shader_parameter("shock", shock)
	var details := sprite.get_node_or_null("Life")
	if details != null:
		details.phenotype = mat.get_shader_parameter("phenotype")
		details.flow_velocity = mat.get_shader_parameter("flow_velocity")
		details.animate(time, movement, vitality, meal)
	for i in 3:
		var bud := sprite.get_node_or_null("GrowthBud%d" % i)
		if bud != null and bud.visible:
			bud.material.set_shader_parameter("colony_grade",mat.get_shader_parameter("colony_grade"))
			animate_organism(bud,time,movement,vitality,meal,shock)

func sync() -> void:
	var title: bool = game.run.state=="home" and not game.home_pond_open
	scale = Vector2.ONE*(2.15 if title else 1.0)
	position = game.run.board.center*(Vector2.ONE-scale)
	sync_appearance()
	var time: float = game.visual_time
	var movement := 0.0 if game.reduced_motion else 1.0
	field.material.set_shader_parameter("clock", time)
	field.material.set_shader_parameter("motion", movement)
	field.material.set_shader_parameter("detail", float(game.visual_quality))
	field.material.set_shader_parameter("dish", float(appearance.biome) if game.run.journey else 0.0)
	sync_water_impulses()
	pond.set_quality(game.visual_quality)
	pond.sync(time, movement)
	water_tracers.sync(time,movement,game.run.fluid,appearance,game.visual_quality)
	phage_visual.sync(game.run,time,movement)
	var event: Dictionary = game.run.harvest.HabitatEvents.sample(game.run) if game.run.journey else {}
	traveller.visible = not event.is_empty() and event.kind=="traveller" and event.age>=0.0 and game.run.state in ["active","paused"]
	if traveller.visible:
		traveller.position = event.position if not game.reduced_motion else game.run.board.center+Vector2(0,110)
		traveller.material.set_shader_parameter("clock",time)
		traveller.material.set_shader_parameter("motion",movement)
		traveller.material.set_shader_parameter("opacity",event.strength*0.56)
		traveller.material.set_shader_parameter("water_grade",appearance.water_grade)
		traveller.material.set_shader_parameter("water_base",appearance.water_base)
		traveller.material.set_shader_parameter("light_direction",appearance.light_direction)
	if harvest_flow != null:
		harvest_flow.visible = game.run.harvest != null
		harvest_flow.queue_redraw()
	var habitat: bool = game.run.state=="home" or (game.home_pond!=null and game.home_pond.showing_epilogue())
	for sprite in cells+buds+[mother,preview,injury_motes]+enemies.values()+pulses+invaders.values():
		sprite.visible = not habitat
	if habitat:
		if harvest_flow != null:
			harvest_flow.visible = false
		return
	var meal := 0.0
	for effect in game.effects:
		if not effect.positions.is_empty():
			meal += effect.digestion() * 0.45
	meal = minf(meal, 1.0)
	var shock: float = game.run.mother_damage.recoil() * movement
	var legal: Array = game.run.selection.legal_next()
	anatomy = Anatomy.recipe(game.run.mutations,growing_trait,growth_progress())
	var traits: Vector4 = anatomy.traits
	for i in cells.size():
		var mat: ShaderMaterial = cells[i].material
		var cell = game.run.cells[i]
		if cell.lost or cell.captor>=0:
			cells[i].visible = false
			buds[i].visible = false
			continue
		var clot = game.run.clot_for(i)
		var pull: float = clot.amount() if clot != null else 0.0
		var feed: float = clot.digestion() if clot != null and not clot.positions.is_empty() else 0.0
		cells[i].position = clot.cell_position(clot.nodes.find(i), game.reduced_motion) if clot != null else game.run.board.anchors[i]
		var vitality: float = 1.0 if cell.is_ready() else clampf(0.55 + cell.progress() * 0.45 + feed * 0.25, 0.0, 1.0)
		if game.reduced_motion and not cell.is_ready():
			vitality = 0.20 + cell.progress() * 0.35
		if game.run.journey and game.run.harvest.ecology.blocked(game.run,i):
			vitality = 0.18
		cells[i].rotation = float(i)*2.399+(sin(time*0.31+i*1.7)*0.065+sin(time*0.17+i*2.1)*0.035)*movement
		var drift: Vector2 = game.run.board.velocities[i]/game.run.board.MAX_SPEED
		if clot != null:
			drift = (clot.center-clot.polygon[clot.nodes.find(i)]).normalized()*sin(pull*PI)*(1.0 if clot.progress()<0.5 else -1.0)
		mat.set_shader_parameter("flow_velocity",drift.rotated(-cells[i].rotation)*movement)
		Anatomy.apply(cells[i],anatomy)
		animate_organism(cells[i], time, movement, vitality, feed)
		cells[i].z_index = 0 if clot != null else 3
		# Retire the individual skins as the shared surface takes over. Modulate
		# also fades their cilia/organelles, so no seams survive inside the mass.
		cells[i].modulate.a = 1.0 - smoothstep(0.24, 0.82, pull) * movement
		var extent: float = cells[i].get_meta("extent")
		cells[i].scale = Vector2(1.0 + pull * 0.09 * movement, 1.0 - pull * 0.06 * movement) * extent / CELL.get_width()

		var returning: Dictionary = game.run.amoebas.return_for(i)
		if not returning.is_empty():
			cells[i].position = game.run.amoebas.return_position(returning,game.reduced_motion)
			cells[i].scale *= lerpf(0.68,1.0,smoothstep(0.0,1.25,returning.age))

		mat.set_shader_parameter("selected", 1.0 if legal.has(i) or game.run.selection.path.has(i) else 0.0)
		buds[i].visible = traits.x > 0.0 and cell.is_ready()
		if buds[i].visible:
			buds[i].position = cells[i].position + Vector2.from_angle(i * 2.399 + 0.4) * 32.0
			buds[i].scale = Vector2.ONE*27.0/CELL.get_width()*traits.x
			buds[i].modulate.a = traits.x
			animate_organism(buds[i], time, movement, 0.75)
	Anatomy.apply(mother,anatomy)
	mother.material.set_shader_parameter("nourishment", clampf(float(game.run.harvest.nourishment) / (float(game.run.harvest.spec.food) if game.run.journey else game.run.harvest.GOAL), 0.0, 1.0) if game.run.harvest != null else 0.0)
	animate_organism(mother, time, movement, 0.5 + 0.1 * game.run.integrity, meal, shock)
	mother.rotation = sin(time * 0.4) * 0.028 * movement
	mother.material.set_shader_parameter("threat_direction",Vector2(alert.direction).rotated(-mother.rotation))
	mother.material.set_shader_parameter("threat_strength",alert.strength)
	sync_injuries(time, movement, shock)
	var alive := {}
	for enemy in game.run.enemies:
		alive[enemy.id] = true
		if not enemies.has(enemy.id):
			enemies[enemy.id] = create_enemy(enemy)
		sync_enemy(enemies[enemy.id], enemy, time, movement)
	for id in enemies.keys():
		if not alive.has(id):
			enemies[id].queue_free()
			enemies.erase(id)
	preview.visible = game.run.selection.can_close()
	if preview.visible:
		preview.polygon = Geometry.polygon_for(game.run.selection.path, game.run.board.anchors)
		preview.material.set_shader_parameter("poison", 1.0 if game.run.harvest != null and game.run.harvest_preview().poison > 0 else 0.0)
		preview.material.set_shader_parameter("clock", time)
		preview.material.set_shader_parameter("motion", movement)
		preview.material.set_shader_parameter("strength", 0.27 if game.run.selection.closed else 0.11)
	# Match by capture identity: an earlier effect expiring must never reuse its
	# tissue fragments for a later capture with a different number of victims.
	var active_pulses: Array[Node2D] = []
	for effect in game.effects:
		var pulse: Node2D = null
		for candidate in pulses:
			if candidate.get_meta("serial") == effect.serial:
				pulse = candidate
				break
		if pulse == null:
			pulse = create_pulse(effect)
		active_pulses.append(pulse)
	for old in pulses:
		if not active_pulses.has(old):
			old.queue_free()
	pulses = active_pulses
	for i in pulses.size():
		var clot = game.effects[i]
		var t: float = clot.progress()
		var points: PackedVector2Array = clot.cell_positions(game.reduced_motion)
		var surface: ColorRect = pulses[i].get_meta("surface")
		if pulses[i].has_meta("channel"):
			var channel: ColorRect = pulses[i].get_meta("channel")
			channel.visible = not game.reduced_motion
			var destination: Vector2 = game.run.board.anchors[clot.restored_node]
			var channel_bounds := Rect2(clot.center, Vector2.ZERO).expand(destination).grow(10.0)
			channel.position = channel_bounds.position
			channel.size = channel_bounds.size
			channel.modulate.a = smoothstep(0.15, 0.35, t) * (1.0 - smoothstep(0.55, 0.75, t))
			channel.material.set_shader_parameter("bounds_size", channel_bounds.size)
			channel.material.set_shader_parameter("first", clot.center - channel_bounds.position)
			channel.material.set_shader_parameter("second", destination - channel_bounds.position)
			channel.material.set_shader_parameter("width", 2.6)
			channel.material.set_shader_parameter("clock", time * 2.0)
		surface.visible = not game.reduced_motion and clot.amount() > 0.24
		var bounds := Rect2(points[0], Vector2.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		bounds = bounds.grow(90.0)
		surface.position = bounds.position
		surface.size = bounds.size
		var local_points := PackedVector2Array()
		for point in points:
			local_points.append(point - bounds.position)
		local_points.resize(10)
		surface.material.set_shader_parameter("members", local_points)
		surface.material.set_shader_parameter("member_count", points.size())
		surface.material.set_shader_parameter("bounds_size", bounds.size)
		surface.material.set_shader_parameter("fusion", clot.amount())
		surface.material.set_shader_parameter("opacity", smoothstep(0.24, 0.82, clot.amount()))
		surface.material.set_shader_parameter("clock", time)
		surface.material.set_shader_parameter("feeding", clot.digestion() if not clot.positions.is_empty() else 0.0)
		surface.material.set_shader_parameter("mastery",1.0 if not clot.mastery.is_empty() else 0.0)
		var ghosts: Array = pulses[i].get_meta("ghosts")
		for j in ghosts.size():
			var ghost: Sprite2D = ghosts[j]
			ghost.position = clot.prey_position(j, game.reduced_motion)
			var digestion: float = smoothstep(0.27, 0.58, t)
			ghost.scale = Vector2(1.0-digestion*0.24*movement,1.0-digestion*0.32*movement)*float(ghost.get_meta("extent"))/ghost.texture.get_width()
			animate_organism(ghost, time, movement, 1.0)
			ghost.material.set_shader_parameter("dissolve", digestion)

func sync_water_impulses() -> void:
	# Optical pressure fronts accompany the persistent simulation in Run.fluid.
	# Their ages still follow the saved capture, nudge and injury events.
	var impulses := PackedVector4Array()
	var currents := PackedVector4Array()
	alert = MotherAlert.sample(game.run)
	if not game.reduced_motion:
		var nudge = game.run.nudge
		var push_age: float = nudge.COOLDOWN-nudge.cooldown
		if nudge.cooldown>0.0 and push_age<1.7 and nudge.ripple_vector.length()>0.0:
			var strength := sin(push_age/1.7*PI)*0.55
			impulses.append(Vector4(nudge.ripple_origin.x,nudge.ripple_origin.y,push_age,strength))
			currents.append(Vector4(nudge.ripple_origin.x,nudge.ripple_origin.y,strength*12.0,strength*7.0))
		for effect in game.effects:
			if impulses.size()>=3:
				break
			var progress: float = effect.progress()
			impulses.append(Vector4(effect.center.x,effect.center.y,progress*3.0,sin(progress*PI)*0.8))
			var envelope := sin(progress*PI)
			var release := smoothstep(0.55,0.90,progress)
			currents.append(Vector4(effect.center.x,effect.center.y,lerpf(-20.0,24.0,release)*envelope,18.0*envelope))
		for bite in game.run.mother_damage.bites:
			if impulses.size()>=4:
				break
			impulses.append(Vector4(bite.origin.x,bite.origin.y,bite.age,sin(clampf(bite.age/2.2,0.0,1.0)*PI)*0.65))
			currents.append(Vector4(bite.origin.x,bite.origin.y,impulses[-1].w*16.0,3.0*impulses[-1].w))
		if currents.size()<4 and alert.strength>0.0:
			currents.append(Vector4(alert.position.x,alert.position.y,alert.strength*12.0,alert.strength*3.0))
		for body in game.run.enemies:
			if currents.size()<4 and body.kind in ["bellwether","bell_bud"]:
				currents.append(Vector4(body.nucleus.x,body.nucleus.y,-24.0*body.current_strength(),4.0*body.current_strength()))
			elif currents.size()<4 and body.visitor and body.form=="glass_harp":
				currents.append(Vector4(body.nucleus.x,body.nucleus.y,-11.0*body.opening(),6.0*body.opening()))
			elif currents.size()<4 and body.visitor and body.form=="glowdrift":
				currents.append(Vector4(body.nucleus.x,body.nucleus.y,8.0*body.opening(),3.0*body.opening()))
		if game.run.journey and currents.size()<4:
			var event: Dictionary = game.run.harvest.HabitatEvents.sample(game.run)
			if not event.is_empty() and event.kind=="traveller":
				currents.append(Vector4(event.position.x,event.position.y,14.0*event.strength,7.0*event.strength))
	impulses.resize(4)
	currents.resize(4)
	field.material.set_shader_parameter("impulses",impulses)
	var wake := water.sample(game.visual_time,game.reduced_motion)
	var fluid_texture: ImageTexture = game.run.fluid.flow_texture()
	field.material.set_shader_parameter("fluid_map",fluid_texture)
	field.material.set_shader_parameter("fluid_enabled",true)
	pond.set_fluid(game.run.fluid,fluid_texture)
	field.material.set_shader_parameter("currents",currents)
	field.material.set_shader_parameter("strokes",wake.strokes)
	field.material.set_shader_parameter("stroke_strengths",wake.strengths)
	pond.set_flow(currents,wake.strokes,wake.strengths)

func disturb_water(from: Vector2, to: Vector2) -> void:
	if game.run.selection.active and game.run.state == "active":
		game.run.fluid.stroke(from,to)
		if not game.reduced_motion:
			water.stroke(from,to,game.visual_time)

func core_position(index: int) -> Vector2:
	return mother.to_global((MotherDamage.CORE_UVS[index] - Vector2.ONE * 0.5) * MOTHER.get_width())

func sync_injuries(time: float, movement: float, shock: float) -> void:
	var damage = game.run.mother_damage
	var progress: PackedFloat32Array = damage.progress_values()
	var sites := PackedVector2Array(MotherDamage.CORE_UVS)
	var pulses_now := PackedFloat32Array([0, 0, 0, 0, 0])
	var openings := PackedFloat32Array([0, 0, 0, 0, 0])
	var seals := PackedFloat32Array([0, 0, 0, 0, 0])
	var alive := {}
	var recoil := Vector2.ZERO
	for bite in damage.bites:
		var direction: Vector2 = (game.run.board.center - bite.origin).normalized()
		recoil += direction * sin(clampf(bite.age / 0.46, 0.0, 1.0) * PI) * 2.4 * movement
	mother.position = game.run.board.center + recoil.limit_length(3.0)
	mother.scale = Vector2(1.0 - shock * 0.035, 1.0 + shock * 0.025) * float(mother.get_meta("extent")) / MOTHER.get_width()
	for bite in damage.bites:
		alive[bite.serial] = true
		if not invaders.has(bite.serial):
			var visual_enemy := EnemyData.new(bite.enemy_id, bite.origin, 0.0, bite.kind)
			visual_enemy.form = bite.get("form", "")
			visual_enemy.health = bite.health
			var body := create_enemy(visual_enemy)
			body.z_index = 6
			invaders[bite.serial] = body
		var invader: Node2D = invaders[bite.serial]
		invader.visible = bite.kind != "cyst" # poison arrives via the feeding stream
		var age: float = bite.age
		var core := core_position(bite.core)
		var direction: Vector2 = (core - bite.origin).normalized()
		var press := sin(clampf(age/0.40,0.0,1.0)*PI)*movement
		var burrow := smoothstep(0.18, 0.84, age) * movement
		var sink := smoothstep(1.48, MotherDamage.DURATION, age)
		var feeding := sin(progress[bite.core]*PI)
		invader.position = bite.origin.lerp(core - direction * 9.0, burrow)
		invader.position -= direction*press*2.3
		invader.position += direction*(sink*6.0+sin(age*16.0)*feeding*0.8)*movement
		invader.modulate.a = 1.0 - burrow * 0.12 - sink * 0.28
		var lobes: Array = invader.get_meta("lobes")
		var local_sites := PackedVector2Array()
		for i in lobes.size():
			var lobe: Sprite2D = lobes[i]
			var original: Vector2 = bite.nuclei[i] if i < bite.nuclei.size() else bite.origin
			lobe.position = (original - bite.origin) * (1.0 - burrow * 0.30)
			local_sites.append(lobe.position)
			lobe.rotation = (game.run.board.center - bite.origin).angle() + sin(age * 19.0 + i) * 0.028 * sin(clampf(age / 1.6, 0.0, 1.0) * PI) * movement
			if lobes.size() == 2:
				lobe.rotation += PI * i
			# A short squeeze through the membrane, then a small feeding swell.
			var squeeze := sin(burrow*PI)*0.15
			lobe.scale = Vector2(1.0-burrow*0.25+press*0.08-squeeze*0.3,1.0-burrow*0.34-press*0.11-squeeze+feeding*0.06*movement) * float(lobe.get_meta("extent")) / lobe.texture.get_width()
			animate_organism(lobe, time, movement, 1.0, sin(progress[bite.core] * PI))
			lobe.material.set_shader_parameter("invading_depth",burrow)
			lobe.material.set_shader_parameter("host_texture",MOTHER)
			lobe.material.set_shader_parameter("host_center",mother.position)
			lobe.material.set_shader_parameter("host_extent",mother.scale*MOTHER.get_width())
			lobe.material.set_shader_parameter("core_sites",PackedVector2Array(MotherDamage.CORE_UVS))
			lobe.material.set_shader_parameter("core_radii",PackedFloat32Array(MotherDamage.CORE_RADII))
			lobe.material.set_shader_parameter("core_damage",progress)
			lobe.material.set_shader_parameter("dissolve", sink)
			lobe.material.set_shader_parameter("armor_damage", 1.0 if bite.kind == "shellback" and bite.health == 1 else 0.0)
		if invader.has_meta("bridge"):
			sync_bridge(invader, local_sites[0], local_sites[1], time, movement, false, 0.0)
			invader.get_meta("bridge").modulate.a = 1.0 - sink
		sites[bite.core] = mother.to_local(bite.origin) / MOTHER.get_width() + Vector2.ONE * 0.5
		pulses_now[bite.core] = sin(clampf(age / 1.4, 0.0, 1.0) * PI) * 0.7
		openings[bite.core] = smoothstep(0.04,0.34,age)*(1.0-smoothstep(0.72,1.24,age))*movement
		seals[bite.core] = sin(smoothstep(1.30,MotherDamage.DURATION,age)*PI)*movement
	for id in invaders.keys():
		if not alive.has(id):
			invaders[id].queue_free()
			invaders.erase(id)
	mother.material.set_shader_parameter("core_damage", progress)
	mother.material.set_shader_parameter("injury_sites", sites)
	mother.material.set_shader_parameter("injury_pulse", pulses_now)
	mother.material.set_shader_parameter("injury_opening", openings)
	mother.material.set_shader_parameter("injury_seal", seals)
	var fatal := 1.0 if game.run.integrity == 0 else 0.0
	for value in progress:
		fatal = minf(fatal, value)
	mother.material.set_shader_parameter("fatal_damage", fatal)
	injury_motes.visible = movement > 0.0
	injury_motes.queue_redraw()

func create_pulse(effect: RefCounted) -> Node2D:
	var pulse := Node2D.new()
	pulse.z_index = 0
	pulse.set_meta("serial", effect.serial)
	add_child(pulse)
	var surface := ColorRect.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.material = material_for(FUSED)
	surface.material.set_shader_parameter("tissue_texture", CELL)
	surface.material.set_shader_parameter("colony_grade",appearance.get("colony_grade",Vector3.ONE))
	surface.material.set_shader_parameter("water_base",appearance.water_base*appearance.water_grade)
	surface.material.set_shader_parameter("light_direction",appearance.light_direction)
	pulse.add_child(surface)
	pulse.set_meta("surface", surface)
	if effect.restored_node >= 0:
		var channel := ColorRect.new()
		channel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		channel.material = material_for(BRIDGE)
		channel.material.set_shader_parameter("tissue_texture", CELL)
		pulse.add_child(channel)
		pulse.set_meta("channel", channel)
	var ghosts: Array[Sprite2D] = []
	for i in effect.positions.size():
		var origin: Vector2 = effect.positions[i]
		var kind: String = effect.prey_kinds[i] if i < effect.prey_kinds.size() else "drifter"
		var form: String = effect.prey_forms[i] if i < effect.prey_forms.size() else ""
		var ghost := organism(enemy_texture(kind, form), enemy_extent(kind,form), origin.x * 0.03, false)
		if ECOLOGY_UVS.has(kind):
			register_nucleus(ghost,ECOLOGY_UVS[kind])
		if kind == "food":
			register_nucleus(ghost, Vector2(0.499, 0.547))
		elif kind == "cyst":
			register_nucleus(ghost, Vector2(0.5, 0.51))
		if kind == "twinspore":
			register_nucleus(ghost, Vector2(0.498, 0.5873))
		if kind == "shellback":
			register_nucleus(ghost, Vector2(0.4996, 0.5119))
			ghost.material.set_shader_parameter("armor_damage", 1.0)
		if kind == "conjoined":
			register_nucleus(ghost, Vector2(0.5005, 0.506))
		if kind in ["bell_bud","bellwether","regent","spore"]:
			register_nucleus(ghost,{"bell_bud":Vector2(0.502,0.485),"bellwether":Vector2(0.502,0.485),"regent":Vector2(0.501,0.505),"spore":Vector2(0.514,0.526)}[kind])
		if Forms.valid_form(form, kind):
			register_nucleus(ghost, Forms.definition(form).uv)
		ghost.reparent(pulse)
		ghost.z_index = 2
		ghost.position = origin
		ghost.rotation = (game.run.board.center - origin).angle()
		ghost.material.set_shader_parameter("warmth", 1.0)
		ghosts.append(ghost)
	pulse.set_meta("ghosts", ghosts)
	return pulse

func enemy_extent(kind: String, form: String = "") -> float:
	if Forms.definition(form).get("rare",false):
		return 90.0
	return {"bacterium":112.0, "amoeba":142.0, "bell_bud": 74.0, "grazer": 84.0, "parasite": 88.0, "divider": 95.0, "warden": 52.0, "bellwether": 130.0, "regent": 145.0, "spore": 43.0, "food": 47.0, "cyst": 43.0, "conjoined": 112.0, "twinspore": 70.0, "shellback": 84.0}.get(kind, 78.0)

func enemy_texture(kind: String, form: String = "") -> Texture2D:
	if kind=="amoeba": return AmoebaVisual.TEXTURE
	if kind=="bacterium": return BACTERIUM
	if kind=="phage": return PhageVisual.TEXTURE
	if Forms.valid_form(form, kind):
		return Forms.texture(form)
	if not Forms.definition(kind).is_empty():
		return Forms.texture(kind) # Field journal entries use the form ID.
	if kind == "grazer":
		return GRAZER
	if kind == "parasite":
		return PARASITE
	if kind == "divider":
		return DIVIDER
	if kind == "warden":
		return REGENT
	if kind in ["bellwether","bell_bud"]:
		return BELLWETHER
	if kind == "regent":
		return REGENT
	if kind == "spore":
		return SPORE
	if kind == "food":
		return FOOD
	if kind == "cyst":
		return CYST
	if kind == "shellback":
		return SHELLBACK
	if kind in ["twinspore", "conjoined"]:
		return CONJOINED if kind == "conjoined" else TWINSPORE
	return DRIFTER

func create_enemy(enemy: RefCounted) -> Node2D:
	if enemy.kind=="amoeba":
		var amoeba := AmoebaVisual.new()
		add_child(amoeba)
		amoeba.setup(self,enemy)
		return amoeba
	var body := Node2D.new()
	body.z_index = 4
	add_child(body)
	var lobes: Array[Sprite2D] = []
	if enemy.nuclei().size() == 2:
		var bridge := ColorRect.new()
		bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bridge.material = material_for(BRIDGE)
		bridge.material.set_shader_parameter("tissue_texture", enemy_texture(enemy.kind))
		bridge.z_index = -1
		body.add_child(bridge)
		body.set_meta("bridge", bridge)
	for i in enemy.nuclei().size():
		var extent := 90.0 if enemy.visitor else enemy_extent(enemy.kind)
		var sprite := organism(enemy_texture(enemy.kind, enemy.form), extent, enemy.id * 0.8 + i * 1.3, not enemy.is_boss() and enemy.kind!="bacterium")
		sprite.reparent(body)
		sprite.material.set_shader_parameter("warmth", 0.6 if enemy.is_boss() else 1.0)
		if ECOLOGY_UVS.has(enemy.kind):
			register_nucleus(sprite,ECOLOGY_UVS[enemy.kind])
		elif enemy.kind in ["bellwether", "bell_bud", "regent", "spore"]:
			register_nucleus(sprite, {"bell_bud": Vector2(0.502,0.485), "bellwether": Vector2(0.502, 0.485), "regent": Vector2(0.501, 0.505), "spore": Vector2(0.514, 0.526)}[enemy.kind])
		elif enemy.kind == "food":
			register_nucleus(sprite, Vector2(0.499, 0.547))
		elif enemy.kind == "cyst":
			register_nucleus(sprite, Vector2(0.5, 0.51))
		elif enemy.kind == "twinspore":
			register_nucleus(sprite, Vector2(0.498, 0.5873))
		elif enemy.kind == "shellback":
			register_nucleus(sprite, Vector2(0.4996, 0.5119))
		elif enemy.kind == "conjoined":
			register_nucleus(sprite, Vector2(0.5005, 0.506))
		if Forms.valid_form(enemy.form, enemy.kind):
			register_nucleus(sprite, Forms.definition(enemy.form).uv)
		lobes.append(sprite)
	body.set_meta("lobes", lobes)
	return body

func register_nucleus(sprite: Sprite2D, uv: Vector2) -> void:
	sprite.offset = (Vector2.ONE * 0.5 - uv) * sprite.texture.get_size()
	sprite.material.set_shader_parameter("nucleus_uv", uv)

func sync_enemy(body: Node2D, enemy: RefCounted, time: float, movement: float) -> void:
	if enemy.kind=="amoeba":
		body.sync(self,enemy,time,movement)
		return
	body.position = enemy.nucleus
	body.modulate.a = enemy.opacity() if enemy.has_method("opacity") else 1.0
	var arrival := Arrival.progress(enemy)
	var nuclei: PackedVector2Array = enemy.nuclei()
	var lobes: Array = body.get_meta("lobes")
	var being_eaten: float = game.run.harvest.ecology.eating_progress(game.run,enemy.id) if game.run.journey else 0.0
	for i in nuclei.size():
		var sprite: Sprite2D = lobes[i]
		sprite.position = nuclei[i] - enemy.nucleus
		sprite.rotation = (nuclei[1 - i] - nuclei[i]).angle() if nuclei.size() == 2 else (game.run.board.center - enemy.nucleus).angle()
		if enemy.kind in ["grazer","parasite","divider","drifter","bacterium"] and enemy.heading.length_squared()>0.0:
			sprite.rotation = enemy.heading.angle()
		if enemy.kind=="bacterium":
			var infection: float = maxf(0.0,enemy.infection_age/enemy.INFECTION_TIME)
			sprite.scale = Vector2(1.0+infection*0.05,1.0+infection*0.25)*enemy_extent(enemy.kind)/sprite.texture.get_width()
			sprite.material.set_shader_parameter("infection",infection)
		if enemy.kind == "divider":
			var division: float = 0.0 if enemy.daughter else smoothstep(12.0,20.0,enemy.age)
			sprite.material.set_shader_parameter("division",division)
			sprite.scale = Vector2(1.0+division*0.18,1.0)*enemy_extent(enemy.kind)/sprite.texture.get_width()*(0.70 if enemy.daughter else 1.0)
		if enemy.cradle and enemy.hatch_remaining()>=0.0:
			var hatch: float = 1.0-enemy.hatch_remaining()/12.0
			sprite.material.set_shader_parameter("division",smoothstep(0.35,1.0,hatch))
			sprite.scale = Vector2(1.0+hatch*0.35*movement,1.0)*enemy_extent(enemy.kind)/sprite.texture.get_width()
		var sway_rate := 0.7 if enemy.is_boss() else 1.0 if enemy.kind == "shellback" else 2.1 if enemy.kind == "twinspore" else 4.8
		var sway_extent := 0.075 if enemy.is_boss() else 0.018 if enemy.kind == "shellback" else 0.055 if enemy.kind == "twinspore" else 0.035
		if enemy.kind in ["food", "cyst", "spore"]:
			sway_rate = 0.65
			sway_extent = 0.12
		var species_phase: float = enemy.id*0.8+i
		sprite.rotation += (sin(time*sway_rate+species_phase)*0.72+sin(time*sway_rate*0.43+species_phase*1.73)*0.28)*sway_extent*movement
		if enemy.kind=="cyst" and enemy.has_method("nudge_roll"):
			sprite.rotation += enemy.nudge_roll()*movement
		sprite.material.set_shader_parameter("flow_velocity",Vector2(minf(enemy.speed/12.0,1.0),0)*movement)
		animate_organism(sprite, time, movement, 0.9 if enemy.slowed > 0.0 else 1.0, sin(enemy.hunt_time/6.0*PI)*0.6, enemy.hit_flash * 0.5)
		sprite.material.set_shader_parameter("visitor_open",enemy.opening() if enemy.visitor and not game.reduced_motion else 1.0)
		sprite.material.set_shader_parameter("visitor_glow",enemy.opening()*0.6 if enemy.form=="glowdrift" else 0.0)
		var hatching: float = (1.0-smoothstep(0.0,2.0,enemy.hatch_remaining()))*0.5 if enemy.cradle and enemy.hatch_remaining()>=0.0 else 0.0
		sprite.material.set_shader_parameter("dissolve",maxf(being_eaten*0.94,hatching) if enemy.kind!="bacterium" else smoothstep(7.8,9.0,enemy.infection_age))
		sprite.material.set_shader_parameter("arrival", arrival)
		var details := sprite.get_node_or_null("Life")
		if details != null:
			details.modulate.a = smoothstep(0.2, 1.0, arrival)
		sprite.material.set_shader_parameter("armor_damage", 1.0 if enemy.kind == "shellback" and enemy.health == 1 else 0.0)
		sprite.material.set_shader_parameter("protection_layers", float(enemy.health) if (enemy.is_boss() or enemy.kind=="bell_bud") and not enemy.can_take_pulse() else 2.0 if enemy.cradle and not enemy.gate_ids.is_empty() else 0.0)
		sprite.material.set_shader_parameter("bell_breath",enemy.current_strength() if enemy.kind in ["bellwether","bell_bud"] and not game.reduced_motion else 0.0)
		sprite.material.set_shader_parameter("selected", enemy.shield_flash * 0.8)
	if body.has_meta("bridge"):
		sync_bridge(body, nuclei[0] - enemy.nucleus, nuclei[1] - enemy.nucleus, time, movement, enemy.is_boss(), enemy.hit_flash)
		body.get_meta("bridge").modulate.a = lerpf(0.28, 1.0, smoothstep(0.0, 1.0, arrival))

func sync_bridge(body: Node2D, first: Vector2, second: Vector2, time: float, movement: float, boss: bool, pulse: float) -> void:
	var bridge: ColorRect = body.get_meta("bridge")
	var bounds := Rect2(first, Vector2.ZERO).expand(second).grow(35.0)
	bridge.position = bounds.position
	bridge.size = bounds.size
	bridge.material.set_shader_parameter("bounds_size", bounds.size)
	bridge.material.set_shader_parameter("first", first - bounds.position)
	bridge.material.set_shader_parameter("second", second - bounds.position)
	bridge.material.set_shader_parameter("width", 18.0 if boss else 6.0)
	bridge.material.set_shader_parameter("clock", time)
	bridge.material.set_shader_parameter("motion", movement)
	bridge.material.set_shader_parameter("boss", 1.0 if boss else 0.0)
	bridge.material.set_shader_parameter("pulse", pulse)
