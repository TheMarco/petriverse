extends "res://tests/harvest_visual.gd"
func capture(name: String) -> void:
	game.set_process_unhandled_input(false)
	await super.capture(name)
	game.set_process_unhandled_input(true)

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-native-journey.cfg"
	game.journey_profile.path = "/tmp/microverse-native-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	await capture("journey-home")
	expect(game.run.state == Run.HOME and game.hud.new_button.visible and not game.hud.colony_buttons[0].visible, "Default launch offers one clear new-journey action")
	mouse(game.hud.new_button.get_rect().get_center(),true)
	mouse(game.hud.new_button.get_rect().get_center(),false)
	await capture("journey-brief")
	expect(game.run.state == Run.BRIEF, "New journey opens the first briefing")
	key(KEY_ENTER)
	await capture("journey-stillwater")
	expect(game.run.state == Run.ACTIVE and not game.hud.center_button.visible, "Enter starts the real encounter")
	var run = game.run
	# The first reward follows two real, guided mouse captures and recovery.
	for path in [run.Lesson.SMALL, run.Lesson.WIDE]:
		mouse(run.board.anchors[path[0]],true)
		var previous: Vector2 = run.board.anchors[path[0]]
		for id in path.slice(1)+[path[0]]:
			drag(previous,run.board.anchors[id])
			previous = run.board.anchors[id]
		mouse(previous,false)
		run.step(3.1)
	await capture("journey-evolution")
	expect(run.state == Run.EVOLVE and game.hud.cards[0].visible and game.hud.travel_button.visible, "Real meal opens mutation and onward travel controls")
	var selected_trait: String = run.offered_mutations[0]
	key(KEY_1)
	await refresh()
	expect(run.stage_index == 1 and run.mutations.has(selected_trait) and run.state == Run.BRIEF, "Evolution input carries the colony to the next encounter")
	key(KEY_ENTER) # Dismiss the growth closeup before the following encounter.
	for stage in [1, 3, 4, 7, 11]:
		run.stage_index = stage
		run.start_stage()
		run.begin_encounter()
		run.step(8.5 if stage == 7 else 5.5)
		await capture("journey-stage-%02d" % stage)
		expect(game.microscope.enemies.size() == run.enemies.size(), "Every organism renders in stage %d" % stage)
		if stage in [3,7,11]:
			expect(game.microscope.enemies[run.boss().id].get_meta("lobes").size() == run.boss().nuclei().size(), "Boss capture anatomy matches rendering")
	# The boss must never hide a dangerous meal's consequence preview.
	run.stage_index = 7
	run.start_stage()
	run.begin_encounter()
	run.harvest.nourishment = 6
	# This checks consequence visibility, independent of the initial bloom count.
	run.integrity = 2
	run.selection.start(run.board.anchors[16])
	for id in [17,18,19,20,21,22,23,16]:
		run.selection.visit(id)
	await capture("journey-boss-risk-preview")
	expect(run.selection.closed and run.harvest_preview().poison >= run.integrity, "Boss encounter still exposes lethal poison in a closed membrane")
	run.selection.cancel()
	game.large_text = true
	run.stage_index = 7
	run.start_stage()
	await capture("journey-large-brief")
	key(KEY_J)
	await capture("journey-journal")
	expect(game.journal_open and game.hud.journal_close.visible and not game.hud.center_button.visible, "Journal pauses and blocks encounter actions")
	key(KEY_J)
	game.return_home()
	await refresh()
	expect(game.hud.continue_button.visible, "Return home offers the saved journey")
	game.resume_journey()
	await refresh()
	expect(run.stage_index == 7 and run.state == Run.BRIEF, "Continue restores progress")
	run.begin_encounter()
	run.state = Run.LOSS
	run.harvest.loss_title = "The mother was eaten."
	run.harvest.loss_reason = "A hunter reached the mother."
	await capture("journey-retry")
	key(KEY_ENTER)
	await refresh()
	expect(run.stage_index == 7 and run.state == Run.BRIEF, "Native retry stays in current encounter")
	run.stage_index = 11
	run.start_stage()
	run.begin_encounter()
	run.boss_defeated = true
	run.check_completion()
	await capture("journey-victory")
	expect(run.state == Run.SUCCESS and game.hud.center_button.visible, "Final victory has a route back into the game")
	game.queue_free()
	await process_frame
	print("JOURNEY VISUAL: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
