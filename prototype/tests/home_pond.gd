extends "res://tests/journey_rules.gd"

func exercise() -> void:
	var run := Run.new(true,73,true,true)
	fixture_stage(run,2)
	var scheduled: float = run.harvest.visitor_at
	expect(scheduled>=36.0 and scheduled<=44.0,"A rare visitor is scheduled in the first biome's recovery interval")
	run.stage_elapsed = scheduled
	run.enemies.clear()
	run.harvest.Discoveries.step(run)
	var visitor = run.enemies[0]
	expect(visitor.visitor and visitor.form=="moonlace" and visitor.age==0.0,"The real director creates a distinct visitor with a fresh organic arrival")
	expect(visitor.lifetime()==72.0,"An optional discovery leaves ample time to watch and rescue")
	visitor.step(6.0,run.board.center)
	run.harvest.Discoveries.step(run)
	expect(visitor.opening()==1.0 and visitor.bloom_releases==1 and run.enemies.filter(func(e): return e.kind=="food").size()==2,"Leaving Moonlace alive releases actual edible food as its petals open")
	var snapshot := Save.capture(run)
	var restored := Run.new(true,42,true,true)
	expect(Save.restore(restored,snapshot),"Visitor and rescue state restore through the normal journey save")
	restored.harvest.Discoveries.step(restored)
	expect(restored.enemies.size()==run.enemies.size() and restored.enemies[0].bloom_releases==1,"Resume neither duplicates the visitor nor replays its food bloom")
	restored.state = Run.PAUSED
	var age: float = restored.enemies[0].age
	restored.step(20.0)
	expect(restored.enemies[0].age==age,"Pause freezes the visitor's lifetime and food cycle")
	# A normal legal membrane rescues the actual living entity; watching or
	# discovering it alone must never fabricate a home-pond resident.
	var profile := Profile.new()
	profile.path = "/tmp/microverse-home-residents-test.cfg"
	profile.observe(run)
	expect(profile.residents.is_empty(),"Observing a visitor alone does not put it in the home pond")
	run.enemies = [visitor]
	visitor.origin = (run.board.anchors[0]+run.board.anchors[8]+run.board.anchors[9])/3.0
	visitor.nucleus = visitor.origin
	select(run)
	var result: Dictionary = run.release()
	expect(result.rescued==1 and run.rescued_specimens.size()==1,"A valid player capture records one real rescued specimen")
	profile.observe(run)
	profile.observe(run)
	expect(profile.residents.size()==1 and profile.residents[0].form=="moonlace" and profile.residents[0].rare and profile.residents[0].stage==2,"The resident preserves its identity and origin without duplicate observations")
	var loaded := Profile.new()
	loaded.path = profile.path
	loaded.load_profile()
	expect(loaded.residents==profile.residents,"Actual residents persist on disk independently of the active journey")
	var young_size: float = loaded.maturity(loaded.residents[0])
	run.state = Run.EVOLVE
	run.mutations = ["elastic","nursery"]
	loaded.observe(run)
	var grown_size: float = loaded.maturity(loaded.residents[0])
	expect(grown_size>young_size and loaded.last_colony_traits==run.mutations,"A newly completed encounter grows real residents and remembers Mother anatomy")
	loaded.observe(run)
	expect(loaded.maturity(loaded.residents[0])==grown_size,"Autosaving a completed encounter never farms additional resident growth")
	var memory := Profile.new()
	memory.path = loaded.path
	memory.load_profile()
	expect(memory.cleared_encounters==loaded.cleared_encounters and memory.maturity(memory.residents[0])==grown_size and memory.last_colony_traits==run.mutations,"Growth and the evolved home Mother persist on disk")
	run.state = Run.ACTIVE
	var after_capture := Save.capture(run)
	Save.restore(restored,after_capture)
	loaded.observe(restored)
	expect(loaded.residents.size()==1,"Resuming the same captured specimen cannot duplicate its home resident")
	Save.restore(restored,snapshot)
	var retry_visitor = restored.enemies[0]
	restored.enemies = [retry_visitor]
	retry_visitor.nucleus = (restored.board.anchors[0]+restored.board.anchors[8]+restored.board.anchors[9])/3.0
	select(restored)
	var retry_capture: Dictionary = restored.release()
	loaded.observe(restored)
	expect(retry_capture.rescued==1 and loaded.residents.size()==1,"Capturing the same individual again after a checkpoint restore cannot multiply residents")
	var legacy := after_capture.duplicate(true)
	legacy.run.erase("rescued_specimens")
	Save.restore(restored,legacy)
	expect(restored.rescued_specimens.is_empty(),"Legacy journey saves do not inherit or invent a previous run's rescues")
	run.restart()
	loaded.observe(run)
	expect(run.rescued_specimens.is_empty() and loaded.residents.size()==1,"Starting a new journey preserves the permanent pond")
	for biome in 3:
		var visits := 0
		for stage in range(biome*4,biome*4+4):
			fixture_stage(run,stage)
			if run.harvest.visitor_at>0.0:
				visits += 1
		expect(visits==1,"Exactly one optional visitor is scheduled in biome %d" % biome)
	run.dispose()
	restored.dispose()
	print("HOME POND RULES: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
