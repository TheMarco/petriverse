extends "res://tests/harvest_feasibility.gd"
## Complete connected journeys using stale observations and the same actual
## swept-pointer gestures as the harvest feasibility test. No future positions.
func free_local_routes(run: RefCounted, center: Vector2) -> Array:
	var cells: Array = range(run.cells.size()).filter(func(id): return run.is_ready(id))
	cells.sort_custom(func(a,b): return run.board.anchors[a].distance_squared_to(center)<run.board.anchors[b].distance_squared_to(center))
	cells = cells.slice(0,7)
	var options: Array = []
	for a in cells.size():
		for b in range(a+1,cells.size()):
			for c in range(b+1,cells.size()):
				var route: Array = [cells[a],cells[b],cells[c]]
				var polygon := Geometry.polygon_for(route,run.board.anchors)
				if Geometry.capture_valid(route,run.board,run.is_ready,run.selection.max_vertices) and Geometry.contains(center,polygon):
					options.append(route)
	# Four visually nearby free triangles replace four old graph-only options.
	# Outcomes are still scored for at most eight observed options in total.
	options.sort_custom(func(a,b): return Geometry.area(Geometry.polygon_for(a,run.board.anchors))<Geometry.area(Geometry.polygon_for(b,run.board.anchors)))
	return options.slice(0,4)

func accepts_meal(run: RefCounted, profile: Dictionary, meal: Dictionary) -> bool:
	if meal.poison==0:
		return true
	# A Feast player may deliberately exchange one health for a substantial
	# meal, using the same visible consequence preview as a human.
	return profile.get("build","")=="elastic" and meal.poison==1 and meal.food>=4 and run.integrity>=3

