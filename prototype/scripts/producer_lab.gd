extends "res://scripts/main.gd"
## Producer Lab — Experiments. Standalone playtest scene; never writes a
## real journey/profile: all save paths point at /tmp and records are off.
const Rules = preload("res://scripts/producer_lab_rules.gd")
const Organism = preload("res://scripts/harvest_organism.gd")
const Predator = preload("res://scripts/journey_boss.gd")

class LabHud:
	extends "res://scripts/journey_hud.gd"
	func refresh() -> void:
		for c in managed_controls():
			if c != null: c.visible = false
		for child in get_children():
			if child is Control: child.hide()
		queue_redraw()
	func _draw() -> void:
		if game != null and game.has_method("draw_lab_hud"): game.draw_lab_hud(self)
	func draw_overlays() -> void:
		pass # The lab draws its own screens.

var lab_phase := "menu" # menu, choice, brief, playing, won, lost
var experiment := 0 # 1 Safe passage, 2 Choose the current, 3 The Regent breaks
var feedback := "Pick an experiment."
var escort = Rules.Escort.new()
var boss_phase = Rules.BossPhase.new()
var broods: Array = [] # {body, t}
var hunters: Array = [] # {body, pos}
var hunter_schedule: Array = []
var lab_remaining := 0.0
var lab_elapsed := 0.0
var current_choice := ""
var boss_ref: RefCounted = null
var boss_hits_seen := 0
var seen_capture := 0
var buttons := {}
var ui_layer: CanvasLayer
var phase_synced := ""

func _init() -> void:
	save_records = false
	preferences_enabled = false
	creature_intros_enabled = false
	show_home_on_start = false
	journey_path = "/tmp/petriverse-producer-lab-journey.cfg"
	journey_profile.path = "/tmp/petriverse-producer-lab-profile.cfg"
	preferences_path = "/tmp/petriverse-producer-lab-preferences.cfg"

func _ready() -> void:
	super._ready()
	readable_ui.queue_free()
	readable_ui = null
	hud.queue_free()
	hud = LabHud.new()
	add_child(hud)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	_make_buttons()
	show_menu()
	DisplayServer.window_set_title("PETRIVERSE — Experiments (Producer Lab)")

func comfort_layout() -> bool:
	return false

func _make_buttons() -> void:
	var defs := [
		["exp1", "1 · Safe passage", Vector2(340, 560), Callable(self, "select_experiment").bind(1)],
		["exp2", "2 · Choose the current", Vector2(340, 612), Callable(self, "select_experiment").bind(2)],
		["exp3", "3 · The Regent breaks", Vector2(340, 664), Callable(self, "select_experiment").bind(3)],
		["exit", "Exit to title · Q", Vector2(340, 780), Callable(self, "exit_to_title")],
		["chan", "1 · Fast channel", Vector2(340, 560), Callable(self, "choose_current").bind("channel")],
		["shel", "2 · Sheltered eddy", Vector2(640, 560), Callable(self, "choose_current").bind("shelter")],
		["start", "Start · Enter", Vector2(340, 716), Callable(self, "begin_play")],
		["retry", "Retry · R / Enter", Vector2(340, 716), Callable(self, "retry_lab")],
		["resume", "Resume · Space", Vector2(340, 664), Callable(self, "pause")],
		["pause", "Pause · Space", Vector2(1060, 620), Callable(self, "pause")],
		["menu", "Experiments menu", Vector2(640, 716), Callable(self, "show_menu")],
	]
	for d in defs:
		var b := Button.new()
		b.name = d[0]; b.text = d[1]; b.position = d[2]; b.size = Vector2(180 if d[0]=="pause" else 300, 44)
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.theme = UI.theme()
		UI.style_button(b, "secondary", 15)
		b.pressed.connect(d[3])
		ui_layer.add_child(b)
		buttons[d[0]] = b

