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
	expect(not run.enemies.has(food) and grazer.stored_food==1 and run.integrity==run.max_integrity,"Grazer steals real food without damaging the mother")
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
	quiet(run,6)
	run.mutations = ["elastic","catalyst","lure","feast","enzyme","filter"]
	eco = run.harvest.ecology
	eco.queue_wave(run)
	var hunters: Array = eco.pending.filter(func(event): return event.kind=="hunter")
	expect(hunters.size()==2 and is_equal_approx(hunters[0].at,8.0) and is_equal_approx(hunters[1].at,14.0),"An evolved Glassgarden colony faces two staggered, warned hunters on the food-rich route")
	expect(eco.Rhythm.warning_sites(run).filter(func(site): return site.kind=="hunter").size()==1,"The earlier hunter still has an eight-second arrival mark")
	eco.spawn_event(run,hunters[0])
	expect(run.enemies.any(func(body): return body.kind in ["drifter","shellback"] and body.speed>7.5),"Later hunters cross the dish sooner against a fully evolved colony")
	var current_stage: int = run.stage_index
	var current_route: Array = run.route_plan.duplicate(true)
	run.stage_index = 9
	run.route_plan = range(30)
	run.biomass = 30
	var stocked_speed: float = eco.hunter_speed(run)
	run.biomass = 0
	expect(stocked_speed>10.0 and eco.hunter_speed(run)<stocked_speed-2.0,"Stored food strengthens late hunter pursuit without accelerating an empty colony")
	run.stage_index = current_stage
	run.route_plan = current_route
	quiet(run,6)
	run.harvest.spec.mode = "feed"
	run.harvest.spec.generated = true
	run.harvest.spec.stage = 6
	expect(run.harvest.hunter_quota()==2,"Glassgarden feeding visits ask for real hunter captures")
	run.harvest.spec.food = 3
	run.harvest.nourishment = 3
	run.enemies.clear()
	var hunter_center: Vector2 = (run.board.anchors[0]+run.board.anchors[8]+run.board.anchors[9])/3.0
	for capture_number in 2:
		run.next_enemy_id += 1
		run.enemies.append(run.Drifter.new(run.next_enemy_id,hunter_center,0.0))
		select(run,[0,8,9])
		result = run.release()
		expect(result.valid and run.harvest.hunters_captured==capture_number+1,"A feeding visit counts only real hunter captures")
		if capture_number==0:
			expect(run.state==Run.ACTIVE and run.harvest.hunter_quota()==2,"Enough food alone cannot finish a later feeding visit")
			var mid_visit := Save.capture(run)
			var restored_visit := Run.new(true,99,true,true)
			expect(Save.restore(restored_visit,mid_visit) and restored_visit.harvest.hunters_captured==1,"Saved feeding defense progress survives resume")
			restored_visit.dispose()
			settle(run)
	expect(run.state==Run.EVOLVE,"Two captured hunters finish the defended feeding visit")
	run.dispose()
	var thirty: Array = Route.make(79)
	for i in 15:
		thirty.insert(4,thirty[3].duplicate(true))
	var final_position := -1
	for i in thirty.size():
		if thirty[i].generated and int(thirty[i].stage)>=8:
			final_position = i
			break
	var recipe: Dictionary = thirty[final_position]
	recipe.mode = "defend"
	recipe.food = 1
	recipe.target = 1
	thirty[final_position] = recipe
	expect(Route.valid(thirty),"The late defended visit remains a valid saved route")
	var final_run := Run.new(true,79,true,true)
	final_run.route_plan = thirty
	final_run.route_position = final_position
	final_run.long_journey = true
	final_run.expedition_roster = Expedition.plan(final_run.run_seed,thirty,[])
	final_run.stage_index = int(recipe.stage)
	final_run.start_stage()
	expect(final_run.harvest.final_surge_enabled,"A generated Blue Deep defense on the original journey promises a final surge")
	final_run.Habitats.choose(final_run,"refuge")
	final_run.begin_encounter()
	final_run.harvest.nourishment = 1
	final_run.harvest.defended = 1
	if not final_run.harvest.event_state.is_empty():
		final_run.harvest.event_state.warned = true
	final_run.stage_elapsed = float(final_run.harvest.spec.duration) - 1.0
	final_run.harvest.check_completion(final_run)
	var final_events: Array = final_run.harvest.ecology.pending.filter(func(event): return event.get("final_surge",false))
	expect(final_run.state==Run.ACTIVE and not final_run.harvest.final_surge_rapid and final_events.size()==2 and final_events[0].at-final_run.stage_elapsed>=8.0,"A later sheltered clear warns of two final hunters instead of ending the round")
	final_run.stage_elapsed = float(final_run.harvest.spec.duration)
	final_run.step(0.25)
	expect(final_run.state==Run.ACTIVE and final_run.stage_elapsed>float(final_run.harvest.spec.duration) and final_run.harvest.final_surge_start_time>0.0,"A final hunter warned near the encounter limit gets simulation time to arrive and be captured")
	final_run.stage_elapsed = 0.0
	var final_event: Dictionary = final_events[0]
	final_run.harvest.ecology.pending.erase(final_event)
	final_run.harvest.ecology.spawn_event(final_run,final_event)
	var final_id: int = final_run.harvest.final_surge_ids[0]
	var final_body: RefCounted = final_run.enemies.filter(func(body): return body.id==final_id)[0]
	final_body.nucleus = (final_run.board.anchors[0]+final_run.board.anchors[8]+final_run.board.anchors[9])/3.0
	final_body.speed = 0.0
	final_run.enemies = [final_body]
	final_run.harvest.next_bloom = 9999.0
	final_run.harvest.ecology.next_wave = 9999.0
	var first_hit: Dictionary = capture_body(final_run,final_body)
	expect(first_hit.valid and final_body.health==1 and final_run.harvest.final_surge_captured==0 and final_run.state==Run.ACTIVE,"The armored final hunter needs a second actual capture")
	var final_snapshot: Dictionary = Save.capture(final_run)
	var escaped_final := Run.new(true,81,true,true)
	expect(Save.restore(escaped_final,final_snapshot),"The late defense can be restored after the first armored hit")
	escaped_final.enemies = escaped_final.enemies.filter(func(body): return body.id!=final_id)
	escaped_final.harvest.step(escaped_final)
	expect(escaped_final.harvest.ecology.pending.any(func(event): return event.get("final_surge",false)),"A final hunter that reaches Mother is replaced after a visible warning")
	escaped_final.dispose()
	var final_resume := Run.new(true,80,true,true)
	expect(Save.restore(final_resume,final_snapshot) and final_resume.harvest.final_surge_ids.has(final_id) and final_resume.harvest.final_surge_start_time==final_run.harvest.final_surge_start_time and not final_resume.harvest.final_surge_rapid,"The marked final hunter, wave pressure, grace period, and its damaged armor survive resume")
	final_resume.harvest.next_bloom = 9999.0
	final_resume.harvest.ecology.next_wave = 9999.0
	settle(final_resume)
	var resumed_hunter: RefCounted = final_resume.enemies.filter(func(body): return body.id==final_id)[0]
	var final_hit: Dictionary = capture_body(final_resume,resumed_hunter)
	expect(final_hit.valid and final_resume.harvest.final_surge_captured==1 and final_resume.state==Run.ACTIVE,"Capturing the first final hunter leaves the second still to repel")
	final_resume.harvest.final_surge_captured = 2
	final_resume.harvest.check_completion(final_resume)
	expect(final_resume.state==Run.EVOLVE,"Repelling both final hunters completes the defended visit")
	final_resume.dispose()
	final_run.dispose()
	var rich_run := Run.new(true,82,true,true)
	rich_run.route_plan = thirty.duplicate(true)
	rich_run.route_position = final_position
	rich_run.long_journey = true
	rich_run.expedition_roster = Expedition.plan(rich_run.run_seed,rich_run.route_plan,[])
	rich_run.stage_index = int(recipe.stage)
	rich_run.start_stage()
	rich_run.Habitats.choose(rich_run,"bloom")
	rich_run.begin_encounter()
	rich_run.harvest.nourishment = 1
	rich_run.harvest.defended = 1
	rich_run.harvest.check_completion(rich_run)
	var rich_final: Array = rich_run.harvest.ecology.pending.filter(func(event): return event.get("final_surge",false))
	expect(rich_run.harvest.final_surge_rapid and rich_final.size()==4 and rich_final[2].species=="shellback" and is_equal_approx(rich_final[1].at-rich_final[0].at,2.0),"A swift food-rich clear draws four closely staggered hunters including two armored Shellbacks")
	var rapid_resume := Run.new(true,84,true,true)
	expect(Save.restore(rapid_resume,Save.capture(rich_run)) and rapid_resume.harvest.final_surge_rapid and rapid_resume.harvest.ecology.pending.filter(func(event): return event.get("rapid_surge",false)).size()==4,"The swift hunter wave survives save and resume")
	rapid_resume.dispose()
	rich_run.stage_elapsed = 14.5
	rich_run.harvest.ecology.step(rich_run,14.5)
	expect(rich_run.harvest.final_surge_ids.size()==4 and rich_run.enemies.filter(func(body): return body.kind=="shellback").size()>=2,"All four warned hunters enter the swift food-rich encounter")
	rich_run.dispose()
	var rescue_position := -1
	for i in thirty.size():
		if i%2==0 and int(thirty[i].stage)>=8 and thirty[i].mode=="rescue":
			rescue_position = i
			break
	expect(rescue_position>=0,"The original route includes a late alternate rescue visit")
	if rescue_position>=0:
		var rescue_run := Run.new(true,83,true,true)
		rescue_run.route_plan = thirty.duplicate(true)
		rescue_run.route_position = rescue_position
		rescue_run.long_journey = true
		rescue_run.expedition_roster = Expedition.plan(rescue_run.run_seed,rescue_run.route_plan,[])
		rescue_run.stage_index = int(thirty[rescue_position].stage)
		rescue_run.start_stage()
		rescue_run.Habitats.choose(rescue_run,"refuge")
		rescue_run.begin_encounter()
		rescue_run.harvest.nourishment = int(rescue_run.harvest.spec.food)
		rescue_run.harvest.rescued = int(rescue_run.harvest.spec.target)
		rescue_run.harvest.check_completion(rescue_run)
		var rescue_final: Array = rescue_run.harvest.ecology.pending.filter(func(event): return event.get("final_surge",false))
		expect(rescue_run.harvest.final_surge_enabled and rescue_run.state==Run.ACTIVE and rescue_final.size()==2 and rescue_final[0].species=="twinspore","An authored late rescue also ends with a linked-hunter wave after its goals")
		rescue_run.dispose()
	print("JOURNEY ECOLOGY: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
