extends RefCounted
## Authored overlapping opportunities followed by recovery space. No response
## depends on a sub-second action; all deadlines use simulation time.
const Body = preload("res://scripts/ecology_enemy.gd")
const Rhythm = preload("res://scripts/encounter_rhythm.gd")
var next_wave := 12.0
var rhythm_origin := 0.0
var pace: Dictionary = Rhythm.legacy_pacing()
var wave := 0
var pending: Array = []
var eaten_food := 0
var escaped_spores := 0
var notice := ""
var notice_time := 0.0
var gates_spawned := false
const FEEDING_TIME := 6.0

static func hunter_speed(run: RefCounted) -> float:
	# A grown colony attracts hunters that close the distance sooner. The first
	# biome keeps its teaching pace; later hunters still take many seconds to
	# cross the dish, leaving time to respond to the arrival warning.
	if run.stage_index < 4 or run.mutations.size() < 4:
		return 5.4
	var speed := minf(9.0, 5.4 + 0.7 * float(run.mutations.size() - 3) + 0.15 * float(run.stage_index - 4))
	# A stocked, evolved colony leaves a stronger food trail in the Blue Deep.
	# Spending reserves between encounters weakens this late predator response.
	if run.encounter_total() == 30 and run.stage_index >= 8 and run.mutations.size() >= 5:
		speed += 2.4 * clampf((float(run.biomass) - 12.0) / 18.0, 0.0, 1.0)
	return speed

static func early_hunters(run: RefCounted) -> bool:
	return run.stage_index >= 4 and run.mutations.size() >= 5

func pocket(run: RefCounted, area: int, outer: bool = false) -> Vector2:
	var s := posmod(area,8)
	var n := (s+1)%8
	var ids: Array = [s,8+s,8+n] if not outer else [8+s,16+s,16+n]
	return (run.board.anchors[ids[0]]+run.board.anchors[ids[1]]+run.board.anchors[ids[2]])/3.0

func add(run: RefCounted, kind: String, area: int, at: Vector2, inherited_form: String = "choose") -> RefCounted:
	run.next_enemy_id += 1
	var body: RefCounted = run.Amoebas.Body.new(run.next_enemy_id,at) if kind=="amoeba" else run.Phages.Bacterium.new(run.next_enemy_id,at,posmod(area,8)) if kind=="bacterium" else Body.new(run.next_enemy_id,kind,at,posmod(area,8))
	run.enemies.append(body)
	run.discover(kind)
	if inherited_form == "choose":
		preload("res://scripts/creature_forms.gd").assign(run, body)
	else:
		body.form = inherited_form
	return body

func blocked(run: RefCounted, node: int) -> bool:
	for body in run.enemies:
		if body.kind == "parasite" and body.latched and body.target_node == node:
			return true
	return false

func begin(run: RefCounted) -> void:
	pace = Rhythm.pacing(run.stage_index)
	next_wave = pace.warning
	if run.harvest.spec.mode == "boss":
		spawn_gates(run)
	if run.harvest.spec.get("phage_lesson",false):
		var body = add(run,"bacterium",run.harvest.rotation,pocket(run,run.harvest.rotation))
		run.phages.pair(run,body)
	if run.stage_index==2 and not run.harvest.spec.get("generated",false):
		run.next_enemy_id += 1
		var bud = run.JourneyHarvest.Predator.new(run.next_enemy_id,run.board,0)
		bud.juvenile = true
		bud.kind = "bell_bud"
		bud.health = 1
		bud.nucleus = pocket(run,(run.harvest.rotation+2)%8)
		run.enemies.append(bud)
		run.discover("bell_bud")
	if run.stage_index==6 and not run.harvest.spec.get("generated",false):
		var spores: Array = run.enemies.filter(func(e): return e.kind=="spore")
		if not spores.is_empty():
			spores[0].cradle = true
			spores[0].story = "cradle"
			spawn_gates(run,spores[0])

func announce(text: String) -> void:
	notice = text
	notice_time = 5.0

