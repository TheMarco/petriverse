extends "res://scripts/harvest.gd"
const Ecology = preload("res://scripts/journey_ecology.gd")
var ecology = Ecology.new()
const Predator = preload("res://scripts/journey_boss.gd")
const MutationRules = preload("res://scripts/mutations.gd")
const Geo = preload("res://scripts/loop_geometry.gd")
const Discoveries = preload("res://scripts/journey_discoveries.gd")
const Mastery = preload("res://scripts/journey_mastery.gd")
const HabitatEvents = preload("res://scripts/habitat_events.gd")
var event_state: Dictionary = {}
var spec: Dictionary = {}
var rescued := 0
var purified := 0
var defended := 0
var visited: Array = []
var clean_food := 0
var threats_spawned := 0
var spores_spawned := 0
var next_spore := 14.0
var tide := 0
var boss_hits := 0
var last_time := 0.0
var visitor_at := -1.0
var visitor_spawned := false

func begin(run: RefCounted) -> void:
	rotation = run.rng.randi_range(0,7)
	var starting_areas: Array = [0,3,6] if run.stage_index==0 else [0] if spec.mode=="boss" else [0,3]
	for area in starting_areas:
		spawn_bloom(run,(rotation+area)%8)
	next_bloom = Ecology.Rhythm.CYCLE if run.stage_index>0 else 18.0
	if spec.mode == "rescue":
		spawn_spore(run)
	if spec.mode == "boss":
		run.next_enemy_id += 1
		run.enemies.append(Predator.new(run.next_enemy_id, run.board, run.stage_index / 4))
		run.discover(run.enemies[-1].kind)
	run.discover("food")
	run.discover("cyst")
	ecology.begin(run)
	Discoveries.begin(run)
	HabitatEvents.begin(run)

func spawn_bloom(run: RefCounted, sector: int) -> void:
	var first: int = run.enemies.size()
	super.spawn_bloom(run, sector)
	for body in run.enemies.slice(first):
		body.bloom_id = blooms
		preload("res://scripts/creature_forms.gd").assign(run, body)
	if spec.get("mode", "") not in ["purify", "boss"]:
		if run.habitat_applied:
			run.Habitats.trim_bloom(run,run.enemies.slice(first))
		return
	# These objectives need separable poison pockets and unobstructed boss
	# routes. Outer triangles make that spatial choice legible at human speed.
	var a: Vector2 = run.board.anchors[8 + sector]
	var b: Vector2 = run.board.anchors[16 + sector]
	var c: Vector2 = run.board.anchors[16 + (sector + 1) % 8]
	for i in 2:
		var body = run.enemies[first + 5 + i]
		body.origin = a * 0.25 + b * (0.48 if i == 0 else 0.27) + c * (0.27 if i == 0 else 0.48)
		body.nucleus = body.origin
		body.drift = Vector2(7, 5)
	if run.habitat_applied:
		run.Habitats.trim_bloom(run,run.enemies.slice(first))

func spawn_spore(run: RefCounted, area: int = -1) -> void:
	var sector := (rotation + spores_spawned * 3 + 1) % 8 if area < 0 else area
	# Rescue is a neighboring opportunity, sharing a blue cell with the food
	# pocket while keeping the pearl visually separate from algae and cysts.
	var a: Vector2 = run.board.anchors[8 + sector]
	var b: Vector2 = run.board.anchors[16 + sector]
	var c: Vector2 = run.board.anchors[16 + (sector + 1) % 8]
	run.next_enemy_id += 1
	var spore := Organism.new(run.next_enemy_id, "spore", (a + b + c) / 3.0, Vector2(5, 4), float(spores_spawned))
	run.enemies.append(spore)
	run.discover("spore")
	preload("res://scripts/creature_forms.gd").assign(run, spore)
	spores_spawned += 1

func step(run: RefCounted) -> void:
	if run.Lesson.active(run):
		run.Lesson.step(run)
		return
	var now: float = run.stage_elapsed
	var delta := now - last_time
	last_time = now
	run.enemies = run.enemies.filter(func(body): return body.kind not in ["food", "cyst", "spore"] or body.age < body.lifetime())
	# Quiet replenishment fills the space between structured bloom encounters.
	# The director supplies the overlapping threat/rescue opportunities.
	while now >= next_bloom and next_bloom < float(spec.duration)-18.0:
		spawn_bloom(run,(rotation+blooms*3+1)%8)
		if spec.mode=="rescue" and rescued<int(spec.target) and run.enemies.filter(func(e): return e.kind=="spore").size()<2:
			spawn_spore(run)
		next_bloom += Ecology.Rhythm.CYCLE if run.stage_index>0 else 26.0
	ecology.step(run,delta)
	Discoveries.step(run,delta)
	HabitatEvents.step(run,delta)
	# Water motion affects real bodies, with a very slow, bounded oscillation.
	if run.stage_index >= 4:
		tide = int(now / 18.0) % 2
		var current := Vector2(0.7 if tide == 0 else -0.7, 0.18 * sin(now * 0.1))
		if run.stage_index >= 8:
			current = Vector2.from_angle(now * 0.025) * 0.65
		for body in run.enemies:
			if body.kind in ["food", "cyst", "spore"]:
				body.origin += current * delta

