extends SceneTree
## Deterministic eight-second live-material/capture reel and visual-state checks.
# Movie capture must survive the user switching windows. Production focus-pause
# remains covered by integration.gd; only this deterministic fixture ignores it.
class MovieScene:
	extends "res://scripts/main.gd"
	func _init() -> void:
		# Godot dispatches _notification to every script in the inheritance chain;
		# overriding it cannot suppress Main's handler. Opt out explicitly here.
		pause_on_focus_loss = false
const Drifter = preload("res://scripts/drifter.gd")
var game: Node2D
var frame_number := 0
var checks := 0
var failures := 0
var pond_initial_pose: Transform2D
var suspension_initial_pose: Transform2D
var extended_reel := false

func _initialize() -> void:
	call_deferred("setup")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)

func setup() -> void:
	# All gestures below are scripted. GUI input could otherwise activate a HUD
	# button while the user works in another app during a native recording.
	root.gui_disable_input = true
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = MovieScene.new()
	game.save_records = false
	game.preferences_enabled = false
	game.audio_enabled = false
	game.run.journey = false # This fixture exercises the isolated enclosure rules.
	game.run.harvest_mode = false
	game.run.full_run = false
	game.run.restart()
	if game == null or game.run == null:
		printerr("FAIL: Scene dependencies failed to load")
		quit(1)
		return
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	# Desktop pointer motion must not modify this scripted movie gesture.
	game.set_process_unhandled_input(false)
	if DisplayServer.get_name() != "headless":
		# macOS can stop automatic redraws when this fixture is covered by another
		# window, while MovieMaker still writes stale frames. Draw explicitly only
		# in this capture fixture; normal gameplay keeps the engine render loop.
		RenderingServer.render_loop_enabled = false
	var board = game.run.board
	game.run.enemies = [Drifter.new(1, (board.anchors[0] + board.anchors[8] + board.anchors[9] + board.anchors[1]) / 4.0, 6), Drifter.new(2, Vector2(875, 590), 6)]
	game.run.encounter.spawned = 2
	game.run.encounter.next_spawn = 12.0
	expect(game.microscope.cells.size() == 24, "All cells have a visual")
	pond_initial_pose = game.microscope.pond.specimens[0].transform
	suspension_initial_pose = game.microscope.pond.suspension.multimesh.get_instance_transform_2d(0)
	expect(game.microscope.pond.specimens.size() == 46 and game.microscope.pond.suspension.multimesh.instance_count == 264, "The brightfield pond has drifting specimens and a full suspension layer")
	var small_specimens := true
	for specimen in game.microscope.pond.specimens:
		small_specimens = small_specimens and specimen.scale.x * specimen.get_rect().size.x <= 44.01
	expect(small_specimens, "Every ambient specimen stays below 44 pixels including transparent margins")
	var species := {}
	for specimen in game.microscope.pond.specimens:
		species[specimen.frame] = true
	expect(species.size() == 4, "Four photographic forms replace repeated fantasy amoeba silhouettes")
	expect(game.microscope.field.material.get_shader_parameter("pond_plate") != null, "The water field uses the photographic microscopy plate")
	expect(game.microscope.pond.z_index < 0 and game.microscope.pond.specimens[0].z_index < 0, "Ambient organisms stay behind gameplay tissue")
	for i in 24:
		expect(game.microscope.cells[i].position == board.anchors[i], "Visual cell %d matches its live node" % i)

