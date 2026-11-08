extends SceneTree
## A short scripted session for review, recorded with the game's own mixed audio:
## godot --path . --write-movie /absolute/feel-reel.avi --script res://tests/feel_reel.gd
## Real mouse input at human speed. Saves, profiles and preferences stay in /tmp.
const Main = preload("res://scripts/main.gd")
const Run = preload("res://scripts/run_controller.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
var game: Node2D
var pointer := Vector2(640, 700)
var pointer_down := false
var marker: Node2D

class PointerMarker:
	extends Node2D
	var reel
	func _draw() -> void:
		# A visible stand-in for the player's pointer, since recordings omit the OS cursor.
		var radius := 9.0 if reel.pointer_down else 11.0
		draw_circle(reel.pointer, radius + 2.0, Color(0, 0.04, 0.05, 0.5), false, 4.0, true)
		draw_circle(reel.pointer, radius, Color(0.92, 0.98, 0.96, 0.95), false, 1.8, true)
		draw_circle(reel.pointer, 2.6 if reel.pointer_down else 1.6, Color(0.92, 0.98, 0.96, 0.95), true, -1, true)

func _initialize() -> void:
	call_deferred("record")

func wait(seconds: float) -> void:
	for i in maxi(1, roundi(seconds * 60.0)):
		marker.queue_redraw()
		await process_frame

func move_to(target: Vector2, seconds: float) -> void:
	var start := pointer
	var frames := maxi(1, roundi(seconds * 60.0))
	for i in frames:
		var t := float(i + 1) / frames
		var eased := t * t * (3.0 - 2.0 * t)
		var next := start.lerp(target, eased)
		var motion := InputEventMouseMotion.new()
		motion.position = next
		motion.relative = next - pointer
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT if pointer_down else 0
		root.push_input(motion, true)
		pointer = next
		marker.queue_redraw()
		await process_frame

func press(down: bool) -> void:
	var click := InputEventMouseButton.new()
	click.position = pointer
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	root.push_input(click, true)
	pointer_down = down

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)

## Draw a loop through live cell positions at about three segments a second.
func draw_loop(path: Array) -> void:
	var run = game.run
	await move_to(run.board.anchors[path[0]], 0.45)
	press(true)
	await wait(0.12)
	for id in path.slice(1) + [path[0]]:
		await move_to(run.board.anchors[id], 0.32)
	await wait(0.18)
	press(false)

func ready_loop_around(point: Vector2) -> Array:
	var run = game.run
	var best: Array = []
	for path in run.board.triangles:
		if Geometry.capture_valid(path, run.board, run.is_ready) and Geometry.contains(point, Geometry.polygon_for(path, run.board.anchors)):
			return path
	return best

func record() -> void:
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for file in ["/tmp/petriverse-reel-journey.cfg", "/tmp/petriverse-reel-profile.cfg"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	game = Main.new()
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/petriverse-reel-journey.cfg"
	game.journey_profile.path = "/tmp/petriverse-reel-profile.cfg"
	root.add_child(game)
	game.soundscape.preferences_path = "/tmp/petriverse-reel-preferences.cfg"
	game.soundscape.muted = false
	game.soundscape.music_volume = 0.65
	game.soundscape.effects_volume = 0.70
	marker = PointerMarker.new()
	marker.reel = self
	marker.z_index = 100
	root.add_child(marker)
	# Title: the staged first-launch introduction.
	await wait(3.2)
	await move_to(game.hud.new_button.get_global_rect().get_center(), 0.6)
	press(true)
	press(false)
	await wait(1.6)
	key(KEY_ENTER)
	await wait(1.4)
	# The guided lesson: two real captures, food motes and arrival ticks.
	var run = game.run
	await draw_loop(run.Lesson.SMALL)
	await wait(4.0)
	await draw_loop(run.Lesson.WIDE)
	# Completion: celebration, finish cue, then the evolution choice.
	await wait(4.5)
	await move_to(game.hud.cards[0].get_global_rect().get_center(), 0.7)
	await wait(1.0)
	key(KEY_1)
	await wait(3.5)
	key(KEY_ENTER)
	await wait(0.8)
	# The Bellwether: its title card, then the moment it opens.
	for position in run.route_plan.size():
		if run.route_plan[position].mode == "boss":
			run.route_position = position
			run.stage_index = int(run.route_plan[position].stage)
			break
	run.start_stage()
	game.reset_presentation()
	game.feel.last_card_dish = run.JourneyPlan.dish(run.stage_index).name
	await wait(1.2)
	key(KEY_ENTER)
	await wait(0.2)
	run.harvest.nourishment = 6
	var boss = run.boss()
	for i in 600:
		if boss == null or boss.can_take_pulse():
			break
		await wait(1.0 / 60.0)
	await wait(1.4)
	var strike := ready_loop_around(boss.nucleus) if boss != null else []
	if not strike.is_empty():
		await draw_loop(strike)
		await wait(2.4)
	# One organelle left: the heartbeat and the pulsing rim.
	run.integrity = 1
	await wait(5.0)
	# Pause pulls the dish out of focus behind the menu.
	key(KEY_SPACE)
	await wait(2.5)
	game.queue_free()
	await process_frame
	print("FEEL REEL: recorded")
	quit()
