extends RefCounted
## One optional visitor per biome, on a repeatable quiet encounter. This uses
## its own seed so discoveries never reshuffle the authored encounter director.
static func begin(run: RefCounted) -> void:
	var variation := RandomNumberGenerator.new()
	variation.seed = run.run_seed ^ (0x711a + run.stage_index/4)
	var stage: int = 2 if run.stage_index<4 else run.stage_index/4*4+variation.randi_range(0,2)
	if run.stage_index==stage:
		run.harvest.visitor_at = 36.0+variation.randf_range(0.0,8.0)

static func site(run: RefCounted) -> Vector2:
	return run.harvest.ecology.pocket(run,(run.harvest.rotation+5)%8,true)

static func form_for(run: RefCounted) -> String:
	return ["moonlace","glass_harp","glowdrift"][clampi(run.stage_index/4,0,2)]

static func name_for(run: RefCounted) -> String:
	return run.JourneyPlan.SPECIES.filter(func(entry): return entry.id==form_for(run))[0].name

static func step(run: RefCounted, delta: float = 0.0) -> void:
	preload("res://scripts/expedition_creatures.gd").step(run)
	var harvest = run.harvest
	if harvest.visitor_at>0.0 and not harvest.visitor_spawned and run.stage_elapsed>=harvest.visitor_at:
		run.next_enemy_id += 1
		var visitor = run.Harvest.Organism.new(run.next_enemy_id,"spore",site(run),Vector2(24,18),1.3)
		visitor.visitor = true
		visitor.form = form_for(run)
		run.enemies.append(visitor)
		harvest.visitor_spawned = true
		run.discover(visitor.form)
		harvest.ecology.announce("A %s is visiting · watch it help, or bring it home" % name_for(run))
	for body in run.enemies.duplicate():
		if body.visitor and body.form=="glowdrift":
			if body.opening()>0.45:
				for hunter in run.enemies:
					if hunter.kind in ["drifter","shellback","twinspore","divider"] and not hunter.is_boss() and hunter.nucleus.distance_to(body.nucleus)<125.0:
						hunter.slowed = maxf(hunter.slowed,0.7)
			continue
		if body.visitor and body.form=="glass_harp":
			separate_food(run,body,delta)
			continue
		if not body.visitor or body.age<6.0+18.0*body.bloom_releases:
			continue
		body.bloom_releases += 1
		for i in 2:
			run.next_enemy_id += 1
			var angle: float = body.bloom_releases*2.399+i*PI
			var food = run.Harvest.Organism.new(run.next_enemy_id,"food",body.nucleus+Vector2.from_angle(angle)*37.0,Vector2(14,12),angle)
			food.bloom_id = -100000-body.id*8-body.bloom_releases
			run.enemies.append(food)

static func separate_food(run: RefCounted, visitor: RefCounted, delta: float) -> void:
	# A real, bounded current: food gathers and poison separates. Capture
	# geometry follows the moving bodies; no cyst vanishes or advances a goal.
	var current: float = visitor.opening()*delta
	for body in run.enemies:
		if body.kind not in ["food","cyst"] or body.nucleus.distance_to(visitor.nucleus)>140.0:
			continue
		var direction: Vector2 = visitor.nucleus-body.nucleus
		if body.kind=="cyst":
			direction = -direction
		var shift: Vector2 = direction.limit_length(2.4*current)
		if (body.origin+shift).distance_to(run.board.center)<=338.0:
			body.origin += shift
