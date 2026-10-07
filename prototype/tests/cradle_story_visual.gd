extends "res://tests/boss_patterns_visual.gd"

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-cradle-native-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-cradle-native-profile.cfg"
	root.add_child(game)
	game.journey_profile.residents.clear()
	game.set_process(false)
	game.set_physics_process(false)
	root.size = Vector2i(1280,900)
	root.content_scale_size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	prepare(6)
	game.large_text = true
	game.run.state = Run.BRIEF
	await capture("cradle-story-brief")
	game.run.state = Run.ACTIVE
	var b = game.run.board
	var pearl = game.run.enemies.filter(func(e): return e.cradle)[0]
	game.run.enemies = game.run.enemies.filter(func(e): return e==pearl or pearl.gate_ids.has(e.id))
	var at: Vector2 = (b.anchors[0]+b.anchors[8]+b.anchors[9])/3.0
	pearl.origin = at
	pearl.nucleus = at
	pearl.drift = Vector2.ZERO
	for shield in game.run.enemies:
		if shield.kind=="warden":
			shield.nucleus = at+Vector2(-10 if shield.id==pearl.gate_ids[0] else 10,0)
			shield.destination = shield.nucleus
	await gesture([0,8,9])
	expect(pearl.gate_ids.is_empty() and pearl.hatch_remaining()>11.8,"A native two-segments-per-second shield capture starts the advertised hatching choice")
	game.toast_time = 0.0
	await capture("cradle-story-choice")
	advance(10.6)
	await capture("cradle-story-unfolding")
	var tissue: Sprite2D = game.microscope.enemies[pearl.id].get_meta("lobes")[0]
	expect(tissue.material.get_shader_parameter("division")>0.8 and tissue.material.get_shader_parameter("dissolve")>0.0,"The pearl visibly separates and sheds its tissue before hatching")
	game.reduced_motion = true
	await capture("cradle-story-reduced-motion")
	expect(tissue.material.get_shader_parameter("motion")==0.0 and is_equal_approx(tissue.scale.x,tissue.scale.y),"Reduced motion keeps the hatching membrane still without hiding its choice")
	game.reduced_motion = false
	advance(1.6)
	await capture("cradle-story-birth")
	var young: Array = game.run.enemies.filter(func(e): return e.story=="hatchling")
	expect(young.size()==2 and young.all(func(e): return game.microscope.enemies[e.id].get_meta("lobes")[0].material.get_shader_parameter("arrival")<1.0),"Both young emerge through the organic birth shader")
	advance(2.5)
	var chosen: Array = []
	var smallest := INF
	for a in 24:
		for c in range(a+1,24):
			for d in range(c+1,24):
				var candidate: Array = [a,c,d]
				var polygon: PackedVector2Array = game.run.Geometry.polygon_for(candidate,b.anchors)
				var contains := true
				for child in young:
					for padding in [Vector2(12,0),Vector2(-12,0),Vector2(0,12),Vector2(0,-12)]:
						contains = contains and game.run.Geometry.contains(child.nucleus+padding,polygon)
				if contains and candidate.all(func(id): return game.run.is_ready(id)):
					var area: float = absf((polygon[1]-polygon[0]).cross(polygon[2]-polygon[0]))
					if area<smallest:
						smallest = area
						chosen = candidate
	expect(not chosen.is_empty(),"The actual drifting board still offers a clean polygon around both young")
	if not chosen.is_empty():
		await gesture(chosen)
	expect(game.run.harvest.rescued==2 and game.run.rescued_specimens.size()==2,"A deliberate native mouse capture rescues both actual hatchlings")
	game.run.step_recovery(8.0)
	game.journey_profile.observe(game.run)
	game.return_home()
	await refresh()
	var specimen: Dictionary = game.home_pond.specimens[0]
	mouse(specimen.sprite.position,true)
	mouse(specimen.sprite.position,false)
	await capture("cradle-story-at-home")
	expect(game.home_pond.selected_record().story=="hatchling","The saved resident carries its real hatching story into the home pond")
	game.queue_free()
	await process_frame
	print("CRADLE STORY VISUAL: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
