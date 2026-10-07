extends "res://tests/journey_rules.gd"
const Appearance = preload("res://scripts/mission_appearance.gd")

func count_kind(run: RefCounted, kind: String) -> int:
	return run.enemies.filter(func(e): return e.kind==kind).size()

func exercise() -> void:
	var run := Run.new(true,73,true,true)
	expect(not run.Habitats.pending(run) and not run.Habitats.choose(run,"refuge"),"The opening lesson has no destination decision")
	run.stage_index = 4
	run.start_stage()
	var food: int = count_kind(run,"food")
	var poisons: int = count_kind(run,"cyst")
	var rng_state: int = run.rng.state
	expect(run.Habitats.pending(run) and run.state==Run.BRIEF,"A later encounter offers destinations before simulation")
	expect(not run.Habitats.choose(run,"unknown"),"Unknown destination identifiers cannot mutate the journey")
	expect(run.Habitats.choose(run,"refuge"),"The sheltered destination can be selected")
	run.step(20.0)
	expect(run.stage_elapsed==0.0 and count_kind(run,"food")==food and run.rng.state==rng_state,"Reading and choosing never move the dish, consume food, or reroll randomness")
	var chosen := Save.capture(run)
	var restored := Run.new(true,99,true,true)
	expect(Save.restore(restored,chosen) and restored.habitat_choice=="refuge" and not restored.Habitats.pending(restored),"A chosen destination survives save before encounter entry")
	restored.begin_encounter()
	expect(count_kind(restored,"food")==food-2 and count_kind(restored,"cyst")==poisons,"Shelter has four food in each of two initial blooms, preserving poison objectives")
	expect(restored.harvest.visitor_at==36.0 and restored.habitat_history.get("4")=="refuge","Shelter schedules its promised visitor and records the travelled route")
	var before: int = count_kind(restored,"food")
	restored.harvest.spawn_bloom(restored,3)
	expect(count_kind(restored,"food")==before+4,"Later sheltered blooms keep their advertised food density")
	for wave in 4:
		restored.harvest.ecology.queue_wave(restored)
	var hunters: int = restored.harvest.ecology.pending.filter(func(e): return e.kind=="hunter").size()
	expect(hunters==2 and restored.harvest.ecology.pending.filter(func(e): return e.kind=="bloom").size()==4,"Shelter halves scheduled hunter arrivals while retaining every feeding opportunity")
	var active := Save.capture(restored)
	expect(Save.restore(run,active) and count_kind(run,"food")==before+4,"Restoring an active shelter never removes another food from its blooms")
	run.state = Run.PAUSED
	run.step(40.0)
	expect(not run.harvest.visitor_spawned and run.stage_elapsed==0.0,"Pause does not bring the promised visitor early")
	run.state = Run.ACTIVE
	run.stage_elapsed = 36.0
	run.harvest.Discoveries.step(run)
	expect(run.enemies.any(func(e): return e.visitor and e.form=="glass_harp"),"The promised Glassgarden visitor actually enters the dish")
	run.state = Run.LOSS
	run.checkpoint = chosen
	expect(run.retry_encounter() and run.habitat_choice=="refuge","Retry retains the chosen habitat")
	run.begin_encounter()
	expect(count_kind(run,"food")==food-2,"Retry reapplies the shelter exactly once from its original checkpoint")
	var legacy := chosen.duplicate(true)
	for field in Save.HABITAT_FIELDS:
		legacy.run.erase(field)
	expect(Save.restore(restored,legacy) and not restored.Habitats.pending(restored),"Older saves resume their original encounter without a new forced decision")
	restored.begin_encounter()
	expect(count_kind(restored,"food")==food,"Old encounters keep their original food supply")
	var bloom: Dictionary = Appearance.make(73,4,true,"bloom")
	var refuge: Dictionary = Appearance.make(73,4,true,"refuge")
	expect(bloom.water_grade!=refuge.water_grade and bloom.key!=refuge.key and bloom.cells==refuge.cells,"Shelter changes the water appearance without changing cell geometry")
	for stage in [0,1,3,7,11]:
		run.stage_index = stage
		run.start_stage()
		expect(not run.Habitats.pending(run),"Teaching and boss encounter %d stays on its authored route" % stage)
	run.dispose()
	restored.dispose()
	print("JOURNEY HABITATS: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
