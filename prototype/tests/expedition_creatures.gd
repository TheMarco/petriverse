extends "res://tests/harvest_visual.gd"
const Forms = preload("res://scripts/creature_forms.gd")
const Expedition = preload("res://scripts/expedition_creatures.gd")
const Save = preload("res://scripts/journey_save.gd")

func enter(run: RefCounted, index: int) -> void:
	run.route_position = index
	run.stage_index = run.route_plan[index].stage
	run.start_stage()
	run.begin_encounter()

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-expedition-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-expedition-profile-unused.cfg"
	root.add_child(game)
	# Each check begins with a genuinely new collector; prior fixture runs may
	# have completed the /tmp journal already, where repeats are then legitimate.
	game.journey_profile = preload("res://scripts/journey_profile.gd").new()
	game.journey_profile.path = "/tmp/microverse-expedition-profile-unused.cfg"
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	var run = game.run
	var found: Array = []
	for journey_number in 4:
		run.fixed_seed = 73+journey_number*31
		game.new_journey("wanderer")
		var roster: Array = run.expedition_roster.duplicate(true)
		expect(roster.size()==3 and Expedition.valid(roster,run.route_plan),"One valid rare population per biome")
		expect(roster==Expedition.plan(run.run_seed,run.route_plan,game.journey_profile.discovered),"Known history and seed reproduce rare population")
		var rng_before: int = run.rng.state
		Expedition.plan(run.run_seed,run.route_plan,game.journey_profile.discovered)
		expect(run.rng.state==rng_before,"Discovery planning does not reshuffle the encounter RNG")
		for visit in roster:
			expect(not found.has(visit.form),"Unseen form preferred: "+visit.form)
			enter(run,visit.encounter)
			run.stage_elapsed = 7.9
			Expedition.step(run)
			expect(not run.enemies.any(func(e): return e.form==visit.form),"Rare arrival waits for its simulation cue")
			var before := Save.capture(run)
			run.stage_elapsed = 8.0
			Expedition.step(run)
			var bodies: Array = run.enemies.filter(func(e): return e.form==visit.form)
			expect(bodies.size()==1 and bodies[0].age==0.0,"Scheduled creature emerges exactly once: "+visit.form)
			expect(run.seen_species.has(visit.form) and not bodies[0].visitor,"Real discovery recorded without granting unrelated helper powers")
			var count: int = run.enemies.size()
			Expedition.step(run)
			expect(run.enemies.size()==count,"Repeated update cannot duplicate the discovery")
			var clone := Run.new(true,99,true,true)
			var config := ConfigFile.new()
			config.set_value("fixture","snapshot",Save.capture(run))
			expect(config.save("/tmp/microverse-expedition-roundtrip.cfg")==OK,"Write rare encounter snapshot")
			var disk := ConfigFile.new()
			disk.load("/tmp/microverse-expedition-roundtrip.cfg")
			expect(Save.restore(clone,disk.get_value("fixture","snapshot")) and clone.expedition_roster==run.expedition_roster,"Resume preserves selected forms and spawned flags")
			Expedition.step(clone)
			expect(clone.enemies.size()==count and clone.enemies.any(func(e): return e.form==visit.form),"Resume retains the actual rare body without spawning another")
			expect(Save.restore(clone,before),"Restore just before the arrival")
			clone.stage_elapsed = 8.0
			Expedition.step(clone)
			expect(clone.enemies.any(func(e): return e.form==visit.form),"Pre-arrival save produces the same discovery")
			clone.dispose()
			game.journey_profile.observe(run)
			found.append(visit.form)
			run.state = Run.LOSS
			expect(run.retry_encounter(),"Retry restores the encounter checkpoint")
			run.begin_encounter()
			run.stage_elapsed = 8.0
			Expedition.step(run)
			expect(run.enemies.any(func(e): return e.form==visit.form),"Retry preserves the discovery instead of rerolling it")
		expect(found.size()==(journey_number+1)*3,"A journey can introduce only three of the twelve rare forms")
	expect(found.size()==12 and Expedition.ENTRIES.all(func(e): return found.has(e.id)),"Four completed discovery routes reveal all twelve forms")
	var profile = preload("res://scripts/journey_profile.gd").new()
	profile.path = game.journey_profile.path
	profile.load_profile()
	expect(found.all(func(id): return profile.discovered.has(id)),"Rare discoveries survive an actual profile disk reload")
	var old := Save.capture(run)
	old.erase("expedition_roster")
	var restored := Run.new(true,29,true,true)
	expect(Save.restore(restored,old) and restored.expedition_roster.is_empty(),"Existing journeys gain no surprise rare spawns mid-save")
	var broken := Save.capture(run)
	broken.expedition_roster[0].encounter = 999
	expect(not Save.restore(restored,broken),"Invalid rare encounter rejected before mutation")
	restored.dispose()
	# Each new form uses its familiar family's real body, arrival and capture rules.
	for entry in Expedition.ENTRIES:
		run.enemies.clear()
		var body = Expedition.spawn(run,entry)
		expect(body.form==entry.id and body.kind==entry.kind and body.age==0.0,"Newborn has correct anatomy and role: "+entry.id)
		if entry.kind=="parasite":
			expect(body.target_node>=0 and body.site_nodes.size()==3,"Veil parasite has a real reachable latch site")
		if entry.kind=="shellback":
			expect(body.health==2 and not body.apply_pulse(1) and body.apply_pulse(1),"Rare armor still requires two ordinary captures")
		if entry.kind=="spore":
			run.state = Run.ACTIVE
			var at := Vector2.ZERO
			for id in [0,8,9]: at += run.board.anchors[id]/3.0
			body.origin = at
			body.nucleus = at
			for cell in run.cells: cell.remaining = 0.0
			run.selection.start(run.board.anchors[0])
			for id in [8,9,0]: run.selection.visit(id)
			var result: Dictionary = run.release()
			expect(result.get("rescued",0)==1 and run.rescued_specimens[-1].form==entry.id and run.rescued_specimens[-1].rare,"New spore can become an identified rare pond resident")
	# Native pictures show each biome's small rare population, never all at once.
	for biome in 3:
		var index: int = run.route_plan.find(run.route_plan.filter(func(spec): return int(spec.stage)/4==biome and spec.get("generated",false) and int(spec.stage)>=biome*4+2)[0])
		enter(run,index)
		run.enemies.clear()
		game.effects.clear()
		game.reset_presentation()
		var entries: Array = Expedition.ENTRIES.filter(func(e): return int(e.first_stage)/4==biome)
		for i in entries.size():
			var body = Expedition.spawn(run,entries[i])
			body.nucleus = run.board.center+Vector2.from_angle(-PI*0.5+i*TAU/4.0)*202.0
			if body.kind in ["food","cyst","spore"]: body.origin = body.nucleus
			body.age = 5.0
			if body.kind in ["grazer","parasite","divider"]: body.spawning = 0.0
		game.last_discovery = run.discovery_serial
		game.toast_time = 0.0
		await capture("expedition-biome-%d" % biome)
	game.journal_open = true
	game.hud.turn_journal(99)
	await capture("expedition-journal")
	expect(run.JourneyPlan.SPECIES.size()==41 and not game.hud.journal_next.visible,"Expanded 41-entry journal reaches its last page")
	game.journal_open = false
	run.enemies.clear()
	var body = run.harvest.ecology.add(run,"grazer",1,run.board.center+Vector2(140,-90),"chalice_grazer")
	body.age = 5.0
	body.spawning = 0.0
	await capture("expedition-chalice-in-game")
	var sprite: Sprite2D = game.microscope.enemies[body.id].get_meta("lobes")[0]
	expect(sprite.texture==Forms.texture("chalice_grazer"),"Rare creature uses its own generated tissue")
	var uv: Vector2 = sprite.material.get_shader_parameter("nucleus_uv")
	var center: Vector2 = sprite.to_global(sprite.offset+(uv-Vector2.ONE*0.5)*sprite.texture.get_size())
	expect(center.distance_to(body.nucleus)<0.1,"New capture nucleus registers to the real sprite")
	game.queue_free()
	await process_frame
	print("EXPEDITION CREATURES: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