func _process(_delta: float) -> bool:
	if game == null or game.run == null:
		return false
	if DisplayServer.get_name() != "headless":
		# Deferred behind CanvasItem redraw notifications, so HUD and tissue have
		# both submitted their current commands before the movie frame is drawn.
		call_deferred("draw_recording_frame")
	frame_number += 1
	# Fixed simulated time is used only for the reproducible movie, never gameplay.
	game.run.state = "active"
	game.run.step(1.0 / 60.0)
	game._process(1.0 / 60.0)
	var board = game.run.board
	# The long reel shares the same gesture and extends only the quiet tail.
	if extended_reel and frame_number > 450:
		if frame_number == 1200:
			print("DRIFT REVIEW: %d checks; %d failures; 20 seconds" % [checks, failures])
			game.queue_free()
			quit(0 if failures == 0 else 1)
		return false
	match frame_number:
		60:
			expect(game.microscope.pond.specimens[0].transform != pond_initial_pose, "Pond organisms translate and tumble with time")
			expect(game.microscope.pond.suspension.multimesh.get_instance_transform_2d(0) == suspension_initial_pose, "Suspended particles animate without CPU transform uploads")
			game.run.selection.start(board.anchors[0])
		61:
			game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			expect(game.run.state == "active" and game.run.selection.path == [0], "Desktop focus changes cannot cancel the scripted movie gesture")
		90: game.run.selection.drag(board.anchors[0], board.anchors[8])
		120: game.run.selection.drag(board.anchors[8], board.anchors[9])
		140: game.run.selection.drag(board.anchors[9], board.anchors[1])
		150: game.run.selection.drag(board.anchors[1], board.anchors[0])
		180:
			expect(game.run.preview() == [1], "Rendered preview matches nucleus target")
			game.commit_selection()
			expect(game.run.score == 100, "Logical capture remains immediate")
		181:
			expect(not game.microscope.enemies.has(1), "Captured organism removed from renderer")
			expect(not game.run.is_ready(0), "Recovery starts after capture")
			expect(game.run.clot_for(0) != null, "Captured cells enter a recovery clot")
		200:
			expect(game.microscope.pulses.size() == 1 and game.microscope.pulses[0].get_meta("ghosts").size() == 1, "Captured tissue persists only as one digestive visual")
			var effect_age: float = game.effects[0].age
			var ghost: Sprite2D = game.microscope.pulses[0].get_meta("ghosts")[0]
			var ghost_pose := ghost.transform
			game.pause()
			game._process(0.6)
			expect(game.effects[0].age == effect_age and ghost.transform == ghost_pose, "Pause freezes digestion")
			game.pause()
		260:
			expect(game.microscope.mother.material.get_shader_parameter("feeding") > 0.0, "Digestion nourishes the mother visually")
			var surface: ColorRect = game.microscope.pulses[0].get_meta("surface")
			var skins_hidden := true
			for id in game.effects[0].nodes:
				skins_hidden = skins_hidden and is_zero_approx(game.microscope.cells[id].modulate.a)
			expect(skins_hidden and surface.visible and surface.material.get_shader_parameter("opacity") == 1.0, "One shared body completely replaces the individual cell membranes")
			expect(surface.material.get_shader_parameter("member_count") == 4, "All four captured cells contribute to the fused body")
			expect(not game.microscope.pulses[0] is Polygon2D, "Recovery has no temporary polygon film or outline")
			var ghost: Sprite2D = game.microscope.pulses[0].get_meta("ghosts")[0]
			expect(ghost.material.get_shader_parameter("dissolve") > 0.0, "Prey erodes inside the fused body")
		360:
			expect(game.run.is_ready(0), "Recovery still completes at three seconds")
			expect(is_equal_approx(game.microscope.cells[0].material.get_shader_parameter("energy"), 1.0), "Recovered tissue returns to full brightness")
			expect(game.microscope.pulses.is_empty(), "Digested tissue is removed when the effect completes")
			var anchored := true
			for i in 24:
				anchored = anchored and game.microscope.cells[i].position == board.anchors[i]
			expect(anchored, "All sprites follow the live nodes through capture and recovery")
			expect(game.microscope.cells[0].modulate.a == 1.0 and game.microscope.cells[1].modulate.a == 1.0, "Separate skins are restored when the cells return")
			expect(game.microscope.enemies[2].position == game.run.enemies[0].nucleus, "Swimming keeps the visible nucleus at the logical target")
		400:
			var pond_pose: Transform2D = game.microscope.pond.specimens[0].transform
			var pond_clock: float = game.microscope.pond.suspension.material.get_shader_parameter("clock")
			var field_clock: float = game.microscope.field.material.get_shader_parameter("clock")
			var body_rotation: float = game.microscope.cells[0].rotation
			var cilia_clock: float = game.microscope.mother.get_node("Life").clock
			var before: float = game.visual_time
			game.pause()
			game._process(2.0)
			expect(game.visual_time == before, "Pause freezes visual clock")
			expect(is_equal_approx(game.microscope.mother.material.get_shader_parameter("clock"), before), "Pause freezes tissue shader")
			expect(game.microscope.field.material.get_shader_parameter("clock") == field_clock, "Pause freezes the photographic water layer")
			expect(game.microscope.cells[0].rotation == body_rotation, "Pause freezes tissue orientation")
			expect(game.microscope.mother.get_node("Life").clock == cilia_clock, "Pause freezes cilia and granules")
			expect(game.microscope.pond.specimens[0].transform == pond_pose and game.microscope.pond.suspension.material.get_shader_parameter("clock") == pond_clock, "Pause freezes pond organisms and every suspended particle")
			game.pause()
		420:
			game.toggle_motion()
			game._process(0.0)
			expect(game.microscope.mother.material.get_shader_parameter("motion") == 0.0, "Reduced motion disables tissue motion")
			expect(game.microscope.field.material.get_shader_parameter("motion") == 0.0, "Reduced motion disables background motion")
			expect(game.microscope.mother.get_node("Life").movement == 0.0, "Reduced motion stops cilia and granules")
			var pond_pose: Transform2D = game.microscope.pond.specimens[0].transform
			var body_pose: Transform2D = game.microscope.enemies[2].transform
			game._process(0.25)
			expect(game.microscope.field.material.get_shader_parameter("motion") == 0.0 and game.microscope.enemies[2].transform == body_pose, "Reduced motion stops photographic water flow and swimming sway")
			expect(game.microscope.pond.specimens[0].transform == pond_pose and game.microscope.pond.suspension.material.get_shader_parameter("motion") == 0.0 and game.microscope.pond.specimens[0].material.get_shader_parameter("motion") == 0.0, "Reduced motion freezes the whole ambient ecosystem")
		450:
			game.toggle_motion()
		460:
			# Overlap actual captures, with the first near the end of its recovery.
			game.run.enemies = [Drifter.new(101, (board.anchors[0] + board.anchors[8] + board.anchors[9]) / 3.0, 0.0)]
			capture_path([0, 8, 9])
			game.run.step(2.9)
			var at: Vector2 = (board.anchors[3] + board.anchors[11] + board.anchors[12]) / 3.0
			game.run.enemies = [Drifter.new(102, at, 0.0), Drifter.new(103, at + Vector2(4, 0), 0.0)]
			capture_path([3, 11, 12])
			game._process(0.0)
		467:
			expect(game.microscope.pulses.size() == 1 and game.microscope.pulses[0].get_meta("serial") == game.run.capture_serial, "Overlapping captures retain the correct later clot")
			expect(game.microscope.pulses[0].get_meta("ghosts").size() == 2, "Overlapping clot retains both of its own prey")
			game.toggle_motion()
			game._process(0.0)
			expect(not game.microscope.pulses[0].get_meta("surface").visible and game.microscope.cells[3].modulate.a == 1.0, "Reduced motion hides fusion and keeps the individual cells visible")
			game.toggle_motion()
		480:
			game.restart()
			game._process(0.0)
			expect(game.microscope.enemies.is_empty() and game.microscope.pulses.is_empty(), "Restart clears old visual organisms and pulses")
			expect(game.microscope.pond.specimens[0].transform == pond_initial_pose and game.microscope.pond.clock == 0.0, "Restart deterministically resets pond currents")
			print("VISUAL MOTION: %d checks; %d failures" % [checks, failures])
			game.queue_free()
			quit(0 if failures == 0 else 1)
	return false

func draw_recording_frame() -> void:
	RenderingServer.force_draw(false, 1.0 / 60.0)

func capture_path(ids: Array) -> void:
	game.run.selection.start(game.run.board.anchors[ids[0]])
	for id in ids.slice(1):
		game.run.selection.visit(id)
	game.run.selection.visit(ids[0])
	game.commit_selection()
