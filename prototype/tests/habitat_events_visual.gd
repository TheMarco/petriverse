extends "res://tests/boss_patterns_visual.gd"

func scene(stage: int, time: float) -> void:
	prepare(stage)
	game.run.enemies.clear()
	game.run.stage_elapsed = time
	game.run.harvest.last_time = time
	game.run.harvest.HabitatEvents.step(game.run,0.0)
	game.last_discovery = game.run.discovery_serial
	game.toast_time = 0.0
	game.visual_time = time

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-events-native-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-events-native-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.size = Vector2i(1280,900)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.render_loop_enabled = false
	scene(2,46.0)
	advance(4.0)
	await capture("event-drifting-bloom")
	expect(game.run.enemies.filter(func(e): return e.kind=="food").size()==6,"The migrating event renders real food bodies")
	scene(5,46.0)
	advance(15.0)
	game.large_text = true
	await capture("event-garden-warning")
	expect(Guide.next_action(game.run).title=="Harvest before the garden wakes","The live guidance explains the temporary feeding opportunity")
	advance(7.8)
	await capture("event-garden-hatching")
	var cysts: Array = game.run.enemies.filter(func(e): return e.kind=="cyst")
	expect(cysts.size()==3 and game.microscope.enemies[cysts[0].id].get_meta("lobes")[0].material.get_shader_parameter("arrival")<1.0,"Forecast cysts emerge through the actual organic arrival shader")
	scene(9,59.0)
	await capture("event-deep-traveller")
	expect(game.microscope.traveller.visible and game.microscope.traveller.z_index<game.microscope.mother.z_index,"The giant is visibly below the playable organisms")
	var first: Vector2 = game.microscope.traveller.position
	advance(3.0)
	await refresh()
	expect(game.microscope.traveller.position.distance_to(first)>40.0,"The deep traveller crosses the field with simulation time")
	game.run.toggle_pause()
	first = game.microscope.traveller.position
	game._process(5.0)
	await refresh()
	expect(game.microscope.traveller.position==first,"Pausing freezes the travelling background organism")
	game.run.toggle_pause()
	game.reduced_motion = true
	await refresh()
	first = game.microscope.traveller.position
	advance(2.0)
	await capture("event-deep-traveller-reduced-motion")
	expect(game.microscope.traveller.position==first and game.microscope.traveller.material.get_shader_parameter("motion")==0.0,"Reduced motion removes the large background sweep and tissue flex")
	game.queue_free()
	await process_frame
	print("HABITAT EVENTS VISUAL: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
