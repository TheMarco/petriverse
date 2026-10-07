extends "res://tests/harvest_visual.gd"

func advance(seconds: float) -> void:
	for i in ceili(seconds*60.0):
		game.run.step(1.0/60.0)
		game._process(1.0/60.0)

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-expansion-native-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-expansion-native-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.size = Vector2i(1280,900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.render_loop_enabled = false
	var run = game.run
	run.run_seed = 73
	run.stage_index = 6
	run.start_stage()
	run.begin_encounter()
	advance(15.0)
	game.toast_time = 0.0
	await capture("ecosystem-approaching-wave")
	expect(not preload("res://scripts/encounter_rhythm.gd").warning_sites(run).is_empty(),"Native warning is driven by real pending arrivals")
	advance(5.3)
	await capture("ecosystem-emerging-wave")
	expect(run.enemies.any(func(e): return e.kind=="divider" and e.age<0.5),"The announced divider visibly emerges on schedule")
	run.start_stage()
	run.begin_encounter()
	run.harvest.next_bloom = 9999.0
	run.harvest.ecology.next_wave = 9999.0
	run.enemies.clear()
	var at: Vector2 = run.harvest.ecology.pocket(run,0,true)
	var spore = run.Harvest.Organism.new(901,"spore",at,Vector2.ZERO,0.0)
	spore.age = 3.0
	var hunter = Drifter.new(902,at+Vector2(14,0),5.4)
	hunter.age = 3.0
	run.enemies = [spore,hunter]
	advance(2.5)
	game.toast_time = 0.0
	await capture("ecosystem-hunter-feeding")
	var prey_visual: Sprite2D = game.microscope.enemies[901].get_meta("lobes")[0]
	expect(prey_visual.material.get_shader_parameter("dissolve")>0.35,"Actual predation gradually dissolves prey tissue")
	var predator_visual: Sprite2D = game.microscope.enemies[902].get_meta("lobes")[0]
	expect(predator_visual.material.get_shader_parameter("feeding")>0.4,"Predator tissue visibly feeds as its meal progresses")
	var path: Array = [8,16,17,8]
	mouse(run.board.anchors[path[0]],true)
	for i in range(1,path.size()):
		drag(run.board.anchors[path[i-1]],run.board.anchors[path[i]])
	mouse(run.board.anchors[path[0]],false)
	advance(1.1)
	await capture("ecosystem-guardian-capture")
	expect(run.last_capture.get("mastery",[])==["guardian"] and run.last_capture.rescued==1,"Real mouse input rescues the prey and catches its hunter")
	expect(game.microscope.pulses[0].get_meta("surface").material.get_shader_parameter("mastery")==1.0,"The earned capture has a pearlescent digestion flourish")
	expect(game.toast.begins_with("A life protected"),"The reward explains the player's accomplishment")
	advance(1.0)
	expect(game.soundscape.events_played.get("mastery",0)==1,"The actual earned capture triggers one musical blossom")
	game.queue_free()
	await process_frame
	print("ECOSYSTEM EXPANSION: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
