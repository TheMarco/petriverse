extends SceneTree
## Twelve-second native renderer reel: one normal-size hit, then a closer view
## of a second hit. Uses the real contact radius, enemy speed and injury timer.
class MovieScene:
	extends "res://scripts/main.gd"
	func _init() -> void:
		pause_on_focus_loss = false
const Drifter = preload("res://scripts/drifter.gd")
var game: Node2D
var frame := 0

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1280, 900)
	root.content_scale_size = root.size
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
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.run.encounter.next_spawn = 1000.0
	spawn(1, -0.58)

func spawn(id: int, angle: float) -> void:
	game.run.enemies.append(Drifter.new(id, game.run.board.center + Vector2.from_angle(angle) * 62.0, game.run.board.tuning.enemy_speed))
	game.run.encounter.spawned = id

func _process(_delta: float) -> bool:
	if game == null:
		return false
	frame += 1
	game.run.step(1.0 / 60.0)
	game._process(1.0 / 60.0)
	if frame == 300:
		root.canvas_transform = Transform2D(0.0, Vector2.ONE * 2.8, 0.0, Vector2(root.size) * 0.5 - game.run.board.center * 2.8)
		spawn(2, 2.6)
	if frame == 720:
		var complete: bool = game.run.integrity == 3 and game.run.mother_damage.progress_values().count(1.0) == 2 and game.microscope.invaders.is_empty()
		print("MOTHER REEL: ", "two hits completed; no live invaders" if complete else "FAIL: damage reel did not complete")
		game.queue_free()
		quit(0 if complete else 1)
	return false
