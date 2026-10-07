extends "res://tests/journey_rules.gd"

func quiet(run: RefCounted, index: int) -> void:
	fixture_stage(run,index)
	run.harvest.next_bloom = 9999.0
	run.harvest.ecology.next_wave = 9999.0
	run.harvest.ecology.pending.clear()
	run.harvest.spec.food = 999

func tick(run: RefCounted, seconds: float) -> void:
	for i in ceili(seconds*60.0):
		run.step(1.0/60.0)

func capture_body(run: RefCounted, body: RefCounted) -> Dictionary:
	for triangle in run.board.triangles:
		if triangle.any(func(id): return not run.is_ready(id)):
			continue
		var polygon: PackedVector2Array = run.Geometry.polygon_for(triangle,run.board.anchors)
		if Array(body.nuclei()).all(func(point): return run.Geometry.contains(point,polygon)):
			select(run,triangle)
			return run.release()
	return {"valid":false}

func exercise() -> void:
	var run := Run.new(true,73,true,true)
	quiet(run,1)
	run.enemies.clear()
	var eco = run.harvest.ecology
	var place: Vector2 = eco.pocket(run,0)
	run.next_enemy_id += 1
	var food := run.Harvest.Organism.new(run.next_enemy_id,"food",place,Vector2.ZERO,0.0)
	run.enemies.append(food)
	var grazer = eco.add(run,"grazer",0,place)
	grazer.spawning = 0.0
	grazer.speed = 0.0
	tick(run,3.8)
	expect(run.enemies.has(food) and grazer.stored_food==0,"Grazer leaves time to react before its first bite")
	tick(run,0.3)
	expect(not run.enemies.has(food) and grazer.stored_food==1 and run.integrity==5,"Grazer steals real food without damaging the mother")
	var result := capture_body(run,grazer)
	expect(result.valid and result.food==1 and result.salvage==1,"Capturing a grazer returns its stolen food through the actual resolver")
	quiet(run,4)
	run.enemies.clear()
	eco = run.harvest.ecology
	eco.spawn_event(run,{"kind":"parasite","area":0})
	var parasite = run.enemies[-1]
	parasite.nucleus = parasite.destination
	parasite.spawning = 0.0
	select(run,[0,8,9])
	eco.step(run,7.1)
	expect(not parasite.latched and run.selection.closed,"Parasite does not invalidate a held gesture")
	run.selection.cancel()
	eco.step(run,0.1)
	expect(parasite.latched and not run.is_ready(parasite.target_node),"Parasite actually blocks its indicated cell")
	expect(not parasite.site_nodes.has(parasite.target_node),"Blocked cell is not required to capture its parasite")
	var saved := Save.capture(run)
	var clone := Run.new(true,33,true,true)
	expect(Save.restore(clone,saved) and not clone.is_ready(parasite.target_node),"Save/resume preserves parasite attachment and blocked input")
	result = capture_body(run,parasite)
	expect(result.valid and result.threats==1 and run.is_ready(parasite.target_node),"Alternate triangle captures parasite and frees its cell immediately")
	clone.dispose()
	quiet(run,8)
	run.enemies.clear()
	eco = run.harvest.ecology
	var divider = eco.add(run,"divider",0,run.board.center+Vector2(230,0))
	divider.age = 19.8
	divider.spawning = 0.0
	tick(run,0.3)
	expect(not run.enemies.has(divider) and run.enemies.size()==2,"Ignored divider becomes two independently capturable offspring")
	for child in run.enemies:
		child.age = 30.0
		child.spawning = 0.0
	eco.step(run,1.0)
	expect(run.enemies.size()==2 and run.enemies.all(func(e): return e.daughter),"Division is bounded; offspring do not multiply indefinitely")
	quiet(run,7)
	var boss = run.boss()
	run.enemies = run.enemies.filter(func(e): return e.is_boss() or e.kind=="warden")
	run.harvest.nourishment = 6
	eco = run.harvest.ecology
	expect(boss.gate_ids.size()==2 and not boss.can_take_pulse(),"Regent begins with two real shield organisms")
	boss.step(60.0,run.board.center)
	expect(not boss.can_take_pulse(),"Waiting alone cannot open the boss")
	var guards: Array = run.enemies.filter(func(e): return e.kind=="warden")
	result = capture_body(run,guards[0])
	expect(result.valid and result.wardens==1 and not boss.can_take_pulse(),"First shield capture leaves one active shield")
	tick(run,3.2)
	result = capture_body(run,guards[1])
	expect(result.valid and boss.can_take_pulse() and boss.open_remaining==14.0,"Final shield capture creates a fourteen-second opening")
	# The opening has room for recovery, thought and a four-edge 2 segments/s drag.
	tick(run,5.3)
	select(run,[0,8,9,1])
	expect(run.harvest_preview().boss_layers==1,"Boss is capturable after recovery and deliberation")
	result = run.release()
	expect(result.valid and result.boss_layers==1 and boss.health==2 and run.harvest.nourishment==3,"Player-created opening produces a real charged boss hit")
	tick(run,4.2)
	expect(boss.gate_ids.size()==2 and not boss.can_take_pulse(),"A successful hit sets up the next shield puzzle")
	var old := Save.capture(run)
	old.version = 1
	old.erase("ecology")
	old.enemies = old.enemies.filter(func(e): return not e.has("living"))
	for e in old.enemies:
		if e.has("boss"):
			for key in ["gate_ids","open_remaining","reset_remaining","round_index"]:
				e.boss.erase(key)
	clone = Run.new(true,11,true,true)
	expect(Save.restore(clone,old),"Previous save format remains loadable")
	expect(clone.boss().health==2 and clone.harvest.nourishment==3 and clone.boss().gate_ids.size()==2,"Migration keeps boss progress and creates playable shields")
	clone.dispose()
	quiet(run,6)
	eco = run.harvest.ecology
	eco.next_wave = 12.0
	tick(run,25.0)
	expect(run.enemies.any(func(e): return e.kind=="divider") and run.enemies.any(func(e): return e.kind=="drifter") and run.enemies.any(func(e): return e.kind=="spore"),"A real encounter overlaps rescue, a dividing organism and defense")
	expect(eco.next_wave>run.stage_elapsed+20.0 and eco.pending.all(func(e): return e.at<=eco.pace.rest),"Staggered arrivals finish within the activity phase, before a breathing interval")
	# Storage must not quietly discard objective progress, including legacy saves.
	quiet(run,0)
	run.biomass = 29
	meal(run,["food","food","food"])
	select(run)
	result = run.release()
	expect(result.food==3 and run.harvest.nourishment==3 and run.biomass==30,"Full storage still allows the whole meal to advance the objective")
	run.biomass = 120
	run.bank_food(4)
	expect(run.biomass==120,"Previously saved surplus is preserved without growing further")
	settle(run)
	run.state = Run.EVOLVE
	run.offered_mutations = ["fission","elastic","symbiosis"]
	expect(run.choose_journey_evolution("fission") and run.biomass==114 and run.evolution_cost()==8,"Evolution charges the displayed price before increasing the next price")
	run.state = Run.EVOLVE
	run.integrity = 2
	run.biomass = 6
	expect(run.choose_journey_evolution("repair") and run.integrity==4 and run.biomass==0,"Repair trades one evolution opportunity and six food for two health")
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	expect(run.Mutations.journey_offers([],rng)==["fission","elastic"],"First evolution uses the two feeding styles taught in practice")
	for anchor in ["fission","elastic","symbiosis"]:
		var offered: Array = run.Mutations.journey_offers([anchor],rng)
		var family: Array = run.Mutations.BUILD_PATHS[anchor].synergy
		expect(offered.size()==3 and offered.filter(func(id): return family.has(id)).size()==2,"Offers support "+anchor+" while leaving a different choice")
	quiet(run,1)
	var area := 0
	run.enemies.clear()
	run.harvest.spawn_bloom(run,area)
	run.harvest.spawn_spore(run,area)
	var pearl = run.enemies[-1]
	var rescue_path: Array = [8,16,17]
	expect(run.Geometry.contains(pearl.nucleus,run.Geometry.polygon_for(rescue_path,run.board.anchors)),"Rescue has its own visible neighboring pocket")
	select(run,[0,8,9])
	result = run.release()
	expect(result.food>0 and result.rescued==0 and not run.is_ready(8),"Feeding spends the shared cell without automatically rescuing the neighboring spore")
	settle(run)
	select(run,rescue_path)
	result = run.release()
	expect(result.valid and result.rescued==1 and result.poison==0,"The same cells recover in time for a clean deliberate rescue")
	quiet(run,1)
	run.enemies = run.enemies.filter(func(e): return e.kind=="spore")
	run.enemies[0].age = 12.0
	var guidance = preload("res://scripts/journey_guidance.gd")
	expect(guidance.next_action(run).title=="Rescue the fading spore","A time-limited rescue takes guidance priority over plentiful food")
	quiet(run,5)
	run.enemies.clear()
	run.harvest.spawn_bloom(run,0)
	run.harvest.visited = [0,1,2,3,4,5,6,7]
	expect(guidance.next_action(run).target>=0,"After the area quota is met, food guidance includes already-fed areas")
	run.dispose()
	print("JOURNEY ECOLOGY: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