func outcome(ids: Array, run: RefCounted, loop_size: int = -1) -> Dictionary:
	if loop_size < 0:
		loop_size = run.selection.path.size()
	var result := {"food": 0, "poison": 0, "threats": 0, "rescued": 0, "purified": 0, "raw_food": 0, "filtered": 0, "boss_layers": 0, "wardens": 0, "salvage": 0, "food_bonuses": {}, "cells_rescued": 0}
	var cysts := 0
	for body in run.enemies:
		if not ids.has(body.id):
			continue
		if body.kind == "food":
			result.raw_food += 1
		elif body.kind == "cyst":
			cysts += 1
		elif body.kind == "spore":
			result.rescued += 1
		elif body.kind == "warden":
			result.wardens += 1
		elif body.is_boss():
			if nourishment >= 3 and body.can_take_pulse():
				result.boss_layers += 1
		elif body.health <= MutationRules.damage(run.mutations, loop_size):
			result.threats += 1
			if body.kind=="amoeba" and body.captive_node>=0: result.cells_rescued += 1
			if body.kind in ["grazer","bacterium"]:
				result.salvage += body.stored_food
			result.salvage += body.carried_food
	result.food = result.raw_food + result.salvage
	result.poison = cysts
	if spec.mode == "purify" and result.raw_food == 0 and result.rescued == 0 and result.threats == 0 and ids.size() == cysts:
		result.purified = cysts
		result.poison = 0
	elif run.mutations.has("filter"):
		result.filtered = mini(1, cysts)
		result.poison -= result.filtered
	# Every starting direction has a useful feeding engine immediately. The
	# short-loop and wide-loop rewards cannot stack in the same membrane.
	if run.mutations.has("fission") and loop_size<=4 and result.raw_food>0 and result.poison==0:
		result.food_bonuses.fission = 1
	if run.mutations.has("elastic") and loop_size>=6:
		if result.raw_food>0:
			result.food_bonuses.elastic = result.raw_food
	if run.mutations.has("feast") and result.raw_food >= 4:
		result.food_bonuses.feast = 2
	if run.mutations.has("grazer") and result.raw_food in [1, 2] and result.poison == 0:
		result.food_bonuses.grazer = 1
	if run.mutations.has("symbiosis") and result.threats>0:
		result.food_bonuses.symbiosis = result.threats * 2
	if run.mutations.has("catalyst") and result.purified == 0 and cysts>0:
		result.food_bonuses.catalyst = cysts * 2
	# This ledger drives both the actual award and visible attribution. The
	# preview must never claim a bonus that the committed meal cannot earn.
	for amount in result.food_bonuses.values():
		result.food += amount
	return result