func show_menu() -> void:
	lab_phase = "menu"; experiment = 0
	broods.clear(); hunters.clear(); boss_ref = null
	if run != null:
		run.enemies.clear(); run.selection.cancel(); run.state = Run.PAUSED
	feedback = "Pick an experiment."

func exit_to_title() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func return_home() -> void: show_menu()

func restart() -> void:
	if lab_phase != "menu" and experiment > 0: select_experiment(experiment)

func retry_lab() -> void:
	if experiment > 0: select_experiment(experiment)

func pause() -> void:
	if lab_phase == "playing": run.toggle_pause()

func select_experiment(id: int) -> void:
	experiment = id
	escort = Rules.Escort.new()
	boss_phase = Rules.BossPhase.new()
	broods.clear(); hunters.clear(); hunter_schedule.clear()
	boss_hits_seen = 0; seen_capture = run.capture_serial
	lab_elapsed = 0.0
	_setup_common(7 if id == 3 else 0)
	if id == 1: _setup_escort()
	elif id == 2:
		current_choice = ""
		lab_phase = "choice"
		feedback = "Same seeded dish. Choose a current — forecast is shown above."
		return
	elif id == 3: _setup_boss()
	lab_phase = "brief"

func _setup_common(stage: int) -> void:
	run.selection.cancel()
	run.lesson_step = -1
	run.route_plan.clear()
	run.stage_index = stage
	run.start_stage()
	run.enemies.clear(); run.clots.clear(); run.residuals.clear()
	run.harvest.last_refill = 99999.0
	run.harvest.event_state = {}
	run.harvest.visitor_at = -1.0
	run.harvest.next_bloom = 99999.0
	run.harvest.ecology.next_wave = 99999.0
	run.harvest.ecology.pending.clear()
	run.harvest.final_surge_enabled = false
	run.harvest.spec = {"mode": "boss" if experiment == 3 else "feed", "duration": 99999.0, "food": 999, "target": 999, "threats": 0}
	run.max_integrity = 5
	run.mother_damage.set_capacity(5)
	run.integrity = 5
	run.harvest.nourishment = 0
	for cell in run.cells: cell.remaining = 0.0
	run.state = Run.PAUSED

func _add_organism(kind: String, at: Vector2) -> RefCounted:
	run.next_enemy_id += 1
	var body := Organism.new(run.next_enemy_id, kind, at, Vector2.ZERO, float(run.next_enemy_id) * 1.7)
	run.enemies.append(body)
	return body

func _setup_escort() -> void:
	lab_remaining = Rules.ESCORT_SECONDS
	for i in Rules.BROOD_TOTAL:
		var body = _add_organism("spore", Rules.arc_point(run.board.center, 0.0))
		broods.append({"body": body, "t": -0.09 * i})
	for i in 3:
		hunter_schedule.append({"at": 13.0 + i * 17.0, "warned": false, "spawned": false,
			"pos": run.board.center + (Vector2(-298, -198) if i % 2 == 0 else Vector2(298, -208))})
	feedback = "Escort the pearl brood along the arc."

func _setup_boss() -> void:
	lab_remaining = 120.0
	run.next_enemy_id += 1
	boss_ref = Predator.new(run.next_enemy_id, run.board, 1)
	boss_ref.health = Rules.BOSS_HEALTH
	run.enemies.append(boss_ref)
	run.harvest.ecology.spawn_gates(run)
	run.harvest.nourishment = 3
	for i in 3:
		_add_organism("food", run.board.center + Vector2(-120 + i * 110, 215))
	feedback = "Break both shield wardens, then loop the open Regent. A hit costs 3 food charge."

func choose_current(choice: String) -> void:
	current_choice = choice
	var layout: Dictionary = Rules.current_layout(choice, run.board.center)
	for p in layout.food: _add_organism("food", p)
	for p in layout.cysts: _add_organism("cyst", p)
	lab_remaining = Rules.CURRENT_SECONDS
	lab_phase = "brief"
	feedback = "Fast channel: rich moving lane, poison beside it." if choice == "channel" else "Sheltered eddy: small safe pockets, gentle current."

