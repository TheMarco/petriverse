extends SceneTree
## Focused Producer Lab fixture: deterministic rules + real loop captures.
const Rules = preload("res://scripts/producer_lab_rules.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("test_all")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func capture_at(game: Node, ids: Array) -> Dictionary:
	var run = game.run
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = run.board.anchors[ids[0]]
	game._unhandled_input(press)
	for id in ids.slice(1)+[ids[0]]:
		var motion := InputEventMouseMotion.new()
		motion.position = run.board.anchors[id]
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		game._unhandled_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = press.position
	game._unhandled_input(release)
	return run.last_capture

func centroid(game: Node, ids: Array) -> Vector2:
	var total := Vector2.ZERO
	for id in ids: total += game.run.board.anchors[id]
	return total / ids.size()

func test_all() -> void:
	# Escort rules: loop-rescue alone cannot win; a true arrival is required.
	var e = Rules.Escort.new()
	e.record_rescued(); e.record_rescued()
	expect(not e.is_won() and not e.is_doomed(), "Two loop-rescues without an arrival do not win")
	e.record_arrival()
	expect(e.is_won(), "Arrival plus rescued brood wins the escort")
	var doomed = Rules.Escort.new()
	doomed.record_lost(); doomed.record_lost()
	expect(doomed.is_doomed(), "Losing two of three brood makes the goal unreachable")
	var arc := Rules.escort_arc(Vector2(640, 450))
	expect(arc[0].distance_to(Vector2(640, 450)) > 200.0 and arc[-1].distance_to(Vector2(640, 450)) > 200.0, "Escort arc stays outside Mother")
	# Current rules: layouts and transport genuinely differ, both valid.
	var center := Vector2(640, 450)
	var chan: Dictionary = Rules.current_layout("channel", center)
	var shel: Dictionary = Rules.current_layout("shelter", center)
	expect(chan.food != shel.food, "Channel and shelter food positions differ")
	for layout in [chan, shel]:
		for p in layout.food + layout.cysts:
			expect(Rules.inside_dish(p, center), "Current layout keeps organisms inside dish away from Mother")
	var lane_spread := 0.0
	for p in chan.food: lane_spread = maxf(lane_spread, absf(p.y - chan.lane_y))
	expect(lane_spread < 30.0, "Channel food is concentrated in the moving lane")
	expect(Rules.current_velocity("channel", Vector2(640, 300), center, 0.0).x > 20.0, "Channel current is fast in the lane")
	expect(Rules.current_velocity("shelter", Vector2(640, 300), center, 0.0).length() < 8.0, "Shelter current is gentle")
	expect(Rules.current_velocity("channel", center, center, 0.0) == Vector2.ZERO, "Currents never transport Mother")
	# Boss phase rules: break triggers once, anchors move, later hits defeat.
	var bp = Rules.BossPhase.new()
	var before: Array = bp.shield_anchors(center)
	expect(not bp.apply_hit() and bp.phase_broken and bp.break_count == 1, "First boss hit breaks the shell once")
	expect(bp.shield_anchors(center) != before, "Shield anchors move to opposite flanks after the break")
	expect(not bp.apply_hit() and bp.break_count == 1, "Second hit does not re-trigger the break")
	expect(bp.apply_hit() and bp.defeated(), "Third hit defeats the boss")
	# Live scene: menu, pause/retry, and real captures in all three experiments.
	var scene: PackedScene = load("res://playtests/producer_lab.tscn")
	var game = scene.instantiate()
	game.audio_enabled = false
	root.add_child(game)
	await process_frame
	await process_frame
	expect(game.lab_phase == "menu" and game.save_records == false and game.journey_path.begins_with("/tmp/"), "Lab opens on Experiments menu with isolated /tmp state")
	game.select_experiment(1)
	expect(game.broods.size() == 3 and game.run.state == game.Run.PAUSED, "Safe passage spawns 3 identifiable brood, frozen at brief")
	game.begin_play()
	expect(game.run.state == game.Run.ACTIVE, "Start begins the escort")
	var middle: Vector2 = centroid(game, [0, 8, 9])
	game.broods[0].body.nucleus = middle; game.broods[0].body.origin = middle
	var result: Dictionary = capture_at(game, [0, 8, 9])
	game._process_captures()
	expect(result.valid and game.escort.rescued == 1 and not game.escort.is_won(), "Real loop rescue counts safe without winning")
	game.pause()
	expect(game.run.state == game.Run.PAUSED, "Pause freezes the escort")
	game.pause()
	expect(game.run.state == game.Run.ACTIVE, "Pause resumes the escort")
	game.retry_lab()
	expect(game.escort.safe_count() == 0 and game.broods.size() == 3 and game.lab_phase == "brief", "Retry resets the escort")
	game.begin_play()
	game._step_escort(50.0)
	game._check_end()
	expect(game.escort.arrived == 3 and game.lab_phase == "won", "Brood travelling the full arc arrive and win")
	game.select_experiment(2)
	game.choose_current("channel")
	var chan_food: Array = game.run.enemies.filter(func(b): return b.kind == "food")
	expect(chan_food.size() >= 5, "Channel spawns real food organisms")
	game.begin_play()
	chan_food[0].nucleus = middle; chan_food[0].origin = middle
	var before_food: int = game.run.harvest.nourishment
	result = capture_at(game, [0, 8, 9])
	expect(result.valid and game.run.harvest.nourishment > before_food, "Real food capture advances Choose the current")
	game.select_experiment(3)
	expect(game.boss_ref != null and game.boss_ref.health == 3, "Regent spawns with 3 health")
	var wardens: Array = game.run.enemies.filter(func(b): return b.kind == "warden")
	expect(wardens.size() == 2 and not game.boss_ref.can_take_pulse(), "Regent starts shielded by two wardens")
	game.begin_play()
	for w in wardens: w.nucleus = middle
	result = capture_at(game, [0, 8, 9])
	expect(result.valid and game.boss_ref.can_take_pulse(), "Capturing both wardens opens the Regent")
	game.boss_ref.nucleus = middle
	for cell in game.run.cells: cell.remaining = 0.0
	game.run.harvest.nourishment = 3
	result = capture_at(game, [0, 8, 9])
	game._process_captures()
	expect(result.get("boss_layers", 0) == 1 and game.boss_phase.phase_broken, "First real Regent hit breaks the shell in the live scene")
	expect(game.run.enemies.filter(func(b): return b.kind == "food").size() >= 3, "The break creates a safe feeding opening")
	# Real simulation loss leaves ACTIVE before the presentation frame.
	game.run.integrity = 0
	game.run.state = game.Run.LOSS
	game._process(0.0)
	expect(game.lab_phase=="lost", "Simulation death still reaches the lab failure screen")
	game.select_experiment(3)
	game.begin_play()
	game.run.boss_defeated = true
	game.run.state = game.Run.EVOLVE
	game._process(0.0)
	expect(game.lab_phase=="won", "Final boss capture reaches success after the campaign simulation settles")
	game.queue_free()
	await process_frame
	await process_frame
	print("PRODUCER LAB: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
