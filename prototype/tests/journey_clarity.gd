extends "res://tests/harvest_visual.gd"
const Guide = preload("res://scripts/journey_guidance.gd")

func capture(name: String) -> void:
	# The fixture builds a held mouse path directly. Physical pointer motion
	# during a render must not redraw that path before its checked release.
	game.set_process_unhandled_input(false)
	await super.capture(name)
	game.set_process_unhandled_input(true)

func stage(index: int) -> void:
	game.run.stage_index = index
	game.run.start_stage()
	game.run.begin_encounter()
	game.toast_time = 0.0
	game.last_discovery = game.run.discovery_serial

func open_boss() -> void:
	game.run.enemies = game.run.enemies.filter(func(e): return e.kind != "warden")
	game.run.harvest.ecology.resolve_gates(game.run)

func select_path(path: Array) -> void:
	var run = game.run
	run.selection.cancel()
	run.selection.start(run.board.anchors[path[0]])
	for id in path.slice(1):
		run.selection.visit(id)
	run.selection.visit(path[0])

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-clarity-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-clarity-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	if "--payoff-only" in OS.get_cmdline_user_args():
		game.run.fixed_seed = 73
		game.run.restart()
		await payoff_example()
		finish()
		return
	stage(7)
	var run = game.run
	run.integrity = 2
	run.biomass = 120
	run.harvest.nourishment = 6
	run.harvest.boss_hits = 1
	run.boss().health = 2
	run.stage_elapsed = 120.0
	run.mutations = ["enzyme","elastic","filter","feast","residual","grazer","fission"]
	await capture("journey-clarity-closed")
	var boss = run.boss()
	var guide: Dictionary = Guide.next_action(run)
	expect(guide.title == "Break 2 shields" and guide.detail.contains("14 seconds"), "Full charge instructs the player to create a boss opening")
	expect(boss.gate_ids.has(guide.target) and boss.status_text() == "CAPTURE 2 SHIELDS", "Closed boss identifies its actual shield targets")
	expect(game.hud.help_button.visible and game.hud.trait_tooltips[0].tooltip_text.contains("two damage"), "Instructions and mutation effects are available in combat")
	if "--representative" in OS.get_cmdline_user_args():
		finish()
		return
	open_boss()
	expect(boss.can_take_pulse() and boss.seconds_until_close() == 14.0 and Guide.next_action(run).title == "Attack the boss now", "Advice switches at the exact Regent opening")
	await capture("journey-clarity-open")
	select_path([0,8,9,1])
	expect(run.selection.closed and Guide.next_action(run).title == "Release to attack", "Closed valid boss loop gets an explicit release action")
	expect(Guide.next_action(run,true).title == "Enter to attack", "Click input receives its correct commit key")
	await capture("journey-clarity-attack")
	game.commit_selection()
	expect(run.harvest.boss_hits == 2 and boss.health == 1, "The instructed attack really removes one boss layer")
	expect(boss.reset_remaining==4.0 and Guide.next_action(run).title == "Boss is reforming", "Post-hit feedback describes brief reformation")
	boss.step(4.0,run.board.center)
	run.harvest.ecology.spawn_gates(run)
	expect(not boss.can_take_pulse() and Guide.next_action(run).title == "Break 2 shields", "Reformed boss requires another player-created opening")
	open_boss()
	expect(boss.can_take_pulse(), "Removing the next shield set reopens the boss")
	run.harvest.nourishment = 1
	expect(Guide.next_action(run).title == "Collect 2 more food", "Insufficient attack charge states exact missing food")
	# Reproduce the user's state for paused contextual help.
	run.harvest.nourishment = 6
	key(KEY_H)
	await capture("journey-clarity-help")
	var elapsed: float = run.elapsed
	run.step(1.0)
	key(KEY_SPACE)
	key(KEY_ENTER)
	mouse(run.board.anchors[0],true)
	mouse(run.board.anchors[0],false)
	expect(game.help_open and run.state == Run.PAUSED and run.elapsed == elapsed and not run.selection.active, "Help pauses simulation and blocks click/keyboard gameplay")
	expect(game.hud.help_close.visible and not game.hud.center_button.visible and not game.hud.pause_button.visible, "Help exposes only its own close action")
	key(KEY_ESCAPE)
	expect(not game.help_open and run.state == Run.ACTIVE, "Closing help resumes an originally active encounter")
	game.pause()
	key(KEY_H)
	key(KEY_H)
	expect(run.state == Run.PAUSED, "Help does not resume an already paused encounter")
	game.pause()
	game.large_text = true
	key(KEY_H)
	await capture("journey-clarity-help-large")
	key(KEY_H)
	await capture("journey-clarity-large")
	game.large_text = false
	for index in [1,4,5,8]:
		stage(index)
		run.harvest.nourishment = run.harvest.spec.food
		guide = Guide.next_action(run)
		expect(not guide.title.contains("more food") and not Guide.objective_text(run).is_empty(), "Completed food objective reveals the remaining goal at stage %d" % index)
		await capture("journey-clarity-mode-%d" % index)
	stage(7)
	run.integrity = 1
	run.mutations.erase("filter") # This fixture must actually contain lethal poison.
	run.harvest.nourishment = 6
	open_boss()
	run.enemies.append(run.Harvest.Organism.new(999,"cyst",run.boss().nucleus,Vector2.ZERO,0.0))
	select_path([0,8,9,1])
	guide = Guide.next_action(run)
	expect(guide.urgent and guide.title == "This loop will kill you", "Lethal poison takes precedence over an otherwise valid boss attack")
	await capture("journey-clarity-lethal")
	stage(7)
	run.harvest.nourishment = 6
	run.enemies = [run.boss()]
	select_path([0,8,9,1])
	expect(Guide.next_action(run).title == "The boss is protected", "Closed shell enclosed by a loop does not promise an attack")
	game.commit_selection()
	expect(game.toast.contains("protected") and run.harvest.boss_hits == 0, "An early release explains why the boss was not captured [actual: %s]" % game.toast)
	stage(7)
	run.harvest.nourishment = 6
	run.enemies = [run.boss(),run.Harvest.Organism.new(991,"food",run.boss().nucleus,Vector2.ZERO,0.0)]
	select_path([0,8,9,1])
	game.commit_selection()
	expect(game.toast.contains("food") and game.toast.contains("protected") and run.harvest.boss_hits == 0, "Food collected with a protected boss reports both outcomes")
	stage(7)
	run.harvest.nourishment = 1
	run.enemies = [run.boss()] # No incidental food can charge this empty attack.
	select_path([0,8,9,1])
	expect(Guide.next_action(run).title == "Need 2 more food charge", "A boss inside an uncharged loop explains the missing charge")
	stage(11)
	run.harvest.nourishment = 6
	boss = run.boss()
	open_boss()
	# Put the boss midpoint on a triangle edge with one heart on each side.
	var a: Vector2 = run.board.anchors[0]
	var b: Vector2 = run.board.anchors[8]
	boss.nucleus = (a+b)*0.5
	boss.axes[0] = (b-a).orthogonal().normalized()
	select_path([0,8,9])
	expect(Guide.next_action(run).title == "Include BOTH gold centers", "One Conjoined heart inside explains the missing second target")
	await payoff_example()
	stage(0)
	await capture("journey-clarity-first-meal")
	run.state = Run.BRIEF
	game.large_text = true
	await capture("journey-clarity-brief-large")
	finish()

