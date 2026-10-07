extends SceneTree
## Campaign pacing uses visible positions, finite planning time and actual node visits.
const Run = preload("res://scripts/run_controller.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
const Resolver = preload("res://scripts/loop_resolver.gd")
const Conjoined = preload("res://scripts/conjoined.gd")
const Mutations = preload("res://scripts/mutations.gd")
var checks := 0
var failures: Array[String] = []
var candidates: Array = []

func _initialize() -> void:
	call_deferred("exercise")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func routes(board: RefCounted, path: Array, limit: int) -> void:
	if path.size() >= 3 and board.neighbors[path[-1]].has(path[0]) and path[1] < path[-1] and Geometry.simple_polygon(Geometry.polygon_for(path, board.rest_anchors)):
		candidates.append(path.duplicate())
	if path.size() >= limit:
		return
	for id in board.neighbors[path[-1]]:
		if id > path[0] and Geometry.can_append(path, id, board.rest_anchors, func(_id): return true, limit):
			routes(board, path + [id], limit)

func best_path(run: RefCounted) -> Array:
	var best: Array = []
	var merit := -INF
	for path in candidates:
		if path.size() > run.selection.max_vertices or path.any(func(id): return not run.is_ready(id)):
			continue
		var polygon := Geometry.polygon_for(path, run.board.anchors)
		var value := 0.0
		var safe_targets := 0
		for enemy in run.enemies:
			if not enemy.can_take_pulse():
				continue
			var inside := true
			for nucleus in enemy.nuclei():
				if not Geometry.contains(nucleus, polygon):
					inside = false
					break
				var margin := INF
				for i in polygon.size():
					margin = minf(margin, Geometry.distance_to_segment(nucleus, polygon[i], polygon[(i + 1) % polygon.size()]))
				if margin < 13.0:
					inside = false
			if inside:
				safe_targets += 1
				var urgency: float = 380.0 - enemy.nucleus.distance_to(run.board.center)
				value += 200.0 if enemy.is_boss() else 20.0 + urgency * 0.8
				if enemy.kind == "shellback" and enemy.health == 2 and Mutations.damage(run.mutations, path.size()) == 2:
					value += 70.0
		if safe_targets == 0:
			continue
		value -= path.size() * 16.0
		if value > merit:
			merit = value
			best = path
	return best.duplicate()

func simulate(rate: float, seed_value: int) -> Dictionary:
	var run := Run.new(true, seed_value)
	var path: Array = []
	var index := 0
	var next_visit := 0.0
	var next_plan := 0.7
	var gesture_start := 0.0
	var max_rate := 0.0
	var transitions := 0
	var offered: Array = []
	var spent := 0.0
	var attempts := 0
	var empty := 0
	while spent < 380.0 and run.state not in [Run.SUCCESS, Run.LOSS]:
		spent += 1.0 / 60.0
		run.step(1.0 / 60.0)
		if run.state == Run.EVOLVE:
			path.clear()
			if run.evolution_ready():
				offered.append(run.offered_mutations.duplicate())
				var choice: String = run.offered_mutations[0]
				for wanted in ["fission", "enzyme", "frenzy"]:
					if run.offered_mutations.has(wanted):
						choice = wanted
						break
				run.choose_mutation(choice)
				transitions += 1
				next_plan = run.elapsed + 1.0
			continue
		if run.state != Run.ACTIVE:
			break
		if not path.is_empty():
			if run.elapsed + 0.00001 >= next_visit:
				if index < path.size():
					run.selection.visit(path[index])
					index += 1
					next_visit += 1.0 / rate
				else:
					run.selection.visit(path[0])
					var result: Dictionary = run.release()
					attempts += 1
					if result.get("ids", []).is_empty():
						empty += 1
					max_rate = maxf(max_rate, path.size() / (run.elapsed - gesture_start))
					path.clear()
					next_plan = run.elapsed + 0.55
		elif run.elapsed >= next_plan:
			path = best_path(run)
			if not path.is_empty():
				run.selection.start(run.board.anchors[path[0]])
				index = 1
				gesture_start = run.elapsed
				next_visit = run.elapsed + 1.0 / rate
			else:
				next_plan = run.elapsed + 0.3
	var result := {"rate": rate, "seed": seed_value, "state": run.state, "stage": run.stage_index,
		"integrity": run.integrity, "seconds": snappedf(run.elapsed, 0.01), "score": run.score,
		"mutations": run.mutations.duplicate(), "choices": transitions, "max_rate": max_rate,
		"captures": attempts, "empty": empty, "offers": offered}
	run.dispose()
	return result

func boss_combinations() -> void:
	var ids: Array = []
	for item in Mutations.CATALOG:
		ids.append(item.id)
	var count := 0
	for a in range(ids.size() - 2):
		for b in range(a + 1, ids.size() - 1):
			for c in range(b + 1, ids.size()):
				var run := Run.new(true, 42)
				run.stage_index = 3
				run.enemies.clear()
				run.start_stage()
				for id in [ids[a], ids[b], ids[c]]:
					run.add_mutation(id)
				# Start with an entirely exhausted board; missing the first window
				# must not make any mutation combination impossible.
				for cell in run.cells:
					cell.spend(12.0)
				var path: Array = []
				var next_visit := 0.0
				var index := 0
				var joint_hits := 0
				while run.elapsed < 70.0 and run.state == Run.ACTIVE:
					run.step(1.0 / 60.0)
					# This check isolates the boss's geometry/recovery. Full simulations
					# above include and defend against its actual summoned attackers.
					run.enemies = run.enemies.filter(func(enemy): return enemy.is_boss())
					if not path.is_empty():
						if run.elapsed >= next_visit:
							if index < path.size():
								run.selection.visit(path[index])
								index += 1
								next_visit += 0.25
							else:
								run.selection.visit(path[0])
								var captured: Dictionary = run.release()
								joint_hits += int(captured.get("boss_layers", 0))
								path.clear()
					else:
						var boss = run.boss()
						if boss != null and boss.can_take_pulse() and boss.phase() >= 5.3 and boss.phase() <= 8.0:
							# The visible hearts stay in the water while friendly nodes
							# wander. Choose a currently enclosing route, as in the
							# complete campaign policy, rather than old node IDs.
							var route: Array = best_path(run)
							if not route.is_empty():
								path = route.duplicate()
								run.selection.start(run.board.anchors[path[0]])
								index = 1
								next_visit = run.elapsed + 0.25
				count += 1
				expect(run.state == Run.SUCCESS and joint_hits == 3, "Boss remains beatable after a missed window: %s" % str([ids[a], ids[b], ids[c]]))
				expect(run.score == 2500, "Boss layers never multiply damage, kills or the victory award")
				run.dispose()
	print("BOSS COMBINATIONS: ", count)

func exercise() -> void:
	var board_run := Run.new(false)
	for i in board_run.board.anchors.size():
		routes(board_run.board, [i], 8)
	board_run.dispose()
	print("CANDIDATE HUMAN ROUTES: ", candidates.size())
	var profiles: Array = [] if "--boss-only" in OS.get_cmdline_user_args() else [[4.0, 103], [3.0, 103], [4.0, 271]]
	for profile in profiles:
		var result := simulate(profile[0], profile[1])
		print("FULL RUN: ", JSON.stringify(result))
		expect(result.state == "success", "Complete campaign at %.1f segments/s, seed %d" % [profile[0], profile[1]])
		expect(result.choices == 3 and result.mutations.size() == 3, "Three distinct mutations lead to the boss")
		expect(result.max_rate <= profile[0] + 0.01, "The pacing policy never exceeds its human input speed")
		expect(result.seconds >= 140.0 and result.seconds <= 330.0, "A successful complete run stays near the 3–5 minute target")
	boss_combinations()
	print("CAMPAIGN: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
