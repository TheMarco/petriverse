extends SceneTree
## Rules and presentation state for flow scoring, the swift-finish bonus,
## reward motes and rolling counters, overlay entrances, optics targets,
## encounter cards, boss windows and the critical heartbeat.
const Run = preload("res://scripts/run_controller.gd")
const Main = preload("res://scripts/main.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("exercise")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func meal(run: RefCounted, kinds: Array, path: Array) -> void:
	run.enemies.clear()
	var center := Vector2.ZERO
	for id in path:
		center += run.board.anchors[id]
	center /= path.size()
	for i in kinds.size():
		run.next_enemy_id += 1
		run.enemies.append(run.Harvest.Organism.new(run.next_enemy_id, kinds[i], center + Vector2((i - 1) * 6.0, 0.0), Vector2.ZERO, 0.0))

func ready_triangle(run: RefCounted, used: Array) -> Array:
	for triangle in run.board.triangles:
		if triangle.all(func(id): return run.is_ready(id) and not used.has(id)):
			return triangle
	return []

func capture(run: RefCounted, kinds: Array, used: Array) -> Dictionary:
	var path := ready_triangle(run, used)
	if path.is_empty():
		return {}
	used.append_array(path)
	meal(run, kinds, path)
	run.selection.start(run.board.anchors[path[0]])
	for id in path.slice(1):
		run.selection.visit(id)
	run.selection.visit(path[0])
	return run.release()

func wait(run: RefCounted, seconds: float) -> void:
	for i in int(seconds * 60.0):
		run.step(1.0 / 60.0)

func frames(game: Node2D, seconds: float, step: float = 1.0 / 30.0) -> void:
	for i in int(seconds / step):
		if game.run.state == Run.ACTIVE:
			game.run.step(step)
		game._process(step)

func exercise() -> void:
	# Flow: meaningful clean captures within three seconds chain a score bonus.
	var run := Run.new(true, 51, true, true)
	run.stage_index = 1
	run.start_stage()
	run.begin_encounter()
	var used: Array = []
	var first: Dictionary = capture(run, ["food", "food"], used)
	expect(first.get("valid", false) and first.flow == 1 and first.flow_bonus == 0, "A first capture starts a flow without a bonus")
	wait(run, 1.0)
	var score_before: int = run.score
	var second: Dictionary = capture(run, ["food"], used)
	expect(second.get("valid", false) and second.flow == 2 and second.flow_bonus == 40, "A second capture within three seconds continues the flow")
	expect(run.score - score_before == second.points and second.points == 25 + 40, "Flow adds only score: %d" % (run.score - score_before))
	wait(run, 1.0)
	var third: Dictionary = capture(run, ["food"], used)
	expect(third.get("valid", false) and third.flow == 3 and third.flow_bonus == 80, "The bonus grows with the chain")
	wait(run, 3.5)
	used.clear()
	var fourth: Dictionary = capture(run, ["food"], used)
	expect(fourth.get("valid", false) and fourth.flow == 1 and fourth.flow_bonus == 0, "A pause longer than three seconds starts a new flow")
	wait(run, 0.5)
	var poisoned: Dictionary = capture(run, ["food", "cyst"], used)
	expect(poisoned.get("valid", false) and poisoned.flow == 0 and poisoned.flow_bonus == 0, "Poison breaks the flow")
	expect(run.harvest.best_flow == 3, "The best flow of the encounter is remembered")
	var food_before: int = run.harvest.nourishment
	expect(food_before == 2 + 1 + 1 + 1 + 1, "Flow never changes the food awarded")
	# Swift finish: unused time becomes score; health keeps its bonus.
	run.stage_elapsed = 60.0
	var before: int = run.score
	var expected_swift := int(run.harvest.deadline() - 60.0) * 2
	run.finish_journey_stage()
	expect(run.stage_bonus.swift == expected_swift and run.score - before == run.integrity * 50 + expected_swift, "A swift finish converts unused seconds to score")
	expect(run.stage_bonus.flow == 3 and run.stage_bonus.health == run.integrity * 50, "The finish summary lists flow and health bonuses")
	run.dispose()
	var boss_run := Run.new(true, 52, true, true)
	boss_run.stage_index = 3
	boss_run.start_stage()
	boss_run.begin_encounter()
	boss_run.stage_elapsed = 30.0
	var boss_before: int = boss_run.score
	boss_run.finish_journey_stage()
	# A clean finish may also earn a 150-point feat; no time bonus is added.
	var boss_extra: int = boss_run.score - boss_before - boss_run.integrity * 50
	expect(boss_run.stage_bonus.swift == 0 and boss_extra >= 0 and boss_extra % 150 == 0, "Boss encounters keep their original finish score")
	boss_run.dispose()

	# Presentation: a real game scene with saves and audio off.
	var game: Node2D = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/petriverse-feel-journey.cfg"
	game.journey_profile.path = "/tmp/petriverse-feel-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var live = game.run
	live.stage_index = 1
	live.start_stage()
	game.reset_presentation()
	game._process(0.0)
	expect(game.optics.target_defocus() == game.optics.DIALOG_DEFOCUS, "The dish defocuses behind the briefing")
	var swells: int = game.soundscape.events_played.get("swell", 0)
	game.feel.last_card_dish = "Stillwater"
	live.begin_encounter()
	frames(game, 0.1)
	expect(not game.feel.card.is_empty() and game.feel.card.title == live.harvest.spec.name, "An encounter opens with its title card")
	expect(game.soundscape.events_played.get("swell", 0) == swells + 1, "The opening card has one swell")
	expect(game.optics.target_defocus() == 0.0, "Play is in focus")
	frames(game, 3.0)
	expect(game.feel.card.is_empty(), "The card leaves within three seconds")
	# Reward motes carry each unit of food; the counter never shows more than earned.
	game.hud.queue_redraw()
	game._process(0.0)
	used.clear()
	var gained: Dictionary = capture(live, ["food", "food", "food"], used)
	game._process(1.0 / 60.0)
	var actual: int = live.harvest.nourishment
	var shown: int = game.feel.shown("objective", actual)
	expect(gained.get("valid", false) and game.feel.motes.size() == 3, "Each unit of food travels as a mote")
	expect(shown < actual and shown >= 0, "The counter waits for its motes (%d of %d)" % [shown, actual])
	var popped := false
	for i in 40:
		game._process(1.0 / 30.0)
		popped = popped or game.feel.pop("objective") > 0.5
		expect(game.feel.shown("objective", live.harvest.nourishment) <= live.harvest.nourishment, "Displayed food never exceeds the real amount")
	expect(game.feel.motes.is_empty() and game.feel.shown("objective", live.harvest.nourishment) == live.harvest.nourishment and popped, "Every mote lands and the counter pops to the real value")
	expect(game.soundscape.events_played.get("mote", 0) >= 1 and game.soundscape.events_played.get("connect", 0) == 0, "Mote arrivals use their own cue, separate from cell selection")
	# The first cell's caption is drawn by the HUD above organisms, not by the dish.
	frames(game, 3.5)
	used.clear()
	var caption_path := ready_triangle(live, used)
	live.selection.start(live.board.anchors[caption_path[0]])
	expect(game.hud.draws_start_caption and game.start_caption() == "START", "Starting a loop is captioned START by the HUD")
	live.selection.visit(caption_path[1])
	live.selection.visit(caption_path[2])
	live.selection.visit(caption_path[0])
	expect(game.start_caption() == "RELEASE", "A closed loop is captioned RELEASE")
	live.selection.cancel()
	# Reduced motion: no travelling motes or shake; values settle at once.
	game.reduced_motion = true
	frames(game, 3.5)
	used.clear()
	capture(live, ["food", "food"], used)
	game._process(1.0 / 60.0)
	expect(game.feel.motes.is_empty() and game.feel.shown("objective", live.harvest.nourishment) == live.harvest.nourishment, "Reduced motion shows food at once")
	live.integrity -= 1
	game._process(1.0 / 60.0)
	expect(game.feel.shake == Vector2.ZERO and game.feel.hurt > 0.9, "Reduced motion keeps the injury flash without shaking")
	game.reduced_motion = false
	live.integrity -= 1
	game._process(1.0 / 60.0)
	game._process(1.0 / 60.0)
	expect(game.feel.trauma > 0.0 and game.view_offset() != game.dish_offset(), "An injury shakes the view")
	expect(game.to_dish(Vector2(640, 450)) == (Vector2(640, 450) - game.dish_offset()) / game.dish_scale(), "Shake never moves input mapping")
	# Critical health: a heartbeat sound and pulse while one organelle remains.
	live.integrity = 1
	var beats: int = game.soundscape.events_played.get("heartbeat", 0)
	frames(game, 4.0)
	expect(game.feel.critical > 0.9 and game.soundscape.events_played.get("heartbeat", 0) > beats, "Critical health beats audibly")
	live.integrity = 3
	frames(game, 2.0)
	expect(game.feel.critical < 0.5, "The heartbeat fades once health returns")
	# Overlay entrances: a real frame step animates; a zero step shows the result.
	game.pause()
	game._process(1.0 / 60.0)
	expect(game.hud.overlay_shown == "paused" and game.hud.overlay_layer.modulate.a < 0.5, "The pause menu fades in")
	for i in 20:
		game._process(1.0 / 60.0)
	expect(game.hud.overlay_layer.modulate.a > 0.99 and game.hud.center_button.modulate.a > 0.99, "The pause menu settles fully visible")
	expect(game.optics.target_defocus() == game.optics.DIALOG_DEFOCUS, "The dish defocuses behind the pause menu")
	game.pause()
	game._process(0.0)
	game.toggle_help()
	game._process(0.0)
	expect(game.hud.overlay_layer.modulate.a > 0.99, "A zero step shows dialogs fully, for fixtures and captures")
	game.toggle_help()
	game._process(0.0)
	# Boss windows: the opening of a vulnerable window is announced once.
	live.stage_index = 3
	live.start_stage()
	game.reset_presentation()
	live.begin_encounter()
	game._process(1.0 / 60.0)
	expect(game.feel.card.get("boss", false), "A boss encounter opens with a boss card")
	var boss = live.boss()
	expect(boss != null and not game.feel.boss_open, "The Bellwether starts closed")
	var announced := 0
	for i in 600:
		live.step(1.0 / 30.0)
		var before_numbers: int = game.feel.numbers.size()
		game._process(1.0 / 30.0)
		if game.feel.numbers.size() > before_numbers and game.feel.numbers[-1].text == "Open":
			announced += 1
		if boss.can_take_pulse():
			break
	expect(boss.can_take_pulse() and announced == 1 and game.feel.boss_open, "Its open window is announced exactly once")
	# Loss drains the dish.
	live.state = Run.LOSS
	frames(game, 2.0)
	expect(game.optics.saturation < 0.5, "A loss drains color from the dish")
	game.queue_free()
	await process_frame
	for file in ["/tmp/petriverse-feel-journey.cfg", "/tmp/petriverse-feel-profile.cfg"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	print("GAME FEEL: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