func commit(path: Array, polygon: PackedVector2Array, ids: Array, recovery: float, run: RefCounted) -> Dictionary:
	var result := outcome(ids, run, path.size())
	var positions: Array = []
	var kinds: Array = []
	var forms: Array = []
	var absorbed: Array = []
	var split_hearts: Array = []
	var armor := 0
	var boss_layers := 0
	var poison_left: int = result.poison
	run.mother_damage.prepare_integrity(run.integrity)
	for body in run.enemies:
		if not ids.has(body.id):
			continue
		if body.is_boss():
			if nourishment < 3 or not body.can_take_pulse():
				continue
			nourishment -= 3
			boss_layers += 1
			boss_hits += 1
			if not body.apply_pulse(1):
				if body.variant==2:
					split_hearts.append(body.nucleus)
				continue
			run.boss_defeated = true
		elif body.kind not in ["food", "cyst", "spore"]:
			if not body.apply_pulse(MutationRules.damage(run.mutations, path.size())):
				armor += 1
				continue
		if body.kind == "food":
			var sector := posmod(roundi((body.nucleus - run.board.center).angle() / (TAU / 8.0)), 8)
			if not visited.has(sector):
				visited.append(sector)
		if body.kind == "cyst" and poison_left > 0:
			var origin: Vector2 = run.board.center + (body.nucleus - run.board.center).normalized() * 43.0
			run.mother_damage.record(body.id, origin, run.board.center, "cyst", PackedVector2Array([origin]))
			poison_left -= 1
		if body.kind == "spore":
			var rare: bool = body.visitor or preload("res://scripts/creature_forms.gd").definition(body.form).get("expedition",false)
			run.rescued_specimens.append({"token":"%d:%d:%d" % [run.run_seed,run.stage_index,body.id], "form":body.form, "stage":run.stage_index, "encounter":run.encounter_index()+1, "rare":rare, "story":body.story})
		if body.kind=="amoeba": run.amoebas.rescue(run,body)
		absorbed.append(body.id)
		for p in body.nuclei():
			positions.append(p)
			kinds.append(body.kind)
			forms.append(body.form)
	for at in split_hearts:
		run.next_enemy_id += 1
		var direction: Vector2 = (at-run.board.center).normalized()
		var birthplace: Vector2 = run.board.center+direction*maxf(180.0,at.distance_to(run.board.center))
		var young = run.Drifter.new(run.next_enemy_id,birthplace,5.4,"twinspore")
		# A three-second visible birth gives the player time to register it.
		# These young defend their parent; they do not divert to eat algae.
		young.stunned = 3.0
		young.foraging_done = true
		run.enemies.append(young)
		run.discover("twinspore")
		ecology.announce("Young hearts are hatching nearby · catch both before they reach Mother")
	nourishment += result.food
	if spec.mode == "boss":
		nourishment = mini(6, nourishment)
	run.bank_food(result.food)
	run.total_food += result.food
	poison_taken += result.poison
	run.integrity = maxi(0, run.integrity - result.poison)
	rescued += result.rescued
	purified += result.purified
	defended += result.threats
	run.total_rescued += result.rescued
	result["mastery"] = Mastery.capture(run,absorbed,result.poison)
	run.enemies = run.enemies.filter(func(body): return not absorbed.has(body.id))
	var capture_center := Vector2.ZERO
	for point in polygon:
		capture_center += point/float(polygon.size())
	if not absorbed.is_empty() and run.stage_index>=2:
		ecology.disturb_survivors(run,capture_center)
		ecology.resolve_gates(run)
	run.kills += result.raw_food + result.threats
	run.best_capture = maxi(run.best_capture, result.raw_food)
	run.loops_drawn += 1
	run.score += result.food * 25 + result.threats * 100 + result.rescued * 150 + result.purified * 30 + boss_layers * 300
	if run.mutations.has("nursery") and result.poison == 0:
		clean_food += result.raw_food
		if clean_food >= 12 and run.integrity > 0:
			clean_food -= 12
			run.heal(1)
	var restored := -1
	if run.mutations.has("frenzy") and positions.size() >= 3:
		restored = path[0]
		run.cells[restored].remaining = 0.0
	if run.mutations.has("lure"):
		var center := Vector2.ZERO
		for p in polygon:
			center += p
		center /= polygon.size()
		for body in run.enemies:
			if body.kind != "food":
				continue
			for i in polygon.size():
				if Geo.distance_to_segment(body.nucleus, polygon[i], polygon[(i + 1) % polygon.size()]) < 110.0:
					body.pull_toward(center, 22.0)
					break
	if run.mutations.has("residual"):
		run.residuals.append({"polygon": polygon.duplicate(), "remaining": 4.0})
	result.merge({"valid": true, "ids": ids, "points": result.food * 25, "polygon": polygon, "positions": positions,
		"prey_kinds": kinds, "prey_forms": forms, "nodes": path.duplicate(), "kills": result.raw_food + result.threats,
		"bodies": positions.size(), "armor_hits": armor, "restored_node": restored, "recovery": recovery}, true)
	result.boss_layers = boss_layers
	return result

func objective_count() -> int:
	match spec.mode:
		"rescue": return rescued
		"purify": return purified
		"defend": return defended
		"sectors": return visited.size()
		"boss": return boss_hits
	return nourishment

func objective_label() -> String:
	return {"rescue": "spores rescued", "purify": "cysts neutralized", "defend": "hunters captured", "sectors": "feeding sectors", "boss": "layers dissolved", "feed": "food gathered"}[spec.mode]

func check_completion(run: RefCounted) -> void:
	if run.Lesson.active(run):
		return
	if run.integrity <= 0:
		loss_title = "The mother was poisoned."
		loss_reason = "A mixed meal contained more cysts than the colony could survive."
		run.state = run.LOSS
	elif spec.mode == "boss" and run.boss_defeated:
		run.finish_journey_stage()
	elif spec.mode != "boss" and nourishment >= int(spec.food) and (spec.mode == "feed" or objective_count() >= int(spec.target)):
		run.finish_journey_stage()
	elif run.stage_elapsed >= float(spec.duration):
		loss_title = "The current moved on."
		loss_reason = "The encounter's goals were unfinished. Retry this encounter with your colony intact."
		run.state = run.LOSS
	if run.state != run.ACTIVE:
		run.selection.cancel()
