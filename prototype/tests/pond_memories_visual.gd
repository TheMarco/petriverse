extends "res://tests/home_pond_visual.gd"

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-pond-memories-native-journey.cfg"
	game.journey_profile.path = "/tmp/microverse-pond-memories-native-profile.cfg"
	root.add_child(game)
	game.journey_profile.residents.clear()
	game.journey_profile.pond_memories.clear()
	game.journey_profile.cleared_encounters.clear()
	game.set_process(false)
	game.set_physics_process(false)
	root.size = Vector2i(1280,900)
	root.content_scale_size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	game.run.stage_index = 2
	game.run.start_stage()
	game.run.begin_encounter()
	for batch in 2:
		await rescue_batch(batch)
	# A real mouse capture earns the nursery visible in this preview.
	var b = game.run.board
	game.run.enemies.clear()
	for kind in ["spore","drifter"]:
		game.run.next_enemy_id += 1
		var at: Vector2 = (b.anchors[0]+b.anchors[8]+b.anchors[9])/3.0
		var body = Drifter.new(game.run.next_enemy_id,at,0.0) if kind=="drifter" else game.run.Harvest.Organism.new(game.run.next_enemy_id,"spore",at,Vector2.ZERO,0.0)
		game.run.enemies.append(body)
	await refresh()
	mouse(b.anchors[0],true)
	var previous: Vector2 = b.anchors[0]
	for id in [8,9,0]:
		drag(previous,b.anchors[id])
		previous = b.anchors[id]
	mouse(b.anchors[0],false)
	game.run.step_recovery(8.0)
	game.journey_profile.observe(game.run)
	game.return_home()
	game.home_pond_open = true
	await refresh()
	expect(game.journey_profile.residents.size()==7 and game.home_pond.keepsakes.size()==6,"A real earned nursery renders six wild decorations without adding rescued residents")
	var selected: Dictionary = game.home_pond.specimens[0]
	mouse(selected.sprite.position,true)
	mouse(selected.sprite.position,false)
	await refresh()
	var record: Dictionary = game.home_pond.selected_record()
	expect(not record.is_empty() and not game.home_pond.selected_companion().is_empty(),"Selecting an actual resident reveals a real companion")
	mouse(game.hud.rename_button.get_rect().get_center(),true)
	mouse(game.hud.rename_button.get_rect().get_center(),false)
	await capture("home-pond-name-editor")
	expect(game.hud.renaming() and game.hud.name_input.has_focus(),"The native name button opens a focused editable field")
	var clock_before: float = game.home_pond.clock
	game._process(5.0)
	expect(game.home_pond.clock==clock_before and not game.hud.new_button.visible,"The editor freezes pond motion and prevents accidental new journeys")
	game.hud.name_input.text = "Luna"
	key(KEY_ENTER)
	await refresh()
	expect(not game.hud.renaming() and game.journey_profile.resident_label(record)=="Luna","Enter commits the resident name through the native editor")
	var loaded = game.JourneyProfile.new()
	loaded.path = game.journey_profile.path
	loaded.load_profile()
	expect(loaded.residents.any(func(r): return r.token==record.token and r.get("nickname","")=="Luna"),"The native name edit persists to the isolated profile file")
	game.large_text = true
	await capture("home-pond-companions")
	mouse(game.hud.rename_button.get_rect().get_center(),true)
	mouse(game.hud.rename_button.get_rect().get_center(),false)
	game.hud.name_input.text = "Cancelled"
	key(KEY_ESCAPE)
	await refresh()
	expect(not game.hud.renaming() and game.home_pond_open and game.journey_profile.resident_label(record)=="Luna","Escape cancels only the editor and preserves the previous name")
	game.journey_profile.rename_resident(record.token,"W".repeat(24))
	await capture("home-pond-long-name")
	game.journey_profile.rename_resident(record.token,"Luna")
	var first: Vector2 = selected.sprite.position
	game._process(20.0)
	expect(selected.sprite.position.distance_to(first)>1.0 and game.run.state==Run.HOME,"Residents continue independent visits while the saved journey remains at home")
	game.reduced_motion = true
	first = selected.sprite.position
	var garden: Vector2 = game.home_pond.keepsakes[0].sprite.position
	game._process(10.0)
	expect(selected.sprite.position==first and game.home_pond.keepsakes[0].sprite.position==garden,"Reduced motion freezes residents and earned gardens")
	game.queue_free()
	await process_frame
	print("POND MEMORIES VISUAL: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
