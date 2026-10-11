extends SceneTree
const Stage = preload("res://scripts/creature_film_stage.gd")
const Cinema = preload("res://scripts/creature_cinema.gd")
const Journey = preload("res://scripts/journey_plan.gd")
const Profile = preload("res://scripts/journey_profile.gd")
var failures: Array = []
var checks := 0
var results := {}
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _initialize() -> void:
	call_deferred("exercise")
func exercise() -> void:
	var catalogue := Cinema.entries()
	expect(catalogue.size()==Journey.SPECIES.size(),"Every discoverable creature has a film")
	for entry in Journey.SPECIES:
		if not OS.get_cmdline_user_args().is_empty() and not OS.get_cmdline_user_args().has(entry.id): continue
		expect(catalogue.has(entry.id),"Catalogue: "+entry.id)
		if not catalogue.has(entry.id): continue
		var data: Dictionary = catalogue[entry.id]
		expect(data.name==entry.name and not data.narration.is_empty(),"Title and narration: "+entry.id)
		var stage = Stage.new()
		root.add_child(stage)
		stage.render_enabled = false
		stage.prepare(data)
		for frame in int(stage.duration*30): stage.advance(1.0/30.0)
		var captures: Array = stage.events.filter(func(e): return e.get("valid",false))
		var errors: Array = stage.events.filter(func(e): return e.has("error") or (e.has("valid") and not e.valid))
		expect(errors.is_empty(),"Legal filmed inputs: "+entry.id)
		var totals := {"food":0,"rescued":0,"cells_rescued":0,"kills":0,"armor_hits":0,"boss_layers":0}
		for capture in captures:
			for key in totals: totals[key] += int(capture.get(key,0))
		match data.scene:
			"food": expect(totals.food>=1,"Food absorbed: "+entry.id)
			"spore": expect(totals.rescued==1,"Spore rescued: "+entry.id)
			"cyst": expect(stage.milestones.get("nudged",false),"Poison nudged: "+entry.id)
			"hunter","grazer": expect(totals.kills>=1 and totals.food>=1,"Theft and recapture: "+entry.id)
			"shellback": expect(totals.armor_hits>=1 and totals.kills>=1,"Two real shell captures: "+entry.id)
			"twinspore": expect(totals.kills>=1,"Both nuclei captured: "+entry.id)
			"amoeba": expect(stage.milestones.get("swallowed",false) and totals.cells_rescued==1,"Swallow and rescue: "+entry.id)
			"phage": expect(stage.milestones.get("infected",false) and stage.milestones.get("ruptured",false),"Full infection: "+entry.id)
			"parasite": expect(stage.milestones.get("latched",false) and totals.kills>=1,"Latch and release: "+entry.id)
			"divider": expect(stage.milestones.get("split",false) and totals.kills>=2,"Split and catch young: "+entry.id)
			"moonlace": expect(stage.milestones.get("bloomed",false),"Moonlace releases food")
			"glowdrift": expect(stage.milestones.get("sheltered",false),"Glowdrift slows a hunter")
			"regent","warden": expect(stage.milestones.get("opened",false),"Linked shields open: "+entry.id)
			"bellwether": expect(stage.milestones.get("opened",false) and not captures.is_empty(),"Breath and capture: "+entry.id)
			"conjoined": expect(totals.boss_layers>=1,"Both boss hearts captured")
		results[entry.id] = {"scene":data.scene,"milestones":stage.milestones,"totals":totals,"errors":errors}
		stage.free()
	# Old profiles have no introduction history; seen films persist independently of discoveries.
	var config := ConfigFile.new()
	config.set_value("profile","discovered",["amoeba"])
	config.save("/tmp/petriverse-film-profile-test.cfg")
	var profile := Profile.new()
	profile.path = "/tmp/petriverse-film-profile-test.cfg"
	profile.load_profile()
	expect(profile.introduced_species.is_empty() and profile.discovered.has("amoeba"),"Old saves migrate without losing discoveries")
	profile.introduced_species.append("amoeba")
	expect(profile.save_profile(),"Introduction history saves")
	var restored := Profile.new()
	restored.path = profile.path
	restored.load_profile()
	expect(restored.introduced_species==["amoeba"] and restored.discovered==["amoeba"],"History survives relaunch separately from journal")
	var report := {"checks":checks,"failures":failures,"films":results}
	FileAccess.open("res://artifacts/creature-films-report.json" if OS.get_cmdline_user_args().is_empty() else "res://artifacts/creature-films-focused-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CREATURE FILMS: ",checks," checks; failures: ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
