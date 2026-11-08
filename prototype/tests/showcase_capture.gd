extends SceneTree
## Native screenshots of every major screen for visual review.
## godot --path . --script res://tests/showcase_capture.gd -- --out=/absolute/dir [--light]
## Uses temporary save files; never reads or writes the player's journey.
const Main = preload("res://scripts/main.gd")
const Run = preload("res://scripts/run_controller.gd")
var game: Node2D
var out := "res://artifacts/showcase"
var shots := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out if out.is_absolute_path() else ProjectSettings.globalize_path(out))
	call_deferred("exercise")

func advance(seconds: float, steps: int = 0) -> void:
	# Real frames, so shaders, tweens and presentation clocks all move.
	var count := steps if steps > 0 else maxi(1, int(seconds * 30.0))
	for i in count:
		if game.run.state == Run.ACTIVE:
			game.run.step(seconds / count)
		game._process(seconds / count)
		# Explicit drawing keeps captures reliable when the window is covered.
		RenderingServer.force_draw(false)
		await process_frame

func capture(name: String) -> void:
	# Real frames only: a zero-length refresh would finish every entrance.
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	var path := out.path_join("%02d-%s.png" % [shots, name])
	shots += 1
	root.get_texture().get_image().save_png(path)
	print("SHOT ", path)

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

## A clean two-food capture on any ready triangle, as a player would draw it.
func quick_capture(run: RefCounted, used: Array) -> void:
	for triangle in run.board.triangles:
		if triangle.all(func(id): return run.is_ready(id) and not used.has(id)):
			used.append_array(triangle)
			var center: Vector2 = (run.board.anchors[triangle[0]] + run.board.anchors[triangle[1]] + run.board.anchors[triangle[2]]) / 3.0
			for i in 2:
				run.next_enemy_id += 1
				run.enemies.append(run.Harvest.Organism.new(run.next_enemy_id, "food", center + Vector2(i * 8.0 - 4.0, 0), Vector2.ZERO, 0.0))
			run.selection.start(run.board.anchors[triangle[0]])
			run.selection.visit(triangle[1])
			run.selection.visit(triangle[2])
			run.selection.visit(triangle[0])
			run.release()
			return

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)

