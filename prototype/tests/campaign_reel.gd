extends SceneTree
## Native eight-second species reel using the production shaders and simulation.
class MovieScene:
	extends "res://scripts/main.gd"
	func _init() -> void:
		pause_on_focus_loss = false
const Enemy = preload("res://scripts/drifter.gd")
const Boss = preload("res://scripts/conjoined.gd")
var game: Node2D
var frame := 0

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1280, 900)
	root.content_scale_size = root.size
	RenderingServer.render_loop_enabled = false
	game = MovieScene.new()
	game.audio_enabled = false
	game.preferences_enabled = false
	game.save_records = false
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.run.stage_index = 2
	game.run.start_stage()
	game.run.encounter.spawned = game.run.encounter.budget
	game.run.enemies = [Enemy.new(101, Vector2(480, 300), 4.0, "shellback"), Enemy.new(102, Vector2(830, 335), 4.0, "shellback"), Enemy.new(103, Vector2(850, 570), 4.0, "twinspore"), Enemy.new(104, Vector2(415, 590), 4.0)]
	game.run.enemies[1].apply_pulse(1)

func _process(_delta: float) -> bool:
	if game == null:
		return false
	frame += 1
	if frame == 241:
		game.run.stage_index = 3
		game.run.start_stage()
		game.run.boss().age = 2.5
	game.run.step(1.0 / 60.0)
	game._process(1.0 / 60.0)
	call_deferred("record_frame")
	return false

func record_frame() -> void:
	RenderingServer.force_draw(false, 1.0 / 60.0)
	if frame >= 480:
		print("CAMPAIGN REEL: eight seconds of native species motion")
		game.queue_free()
		quit()
