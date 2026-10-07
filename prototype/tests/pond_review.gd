extends SceneTree
## One representative native composition, then its selection and close-up.
class ReviewScene:
	extends "res://scripts/main.gd"
	func _init() -> void:
		pause_on_focus_loss = false
const Drifter = preload("res://scripts/drifter.gd")
var game: Node2D

func _initialize() -> void:
	call_deferred("review")

func capture(name: String) -> void:
	game._process(0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")
	await process_frame

func review() -> void:
	root.gui_disable_input = true
	root.size = Vector2i(1280, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = ReviewScene.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	var board = game.run.board
	game.run.enemies = [Drifter.new(1, (board.anchors[0] + board.anchors[8] + board.anchors[9]) / 3.0, 6), Drifter.new(2, Vector2(875, 590), 6)]
	game.run.encounter.spawned = 2
	# Useful for reviewing the first material while replacement sprites generate.
	if OS.get_cmdline_user_args().has("--plate-only"):
		game.microscope.pond.visible = false
	await capture("brightfield-dish")
	game.run.selection.start(board.anchors[0])
	game.run.selection.visit(8)
	game.run.selection.visit(9)
	game.run.selection.visit(0)
	await capture("brightfield-selection")
	game.run.selection.cancel()
	root.canvas_transform = Transform2D(0.0, Vector2.ONE * 2.0, 0.0, Vector2(root.size) * 0.5 - board.center * 2.0)
	await capture("brightfield-detail")
	game.queue_free()
	print("POND REVIEW: saved dish, selection, and detail")
	quit()
