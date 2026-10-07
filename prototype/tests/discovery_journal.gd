extends "res://tests/harvest_visual.gd"

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-journal-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-journal-profile-unused.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.size = Vector2i(1280,900)
	root.content_scale_size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	game.journey_profile.discovered.clear()
	game.run.seen_species.clear()
	game.run.stage_index = 4
	game.run.start_stage()
	game.run.begin_encounter()
	game.large_text = true
	key(KEY_J)
	var rare_index: int = game.hud.Journey.SPECIES.map(func(e): return e.id).find("glowdrift")
	game.hud.journal_page = rare_index/game.hud.JOURNAL_PAGE_SIZE
	await capture("discovery-journal-hints")
	expect(game.journal_open and game.run.state==Run.PAUSED,"Reading discovery directions pauses the active journey")
	for id in ["moonlace","glass_harp","glowdrift"]:
		var entry: Dictionary = game.microscope.Forms.definition(id)
		var hint: String = game.hud.Journey.search_hint(entry)
		expect(hint.contains("sheltered route") and hint.contains(game.hud.Journey.dish(int(entry.first_stage)).name),"A rare organism gives an actionable habitat direction: "+id)
	for entry in preload("res://scripts/expedition_creatures.gd").ENTRIES:
		var hint: String = game.hud.Journey.search_hint(entry)
		expect(hint.contains("one of four") and hint.contains(game.hud.Journey.dish(int(entry.first_stage)).name) and not hint.contains("sheltered route"),"Rare forms explain their biome and cross-journey discovery rule: "+entry.id)
	game.hud.journal_page = game.hud.Journey.SPECIES.map(func(e): return e.id).find("chalice_grazer")/game.hud.JOURNAL_PAGE_SIZE
	await capture("discovery-journal-expedition-hints")
	game.journey_profile.discovered = game.hud.Journey.SPECIES.map(func(e): return e.id)
	await capture("discovery-journal-rare-known")
	game.hud.journal_page = 1
	await capture("discovery-journal-bosses")
	game.hud.turn_journal(999)
	await refresh()
	var last_page := ceili(float(game.hud.Journey.SPECIES.size())/game.hud.JOURNAL_PAGE_SIZE)-1
	expect(game.hud.journal_page==last_page and not game.hud.journal_next.visible and game.hud.journal_previous.visible,"Every species remains reachable in readable journal pages")
	mouse(game.hud.journal_previous.get_rect().get_center(),true)
	mouse(game.hud.journal_previous.get_rect().get_center(),false)
	await refresh()
	expect(game.hud.journal_page==last_page-1,"The native previous-page button navigates the expanded journal")
	key(KEY_J)
	expect(not game.journal_open and game.run.state==Run.ACTIVE,"Closing the journal resumes the original encounter")
	game.queue_free()
	await process_frame
	print("DISCOVERY JOURNAL: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
