extends "res://tests/boss_patterns_visual.gd"

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-rare-native-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-rare-native-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.size = Vector2i(1280,900)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.render_loop_enabled = false
	prepare(4)
	game.run.enemies.clear()
	game.run.harvest.visitor_at = 0.1
	game.run.stage_elapsed = 0.1
	game.run.harvest.last_time = game.run.stage_elapsed
	game.run.harvest.Discoveries.step(game.run)
	var harp = game.run.enemies[0]
	advance(6.0)
	game.last_discovery = game.run.discovery_serial
	game.toast_time = 0.0
	await capture("rare-glass-harp")
	var sprite: Sprite2D = game.microscope.enemies[harp.id].get_meta("lobes")[0]
	var uv: Vector2 = sprite.material.get_shader_parameter("nucleus_uv")
	var center: Vector2 = sprite.to_global(sprite.offset+(uv-Vector2.ONE*0.5)*sprite.texture.get_size())
	expect(center.distance_to(harp.nucleus)<0.1 and sprite.texture.get_image().has_mipmaps(),"The photographic visitor has a registered nucleus and small-sprite mipmaps")
	var chosen: Array = []
	for path in game.run.board.triangles:
		if game.run.Geometry.contains(harp.nucleus,game.run.Geometry.polygon_for(path,game.run.board.anchors)):
			chosen = path
			break
	expect(not chosen.is_empty(),"The director puts the visitor inside a real capture opportunity")
	await gesture(chosen)
	expect(game.run.rescued_specimens.any(func(r): return r.form=="glass_harp"),"A real two-segments-per-second mouse gesture rescues the visitor")
	var ghosts: Array = game.microscope.pulses[-1].get_meta("ghosts")
	expect(ghosts.any(func(g): return g.texture.resource_path.ends_with("glass_harp.png") and g.get_meta("extent")==90.0),"Absorption retains the visitor's full tissue and scale")
	game.run.step_recovery(8.0)
	game.journey_profile.observe(game.run)
	game.return_home()
	await capture("rare-glass-harp-home")
	expect(game.home_pond.specimens.any(func(s): return s.record.form=="glass_harp"),"The rescued Glass Harp becomes a real home-pond resident")
	game.home_pond_open = false
	prepare(8)
	game.run.enemies.clear()
	game.run.harvest.visitor_at = 0.1
	game.run.stage_elapsed = 0.1
	game.run.harvest.last_time = 0.1
	game.run.harvest.Discoveries.step(game.run)
	var glow = game.run.enemies[0]
	advance(6.0)
	game.last_discovery = game.run.discovery_serial
	game.toast_time = 0.0
	await capture("rare-glowdrift")
	var light: Sprite2D = game.microscope.enemies[glow.id].get_meta("lobes")[0]
	expect(light.material.get_shader_parameter("visitor_glow")>0.5,"Glowdrift's living chambers shine during their real protective opening")
	game.reduced_motion = true
	await capture("rare-glowdrift-reduced-motion")
	expect(light.material.get_shader_parameter("motion")==0.0 and light.material.get_shader_parameter("visitor_open")==1.0,"Reduced motion keeps the new tissue still and readable")
	game.queue_free()
	await process_frame
	print("RARE VISITORS VISUAL: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