func spawn_gates(run: RefCounted, holder: RefCounted = null) -> void:
	var boss = run.boss() if holder==null else holder
	if boss == null or boss.health <= 0 or (boss.is_boss() and boss.variant!=1):
		return
	run.enemies = run.enemies.filter(func(e): return not boss.gate_ids.has(e.id))
	boss.gate_ids.clear()
	boss.shield_remaining = 0.0
	for i in 2:
		var area: int = posmod(run.harvest.rotation + (boss.round_index*3 if boss.is_boss() else 0) + i*2,8)
		var at: Vector2 = pocket(run,area) if boss.is_boss() else boss.nucleus+Vector2(-27 if i==0 else 27,12)
		var guard = add(run,"warden",area,at)
		guard.spawning = 0.0
		boss.gate_ids.append(guard.id)
	gates_spawned = true

func resolve_gates(run: RefCounted) -> void:
	for holder in run.enemies:
		if holder.gate_ids.is_empty():
			continue
		var old_count: int = holder.gate_ids.size()
		holder.gate_ids = holder.gate_ids.filter(func(id): return run.enemies.any(func(e): return e.id == id))
		if holder.gate_ids.is_empty():
			holder.shield_remaining = 0.0
			if holder.is_boss():
				holder.open_remaining = 14.0
				announce("Shields broken · Regent open for 14s")
			else:
				holder.cradle_open_age = holder.age
				announce("Cradle open · rescue now, or protect it for 12s to hatch two young")
		elif old_count>holder.gate_ids.size():
			holder.shield_remaining = 18.0
			announce("Capture the remaining shield before it regrows · 18s")

func step(run: RefCounted, delta: float) -> void:
	notice_time = maxf(0.0,notice_time-delta)
	var boss = run.boss()
	if boss != null and boss.variant==1 and boss.gate_ids.is_empty() and boss.open_remaining <= 0.0 and boss.reset_remaining <= 0.0:
		spawn_gates(run)
	for holder in run.enemies.duplicate():
		if holder.shield_remaining>0.0:
			holder.shield_remaining = maxf(0.0,holder.shield_remaining-delta)
			if holder.shield_remaining<=0.0 and not holder.gate_ids.is_empty():
				spawn_gates(run,holder)
				announce("Shields regrew · capture both together or in quick succession")
		if holder.kind in ["bellwether","bell_bud"]:
			var strength: float = holder.current_strength()
			for food in run.enemies:
				if food.kind not in ["food","cyst"]:
					continue
				var toward: Vector2 = holder.nucleus-food.nucleus
				var distance := toward.length()
				if distance>60.0 and distance<250.0:
					food.origin += toward.normalized()*strength*3.0*delta*(1.0-distance/350.0)
	var linked: Array = []
	for holder in run.enemies:
		linked.append_array(holder.gate_ids)
	run.enemies = run.enemies.filter(func(e): return e.kind!="warden" or linked.has(e.id))
	if run.stage_index > 0 and run.stage_elapsed >= next_wave and run.stage_elapsed < float(run.harvest.spec.duration)-22.0:
		queue_wave(run)
		next_wave += pace.cycle
	var due: Array = pending.filter(func(e): return e.at <= run.stage_elapsed)
	pending = pending.filter(func(e): return e.at > run.stage_elapsed)
	for event in due:
		spawn_event(run,event)
	run.amoebas.step(run,delta)
	run.phages.step(run,delta)
	step_food_web(run,delta)
	step_cradles(run)
	var remove: Array = []
	var newborns: Array = []
	for body in run.enemies.duplicate():
		if body.kind not in ["grazer","parasite","divider","warden","bacterium"] or body.spawning > 0.0:
			continue
		match body.kind:
			"grazer", "bacterium":
				if body.kind=="bacterium" and body.infection_age>=3.0:
					body.destination = body.nucleus
					continue
				var food = null
				var distance := INF
				for candidate in run.enemies:
					if candidate.kind == "food" and not remove.has(candidate.id):
						var d: float = body.nucleus.distance_to(candidate.nucleus)
						if d < distance:
							distance = d
							food = candidate
				if food != null and body.stored_food < 3:
					if body.target_id != food.id:
						body.action_clock = 0.0
					body.target_id = food.id
					body.destination = food.nucleus
					if distance < 18.0:
						body.action_clock += delta
						if body.action_clock >= 4.0:
							body.action_clock = 0.0
							body.stored_food += 1
							eaten_food += 1
							remove.append(food.id)
				else:
					body.destination = run.board.center + (body.nucleus-run.board.center).normalized()*435.0
				if body.nucleus.distance_to(run.board.center)>408.0 and (body.kind!="bacterium" or body.infection_age<0.0):
					remove.append(body.id)
			"parasite":
				# It extends a visible tether into the neighboring cell while its
				# body remains in a capturable triangle that does not use that cell.
				body.destination = Vector2.ZERO
				for node in body.site_nodes:
					body.destination += run.board.anchors[node]/float(body.site_nodes.size())
				if body.latched:
					body.nucleus = body.destination
				elif body.nucleus.distance_to(body.destination)<6.0:
					body.action_clock += delta
					if body.action_clock >= 7.0 and not run.selection.path.has(body.target_node) and run.cells[body.target_node].is_ready() and not run.amoebas.reserved(run,body.target_node,body.id):
						body.latched = true
						announce("A parasite blocked a cell · capture its coral body")
			"divider":
				if not body.daughter and body.split_remaining() <= 0.0:
					remove.append(body.id)
					var axis: Vector2 = (body.nucleus-run.board.center).orthogonal().normalized()
					for sign_value in [-1,1]:
						newborns.append({"area":body.sector,"position":body.nucleus+axis*float(sign_value)*20.0,"form":body.form})
					announce("Divider split · catch both young hunters in one loop")
	run.enemies = run.enemies.filter(func(body): return not remove.has(body.id))
	for child in newborns:
		var body = add(run,"divider",child.area,child.position,child.form)
		body.daughter = true
		body.speed = 7.0
		body.spawning = 1.0