func choose_journey(run: RefCounted, profile: Dictionary, pointer: Vector2) -> Dictionary:
	var harvest = run.harvest
	var spec: Dictionary = harvest.spec
	var food_needed: bool = harvest.nourishment < int(spec.food)
	var desired := "food"
	if not food_needed:
		desired = {"rescue": "spore", "purify": "cyst", "defend": "drifter", "boss": "boss", "sectors": "food"}.get(spec.mode,"food")
	if spec.mode == "boss" and not food_needed and run.boss()!=null and not run.boss().can_take_pulse():
		desired = "warden"
	var urgent: Array = run.enemies.filter(func(e): return e.kind in ["drifter","shellback","twinspore","divider"] and not e.is_boss() and e.nucleus.distance_to(run.board.center)<155.0)
	var focuses: Array = run.enemies.filter(func(e): return e.kind == desired or (desired == "boss" and e.is_boss()) or (desired == "drifter" and e.kind in ["shellback","twinspore","grazer","parasite","divider","bell_bud"]))
	var blocked: Array = run.enemies.filter(func(e): return e.kind == "parasite" and e.latched)
	# Follow the same visible rescue countdown and instruction as the HUD.
	if spec.mode=="rescue" and harvest.rescued<int(spec.target):
		var fading: Array = run.enemies.filter(func(e): return e.kind=="spore" and not e.visitor and e.lifetime()-e.age<18.0)
		if not fading.is_empty():
			focuses = fading
			desired = "spore"
	var cradles: Array = run.enemies.filter(func(e): return e.cradle and not e.gate_ids.is_empty())
	if not cradles.is_empty():
		focuses = run.enemies.filter(func(e): return cradles[0].gate_ids.has(e.id))
		desired = "warden"
	if not blocked.is_empty() and urgent.is_empty():
		focuses = blocked
	if not urgent.is_empty():
		focuses = urgent
	if focuses.is_empty():
		return {}
	focuses.sort_custom(func(a,b): return a.nucleus.distance_squared_to(pointer)<b.nucleus.distance_squared_to(pointer))
	var focus = focuses[policy_rng.randi_range(0,mini(2,focuses.size()-1))]
	var nearby: Array = []
	for route in candidates:
		if route.size()>run.selection.max_vertices or route.any(func(id): return not run.is_ready(id)):
			continue
		var polygon := Geometry.polygon_for(route,run.board.anchors)
		if (global_search or Geometry.contains(focus.nucleus,polygon)) and Geometry.capture_valid(route,run.board,run.is_ready,run.selection.max_vertices):
			nearby.append(route)
	# Simple triangles are the first routes a player sees. Shuffle within equal
	# lengths; boss routes are authored and advertised by visible anatomy.
	for i in nearby.size():
		var j := policy_rng.randi_range(i,nearby.size()-1)
		var swap = nearby[i]
		nearby[i] = nearby[j]
		nearby[j] = swap
	nearby.sort_custom(func(a,b): return a.size()<b.size())
	if profile.get("build","")=="elastic" and not global_search and desired=="food" and food_needed and urgent.is_empty() and blocked.is_empty():
		# Four familiar short routes and four broad enclosures: still eight
		# observed possibilities, but the build's reach is actually exercised.
		var wide: Array = nearby.filter(func(path): return path.size()>=6)
		nearby = nearby.slice(0,4)+wide.slice(0,4)
	if not global_search:
		var free: Array = free_local_routes(run,focus.nucleus)
		nearby = free+nearby.slice(0,int(profile.routes)-free.size())
	var best := {}
	var merit := 0.0
	for route in nearby.slice(0,nearby.size() if global_search else int(profile.routes)):
		var polygon := Geometry.polygon_for(route,run.board.anchors)
		var ids: Array = []
		var unsafe := false
		var armor := 0
		var min_threat_distance := INF
		for body in run.enemies:
			var inside := true
			var margin := INF
			for nucleus in body.nuclei():
				inside = inside and Geometry.contains(nucleus,polygon)
				for i in polygon.size():
					margin = minf(margin, Geometry.distance_to_segment(nucleus,polygon[i],polygon[(i+1)%polygon.size()]))
			if body.kind == "cyst" and (inside or margin < float(profile.get("cyst_margin",12.0))):
				if inside:
					ids.append(body.id)
				elif spec.mode != "purify":
					unsafe = true
			elif inside and margin > (4.0 if body.is_boss() else 8.0) and body.can_take_pulse():
				ids.append(body.id)
				if body.kind in ["drifter","shellback","twinspore","divider"]:
					min_threat_distance = minf(min_threat_distance,body.nucleus.distance_to(run.board.center))
				if body.kind == "shellback" and body.health == 2:
					armor += 1
		if unsafe:
			continue
		var result: Dictionary = harvest.outcome(ids,run,route.size())
		if not accepts_meal(run,profile,result):
			continue
		var defense_value := 16.0 if min_threat_distance < 165.0 else 5.0
		var value: float = result.food * (5.0 if food_needed else 0.6) + (result.threats + armor) * defense_value + result.rescued * (18.0 if desired == "spore" else 5.0) + result.purified * (14.0 if desired == "cyst" else 2.0) + result.boss_layers * 45.0 + result.get("wardens",0) * (28.0 if not food_needed else 1.0) - route.size() * 0.6 - result.poison*15.0
		if value > merit:
			merit = value
			best = {"path":route.duplicate(),"food":result.food}
	return best

func measure_stage(run: RefCounted, profile: Dictionary, seed_value: int) -> Dictionary:
	policy_rng.seed = seed_value * 37 + 7
	recent_focus.clear()
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
	stats.route_sizes = {}
	var gesture_start := 0.0
	var expected_food := 0
	var next_fumble := false
	var last_contact: float = run.contact_time
	while run.state == Run.ACTIVE and clock < float(run.harvest.spec.duration)+1.0:
		var dt := 1.0 / 60.0
		clock += dt
		run.step(dt)
		if run.contact_time!=last_contact:
			stats.contacts += run.last_contacts.size()
			last_contact = run.contact_time
		if run.state != Run.ACTIVE:
			break
		if phase == "observe":
			var choice := choose_journey(run,profile,pointer)
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
					elif not accepts_meal(run,profile,preview):
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
				var size: int = result.nodes.size()
				stats.route_sizes[str(size)] = int(stats.route_sizes.get(str(size),0))+1
				if result.food == 0 and result.threats == 0 and result.rescued==0 and result.purified==0 and result.boss_layers==0 and result.get("wardens",0)==0 and result.armor_hits==0:
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
	stats.objective = run.harvest.objective_count()
	stats.stage = run.stage_index
	stats.encounter = run.encounter_index()+1
	stats.name = run.harvest.spec.name
	stats.mode = run.harvest.spec.mode
	stats.cause = run.harvest.loss_title if run.state == Run.LOSS else ""
	return stats

