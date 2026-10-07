extends SceneTree
## Native, deterministic fifteen-second comparison of the three first builds.
const Main = preload("res://scripts/main.gd")
var game: Node2D
var frame := 0

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1152,810)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-evolution-reel-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-evolution-reel-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.run.fixed_seed = 73
	game.run.restart()
	game.run.stage_index = 1
	game.run.start_stage()
	game.run.enemies.clear()
	game._process(0.0)
	RenderingServer.render_loop_enabled = false

func _process(_delta: float) -> bool:
	if game == null:
		return false
	if frame%300==0:
		var id: String = ["fission","elastic","symbiosis"][frame/300]
		game.run.mutations = [id]
		game.evolution_reveal.present(id)
	game._process(1.0/60.0)
	call_deferred("draw_frame")
	frame += 1
	return false

func draw_frame() -> void:
	RenderingServer.force_draw(false)
	if frame==900:
		print("EVOLUTION REEL: three growth transformations completed")
		game.queue_free()
		quit()
