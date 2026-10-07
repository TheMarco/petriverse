extends "res://tests/journey_feasibility.gd"
## Focused late-game proxy: observed routes, 2.5s deliberation, swept-pointer
## input at two segments/s, and six-pixel aim error. Never a human win rate.

func exercise() -> void:
	var board_run := Run.new(false)
	for i in 24:
		routes(board_run.board,[i],6)
	for s in 8:
		var n := (s+1)%8
		var nn := (s+2)%8
		var nnn := (s+3)%8
		candidates.append([s,8+s,16+s,16+n,16+nn,8+nn,nn,n])
		candidates.append([s,8+s,16+s,16+n,16+nn,16+nnn,8+nnn,nnn,nn,n])
	candidates.append([0,1,2,3,4,5,6,7])
	board_run.dispose()
	var builds := {
		"fission":["fission","grazer","lure","frenzy","nursery"],
		"elastic":["elastic","feast","enzyme","filter","catalyst"],
		"symbiosis":["symbiosis","enzyme","residual","frenzy","nursery"],
	}
	var reports: Array = []
	for build in builds:
		var run := Run.new(true,73,true,true)
		for trait_id in builds[build]:
			run.add_mutation(trait_id)
		run.stage_index = 11
		run.start_stage()
		run.begin_encounter()
		var profile := {"name":"deliberate", "rate":2.0, "think":2.5, "review":0.45, "routes":8, "aim":6.0, "mistake_every":0, "build":build, "cyst_margin":6.0 if build=="fission" else 12.0}
		var report := measure_stage(run,profile,run.run_seed+11*17)
		report.build = build
		report.mutations = run.mutations.duplicate()
		reports.append(report)
		print("FINALE PROFILE ",JSON.stringify(report))
		expect(report.state==Run.SUCCESS,"The finale remains achievable at two segments/s with "+build)
		expect(report.max_rate<=2.00001,"The finale policy respects deliberate human input speed: "+build)
		run.dispose()
	var file := FileAccess.open("res://artifacts/finale-pacing.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"profiles":reports,"limits":"Three sampled builds at seed 73; scripted local observations, not human difficulty or enjoyment."},"\t"))
	file.close()
	print("FINALE PACING: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