func exercise() -> void:
	var samples := 1
	var rate := 2.0
	var build := ""
	var habitat := "bloom"
	var extended := false
	var first_seed := 73
	var think := 2.5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): samples = int(arg.get_slice("=",1))
		if arg.begins_with("--rate="): rate = float(arg.get_slice("=",1))
		if arg == "--search=all": global_search = true
		if arg.begins_with("--build="): build = arg.get_slice("=",1)
		if arg.begins_with("--habitat="): habitat = arg.get_slice("=",1)
		if arg=="--long": extended = true
		if arg.begins_with("--seed="): first_seed = int(arg.get_slice("=",1))
		if arg.begins_with("--think="): think = float(arg.get_slice("=",1))
	if not build.is_empty() and not Run.Mutations.BUILD_PATHS.has(build):
		printerr("Unknown build: ",build)
		quit(1)
		return
	var profile := {"name":"deliberate" if think>=2.5 else "practiced", "rate":rate, "think":think, "review":0.45, "routes":8, "aim":6.0, "mistake_every":0}
	profile.build = build
	profile.habitat = habitat
	profile.cyst_margin = 6.0 if build=="fission" else 12.0
	var preferences: Array = ["grazer","filter","nursery","symbiosis","fission","lure","catalyst","frenzy","residual","enzyme","feast","elastic"]
	if not build.is_empty():
		preferences = [build]+Run.Mutations.BUILD_PATHS[build].synergy+preferences
	var board_run := Run.new(false)
	for i in 24:
		routes(board_run.board,[i],6 if build=="elastic" else 5)
	if build=="elastic":
		for s in 8:
			var n := (s+1)%8
			var nn := (s+2)%8
			var nnn := (s+3)%8
			candidates.append([s,8+s,16+s,16+n,16+nn,8+nn,nn,n])
			candidates.append([s,8+s,16+s,16+n,16+nn,16+nnn,8+nnn,nnn,nn,n])
	candidates.append([0,1,2,3,4,5,6,7])
	board_run.dispose()
	var reports: Array = []
	var wins := 0
	for sample in samples:
		var run := Run.new(true,first_seed+sample*37,true,true)
		if extended:
			run.long_journey = true
			run.restart()
		var stage_reports: Array = []
		while run.stage_index < 12:
			if run.Habitats.pending(run):
				run.Habitats.choose(run,habitat)
			run.begin_encounter()
			var report := measure_stage(run,profile,run.run_seed+run.encounter_index()*17)
			stage_reports.append(report)
			print("JOURNEY STAGE ", JSON.stringify(report))
			expect(report.max_rate <= rate+0.00001 and report.max_rate <= 4.0,"Human input speed cap")
			if run.state in [Run.LOSS,Run.SUCCESS]:
				break
			for i in 600:
				if run.evolution_ready(): break
				run.step(1.0/60.0)
			if run.integrity <= 3 and run.biomass >= run.repair_cost():
				run.choose_journey_evolution("repair")
			else:
				var choice := "continue"
				for option in preferences:
					if run.offered_mutations.has(option) and run.biomass >= run.evolution_cost():
						choice = option
						break
				run.choose_journey_evolution(choice)
		wins += int(run.state==Run.SUCCESS)
		reports.append({"seed":run.run_seed,"state":run.state,"last_stage":run.stage_index,"mutations":run.mutations.duplicate(),"stages":stage_reports})
		run.dispose()
	var path := "res://artifacts/journey-living-ecosystem-feasibility-%s-%.1f%s.json" % ["all" if global_search else "local",rate,"" if build.is_empty() else "-"+build]
	if habitat!="bloom":
		path = path.trim_suffix(".json")+"-"+habitat+".json"
	if extended:
		path = path.trim_suffix(".json")+"-long.json"
	if first_seed!=73:
		path = path.trim_suffix(".json")+"-seed%d.json" % first_seed
	if think!=2.5:
		path = path.trim_suffix(".json")+"-think%.1f.json" % think
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"profile":profile,"global_search":global_search,"wins":wins,"runs":samples,"journeys":reports,"limits":"Simulated route search is not a human playtest. No retries used. At most eight consequence reviews: four nearby free triangles plus four familiar routes; no future positions."},"  "))
	if extended:
		expect(wins==samples,"Every requested generated journey reaches its thirtieth encounter and wins")
	print("JOURNEY FEASIBILITY: %d/%d complete journeys; %d checks; %d failures" % [wins,samples,checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
