extends SceneTree

const Run = preload("res://scripts/run_controller.gd")
const Enemy = preload("res://scripts/drifter.gd")
const Mutations = preload("res://scripts/mutations.gd")
const Resolver = preload("res://scripts/loop_resolver.gd")
const Records = preload("res://scripts/records.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("exercise")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func midpoint(run: RefCounted, path: Array) -> Vector2:
	var result := Vector2.ZERO
	for id in path:
		result += run.board.anchors[id]
	return result / path.size()

func capture(run: RefCounted, path: Array) -> Dictionary:
	run.selection.start(run.board.anchors[path[0]])
	for id in path.slice(1):
		run.selection.visit(id)
	run.selection.visit(path[0])
	return run.release()

func exercise() -> void:
	var run := Run.new(false)
	var short_loop := [0, 8, 9]
	var shell := Enemy.new(1, midpoint(run, short_loop), 6.0, "shellback")
	run.enemies = [shell]
	run.encounter.spawned = 1
	var result := capture(run, short_loop)
	expect(result.ids == [1] and shell.health == 1 and run.score == 0 and run.kills == 0, "First Shellback capture removes armor but awards no kill")
	expect(shell.stunned > 0.0 and result.armor_hits == 1 and result.positions.is_empty(), "Armor hit stuns its surviving body without creating a digestion ghost")
	var before: Vector2 = shell.nucleus
	shell.step(0.5, run.board.center)
	expect(shell.nucleus == before, "A surviving armored enemy pauses to allow a second route")
	run.step_recovery(3.0)
	result = capture(run, short_loop)
	expect(run.enemies.is_empty() and result.points == 200 and run.encounter.resolved == 1, "Second capture kills and scores a Shellback exactly once")
	var square := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	var pair := {"position": Vector2(80, 50), "health": 1, "nuclei": [Vector2(50, 50), Vector2(110, 50)]}
	expect(not Resolver.enclosed(pair, square), "One enclosed Twinspore nucleus is insufficient")
	pair.nuclei[1] = Vector2(100, 50)
	expect(Resolver.enclosed(pair, square), "Both nuclei use the shared boundary-inclusive capture rule")
	run.restart()
	run.add_mutation("frenzy")
	var twin := Enemy.new(2, midpoint(run, short_loop), 0.0, "twinspore")
	twin.pair_span = 8.0
	run.enemies = [twin, Enemy.new(3, midpoint(run, short_loop), 0.0)]
	run.encounter.spawned = 2
	result = capture(run, short_loop)
	expect(result.kills == 2 and result.bodies == 3 and run.kills == 2, "A pair counts as one scoring group and two eaten bodies")
	expect(result.points == 438 and run.score == 438, "Multi-capture bonus uses groups, not Twinspore nuclei")
	expect(run.is_ready(0) and not run.is_ready(8) and not run.is_ready(9), "Feeding Frenzy restores only the starting cell")
	expect(run.clot_for(0) == null and run.clots[0].nodes == [8, 9], "The restored start stays at its selectable home while other cells clot")
	run.step_recovery(1.5)
	expect(not run.clots.is_empty() and run.clots[0].progress() > 0.4, "Frenzy does not prematurely finish the other members' digestion")
	run.step_recovery(1.5)
	expect(run.clots.is_empty() and run.is_ready(8), "Frenzy members still return on their own recovery clock")
	run.restart()
	for id in ["fission", "elastic", "enzyme"]:
		run.add_mutation(id)
	expect(is_equal_approx(Mutations.recovery(run.mutations, 3), 2.6), "Short-loop override precedes additive recovery costs")
	expect(is_equal_approx(Mutations.recovery(run.mutations, 6), 4.8), "Large-loop power and reach costs compose consistently")
	expect(run.selection.max_vertices == 10 and not run.add_mutation("elastic"), "Elastic increases the input limit and cannot be taken twice")
	var large := [0, 8, 16, 17, 9, 1]
	run.enemies = [Enemy.new(4, midpoint(run, large), 0.0, "shellback")]
	result = capture(run, large)
	expect(result.valid and result.points == 200 and run.enemies.is_empty(), "A six-cell enzyme loop digests an armored enemy in one pulse")
	run.step_recovery(5.0)
	var ten_loop := [0, 8, 16, 17, 18, 19, 11, 3, 2, 1]
	result = capture(run, ten_loop)
	expect(result.valid and result.nodes.size() == 10 and run.clots[0].nodes.size() == 10, "Elastic accepts and commits a real ten-cell membrane")
	run.step_recovery(4.8)
	expect(run.clots.is_empty() and ten_loop.all(func(id): return run.is_ready(id)), "All ten cells return on the same mutation recovery clock")
	run.restart()
	for i in 6:
		run.enemies.append(Enemy.new(i + 1, midpoint(run, short_loop), 0.0))
	result = capture(run, short_loop)
	expect(result.points == 1200 and result.kills == 6, "Multi-capture bonus caps at 100 percent")
	run.restart()
	run.add_mutation("lure")
	var outside: Vector2 = run.board.anchors[0] + Vector2(0, 25)
	var visitor := Enemy.new(7, outside, 0.0)
	run.enemies = [visitor]
	result = capture(run, short_loop)
	expect(result.ids.is_empty() and run.kills == 0 and visitor.health == 1, "Lure cannot turn displacement into an automatic capture")
	visitor.step(0.7, run.board.center)
	expect(visitor.nucleus != outside and visitor.nucleus.distance_to(outside) <= 45.001, "Nearby ordinary enemies are drawn at most 45 pixels")
	run.restart()
	run.add_mutation("residual")
	capture(run, short_loop)
	expect(run.residuals.size() == 1 and run.residuals[0].remaining == 1.5, "Residual membrane has a finite lifetime")
	run.step(1.6)
	expect(run.residuals.is_empty(), "Residual membrane expires rather than permanently blocking the dish")
	run.restart()
	var crossing := Enemy.new(8, Vector2(711, 450), 10.0)
	run.enemies = [crossing]
	run.residuals = [{"polygon": PackedVector2Array([Vector2(700, 430), Vector2(710, 430), Vector2(710, 470), Vector2(700, 470)]), "remaining": 1.5}]
	run.step(0.2)
	expect(is_equal_approx(crossing.slowed, 1.0), "Crossing an active residual boundary starts the one-second slow")
	var crossing_before: Vector2 = crossing.nucleus
	run.step(0.25)
	expect(is_equal_approx(crossing_before.distance_to(crossing.nucleus), 1.5), "Residual slow reduces real displacement by forty percent")
	var rng := RandomNumberGenerator.new()
	rng.seed = 108
	var chosen: Array = []
	for i in 3:
		var offers := Mutations.offers(chosen, rng)
		expect(offers.size() == 3 and not offers.any(func(id): return chosen.has(id)), "Choice %d offers three unchosen mutations" % (i + 1))
		chosen.append(offers[0])
	var records := Records.new()
	records.path = "user://records-test.cfg"
	run.score = 4125
	run.best_capture = 3
	run.state = "success"
	records.record(run)
	var loaded := Records.new()
	loaded.path = records.path
	loaded.load_records()
	expect(loaded.best_score == 4125 and loaded.best_capture == 3 and loaded.runs == 1 and loaded.victories == 1, "Run records survive a save and fresh load")
	run.score = 900
	run.state = "loss"
	loaded.record(run)
	expect(loaded.best_score == 4125 and loaded.victories == 1 and loaded.runs == 2 and not loaded.new_record, "A lower loss keeps the personal best and victory count")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(records.path))
	run.dispose()
	print("EVOLUTION RULES: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
