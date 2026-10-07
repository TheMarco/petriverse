extends "res://tests/harvest_visual.gd"
const Forms = preload("res://scripts/creature_forms.gd")
const Arrival = preload("res://scripts/organism_arrival.gd")
const Save = preload("res://scripts/journey_save.gd")
const Guide = preload("res://scripts/journey_guidance.gd")

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-arrivals-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-arrivals-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	var run = game.run
	run.stage_index = 10
	run.start_stage()
	run.begin_encounter()
	var encountered: Array = []
	# Exercise each real spawn route, including bloom and ordinary hunters.
	for i in 24:
		run.enemies.clear()
		run.harvest.spawn_bloom(run,i%8)
		run.harvest.spawn_spore(run,i%8)
		run.spawn_enemy({"angle":0,"radius":300,"speed":5.4,"kind":"drifter"})
		for family in ["grazer","parasite","divider"]:
			run.harvest.ecology.add(run,family,i%8,run.board.center+Vector2(220,0))
		for body in run.enemies:
			if not body.form.is_empty() and not encountered.has(body.form):
				encountered.append(body.form)
	expect(encountered.size()==12,"All twelve forms occur through actual mission spawn routes")
	var rng_before: int = run.rng.state
	Forms.assign(run,run.enemies[0])
	expect(run.rng.state==rng_before,"Creature variation does not change gameplay RNG")
	run.enemies.clear()
	for i in Forms.ENTRIES.size():
		var entry: Dictionary = Forms.ENTRIES[i]
		var at: Vector2 = run.board.center + Vector2.from_angle(i*TAU/float(Forms.ENTRIES.size()))*252.0
		var body: RefCounted
		if entry.kind in ["food","cyst","spore"]:
			body = run.Harvest.Organism.new(400+i,entry.kind,at,Vector2.ZERO,0.0)
		elif entry.kind in ["grazer","parasite","divider"]:
			body = run.JourneyHarvest.Ecology.Body.new(400+i,entry.kind,at,i%8)
			body.target_node = i%8
		else:
			body = run.Drifter.new(400+i,at,5.4,entry.kind)
		body.form = entry.id
		body.visitor = entry.get("rare",false) and not entry.get("expedition",false)
		run.enemies.append(body)
		var texture: Texture2D = Forms.texture(entry.id)
		var pixels := texture.get_image()
		expect(pixels.detect_alpha()!=Image.ALPHA_NONE and pixels.get_pixel(0,0).a<0.01,"Real transparent sprite (allow sub-percent alpha noise): "+entry.id)
		expect(pixels.has_mipmaps(),"Mipmap filtering for small living sprites: "+entry.id)
	game.last_discovery = run.discovery_serial
	game.toast_time = 0.0
	for age in [0.0,0.85,3.0]:
		for body in run.enemies:
			body.age = age
		game.visual_time = age
		await capture("creature-arrivals-%02d" % int(age*10))
		for body in run.enemies:
			var sprite: Sprite2D = game.microscope.enemies[body.id].get_meta("lobes")[0]
			var uv: Vector2 = sprite.material.get_shader_parameter("nucleus_uv")
			var center: Vector2 = sprite.to_global(sprite.offset+(uv-Vector2.ONE*0.5)*sprite.texture.get_size())
			expect(center.distance_to(body.nucleus)<0.1,"Nucleus stays aligned through birth: "+body.form)
			expect(sprite.material.get_shader_parameter("arrival")==Arrival.progress(body),"Tissue follows simulation age: "+body.form)
	var before: float = run.enemies[0].age
	run.state = Run.PAUSED
	run.step(10.0)
	expect(run.enemies[0].age==before,"Pause freezes arrival")
	var clone := Run.new(true,18,true,true)
	expect(Save.restore(clone,Save.capture(run)) and clone.enemies[0].form==run.enemies[0].form and Arrival.progress(clone.enemies[0])==1.0,"Resume preserves form and does not replay birth")
	clone.dispose()
	game.reduced_motion = true
	await refresh()
	expect(game.microscope.enemies[400].get_meta("lobes")[0].material.get_shader_parameter("motion")==0.0,"Reduced motion removes emergence folding and focus motion")
	expect(game.microscope.enemies[400].get_meta("lobes")[0].material.get_shader_parameter("visitor_open")==1.0,"Reduced motion keeps Moonlace petals still and fully open")
	game.reduced_motion = false
	game.journal_open = true
	game.hud.journal_page = 2
	await capture("creature-journal-1")
	game.hud.journal_page = 3
	await capture("creature-journal-2")
	game.large_text = true
	game.hud.journal_page = 2
	await capture("creature-journal-large")
	game.large_text = false
	game.hud.turn_journal(99)
	await refresh()
	expect(not game.hud.journal_next.visible and game.hud.journal_previous.visible,"All %d journal entries fit in paginated cards" % run.JourneyPlan.SPECIES.size())
	game.journal_open = false
	run.state = Run.ACTIVE
	run.enemies.clear()
	var polygon: PackedVector2Array = run.Geometry.polygon_for([0,8,9],run.board.anchors)
	var center: Vector2 = (polygon[0]+polygon[1]+polygon[2])/3.0
	for spec in [["food","fern_desmid"],["cyst","crown_cyst"]]:
		var body = run.Harvest.Organism.new(500+run.enemies.size(),spec[0],center,Vector2.ZERO,0.0)
		body.form = spec[1]
		run.enemies.append(body)
	run.selection.start(run.board.anchors[0])
	for id in [8,9,0]:
		run.selection.visit(id)
	expect(run.harvest_preview().food==1 and run.harvest_preview().poison==1,"Forming food and cyst retain honest capture and poison preview")
	var result: Dictionary = run.release()
	expect(result.food==1 and result.poison==1 and result.prey_forms==["fern_desmid","crown_cyst"],"Capture preserves form identity and original rules")
	await refresh()
	expect(game.microscope.pulses[0].get_meta("ghosts")[0].texture==Forms.texture("fern_desmid"),"Absorption uses the captured creature's actual tissue")
	clone = Run.new(true,19,true,true)
	expect(Save.restore(clone,Save.capture(run)) and clone.clots[0].prey_forms==result.prey_forms,"Saving during absorption preserves creature forms")
	clone.dispose()
	run.selection.cancel()
	var hunter = run.Drifter.new(610,run.board.center+Vector2(130,0),5.4)
	hunter.form = "needle_hunter"
	run.enemies = [hunter]
	var guide := Guide.next_action(run)
	expect(guide.urgent and guide.target==610 and guide.detail.contains("health core"),"Approaching hunter states its consequence and deadline")
	expect(Guide.next_action(run,true).detail.ends_with("press Enter."),"Urgent guidance respects click input")
	hunter.age = 5.0
	await capture("creature-urgency")
	hunter.nucleus = run.board.center
	run.resolve_contacts()
	await refresh()
	var bite = run.mother_damage.bites[-1]
	expect(bite.form=="needle_hunter" and game.microscope.invaders[bite.serial].get_meta("lobes")[0].texture==Forms.texture("needle_hunter"),"Mother attack keeps the invading hunter's identity")
	run.enemies.clear()
	var parent = run.harvest.ecology.add(run,"divider",0,run.board.center+Vector2(240,0),"hourglass_divider")
	parent.age = 20.1
	parent.spawning = 0.0
	run.harvest.ecology.step(run,0.1)
	expect(run.enemies.size()==2 and run.enemies.all(func(body): return body.form=="hourglass_divider" and body.daughter),"Divider offspring inherit the parent's tissue form")
	game.queue_free()
	await process_frame
	print("CREATURE ARRIVALS: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
