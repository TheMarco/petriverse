extends "res://tests/harvest_visual.gd"

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-home-visual-journey.cfg"
	game.journey_profile.path = "/tmp/microverse-home-visual-profile.cfg"
	game.journey_profile.residents.clear()
	root.add_child(game)
	game.journey_profile.residents.clear()
	game.set_process(false)
	game.set_physics_process(false)
	root.size = Vector2i(1280,900)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.render_loop_enabled = false
	game.home_pond_open = true
	await capture("home-pond-empty")
	expect(game.home_pond.visible and not game.microscope.cells[0].visible,"The home habitat replaces the playable cells without altering the saved run")
	game.run.fixed_seed = 73
	game.run.restart()
	game.run.stage_index = 2
	game.run.start_stage()
	game.run.begin_encounter()
	game.home_pond_open = false
	game.run.stage_elapsed = game.run.harvest.visitor_at
	game.run.enemies.clear()
	game.run.harvest.Discoveries.step(game.run)
	var visitor = game.run.enemies[0]
	visitor.age = 6.0
	game.run.harvest.Discoveries.step(game.run)
	await capture("moonlace-visiting")
	expect(game.microscope.enemies[visitor.id].get_meta("lobes")[0].texture.resource_path.ends_with("moonlace.png"),"The visitor uses its new photographic lace tissue")
	var b = game.run.board
	# Rescues in this fixture go through native mouse input; no profile entries
	# are fabricated to make a prettier habitat screenshot.
	for batch in 4:
		await rescue_batch(batch)
	game.journey_profile.observe(game.run)
	expect(game.journey_profile.residents.size()==12,"Twelve actual mouse-captured specimens populate the pond")
	var before: float = game.run.elapsed
	game.return_home()
	await refresh()
	game._process(8.0)
	await capture("home-pond-living")
	expect(game.home_pond.specimens.size()==12 and game.home_pond.visible,"The habitat renders each saved resident with its own living sprite")
	expect(game.home_pond.wild_algae.size()==9,"Three rescued specimen forms attract small non-player algae to the habitat")
	expect(not game.hud.pond_button.get_rect().intersects(game.hud.journal_button.get_rect()),"Pond navigation and the field journal never overlap")
	var specimen: Dictionary = game.home_pond.specimens[1]
	var first: Vector2 = specimen.sprite.position
	game._process(12.0)
	expect(first.distance_to(specimen.sprite.position)>3.0 and game.run.elapsed==before,"Residents wander independently while the journey stays frozen")
	mouse(specimen.sprite.position,true)
	mouse(specimen.sprite.position,false)
	await capture("home-pond-resident")
	expect(game.home_pond.selected_record().token==specimen.record.token,"Clicking a resident reveals its real saved origin")
	game.reduced_motion = true
	first = specimen.sprite.position
	game._process(5.0)
	expect(specimen.sprite.position==first,"Reduced motion keeps the home pond still")
	key(KEY_ESCAPE)
	await refresh()
	expect(not game.home_pond_open and game.hud.new_button.visible,"Escape returns to the understandable journey menu")
	game.resume_journey()
	await refresh()
	expect(not game.home_pond.visible and game.microscope.cells[0].visible and game.run.state==Run.PAUSED,"Continuing restores the exact paused journey and playable cells")
	game.run.state = Run.ACTIVE
	game.reduced_motion = false
	for batch in range(4,14):
		await rescue_batch(batch)
	game.journey_profile.observe(game.run)
	game.return_home()
	await refresh()
	expect(game.journey_profile.residents.size()==42 and game.home_pond.specimens.size()==36 and game.hud.pond_next.visible,"Large collections retain every actual rescue and show at most 36 residents at once")
	var next_at: Vector2 = game.hud.pond_next.get_rect().get_center()
	mouse(next_at,true)
	mouse(next_at,false)
	await capture("home-pond-next-residents")
	expect(game.home_pond.page==1 and game.home_pond.specimens.size()==6 and game.hud.pond_previous.visible and not game.hud.pond_next.visible,"Native page controls reveal the remaining residents without dropping them")
	# Use those same actual captures for the final tableau, never an invented
	# collection. The journey end is staged solely to inspect its presentation.
	game.run.state = Run.SUCCESS
	game.run.stage_index = 11
	game.run.mutations = ["elastic","feast","nursery","filter"]
	game.run.enemies.clear()
	game.journey_profile.observe(game.run)
	game.home_pond.page = 0
	game.large_text = true
	game.reduced_motion = false
	await capture("journey-living-ending")
	expect(game.home_pond.showing_epilogue() and game.home_pond.visible and not game.microscope.mother.visible,"Victory replaces the board with the actual rescued home pond")
	expect(game.home_pond.specimens.size()==12 and not game.hud.pause_button.visible and not game.hud.debug_button.visible,"The ending gives twelve actual residents room to breathe and retires gameplay controls")
	var anatomy: Dictionary = game.home_pond.Anatomy.recipe(game.run.mutations)
	expect(game.home_pond.mother.material.get_shader_parameter("traits")==anatomy.traits,"The ending shows the actual evolved Mother anatomy")
	var end_position: Vector2 = game.home_pond.specimens[0].sprite.position
	var end_time: float = game.run.elapsed
	game._process(8.0)
	expect(game.home_pond.specimens[0].sprite.position!=end_position and game.run.elapsed==end_time,"The final living tableau animates without advancing the completed journey")
	game.reduced_motion = true
	end_position = game.home_pond.specimens[0].sprite.position
	game._process(5.0)
	expect(game.home_pond.specimens[0].sprite.position==end_position,"Reduced motion also keeps the final tableau still")
	key(KEY_ENTER)
	await capture("home-pond-after-journey")
	expect(game.run.state==Run.HOME and game.home_pond_open,"The final primary action returns to the persistent home habitat")
	game.queue_free()
	await process_frame
	print("HOME POND VISUAL: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func rescue_batch(batch: int) -> void:
	var b = game.run.board
	game.run.enemies.clear()
	for i in 3:
		game.run.next_enemy_id += 1
		var at: Vector2 = (b.anchors[0]+b.anchors[8]+b.anchors[9])/3.0+Vector2((i-1)*13,0)
		var body = game.run.Harvest.Organism.new(game.run.next_enemy_id,"spore",at,Vector2.ZERO,0.0)
		body.form = ["","snow_spore","sail_spore","moonlace"][(batch+i)%4]
		body.visitor = body.form=="moonlace"
		body.age = 6.0
		game.run.enemies.append(body)
	await refresh()
	mouse(b.anchors[0],true)
	var previous: Vector2 = b.anchors[0]
	for id in [8,9,0]:
		drag(previous,b.anchors[id])
		previous = b.anchors[id]
	mouse(b.anchors[0],false)
	if batch==1:
		await refresh()
		var ghosts: Array = game.microscope.pulses[-1].get_meta("ghosts")
		expect(ghosts.any(func(g): return g.texture.resource_path.ends_with("moonlace.png") and g.get_meta("extent")==90.0),"Moonlace keeps its full living size as it enters absorption")
	game.run.step_recovery(8.0)
