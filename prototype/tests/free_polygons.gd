extends "res://tests/harvest_visual.gd"
const Save = preload("res://scripts/journey_save.gd")

func click_cell(id: int) -> void:
	mouse(game.run.board.anchors[id], true)
	mouse(game.run.board.anchors[id], false)

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-free-polygons-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-free-polygons-profile-unused.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	var run = game.run
	run.stage_index = 1
	run.start_stage()
	run.begin_encounter()
	run.enemies.clear()
	var path := [0,17,9]
	var center := Vector2.ZERO
	for id in path:
		center += run.board.anchors[id]/3.0
	run.enemies.append(run.Harvest.Organism.new(500,"food",center,Vector2.ZERO,0.0))
	await refresh()
	expect(not run.board.neighbors[0].has(17), "Fixture crosses an edge absent from the old network")
	mouse(run.board.anchors[0],true)
	drag(run.board.anchors[0],run.board.anchors[17])
	expect(run.selection.path == [0,17], "Native drag directly connects previously unlinked cells")
	drag(run.board.anchors[17],run.board.anchors[9])
	expect(run.selection.path == path and run.preview() == [500], "Free polygon highlights its real capture target")
	drag(run.board.anchors[9],run.board.anchors[0])
	await capture("free-polygon-preview")
	expect(run.selection.closed, "Native drag closes a polygon across the old network")
	mouse(run.board.anchors[0],false)
	expect(run.biomass == 1 and run.enemies.is_empty() and not run.is_ready(17), "Release captures and starts digestion on the actual chosen cells")
	var saved := Save.capture(run)
	var restored := Run.new(true,73,true,true)
	expect(Save.restore(restored,saved) and not restored.is_ready(17) and restored.clots[0].nodes == path, "A free-edge capture survives saving and resuming during recovery")
	restored.dispose()
	run.step(0.9)
	await capture("free-polygon-digestion")
	run.step(2.2)
	expect(run.is_ready(17), "Free-connected cells return on the unchanged recovery clock")
	# Click input can make very long edges without pointer-hit intermediates.
	game.click_mode = true
	for id in [16,19,17,16]:
		click_cell(id)
	expect(run.selection.closed and run.selection.path == [16,19,17], "Click input accepts long edges that keep Mother outside")
	key(KEY_ESCAPE)
	for id in [16,20,18]:
		click_cell(id)
	click_cell(22)
	expect(run.selection.path == [16,20,18] and run.selection.rejection_reason.contains("cross"), "Crossing edges remain blocked through real input")
	key(KEY_ESCAPE)
	run.cells[17].spend(1)
	click_cell(0)
	click_cell(17)
	expect(run.selection.path == [0] and game.JourneyHud.Guidance.next_action(run).title == "Cell is digesting", "Recovery blocks any connection with an understandable explanation")
	key(KEY_ESCAPE)
	run.cells[17].remaining = 0
	# Free choices are computed from live positions, including resumed drift.
	run.step(5.0)
	click_cell(0)
	expect(run.selection.legal_next().size() == 23, "All other ready cells remain connectable after independent drift")
	key(KEY_ESCAPE)
	game.queue_free()
	await process_frame
	print("FREE POLYGONS: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
