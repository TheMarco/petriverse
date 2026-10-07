extends "res://tests/harvest_visual.gd"
const Guide = preload("res://scripts/journey_guidance.gd")
func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-ecology-native-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-ecology-native-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	var run = game.run
	run.stage_index = 7
	run.start_stage()
	run.begin_encounter()
	run.harvest.nourishment = 6
	var eco = run.harvest.ecology
	var grazer = eco.add(run,"grazer",4,eco.pocket(run,4))
	grazer.stored_food = 2
	grazer.action_clock = 2.5
	grazer.spawning = 0.0
	eco.spawn_event(run,{"kind":"parasite","area":2})
	var parasite = run.enemies[-1]
	parasite.nucleus = parasite.destination
	parasite.spawning = 0.0
	parasite.latched = true
	var divider = eco.add(run,"divider",5,eco.pocket(run,5))
	divider.age = 16.0
	divider.spawning = 0.0
	game.last_discovery = run.discovery_serial
	await capture("ecology-living-dish")
	expect(game.microscope.enemies.size()==run.enemies.size(),"Every behavioral organism has a native rendered body")
	for body in [grazer,parasite,divider]:
		var sprite: Sprite2D = game.microscope.enemies[body.id].get_meta("lobes")[0]
		expect(sprite.texture==game.microscope.enemy_texture(body.kind,body.form) and sprite.texture!=game.microscope.DRIFTER,"Distinct final sprite for "+body.kind)
	expect(game.microscope.cells[parasite.target_node].material.get_shader_parameter("energy")<0.3,"Blocked cell visibly loses vitality")
	expect(Guide.next_action(run).title=="Break 2 shields","HUD describes player-created opening")
	var dividing_sprite: Sprite2D = game.microscope.enemies[divider.id].get_meta("lobes")[0]
	expect(dividing_sprite.material.get_shader_parameter("division")>0.0,"The approaching division visibly constricts the living body")
	if "--representative" not in OS.get_cmdline_user_args():
		run.enemies = run.enemies.filter(func(e): return e.kind != "warden")
		eco.resolve_gates(run)
		await capture("ecology-boss-open")
		expect(Guide.next_action(run).title=="Attack the boss now","Shield removal changes the live instruction")
		key(KEY_J)
		await capture("ecology-journal-first")
		game.hud.turn_journal(1)
		await capture("ecology-journal-new-species")
		game.hud.turn_journal(99)
		await capture("ecology-journal-final")
		expect(game.hud.journal_previous.visible and not game.hud.journal_next.visible,"Expanded journal is paginated without overflowing")
		key(KEY_J)
		game.large_text = true
		await capture("ecology-large-text")
		run.stage_index = 6
		run.start_stage()
		await capture("ecology-divider-brief")
		run.begin_encounter()
		run.step(10.0)
		game.last_discovery = run.discovery_serial
		game.toast_time = 0.0
		await capture("ecology-rescue-deadline")
		expect(Guide.next_action(run).title=="Rescue the fading spore","Rendered rescue encounter has an actionable deadline instruction")
	game.queue_free()
	await process_frame
	print("ECOLOGY VISUAL: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