func prey_for(run: RefCounted, hunter: RefCounted) -> RefCounted:
	for body in run.enemies:
		if body.id==hunter.hunt_target:
			return body
	return null

func hunt_destination(run: RefCounted, body: RefCounted) -> Vector2:
	if body.hunt_target>=0:
		var prey = prey_for(run,body)
		if prey != null:
			return prey.nucleus
	return run.board.center

func eating_progress(run: RefCounted, prey_id: int) -> float:
	var progress := 0.0
	for hunter in run.enemies:
		if hunter.hunt_target==prey_id:
			progress = maxf(progress,hunter.hunt_time/FEEDING_TIME)
	return progress

func step_food_web(run: RefCounted, delta: float) -> void:
	if run.stage_index<2:
		return
	var eaten: Array = []
	for hunter in run.enemies:
		if hunter.kind not in ["drifter","twinspore"] or hunter.age<2.5:
			continue
		if hunter.hunt_target<0 and not hunter.foraging_done:
			var candidates: Array = run.enemies.filter(func(e): return e.kind in ["food","spore"] and e.gate_ids.is_empty() and e.age>2.0 and e.nucleus.distance_to(hunter.nucleus)<100.0 and not run.enemies.any(func(h): return h.hunt_target==e.id))
			candidates.sort_custom(func(a,b): return a.nucleus.distance_to(hunter.nucleus)-(30.0 if a.kind=="spore" else 0.0)<b.nucleus.distance_to(hunter.nucleus)-(30.0 if b.kind=="spore" else 0.0))
			if not candidates.is_empty():
				hunter.hunt_target = candidates[0].id
				hunter.forage_remaining = 24.0
		if hunter.hunt_target<0:
			continue
		var prey = prey_for(run,hunter)
		hunter.forage_remaining = maxf(0.0,hunter.forage_remaining-delta)
		if prey==null or hunter.forage_remaining<=0.0:
			hunter.hunt_target = -1
			hunter.hunt_time = 0.0
			hunter.foraging_done = true
			continue
		if hunter.nucleus.distance_to(prey.nucleus)<22.0 and hunter.stunned<=0.0:
			hunter.hunt_time += delta
			if hunter.hunt_time>=FEEDING_TIME:
				eaten.append(prey.id)
				if prey.kind=="food":
					hunter.carried_food += 1
					eaten_food += 1
				else:
					escaped_spores += 1
				hunter.hunt_target = -1
				hunter.hunt_time = 0.0
				hunter.fed_remaining = 8.0
				hunter.foraging_done = true
				announce("Hunter is digesting · recover its food" if prey.kind=="food" else "A spore was eaten · catch hunter and spore together next time")
		else:
			hunter.hunt_time = maxf(0.0,hunter.hunt_time-delta*0.5)
	# Small shoals gather naturally; threatened life scatters at human-readable speed.
	for body in run.enemies:
		if body.kind not in ["food","spore"]:
			continue
		var drift := Vector2.ZERO
		var neighbors := 0
		if body.kind=="food" and body.bloom_id>=0:
			for other in run.enemies:
				if other.id!=body.id and other.kind=="food" and other.bloom_id==body.bloom_id and body.nucleus.distance_to(other.nucleus)<65.0:
					drift += other.nucleus-body.nucleus
					neighbors += 1
			if neighbors>0:
				drift = (drift/float(neighbors)).limit_length(0.45)
		for hunter in run.enemies:
			if hunter.kind in ["drifter","twinspore","grazer"]:
				var away: Vector2 = body.nucleus-hunter.nucleus
				if away.length()<72.0:
					drift += away.normalized()*(1.0-away.length()/72.0)*(1.2 if body.kind=="spore" else 0.65)
		body.origin += drift.limit_length(1.5)*maxf(delta,0.0)
		body.origin = run.board.center+(body.origin-run.board.center).limit_length(run.board.dish_radius-48.0)
	run.enemies = run.enemies.filter(func(e): return not eaten.has(e.id))