func begin_play() -> void:
	if lab_phase in ["brief", "choice"] and experiment > 0:
		if lab_phase == "choice": choose_current("channel")
		lab_phase = "playing"
		run.state = Run.ACTIVE

func _process(delta: float) -> void:
	super._process(delta)
	if lab_phase == "playing":
		_process_captures()
		_check_end()
	if lab_phase == "playing" and run.state == Run.ACTIVE:
		lab_elapsed += delta
		lab_remaining = maxf(0.0, lab_remaining - delta)
		if experiment == 1: _step_escort(delta)
		elif experiment == 2: _step_current(delta)
		elif experiment == 3: _step_boss(delta)
		_check_end()
	elif lab_phase in ["brief", "choice", "menu"]:
		_sync_frozen()
	_sync_buttons()
	queue_redraw()

func _sync_frozen() -> void:
	for entry in broods:
		entry.body.nucleus = Rules.arc_point(run.board.center, maxf(0.0, entry.t))
		entry.body.origin = entry.body.nucleus
	if experiment == 3 and boss_ref != null and boss_phase.phase_broken:
		_position_wardens()

func _step_escort(delta: float) -> void:
	for entry in hunter_schedule:
		if not entry.warned and lab_elapsed >= entry.at - 3.0:
			entry.warned = true
			feedback = "Warning · a hunter is approaching the arc in 3s — watch the marked rim."
		if not entry.spawned and lab_elapsed >= entry.at:
			entry.spawned = true
			run.spawn_enemy({"position": entry.pos, "speed": 0.0, "kind": "drifter", "angle": 0.0, "radius": 0.0})
			hunters.append({"body": run.enemies[-1], "pos": entry.pos})
	for entry in broods:
		entry.t += delta * 0.024
		entry.body.age = minf(entry.body.age, 10.0)
		entry.body.nucleus = Rules.arc_point(run.board.center, clampf(entry.t, 0.0, 1.0))
		entry.body.origin = entry.body.nucleus
		if entry.t >= 1.0 and not entry.get("done", false):
			entry.done = true
			escort.record_arrival()
			run.enemies.erase(entry.body)
			feedback = "A brood arrived under its own travel · %d safe, %d arrived." % [escort.safe_count(), escort.arrived]
	broods = broods.filter(func(e): return not e.get("done", false))
	for h in hunters:
		if not run.enemies.has(h.body): continue
		var target: Vector2 = h.pos
		var best := INF
		for entry in broods:
			var d: float = h.pos.distance_squared_to(entry.body.nucleus)
			if d < best: best = d; target = entry.body.nucleus
		h.pos = h.pos.move_toward(target, 30.0 * delta)
		h.body.nucleus = h.pos
		for entry in broods.duplicate():
			if h.pos.distance_to(entry.body.nucleus) < 24.0:
				escort.record_lost()
				run.enemies.erase(entry.body)
				run.enemies.erase(h.body)
				broods.erase(entry)
				feedback = "A hunter ate a brood · %d lost. Too many lost ends the escort." % escort.lost
				break
	hunters = hunters.filter(func(h): return run.enemies.has(h.body))

func _step_current(delta: float) -> void:
	for body in run.enemies:
		if body.kind in ["food", "cyst"]:
			body.age = minf(body.age, 20.0)
			var v: Vector2 = Rules.current_velocity(current_choice, body.nucleus, run.board.center, lab_elapsed)
			var next: Vector2 = body.nucleus + v * delta
			if not Rules.inside_dish(next, run.board.center):
				next = body.nucleus - v * delta
				if current_choice == "channel" and body.kind == "food":
					next = Vector2(run.board.center.x - 285.0, Rules.current_layout("channel", run.board.center).lane_y)
			body.origin = next; body.nucleus = next
	# Keep the goal achievable as organisms are eaten or expire.
	var foods: int = run.enemies.filter(func(e): return e.kind == "food").size()
	if foods < 5 and lab_remaining > 4.0:
		var layout: Dictionary = Rules.current_layout(current_choice, run.board.center)
		_add_organism("food", layout.food[foods % layout.food.size()])

