extends SceneTree
## A timing proxy, not a claim of human playtesting. No future target positions
## or instant loops: planning, each dragged edge, closure, release, and mistakes
## all consume live simulation time. Route choice still has perfect board knowledge.

const Run = preload("res://scripts/run_controller.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
const STEP := 1.0 / 60.0
const LIMIT := 360.0
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("exercise")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func choose_route(run: RefCounted, candidates: Array) -> Array:
	# Prioritize the most urgent currently visible target. Prefer a polygon with
	# room around its current nucleus, without predicting where it will move.
	var enemies: Array = run.enemies.duplicate()
	enemies.sort_custom(func(a, b): return a.nucleus.distance_to(run.board.center) < b.nucleus.distance_to(run.board.center))
	for enemy in enemies:
		var best: Array = []
		var best_margin := 10.0
		for path in candidates:
			if not Geometry.validate(path, run.board.anchors, run.is_ready):
				continue
			var polygon := Geometry.polygon_for(path, run.board.anchors)
			if not Geometry.contains(enemy.nucleus, polygon):
				continue
			var margin := INF
			for i in polygon.size():
				margin = minf(margin, Geometry.distance_to_segment(enemy.nucleus, polygon[i], polygon[(i + 1) % polygon.size()]))
			if margin > best_margin:
				best = path
				best_margin = margin
		if not best.is_empty():
			return best.duplicate()
	return []

func simulate(profile: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var run = Run.new(false)
	for setting in overrides:
		run.board.tuning[setting] = overrides[setting]
	run.restart()
	var candidates: Array = run.board.triangles.duplicate()
	if profile.get("large_loops", false):
		candidates = [[0, 1, 2, 3, 4, 5, 6, 7]]
	var path: Array = []
	var stage := "idle"
	var timer := 0.0
	var next_vertex := 1
	var attempts := 0
	var captures := 0
	var empty := 0
	var cancellations := 0
	var segments := 0
	var peak := 0
	var drawing_started := 0.0
	var minimum_drawing_time := INF
	var timing_valid := true
	var max_speed := 0.0
	var max_node_speed := 0.0
	var node_positions: PackedVector2Array = run.board.anchors.duplicate()
	while run.elapsed < LIMIT and run.state == Run.ACTIVE:
		run.step(STEP)
		for i in node_positions.size():
			max_node_speed = maxf(max_node_speed, node_positions[i].distance_to(run.board.anchors[i]) / STEP)
		node_positions = run.board.anchors.duplicate()
		peak = maxi(peak, run.enemies.size())
		for enemy in run.enemies:
			max_speed = maxf(max_speed, enemy.speed)
		if run.state != Run.ACTIVE:
			break
		timer -= STEP
		if timer > 0.000001:
			continue
		match stage:
			"idle":
				path = choose_route(run, candidates)
				if path.is_empty():
					timer = 0.25 # Do not scan and act at physics-frame speed.
					continue
				attempts += 1
				stage = "plan"
				timer = profile.planning + profile.reposition
				if profile.get("hesitate_every", 0) > 0 and attempts % int(profile.hesitate_every) == 0:
					timer += 1.0
			"plan":
				run.selection.start(run.board.anchors[path[0]])
				drawing_started = run.elapsed
				next_vertex = 1
				stage = "draw"
				timer = 1.0 / profile.segments_per_second
			"draw":
				var previous: int = path[(next_vertex - 1) % path.size()]
				var next: int = path[next_vertex % path.size()]
				run.selection.drag(run.board.anchors[previous], run.board.anchors[next])
				segments += 1
				next_vertex += 1
				if next_vertex > path.size():
					var spent: float = run.elapsed - drawing_started
					minimum_drawing_time = minf(minimum_drawing_time, spent)
					timing_valid = timing_valid and spent + 0.0001 >= path.size() / profile.segments_per_second
					stage = "release"
					timer = profile.release
				else:
					timer = 1.0 / profile.segments_per_second
			"release":
				if profile.get("cancel_every", 0) > 0 and attempts % int(profile.cancel_every) == 0:
					run.selection.cancel()
					cancellations += 1
				else:
					var result: Dictionary = run.release()
					if result.valid and result.points > 0:
						captures += 1
					else:
						empty += 1
				stage = "idle"
				timer = 0.25
	var result := {"profile": profile.name, "state": run.state, "integrity": run.integrity, "kills": run.kills, "elapsed": snappedf(run.elapsed, 0.01), "peak_enemies": peak, "attempts": attempts, "captures": captures, "empty_loops": empty, "cancelled_loops": cancellations, "segments": segments, "shortest_draw_seconds": snappedf(minimum_drawing_time, 0.001), "timing_valid": timing_valid, "max_enemy_speed": max_speed, "max_node_speed": max_node_speed, "assumptions": profile, "tuning": run.board.tuning.duplicate()}
	run.dispose()
	return result

func exercise() -> void:
	var profiles := [
		{"name": "skillful", "segments_per_second": 4.0, "planning": 1.5, "reposition": 0.5, "release": 0.25},
		{"name": "steady", "segments_per_second": 3.0, "planning": 1.75, "reposition": 0.5, "release": 0.25},
		{"name": "deliberate", "segments_per_second": 2.0, "planning": 2.0, "reposition": 0.5, "release": 0.25},
		{"name": "hesitations_and_cancels", "segments_per_second": 2.0, "planning": 2.0, "reposition": 0.5, "release": 0.25, "cancel_every": 5, "hesitate_every": 4},
		{"name": "large_loops", "segments_per_second": 4.0, "planning": 1.5, "reposition": 0.5, "release": 0.25, "large_loops": true},
		{"name": "deliberate_large_loops", "segments_per_second": 2.0, "planning": 2.0, "reposition": 0.5, "release": 0.25, "large_loops": true}
	]
	var reports: Array = []
	var arguments := OS.get_cmdline_user_args()
	var compare := arguments.has("--compare")
	var previous_tuning := {"enemy_speed": 19.0, "enemy_speed_spread": 3.0, "spawn_interval": 2.7, "first_spawn_delay": 3.0}
	# Human playtests found the all-profiles/three-integrity floor too forgiving.
	# Keep wins with a margin at 3–4 segments/s and wins at 2 segments/s; the
	# slowest profile with repeated mistakes is a stress observation, not a must-win.
	var minimum_integrity := {"skillful": 3, "steady": 2, "deliberate": 1, "hesitations_and_cancels": 0, "large_loops": 3, "deliberate_large_loops": 1}
	for profile in profiles:
		if compare:
			var before := simulate(profile, previous_tuning)
			print("BEFORE ", JSON.stringify(before))
		var result := simulate(profile)
		reports.append(result)
		print("PACED ", JSON.stringify(result))
		expect(result.timing_valid, "%s obeys the drag rate including closure" % profile.name)
		var required_integrity: int = minimum_integrity[profile.name]
		expect(result.state == Run.SUCCESS if required_integrity > 0 else result.state in [Run.SUCCESS, Run.LOSS], "%s completes its pacing scenario" % profile.name)
		expect(result.integrity >= required_integrity, "%s meets its declared integrity floor of %d" % [profile.name, required_integrity])
		expect(result.max_node_speed <= 12.00001, "%s keeps independent cell drift within 12 pixels/s" % profile.name)
		expect(result.max_enemy_speed <= 7.0, "%s caps enemy motion at 7 pixels/s" % profile.name)
	var file := FileAccess.open("res://artifacts/human-pacing.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(reports, "  ") + "\n")
	print("PACING: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