func payoff_example() -> void:
	var run = game.run
	stage(1)
	run.integrity = 5
	run.biomass = 0
	run.mutations = ["fission","grazer"]
	var meal_center: Vector2 = (run.board.anchors[0]+run.board.anchors[8]+run.board.anchors[9])/3.0
	run.enemies.clear()
	for id in [9001,9002]:
		var food = run.Harvest.Organism.new(id,"food",meal_center+Vector2((id-9001)*12,0),Vector2.ZERO,0.0)
		food.age = 5.0
		run.enemies.append(food)
	select_path([0,8,9])
	var upgraded: Dictionary = run.harvest_preview()
	expect(upgraded.food==4 and upgraded.food_bonuses=={"fission":1,"grazer":1},"A visible meal predicts both earned upgrade bonuses")
	await capture("journey-evolution-payoff-preview")
	var text_preference: bool = game.large_text
	game.large_text = true
	await capture("journey-evolution-payoff-preview-large")
	game.large_text = text_preference
	game.commit_selection()
	expect(game.toast.contains("Rapid Fission +1") and game.toast.contains("other upgrades +1") and run.last_capture.food==4,"Capture feedback names real upgrade contributions without awarding them twice")
	run.step(0.5)
	game._process(0.5)
	await capture("journey-evolution-payoff-capture")
	game.large_text = true
	await capture("journey-evolution-payoff-capture-large")
	game.large_text = text_preference

func finish() -> void:
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("JOURNEY CLARITY: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