func _step_boss(_delta: float) -> void:
	if boss_ref == null: return
	if boss_phase.phase_broken: _position_wardens()
	if boss_ref.open_remaining > 0.0:
		feedback = "Regent OPEN for %ds · loop it now (needs 3 charge, have %d)." % [ceili(boss_ref.open_remaining), run.harvest.nourishment]

func _position_wardens() -> void:
	if boss_ref == null: return
	var anchors: Array = boss_phase.shield_anchors(boss_ref.nucleus)
	var wardens: Array = run.enemies.filter(func(e): return e.kind == "warden")
	for i in mini(wardens.size(), anchors.size()):
		wardens[i].nucleus = anchors[i]
		wardens[i].destination = anchors[i]

func _process_captures() -> void:
	if run.capture_serial == seen_capture: return
	seen_capture = run.capture_serial
	var ids: Array = run.last_capture.get("ids", [])
	if experiment == 1:
		for entry in broods.duplicate():
			if ids.has(entry.body.id):
				broods.erase(entry)
				escort.record_rescued()
				feedback = "Brood rescued inside your loop · counts safe, but a win still needs 1 true escorted arrival (%d arrived)." % escort.arrived
	elif experiment == 2:
		if int(run.last_capture.get("food", 0)) > 0:
			feedback = "Food gathered %d / %d · cysts in a loop poison Mother." % [run.harvest.nourishment, Rules.CURRENT_GOAL]
	elif experiment == 3 and run.harvest.boss_hits > boss_hits_seen:
		boss_hits_seen = run.harvest.boss_hits
		var defeated: bool = boss_phase.apply_hit()
		if boss_phase.break_count == 1 and boss_hits_seen == 1:
			feedback = "The Regent breaks! Shell cracked · shields swing to opposite flanks · a safe feeding opening appears below."
			_position_wardens()
			for i in 3:
				_add_organism("food", boss_ref.nucleus + Vector2(-70 + i * 70, 130))
		elif not defeated:
			feedback = "Regent hit · %d health left. Re-break its shields during the open window." % boss_phase.health

func _check_end() -> void:
	if run.integrity <= 0:
		return _finish(false, "Mother died.")
	if experiment == 1:
		if escort.is_won(): return _finish(true, "Safe passage complete · %d arrived, %d loop-rescued." % [escort.arrived, escort.rescued])
		if escort.is_doomed(): return _finish(false, "Too many brood lost to reach %d safe with a true arrival." % Rules.BROOD_SAFE_NEEDED)
	elif experiment == 2:
		if run.harvest.nourishment >= Rules.CURRENT_GOAL: return _finish(true, "Current mastered · gathered %d food." % run.harvest.nourishment)
	elif experiment == 3:
		if boss_phase.defeated() or run.boss_defeated: return _finish(true, "The Regent is defeated.")
	if lab_remaining <= 0.0:
		_finish(false, "Time ran out.")

func _finish(won: bool, why: String) -> void:
	lab_phase = "won" if won else "lost"
	feedback = why
	run.state = Run.PAUSED
	run.selection.cancel()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_H,KEY_J,KEY_V]: return
		match event.keycode:
			KEY_Q: exit_to_title(); return
			KEY_1:
				if lab_phase == "menu": select_experiment(1); return
				if lab_phase == "choice": choose_current("channel"); return
			KEY_2:
				if lab_phase == "menu": select_experiment(2); return
				if lab_phase == "choice": choose_current("shelter"); return
			KEY_3:
				if lab_phase == "menu": select_experiment(3); return
			KEY_ENTER, KEY_KP_ENTER:
				if lab_phase == "brief": begin_play(); return
				if lab_phase in ["won", "lost"]: retry_lab(); return
			KEY_ESCAPE:
				if lab_phase in ["brief", "choice", "won", "lost"]: show_menu(); return
	if lab_phase == "playing":
		super._unhandled_input(event)
	elif lab_phase in ["won", "lost"] and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		retry_lab()

