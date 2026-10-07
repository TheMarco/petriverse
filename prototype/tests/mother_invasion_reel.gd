extends SceneTree
## Eight seconds, captured with explicit native draws even behind another window.
const Main = preload("res://scripts/main.gd")
const Drifter = preload("res://scripts/drifter.gd")
const OUT := "/tmp/microverse-mother-invasion-frames"

func _initialize() -> void:
	call_deferred("render")

func render() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.gui_disable_input = true
	root.size = Vector2i(1280,900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.render_loop_enabled = false
	var game := Main.new()
	game.save_records = false
	game.preferences_enabled = false
	game.audio_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-invasion-reel-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-invasion-reel-profile-unused.cfg"
	game.run.journey = false
	game.run.harvest_mode = false
	game.run.full_run = false
	game.run.restart()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.run.encounter.next_spawn = 9999.0
	for frame in range(1,241):
		if frame==121:
			root.canvas_transform = Transform2D(0.0,Vector2.ONE*3.2,0.0,Vector2(root.size)*0.5-game.run.board.center*3.2)
		if frame in [25,145]:
			var angle := -0.58 if frame==25 else 2.6
			var origin: Vector2 = game.run.board.center+Vector2.from_angle(angle)*(game.run.board.mother_radius+9.0)
			var hunter := Drifter.new(frame,origin,0.0)
			if frame==145: hunter.form = "trident_hunter"
			game.run.enemies.append(hunter)
			game.run.resolve_contacts()
		game.run.step(1.0/30.0)
		game._process(1.0/30.0)
		game.hud.hide()
		await process_frame
		RenderingServer.force_draw(false)
		var picture := root.get_texture().get_image()
		if picture.save_png(OUT+"/frame-%04d.png" % frame)!=OK:
			printerr("FAIL: Could not save frame ",frame)
			quit(1)
			return
	var complete: bool = game.run.integrity==3 and game.run.mother_damage.progress_values().count(1.0)==2 and game.microscope.invaders.is_empty()
	print("MOTHER INVASION REEL: ","240 frames; two complete hits" if complete else "FAIL: incomplete hits")
	game.queue_free()
	await process_frame
	quit(0 if complete else 1)
