extends "res://tests/harvest_visual.gd"

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-habitats-native-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-habitats-native-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.size = Vector2i(1280,900)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.render_loop_enabled = false
	game.run.stage_index = 4
	game.run.start_stage()
	await capture("habitat-choice")
	expect(game.hud.habitat_buttons[0].visible and game.hud.habitat_buttons[1].visible and not game.hud.center_button.visible,"The player sees two explicit travel options before the briefing")
	game.large_text = true
	await capture("habitat-choice-large-text")
	var at: Vector2 = game.hud.habitat_buttons[1].get_rect().get_center()
	mouse(at,true)
	mouse(at,false)
	await capture("habitat-refuge-brief")
	expect(game.run.habitat_choice=="refuge" and game.run.state==Run.BRIEF and game.hud.center_button.visible,"Clicking shelter reveals its encounter briefing without starting the timer")
	key(KEY_ENTER)
	game.run.step(3.0)
	game.visual_time += 3.0
	await capture("habitat-refuge-live")
	expect(game.run.state==Run.ACTIVE and game.run.habitat_applied and game.run.enemies.filter(func(e): return e.kind=="food").size()==8,"Native entry activates the advertised sheltered food supply")
	expect(game.microscope.appearance.key.ends_with(":refuge"),"The live dish renders the selected habitat appearance")
	game.toggle_help()
	await refresh()
	expect(game.hud.habitat_buttons.all(func(b): return not b.visible),"Travel controls do not leak over help or gameplay")
	game.toggle_help()
	game.run.stage_index = 2
	game.run.start_stage()
	await refresh()
	key(KEY_ENTER)
	await refresh()
	expect(game.run.state==Run.BRIEF and game.run.habitat_confirmed and game.run.habitat_choice=="bloom","Keyboard travel confirms the food-rich route and leaves time to read its briefing")
	key(KEY_ENTER)
	await refresh()
	expect(game.run.state==Run.ACTIVE and game.run.habitat_history.get("2")=="bloom","A second deliberate Enter starts the selected destination")
	game.queue_free()
	await process_frame
	print("HABITATS VISUAL: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
