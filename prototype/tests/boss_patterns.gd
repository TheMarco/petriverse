extends "res://tests/journey_ecology.gd"
const Guide = preload("res://scripts/journey_guidance.gd")

func exercise() -> void:
	var run := Run.new(true,73,true,true)
	quiet(run,3)
	var bell = run.boss()
	run.harvest.nourishment = 6
	run.enemies = [bell]
	expect(bell.gate_ids.is_empty() and not bell.can_take_pulse(),"Bellwether begins its breathing pattern without shield targets")
	var food = run.Harvest.Organism.new(1001,"food",bell.nucleus+Vector2(100,0),Vector2.ZERO,0.0)
	run.enemies.append(food)
	var origin: Vector2 = food.origin
	select(run,[0,8,9])
	var held: Vector2 = run.board.anchors[0]
	tick(run,4.0)
	expect(food.origin.distance_to(bell.nucleus)<origin.distance_to(bell.nucleus)-2.0,"The inhale physically draws food closer")
	expect(run.board.anchors[0]==held,"The breathing current never moves a held blue cell")
	run.selection.cancel()
	expect(Guide.next_action(run).title=="Wait for the exhale","Closed Bellwether explains the actual timed opening")
	tick(run,4.1)
	expect(bell.can_take_pulse() and bell.open_remaining>15.0,"Eight-second inhale opens a sixteen-second attack window")
	run.enemies = [bell]
	select(run,[0,8,9,1])
	expect(run.harvest_preview().boss_layers==1,"The exhale permits a real charged polygon")
	var result: Dictionary = run.release()
	expect(result.boss_layers==1 and bell.health==2 and bell.reset_remaining==4.0,"A Bellwether capture removes one layer and starts recovery")
	var restored := Run.new(true,1,true,true)
	expect(Save.restore(restored,Save.capture(run)),"A saved breathing cycle restores")
	tick(run,9.0)
	tick(restored,9.0)
	expect(restored.boss().pattern_time==bell.pattern_time and restored.boss().nuclei()==bell.nuclei() and restored.boss().can_take_pulse()==bell.can_take_pulse(),"Breath, target, and vulnerability resume exactly")
	restored.dispose()
	quiet(run,2)
	var buds: Array = run.enemies.filter(func(e): return e.kind=="bell_bud")
	expect(buds.size()==1 and not buds[0].is_boss() and buds[0].health==1,"A one-hit juvenile teaches breathing in the preceding encounter")
	var bud = buds[0]
	run.enemies = [bud]
	tick(run,8.2)
	result = capture_body(run,bud)
	expect(result.valid and result.threats==1 and not run.boss_defeated,"Capturing the open juvenile advances defense without ending the journey")
	quiet(run,7)
	var regent = run.boss()
	var eco = run.harvest.ecology
	run.harvest.nourishment = 6
	run.enemies = run.enemies.filter(func(e): return e.is_boss() or e.kind=="warden")
	var first = run.enemies.filter(func(e): return e.kind=="warden")[0]
	result = capture_body(run,first)
	expect(result.valid and regent.gate_ids.size()==1 and regent.shield_remaining==18.0,"Breaking one Regent shield starts an explicit eighteen-second deadline")
	expect(Guide.next_action(run).title=="Break the last shield","The live instruction prioritizes finishing the shield pair")
	restored = Run.new(true,1,true,true)
	Save.restore(restored,Save.capture(run))
	run.state = Run.PAUSED
	run.step(20.0)
	expect(regent.shield_remaining==18.0,"Pause never consumes the shield deadline")
	run.state = Run.ACTIVE
	tick(run,18.1)
	tick(restored,18.1)
	expect(regent.gate_ids.size()==2 and not regent.can_take_pulse() and restored.boss().gate_ids==regent.gate_ids,"Expired shields regrow once, identically after save/resume")
	# One broad but legal membrane can break both, avoiding the deadline.
	var guards: Array = run.enemies.filter(func(e): return e.kind=="warden")
	var at: Vector2 = (run.board.anchors[0]+run.board.anchors[8]+run.board.anchors[9])/3.0
	guards[0].nucleus = at+Vector2(-8,0)
	guards[1].nucleus = at+Vector2(8,0)
	select(run)
	result = run.release()
	expect(result.wardens==2 and regent.can_take_pulse() and regent.shield_remaining==0.0,"Capturing both shields together opens Regent without a regeneration race")
	restored.dispose()
	quiet(run,6)
	var cradles: Array = run.enemies.filter(func(e): return e.cradle)
	expect(cradles.size()==1 and cradles[0].gate_ids.size()==2 and not cradles[0].can_take_pulse(),"The earlier glass cradle teaches the same two-shield rule")
	var pearl = cradles[0]
	expect(Guide.next_action(run).title=="Open the glass cradle","The nursery explains the preparatory shield interaction")
	run.enemies = run.enemies.filter(func(e): return e==pearl or pearl.gate_ids.has(e.id))
	var hunter = run.Drifter.new(1901,pearl.nucleus,0.0)
	hunter.age = 3.0
	run.enemies.append(hunter)
	tick(run,7.0)
	expect(run.enemies.has(pearl) and hunter.hunt_target==-1,"A protected cradle pearl cannot be eaten through its intact shields")
	run.enemies = run.enemies.filter(func(e): return not pearl.gate_ids.has(e.id))
	run.harvest.ecology.resolve_gates(run)
	expect(pearl.can_take_pulse() and run.harvest.ecology.notice.contains("rescue"),"Removing the cradle shields exposes a normal rescuable pearl")
	result = capture_body(run,pearl)
	expect(result.valid and result.rescued>=1,"The practice cradle leads to a real rescue")
	var broad_run := Run.new(true,73,true,true)
	fixture_stage(broad_run,11)
	broad_run.enemies = [broad_run.boss()]
	broad_run.harvest.nourishment = 3
	select(broad_run,range(16,24))
	var broad_result: Dictionary = broad_run.release()
	expect(broad_result.valid and broad_result.boss_layers==1,"A legal eight-cell membrane can catch both separated hearts immediately without waiting")
	broad_run.dispose()
	quiet(run,11)
	var twins = run.boss()
	run.enemies = [twins]
	run.harvest.nourishment = 6
	var wide: float = twins.nuclei()[0].distance_to(twins.nuclei()[1])
	expect(twins.can_take_pulse() and twins.gate_ids.is_empty() and wide>150.0,"Conjoined exposes two separated hearts without any shield puzzle")
	tick(run,6.1)
	expect(twins.nuclei()[0].distance_to(twins.nuclei()[1])<55.0,"Waiting brings the hearts together for a smaller polygon")
	select(run,[0,8,9,1])
	expect(Guide.next_action(run).title=="Release to attack" and run.harvest_preview().boss_layers==1,"Both contracted hearts are an honest charged capture")
	result = run.release()
	expect(result.boss_layers==1 and twins.health==2 and run.enemies.any(func(e): return e.kind=="twinspore" and e.age==0.0),"An actual hit releases an emerging paired hunter while preserving the boss's next layer")
	var young = run.enemies.filter(func(e): return e.kind=="twinspore")[0]
	var birth: Vector2 = young.nucleus
	var deadline := Guide.contact_seconds(run,young)
	expect(deadline>=18.0 and deadline<=35.0,"The nearby young pair creates a real but deliberate response window")
	tick(run,2.5)
	expect(young.nucleus==birth and is_equal_approx(young.age,2.5) and young.foraging_done,"Young hearts visibly emerge before moving toward Mother, without a food detour")
	restored = Run.new(true,1,true,true)
	expect(Save.restore(restored,Save.capture(run)),"Save captures the new boss phase and paused hatchling")
	tick(run,1.0)
	tick(restored,1.0)
	expect(young.nucleus.distance_to(birth)>1.0 and Save.capture(restored).enemies==Save.capture(run).enemies,"Hatching finishes and resumes with identical real movement after save/load")
	restored.dispose()
	# The last pattern spreads farther, but retains an eight-second tight
	# plateau: thinking, drawing at two segments/s, and a release review fit.
	twins.round_index = 2
	twins.reset_remaining = 0.0
	twins.pattern_time = 0.0
	expect(twins.nuclei()[0].distance_to(twins.nuclei()[1])>wide+50.0,"Later layers increase the spatial challenge without adding health")
	for time in [8.0,12.0,16.0]:
		twins.pattern_time = time
		expect(twins.nuclei()[0].distance_to(twins.nuclei()[1])<=54.01 and twins.can_take_pulse(),"The final layer retains a full deliberate close-heart window at %.0fs" % time)
	# Migrate old shield-based Bellwether and Conjoined snapshots without loss.
	for stage in [3,11]:
		quiet(run,stage)
		var legacy := Save.capture(run)
		legacy.enemies = legacy.enemies.filter(func(e): return e.has("boss"))
		legacy.enemies[0].boss.erase("pattern_time")
		legacy.enemies[0].boss.health = 2
		legacy.enemies[0].health = 2
		legacy.enemies[0].boss.gate_ids = [999]
		legacy.enemies[0].gate_ids = [999]
		restored = Run.new(true,3,true,true)
		expect(Save.restore(restored,legacy) and restored.boss().health==2 and restored.boss().gate_ids.is_empty(),"Legacy boss progress migrates into its distinct pattern at stage %d" % stage)
		restored.dispose()
	run.dispose()
	print("BOSS PATTERNS: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
