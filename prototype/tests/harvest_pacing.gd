extends "res://tests/full_run.gd"
## Feasibility proxy, not a model of human perception or a claim about fun.
## Uses current visible positions with a margin, 0.8s planning and timed visits.
func best_path(run: RefCounted) -> Array:
	var best: Array = []
	var merit := -INF
	for path in candidates:
		if path.any(func(id): return not run.is_ready(id)):
			continue
		var polygon := Geometry.polygon_for(path, run.board.anchors)
		var food := 0
		var poison := 0
		var defense := 0.0
		for body in run.enemies:
			var inside := Geometry.contains(body.nucleus, polygon)
			var margin := INF
			for i in polygon.size():
				margin = minf(margin, Geometry.distance_to_segment(body.nucleus, polygon[i], polygon[(i+1)%polygon.size()]))
			if body.kind == "cyst" and (inside or margin < 12.0):
				poison += 1
			elif inside and margin >= 12.0:
				if body.kind == "food":
					food += 1
				elif body.kind == "drifter":
					defense += maxf(0.0, 250.0 - body.nucleus.distance_to(run.board.center)) * 0.12
		if poison >= run.integrity or food == 0 and defense == 0:
			continue
		var value: float = food * 7.0 + defense - poison * 23.0 - path.size() * 1.6
		if value > maxf(0.0,merit):
			merit = value
			best = path
	return best.duplicate()

func harvest_simulation(rate: float, seed_value: int) -> Dictionary:
	var run := Run.new(false,seed_value,true)
	var path: Array = []
	var index := 0
	var next_visit := 0.0
	var next_plan := 0.8
	var gesture_start := 0.0
	var max_rate := 0.0
	var attempts := 0
	var empty := 0
	var changed := 0
	var last_path: Array = []
	var route_sizes: Dictionary = {}
	while run.state == Run.ACTIVE:
		run.step(1.0 / 60.0)
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
					# A player can cancel a newly lethal/contaminated outline.
					var preview: Dictionary = run.harvest_preview()
					if preview.poison >= run.integrity or preview.food == 0 and preview.threats == 0:
						run.selection.cancel()
						changed += 1
					else:
						var result: Dictionary = run.release()
						attempts += 1
						if result.get("ids",[]).is_empty():
							empty += 1
					max_rate = maxf(max_rate, path.size() / (run.elapsed - gesture_start))
					path.clear()
					next_plan = run.elapsed + 0.8
		elif run.elapsed >= next_plan:
			path = best_path(run)
			if not path.is_empty():
				if not last_path.is_empty() and path != last_path:
					changed += 1
				last_path = path.duplicate()
				route_sizes[path.size()] = route_sizes.get(path.size(),0)+1
				run.selection.start(run.board.anchors[path[0]])
				index = 1
				gesture_start = run.elapsed
				next_visit = run.elapsed + 1.0 / rate
			else:
				next_plan = run.elapsed + 0.4
	var result := {"rate":rate,"seed":seed_value,"state":run.state,"seconds":snappedf(run.elapsed,0.01),"nourishment":run.harvest.nourishment,"integrity":run.integrity,"poison":run.harvest.poison_taken,"captures":attempts,"empty":empty,"max_rate":max_rate,"different_routes":changed,"route_sizes":route_sizes}
	run.dispose()
	return result

func exercise() -> void:
	var map := Run.new(false)
	for i in map.board.anchors.size():
		routes(map.board,[i],8)
	map.dispose()
	var reports: Array = []
	for rate in [3.0,4.0]:
		for seed_value in [73,103,271]:
			var report := harvest_simulation(rate,seed_value)
			print("HARVEST SAMPLE ",JSON.stringify(report))
			reports.append(report)
			expect(report.max_rate <= rate + 0.00001, "Actual gesture includes closure at stated segment rate")
			expect(report.state == Run.SUCCESS, "Harvest feasible at %s segments/s seed %s" % [rate,seed_value])
	var file := FileAccess.open("res://artifacts/harvest-pacing.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"method":"current visible positions, 12px safety margin, 0.8s planning, 3–4 actual segments/sec; geometric oracle, not human validation", "samples":reports},"  "))
	print("HARVEST PACING: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
