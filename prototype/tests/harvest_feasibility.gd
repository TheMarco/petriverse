extends "res://tests/full_run.gd"
## Bounded local search with stale observations, thinking time, real swept
## pointer motion and imperfect aim. Still a proxy, not a human playtest.
const PROFILES := [
	{"name":"deliberate", "rate":2.0, "think":2.5, "review":0.45, "routes":6, "aim":6.0, "mistake_every":0},
	{"name":"learning", "rate":1.5, "think":3.5, "review":0.65, "routes":4, "aim":10.0, "mistake_every":7},
	{"name":"practiced", "rate":3.0, "think":1.5, "review":0.3, "routes":10, "aim":4.0, "mistake_every":0},
]
var policy_rng := RandomNumberGenerator.new()
var source_label := "current"
var recent_focus: Dictionary = {}
var seed_count := 20
var global_search := false

func choose_local(run: RefCounted, profile: Dictionary, pointer: Vector2) -> Dictionary:
	var visible: Array = run.enemies.filter(func(e): return e.kind == "food" and (not e.has_method("opacity") or e.opacity() > 0.35))
	var threats: Array = run.enemies.filter(func(e): return e.kind == "drifter" and e.nucleus.distance_to(run.board.center) < 160.0 and float(recent_focus.get(e.id,-100.0)) < run.elapsed - 5.0)
	if not threats.is_empty():
		visible = threats
	if visible.is_empty():
		return {}
	visible.sort_custom(func(a,b): return a.nucleus.distance_squared_to(pointer) < b.nucleus.distance_squared_to(pointer))
	var fresh: Array = visible.filter(func(e): return float(recent_focus.get(e.id,-100.0)) < run.elapsed - 5.0)
	if not fresh.is_empty():
		visible = fresh
	var focus = visible[policy_rng.randi_range(0,mini(2,visible.size()-1))]
	recent_focus[focus.id] = run.elapsed
	var nearby: Array = []
	for route in candidates:
		if route.any(func(id): return not run.is_ready(id)):
			continue
		var polygon := Geometry.polygon_for(route,run.board.anchors)
		if Geometry.contains(focus.nucleus,polygon):
			nearby.append(route)
	# A few plausible neighboring loops, not all possible contours on the dish.
	for i in nearby.size():
		var other := policy_rng.randi_range(i,nearby.size()-1)
		var swap = nearby[i]
		nearby[i] = nearby[other]
		nearby[other] = swap
	if global_search:
		nearby = candidates
	var best: Dictionary = {}
	var merit := 0.0
	for route in nearby.slice(0,nearby.size() if global_search else profile.routes):
		var polygon := Geometry.polygon_for(route,run.board.anchors)
		var food := 0
		var poison := 0
		var defense := 0
		for body in run.enemies:
			var inside := Geometry.contains(body.nucleus,polygon)
			var margin := INF
			for i in polygon.size():
				margin = minf(margin, Geometry.distance_to_segment(body.nucleus,polygon[i],polygon[(i+1)%polygon.size()]))
			if body.kind == "cyst" and (inside or margin < 18.0):
				poison += 1
			elif inside and margin >= 10.0:
				if body.kind == "food":
					food += 1
				elif body.kind == "drifter":
					defense += 1
		if poison > 0:
			continue
		var value: float = food * 5.0 + defense * 9.0 - route.size() * 0.7
		if value > merit:
			merit = value
			best = {"path":route.duplicate(),"food":food,"threats":defense}
	return best