func _sync_buttons() -> void:
	var show := {"menu": ["exp1", "exp2", "exp3", "exit"], "choice": ["chan", "shel", "menu"],
		"brief": ["start", "menu"], "won": ["retry", "menu", "exit"], "lost": ["retry", "menu", "exit"],
		"playing": ["resume","menu","exit"] if run.state == Run.PAUSED else ["pause"]}
	for name in buttons: buttons[name].visible = show.get(lab_phase, []).has(name)
	if lab_phase != phase_synced:
		phase_synced = lab_phase
		var primary: String = {"menu": "exp1", "choice": "chan", "brief": "start", "won": "retry", "lost": "retry"}.get(lab_phase, "")
		if buttons.has(primary): buttons[primary].call_deferred("grab_focus")

func _draw() -> void:
	super._draw()
	var c: Vector2 = run.board.center
	if experiment == 1:
		var arc := Rules.escort_arc(c)
		draw_polyline(arc, Color(0.55, 0.9, 0.85, 0.5), 3.0, true)
		draw_circle(arc[-1], 16, Color(0.6, 1, 0.8, 0.35))
		draw_circle(arc[-1], 16, Color(0.8, 1, 0.9), false, 2.0, true)
		for brood in broods:
			draw_circle(brood.body.nucleus,18,Color(0.8,1,0.9,0.7),false,1.6,true)
		for entry in hunter_schedule:
			if entry.warned and not entry.spawned:
				draw_circle(entry.pos, 14 + 4 * sin(visual_time * 6), Color(1, 0.5, 0.4, 0.8), false, 3.0, true)
	elif experiment == 2 and current_choice != "":
		if current_choice == "channel":
			var y: float = Rules.current_layout("channel", c).lane_y
			for i in 7:
				var x := c.x - 270.0 + i * 88.0
				draw_line(Vector2(x, y), Vector2(x + 42, y), Color(0.5, 0.85, 1, 0.8), 3.0, true)
				draw_line(Vector2(x + 42, y), Vector2(x + 30, y - 7), Color(0.5, 0.85, 1, 0.8), 3.0, true)
				draw_line(Vector2(x + 42, y), Vector2(x + 30, y + 7), Color(0.5, 0.85, 1, 0.8), 3.0, true)
		else:
			for p in Rules.current_layout("shelter", c).pockets:
				draw_arc(p, 62, 0.3 + visual_time * 0.4, 2.2 + visual_time * 0.4, 24, Color(0.5, 0.9, 0.8, 0.7), 3.0, true)
	elif experiment == 3 and boss_ref != null:
		for w in run.enemies:
			if w.kind == "warden":
				draw_line(boss_ref.nucleus, w.nucleus, Color(1, 0.75, 0.4, 0.85), 3.0, true)
		if boss_phase.phase_broken:
			draw_arc(boss_ref.nucleus, 58, 0, TAU, 40, Color(1, 0.45, 0.35, 0.9), 4.0, true)

