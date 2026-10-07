extends "res://tests/harvest_visual.gd"
const Guide = preload("res://scripts/journey_guidance.gd")

func advance(seconds: float) -> void:
	for i in ceili(seconds*60.0):
		game.run.step(1.0/60.0)
		game.visual_time += 1.0/60.0

func prepare(stage: int) -> void:
	game.run.stage_index = stage
	game.run.start_stage()
	game.run.begin_encounter()
	game.run.harvest.next_bloom = 9999.0
	game.run.harvest.ecology.next_wave = 9999.0
	game.run.harvest.ecology.pending.clear()
	game.run.harvest.visitor_at = -1.0
	game.run.harvest.nourishment = 6
	game.run.mutations = ["fission","grazer"] if stage<4 else ["elastic","enzyme","filter","nursery"]
	game.run.selection.max_vertices = game.run.Mutations.maximum(game.run.mutations)
	game.last_discovery = game.run.discovery_serial
	game.toast_time = 0.0

func gesture(path: Array) -> void:
	var previous: Vector2 = game.run.board.anchors[path[0]]
	mouse(previous,true)
	for id in path.slice(1)+[path[0]]:
		# Actual mouse travel plus simulation: two segments per second.
		var destination: Vector2 = game.run.board.anchors[id]
		var start: Vector2 = previous
		for j in 30:
			advance(1.0/60.0)
			var next: Vector2 = start.lerp(destination,float(j+1)/30.0)
			drag(previous,next)
			previous = next
	mouse(previous,false)
	await refresh()

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-boss-native-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-boss-native-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.size = Vector2i(1280,900)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.render_loop_enabled = false
	prepare(3)
	var bell = game.run.boss()
	game.run.enemies = game.run.enemies.filter(func(e): return e.is_boss() or e.kind=="food")
	advance(4.0)
	await capture("boss-bellwether-inhale")
	var tissue: Sprite2D = game.microscope.enemies[bell.id].get_meta("lobes")[0]
	expect(tissue.material.get_shader_parameter("bell_breath")>0.9,"The Bellwether's visible tissue contracts with its real inhale")
	advance(4.2)
	await capture("boss-bellwether-open")
	await gesture([0,8,9,1])
	expect(game.run.harvest.boss_hits==1 and bell.health==2,"A native two-segments-per-second gesture damages the Bellwether during exhale")
	prepare(2)
	advance(4.0)
	await capture("boss-bell-bud-lesson")
	prepare(6)
	advance(3.0)
	await capture("boss-glass-cradle-lesson")
	expect(Guide.next_action(game.run).title=="Open the glass cradle","The preparatory encounter visibly instructs the shared shield mechanic")
	prepare(7)
	game.run.enemies = game.run.enemies.filter(func(e): return e.is_boss() or e.kind=="warden")
	var regent = game.run.boss()
	advance(3.0)
	await capture("boss-regent-shields")
	for pass_index in 2:
		var guard = game.run.enemies.filter(func(e): return e.kind=="warden")[0]
		var chosen: Array = []
		for path in game.run.board.triangles:
			if path.all(func(id): return game.run.is_ready(id)) and game.run.Geometry.contains(guard.nucleus,game.run.Geometry.polygon_for(path,game.run.board.anchors)):
				chosen = path
				break
		expect(not chosen.is_empty(),"The visible Regent shield has an available capture route")
		if not chosen.is_empty():
			await gesture(chosen)
		if pass_index==0:
			await capture("boss-regent-last-shield")
			advance(3.0)
	expect(regent.can_take_pulse(),"Two deliberate mouse captures open Regent before shield regeneration")
	await capture("boss-regent-open")
	advance(3.2)
	await gesture([0,8,9,1])
	expect(game.run.harvest.boss_hits==1,"Recovery leaves enough time for the actual charged Regent capture")
	prepare(11)
	game.run.enemies = [game.run.boss()]
	var twins = game.run.boss()
	advance(0.7)
	await capture("boss-conjoined-apart")
	advance(5.5)
	await capture("boss-conjoined-together")
	await gesture([0,8,9,1])
	expect(game.run.harvest.boss_hits==1 and twins.health==2,"Waiting for convergence permits the same human-speed paired-heart capture")
	advance(1.0)
	await capture("boss-conjoined-offspring")
	expect(game.run.enemies.any(func(e): return e.kind=="twinspore"),"The Conjoined releases a real young paired hunter")
	game.run.state = Run.BRIEF
	await capture("boss-conjoined-brief")
	game.journal_open = true
	game.hud.journal_page = 0
	game.large_text = true
	await capture("boss-pattern-journal")
	game.queue_free()
	await process_frame
	print("BOSS PATTERNS VISUAL: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
