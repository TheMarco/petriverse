extends "res://tests/harvest_visual.gd"

func _initialize() -> void:
	root.unfocusable = true
	super._initialize()

func capture(name: String) -> void:
	game.set_process_unhandled_input(false)
	await super.capture(name)
	game.set_process_unhandled_input(true)

func click_button(control: Button) -> void:
	var at := control.get_rect().get_center()
	mouse(at,true)
	mouse(at,false)

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/petriverse-title-no-save.cfg"
	game.journey_profile.path = "/tmp/petriverse-title-no-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	game._process(8.0)
	await capture("petriverse-title-screen")
	expect(game.run.state==Run.HOME and game.hud.new_button.visible and not game.hud.continue_button.visible,"First launch presents one primary start action")
	expect(not game.microscope.mother.visible and not game.microscope.cells[0].visible and game.microscope.scale.x>2.0,"Title uses a full living pond without a misleading playable board")
	var specimen: Sprite2D = game.microscope.pond.specimens[0]
	var before: Vector2 = specimen.position
	game._process(8.0)
	expect(specimen.position!=before,"The actual title background's organisms drift independently")
	if "--representative" in OS.get_cmdline_user_args():
		finish_title()
		return
	click_button(game.hud.new_button)
	await refresh()
	expect(game.run.state==Run.BRIEF and game.microscope.scale==Vector2.ONE,"Start opens the existing lesson and restores normal dish geometry")
	key(KEY_ENTER)
	await refresh()
	expect(game.run.state==Run.ACTIVE and game.microscope.cells[0].visible,"The title leads to a playable lesson")
	game.return_home()
	game.home_pond_open = false
	await capture("petriverse-title-returning")
	expect(game.hud.continue_button.visible and game.hud.continue_button.position.y<game.hud.new_button.position.y,"Returning players receive Continue as the first action")
	expect(not game.hud.continue_button.get_rect().intersects(game.hud.new_button.get_rect()),"Start and Continue have distinct accessible hit areas")
	click_button(game.hud.continue_button)
	await refresh()
	expect(game.run.state==Run.PAUSED and game.microscope.scale==Vector2.ONE,"Continue restores the paused journey at normal scale")
	game.return_home()
	game.home_pond_open = false
	await refresh()
	click_button(game.hud.pond_button)
	await refresh()
	expect(game.home_pond_open and game.home_pond.visible and game.microscope.scale==Vector2.ONE,"Home pond remains accessible with its original geometry")
	key(KEY_ESCAPE)
	await refresh()
	click_button(game.hud.advanced_button)
	await refresh()
	expect(game.hud.advanced_open and game.hud.colony_buttons[0].visible,"Optional starting colonies remain accessible")
	game.hud.toggle_advanced()
	game.large_text = true
	game.reduced_motion = true
	await capture("petriverse-title-large-text")
	specimen = game.microscope.pond.specimens[0]
	before = specimen.position
	game._process(5)
	expect(specimen.position==before,"Reduced motion holds the title background still")
	finish_title()

func finish_title() -> void:
	print("TITLE SCREEN: %d checks; %d failures" % [checks,failures.size()])
	game.queue_free()
	quit(0 if failures.is_empty() else 1)