func draw_lab_hud(h: Node2D) -> void:
	var ink: Color = h.INK; var mut: Color = h.MUTED; var cy: Color = h.CYAN
	if lab_phase != "playing" or run.state == Run.PAUSED:
		h.draw_style_box(UI.box(Color(0.016,0.043,0.052,0.97),18,UI.LINE),Rect2(90,130,1100,710) if lab_phase=="menu" else Rect2(250,160,780,680))
	h.label_at("EXPERIMENTS · Producer Lab", Vector2(40, 48), 22, ink, UI.SEMIBOLD)
	if lab_phase == "menu":
		h.centered("Choose an experiment", 190, 30)
		h.centered("1 · Safe passage — escort 3 pearl brood along the arc. Loop hunters away.", 250, 16, cy)
		h.centered("Looping a brood rescues it safely, but a win needs at least 1 true arrival. Need 2 safe.", 282, 14, mut)
		h.centered("2 · Choose the current — same dish, fast channel or sheltered eddy. Gather 8 food.", 330, 16, cy)
		h.centered("3 · The Regent breaks — break shields, hit the open Regent; its shell breaks after hit 1.", 410, 16, cy)
		h.centered("Keyboard: 1/2/3 select · Enter start/retry · Space pause · R retry · Q exit to title", 480, 14, mut)
		return
	var title: String = {1: "Safe passage", 2: "Choose the current", 3: "The Regent breaks"}.get(experiment, "")
	h.label_at(title, Vector2(40, 84), 18, cy, UI.SEMIBOLD)
	var status := ""
	if experiment == 1: status = "Safe %d/%d · arrived %d · rescued %d · lost %d · %.0fs" % [escort.safe_count(), Rules.BROOD_SAFE_NEEDED, escort.arrived, escort.rescued, escort.lost, lab_remaining]
	elif experiment == 2: status = "Food %d/%d · Mother %d · %.0fs · %s" % [run.harvest.nourishment, Rules.CURRENT_GOAL, run.integrity, lab_remaining, current_choice]
	elif experiment == 3: status = "Regent health %d · charge %d/3 · Mother %d · %.0fs · %s" % [boss_phase.health, run.harvest.nourishment, run.integrity, lab_remaining, "SHELL BROKEN" if boss_phase.phase_broken else "shell intact"]
	h.wrapped(status, Vector2(40, 104), 190, 15, ink)
	h.wrapped(feedback, Vector2(1060, 104), 180, 15, ink)
	if lab_phase == "choice":
		h.centered("Forecast — Channel: food rides a fast lane; purple cysts wait just below it.", 250, 17, cy)
		h.centered("Forecast — Shelter: three small safe pockets in slow eddies; cysts far below.", 286, 17, cy)
		h.centered("Both need %d food in %ds. Currents never push Mother or her blue cells." % [Rules.CURRENT_GOAL, int(Rules.CURRENT_SECONDS)], 330, 15, ink)
	elif lab_phase == "brief":
		h.centered("How to play", 210, 24)
		var lines := {
			1: "Drag through at least 3 blue cells, return to START, then release. Enclose hunters to remove them.\nBrood follow the glowing arc. Enclosing a brood rescues it — safe, but not an arrival.\nLose too many brood, run out of time, or lose Mother and the experiment fails.",
			2: "Connect 3+ blue cells around food, return to START, then release. Avoid purple cysts.\nWatch the arrows: the current really carries food. Keep loops clean and quick.",
			3: "Loop both gold shield wardens to open the Regent, then loop the Regent (costs 3 food charge).\nAfter the first hit its shell breaks, shields move to opposite flanks, and food opens below it."}
		var by := 280.0
		for line in lines.get(experiment, "").split("\n"):
			by = h.wrapped_centered(line, by, 560, 16, ink) + 26.0
		h.centered("Space pauses · R retries · Esc returns from this brief", 680, 14, mut)
	elif lab_phase == "won": h.centered("SUCCESS", 210, 34, Color(0.6, 1, 0.75))
	elif lab_phase == "lost": h.centered("FAILED", 210, 34, Color(1, 0.6, 0.5))
	elif run.state == Run.PAUSED: h.centered("PAUSED", 210, 30)
	if lab_phase == "playing" and run.state == Run.ACTIVE:
		var detail := "Space pauses · R retries · Q returns to title"
		if run.selection.can_close():
			var meal: Dictionary = run.harvest_preview()
			detail = CaptureFeedback.summary(meal)+" · "+CaptureFeedback.health_text(meal,run.integrity)
		elif toast_time>0: detail = toast
		h.wrapped_centered(detail,870,820,14,cy)
