extends "res://tests/journey_rules.gd"

func exercise() -> void:
	var run := Run.new(true,73,true,true)
	fixture_stage(run,3)
	run.begin_encounter()
	run.enemies = run.enemies.filter(func(body): return body.kind != "food")
	run.harvest.nourishment = 0
	var before: int = run.harvest.blooms
	run.stage_elapsed = 17.0
	run.harvest.step(run)
	expect(run.harvest.blooms == before, "Empty dish retains a short recovery interval")
	run.stage_elapsed = 18.0
	run.harvest.step(run)
	expect(run.harvest.blooms == before+1 and run.harvest.last_refill == 18.0, "Depleted boss dish brings its next real food bloom forward")
	var snapshot := Save.capture(run)
	var restored := Run.new(true,99,true,true)
	expect(Save.restore(restored,snapshot) and restored.harvest.last_refill==18.0, "Food refill interval survives save and resume")
	restored.enemies = restored.enemies.filter(func(body): return body.kind != "food")
	restored.stage_elapsed = 19.0
	restored.harvest.step(restored)
	expect(restored.harvest.blooms==before+1, "Resume does not immediately duplicate replenishment")
	fixture_stage(run,3)
	run.begin_encounter()
	run.harvest.nourishment = 6
	run.enemies = run.enemies.filter(func(body): return body.kind != "food")
	before = run.harvest.blooms
	run.stage_elapsed = 20.0
	run.harvest.step(run)
	expect(run.harvest.blooms==before, "Fully charged boss does not receive unneeded catch-up food")
	var profile := Profile.new()
	profile.path = "/tmp/petriverse-producer-improvements-profile.cfg"
	run.rescued_specimens = [{"token":"new-life","form":"pearl_spore","rare":false,"stage":3,"encounter":4}]
	profile.observe(run)
	expect(profile.new_residents().size()==1, "A real rescue awaits its first homecoming")
	profile.observe(run)
	expect(profile.new_residents().size()==1, "Autosave cannot duplicate a homecoming")
	var loaded := Profile.new()
	loaded.path = profile.path
	loaded.load_profile()
	expect(loaded.new_residents().size()==1, "Pending homecoming survives closing the game")
	loaded.welcome(["new-life"])
	var welcomed := Profile.new()
	welcomed.path = profile.path
	welcomed.load_profile()
	expect(welcomed.new_residents().is_empty() and welcomed.residents.size()==1, "Welcoming persists without removing the resident")
	welcomed.residents.append({"token":"legacy","form":"pearl_spore","rare":false})
	expect(welcomed.new_residents().is_empty(), "Old residents without the new field are already settled")
	expect(welcomed.origin_text(welcomed.residents[0]).contains("encounter 4"), "Resident history retains the rescue encounter")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]: DirAccess.remove_absolute(profile.path+suffix)
	run.dispose()
	restored.dispose()
	print("PRODUCER IMPROVEMENTS: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
