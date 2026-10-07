extends "res://tests/journey_rules.gd"

func quiet(run: RefCounted, stage: int = 1) -> void:
	fixture_stage(run,stage)
	run.harvest.next_bloom = 9999.0
	run.harvest.ecology.next_wave = 9999.0
	run.harvest.spec.food = 999

func exercise() -> void:
	var run := Run.new(true,73,true,true)
	quiet(run)
	meal(run,["spore","drifter"])
	select(run)
	var result: Dictionary = run.release()
	expect(result.rescued==1 and result.threats==1 and result.mastery==["guardian"],"An actual rescue and nearby hunter capture earns Guardian")
	expect(run.biomass==1 and run.harvest.nourishment==0,"Mastery gives one stored upgrade food without changing the encounter's food objective")
	expect(run.clots[0].mastery==["guardian"],"The actual digestion carries its visual flourish")
	var clone := Run.new(true,4,true,true)
	expect(Save.restore(clone,Save.capture(run)) and clone.mastery_awards==run.mastery_awards and clone.clots[0].mastery==["guardian"],"Resume preserves earned feats and an in-flight flourish")
	clone.dispose()
	settle(run)
	meal(run,["spore","drifter"])
	select(run)
	result = run.release()
	expect(result.mastery.is_empty() and run.biomass==1,"The same feat cannot be farmed repeatedly in an encounter")
	quiet(run,2)
	meal(run,["spore","shellback"])
	select(run)
	result = run.release()
	expect(result.mastery.is_empty() and result.armor_hits==1,"Cracking armor without removing the hunter is not a completed rescue feat")
	quiet(run,4)
	meal(run,["food","food","food","food"])
	for i in 4:
		run.enemies[i].bloom_id = 1 if i<2 else 2
	var saved := Save.capture(run)
	clone = Run.new(true,4,true,true)
	expect(Save.restore(clone,saved) and clone.enemies[3].bloom_id==2,"Original bloom identity survives a save")
	clone.dispose()
	select(run)
	result = run.release()
	expect(result.mastery==["gatherer"] and result.food==4 and run.harvest.nourishment==4,"One polygon gathers two distinct blooms while preserving normal food accounting")
	quiet(run,5)
	meal(run,["food","food","food","food"])
	for body in run.enemies:
		body.bloom_id = 3
	select(run)
	result = run.release()
	expect(result.mastery.is_empty(),"Four food from a single bloom does not masquerade as a two-bloom capture")
	quiet(run,6)
	meal(run,["spore","drifter","cyst"])
	select(run)
	result = run.release()
	expect(result.poison==1 and result.mastery.is_empty(),"A poisoned rescue gives no precision reward")
	quiet(run,8)
	run.harvest.spec.food = 9
	run.harvest.nourishment = 9
	run.harvest.defended = run.harvest.spec.target
	run.check_completion()
	expect(run.state==Run.EVOLVE and run.mastery_awards[-1].id=="clear_water","A completed poison-free encounter earns its optional clean-water reward")
	var count: int = run.mastery_awards.size()
	run.Mastery.complete(run)
	expect(run.mastery_awards.size()==count,"Encounter completion reward is idempotent")
	quiet(run,9)
	run.harvest.poison_taken = 1
	run.Mastery.complete(run)
	expect(run.mastery_awards.size()==count,"Taking poison excludes the clean-encounter feat")
	run.restart()
	expect(run.mastery_awards.is_empty(),"New journeys begin a fresh set of optional feats")
	run.dispose()
	print("JOURNEY MASTERY: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
