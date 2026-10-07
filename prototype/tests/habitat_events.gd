extends "res://tests/journey_rules.gd"

func quiet(run: RefCounted, stage: int, time: float) -> void:
	fixture_stage(run,stage)
	run.harvest.ecology.next_wave = 9999.0
	run.harvest.ecology.pending.clear()
	run.harvest.next_bloom = 9999.0
	run.harvest.visitor_at = -1.0
	run.enemies.clear()
	run.stage_elapsed = time
	run.harvest.last_time = time

func exercise() -> void:
	var run := Run.new(true,73,true,true)
	quiet(run,2,38.0)
	var events = run.harvest.HabitatEvents
	events.step(run,0.0)
	expect(events.sample(run).warning and run.enemies.is_empty(),"The migration gives eight seconds of warning before any new food appears")
	run.stage_elapsed = 46.0
	run.harvest.last_time = 46.0
	events.step(run,0.0)
	expect(run.enemies.size()==6 and run.harvest.event_state.food.size()==6,"A real six-organism bloom arrives in three capture pockets")
	expect(run.harvest.ecology.pending.any(func(e): return e.kind=="grazer" and e.at==54.0),"A grazer follows the bloom with its own eight-second warning")
	var first = run.enemies[0]
	var original: Vector2 = first.nucleus
	for i in 120:
		run.step(1.0/60.0)
	expect(first.nucleus.distance_to(original)>3.0,"The event's actual food moves with the current")
	var clone := Run.new(true,99,true,true)
	expect(Save.restore(clone,Save.capture(run)),"The ecological event restores through the regular journey save")
	events.step(clone,0.0)
	expect(clone.enemies.size()==run.enemies.size() and clone.harvest.event_state==run.harvest.event_state,"Restoration cannot duplicate the migrating bloom or its scheduled follower")
	quiet(run,5,46.0)
	events.step(run,0.0)
	expect(run.enemies.size()==6 and run.enemies.all(func(e): return e.kind=="food"),"The sleeping garden begins as a genuine clean feeding opportunity")
	run.stage_elapsed = 60.0
	run.harvest.last_time = 60.0
	events.step(run,0.0)
	expect(events.sample(run).detail.contains("8s") and run.harvest.event_state.sites.size()==3,"The waking garden advertises exact hatch sites and the remaining eight seconds")
	expect(Save.restore(clone,Save.capture(run)),"The hatch warning survives save and resume")
	clone.stage_elapsed = 68.0
	clone.harvest.last_time = 68.0
	events.step(clone,0.0)
	var cysts: Array = clone.enemies.filter(func(e): return e.kind=="cyst")
	expect(cysts.size()==3 and cysts.all(func(c): return c.age==0.0 and clone.harvest.event_state.sites.has(c.nucleus)),"Three toxic cysts are born organically at precisely the forecast sites")
	events.step(clone,0.0)
	expect(clone.enemies.filter(func(e): return e.kind=="cyst").size()==3,"An already hatched garden never spawns a second set")
	quiet(run,9,62.0)
	events.step(run,0.0)
	var at: Vector2 = events.traveller_position(run)
	var food = run.Harvest.Organism.new(990,"food",at,Vector2.ZERO,0.0)
	var cyst = run.Harvest.Organism.new(991,"cyst",at,Vector2.ZERO,0.0)
	run.enemies.append_array([food,cyst])
	for i in 90:
		run.step(1.0/60.0)
	expect(cyst.nucleus.y-food.nucleus.y>7.0,"The giant's wake actually opens a gap between food and poison")
	expect(run.enemies.size()==2 and run.integrity==5,"The distant traveller is harmless and is not an uncatchable gameplay enemy")
	run.toggle_pause()
	var position: Vector2 = food.nucleus
	var sample: Dictionary = events.sample(run)
	run.step(30.0)
	expect(food.nucleus==position and events.sample(run)==sample,"Pause freezes the event, its current, and its forecast")
	var legacy: Dictionary = Save.capture(run)
	legacy.harvest.erase("event_state")
	expect(Save.restore(clone,legacy) and clone.harvest.event_state.is_empty(),"Older saves never acquire an unannounced event in progress")
	run.dispose()
	clone.dispose()
	print("HABITAT EVENTS: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
