extends SceneTree
## Native render review of the same live materials at close-up and gameplay size.
const Main = preload("res://scripts/main.gd")
const Drifter = preload("res://scripts/drifter.gd")
var game: Node2D

func _initialize() -> void:
	call_deferred("review")

func frame() -> void:
	game._process(0.0)
	await process_frame
	await process_frame

func save(name: String) -> void:
	await frame()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")
	await process_frame

func review() -> void:
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = Main.new()
	game.save_records = false
	game.preferences_enabled = false
	game.run.journey = false # This fixture exercises the isolated enclosure rules.
	game.run.harvest_mode = false
	game.run.full_run = false
	game.run.restart()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var board = game.run.board
	game.run.enemies = [Drifter.new(1, (board.anchors[0] + board.anchors[8] + board.anchors[9]) / 3.0, 6), Drifter.new(2, Vector2(880, 590), 6)]
	game.run.encounter.spawned = 2
	await save("visual-gameplay")
	# Show the actual material, at 3x its game size, without changing the board.
	game.hud.visible = false
	game.microscope.mother.visible = false
	for sprite in game.microscope.cells:
		sprite.visible = false
	for sprite in game.microscope.enemies.values():
		sprite.visible = false
	game.modulate.a = 1.0
	var specimen = game.microscope.organism(game.microscope.MOTHER, 410, 0.3)
	specimen.position = Vector2(520, 432)
	specimen.z_index = 10
	var cell = game.microscope.organism(game.microscope.CELL, 172, 1.2)
	cell.position = Vector2(860, 290)
	cell.z_index = 10
	var enemy = game.microscope.organism(game.microscope.DRIFTER, 280, 0.7)
	enemy.position = Vector2(872, 575)
	enemy.rotation = -0.45
	enemy.z_index = 10
	await save("visual-specimens")
	for sprite in [specimen, cell, enemy]:
		sprite.queue_free()
	game.queue_free()
	await process_frame
	print("VISUAL REVIEW: saved gameplay and material close-up")
	quit()
