extends "res://tests/journey_rules.gd"
func exercise() -> void:
	var run := Run.new(true, 73, true, true)
	for id in ["fission", "elastic", "frenzy", "lure", "residual", "feast", "catalyst"]:
		fixture_stage(run, 0)
		run.mutations.clear()
		run.add_mutation(id)
		run.selection.max_vertices = run.Mutations.maximum(run.mutations)
		var path: Array = [0,8,9]
		if id == "elastic":
			path = [0,8,16,17,18,19,11,3,2,1]
		elif id == "feast":
			path = [0,1,2,10,9,8]
		meal(run, ["food","food","food","food"] if id == "feast" else (["food","cyst"] if id == "catalyst" else ["food","food","food"]), path)
		var extra: RefCounted
		var extra_origin := Vector2.ZERO
		if id == "lure":
			extra_origin = (run.board.anchors[8] + run.board.anchors[9])*0.5
			extra_origin += (extra_origin-run.board.center).normalized()*30.0
			run.next_enemy_id += 1
			extra = run.Harvest.Organism.new(run.next_enemy_id,"food",extra_origin,Vector2.ZERO,0.0)
			run.enemies.append(extra)
		select(run,path)
		var preview: Dictionary = run.harvest_preview()
		var result: Dictionary = run.release()
		expect(result.valid, "Valid %s membrane" % id)
		if not result.valid:
			continue
		expect(result.food == preview.food and result.poison == preview.poison, "%s preview agrees with release" % id)
		expect(result.food_bonuses == preview.food_bonuses,"The preview attributes exactly the upgrades awarded on release: "+id)
		var attributed: int = result.raw_food+result.salvage
		for bonus in result.food_bonuses.values():
			attributed += int(bonus)
		expect(attributed==result.food,"Base food plus visible upgrade bonuses accounts for the whole meal: "+id)
		match id:
			"fission":
				expect(result.recovery == 2.0 and result.food==4,"Nimble's first upgrade rewards a clean small meal and returns its cells in two seconds")
				expect(run.Mutations.food_bonus_text(result)=="Rapid Fission +1","The first upgrade's real contribution is named in the capture feedback")
			"elastic":
				expect(path.size()==10 and result.recovery==3.6 and result.food==6,"Feast's first upgrade doubles desmid food in a wide capture with a recovery tradeoff")
			"frenzy":
				expect(run.is_ready(path[0]) and not run.clots[0].nodes.has(path[0]),"Frenzy frees the first node while the others fuse")
			"lure":
				run.step(0.7)
				expect(extra.origin.distance_to(extra_origin)>20.0,"Lure physically draws nearby desmids into the next meal")
			"residual":
				expect(run.residuals.size()==1 and run.residuals[0].remaining==4.0,"Residual persists for its advertised duration")
				var edge: Vector2 = (run.board.anchors[8] + run.board.anchors[9])*0.5
				var outward: Vector2 = (edge-run.board.center).normalized()
				extra = run.Drifter.new(999,edge+outward*2.0,10.0,"drifter")
				run.enemies.append(extra)
				run.step(0.4)
				expect(extra.slowed > 0.0,"A hunter crossing a residual membrane actually slows")
			"feast":
				expect(result.food==6 and result.recovery==4.0,"Feast gains food at the cost of a slower wide loop")
			"catalyst":
				expect(result.food==3 and result.poison==1,"Unfiltered Catalyst preserves the risk as well as its food bonus")
	# The first-choice feeding rewards must keep their spatial tradeoffs when
	# a later colony acquires both traits, and cannot create food from emptiness.
	fixture_stage(run,1)
	run.mutations = ["fission","elastic"]
	meal(run,["food","food","food"])
	select(run)
	var narrow: Dictionary = run.release()
	expect(narrow.food==4,"A short mixed-build loop earns only the Nimble feeding bonus")
	settle(run)
	meal(run,["food","food","food"],[0,1,2,10,9,8])
	select(run,[0,1,2,10,9,8])
	var wide: Dictionary = run.release()
	expect(wide.food==6,"A wide mixed-build loop earns only the Feast feeding bonus")
	settle(run)
	meal(run,["food","cyst"])
	select(run)
	var poisoned: Dictionary = run.release()
	expect(poisoned.food==1 and poisoned.poison==1,"An unfiltered poisoned meal does not earn Nimble's clean-feeding reward")
	expect(poisoned.food_bonuses.is_empty(),"Poisoned feeding cannot display a clean-meal evolution bonus")
	settle(run)
	meal(run,[])
	select(run)
	expect(run.release().food==0,"Empty loops never manufacture food")
	# Save a boss with a spent layer, charge and pending recovery, then compare.
	fixture_stage(run,7)
	run.mutations.clear()
	run.harvest.nourishment = 6
	run.enemies = run.enemies.filter(func(e): return e.kind != "warden")
	run.harvest.ecology.resolve_gates(run)
	var boss_route: Array = [0,8,9,1]
	select(run,boss_route)
	var strike: Dictionary = run.release()
	expect(strike.boss_layers==1 and run.boss().health==2 and run.harvest.nourishment==mini(6,3+int(strike.get("food",0))),"A real charged loop strips exactly one boss layer")
	var snapshot := Save.capture(run)
	var restored := Run.new(true,109,true,true)
	expect(Save.restore(restored,snapshot),"Mid-boss snapshot loads")
	expect(restored.boss().health==run.boss().health and restored.boss().round_index==run.boss().round_index and restored.boss().open_remaining==run.boss().open_remaining and restored.boss().nuclei()==run.boss().nuclei(),"Boss layer, opening and capture geometry survive resume")
	for i in 300:
		run.step(1.0/60.0)
		restored.step(1.0/60.0)
	expect(Save.capture(restored).enemies==Save.capture(run).enemies,"Boss and all accompanying organisms remain deterministic after resume")
	for colony in run.JourneyPlan.COLONIES:
		run.colony_id = colony.id
		run.restart()
		expect(run.mutations.is_empty() if colony.trait=="" else run.mutations==[colony.trait],"Starting colony has the promised strategy: "+colony.id)
	run.dispose()
	restored.dispose()
	print("JOURNEY MUTATIONS: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
