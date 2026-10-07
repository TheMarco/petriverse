extends RefCounted

const Clot = preload("res://scripts/clot.gd")
const MotherDamage = preload("res://scripts/mother_damage.gd")
const Board = preload("res://scripts/board.gd")
const Cell = preload("res://scripts/cell.gd")
const Drifter = preload("res://scripts/drifter.gd")
const Encounter = preload("res://scripts/encounter.gd")
const Selection = preload("res://scripts/input_controller.gd")
const Resolver = preload("res://scripts/loop_resolver.gd")
const Mutations = preload("res://scripts/mutations.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
const Plan = preload("res://scripts/run_plan.gd")
const Harvest = preload("res://scripts/harvest.gd")
const JourneyHarvest = preload("res://scripts/journey_harvest.gd")
const JourneyPlan = preload("res://scripts/journey_plan.gd")
const JourneyRoute = preload("res://scripts/journey_route.gd")
const Lesson = preload("res://scripts/journey_lesson.gd")
const Mastery = preload("res://scripts/journey_mastery.gd")
const Habitats = preload("res://scripts/journey_habitats.gd")
const JourneySave = preload("res://scripts/journey_save.gd")
const Conjoined = preload("res://scripts/conjoined.gd")
const CystNudge = preload("res://scripts/cyst_nudge.gd")
const Fluid = preload("res://scripts/fluid_field.gd")
const Amoebas = preload("res://scripts/amoeba_system.gd")
const Phages = preload("res://scripts/phage_system.gd")
const ACTIVE := "active"
const PAUSED := "paused"
const SUCCESS := "success"
const LOSS := "loss"
const EVOLVE := "evolve"
const BRIEF := "brief"
const HOME := "home"

var board = Board.new()
var fluid = Fluid.new()
var water_positions := {}
var amoebas = Amoebas.new()
var phages = Phages.new()
var cells: Array = []
var enemies: Array = []
var encounter: RefCounted
var selection: RefCounted
var state := ACTIVE
var score := 0
var integrity := 5
var kills := 0
var elapsed := 0.0
var last_contacts: Array = []
var contact_time := -100.0
var last_capture: Dictionary = {}
var capture_serial := 0
var clots: Array = []
var mother_damage: RefCounted
var mutations: Array = []
var residuals: Array = []
var best_capture := 0
var loops_drawn := 0
var lesson_step := -1
var lesson_nodes: Array = []
var journey := false
var stage_elapsed := 0.0
var biomass := 0
var total_food := 0
var total_rescued := 0
var rescued_specimens: Array = []
var mastery_awards: Array = []
var habitat_choice := "bloom"
var habitat_confirmed := false
var habitat_applied := false
var habitat_history: Dictionary = {}
var completed_dishes := 0
var colony_id := "wanderer"
var checkpoint: Dictionary = {}
var journey_serial := 0
var retries := 0
var harvest_mode := false
var harvest: RefCounted
var full_run := true
var stage_index := 0
var offered_mutations: Array = []
var rng := RandomNumberGenerator.new()
var run_seed := 0
var fixed_seed := 0
var next_enemy_id := 0
var boss_defeated := false
var seen_species: Array = ["drifter"]
var discovery_serial := 0
var last_discovery := ""
var nudge = CystNudge.new()
var long_journey := false
var route_plan: Array = []
var route_position := 0
var expedition_roster: Array = []
var discovery_history: Array = []

func _init(campaign: bool = true, seed_value: int = 0, risky_harvest: bool = false, connected_journey: bool = false) -> void:
	journey = connected_journey
	harvest_mode = risky_harvest or journey
	full_run = journey or (campaign and not risky_harvest)
	fixed_seed = seed_value
	restart()

func restart() -> void:
	amoebas.reset()
	phages = Phages.new()
	water_positions.clear()
	nudge = CystNudge.new()
	if journey:
		board = Board.new()
	stage_elapsed = 0.0
	biomass = 0
	total_food = 0
	total_rescued = 0
	rescued_specimens.clear()
	mastery_awards.clear()
	habitat_history.clear()
	completed_dishes = 0
	retries = 0
	checkpoint.clear()
	board.reset_motion()
	mutations.clear()
	residuals.clear()
	best_capture = 0
	loops_drawn = 0
	stage_index = 0
	next_enemy_id = 0
	boss_defeated = false
	seen_species = ["drifter"]
	discovery_serial = 0
	last_discovery = ""
	offered_mutations.clear()
	if fixed_seed == 0:
		rng.randomize()
	else:
		rng.seed = fixed_seed
	run_seed = rng.seed
	fluid.reset(board.center,board.dish_radius,run_seed)
	route_position = 0
	route_plan = JourneyRoute.make(run_seed) if journey and long_journey else []
	expedition_roster = preload("res://scripts/expedition_creatures.gd").plan(run_seed,route_plan,discovery_history)
	mother_damage = MotherDamage.new()
	clots.clear()
	cells.clear()
	for _i in board.anchors.size():
		cells.append(Cell.new())
	enemies.clear()
	encounter = Encounter.new(board.tuning)
	# The bound Callable references this object; reuse selection without retaining
	# abandoned controllers on restart. dispose() clears it when the owner exits.
	if selection == null:
		selection = Selection.new(board, is_ready)
	selection.board = board
	selection.cancel()
	selection.max_vertices = 8
	state = ACTIVE
	score = 0
	kills = 0
	integrity = int(board.tuning.mother_integrity)
	elapsed = 0.0
	last_contacts.clear()
	contact_time = -100.0
	last_capture.clear()
	capture_serial = 0
	harvest = Harvest.new() if harvest_mode else null
	if journey:
		for colony in JourneyPlan.COLONIES:
			if colony.id == colony_id and not colony.trait.is_empty():
				add_mutation(colony.trait)
		start_stage()
	elif harvest != null:
		harvest.begin(self)
	elif full_run:
		start_stage()

func start_stage() -> void:
	if journey:
		start_journey_stage()
		return
	selection.cancel()
	residuals.clear()
	state = ACTIVE
	if stage_index < 3:
		encounter = Encounter.new(board.tuning, Plan.encounter(stage_index, rng.randi_range(0, 7) * 45.0))
	else:
		# Boss summons are tracked for the HUD, but do not gate victory.
		encounter = Encounter.new(board.tuning)
		encounter.budget = 0
		next_enemy_id += 1
		enemies.append(Conjoined.new(next_enemy_id, board))

func evolution_ready() -> bool:
	return state == EVOLVE and clots.is_empty() and not mother_damage.active()

func choose_mutation(id: String) -> bool:
	if journey:
		return choose_journey_evolution(id)
	if not evolution_ready() or not offered_mutations.has(id) or not add_mutation(id):
		return false
	offered_mutations.clear()
	stage_index += 1
	start_stage()
	return true

func boss() -> RefCounted:
	for enemy in enemies:
		if enemy.is_boss():
			return enemy
	return null

func dispose() -> void:
	selection.ready = Callable()

func is_ready(id: int) -> bool:
	return id >= 0 and id < cells.size() and cells[id].is_ready() and not (journey and harvest != null and harvest.ecology.blocked(self,id))

func target_snapshot() -> Array:
	var snapshot: Array = []
	for enemy in enemies:
		snapshot.append({"id": enemy.id, "position": enemy.nucleus, "nuclei": enemy.nuclei(), "health": enemy.health, "kind": enemy.kind, "eligible": enemy.can_take_pulse()})
	return snapshot

func preview() -> Array:
	if state != ACTIVE or not selection.can_close():
		return []
	return Resolver.targets(selection.path, board, is_ready, target_snapshot(), selection.max_vertices)

func critical_nuclei() -> PackedVector2Array:
	var result := PackedVector2Array()
	if integrity > 2 or state not in [ACTIVE, PAUSED]:
		return result
	for enemy in enemies:
		if enemy.is_boss() or enemy.kind in ["food", "cyst", "spore", "grazer", "parasite", "warden", "amoeba", "bacterium"]:
			continue
		for nucleus in enemy.nuclei():
			if nucleus.distance_to(board.center) < 135.0:
				result.append(nucleus)
	return result

func preview_warning() -> String:
	if not selection.can_close():
		return ""
	var polygon := Geometry.polygon_for(selection.path, board.anchors)
	for enemy in enemies:
		if enemy.nuclei().size() != 2:
			continue
		var inside := 0
		for nucleus in enemy.nuclei():
			if Geometry.contains(nucleus, polygon):
				inside += 1
		if inside > 0 and not enemy.can_take_pulse():
			return "The body is reforming"
		if inside == 1:
			return "Fit both glowing nuclei"
	return ""

func add_mutation(id: String) -> bool:
	if mutations.has(id) or Mutations.definition(id).is_empty():
		return false
	mutations.append(id)
	selection.max_vertices = Mutations.maximum(mutations)
	return true

func release() -> Dictionary:
	var path: Array = selection.release()
	var result := Resolver.commit(path, self)
	if result.valid:
		last_capture = result
		capture_serial += 1
		clots.append(Clot.new(capture_serial, result, cells, board.center))
		Lesson.record(self, result)
		check_completion()
	return result

func toggle_pause() -> void:
	if state == ACTIVE:
		selection.cancel()
		nudge.cancel()
		state = PAUSED
	elif state == PAUSED:
		state = ACTIVE

func clot_for(id: int) -> RefCounted:
	for clot in clots:
		if clot.nodes.has(id):
			return clot
	return null

func step_recovery(delta: float) -> void:
	for cell in cells:
		cell.step(delta)
	clots = clots.filter(func(clot): return not clot.finished())

func step(delta: float) -> void:
	if state != ACTIVE:
		nudge.cancel()
		if state in [HOME,BRIEF]:
			fluid.sources.clear()
			fluid.step(delta)
		# Finish recovery and injury aftermath after the encounter. Combat and
		# node drift stay stopped; an explicit pause freezes both effects as well.
		if state in [SUCCESS, LOSS, EVOLVE] and (not clots.is_empty() or mother_damage.active() or not amoebas.releases.is_empty() or not phages.bursts.is_empty()):
			step_water(delta)
			amoebas.step_returns(delta)
			phages.aftermath(delta)
			step_recovery(delta)
			mother_damage.step(delta)
		return
	if harvest != null:
		delta = minf(delta, maxf(0.0, (float(harvest.spec.duration) - stage_elapsed) if journey else (Harvest.DURATION - elapsed)))
	elapsed += delta
	nudge.step(delta,self)
	if not Lesson.active(self):
		stage_elapsed += delta
	var held: Array = selection.path.duplicate()
	for i in cells.size():
		if not cells[i].is_ready():
			held.append(i)
	if Lesson.active(self):
		held.append_array(Lesson.WIDE)
	step_water(delta)
	board.step_motion(delta, held, fluid)
	step_recovery(delta)
	mother_damage.step(delta)
	for enemy in enemies:
		var previous: PackedVector2Array = enemy.nuclei()
		var destination: Vector2 = harvest.ecology.hunt_destination(self,enemy) if journey else board.center
		enemy.step(delta, destination)
		advect_body(enemy,delta)
		if not enemy.is_boss():
			for membrane in residuals:
				var current: PackedVector2Array = enemy.nuclei()
				for i in current.size():
					for j in membrane.polygon.size():
						if Geometry.segments_intersect(previous[i], current[i], membrane.polygon[j], membrane.polygon[(j + 1) % membrane.polygon.size()]):
							enemy.slowed = 1.0
	for membrane in residuals:
		membrane.remaining -= delta
	residuals = residuals.filter(func(membrane): return membrane.remaining > 0.0)
	resolve_contacts()
	if state != ACTIVE:
		return
	if harvest != null:
		harvest.step(self)
	elif full_run and stage_index == 3:
		var predator := boss()
		if predator != null and predator.attack_due() and enemies.size() < 7:
			for i in 2:
				var angle: float = predator.cycle_index() * 137.5 + i * 32.0
				var outward: Vector2 = (predator.nucleus - board.center).normalized()
				var origin: Vector2 = predator.nucleus + outward.orthogonal() * (38.0 if i == 0 else -38.0)
				spawn_enemy({"angle": angle, "radius": 343.0, "position": origin, "speed": 7.2, "kind": "drifter"})
				encounter.spawned += 1
				encounter.budget += 1
	elif encounter.step(delta, enemies.size()):
		if not encounter.last_spawn.is_empty():
			spawn_enemy(encounter.last_spawn)
		else:
			var id: int = encounter.spawned
			var speed_offset: float = float((id - 1) % 3) * 0.5 * board.tuning.get("enemy_speed_spread", 3.0)
			spawn_enemy({"angle": float(board.spawn_angles[(id - 1) % board.spawn_angles.size()]), "radius": board.dish_radius - 15.0, "speed": board.tuning.enemy_speed + speed_offset, "kind": "drifter"})
	check_completion()

func step_water(delta: float) -> void:
	fluid.sources.clear()
	phages.water_sources(self)
	if nudge.cooldown>0.0 and nudge.ripple_vector.length_squared()>0.0:
		var age: float = nudge.COOLDOWN-nudge.cooldown
		if age<1.7:
			var strength := sin(age/1.7*PI)
			fluid.sources.append(Vector4(nudge.ripple_origin.x,nudge.ripple_origin.y,12.0*strength,5.0*strength))
	for clot in clots:
		var p: float = clot.progress()
		var envelope := sin(p*PI)
		fluid.sources.append(Vector4(clot.center.x,clot.center.y,lerpf(-22.0,18.0,smoothstep(0.5,0.9,p))*envelope,9.0*envelope))
	# Tissue and swimming organisms push small local wakes into the shared water.
	# These forces do not pull targets toward the pointer or change capture rules.
	for i in board.anchors.size():
		if cells[i].is_ready() and not selection.path.has(i):
			fluid.stroke(board.anchors[i]-board.velocities[i]*delta,board.anchors[i],0.12)
	var moving := {}
	for body in enemies:
		# Use actual displacement: drifting food, swimming hunters and an
		# amoeba's approach all displace water; resting creatures do not.
		var previous: Vector2 = water_positions.get(body.id,body.nucleus)
		var movement: Vector2 = body.nucleus-previous
		moving[body.id] = body.nucleus
		if delta>0.0 and movement.length()<12.0 and body.age>2.5:
			fluid.stroke(previous,body.nucleus,0.85)
			var velocity := movement/maxf(delta,0.001)
			if velocity.length()>1.0:
				var direction := velocity.normalized()
				var rear: Vector2 = body.nucleus-direction*24.0
				var strength := minf(velocity.length(),12.0)*1.1
				for side in [-1.0,1.0]:
					var at: Vector2 = rear+direction.orthogonal()*float(side)*18.0
					fluid.sources.append(Vector4(at.x,at.y,0.0,strength*side))
		if body.kind=="amoeba" and body.phase in ["reaching","digesting"]:
			var at: Vector2 = body.reach_point if body.phase=="reaching" else body.captive_position()
			var force: float = -8.0*sin(clampf(body.reach_age/2.8,0.0,1.0)*PI) if body.phase=="reaching" else -12.0*(1.0-smoothstep(0.0,1.5,body.digestion_age))
			fluid.sources.append(Vector4(at.x,at.y,force,force*0.25))
	water_positions = moving
	fluid.step(delta)

func advect_body(body: RefCounted, delta: float) -> void:
	if Lesson.active(self) or body.is_boss() or body.kind in ["bell_bud","warden","parasite","amoeba"] or not body.gate_ids.is_empty(): return
	var movement := Vector2.ZERO
	if body.kind in ["food","cyst","spore"]:
		movement = (fluid.sample(body.nucleus)*0.18).limit_length(1.2)*delta
	elif body.speed>0.0 and body.stunned<=0.0:
		movement = (fluid.sample(body.nucleus)*0.04).limit_length(minf(0.45,body.speed*0.08))*delta
	var candidate: Vector2 = body.nucleus+movement
	if candidate.distance_to(board.center)>board.dish_radius-25.0: return
	body.advect(movement)

func spawn_enemy(specification: Dictionary) -> void:
	next_enemy_id += 1
	var angle := deg_to_rad(float(specification.angle))
	var position: Vector2 = specification.get("position", board.center + Vector2.from_angle(angle) * float(specification.radius))
	var enemy := Drifter.new(next_enemy_id, position, float(specification.speed), specification.kind)
	discover(enemy.kind)
	if specification.has("form") and preload("res://scripts/creature_forms.gd").valid_form(specification.form,enemy.kind):
		enemy.form = specification.form
	else:
		preload("res://scripts/creature_forms.gd").assign(self, enemy)
	enemy.pair_angle = angle + PI * 0.5
	enemies.append(enemy)

func resolve_contacts() -> void:
	var contacts: Array = []
	for enemy in enemies:
		if enemy.health > 0 and not enemy.is_boss() and enemy.kind not in ["food", "cyst", "spore", "grazer", "parasite", "warden", "amoeba", "bacterium"]:
			for nucleus in enemy.nuclei():
				if nucleus.distance_to(board.center) <= board.mother_radius + 10.0:
					contacts.append(enemy.id)
					break
	if contacts.is_empty():
		return
	# Batch all contacts, even when more arrive than remaining integrity.
	contacts.sort()
	mother_damage.prepare_integrity(integrity)
	for id in contacts:
		for enemy in enemies:
			if enemy.id == id:
				var sites: PackedVector2Array = enemy.nuclei()
				var contact: Vector2 = sites[0]
				for site in sites:
					if site.distance_squared_to(board.center) < contact.distance_squared_to(board.center):
						contact = site
				mother_damage.record(id, contact, board.center, enemy.kind, sites, enemy.health, enemy.form)
				break
	last_contacts = contacts
	contact_time = elapsed
	integrity = maxi(0, integrity - contacts.size())
	enemies = enemies.filter(func(enemy): return not contacts.has(enemy.id))
	encounter.resolved += contacts.size()
	if integrity == 0:
		state = LOSS
		if harvest != null:
			harvest.loss_title = "The mother was eaten."
			harvest.loss_reason = "A hunter reached the center and consumed her last organelle."
		selection.cancel()

func harvest_preview() -> Dictionary:
	if journey:
		return harvest.outcome(preview(), self)
	return harvest.consequences(preview(), target_snapshot()) if harvest != null else {}

func check_completion() -> void:
	if harvest != null and state == ACTIVE:
		harvest.check_completion(self)
		return
	if state != ACTIVE or integrity <= 0:
		return
	if full_run and stage_index == 3:
		if boss_defeated:
			state = SUCCESS
			score += integrity * 200
			enemies.clear()
			selection.cancel()
	elif encounter.is_complete() and enemies.is_empty():
		selection.cancel()
		if full_run:
			state = EVOLVE
			offered_mutations = Mutations.offers(mutations, rng)
		else:
			state = SUCCESS

func discover(kind: String) -> void:
	if not seen_species.has(kind):
		seen_species.append(kind)
		last_discovery = kind
		discovery_serial += 1

func heal(amount: int) -> void:
	var restored := mini(amount, 5 - integrity)
	integrity += restored
	for i in 5:
		if restored > 0 and mother_damage.lost[i]:
			mother_damage.lost[i] = false
			mother_damage.bites = mother_damage.bites.filter(func(b): return b.core != i)
			restored -= 1

func start_journey_stage() -> void:
	amoebas.reset()
	phages.reset()
	water_positions.clear()
	nudge.reset_encounter()
	habitat_choice = "bloom"
	habitat_confirmed = false
	habitat_applied = false
	lesson_step = -1
	lesson_nodes.clear()
	selection.cancel()
	enemies.clear()
	clots.clear()
	residuals.clear()
	stage_elapsed = 0.0
	boss_defeated = false
	for cell in cells:
		cell.remaining = 0.0
		cell.captor = -1
		cell.lost = false
	board = Board.new()
	board.configure_dish(stage_index / 4)
	fluid.reset(board.center,board.dish_radius,appearance_seed() ^ (stage_index*48271))
	selection.board = board
	selection.max_vertices = Mutations.maximum(mutations)
	harvest = JourneyHarvest.new()
	harvest.spec = route_plan[route_position].duplicate(true) if not route_plan.is_empty() else JourneyPlan.stage(stage_index)
	harvest.begin(self)
	encounter = Encounter.new(board.tuning)
	encounter.budget = int(harvest.spec.threats)
	state = BRIEF
	journey_serial += 1
	checkpoint = JourneySave.capture(self)

func begin_encounter() -> bool:
	if state != BRIEF:
		return false
	Habitats.enter(self)
	state = ACTIVE
	journey_serial += 1
	return true

func finish_journey_stage() -> void:
	selection.cancel()
	amoebas.release_all(self)
	Mastery.complete(self)
	score += integrity * 50
	if stage_index % 4 == 3:
		completed_dishes = maxi(completed_dishes, stage_index / 4 + 1)
	if stage_index == JourneyPlan.STAGES.size() - 1:
		state = SUCCESS
		score += integrity * 200
		enemies.clear()
	else:
		state = EVOLVE
		offered_mutations = Mutations.journey_offers(mutations, rng, stage_index >= 2)
		if not route_plan.is_empty() and (harvest.spec.get("generated",false) or mutations.size()>=JourneyRoute.MAX_TRAITS):
			offered_mutations.clear()
	journey_serial += 1

func evolution_cost() -> int:
	return mini(24,6+2*mutations.size())

func repair_cost() -> int:
	return 6

func bank_food(amount: int) -> void:
	# Previously saved stores above capacity remain available to spend.
	# Excess intake still advances the encounter and score.
	if biomass<30:
		biomass = mini(30,biomass+amount)

func choose_journey_evolution(id: String) -> bool:
	if not evolution_ready():
		return false
	if id == "repair":
		if biomass < repair_cost() or integrity >= 5:
			return false
		biomass -= repair_cost()
		heal(2)
	elif id != "continue":
		var price := evolution_cost()
		if biomass < price or not offered_mutations.has(id) or not add_mutation(id):
			return false
		biomass -= price
	offered_mutations.clear()
	if not route_plan.is_empty():
		route_position += 1
		stage_index = int(route_plan[route_position].stage)
	else:
		stage_index += 1
	start_stage()
	return true

func encounter_index() -> int:
	return route_position if not route_plan.is_empty() else stage_index

func encounter_total() -> int:
	return route_plan.size() if not route_plan.is_empty() else JourneyPlan.STAGES.size()

func encounter_key() -> String:
	return "route:%d" % route_position if not route_plan.is_empty() else str(stage_index)

func next_encounter_name() -> String:
	if not route_plan.is_empty():
		return route_plan[mini(route_position+1,route_plan.size()-1)].name
	return JourneyPlan.stage(stage_index+1).name

func appearance_seed() -> int:
	return run_seed ^ ((route_position+1)*0x119de1f3) if not route_plan.is_empty() else run_seed

func retry_encounter() -> bool:
	if not journey or state != LOSS or checkpoint.is_empty():
		return false
	var attempts := retries + 1
	var saved_checkpoint := checkpoint.duplicate(true)
	JourneySave.restore(self, saved_checkpoint)
	checkpoint = saved_checkpoint
	retries = attempts
	# A damaged entry never traps the player in an unwinnable retry loop.
	heal(maxi(0, 3 - integrity))
	state = BRIEF
	journey_serial += 1
	return true