func measure(profile: Dictionary, seed_value: int) -> Dictionary:
	policy_rng.seed = seed_value * 37 + 7
	recent_focus.clear()
	var run := Run.new(false,seed_value,true)
	var path: Array = []
	var phase := "observe"
	var phase_until := 0.0
	var clock := 0.0
	var pointer: Vector2 = run.board.anchors[0]
	var segment_start := 0.0
	var segment_from := pointer
	var index := 0
	var aim := Vector2.ZERO
	var stats := {"profile":profile.name,"seed":seed_value,"captures":0,"empty":0,"abandoned_poison":0,"spoiled":0,"missed_input":0,"plans":0,"search_misses":0,"poison":0,"contacts":0,"max_rate":0.0}
	var gesture_start := 0.0
	var expected_food := 0
	var next_fumble := false
	while run.state == Run.ACTIVE and clock < 180.0:
		var dt := 1.0 / 60.0
		clock += dt
		run.step(dt)
		if run.state != Run.ACTIVE:
			break
		if phase == "observe":
			var choice := choose_local(run,profile,pointer)
			stats.plans += 1
			if choice.is_empty():
				stats.search_misses += 1
				phase = "search"
				phase_until = clock + 0.85
			else:
				path = choice.path
				expected_food = choice.food
				next_fumble = profile.mistake_every > 0 and stats.plans % profile.mistake_every == 0
				phase = "think"
				phase_until = clock + profile.think
		elif phase == "search":
			if clock >= phase_until:
				phase = "observe"
		elif phase == "think":
			if clock >= phase_until:
				pointer = run.board.anchors[path[0]] + Vector2(policy_rng.randf_range(-profile.aim,profile.aim),policy_rng.randf_range(-profile.aim,profile.aim))
				run.selection.start(pointer)
				index = 1
				gesture_start = clock
				segment_start = clock
				segment_from = pointer
				aim = Vector2(policy_rng.randf_range(-profile.aim,profile.aim),policy_rng.randf_range(-profile.aim,profile.aim))
				phase = "trace"
		elif phase == "trace":
			var u := clampf((clock-segment_start)*profile.rate,0.0,1.0)
			var id: int = path[index % path.size()]
			var next_pointer: Vector2 = segment_from.lerp(run.board.anchors[id]+aim,u)
			run.selection.drag(pointer,next_pointer)
			pointer = next_pointer
			if u >= 1.0 - 0.00001:
				index += 1
				if next_fumble and index == 3:
					run.selection.cancel()
					stats.missed_input += 1
					phase = "search"
					phase_until = clock + 0.8
				elif index > path.size():
					stats.max_rate = maxf(stats.max_rate,path.size()/(clock-gesture_start))
					var preview: Dictionary = run.harvest_preview()
					if not run.selection.closed:
						stats.missed_input += 1
						run.selection.cancel()
						phase = "observe"
					elif preview.poison > 0:
						stats.abandoned_poison += 1
						run.selection.cancel()
						phase = "search"
						phase_until = clock + profile.review
					else:
						phase = "release"
						phase_until = clock + profile.review
				else:
					segment_start = clock
					segment_from = pointer
					aim = Vector2(policy_rng.randf_range(-profile.aim,profile.aim),policy_rng.randf_range(-profile.aim,profile.aim))
		elif phase == "release" and clock >= phase_until:
			var result: Dictionary = run.release()
			if result.valid:
				stats.captures += 1
				if result.food == 0 and result.threats == 0:
					stats.empty += 1
				if result.food < expected_food:
					stats.spoiled += 1
			else:
				stats.missed_input += 1
			phase = "observe"
	stats.state = run.state
	stats.seconds = snappedf(clock,0.01)
	stats.food = run.harvest.nourishment
	stats.integrity = run.integrity
	stats.poison = run.harvest.poison_taken
	stats.contacts = 5 - run.integrity - mini(5,run.harvest.poison_taken)
	stats.cause = run.harvest.loss_title if run.state == Run.LOSS else ""
	run.dispose()
	return stats

func exercise() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): source_label = arg.get_slice("=",1)
		if arg == "--search=all": global_search = true
		if arg.begins_with("--seeds="): seed_count = int(arg.get_slice("=",1))
	var board_run := Run.new(false)
	for i in board_run.board.anchors.size():
		routes(board_run.board,[i],5)
	candidates.append([0,1,2,3,4,5,6,7]) # obvious inner ring for core defense
	board_run.dispose()
	print("LOCAL ROUTES ",candidates.size())
	var reports: Array = []
	var groups: Array = []
	for profile in PROFILES:
		var wins := 0
		var total_food := 0
		var abandons := 0
		var spoiled := 0
		var misses := 0
		var poison := 0
		var elapsed := 0.0
		var losses := {}
		for i in seed_count:
			var report := measure(profile,73+i*37)
			reports.append(report)
			wins += int(report.state == Run.SUCCESS)
			total_food += report.food
			abandons += report.abandoned_poison
			spoiled += report.spoiled
			misses += report.search_misses
			poison += report.poison
			elapsed += report.seconds
			if report.state == Run.LOSS: losses[report.cause] = losses.get(report.cause,0)+1
			expect(report.max_rate <= profile.rate + 0.00001 and report.max_rate <= 4.0,"Input respects speed cap")
		var group := {"profile":profile,"wins":wins,"runs":seed_count,"mean_food":float(total_food)/seed_count,"mean_seconds":elapsed/seed_count,"mean_abandoned_poison":float(abandons)/seed_count,"mean_spoiled":float(spoiled)/seed_count,"mean_search_misses":float(misses)/seed_count,"mean_poison":float(poison)/seed_count,"losses":losses}
		groups.append(group)
		print("FEASIBILITY ",JSON.stringify(group))
	var file := FileAccess.open("res://artifacts/harvest-feasibility-"+source_label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"label":source_label,"global_search":global_search,"route_limit":5,"route_count":candidates.size(),"groups":groups,"runs":reports},"  "))
	print("HARVEST FEASIBILITY: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
