extends "res://tests/journey_mastery.gd"

func exercise() -> void:
	var run := Run.new(true,73,true,true)
	var profile := Profile.new()
	profile.path = "/tmp/microverse-pond-memories-rules.cfg"
	quiet(run)
	meal(run,["spore","drifter"])
	select(run)
	var capture: Dictionary = run.release()
	profile.observe(run)
	expect(capture.mastery==["guardian"] and profile.keepsake_unlocked("guardian"),"An actual clean rescue unlocks the permanent pearl nursery")
	expect(profile.residents.size()==1 and profile.pond_memories.size()==1,"A garden is a memory, never a fabricated rescued resident")
	var token: String = profile.residents[0].token
	expect(profile.rename_resident(token,"  Luna  ") and profile.resident_label(profile.residents[0])=="Luna","A rescued resident can receive a trimmed personal name")
	expect(not profile.rename_resident("not-a-resident","Ghost") and profile.residents.size()==1,"Naming cannot invent a resident")
	profile.observe(run)
	expect(profile.pond_memories.size()==1 and profile.resident_label(profile.residents[0])=="Luna","Repeated observations preserve names and do not duplicate achievements")
	var loaded := Profile.new()
	loaded.path = profile.path
	loaded.load_profile()
	expect(loaded.pond_memories==profile.pond_memories and loaded.resident_label(loaded.residents[0])=="Luna","Names and earned gardens survive a real disk reload")
	var before := Save.capture(run)
	var retry := Run.new(true,4,true,true)
	Save.restore(retry,before)
	loaded.observe(retry)
	expect(loaded.pond_memories.size()==1,"Restoring the same journey cannot farm a second persistent feat")
	retry.dispose()
	quiet(run,4)
	meal(run,["food","food","food","food"])
	for i in 4:
		run.enemies[i].bloom_id = i/2
	select(run)
	capture = run.release()
	loaded.observe(run)
	expect(capture.mastery==["gatherer"] and loaded.keepsake_unlocked("gatherer"),"A real two-bloom capture grows a fern meadow")
	quiet(run,8)
	run.harvest.spec.food = 1
	run.harvest.spec.target = 0
	meal(run,["food"])
	select(run)
	run.release()
	loaded.observe(run)
	expect(run.state==Run.EVOLVE and loaded.keepsake_unlocked("clear_water"),"Finishing a poison-free encounter grows a glass garden")
	var points: int = run.score
	var health: int = run.integrity
	var traits: Array = run.mutations.duplicate()
	loaded.rename_resident(token,"Aurora\nBorealis")
	expect(loaded.resident_label(loaded.residents[0])=="Aurora Borealis" and run.score==points and run.integrity==health and run.mutations==traits,"Personal names are sanitized and do not alter journey power")
	loaded.rename_resident(token,"W".repeat(40))
	expect(loaded.resident_label(loaded.residents[0]).length()==24,"Names respect the visible editor's length limit")
	loaded.rename_resident(token,"")
	expect(loaded.resident_label(loaded.residents[0])=="Pearl spore","Clearing a name restores the species label")
	loaded.rename_resident(token,"Luna")
	for stage in [2,3,5,6]:
		run.stage_index = stage
		run.state = Run.EVOLVE
		loaded.observe(run)
	expect(loaded.maturity(loaded.residents[0])==1.0,"Newly completed encounters mature an existing resident")
	quiet(run,9)
	meal(run,["spore"])
	select(run)
	run.release()
	loaded.observe(run)
	var young: Dictionary = loaded.residents[-1]
	var guide: Dictionary = loaded.companion_for(young,loaded.residents)
	expect(guide.token==token and loaded.relationship(young,guide).contains("Luna"),"A young actual rescue recognizes a mature named companion")
	expect(loaded.companion_for(young,[young]).is_empty(),"A single visible resident never invents an offscreen companion")
	var mature := loaded.maturity(young)
	loaded.observe(run)
	expect(loaded.maturity(young)==mature,"Companionship does not farm additional growth")
	run.restart()
	loaded.observe(run)
	expect(loaded.pond_memories.size()==3 and run.mastery_awards.is_empty(),"New journeys retain the three gardens but start fresh optional feats")
	var legacy := ConfigFile.new()
	legacy.set_value("profile","discovered",["spore"])
	legacy.save("/tmp/microverse-pond-memories-legacy.cfg")
	var old := Profile.new()
	old.path = "/tmp/microverse-pond-memories-legacy.cfg"
	old.load_profile()
	expect(old.pond_memories.is_empty() and old.residents.is_empty() and old.discovered==["spore"],"Older profiles load without invented rewards or erased discoveries")
	run.dispose()
	print("POND MEMORIES: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
