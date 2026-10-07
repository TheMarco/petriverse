extends "res://tests/journey_rules.gd"
const Guide = preload("res://scripts/journey_guidance.gd")

func open_cradle(run: RefCounted) -> RefCounted:
	fixture_stage(run,6)
	run.harvest.next_bloom = 9999.0
	run.harvest.ecology.next_wave = 9999.0
	run.harvest.ecology.pending.clear()
	run.harvest.visitor_at = -1.0
	var pearl = run.enemies.filter(func(e): return e.cradle)[0]
	run.enemies = run.enemies.filter(func(e): return e==pearl or pearl.gate_ids.has(e.id))
	var at: Vector2 = (run.board.anchors[0]+run.board.anchors[8]+run.board.anchors[9])/3.0
	pearl.origin = at
	pearl.nucleus = at
	pearl.drift = Vector2.ZERO
	for shield in run.enemies:
		if shield.kind=="warden":
			shield.nucleus = at
	select(run)
	var result: Dictionary = run.release()
	expect(result.wardens==2 and pearl.can_take_pulse(),"A real polygon breaks the shields and frees the living cradle")
	return pearl

func advance(run: RefCounted, seconds: float) -> void:
	for i in ceili(seconds*60):
		run.step(1.0/60.0)

func exercise() -> void:
	var run := Run.new(true,73,true,true)
	var pearl = open_cradle(run)
	expect(pearl.hatch_remaining()==12.0 and Guide.next_action(run).title=="Rescue now, or let it hatch","The safe rescue and delayed two-young choice are explicit")
	var snapshot := Save.capture(run)
	var restored := Run.new(true,4,true,true)
	expect(Save.restore(restored,snapshot),"An open cradle saves through the normal journey snapshot")
	advance(run,8.0)
	advance(restored,8.0)
	expect(is_equal_approx(pearl.hatch_remaining(),4.0) and run.enemies.size()==restored.enemies.size(),"Save/resume preserves the exact hatching deadline")
	run.state = Run.PAUSED
	run.step(20.0)
	expect(is_equal_approx(pearl.hatch_remaining(),4.0),"Pausing freezes the decision window")
	run.state = Run.ACTIVE
	advance(run,4.1)
	advance(restored,4.1)
	var young: Array = run.enemies.filter(func(e): return e.story=="hatchling")
	expect(young.size()==2 and not run.enemies.has(pearl) and young.all(func(e): return e.kind=="spore" and not e.cradle),"Waiting produces two real rescuable young and consumes the cradle once")
	expect(run.harvest.rescued==0 and run.rescued_specimens.is_empty(),"Watching a hatch earns no automatic rescue credit")
	expect(young.map(func(e): return e.id)==restored.enemies.filter(func(e): return e.story=="hatchling").map(func(e): return e.id),"Both sides of a resume hatch the same identities without duplication")
	var before: int = run.enemies.size()
	run.harvest.ecology.step_cradles(run)
	expect(run.enemies.size()==before and young.all(func(e): return e.lifetime()==40.0),"Hatching is idempotent and leaves a generous forty-second rescue window")
	var at: Vector2 = (run.board.anchors[0]+run.board.anchors[8]+run.board.anchors[9])/3.0
	for child in young:
		child.origin = at
		child.nucleus = at
	select(run)
	var captured: Dictionary = run.release()
	var profile := Profile.new()
	profile.path = "/tmp/microverse-cradle-story-profile.cfg"
	profile.observe(run)
	expect(captured.rescued==2 and profile.residents.size()==2 and profile.residents.all(func(r): return r.story=="hatchling"),"A real capture brings both young home with their hatching history")
	var loaded := Profile.new()
	loaded.path = profile.path
	loaded.load_profile()
	expect(loaded.residents==profile.residents,"Their story survives a profile reload")
	pearl = open_cradle(run)
	settle(run)
	pearl.origin = (run.board.anchors[0]+run.board.anchors[8]+run.board.anchors[9])/3.0
	pearl.nucleus = pearl.origin
	select(run)
	captured = run.release()
	expect(captured.rescued==1 and run.rescued_specimens[-1].story=="cradle","Rescuing early remains a valid one-life outcome with its own history")
	advance(run,13.0)
	expect(not run.enemies.any(func(e): return e.story=="hatchling"),"An already rescued pearl cannot hatch phantom organisms in the dish")
	pearl = open_cradle(run)
	pearl.age = 3.0 # The food web ignores bodies during their first two seconds of birth.
	var hunter = run.Drifter.new(8888,pearl.nucleus,0.0)
	hunter.age = 3.0
	run.enemies.append(hunter)
	for i in 7:
		run.harvest.ecology.step_food_web(run,1.0)
	expect(not run.enemies.has(pearl) and run.harvest.ecology.escaped_spores==1,"Leaving an exposed cradle unprotected has a real predation risk")
	pearl = open_cradle(run)
	var legacy := Save.capture(run)
	for body in legacy.enemies:
		body.erase("cradle_open_age")
		body.erase("story")
	Save.restore(restored,legacy)
	advance(restored,14.0)
	expect(not restored.enemies.any(func(e): return e.story=="hatchling"),"Old already-open cradles do not acquire an unannounced new deadline")
	run.dispose()
	restored.dispose()
	print("CRADLE STORY: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
