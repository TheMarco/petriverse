extends RefCounted
## A small, separate experiment. The campaign and its progression stay intact.
const Organism = preload("res://scripts/harvest_organism.gd")
const DURATION := 120.0
const GOAL := 18
var nourishment := 0
var poison_taken := 0
var next_bloom := 9.0
var next_threat := 20.0
var blooms := 0
var rotation := 0
var loss_reason := ""
var loss_title := "The mother died."

func begin(run: RefCounted) -> void:
	rotation = run.rng.randi_range(0, 7)
	for sector in [0, 3, 6]:
		spawn_bloom(run, (sector + rotation) % 8)

func spawn_bloom(run: RefCounted, sector: int) -> void:
	var next := (sector + 1) % 8
	var a: Vector2 = run.board.anchors[sector]
	var b: Vector2 = run.board.anchors[8 + sector]
	var c: Vector2 = run.board.anchors[8 + next]
	var d: Vector2 = run.board.anchors[next]
	var phase: float = run.rng.randf_range(0.0, TAU)
	# Three readable snacks start inside a real neighboring triangle. The richer
	# second pocket shares its edge, so a wider loop trades health for extra food.
	# Position relative to the live cells, not an unrelated cloud around a node.
	var rich_center := (a + c + d) / 3.0
	var outward: Vector2 = (rich_center - run.board.center).normalized()
	var tangent: Vector2 = outward.orthogonal()
	var sites := [a * 0.25 + b * 0.45 + c * 0.30,
		a * 0.25 + b * 0.23 + c * 0.52,
		a * 0.48 + b * 0.26 + c * 0.26,
		rich_center + tangent * 26.0 - outward * 9.0,
		rich_center - tangent * 25.0 - outward * 8.0,
		rich_center + tangent * 6.0,
		rich_center - tangent * 13.0 + outward * 10.0]
	for i in sites.size():
		run.next_enemy_id += 1
		var kind := "food" if i < 5 else "cyst"
		var drift := Vector2(8.0, 6.0) if i < 3 else Vector2(16.0, 13.0)
		var body := Organism.new(run.next_enemy_id, kind, sites[i], drift, phase + i * 1.71)
		run.enemies.append(body)
	blooms += 1

func step(run: RefCounted) -> void:
	run.enemies = run.enemies.filter(func(body): return body.kind not in ["food", "cyst"] or body.age < Organism.LIFETIME)
	while run.elapsed >= next_bloom and next_bloom < DURATION - 12.0:
		spawn_bloom(run, (rotation + blooms * 3 + 1) % 8)
		next_bloom += 9.0
	while run.elapsed >= next_threat and next_threat < DURATION - 17.0:
		var sector := (rotation + int(next_threat / 17.0) * 3) % 8
		var direction: Vector2 = (run.board.rest_anchors[8 + sector] - run.board.center).normalized()
		run.spawn_enemy({"angle": rad_to_deg(direction.angle()), "radius": 278.0, "speed": 8.0, "kind": "drifter"})
		next_threat += 17.0

func consequences(ids: Array, snapshot: Array) -> Dictionary:
	var result := {"food": 0, "poison": 0, "threats": 0}
	for target in snapshot:
		if ids.has(target.id):
			if target.kind == "food":
				result.food += 1
			elif target.kind == "cyst":
				result.poison += 1
			else:
				result.threats += 1
	return result

func commit(path: Array, polygon: PackedVector2Array, ids: Array, recovery: float, run: RefCounted) -> Dictionary:
	var outcome := consequences(ids, run.target_snapshot())
	var positions: Array = []
	var kinds: Array = []
	run.mother_damage.prepare_integrity(run.integrity)
	for body in run.enemies:
		if not ids.has(body.id):
			continue
		positions.append(body.nucleus)
		kinds.append(body.kind)
		if body.kind == "cyst":
			# Poison enters through the feeding current; no remote predator bite.
			var origin: Vector2 = run.board.center + (body.nucleus - run.board.center).normalized() * 43.0
			run.mother_damage.record(body.id, origin, run.board.center, "cyst", PackedVector2Array([origin]))
	nourishment = mini(GOAL, nourishment + outcome.food)
	poison_taken += outcome.poison
	run.integrity = maxi(0, run.integrity - outcome.poison)
	run.enemies = run.enemies.filter(func(body): return not ids.has(body.id))
	run.kills += outcome.food + outcome.threats
	run.best_capture = maxi(run.best_capture, outcome.food)
	run.loops_drawn += 1
	return {"valid": true, "ids": ids, "points": 0, "polygon": polygon,
		"positions": positions, "prey_kinds": kinds, "nodes": path.duplicate(),
		"kills": outcome.food + outcome.threats, "bodies": ids.size(), "armor_hits": 0,
		"boss_layers": 0, "restored_node": -1, "recovery": recovery,
		"food": outcome.food, "poison": outcome.poison, "threats": outcome.threats}

func check_completion(run: RefCounted) -> void:
	if run.integrity <= 0:
		loss_title = "The mother was poisoned."
		loss_reason = "Purple cysts inside your loop consumed her last organelle."
		run.state = run.LOSS
	elif nourishment >= GOAL:
		run.state = run.SUCCESS
	elif run.elapsed >= DURATION:
		loss_title = "Time ran out."
		loss_reason = "Gathered %d / %d food. Reach %d within %d seconds to win." % [nourishment, GOAL, GOAL, int(DURATION)]
		run.state = run.LOSS
	if run.state != run.ACTIVE:
		run.selection.cancel()
