extends SceneTree
const Expedition = preload("res://scripts/expedition_creatures.gd")
const Cinema = preload("res://scripts/creature_cinema.gd")
const MotherAppearance = preload("res://scripts/mother_appearance.gd")
## Run against an exported PCK with isolated state, never a player's save files.
var failures: Array[String] = []
var checks := 0
var game

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ",label)

func _initialize() -> void:
	root.unfocusable = true
	call_deferred("exercise")

func exercise() -> void:
	var Main = load("res://scripts/main.gd")
	expect(Main!=null,"Main script loads from exported pack")
	if Main==null:
		quit(1)
		return
	game = Main.new()
	game.save_records = false
	game.preferences_enabled = false
	game.audio_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-release-smoke-journey.cfg"
	game.journey_profile.path = "/tmp/microverse-release-smoke-profile.cfg"
	game.preferences_path = "/tmp/microverse-release-smoke-preferences.cfg"
	game.records.path = "/tmp/microverse-release-smoke-records.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	root.size = Vector2i(1280,900)
	root.content_scale_size = root.size
	RenderingServer.render_loop_enabled = false
	expect(game.run.state==game.run.HOME,"Main menu starts")
	expect(game.run.board.anchors.size()==24,"Board JSON is packaged")
	for name in game.soundscape.EFFECTS + game.soundscape.TRACKS + game.soundscape.LAYERS + ["pond"]:
		expect(game.soundscape.streams.has(name),"Bundled audio: "+name)
	for entry in Expedition.ENTRIES:
		expect(ResourceLoader.exists("res://assets/organisms/"+entry.id+".png"),"Rare creature: "+entry.id)
	var films: Dictionary = Cinema.entries()
	expect(films.size()==44,"All 44 creature films are bundled")
	for id in films:
		expect(ResourceLoader.exists("res://assets/audio/introductions/"+id+".ogg"),"Creature film narration: "+id)
	for stage in [1,2,4,8,10]:
		expect(MotherAppearance.texture_for(stage,[])!=null,"Mother organelle stage: "+str(stage))
		expect(MotherAppearance.texture_for(stage,["elastic"])!=null,"Elastic Mother organelle stage: "+str(stage))
	for plate in game.microscope.Appearance.PLATES:
		expect(ResourceLoader.exists(plate),"Biome plate: "+plate)
	expect(ProjectSettings.get_setting("application/config/name")=="Petriverse","Release title is Petriverse")
	expect(ProjectSettings.get_setting("application/config/version")=="0.2.3","Release version is 0.2.3")
	for asset in ["branding/petriverse-title-v2.png","organisms/copper-bacterium.png","organisms/silver-phage.png","fonts/Inter-Variable.ttf"]:
		expect(ResourceLoader.exists("res://assets/"+asset),"Current release asset: "+asset)
	for score in ["petriverse-stillwater","petriverse-glassgarden","petriverse-blue-deep"]:
		var music = load("res://assets/audio/"+score+".ogg")
		expect(music!=null and music.get_length()>130.0,"User score packaged: "+score)
	game.new_journey("wanderer")
	expect(game.run.route_plan.size()==15,"New journey has fifteen encounters")
	# Exercise one ordinary capture from the shipped data and compiled scripts.
	game.run.long_journey = false
	game.run.route_plan.clear()
	game.run.stage_index = 1
	game.run.start_stage()
	game.run.begin_encounter()
	game.run.enemies.clear()
	game.run.harvest.next_bloom = 9999
	game.run.harvest.ecology.next_wave = 9999
	game.run.harvest.ecology.pending.clear()
	var anchors = game.run.board.anchors
	var at: Vector2 = (anchors[0]+anchors[8]+anchors[9])/3.0
	var food = game.run.Harvest.Organism.new(500,"food",at,Vector2.ZERO,0.0)
	food.age = 4
	game.run.enemies.append(food)
	game.run.selection.start(anchors[0])
	for id in [8,9,0]: game.run.selection.visit(id)
	var capture: Dictionary = game.run.release()
	expect(capture.get("valid",false) and capture.get("food",0)==1,"Real loop feeds Mother from exported pack")
	for frame in 120:
		game.run.step(1.0/30.0)
		game._process(1.0/30.0)
		await process_frame
		RenderingServer.force_draw(false)
		if frame==32 and DisplayServer.get_name()!="headless":
			expect(root.get_texture().get_image().save_png("/tmp/microverse-release-smoke.png")==OK,"Native release screenshot saved")
	expect(game.run.integrity==game.run.max_integrity,"Capture preserves Mother health")
	expect(game.run.cells.all(func(c): return c.is_ready()),"Captured cells recover")
	expect(game.run.fluid.clock>0.0,"Persistent fluid simulation runs from exported pack")
	var water_map = game.microscope.field.material.get_shader_parameter("fluid_map")
	expect(water_map!=null and water_map.get_size()==Vector2(28,28),"Native microscope receives the shared fluid map")
	var water_snapshot: Dictionary = game.run.fluid.snapshot()
	game.run.toggle_pause()
	game.run.step(1.0)
	expect(game.run.fluid.snapshot()==water_snapshot,"Exported fluid simulation respects pause")
	var report := {"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"platform":OS.get_name(),"source":ProjectSettings.globalize_path("res://")}
	var file := FileAccess.open("/tmp/microverse-release-smoke.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("RELEASE SMOKE: ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
