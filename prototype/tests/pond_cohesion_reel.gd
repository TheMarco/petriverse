extends SceneTree
const Main = preload("res://scripts/main.gd")
## Capture eight seconds of native frames; survives covered/background windows.
## Encode artifacts/pond-cohesion-frames/frame-%04d.png at 30fps for review.
const OUT = "res://artifacts/pond-cohesion-frames"

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
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-pond-reel-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-pond-reel-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.run.fixed_seed = 73
	game.run.restart()
	game.run.stage_index = 2
	game.run.start_stage()
	game.run.Habitats.choose(game.run,"bloom")
	game.run.begin_encounter()
	for i in 360:
		game.run.step(1.0/60.0)
	game.visual_time = 6.0
	game.last_discovery = game.run.discovery_serial
	for frame in range(1,241):
		game.run.step(1.0/30.0)
		game._process(1.0/30.0)
		game.last_discovery = game.run.discovery_serial
		game.toast_time = 0.0
		game.hud.hide()
		await process_frame
		RenderingServer.force_draw(false)
		var view := root.get_texture().get_image()
		if frame in [1,120,240]:
			view.save_png("res://artifacts/pond-cohesion-%03d.png" % frame)
		var error := view.get_region(Rect2i(220,36,840,824)).save_png(OUT+"/frame-%04d.png" % frame)
		if error!=OK:
			printerr("FAIL: frame ",frame," save error ",error)
			quit(1)
			return
	game.queue_free()
	await process_frame
	print("POND REEL: 240 native frames at 30fps")
	quit()
