extends SceneTree
const Main = preload("res://scripts/main.gd")
const Run = preload("res://scripts/run_controller.gd")
const Drifter = preload("res://scripts/drifter.gd")
var game: Node2D
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("exercise")
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)
func refresh() -> void:
	game._process(0.0)
	await process_frame
	await process_frame
func capture(name: String) -> void:
	await refresh()
	RenderingServer.force_draw(false)
	if DisplayServer.get_name() != "headless":
		expect(root.get_texture().get_image().save_png("res://artifacts/" + name + ".png") == OK, "Saved " + name)
func mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
func drag(from: Vector2, to: Vector2) -> void:
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
func exercise() -> void:
	game = Main.new()
	game.run.dispose()
	game.run = Run.new(false, 73, true)
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	await capture("harvest-live-dish")
	expect(game.microscope.enemies.size() == 21, "All initial organisms have native sprites")
	var food = game.run.enemies[0]
	var sprite: Sprite2D = game.microscope.enemies[food.id].get_meta("lobes")[0]
	expect(sprite.texture == game.microscope.FOOD and sprite.material.get_shader_parameter("kind") == 6.0, "Food has distinct art and motion")
	var position: Vector2 = food.nucleus
	game.run.step(2.0)
	game.visual_time += 2.0
	await refresh()
	expect(position != food.nucleus and game.microscope.enemies[food.id].position == food.nucleus, "Rendered current tracks actual moving capture center")
	# One representative contaminated meal, through real window mouse events.
	game.run.enemies.clear()
	var path: Array = [0,1,9]
	var b = game.run.board
	var center: Vector2 = (b.anchors[0] + b.anchors[1] + b.anchors[9]) / 3.0
	for i in 3:
		game.run.enemies.append(Drifter.new(100+i, center + Vector2((i-1)*20, 0), 0.0, "cyst" if i == 2 else "food"))
	await refresh()
	mouse(b.anchors[0],true)
	var previous: Vector2 = b.anchors[0]
	for id in [1,9,0]:
		drag(previous,b.anchors[id])
		previous = b.anchors[id]
	await capture("harvest-risk-preview")
	expect(game.run.selection.closed, "Actual mouse input closes harvest loop")
	expect(game.run.harvest_preview().food == 2 and game.run.harvest_preview().poison == 1, "Native preview shows meal and poison")
	expect(game.microscope.preview.material.get_shader_parameter("poison") == 1.0, "Contaminated membrane changes appearance")
	mouse(b.anchors[0],false)
	game.run.step(1.05)
	game.visual_time += 1.05
	await capture("harvest-feeding")
	expect(game.run.harvest.nourishment == 2 and game.run.integrity == 4, "Mouse release feeds and poisons as previewed")
	expect(game.microscope.harvest_flow.visible and game.microscope.mother.material.get_shader_parameter("nourishment") > 0, "Meal feeds a visible mother reservoir")
	expect(game.microscope.pulses[0].get_meta("ghosts")[0].texture == game.microscope.FOOD, "Digestion keeps food anatomy")
	expect(not game.microscope.invaders.values()[0].visible, "Poison uses current and wound, not a duplicate remote invader")
	key(KEY_SPACE)
	var before: float = game.run.elapsed
	game.run.step(5.0)
	expect(game.run.elapsed == before, "Pause key freezes harvest")
	key(KEY_SPACE)
	key(KEY_V)
	expect(game.settings_open and game.run.state == Run.PAUSED, "Sound settings safely pause the experiment")
	key(KEY_V)
	game.large_text = true
	await capture("harvest-large-text")
	key(KEY_R)
	await refresh()
	expect(game.run.harvest.nourishment == 0 and game.run.integrity == 5 and game.microscope.invaders.is_empty(), "Restart clears visible wounds and nourishment")
	game.run.harvest.nourishment = game.run.Harvest.GOAL
	game.run.check_completion()
	await capture("harvest-result")
	expect(game.hud.center_button.visible and game.run.state == Run.SUCCESS, "Success presents direct replay")
	mouse(Vector2(640,534),true)
	mouse(Vector2(640,534),false)
	await refresh()
	expect(game.run.state == Run.ACTIVE and game.run.elapsed == 0, "Result button starts another harvest")
	game.queue_free()
	await process_frame
	print("HARVEST VISUAL: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