func disturb_survivors(run: RefCounted, center: Vector2) -> void:
	for body in run.enemies:
		if body.kind in ["food","spore"] and body.nucleus.distance_to(center)<135.0:
			var away: Vector2 = (body.nucleus-center).normalized()
			body.pull_toward(body.nucleus+away*20.0,5.0)

func queue_wave(run: RefCounted) -> void:
	var area := Rhythm.sector(run,wave)
	var mode: String = run.harvest.spec.mode
	var family := "grazer" if run.stage_index < 4 else "parasite" if wave%2 == 0 else "grazer"
	if (run.stage_index == 6 and wave%2 == 0) or (run.stage_index >= 8 and wave%2 == 1):
		family = "divider"
	if (run.stage_index==5 and wave%3==0) or (run.stage_index>=8 and wave%3==2): family = "amoeba"
	var families: Array = run.harvest.spec.get("families",[])
	if not families.is_empty():
		family = families[wave%families.size()]
	if run.stage_index==2 and wave==1 and families.is_empty(): family = "bacterium"
	if run.stage_index>=4 and wave%3==1 and families.is_empty(): family = "bacterium"
	# Food and the special organism occupy adjacent pockets. Capturing either
	# uses some of the same blue cells; a wide loop can solve both at once.
	var arrives: float = run.stage_elapsed+8.0
	pending.append({"at":arrives,"kind":"bloom","area":area})
	pending.append({"at":arrives,"kind":family,"area":area})
	if (run.stage_index >= 2 or wave>0) and run.Habitats.hunter_arrives(run,wave) and not (run.harvest.spec.get("phage_lesson",false) and wave==0):
		var hunter := {"at":arrives if early_hunters(run) else arrives+4.0,"kind":"hunter","area":(area+3)%8}
		if run.harvest.spec.has("hunter"):
			hunter.species = run.harvest.spec.hunter
		pending.append(hunter)
		if int(pace.extra_every)>0 and wave%int(pace.extra_every)==0 and run.habitat_choice!="refuge":
			# A staggered second front leaves time for a deliberate first capture.
			# The sheltered route keeps its advertised single, alternate waves.
			pending.append({"at":arrives+6.0 if early_hunters(run) else arrives+10.0,"kind":"hunter","area":(area+6)%8,"species":"drifter"})
	if mode == "rescue":
		pending.append({"at":arrives,"kind":"spore","area":area})
	wave += 1
	announce("Life approaches in 8s · watch the marked water")

