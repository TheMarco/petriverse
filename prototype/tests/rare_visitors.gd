extends "res://tests/journey_rules.gd"

func quiet(run: RefCounted, stage: int) -> void:
	run.stage_index = stage
	run.start_stage()
	run.begin_encounter()
	run.harvest.ecology.next_wave = 9999.0
	run.harvest.ecology.pending.clear()
	run.harvest.next_bloom = 9999.0
	run.enemies.clear()
	run.harvest.visitor_at = 0.1
	run.stage_elapsed = 0.1
	run.harvest.last_time = run.stage_elapsed
	run.harvest.Discoveries.step(run)

func exercise() -> void:
	var run := Run.new(true,73,true,true)
	quiet(run,4)
	var harp = run.enemies[0]
	expect(harp.form=="glass_harp" and harp.visitor and harp.age==0.0,"Glassgarden produces its distinct rare visitor through the real director")
	harp.origin = run.board.center+Vector2(150,0)
	harp.nucleus = harp.origin
	harp.drift = Vector2.ZERO
	harp.age = 5.0
	var food = run.Harvest.Organism.new(900,"food",harp.nucleus+Vector2(0,45),Vector2.ZERO,0.0)
	var cyst = run.Harvest.Organism.new(901,"cyst",harp.nucleus+Vector2(0,45),Vector2.ZERO,0.0)
	run.enemies.append_array([food,cyst])
	var max_jump := 0.0
	for i in 360:
		var before: Vector2 = food.nucleus
		run.step(1.0/60.0)
		max_jump = maxf(max_jump,before.distance_to(food.nucleus))
	expect(food.nucleus.distance_to(cyst.nucleus)>20.0,"Leaving the Glass Harp alive actually separates food from adjacent poison")
	expect(max_jump<0.1 and run.harvest.nourishment==0 and run.harvest.purified==0,"Filtering is gentle movement, not a teleport or automatic objective completion")
	var saved := Save.capture(run)
	var clone := Run.new(true,99,true,true)
	expect(Save.restore(clone,saved),"The new visitor restores with the normal journey snapshot")
	for i in 90:
		run.step(1.0/60.0)
		clone.step(1.0/60.0)
	expect(clone.enemies[1].nucleus.distance_to(food.nucleus)<0.001,"The saved filtering current resumes from exactly the same bodies and opening phase")
	var before: Vector2 = cyst.nucleus
	run.toggle_pause()
	run.step(20.0)
	expect(cyst.nucleus==before,"Pause freezes both the visitor and its real filtering current")
	run.toggle_pause()
	for cell in run.cells:
		cell.remaining = 0.0
	harp.origin = (run.board.anchors[0]+run.board.anchors[8]+run.board.anchors[9])/3.0
	harp.nucleus = harp.origin
	run.enemies = [harp]
	select(run)
	var result: Dictionary = run.release()
	expect(result.rescued==1 and run.rescued_specimens[-1].form=="glass_harp" and run.rescued_specimens[-1].rare,"An ordinary polygon rescues the Glass Harp with its exact rare identity")
	expect(not run.enemies.has(harp),"Rescuing the visitor ends its help in the active dish")
	quiet(run,8)
	var glow = run.enemies[0]
	glow.origin = run.board.center+Vector2(170,0)
	glow.nucleus = glow.origin
	glow.drift = Vector2.ZERO
	glow.age = 6.0
	var hunter = run.Drifter.new(910,glow.nucleus+Vector2(45,0),5.4,"drifter")
	var distant = run.Drifter.new(911,glow.nucleus+Vector2(0,160),5.4,"drifter")
	run.enemies.append_array([hunter,distant])
	run.harvest.Discoveries.step(run,1.0/60.0)
	expect(glow.form=="glowdrift" and hunter.slowed>0 and distant.slowed==0,"Deepwater's glowing visitor slows an actual nearby hunter, leaving distant hunters untouched")
	var near_start: Vector2 = hunter.nucleus
	var far_start: Vector2 = distant.nucleus
	hunter.step(0.4,near_start+Vector2(100,0))
	distant.step(0.4,far_start+Vector2(100,0))
	expect(hunter.nucleus.distance_to(near_start)<distant.nucleus.distance_to(far_start)*0.75,"The shelter changes real hunter travel, not just its appearance")
	glow.age = 17.0
	hunter.slowed = 0.0
	run.harvest.Discoveries.step(run,1.0/60.0)
	expect(hunter.slowed==0,"The shelter rests between openings so protection is temporary")
	expect(Save.restore(clone,Save.capture(run)) and clone.enemies[0].form=="glowdrift" and clone.enemies[0].opening()==glow.opening(),"Save and resume retain the shelter's species and closed phase")
	run.dispose()
	clone.dispose()
	print("RARE VISITORS: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
