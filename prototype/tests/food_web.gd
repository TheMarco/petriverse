extends "res://tests/journey_ecology.gd"

func exercise() -> void:
	var run := Run.new(true,73,true,true)
	quiet(run,2)
	run.enemies.clear()
	var eco = run.harvest.ecology
	var at: Vector2 = eco.pocket(run,0,true)
	var food = run.Harvest.Organism.new(901,"food",at,Vector2.ZERO,0.0)
	food.age = 3.0
	var hunter = run.Drifter.new(902,at+Vector2(12,0),5.4)
	hunter.age = 3.0
	run.enemies = [food,hunter]
	tick(run,2.0)
	expect(hunter.hunt_target==food.id and hunter.hunt_time>1.8,"A real hunter changes course and begins feeding on nearby food")
	expect(eco.hunt_destination(run,hunter)==food.nucleus,"Pursuit targets the moving prey, not Mother's center")
	expect(eco.eating_progress(run,food.id)>0.3 and run.enemies.has(food),"Prey dissolves gradually and remains rescuable during the feeding window")
	var saved := Save.capture(run)
	var clone := Run.new(true,5,true,true)
	expect(Save.restore(clone,saved) and clone.enemies[1].hunt_time==hunter.hunt_time and clone.enemies[1].hunt_target==food.id,"Mid-feeding save/resume retains the exact pursuit and meal progress")
	clone.dispose()
	run.state = Run.PAUSED
	var before: float = hunter.hunt_time
	tick(run,2.0)
	expect(hunter.hunt_time==before,"Pause freezes predation")
	run.state = Run.ACTIVE
	tick(run,3.5)
	expect(run.enemies.has(food),"Feeding leaves six seconds to intervene")
	tick(run,0.7)
	expect(not run.enemies.has(food) and hunter.carried_food==1 and hunter.fed_remaining>7.0 and run.integrity==5,"The hunter eats one real food, digests slowly, and leaves Mother unharmed")
	var result := capture_body(run,hunter)
	expect(result.valid and result.salvage==1 and result.food==1,"Capturing the fed hunter recovers its swallowed food")
	quiet(run,6)
	run.enemies.clear()
	eco = run.harvest.ecology
	at = eco.pocket(run,0,true)
	var spore = run.Harvest.Organism.new(903,"spore",at,Vector2.ZERO,0.0)
	spore.age = 3.0
	hunter = run.Drifter.new(904,at+Vector2(12,0),5.4)
	hunter.age = 3.0
	run.enemies = [spore,hunter]
	tick(run,2.0)
	expect(preload("res://scripts/journey_guidance.gd").next_action(run).title=="A hunter wants the spore","An actual spore pursuit has a plain-language rescue cue")
	result = capture_body(run,spore)
	expect(result.valid and result.rescued==1 and result.threats==1 and result.mastery==["guardian"],"Intervening in the real food web captures pursuer and prey and earns the optional feat")
	quiet(run,2)
	run.enemies.clear()
	eco = run.harvest.ecology
	at = eco.pocket(run,0)
	for i in 2:
		var body = run.Harvest.Organism.new(905+i,"food",at+Vector2(i*35,0),Vector2.ZERO,0.0)
		body.bloom_id = 1
		run.enemies.append(body)
	var distance: float = run.enemies[0].nucleus.distance_to(run.enemies[1].nucleus)
	tick(run,2.0)
	expect(run.enemies[0].nucleus.distance_to(run.enemies[1].nucleus)<distance-1.0,"Food from the same bloom gently congregates")
	var survivor = run.enemies[0]
	var origin: Vector2 = survivor.nucleus
	eco.disturb_survivors(run,origin-Vector2(30,0))
	tick(run,0.7)
	expect(survivor.nucleus.x>origin.x+3.0 and survivor.nucleus.distance_to(origin)<7.0,"A capture disturbance makes nearby delicate life scatter smoothly by only a few pixels")
	run.dispose()
	print("FOOD WEB: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
