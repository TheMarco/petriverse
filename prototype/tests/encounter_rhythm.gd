extends "res://tests/journey_rules.gd"
const Rhythm = preload("res://scripts/encounter_rhythm.gd")

func exercise() -> void:
	var run := Run.new(true,73,true,true)
	fixture_stage(run,1)
	run.harvest.spec.food = 999
	for beat in [[0.0,"feed"],[12.0,"warning"],[20.0,"surge"],[34.0,"rest"],[48.0,"feed"]]:
		run.stage_elapsed = beat[0]
		expect(Rhythm.sample(run).id==beat[1],"Encounter phase at %ds is %s" % beat)
	fixture_stage(run,6)
	run.harvest.spec.food = 999
	for i in 10*60+1:
		run.step(1.0/60.0)
	var eco = run.harvest.ecology
	expect(not eco.pending.is_empty() and Rhythm.sample(run).id=="warning","Real simulation queues the approaching wave during its warning phase")
	var upcoming := Rhythm.warning_sites(run)
	expect(not upcoming.is_empty() and upcoming[0].remaining>7.9,"Wave arrivals have a full eight-second advance cue")
	var state := Save.capture(run)
	var clone := Run.new(true,3,true,true)
	expect(Save.restore(clone,state),"Warning phase can be saved")
	expect(Rhythm.sample(clone)==Rhythm.sample(run) and Rhythm.warning_sites(clone)==upcoming,"Resume retains exact warning time and arrival position")
	clone.dispose()
	for kind in ["grazer","parasite","divider","hunter"]:
		run.enemies.clear()
		eco.pending = [{"kind":kind,"area":2,"at":run.stage_elapsed+4.0}]
		var point: Vector2 = Rhythm.warning_sites(run)[0].position
		eco.spawn_event(run,eco.pending[0])
		expect(run.enemies[-1].nucleus==point,"The %s emerges at the exact advertised point" % kind)
	state.ecology.erase("rhythm_origin")
	state.ecology.erase("pace")
	state.ecology.next_wave = 46.0
	state.ecology.wave = 1
	clone = Run.new(true,3,true,true)
	expect(Save.restore(clone,state),"Previous wave schedules still restore")
	clone.stage_elapsed = 46.0
	expect(Rhythm.sample(clone).id=="warning" and clone.harvest.ecology.next_wave==46.0,"Legacy saves align new phases without moving scheduled arrivals")
	expect(clone.harvest.ecology.pace.cycle==48.0 and clone.harvest.ecology.pace.extra_every==0,"Existing encounters retain their gentler pace until the next encounter")
	fixture_stage(clone,8)
	expect(clone.harvest.ecology.pace.cycle<48.0,"The next encounter adopts the new difficulty curve")
	clone.dispose()
	fixture_stage(run,2)
	run.harvest.spec.food = 999
	for i in 49*60:
		run.step(1.0/60.0)
		run.enemies = run.enemies.filter(func(e): return e.kind in ["food","cyst","spore"])
		expect_once(run,i)
	expect(run.harvest.blooms==4,"Initial food, the activity wave, and quiet replenishment all occur")
	exercise_progression(run)
	run.dispose()
	print("ENCOUNTER RHYTHM: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func expect_once(run: RefCounted, frame: int) -> void:
	if frame==35*60:
		expect(run.harvest.ecology.pending.is_empty() and run.harvest.ecology.next_wave>run.stage_elapsed+20.0,"The ordinary wave ends before a real recovery interval")

func exercise_progression(run: RefCounted) -> void:
	var previous := 48.0
	for stage in range(1,12):
		fixture_stage(run,stage)
		var pace: Dictionary = run.harvest.ecology.pace
		expect(pace.cycle<=previous and pace.arrival-pace.warning==8.0 and pace.cycle-pace.rest>=6.0,"Round %d ramps gently with full warning and recovery time" % (stage+1))
		previous = pace.cycle
		if stage<4:
			expect(pace.cycle==48.0 and pace.extra_every==0,"Opening round %d keeps its original forgiving pacing" % (stage+1))
		if stage%4==3:
			run.harvest.ecology.queue_wave(run)
			expect(run.harvest.ecology.pending.filter(func(e): return e.kind=="hunter").size()==1,"Boss round %d does not add the second-front hunter" % (stage+1))
	# Count actual scheduled waves under identical elapsed time. Remove arrivals
	# after each step to isolate the director from deaths/objective completion.
	var waves: Array = []
	for stage in [2,10]:
		fixture_stage(run,stage)
		run.harvest.spec.food = 999
		for frame in 120*60:
			run.step(1.0/60.0)
			run.enemies.clear()
		waves.append(run.harvest.ecology.wave)
	expect(waves==[3,4],"Late rounds actually deliver more waves in the same two minutes")
	fixture_stage(run,5)
	var eco = run.harvest.ecology
	eco.queue_wave(run)
	eco.queue_wave(run)
	expect(eco.pending.filter(func(e): return e.kind=="hunter").size()==3,"Middle rounds alternate a single approach with a two-front approach")
	fixture_stage(run,10)
	eco = run.harvest.ecology
	run.stage_elapsed = eco.next_wave
	eco.step(run,0.0)
	var hunters: Array = eco.pending.filter(func(e): return e.kind=="hunter")
	expect(hunters.size()==2 and hunters[1].at-hunters[0].at>=6.0 and hunters[0].area!=hunters[1].area,"Late hunters approach different sides with time for a deliberate first response")
	run.stage_elapsed = hunters[1].at-8.0
	var cue: Array = Rhythm.warning_sites(run).filter(func(s): return s.kind=="hunter" and is_equal_approx(s.remaining,8.0))
	expect(cue.size()==1,"The second front receives its own full eight-second arrival marker")
	var state := Save.capture(run)
	var clone := Run.new(true,3,true,true)
	expect(Save.restore(clone,state) and clone.harvest.ecology.pending==eco.pending and Rhythm.sample(clone)==Rhythm.sample(run),"Save/resume preserves later pacing and staggered arrivals exactly")
	clone.state = Run.PAUSED
	clone.step(30.0)
	expect(clone.stage_elapsed==run.stage_elapsed and clone.harvest.ecology.pending==eco.pending,"Pausing does not consume either warning")
	clone.dispose()
	run.stage_elapsed = hunters[1].at
	eco.step(run,0.0)
	expect(run.enemies.any(func(e): return e.kind=="drifter" and e.nucleus==cue[0].position and e.speed==5.4),"The second hunter emerges at its advertised site without increased speed")
	for i in 6:
		eco.spawn_event(run,{"kind":"hunter","area":i})
	expect(run.enemies.filter(func(e): return e.kind in ["drifter","shellback","twinspore","divider"]).size()==4,"Extra arrivals still respect the population cap")
	fixture_stage(run,10)
	run.habitat_choice = "refuge"
	eco = run.harvest.ecology
	for wave in 4:
		eco.queue_wave(run)
	expect(eco.pending.filter(func(e): return e.kind=="hunter").size()==2,"Late sheltered routes retain single hunters on alternate waves")