func arrival_site(run: RefCounted, event: Dictionary) -> Dictionary:
	var area: int = event.area
	var point := pocket(run,area,event.kind in ["hunter","parasite"])
	var site := {"position":point if event.kind=="hunter" else point+Vector2(18,-12),"nodes":[],"target":8+area,"destination":point}
	if event.kind != "parasite":
		return site
	var best := INF
	for triangle in run.board.triangles:
		if triangle.has(site.target):
			continue
		var center := Vector2.ZERO
		for node in triangle:
			center += run.board.anchors[node]/3.0
		var value: float = center.distance_to(run.board.anchors[site.target])
		for other in run.enemies:
			if other.kind == "cyst" and run.Geometry.contains(other.nucleus,run.Geometry.polygon_for(triangle,run.board.anchors)):
				value += 1000.0
		if value<best:
			best = value
			site.nodes = triangle.duplicate()
			site.destination = center
			site.position = center+Vector2(18,-12)
	return site

func spawn_event(run: RefCounted, event: Dictionary) -> void:
	var area: int = event.area
	match event.kind:
		"bloom":
			run.harvest.spawn_bloom(run,area)
		"spore":
			if run.enemies.filter(func(e): return e.kind == "spore").size()<3:
				run.harvest.spawn_spore(run,area)
		"hunter":
			if run.enemies.filter(func(e): return e.kind in ["drifter","shellback","twinspore","divider"]).size()>=4:
				return
			var kind := "drifter"
			if run.stage_index>=4 and wave%2==0:
				kind = "shellback" if run.stage_index<8 else "twinspore"
			kind = event.get("species",kind)
			var point: Vector2 = arrival_site(run,event).position
			var outward: Vector2 = (point-run.board.center).normalized()
			run.spawn_enemy({"angle":rad_to_deg(outward.angle()),"radius":310.0,"position":point,"speed":hunter_speed(run)+(2.0 if event.get("rapid_surge",false) else 0.0),"kind":kind})
			run.harvest.threats_spawned += 1
			if event.get("final_surge",false):
				run.harvest.final_surge_ids.append(run.next_enemy_id)
		_:
			if run.enemies.filter(func(e): return e.kind == event.kind).size()>=(1 if event.kind=="amoeba" and run.stage_index<8 else 2):
				return
			var site := arrival_site(run,event)
			var body = add(run,event.kind,area,site.position)
			if event.kind=="bacterium": run.phages.pair(run,body)
			if event.kind == "parasite":
				body.target_node = site.target
				body.site_nodes = site.nodes
				body.destination = site.destination
			elif event.kind == "grazer":
				body.destination = site.destination

func pressure_text(run: RefCounted) -> String:
	if notice_time>0.0:
		return notice
	var beat := Rhythm.sample(run)
	return beat.title + (" · %ds" % ceili(beat.remaining) if beat.remaining > 0.0 else "")

func step_cradles(run: RefCounted) -> void:
	# A freed cradle is ordinary vulnerable prey. Protect it through one short,
	# clearly advertised wait to bring two actual young lives home instead.
	for holder in run.enemies.duplicate():
		if not holder.cradle or holder.hatch_remaining()!=0.0:
			continue
		run.enemies.erase(holder)
		var axis: Vector2 = (holder.nucleus-run.board.center).orthogonal().normalized()
		if axis.is_zero_approx():
			axis = Vector2.RIGHT
		for i in 2:
			run.next_enemy_id += 1
			var young = run.Harvest.Organism.new(run.next_enemy_id,"spore",holder.nucleus+axis*(-13.0 if i==0 else 13.0),Vector2(7,6),float(i)*PI)
			young.form = "snow_spore" if i==0 else "sail_spore"
			young.story = "hatchling"
			run.enemies.append(young)
			run.discover(young.form)
		announce("The cradle hatched · rescue both pearl-white young")
