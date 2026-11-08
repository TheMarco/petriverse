extends SceneTree
const Run = preload("res://scripts/run_controller.gd")
const Drifter = preload("res://scripts/drifter.gd")
const Resolver = preload("res://scripts/loop_resolver.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("exercise")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func select(run: RefCounted, path: Array = [0, 1, 9]) -> void:
	run.selection.start(run.board.anchors[path[0]])
	for id in path.slice(1):
		run.selection.visit(id)
	run.selection.visit(path[0])

func meal(run: RefCounted, food: int, cysts: int) -> void:
	run.enemies.clear()
	var center: Vector2 = (run.board.anchors[0] + run.board.anchors[1] + run.board.anchors[9]) / 3.0
	for i in food + cysts:
		run.enemies.append(Drifter.new(100 + i, center + Vector2(i * 2.0, 0), 0.0, "food" if i < food else "cyst"))

func observed_meal(run: RefCounted) -> Array:
	# Once cells wander freely, the authored bloom triangle is not a permanent
	# route. Choose a clear enclosure from the positions visible now, preferring
	# three cells and using four when no triangle is clear. No future positions
	# are consulted; the subsequent slow gesture is real.
	var best := best_meal(run, 3)
	return best if not best.is_empty() else best_meal(run, 4)

func best_meal(run: RefCounted, size: int) -> Array:
	var best: Array = []
	var best_clearance := 12.0
	var ids: Array = range(run.board.anchors.size())
	for path in combinations(ids, size):
		if size > 3:
			# Trace the four cells around their centroid, as a player would.
			var middle := Vector2.ZERO
			for id in path:
				middle += run.board.anchors[id] / float(size)
			path.sort_custom(func(a, b): return (run.board.anchors[a] - middle).angle() < (run.board.anchors[b] - middle).angle())
		if not Geometry.capture_valid(path,run.board,run.is_ready):
			continue
		var polygon := Geometry.polygon_for(path,run.board.anchors)
		var count: int = path.size()
		var food_clearance: Array[float] = []
		var poison_clearance := INF
		for body in run.enemies:
			var inside := Geometry.contains(body.nucleus,polygon)
			var margin := INF
			for edge in count:
				margin = minf(margin,Geometry.distance_to_segment(body.nucleus,polygon[edge],polygon[(edge+1)%count]))
			if body.kind=="cyst":
				poison_clearance = minf(poison_clearance,0.0 if inside else margin)
			elif body.kind=="food" and inside:
				food_clearance.append(margin)
		if food_clearance.size()<2:
			continue
		food_clearance.sort()
		var clearance := minf(poison_clearance,food_clearance[-2])
		if clearance>best_clearance:
			best_clearance = clearance
			best = path
	return best

func combinations(items: Array, size: int) -> Array:
	if size == 0:
		return [[]]
	var result: Array = []
	for i in items.size() - size + 1:
		for rest in combinations(items.slice(i + 1), size - 1):
			result.append([items[i]] + rest)
	return result

func exercise() -> void:
	var run := Run.new(false, 73, true)
	expect(run.harvest != null and not run.full_run and run.enemies.size() == 21, "Experiment begins directly with three mixed blooms")
	expect(run.enemies.filter(func(e): return e.kind == "food").size() == 15, "Fifteen edible organisms are visible initially")
	select(run, [16,17,18,19,20,21,22,23])
	# Since Mother must stay outside every membrane, the giant ring cannot even close.
	expect(not run.selection.closed and run.selection.mother_blocked(), "One giant outer ring cannot close around Mother, so it is not a dominant harvest strategy")
	run.selection.cancel()
	var initial: Vector2 = run.enemies[0].nucleus
	run.step(2.0)
	expect(initial.distance_to(run.enemies[0].nucleus) > 1.0, "Food really moves in gameplay space")
	run.toggle_pause()
	initial = run.enemies[0].nucleus
	run.step(10.0)
	expect(run.elapsed == 2.0 and run.enemies[0].nucleus == initial, "Pause freezes current and deadline")
	run.restart()
	meal(run, 3, 1)
	select(run)
	var preview: Dictionary = run.harvest_preview()
	expect(preview.food == 3 and preview.poison == 1, "Mixed-loop preview reports exact food and damage")
	var result: Dictionary = run.release()
	expect(result.valid and result.food == preview.food and result.poison == preview.poison, "Release shares preview consequences")
	expect(run.harvest.nourishment == 3 and run.integrity == 4, "Food feeds and a cyst consumes one organelle")
	expect(run.mother_damage.lost.count(true) == 1 and run.mother_damage.bites[0].kind == "cyst", "Poison leaves a persistent biological wound")
	expect(run.clots.size() == 1 and run.clots[0].food == 3 and run.clots[0].poison == 1, "Feeding effect retains both consequences")
	expect([0,1,9].all(func(id): return not run.is_ready(id)), "Harvest spends its drawing cells")
	expect(run.enemies.is_empty() and run.state == Run.ACTIVE, "Empty dish is not experiment victory")
	run.step(3.0)
	expect([0,1,9].all(func(id): return run.is_ready(id)), "Cells return after three seconds")
	run.restart()
	meal(run, 2, 0)
	select(run)
	var changing = Drifter.new(205, run.board.center, 0.0, "cyst")
	run.enemies.append(changing)
	expect(run.harvest_preview().poison == 0, "Outside toxin does not count in closed preview")
	changing.nucleus = run.enemies[0].nucleus
	expect(run.harvest_preview().poison == 1, "Closed preview updates when current carries toxin across boundary")
	var moved_result: Dictionary = run.release()
	expect(moved_result.poison == 1 and run.integrity == 4, "Commit reads live positions rather than cached initial preview")
	run.restart()
	meal(run, 1, 1)
	run.integrity = 1
	run.harvest.nourishment = run.Harvest.GOAL - 1
	select(run)
	run.release()
	expect(run.state == Run.LOSS and run.harvest.nourishment == run.Harvest.GOAL, "Lethal poison takes precedence over a full meal")
	run.restart()
	meal(run, 1, 0)
	run.harvest.nourishment = run.Harvest.GOAL - 1
	run.elapsed = run.Harvest.DURATION - 0.1
	select(run)
	run.release()
	expect(run.state == Run.SUCCESS and run.integrity == 5, "A surviving final mouthful wins before timeout")
	run.step(3.0)
	expect(run.elapsed == run.Harvest.DURATION - 0.1 and run.clots.is_empty(), "Success freezes timer but completes absorption")
	run.restart()
	run.enemies.clear()
	run.harvest.next_bloom = run.Harvest.DURATION + 10.0
	run.harvest.next_threat = run.Harvest.DURATION + 10.0
	run.elapsed = run.Harvest.DURATION - 0.1
	run.step(1.0)
	expect(run.state == Run.LOSS and is_equal_approx(run.elapsed,run.Harvest.DURATION), "Deadline stops exactly at the configured duration")
	select(run)
	expect(not run.release().valid, "No capture after deadline")
	run.restart()
	run.enemies = [Drifter.new(100, run.board.center, 0.0, "food"), Drifter.new(101, run.board.center, 0.0, "cyst")]
	run.step(0.1)
	expect(run.integrity == 5 and run.enemies.size() == 2, "Food and cysts never bite on contact")
	run.enemies.append(Drifter.new(102, run.board.center, 0.0))
	run.step(0.1)
	expect(run.integrity == 4 and run.enemies.size() == 2, "Drifter contact still costs one organelle")
	run.restart()
	var ids := run.enemies.map(func(e): return e.id)
	for i in 28 * 60:
		run.step(1.0 / 60.0)
	expect(run.enemies.all(func(e): return not ids.has(e.id)), "Unharvested initial bloom drifts away after 27 seconds")
	expect(run.enemies.any(func(e): return e.kind == "drifter"), "Defensive pressure arrives during the harvest")
	expect(run.harvest.nourishment == 0 and run.integrity == 5, "Escaping plankton neither feeds nor damages mother")
	run.restart()
	expect(run.elapsed == 0 and run.harvest.nourishment == 0 and run.harvest.poison_taken == 0 and run.integrity == 5, "Restart clears harvest, wounds, and deadline")
	# A currently visible three-cell meal must survive real slow drawing.
	for sector in 8:
		var trial := Run.new(false, 73 + sector * 37, true)
		trial.enemies.clear()
		trial.harvest.spawn_bloom(trial, sector)
		for i in 210: # 3.5 seconds to inspect the cluster
			trial.step(1.0 / 60.0)
		var route := observed_meal(trial)
		if route.is_empty():
			expect(false,"A safe meal is visible after inspection in sector %d" % sector)
			trial.dispose()
			continue
		# Click input at 1.5 cells/sec, including the closing click. Clicks
		# visit exactly the chosen cells; straight drags would also collect any
		# cell the pointer sweeps across, which a player steers around.
		trial.selection.start(trial.board.anchors[route[0]])
		for id in route.slice(1) + [route[0]]:
			for frame in 40:
				trial.step(1.0 / 60.0)
			trial.selection.visit(id)
		var meal_preview: Dictionary = trial.harvest_preview()
		if OS.get_cmdline_user_args().has("--debug-meals"):
			print("SECTOR ", sector, " route ", route, " path ", trial.selection.path, " closed ", trial.selection.closed, " active ", trial.selection.active, " mother ", trial.selection.mother_blocked(), " reason ", trial.selection.rejection_reason)
		expect(trial.selection.closed and meal_preview.food >= 2 and meal_preview.poison == 0, "Observed safe meal survives slow drawing in sector %d (route %s; meal %s)" % [sector,route,meal_preview])
		trial.dispose()
	var other := Run.new(false, 73, true)
	expect(run.enemies[0].nucleus == other.enemies[0].nucleus, "Fixed seeds reproduce bloom trajectories")
	other.dispose()
	run.dispose()
	print("HARVEST RULES: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
