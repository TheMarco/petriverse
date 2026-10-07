extends "res://tests/harvest_visual.gd"
const Save = preload("res://scripts/journey_save.gd")

func trace(path: Array) -> void:
	mouse(game.run.board.anchors[path[0]], true)
	var previous: Vector2 = game.run.board.anchors[path[0]]
	for id in path.slice(1) + [path[0]]:
		drag(previous, game.run.board.anchors[id])
		previous = game.run.board.anchors[id]
	mouse(previous, false)

func advance(seconds: float) -> void:
	for i in ceili(seconds*60):
		game.run.step(1.0/60.0)
		game.visual_time += 1.0/60.0

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-onboarding-no-save.cfg"
	game.journey_profile.path = "/tmp/microverse-onboarding-no-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	await capture("onboarding-home")
	expect(game.hud.new_button.visible and not game.hud.colony_buttons[0].visible, "One new-journey action; starting traits are optional")
	mouse(game.hud.advanced_button.get_rect().get_center(),true)
	mouse(game.hud.advanced_button.get_rect().get_center(),false)
	await refresh()
	expect(game.hud.colony_buttons[0].visible and not game.hud.new_button.visible, "Advanced colonies remain accessible")
	game.hud.toggle_advanced()
	mouse(game.hud.new_button.get_rect().get_center(),true)
	mouse(game.hud.new_button.get_rect().get_center(),false)
	await refresh()
	expect(game.run.state == Run.BRIEF and game.run.lesson_step == 0, "New journey starts with the ordinary colony and a playable lesson")
	key(KEY_ENTER)
	advance(2)
	await capture("onboarding-small-loop")
	var run = game.run
	var anchors: PackedVector2Array = run.board.anchors.duplicate()
	advance(35)
	expect(run.stage_elapsed == 0 and run.enemies.size() == 3 and run.state == Run.ACTIVE, "Thinking does not expire food or run the lesson timer")
	expect(run.board.anchors[0] == anchors[0] and run.board.anchors[8] == anchors[8], "Lesson targets remain stable while the rest of the dish drifts")
	trace(run.Lesson.SMALL)
	expect(run.lesson_step == 1 and run.biomass == 3 and not run.is_ready(0), "Real mouse small capture starts actual recovery and earns 3 food")
	var snapshot := Save.capture(run)
	var restored := Run.new(true,81,true,true)
	expect(Save.restore(restored,snapshot) and restored.lesson_step == 1, "Save preserves the recovery teaching step")
	restored.step(3.1)
	expect(restored.lesson_step == 2 and restored.enemies.size() == 6, "Resumed lesson advances to the wide capture")
	restored.dispose()
	advance(3.1)
	await capture("onboarding-wide-loop")
	expect(run.lesson_step == 2 and run.enemies.size() == 6, "Second teaching situation supplies two food clusters")
	trace(run.Lesson.WIDE)
	expect(run.lesson_step == 3 and run.biomass == 9, "Six-cell capture collects both clusters using real geometry")
	advance(3.1)
	await capture("onboarding-first-upgrade")
	expect(run.state == Run.EVOLVE and run.offered_mutations == ["fission","elastic"], "Both captures and recovery precede the two understandable upgrades")
	expect(game.hud.cards[0].guided_choice and game.hud.cards[1].visible and not game.hud.cards[2].visible, "Only the two taught choices appear, with animated examples")
	expect(game.hud.cards[0].cost == 6 and game.hud.cards[0].balance == 9, "Upgrade shows the actual cost and food balance")
	expect(game.hud.repair_button.disabled and game.hud.repair_button.text.contains("healthy"), "Full health explains why repair is unavailable")
	for card in game.hud.cards:
		card.set_process(false)
		card.demo_time = 0.0
	await capture("onboarding-upgrade-ready")
	var before: Image
	if DisplayServer.get_name() != "headless":
		before = root.get_texture().get_image().get_region(Rect2i(276,322,350,115))
	for card in game.hud.cards:
		card.demo_time = 2.4
	await capture("onboarding-upgrade-digesting")
	if before != null:
		var after := root.get_texture().get_image().get_region(Rect2i(276,322,350,115))
		expect(before.get_data() != after.get_data(), "Animated example visibly changes from tracing cells to digesting")
	var old := Save.capture(run)
	old.run.erase("lesson_step")
	old.run.erase("lesson_nodes")
	old.run.offered_mutations = ["fission","elastic","symbiosis"]
	var migrated := Run.new(true,81,true,true)
	expect(Save.restore(migrated,old) and migrated.offered_mutations == ["fission","elastic"], "Existing first-choice saves receive the new pair without replaying progress")
	migrated.dispose()
	game.large_text = true
	game.reduced_motion = true
	await capture("onboarding-upgrade-large-text")
	key(KEY_1)
	await refresh()
	expect(run.stage_index == 1 and run.biomass == 3 and run.mutations == ["fission"], "Chosen benefit costs 6, persists, and advances the journey")
	key(KEY_ENTER)
	key(KEY_ENTER)
	await refresh()
	expect(run.state == Run.ACTIVE, "Evolution reveal and next briefing remain playable")
	run.selection.start(run.board.anchors[0])
	run.selection.visit(16)
	expect(run.selection.path == [0,16], "Formerly disconnected cells can connect")
	expect(run.selection.rejection_reason.is_empty(), "Free connections do not display a false restriction")
	run.selection.visit(8)
	expect(run.selection.rejection_reason.is_empty(), "Valid movement has no rejection feedback")
	run.selection.cancel()
	run.cells[8].remaining = 1
	run.selection.start(run.board.anchors[0])
	run.selection.visit(8)
	expect(run.selection.rejection_reason.contains("busy"), "Recovering cells explain why they cannot connect")
	expect(game.JourneyHud.Guidance.next_action(run).title == "Cell is digesting", "Recovery feedback includes the live remaining time")
	run.cells[8].remaining = 0
	expect(game.JourneyHud.Guidance.next_action(run).title != "Cell is digesting", "Recovery feedback clears when the cell is ready")
	# A partial meal must not silently award missing food or skip a teaching step.
	game.new_journey("wanderer")
	run.begin_encounter()
	run.enemies[1].origin = run.board.anchors[20]
	run.enemies[1].nucleus = run.enemies[1].origin
	run.enemies[2].origin = run.board.anchors[21]
	run.enemies[2].nucleus = run.enemies[2].origin
	trace(run.Lesson.SMALL)
	expect(run.lesson_step == 0 and run.biomass == 1, "Partial meal earns only real food and leaves the teaching situation active")
	# Click mode teaches the identical loop and closing gesture.
	game.new_journey("wanderer")
	run.begin_encounter()
	game.click_mode = true
	await refresh()
	for id in run.Lesson.SMALL + [run.Lesson.SMALL[0]]:
		mouse(run.board.anchors[id],true)
		mouse(run.board.anchors[id],false)
	key(KEY_ENTER)
	expect(run.lesson_step == 1 and run.biomass == 3, "Click input completes the same lesson without requiring a drag")
	game.return_home()
	game.resume_journey()
	expect(run.state == Run.PAUSED and run.lesson_step == 1, "Return home and Continue preserve the unfinished lesson")
	var rng := RandomNumberGenerator.new()
	for i in 20:
		var offers: Array = run.Mutations.journey_offers(["fission"],rng,false)
		expect(not offers.has("symbiosis") and not offers.has("enzyme") and not offers.has("residual"), "Defense upgrades wait until the defense encounter is taught")
	game.queue_free()
	await process_frame
	print("ONBOARDING: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
