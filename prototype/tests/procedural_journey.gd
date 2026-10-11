extends "res://tests/harvest_visual.gd"
const Route = preload("res://scripts/journey_route.gd")
const Save = preload("res://scripts/journey_save.gd")

func enter(run: RefCounted, position: int) -> void:
	run.route_position = position
	run.stage_index = run.route_plan[position].stage
	run.start_stage()

func exercise() -> void:
	var signatures := {}
	for seed_value in range(73,85):
		var route := Route.make(seed_value)
		expect(Route.valid(route) and route.size()==15,"Fifteen valid encounters for seed %d" % seed_value)
		expect(route==Route.make(seed_value),"Seed reproduces the entire route")
		var signature := ""
		var counts := [0,0,0]
		var generated := 0
		for spec in route:
			counts[int(spec.stage)/4] += 1
			if spec.generated:
				generated += 1
				signature += "%s:%s:%s:%s;" % [spec.mode,str(spec.families),spec.hunter,spec.event]
				expect(spec.mode!="purify" or spec.stage>=4,"Poison-only missions follow their lesson")
				expect(spec.mode!="sectors" or spec.stage>=5,"Sector missions follow their lesson")
				expect(not spec.families.has("divider") or spec.stage>=6,"Splitting predators follow their introduction")
		expect(counts==[5,5,5] and generated==3,"Each biome has four authored encounters and one distinctive visit")
		signatures[signature] = true
	expect(signatures.size()==12,"All sampled seeds differ in gameplay compositions, not only colors")
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-procedural-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-procedural-profile-unused.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	game.run.fixed_seed = 73
	game.new_journey("wanderer")
	var run = game.run
	expect(run.route_plan.size()==15 and run.Lesson.active(run),"New journey starts the focused route with the real safe lesson")
	enter(run,2)
	await refresh()
	await capture("mother-growth-choice")
	expect(game.hud.growth_buttons[0].visible and game.hud.growth_buttons[1].visible,"The new organelle offers both roles before the encounter")
	game.choose_growth_role("feeder")
	expect(run.growth_roles.get(1)=="feeder" and not game.hud.growth_buttons[0].visible,"Choosing a role returns to the journey briefing")
	run.begin_encounter()
	var wide_path := [0,8,9]
	var meal_center := Vector2.ZERO
	for id in wide_path:
		meal_center += run.board.anchors[id]/3.0
	run.enemies.clear()
	for i in 5:
		run.enemies.append(run.Harvest.Organism.new(10000+i,"food",meal_center,Vector2.ZERO,0.0))
	run.selection.start(run.board.anchors[0])
	for id in [8,9,0]: run.selection.visit(id)
	await capture("long-link-preview")
	game.commit_selection()
	game._process(0.25)
	await capture("grand-sweep-feedback")
	expect(game.big_capture_remaining>0.0 and run.last_capture.capture_grade=="Grand sweep","A five-body capture produces graded in-dish feedback")
	enter(run,3)
	expect(run.harvest.spec.generated and run.stage_index==2 and run.harvest.spec.phage_lesson,"The first special visit teaches phage play after its authored introduction")
	run.begin_encounter()
	run.step(20.0)
	var snapshot := Save.capture(run)
	var config := ConfigFile.new()
	config.set_value("test","snapshot",snapshot)
	expect(config.save("/tmp/microverse-procedural-roundtrip.cfg")==OK,"Save full procedural route to disk")
	var loaded := ConfigFile.new()
	loaded.load("/tmp/microverse-procedural-roundtrip.cfg")
	var restored := Run.new(true,99,true,true)
	expect(Save.restore(restored,loaded.get_value("test","snapshot")),"Restore actual serialized generated mission")
	expect(restored.route_plan==run.route_plan and restored.route_position==3 and restored.harvest.spec==run.harvest.spec,"Resume preserves route, position, goals and creature recipe")
	expect(restored.harvest.ecology.pending==run.harvest.ecology.pending and restored.harvest.event_state==run.harvest.event_state,"Resume keeps arrivals and world event state")
	run.state = Run.LOSS
	expect(run.retry_encounter() and run.route_position==3 and run.harvest.spec==restored.harvest.spec,"Retry keeps the same generated mission")
	run.state = Run.ACTIVE
	run.finish_journey_stage()
	expect(run.offered_mutations.is_empty(),"Generated encounters offer rest rather than exhausting every evolution")
	await capture("procedural-journey-rest")
	expect(run.choose_journey_evolution("continue") and run.route_position==4 and run.stage_index==3,"Travel reaches the first boss")
	var first_appearance: int = run.appearance_seed()
	enter(run,7)
	expect(run.stage_index==5 and run.appearance_seed()!=first_appearance,"Special visits across biomes receive distinct visual recipes")
	run.Habitats.choose(run,"refuge")
	expect(run.harvest.spec.generated and run.harvest.event_state.kind==run.harvest.spec.event,"Generated ecology event is actually installed")
	game.large_text = true
	await capture("procedural-journey-brief")
	run.begin_encounter()
	run.harvest.ecology.pending.clear()
	run.harvest.ecology.queue_wave(run)
	expect(run.harvest.ecology.pending.any(func(e): return e.kind==run.harvest.spec.families[0]),"Seeded creature family drives real wave content")
	expect(run.habitat_history.has(run.encounter_key()),"Each generated encounter retains its own habitat choice")
	await capture("procedural-journey-field")
	var rescue_path := [0,8,9]
	var site := Vector2.ZERO
	for id in rescue_path:
		site += run.board.anchors[id]/3.0
	run.enemies = [run.Harvest.Organism.new(9000,"spore",site,Vector2.ZERO,0.0)]
	run.selection.start(run.board.anchors[0])
	for id in [8,9,0]: run.selection.visit(id)
	var rescue: Dictionary = run.release()
	expect(rescue.get("rescued",0)==1 and run.rescued_specimens[-1].encounter==8,"Rescued life remembers the actual generated encounter number")
	var profile = preload("res://scripts/journey_profile.gd").new()
	profile.path = "/tmp/microverse-procedural-growth.cfg"
	run.mastery_awards.clear()
	run.finish_journey_stage()
	profile.observe(run)
	enter(run,8)
	run.begin_encounter()
	run.finish_journey_stage()
	profile.observe(run)
	expect(profile.cleared_encounters.size()==2 and profile.pond_memories.size()==2,"Separate missions in one chapter each grow the home pond and earn a feat")
	profile.observe(run)
	expect(profile.cleared_encounters.size()==2 and profile.pond_memories.size()==2,"Resaving the same generated encounter cannot duplicate growth or awards")
	for trait_id in ["fission","grazer","lure","frenzy","nursery","symbiosis"]:
		run.add_mutation(trait_id)
	enter(run,4)
	run.state = Run.ACTIVE
	run.finish_journey_stage()
	expect(run.completed_dishes==1 and run.offered_mutations.is_empty(),"First boss closes biome and a six-evolution colony stays distinct")
	expect(run.choose_journey_evolution("continue") and run.route_position==5 and run.stage_index==4,"First biome leads to the second biome")
	enter(run,14)
	run.finish_journey_stage()
	expect(run.state==Run.SUCCESS and run.completed_dishes==3 and run.encounter_index()==14,"Only the fifteenth encounter ends the new journey")
	var old_thirty: Array = run.route_plan.duplicate(true)
	for i in 15:
		old_thirty.insert(4,old_thirty[3].duplicate(true))
	expect(Route.valid(old_thirty),"Saved thirty-encounter routes remain valid")
	var old_save: Dictionary = snapshot.duplicate(true)
	old_save.route.plan = old_thirty
	old_save.expedition_roster = []
	old_save.run.erase("growth_roles")
	expect(Save.restore(restored,old_save) and restored.encounter_total()==30 and restored.growth_roles.get(1)=="guard","An in-progress thirty-encounter save resumes with a safe growth default")
	var legacy := snapshot.duplicate(true)
	legacy.erase("route")
	expect(Save.restore(restored,legacy) and restored.route_plan.is_empty() and restored.encounter_total()==12,"Old saves finish their original twelve-encounter journey")
	var broken := snapshot.duplicate(true)
	broken.route.position = 99
	expect(not Save.restore(restored,broken),"Invalid route position rejected before changing live state")
	restored.dispose()
	game.queue_free()
	await process_frame
	print("PROCEDURAL JOURNEY: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
