extends "res://tests/journey_rules.gd"

func quiet(run: RefCounted) -> void:
	fixture_stage(run,4)
	run.enemies.clear()
	run.phages.reset()
	run.harvest.next_bloom = 9999
	run.harvest.ecology.next_wave = 9999
	run.harvest.ecology.pending.clear()
	run.harvest.spec.food = 999

func exercise() -> void:
	var run = Run.new(true,73,true,true)
	quiet(run)
	var at := Vector2(825,500)
	var body = run.harvest.ecology.add(run,"bacterium",0,at)
	body.age = 4.0
	body.spawning = 0.0
	body.stored_food = 2
	var group = run.phages.add(run,at+Vector2(0,-65))
	group.age = 4.0
	expect(run.nudge.pick(run,group.nucleus)==group,"Phages use the existing nudge gesture")
	expect(not run.target_snapshot().any(func(e): return e.id==group.id),"Friendly phages are never loop food or threats")
	expect(run.nudge.begin(run,group.nucleus),"Begin a deliberate phage nudge")
	var result: Dictionary = run.nudge.release(run,group.nucleus+Vector2(0,60))
	expect(not result.is_empty() and run.nudge.cooldown==6.0,"Phages share the six-second water-push cooldown")
	for i in 120: run.step(1.0/60.0)
	expect(group.host_id==body.id and body.infection_age>0.0,"A pushed cluster reaches and infects a nearby bacterium")
	expect(not run.nudge.eligible(group),"Attached phages cannot be nudged off a host")
	var clone = Run.new(true,9,true,true)
	expect(Save.restore(clone,Save.capture(run)),"Save restores an infection in progress")
	var twin = clone.phages.host(clone,body.id)
	expect(twin.infection_age==body.infection_age and clone.phages.clusters[0].host_id==body.id,"Saved attachment and infection deadline are exact")
	clone.state = Run.PAUSED
	clone.step(5.0)
	expect(twin.infection_age==body.infection_age,"Pause freezes infection")
	var left: float = body.infection_remaining()
	for i in ceili((left-0.1)*60.0): run.step(1.0/60.0)
	expect(run.enemies.has(body),"Infection leaves time to capture the host directly")
	for i in 15: run.step(1.0/60.0)
	expect(not run.enemies.has(body) and run.phages.clusters.is_empty(),"Nine-second infection ruptures one host and consumes its cluster")
	expect(run.enemies.filter(func(e): return e.kind=="food" and e.story=="phage_salvage").size()==2,"Exactly the stolen food returns as collectable organisms")
	expect(run.harvest.nourishment==0 and run.biomass==0,"Released food is not silently added to stores")
	expect(run.harvest.defended==1 and run.kills==1,"A phage kill advances defense once")
	expect(run.integrity==5 and run.cells.all(func(c): return c.captor<0 and not c.lost),"Mother and all colony cells remain unharmed")
	expect(not run.phages.bursts.is_empty() and Array(run.fluid.sources).any(func(s): return s.z>0.1 and absf(s.x-body.nucleus.x)<0.01),"Rupture stirs the shared water")
	clone.dispose()
	quiet(run)
	for kind in ["food","cyst","spore","amoeba","grazer","parasite","divider"]:
		var other: RefCounted
		if kind in ["food","cyst","spore"]:
			other = run.Harvest.Organism.new(900+run.enemies.size(),kind,at,Vector2.ZERO,0.0)
			run.enemies.append(other)
		else: other = run.harvest.ecology.add(run,kind,0,at)
		other.age = 5
	group = run.phages.add(run,at)
	group.age = 4
	run.phages.step(run,0.1)
	expect(group.host_id<0,"Phages ignore every non-bacterial species, including amoebas")
	quiet(run)
	body = run.harvest.ecology.add(run,"bacterium",0,run.harvest.ecology.pocket(run,0))
	body.age = 4
	body.spawning = 0
	body.stored_food = 3
	group = run.phages.add(run,body.nucleus)
	group.age = 4
	run.phages.step(run,0.01)
	select(run)
	var capture: Dictionary = run.release()
	expect(capture.valid and capture.food==3 and not run.enemies.has(body),"A player can capture an infected bacterium and recover its food immediately")
	run.phages.step(run,0.01)
	expect(run.phages.clusters.is_empty() and run.phages.bursts.is_empty(),"Direct capture cancels infection without a duplicate rupture")
	var route: Array = run.JourneyRoute.make(73)
	var lessons: Array = route.filter(func(e): return e.get("phage_lesson",false))
	expect(lessons.size()==1 and lessons[0].families==["bacterium"] and route.find(lessons[0])==4,"A new journey teaches phages in encounter five, Small allies")
	run.route_plan = route
	run.route_position = 4
	run.stage_index = 2
	run.start_stage()
	expect(run.enemies.any(func(e): return e.kind=="bacterium") and run.phages.clusters.size()==1,"The teaching encounter guarantees a host and a helper")
	var data: Dictionary = Save.capture(run)
	data.erase("phages")
	clone = Run.new(true,9,true,true)
	expect(Save.restore(clone,data) and clone.phages.clusters.is_empty(),"Legacy saves do not inject an unexpected phage cluster")
	clone.dispose()
	run.dispose()
	print("PHAGES: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
