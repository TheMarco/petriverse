extends "res://tests/harvest_visual.gd"
const Feedback = preload("res://scripts/capture_feedback.gd")

func screen_point(point: Vector2) -> Vector2:
	return point * game.dish_scale() + game.dish_offset()

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/petriverse-confidence.cfg"
	game.journey_profile.path = "/tmp/petriverse-confidence-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.size = Vector2i(1280,900)
	game.new_journey("wanderer")
	game.run.begin_encounter()
	var run = game.run
	for id in run.Lesson.SMALL:
		if run.selection.active: run.selection.visit(id)
		else: run.selection.start(run.board.anchors[id])
	run.selection.visit(run.Lesson.SMALL[0])
	game.capture_feedback.observe(run, 0.0)
	expect(game.capture_feedback.outcome.poison == 0, "Clean preview uses real enclosed organisms")
	var center: Vector2 = Vector2.ZERO
	for id in run.Lesson.SMALL: center += run.board.anchors[id] / 3.0
	var cyst = run.Harvest.Organism.new(999,"cyst",center,Vector2.ZERO,0.0)
	run.enemies.append(cyst)
	game.capture_feedback.observe(run, 0.0)
	expect(game.capture_feedback.warning_serial == 1 and game.capture_feedback.warning_remaining > 0, "Poison entering an unchanged loop creates a new warning")
	game.capture_feedback.observe(run, 0.1)
	expect(game.capture_feedback.warning_serial == 1, "Persistent poison does not retrigger sound every frame")
	expect(Feedback.health_text(game.capture_feedback.outcome,run.integrity).contains("2 remaining"), "Preview explains health after release")
	var before: int = run.integrity
	game.commit_selection()
	expect(run.integrity == before-1 and run.last_capture.poison == 1, "Committed damage matches current preview")
	var mixed := {"food":3,"poison":1,"rescued":1,"threats":2,"wardens":1}
	var description := Feedback.summary(mixed)
	expect(description.contains("3 food") and description.contains("1 rescued") and description.contains("2 threats") and description.contains("1 shields"), "Mixed captures retain every useful outcome")
	game.new_journey("wanderer")
	run.begin_encounter()
	for id in run.Lesson.SMALL:
		if run.selection.active: run.selection.visit(id)
		else: run.selection.start(run.board.anchors[id])
	var near: Vector2 = run.board.anchors[run.Lesson.SMALL[0]] + Vector2(35,0)
	expect(not run.selection.close_near_start(near), "Precise mode requires normal closure")
	run.selection.assisted_closure = true
	expect(run.selection.close_near_start(near) and run.selection.closed, "Opt-in assistance closes a valid loop just outside the hit circle")
	key(KEY_ESCAPE)
	expect(not run.selection.active and run.state == Run.ACTIVE and run.cells.all(func(c): return c.is_ready()), "Escape cancels an active gesture for free")
	key(KEY_ESCAPE)
	expect(run.state == Run.PAUSED, "Escape pauses when no gesture is active")
	key(KEY_ESCAPE)
	expect(run.state == Run.ACTIVE, "Escape resumes a paused encounter")
	run.selection.start(run.board.anchors[0])
	run.selection.visit(8)
	expect(not run.selection.close_near_start(run.board.anchors[0]), "Assistance cannot close a two-cell path")
	run.selection.cancel()
	root.size = Vector2i(768,540)
	game._process(0.0)
	await process_frame
	expect(game.comfort_layout() and game.readable_ui.screen.visible and not game.hud.pause_button.visible, "Small window uses the reflowed native HUD")
	for id in run.Lesson.SMALL + [run.Lesson.SMALL[0]]:
		game.click_mode = true
		mouse(screen_point(run.board.anchors[id]),true)
		mouse(screen_point(run.board.anchors[id]),false)
	key(KEY_ENTER)
	expect(run.lesson_step==1 and run.biomass==3, "Reflowed dish maps real pointer input to the same capture")
	game.return_home()
	var snapshot: Dictionary = game.resume_data.duplicate(true)
	game.request_new_journey("wanderer")
	expect(game.pending_new_colony=="wanderer" and game.resume_data==snapshot, "New journey asks before replacing unfinished progress")
	game._process(0.0)
	expect(game.readable_ui.screen_key()=="confirm" and game.readable_ui.controls.size()==2, "Small windows ask in the reflowed layout")
	key(KEY_ESCAPE)
	expect(game.pending_new_colony.is_empty() and game.resume_data==snapshot, "Escape keeps the unfinished journey")
	game.toggle_sound_settings()
	game._process(0.0)
	await process_frame
	expect(game.readable_ui.controls.all(func(c): return c.focus_mode==Control.FOCUS_ALL), "Comfort controls support keyboard focus")
	game.queue_free()
	await process_frame
	print("CAPTURE CONFIDENCE: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
