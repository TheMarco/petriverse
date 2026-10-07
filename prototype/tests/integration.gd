extends SceneTree
## Engine-level input, HUD, resize and render checks. Native runs also save PNGs.

const Main = preload("res://scripts/main.gd")
const Drifter = preload("res://scripts/drifter.gd")
var game: Node2D
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("exercise")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func mouse_button(at: Vector2, pressed: bool, which: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = which
	event.pressed = pressed
	root.push_input(event, true)

func motion(from: Vector2, to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.relative = to - from
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)

func refresh() -> void:
	game._process(0.0)
	await process_frame
	await process_frame

func capture(filename: String) -> void:
	await refresh()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output := "res://artifacts/" + filename + ".png"
		expect(root.get_texture().get_image().save_png(output) == OK, "Saved " + filename)
		# Resume scene mutations on the main frame, outside the render callback.
		await process_frame

func exercise() -> void:
	game = Main.new()
	game.save_records = false
	game.preferences_enabled = false
	game.run.journey = false # This fixture exercises the isolated enclosure rules.
	game.run.harvest_mode = false
	game.run.full_run = false
	game.run.restart()
	# Desktop focus changes must not interrupt injected input between captures.
	# Restore the production default for the dedicated focus-loss assertion.
	var normal_focus_policy: bool = game.pause_on_focus_loss
	game.pause_on_focus_loss = false
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await refresh()
	var board = game.run.board
	# Real Window transforms, not a reimplementation of the scaling formula.
	for dimensions in [Vector2i(1280, 900), Vector2i(1920, 1080), Vector2i(900, 900)]:
		root.size = dimensions
		await refresh()
		var transform := root.get_final_transform()
		print("VIEWPORT ", dimensions, ": ", transform)
		# Godot rounds the letterboxed viewport to integer physical pixels.
		expect(absf(transform.x.length() - transform.y.length()) * 900.0 < 1.0, "Uniform scale within one raster pixel at %s" % dimensions)
		for id in [0, 9, 17, 23]:
			var screen: Vector2 = transform * board.anchors[id]
			var logical: Vector2 = transform.affine_inverse() * screen
			expect(board.hit_test(logical) == id, "Stable logical hit %d at %s" % [id, dimensions])
		if dimensions.x == 1920:
			expect(transform.origin.x > 0, "Wide window letterboxes horizontally")
		if dimensions == Vector2i(900, 900):
			expect(transform.origin.y > 0, "Square window letterboxes vertically")
	root.size = Vector2i(1280, 900)
	await refresh()
	game.run.enemies = [Drifter.new(1, (board.anchors[0] + board.anchors[8] + board.anchors[9]) / 3.0, 19), Drifter.new(2, Vector2(870, 600), 19)]
	game.run.encounter.spawned = 2
	await capture("01-dish")
	# Inject through the viewport so Control consumption and _unhandled_input run.
	mouse_button(board.anchors[0], true)
	motion(board.anchors[0], board.anchors[8])
	motion(board.anchors[8], board.anchors[9])
	expect(game.run.selection.path == [0, 8, 9] and not game.run.selection.closed, "Viewport mouse events select three cells")
	expect(game.run.preview() == [1], "Prospective loop previews target")
	motion(board.anchors[9], board.anchors[0])
	expect(game.run.selection.closed, "Viewport motion closes loop")
	await capture("02-capture-preview")
	mouse_button(board.anchors[0], false)
	expect(game.run.score == 100 and game.run.enemies.size() == 1 and not game.run.is_ready(0), "Viewport release captures immediately")
	game.run.step(1.5)
	game._process(0.2)
	await capture("03-recovery")
	key(KEY_SPACE)
	await refresh()
	expect(game.run.state == "paused" and game.hud.center_button.visible, "Pause key displays resume overlay")
	var remaining: float = game.run.cells[0].remaining
	game.run.step(9)
	expect(game.run.cells[0].remaining == remaining, "Pause keeps recovery frozen")
	# Real Control click: the overlay button must consume it and resume.
	mouse_button(Vector2(640, 534), true)
	mouse_button(Vector2(640, 534), false)
	expect(game.run.state == "active" and not game.run.selection.active, "Resume button works without selecting")
	key(KEY_R)
	expect(game.run.score == 0 and game.effects.is_empty() and game.toast_time == 0, "Restart clears visual and logical state")
	key(KEY_C)
	for id in [0, 8, 9, 0]:
		mouse_button(board.anchors[id], true)
		mouse_button(board.anchors[id], false)
	expect(game.run.selection.closed and game.run.is_ready(0), "Click mode waits for explicit commit")
	key(KEY_ENTER)
	expect(not game.run.is_ready(0), "Click mode Enter commits")
	game.restart()
	key(KEY_C)
	mouse_button(board.anchors[0], true)
	motion(board.anchors[0], board.anchors[8])
	key(KEY_ESCAPE)
	mouse_button(board.anchors[8], false)
	expect(game.run.is_ready(0) and game.run.is_ready(8), "Escape cancels without spending")
	mouse_button(board.anchors[0], true)
	motion(board.anchors[0], board.anchors[8])
	game.pause_on_focus_loss = normal_focus_policy
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.run.state == "paused" and not game.run.selection.active and game.run.is_ready(0), "Losing focus pauses and safely cancels the live gesture")
	game.pause_on_focus_loss = false
	key(KEY_SPACE)
	mouse_button(board.anchors[0], true)
	motion(board.anchors[0], board.anchors[8])
	mouse_button(board.anchors[8], true, MOUSE_BUTTON_RIGHT)
	mouse_button(board.anchors[8], false)
	expect(game.run.is_ready(0) and not game.run.selection.active, "Right-click cancels without spending")
	key(KEY_D)
	expect(game.debug_mode, "Debug key shows inspection overlay")
	await capture("04-inspection")
	key(KEY_D)
	game.run.integrity = 1
	game.run.enemies = [Drifter.new(1, board.center, 19)]
	game.run.step(1.0 / 60)
	await refresh()
	expect(game.run.state == "loss" and not game.hud.center_button.visible, "Fatal bite stays visible before the loss panel")
	game.run.step(2.3)
	await capture("05-loss")
	expect(game.run.state == "loss" and game.hud.center_button.visible, "Loss and restart control render")
	mouse_button(Vector2(640, 534), true)
	mouse_button(Vector2(640, 534), false)
	expect(game.run.state == "active" and game.run.integrity == 5, "End-state button restarts")
	game.run.encounter.spawned = 20
	game.run.encounter.resolved = 20
	game.run.score = 2000
	game.run.kills = 20
	game.run.check_completion()
	await capture("06-success")
	expect(game.run.state == "success" and game.hud.center_button.visible, "Success and restart control render")
	print("INTEGRATION: %d checks; %d failures; display=%s" % [checks, failures.size(), DisplayServer.get_name()])
	game.queue_free()
	await process_frame
	# Give the audio mixer one real buffer interval to retire Ogg playback.
	await create_timer(0.1).timeout
	quit(0 if failures.is_empty() else 1)
