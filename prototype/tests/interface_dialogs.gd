extends "res://tests/harvest_visual.gd"
## Normal-size dialogs: settings, the new-journey confirmation, HUD tooltips
## and the turned-over evolution cards. Runs headless.
const UI = preload("res://scripts/ui_style.gd")

func click_button(control: Button) -> void:
	var at := control.get_global_rect().get_center()
	mouse(at, true)
	mouse(at, false)

func exercise() -> void:
	for file in ["/tmp/petriverse-dialogs-journey.cfg", "/tmp/petriverse-dialogs-profile.cfg"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/petriverse-dialogs-journey.cfg"
	game.journey_profile.path = "/tmp/petriverse-dialogs-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1152, 810)
	await refresh()
	var hud = game.hud
	expect(not game.comfort_layout(), "The default window uses the normal layout")

	# Settings: every option is a HUD control inside one compact dialog.
	game.toggle_sound_settings()
	await refresh()
	var options: Array = [hud.music_slider, hud.effects_slider, hud.mute_button, hud.mode_button, hud.assist_button, hud.slow_button, hud.comfort_motion_button, hud.contrast_button, hud.text_button, hud.quality_button, hud.fullscreen_button, hud.sound_close]
	expect(options.all(func(c): return c.visible), "Settings shows all twelve controls at normal size")
	expect(not game.readable_ui.screen.visible, "Settings no longer uses the large reflowed panel in a normal window")
	expect(options.all(func(c): return hud.SETTINGS.encloses(c.get_global_rect())), "Every settings control sits inside the dialog")
	var overlaps := false
	for i in options.size():
		for j in range(i + 1, options.size()):
			overlaps = overlaps or options[i].get_global_rect().intersects(options[j].get_global_rect())
	expect(not overlaps, "No two settings controls overlap")
	click_button(hud.assist_button)
	await refresh()
	expect(game.assisted_closure and hud.assist_button.text == "On", "Closure assistance toggles from its row")
	click_button(hud.assist_button)
	key(KEY_ESCAPE)
	await refresh()
	expect(not game.settings_open and not hud.music_slider.visible, "Escape closes settings")

	# Tooltips: the engine's single-line popup is silent; the HUD draws a wrapped one.
	expect(hud.slow_button.get_tooltip(Vector2.ZERO).is_empty() and hud.slow_button.tooltip_text.contains("35%"), "Settings buttons keep their text but silence the engine tooltip")
	var long_lines: PackedStringArray = hud.lines_for(hud.slow_button.tooltip_text, hud.TIP_WIDTH - 28.0, 13, UI.REGULAR)
	expect(long_lines.size() >= 2, "A long tooltip wraps to the tooltip width")

	# Confirmation before an unfinished journey is replaced.
	game.new_journey("wanderer")
	game.overlay_action()
	await refresh()
	game.return_home()
	game.home_pond_open = false
	await refresh()
	var snapshot: Dictionary = game.resume_data.duplicate(true)
	click_button(hud.new_button)
	await refresh()
	expect(game.pending_new_colony == "wanderer" and game.resume_data == snapshot, "Starting over asks first")
	expect(hud.confirm_keep.visible and hud.confirm_replace.visible and not hud.new_button.visible and not hud.continue_button.visible, "The question replaces the title's choices")
	expect(hud.confirm_keep.has_focus(), "Keeping the journey is the focused answer")
	expect(not game.readable_ui.screen.visible and not hud.confirm_summary().is_empty(), "The question is a HUD dialog with a summary of the journey")
	key(KEY_ESCAPE)
	await refresh()
	expect(game.pending_new_colony.is_empty() and game.resume_data == snapshot and hud.continue_button.visible, "Escape keeps the journey and restores the title")
	click_button(hud.new_button)
	await refresh()
	click_button(hud.confirm_replace)
	await refresh()
	expect(game.pending_new_colony.is_empty() and game.run.state == Run.BRIEF and game.run.stage_index == 0, "Confirming starts the new journey")

	# A traited encounter: trait tooltips carry the trait name as a title.
	var run = game.run
	run.stage_index = 4
	run.mutations = ["filter", "feast"]
	run.start_stage()
	game.reset_presentation()
	run.begin_encounter()
	await refresh()
	var zone: Control = hud.trait_tooltips[0]
	expect(zone.visible and zone.get_meta("tip_title", "") == "Filter Veil" and zone.tooltip_text.contains("cyst") and zone.get_tooltip(Vector2.ZERO).is_empty(), "Trait tooltips have a title and a wrapped body")
	expect(hud.pause_button.get_meta("tip_key", "") == "Space", "The pause tooltip shows its key")

	# Evolution: cards carry no tooltip; Compare details turns them over.
	run.biomass = 30
	run.harvest.nourishment = run.harvest.spec.food
	for i in 120:
		run.step(1.0 / 30.0)
		game._process(1.0 / 30.0)
	await refresh()
	expect(run.evolution_ready() and hud.cards[0].visible and hud.compare_button.visible, "Evolution offers cards and Compare details")
	expect(hud.cards.all(func(card): return card.tooltip_text.is_empty()), "Evolution cards have no one-line tooltip")
	click_button(hud.compare_button)
	await refresh()
	expect(game.comparisons_open and hud.cards[0].visible and hud.cards[0].detailed and hud.compare_button.text == "Show cards", "Compare details turns every card over in place")
	expect(not game.readable_ui.screen.visible, "Comparisons stay in the normal-size dialog")
	click_button(hud.compare_button)
	await refresh()
	expect(not game.comparisons_open and not hud.cards[0].detailed, "Show cards turns them back")
	game.queue_free()
	await process_frame
	print("INTERFACE DIALOGS: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