func exercise() -> void:
	for file in ["/tmp/petriverse-showcase-journey.cfg", "/tmp/petriverse-showcase-profile.cfg"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/petriverse-showcase-journey.cfg"
	game.journey_profile.path = "/tmp/petriverse-showcase-profile.cfg"
	if "--light" in OS.get_cmdline_user_args():
		game.visual_quality = 0
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280, 900)
	RenderingServer.render_loop_enabled = false
	await advance(0.5)
	await capture("title-intro-0.5s")
	await advance(0.7)
	await capture("title-intro-1.2s")
	await advance(2.0)
	await capture("title")
	game.request_new_journey("wanderer")
	await advance(0.6)
	await capture("brief")
	key(KEY_ENTER)
	await advance(1.5)
	await capture("lesson")
	var run = game.run
	# Draw the lesson loop partway, then capture it with real input.
	var path: Array = run.Lesson.SMALL
	mouse(run.board.anchors[path[0]], true)
	var previous: Vector2 = run.board.anchors[path[0]]
	for id in path.slice(1):
		drag(previous, run.board.anchors[id])
		previous = run.board.anchors[id]
	await advance(0.3)
	await capture("drawing")
	drag(previous, run.board.anchors[path[0]])
	previous = run.board.anchors[path[0]]
	await advance(0.1)
	await capture("closed")
	mouse(previous, false)
	await advance(0.25, 8)
	await capture("capture-0.25s")
	await advance(0.6, 18)
	await capture("capture-0.85s")
	await advance(2.5)
	for stage in [1, 5, 7, 9, 11]:
		run.stage_index = stage
		run.start_stage()
		game.reset_presentation()
		await advance(0.4)
		if stage == 5:
			await capture("brief-stage-%02d" % stage)
		run.begin_encounter()
		await advance(0.9)
		await capture("card-stage-%02d" % stage)
		await advance(5.1)
		await capture("stage-%02d" % stage)
		if stage == 1:
			var used: Array = []
			# A clean chain for the flow readout: no poison anywhere near.
			run.enemies = run.enemies.filter(func(body): return body.kind == "food")
			quick_capture(run, used)
			await advance(0.8)
			quick_capture(run, used)
			await advance(0.5, 12)
			await capture("flow-chain")
	# Pause menu.
	game.pause()
	await advance(0.1, 3)
	await capture("pause-entering")
	await advance(0.6)
	await capture("pause")
	game.pause()
	await advance(0.3)
	# Mother damage: a lethal-ish state for the danger presentation.
	run.integrity = 1
	await advance(1.0)
	await capture("low-health")
	# Loss.
	run.state = Run.LOSS
	run.harvest.loss_title = "The mother was eaten."
	run.harvest.loss_reason = "A hunter reached the mother."
	await advance(0.5)
	await capture("loss-reveal")
	await advance(3.2)
	await capture("loss")
	# Evolution.
	run.stage_index = 4
	run.start_stage()
	game.reset_presentation()
	run.begin_encounter()
	run.biomass = 20
	run.harvest.nourishment = run.harvest.spec.food
	await advance(2.0)
	await capture("pre-evolution")
	await advance(4.0)
	await capture("evolution")
	# Hover the first evolution card with a real pointer event.
	if game.hud.cards[0].visible:
		var hover := InputEventMouseMotion.new()
		hover.position = game.hud.cards[0].get_global_rect().get_center()
		root.push_input(hover, true)
		await advance(0.5)
		await capture("evolution-hover")
		game.choose_evolution(0)
		await advance(1.6)
		await capture("evolution-reveal")
		await advance(2.5)
		await capture("evolution-reveal-grown")
		game.evolution_reveal.dismiss()
		await advance(0.4)
	# Real boss encounters from the route plan, including the open window.
	for position in run.route_plan.size():
		if run.route_plan[position].mode != "boss":
			continue
		run.route_position = position
		run.stage_index = int(run.route_plan[position].stage)
		run.start_stage()
		game.reset_presentation()
		game.feel.last_card_dish = Run.JourneyPlan.dish(run.stage_index).name
		run.begin_encounter()
		await advance(1.0)
		await capture("boss-card-%02d" % run.stage_index)
		run.harvest.nourishment = 6
		for i in 30:
			await advance(0.5, 4)
			if game.feel.boss_open:
				break
		await advance(0.4)
		await capture("boss-window-%02d" % run.stage_index)
	# The end of a journey: the final boss falls.
	run.route_position = run.route_plan.size() - 1
	run.stage_index = int(run.route_plan[run.route_position].stage)
	run.start_stage()
	game.reset_presentation()
	run.begin_encounter()
	await advance(0.5)
	run.stage_elapsed = 120.0
	run.finish_journey_stage()
	await advance(1.2)
	await capture("victory-reveal")
	await advance(3.0)
	await capture("epilogue")
	game.return_home()
	await advance(1.5)
	await capture("home-pond")
	game.toggle_home_pond()
	await advance(1.0)
	await capture("title-returning")
	game.toggle_help()
	await advance(0.5)
	await capture("help")
	game.toggle_help()
	game.toggle_journal()
	await advance(0.5)
	await capture("journal")
	game.toggle_journal()
	# Comfort layout: larger text reflows the dish to two thirds scale.
	game.large_text = true
	run.route_position = 2
	run.stage_index = int(run.route_plan[2].stage)
	run.start_stage()
	game.reset_presentation()
	await advance(0.6)
	await capture("comfort-brief")
	run.begin_encounter()
	await advance(4.0)
	var used: Array = []
	for triangle in run.board.triangles:
		if triangle.all(func(id): return run.is_ready(id)):
			used = triangle
			break
	if not used.is_empty():
		var center: Vector2 = (run.board.anchors[used[0]] + run.board.anchors[used[1]] + run.board.anchors[used[2]]) / 3.0
		run.enemies.append(run.Harvest.Organism.new(9000, "food", center, Vector2.ZERO, 0.0))
		run.enemies.append(run.Harvest.Organism.new(9001, "food", center + Vector2(8, 0), Vector2.ZERO, 0.0))
		run.selection.start(run.board.anchors[used[0]])
		run.selection.visit(used[1])
		run.selection.visit(used[2])
		run.selection.visit(used[0])
		run.release()
	await advance(0.3, 9)
	await capture("comfort-capture")
	game.large_text = false
	game.queue_free()
	await process_frame
	quit()
