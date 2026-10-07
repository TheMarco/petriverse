extends SceneTree
const Main = preload("res://scripts/main.gd")
const Run = preload("res://scripts/run_controller.gd")
const Enemy = preload("res://scripts/drifter.gd")
const Conjoined = preload("res://scripts/conjoined.gd")
var game: Node2D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("exercise")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func refresh() -> void:
	game._process(0.0)
	await process_frame
	await process_frame

func shot(filename: String) -> void:
	await refresh()
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		expect(root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png") == OK, "Saved " + filename)

func click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func visible_boss_loop() -> Array:
	# The old authored node IDs no longer surround the same water once the
	# colony wanders. Exercise the real, current geometry without freezing it.
	var run = game.run
	var hearts: PackedVector2Array = run.boss().nuclei()
	var ready: Array = range(run.cells.size()).filter(func(id): return run.is_ready(id))
	var best: Array = []
	var smallest := INF
	for a in ready.size():
		for b in range(a+1,ready.size()):
			for c in range(b+1,ready.size()):
				var path: Array = [ready[a],ready[b],ready[c]]
				var polygon: PackedVector2Array = run.Geometry.polygon_for(path,run.board.anchors)
				if not run.Geometry.validate(path,run.board.anchors,run.is_ready):
					continue
				if not Array(hearts).all(func(p): return run.Geometry.contains(p,polygon)):
					continue
				var area: float = run.Geometry.area(polygon)
				if area<smallest:
					smallest = area
					best = path
	expect(not best.is_empty(),"Both visible boss hearts fit a ready polygon on the moving board")
	return best

func exercise() -> void:
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = Main.new()
	game.run.dispose()
	game.run = Run.new(true, 103)
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.run.stage_index = 2
	game.run.add_mutation("fission")
	game.run.add_mutation("enzyme")
	game.run.enemies = [Enemy.new(101, Vector2(480, 300), 0.0, "shellback"), Enemy.new(102, Vector2(821, 315), 0.0, "shellback"), Enemy.new(103, Vector2(850, 575), 0.0, "twinspore"), Enemy.new(104, Vector2(420, 590), 0.0)]
	game.run.enemies[1].apply_pulse(1)
	game.visual_time = 8.0
	await shot("campaign-roster")
	expect(game.microscope.enemies.size() == 4, "The roster has four distinct rendered enemy groups")
	expect(game.microscope.enemies[103].get_meta("lobes").size() == 2 and game.microscope.enemies[103].has_meta("bridge"), "Twinspore renders two registered nuclei joined by living tissue")
	for enemy in game.run.enemies:
		var lobes: Array = game.microscope.enemies[enemy.id].get_meta("lobes")
		var sites: PackedVector2Array = enemy.nuclei()
		for i in lobes.size():
			var sprite: Sprite2D = lobes[i]
			var uv: Vector2 = sprite.material.get_shader_parameter("nucleus_uv")
			var visible_nucleus := sprite.to_global((uv - Vector2.ONE * 0.5) * sprite.texture.get_size() + sprite.offset)
			expect(visible_nucleus.distance_to(sites[i]) < 0.001, "Anatomical nucleus stays registered to the capture predicate")
	game.restart()
	game.run.encounter.spawned = game.run.encounter.budget
	game.run.encounter.resolved = game.run.encounter.budget
	game.run.check_completion()
	await shot("campaign-evolution")
	expect(game.hud.cards.all(func(card): return card.visible) and not game.hud.center_button.visible, "Evolution presents three eligible cards")
	var old_elapsed: float = game.run.elapsed
	game.run.step(20.0)
	expect(game.run.elapsed == old_elapsed, "The player has unlimited reading time during evolution")
	click(Vector2(370, 565))
	expect(game.run.state == "active" and game.run.stage_index == 1 and game.run.mutations.size() == 1, "A real mutation card click advances the run exactly once")
	game.run.enemies.clear()
	game.run.stage_index = 3
	game.run.start_stage()
	game.run.step(1.0)
	game.visual_time = 1.0
	await shot("campaign-conjoined-expanded")
	game.run.step(5.0)
	game.visual_time = 6.0
	var path: Array = visible_boss_loop()
	if path.is_empty():
		quit(1)
		return
	game.run.selection.start(game.run.board.anchors[path[0]])
	for id in path.slice(1):
		game.run.selection.visit(id)
	game.run.selection.visit(path[0])
	await shot("campaign-conjoined-window")
	expect(game.run.preview().has(game.run.boss().id), "The contracted boss's two hearts preview together")
	game.commit_selection()
	await refresh()
	expect(game.run.boss().health == 2 and not game.run.boss().can_take_pulse(), "A capture dissolves one layer and clearly enters reformation")
	game.run.step(3.0)
	for cycle in [1, 2]:
		var boss = game.run.boss()
		boss.age = cycle * Conjoined.CYCLE + 5.5
		game.run.step(0.1)
		path = visible_boss_loop()
		if path.is_empty():
			quit(1)
			return
		game.run.selection.start(game.run.board.anchors[path[0]])
		for id in path.slice(1):
			game.run.selection.visit(id)
		game.run.selection.visit(path[0])
		expect(game.run.preview().has(boss.id),"Current visible geometry previews the next boss hit")
		game.commit_selection()
		game.run.step(1.1 if cycle == 2 else 3.0)
	game.visual_time += 7.2
	await shot("campaign-final-digestion")
	expect(game.run.state == "success" and not game.hud.center_button.visible, "The final boss digestion stays visible before results")
	game.run.step(3.0)
	await shot("campaign-victory")
	expect(game.hud.center_button.visible and game.run.score >= 2500, "Victory presents the result and immediate replay")
	click(Vector2(640, 535))
	expect(game.run.state == "active" and game.run.stage_index == 0 and game.run.mutations.is_empty(), "Replay resets all campaign progression")
	game.toggle_sound_settings()
	await refresh()
	# Click the real settings controls wherever the dialog lays them out.
	click(game.hud.text_button.get_rect().get_center())
	click(game.hud.contrast_button.get_rect().get_center())
	click(game.hud.quality_button.get_rect().get_center())
	await refresh()
	expect(game.visual_quality == 1 and game.microscope.pond.specimens.filter(func(sprite): return sprite.visible).size() == 18 and game.microscope.pond.suspension.multimesh.visible_instance_count == 160, "Balanced detail reduces only decorative specimen and particle counts")
	click(game.hud.quality_button.get_rect().get_center())
	await refresh()
	expect(game.visual_quality == 0 and game.microscope.pond.specimens.filter(func(sprite): return sprite.visible).size() == 10 and game.microscope.pond.suspension.multimesh.visible_instance_count == 80, "Light detail keeps varied life with fewer decorative draws")
	game.toggle_sound_settings()
	await shot("campaign-light-detail")
	game.toggle_sound_settings()
	await refresh()
	click(game.hud.quality_button.get_rect().get_center())
	await refresh()
	expect(game.visual_quality == 2 and game.microscope.pond.specimens.filter(func(sprite): return sprite.visible).size() == 46 and game.microscope.pond.suspension.multimesh.visible_instance_count == 264, "Full detail restores every background organism and particle")
	await shot("campaign-comfort")
	expect(game.large_text and game.high_contrast, "Real comfort controls change text size and target contrast")
	game.toggle_sound_settings()
	await shot("campaign-larger-text")
	game.run.add_mutation("frenzy")
	game.run.enemies = [Enemy.new(901, (game.run.board.anchors[0] + game.run.board.anchors[8] + game.run.board.anchors[9]) / 3.0, 0.0), Enemy.new(902, (game.run.board.anchors[0] + game.run.board.anchors[8] + game.run.board.anchors[9]) / 3.0, 0.0), Enemy.new(903, (game.run.board.anchors[0] + game.run.board.anchors[8] + game.run.board.anchors[9]) / 3.0, 0.0)]
	game.run.selection.start(game.run.board.anchors[0])
	game.run.selection.visit(8)
	game.run.selection.visit(9)
	game.run.selection.visit(0)
	game.commit_selection()
	game.run.step_recovery(1.2)
	await shot("campaign-frenzy")
	expect(game.run.is_ready(0) and game.microscope.pulses[0].has_meta("channel"), "A restored starting cell receives a living feeding channel")
	game.restart()
	game.run.integrity = 2
	game.run.mother_damage.prepare_integrity(2)
	game.run.enemies = [Enemy.new(904, game.run.board.center + Vector2(92, 10), 0.0)]
	await shot("campaign-critical-warning")
	expect(game.run.critical_nuclei().size() == 1, "An approaching invader has a visual critical warning even with audio disabled")
	game.restart()
	game.run.enemies = [Enemy.new(905, game.run.board.center + Vector2(48, 0), 0.0, "shellback")]
	game.run.enemies[0].apply_pulse(1)
	game.run.resolve_contacts()
	game.run.step(0.8)
	await shot("campaign-shellback-bite")
	var shell_lobe: Sprite2D = game.microscope.invaders[1].get_meta("lobes")[0]
	expect(shell_lobe.texture == game.microscope.SHELLBACK and shell_lobe.material.get_shader_parameter("armor_damage") == 1.0, "A biting Shellback retains its own anatomy and cracked armor")
	game.restart()
	var biting_pair := Enemy.new(906, game.run.board.center + Vector2(65, 0), 0.0, "twinspore")
	biting_pair.pair_angle = 0.0
	game.run.enemies = [biting_pair]
	var contact_sites: PackedVector2Array = biting_pair.nuclei()
	game.run.resolve_contacts()
	game.run.step(0.8)
	await shot("campaign-twinspore-bite")
	var pair_body: Node2D = game.microscope.invaders[1]
	expect(pair_body.get_meta("lobes").size() == 2 and pair_body.has_meta("bridge"), "A biting Twinspore retains both bodies and its living tether")
	expect(game.run.integrity == 4 and game.run.mother_damage.bites[0].origin == contact_sites[0], "A paired impact damages once and consumes the organelle nearest the contacting nucleus")
	game.queue_free()
	await process_frame
	print("CAMPAIGN VISUAL: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
