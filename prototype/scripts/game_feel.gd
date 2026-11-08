extends Node2D
## Presentation only: capture rewards, impacts and danger cues.
## Observes Run after each step. Never changes rules, timing or eligibility.

const UI = preload("res://scripts/ui_style.gd")
const Journey = preload("res://scripts/journey_plan.gd")
const HEARTBEAT := 1.45 # seconds between beats while the Mother is critical
const PEARL := Color("d8f6ee")
const FOOD := Color("c6eba4")
const DANGER := Color("f2a3c4")
const WARM := Color("edb184")
const NOTES := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
const MAX_MOTES := 14
const MOTE_FLIGHT := 0.72
const MOTE_STAGGER := 0.065

var game: Node2D
var glow: Node2D # additive layer for light: motes, sparks, flashes
var ink: Node2D # normal blend layer for readable numbers
var dot: Texture2D
var rim: Texture2D
var clock := 0.0

var last_capture := 0
var last_integrity := -1
var last_state := ""
var last_objective := -1
var last_biomass := -1
var last_score := -1

var motes: Array = [] # {from, to, control, age, delay, units, color, note}
var sparks: Array = [] # {at, velocity, age, life, size, color}
var flashes: Array = [] # {polygon, age, color, life}
var numbers: Array = [] # {at, text, detail, age, life, color, size}
var counters := {} # name -> {shown: float, target: int, pop: float}
var trauma := 0.0
var shake := Vector2.ZERO
var hurt := 0.0 # brief rim flash after mother damage
var hurt_pip := -1
var heal_glow := 0.0
var critical := 0.0 # eased presence of the critical-health pulse
var celebration := 0.0
var card: Dictionary = {} # {caption, title, detail, age, life, color, boss}
var last_card_dish := ""
var beat_clock := 0.0
var tracked: Font
var rings: Array = [] # {at (dish), age, life, from, to, color, width}
var last_path_size := 0
var last_closed := false

func _ready() -> void:
	game = get_parent()
	z_index = 20
	dot = radial_texture(64, [0.0, 0.22, 0.55, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.72), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0)])
	rim = radial_texture(256, [0.0, 0.80, 0.93, 0.985, 1.0], [Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	glow = Node2D.new()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	glow.draw.connect(draw_glow)
	add_child(glow)
	ink = Node2D.new()
	ink.draw.connect(draw_ink)
	add_child(ink)
	var spaced := FontVariation.new()
	spaced.base_font = UI.font(UI.SEMIBOLD)
	spaced.spacing_glyph = 3
	tracked = spaced

static func radial_texture(size_px: int, offsets: Array, colors: Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = size_px
	texture.height = size_px
	return texture

## Screen position of a point in dish coordinates, including the comfort reflow.
func screen(point: Vector2) -> Vector2:
	if game.has_method("dish_scale"):
		return point * game.dish_scale() + game.dish_offset() + shake
	return point + shake

func motion() -> bool:
	return not game.reduced_motion

func detail() -> int:
	return int(game.visual_quality)

## Rolling counters let the HUD show values arriving rather than jumping.
func shown(name: String, actual: int) -> int:
	if not counters.has(name):
		counters[name] = {"shown": float(actual), "target": actual, "pop": 0.0, "held": 0}
	var counter: Dictionary = counters[name]
	counter.target = actual
	return clampi(int(floor(counter.shown + 0.001)), 0, maxi(actual, 0)) if actual >= counter.shown else actual

func pop(name: String) -> float:
	return float(counters.get(name, {}).get("pop", 0.0))

func held_units(name: String) -> int:
	var units := 0
	for mote in motes:
		if mote.control == name:
			units += int(mote.units)
	return units

func reset() -> void:
	motes.clear()
	sparks.clear()
	flashes.clear()
	numbers.clear()
	rings.clear()
	counters.clear()
	trauma = 0.0
	shake = Vector2.ZERO
	hurt = 0.0
	heal_glow = 0.0
	celebration = 0.0
	last_capture = game.run.capture_serial
	last_integrity = game.run.integrity
	last_state = game.run.state
	last_objective = -1
	last_biomass = -1
	last_score = -1

func update(delta: float) -> void:
	var run = game.run
	if last_integrity < 0:
		reset()
	var paused: bool = run.state == "paused" or game.help_open or game.journal_open or game.settings_open
	if run.capture_serial != last_capture:
		if run.capture_serial > last_capture and not run.last_capture.is_empty():
			on_capture(run.last_capture)
		last_capture = run.capture_serial
	if run.integrity < last_integrity and run.state != "home":
		on_injury(last_integrity - run.integrity)
	elif run.integrity > last_integrity and last_integrity >= 0 and run.state in ["active", "brief", "evolve"]:
		heal_glow = 1.0
	last_integrity = run.integrity
	if run.state != last_state:
		on_state(last_state, run.state)
		last_state = run.state
	track_counters()
	observe_selection()
	if paused:
		queue_draw()
		return
	clock += delta
	advance(delta)
	queue_draw()

## Small acknowledgements while drawing: each new cell answers with a ring,
## and closing the loop rings the first cell more strongly.
func observe_selection() -> void:
	var selection = game.run.selection
	var size: int = selection.path.size() if selection.active else 0
	if game.run.state == "active" and size > last_path_size and size > 0:
		var id: int = selection.path[-1]
		rings.append({"at": game.run.board.anchors[id], "age": 0.0, "life": 0.38, "from": 26.0, "to": 44.0, "color": PEARL, "width": 1.6})
	var closed: bool = selection.active and selection.closed
	if closed and not last_closed and size > 0:
		var first: int = selection.path[0]
		rings.append({"at": game.run.board.anchors[first], "age": 0.0, "life": 0.55, "from": 30.0, "to": 64.0, "color": PEARL, "width": 2.4})
	last_path_size = size
	last_closed = closed

func queue_draw() -> void:
	glow.queue_redraw()
	ink.queue_redraw()

func track_counters() -> void:
	var run = game.run
	if run.harvest == null:
		last_objective = -1
		return
	# Objective food rises as each mote lands; a drop (spent charge, new dish)
	# is shown at once. Values never display above the real amount.
	var objective: int = run.harvest.nourishment
	if not counters.has("objective"):
		counters["objective"] = {"shown": float(maxi(0, objective - held_units("objective"))), "target": objective, "pop": 0.0}
	var counter: Dictionary = counters.objective
	if objective < int(counter.target):
		counter.shown = float(maxi(0, objective - held_units("objective")))
	counter.target = objective
	last_objective = objective
	for name in ["biomass", "score"]:
		var actual: int = run.biomass if name == "biomass" else run.score
		if not counters.has(name):
			counters[name] = {"shown": float(actual), "target": actual, "pop": 0.0}
		if actual < int(counters[name].shown):
			counters[name].shown = float(actual)

func advance(delta: float) -> void:
	# Counters roll toward their target; a pop marks each visible increment.
	for name in counters:
		var counter: Dictionary = counters[name]
		counter.pop = maxf(0.0, counter.pop - delta * 3.2)
		if name == "objective":
			var settled := float(int(counter.target) - held_units("objective"))
			if settled > counter.shown + 0.001:
				counter.shown = settled
				counter.pop = 1.0
			continue
		var target := float(counter.target)
		if counter.shown < target:
			var before := int(counter.shown)
			var rate := maxf(12.0, (target - counter.shown) * 3.5)
			counter.shown = minf(target, counter.shown + rate * delta)
			if int(counter.shown) != before:
				counter.pop = maxf(counter.pop, 0.55)
	trauma = maxf(0.0, trauma - delta * 1.7)
	if motion() and trauma > 0.0:
		var power := trauma * trauma * 5.0
		shake = Vector2(sin(clock * 47.0) + sin(clock * 83.0 + 1.3) * 0.5, cos(clock * 53.0 + 0.4) + sin(clock * 71.0) * 0.5) * power / 1.5
	else:
		shake = Vector2.ZERO
	hurt = maxf(0.0, hurt - delta * 1.4)
	heal_glow = maxf(0.0, heal_glow - delta * 0.8)
	celebration = maxf(0.0, celebration - delta * 0.45)
	var run = game.run
	var target_critical := 1.0 if run.state == "active" and run.integrity <= 1 and run.max_integrity >= 3 else 0.0
	critical = move_toward(critical, target_critical, delta * 0.8)
	if critical > 0.0:
		var before := beat_clock
		beat_clock = fmod(beat_clock + delta, HEARTBEAT)
		if beat_clock < before and critical > 0.4 and game.soundscape != null:
			game.soundscape.play_effect("heartbeat", 0.55 * critical)
	else:
		beat_clock = 0.0
	if not card.is_empty():
		card.age += delta
		if card.age >= card.life:
			card = {}
	for mote in motes:
		mote.age += delta
	var landed := motes.filter(func(mote): return mote.age >= mote.delay + MOTE_FLIGHT)
	for mote in landed:
		land(mote)
	motes = motes.filter(func(mote): return mote.age < mote.delay + MOTE_FLIGHT)
	for spark in sparks:
		spark.age += delta
		spark.at += spark.velocity * delta
		spark.velocity *= exp(-delta * 3.4)
	sparks = sparks.filter(func(spark): return spark.age < spark.life)
	for flash in flashes:
		flash.age += delta
	flashes = flashes.filter(func(flash): return flash.age < flash.life)
	for ring in rings:
		ring.age += delta
	rings = rings.filter(func(ring): return ring.age < ring.life)
	for number in numbers:
		number.age += delta
	numbers = numbers.filter(func(number): return number.age < number.life)

## Two-part pulse (lub, dub) aligned with the heartbeat sound.
func beat() -> float:
	if critical <= 0.0:
		return 0.0
	if not motion():
		return 0.5 * critical
	var lub := exp(-pow(beat_clock / 0.09, 2.0))
	var dub := exp(-pow((beat_clock - 0.33) / 0.09, 2.0)) * 0.7
	var tail := exp(-pow((beat_clock - HEARTBEAT) / 0.09, 2.0))
	return clampf(lub + dub + tail, 0.0, 1.0) * critical

func land(mote: Dictionary) -> void:
	if counters.has(mote.control):
		counters[mote.control].pop = 1.0
	burst(mote.to, 3 if detail() > 0 else 1, mote.color, 26.0, 0.35, true)
	if game.soundscape != null and mote.note >= 0:
		game.soundscape.play_effect("mote", 0.16, pow(2.0, (NOTES[mini(mote.note, NOTES.size() - 1)] + 7) / 12.0))

## Where reward motes fly. The HUD records its live counter positions.
func target_for(control: String) -> Vector2:
	var anchors: Dictionary = game.hud.get("anchors") if game.hud.get("anchors") != null else {}
	if anchors.has(control) and not game.comfort_layout():
		return anchors[control]
	return screen(game.run.board.center)

func on_capture(result: Dictionary) -> void:
	var run = game.run
	if not result.get("valid", false):
		return
	var polygon: PackedVector2Array = result.get("polygon", PackedVector2Array())
	var center := Vector2.ZERO
	for point in polygon:
		center += point / float(maxi(1, polygon.size()))
	var poison: int = int(result.get("poison", 0))
	var food: int = int(result.get("food", 0))
	var grade: String = result.get("capture_grade", "")
	var color := DANGER if poison > 0 else PEARL
	if polygon.size() >= 3:
		flashes.append({"polygon": polygon, "age": 0.0, "life": 0.55 if grade.is_empty() else 0.8, "color": color})
		# Light runs along the closed membrane, then scatters into the water.
		var per_edge := 4 if detail() == 2 else 2 if detail() == 1 else 1
		if not grade.is_empty():
			per_edge += 2
		for i in polygon.size():
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i + 1) % polygon.size()]
			var normal := (a - b).orthogonal().normalized()
			if normal.dot((a + b) * 0.5 - center) < 0.0:
				normal = -normal
			for j in per_edge:
				var at := a.lerp(b, (j + randf()) / per_edge)
				var speed := randf_range(30.0, 85.0) * (1.4 if not grade.is_empty() else 1.0)
				spark_at(at, normal.rotated(randf_range(-0.5, 0.5)) * speed, randf_range(0.45, 0.85), randf_range(2.0, 3.6), color if randf() > 0.3 else FOOD)
	# Rewards: each unit of food travels to the counter it fills.
	var gained: int = food
	if run.harvest != null and last_objective >= 0:
		gained = clampi(int(run.harvest.nourishment) - last_objective, 0, food)
	var sources: Array = []
	var kinds: Array = result.get("prey_kinds", [])
	var positions: Array = result.get("positions", [])
	for i in positions.size():
		if i < kinds.size() and kinds[i] in ["food", "grazer", "bacterium"]:
			sources.append(positions[i])
	if sources.is_empty():
		sources.append(center)
	if gained > 0 and run.harvest != null and motion():
		var count := mini(gained, MAX_MOTES)
		var target := target_for("objective")
		for i in count:
			var units := gained / count + (1 if i < gained % count else 0)
			var from: Vector2 = sources[i % sources.size()]
			from += Vector2.from_angle(randf() * TAU) * randf_range(0.0, 10.0)
			# A chain lifts the arrival notes, so flow is heard as well as seen.
			var lift := mini(maxi(int(result.get("flow", 0)) - 1, 0), 4)
			motes.append({"from": screen(from), "to": target, "control": "objective", "age": 0.0, "delay": 0.12 + i * MOTE_STAGGER, "units": units, "color": FOOD, "note": i + lift, "bend": randf_range(-1.0, 1.0)})
	# A number that belongs to the place where it happened.
	var headline := ""
	var tint := FOOD
	if food > 0:
		headline = "+%d" % food
	elif int(result.get("rescued", 0)) > 0:
		headline = "Rescued"
		tint = PEARL
	elif int(result.get("boss_layers", 0)) > 0:
		headline = "Hit"
		tint = PEARL
	elif int(result.get("threats", 0)) > 0:
		headline = "Cleared"
		tint = PEARL
	elif int(result.get("purified", 0)) > 0:
		headline = "Neutralized"
		tint = Color("d9c3e6")
	var flow: int = int(result.get("flow", 0))
	var caption := grade
	if flow >= 2:
		caption = ("%s  ·  " % grade if not grade.is_empty() else "") + "Flow ×%d" % flow
	if not headline.is_empty():
		numbers.append({"at": center, "text": headline, "detail": caption, "age": 0.0, "life": 1.45 if caption.is_empty() else 2.1, "color": tint, "size": 30 if not grade.is_empty() else 24})
	if poison > 0:
		numbers.append({"at": run.board.center + Vector2(0, -78), "text": "−%d" % poison, "detail": "", "age": 0.0, "life": 1.3, "color": DANGER, "size": 24})
	if not grade.is_empty():
		trauma = maxf(trauma, 0.38 if grade == "Living constellation" else 0.26)
		burst(screen(center), 14 if detail() > 0 else 6, PEARL, 120.0, 0.9, false)

func on_injury(amount: int) -> void:
	trauma = minf(1.0, trauma + 0.55 + 0.15 * amount)
	hurt = 1.0
	hurt_pip = game.run.integrity
	var mother: Vector2 = game.run.board.center
	if motion():
		for i in 10 if detail() > 0 else 4:
			var direction := Vector2.from_angle(randf() * TAU)
			spark_at(mother + direction * 50.0, direction * randf_range(40.0, 90.0), randf_range(0.4, 0.8), randf_range(2.0, 3.2), DANGER)

func on_state(previous: String, current: String) -> void:
	var run = game.run
	if current in ["evolve", "success"] and previous == "active":
		celebration = 1.0
		if motion():
			var mother: Vector2 = run.board.center
			for i in 36 if detail() == 2 else 18:
				var direction := Vector2.from_angle(TAU * i / 36.0 + randf() * 0.2)
				spark_at(mother + direction * 64.0, direction * randf_range(60.0, 150.0) + Vector2(0, -20), randf_range(0.9, 1.6), randf_range(2.2, 4.0), PEARL if i % 3 else FOOD)
	if current == "active" and previous in ["brief", "home"]:
		# New encounter: counters start from the dish's real values.
		counters.clear()
		last_objective = -1
		announce()
	if current in ["brief", "home"]:
		motes.clear()
		counters.clear()
		last_objective = -1

## A brief title over the dish as an encounter opens: a new dish is named
## with its character, a boss with its name, other encounters with their goal.
func announce() -> void:
	var run = game.run
	if not run.journey or run.harvest == null:
		return
	var dish: Dictionary = Journey.dish(run.stage_index)
	var spec: Dictionary = run.harvest.spec
	if run.Lesson.active(run):
		last_card_dish = dish.name
		return
	var caption := "%s  ·  ENCOUNTER %d OF %d" % [str(dish.name).to_upper(), run.encounter_index() + 1, run.encounter_total()]
	if dish.name != last_card_dish:
		card = {"caption": "A NEW DISH", "title": dish.name, "detail": dish.subtitle, "age": 0.0, "life": 3.2, "color": dish.color, "boss": false}
	elif spec.mode == "boss":
		card = {"caption": "BOSS  ·  " + str(dish.name).to_upper(), "title": spec.name, "detail": "", "age": 0.0, "life": 2.8, "color": WARM, "boss": true}
	else:
		card = {"caption": caption, "title": spec.name, "detail": "", "age": 0.0, "life": 2.1, "color": dish.color, "boss": false}
	last_card_dish = dish.name
	if game.soundscape != null:
		game.soundscape.play_effect("swell", 0.55 if card.boss or card.caption == "A NEW DISH" else 0.3)

func spark_at(at: Vector2, velocity: Vector2, life: float, size: float, color: Color) -> void:
	if not motion():
		return
	sparks.append({"at": at, "velocity": velocity, "age": 0.0, "life": life, "size": size, "color": color, "screen": false})

## Screen-space burst, used where motes land on the interface.
func burst(at: Vector2, count: int, color: Color, speed: float, life: float, small: bool) -> void:
	if not motion():
		return
	for i in count:
		var direction := Vector2.from_angle(TAU * i / float(count) + randf() * 0.4)
		sparks.append({"at": at, "velocity": direction * speed * randf_range(0.5, 1.0), "age": 0.0, "life": life * randf_range(0.7, 1.0), "size": 1.6 if small else randf_range(2.0, 3.4), "color": color, "screen": true})

func mote_position(mote: Dictionary) -> Vector2:
	var t: float = clampf((mote.age - mote.delay) / MOTE_FLIGHT, 0.0, 1.0)
	# Ease in, then accelerate into the counter along a gentle arc.
	var eased := t * t * (3.0 - 2.0 * t)
	eased = lerpf(eased, t * t, 0.45)
	var from: Vector2 = mote.from
	var to: Vector2 = mote.to
	var lift := (to - from).orthogonal().normalized() * clampf(from.distance_to(to) * 0.28, 40.0, 160.0) * float(mote.bend)
	var control := (from + to) * 0.5 + lift + Vector2(0, -60)
	var a := from.lerp(control, eased)
	var b := control.lerp(to, eased)
	return a.lerp(b, eased)

func draw_glow() -> void:
	var run = game.run
	var lens_center: Vector2 = screen(run.board.center)
	var lens_radius: float = 404.0 * (game.dish_scale() if game.has_method("dish_scale") else 1.0)
	if run.state != "home":
		# Critical health: a slow warm pulse inside the lens edge.
		var pulse := critical * 0.09 + beat() * 0.16
		var flash := hurt * hurt * 0.38
		if pulse + flash > 0.004:
			glow.draw_texture_rect(rim, Rect2(lens_center - Vector2.ONE * lens_radius, Vector2.ONE * lens_radius * 2.0), false, Color(DANGER, pulse + flash))
		if heal_glow > 0.01:
			glow.draw_texture_rect(dot, Rect2(screen(run.board.center) - Vector2.ONE * 110.0, Vector2.ONE * 220.0), false, Color(PEARL, heal_glow * 0.22))
		if celebration > 0.01 and motion():
			var radius := 80.0 + (1.0 - celebration) * 260.0
			glow.draw_texture_rect(dot, Rect2(lens_center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color(PEARL, celebration * celebration * 0.16))
	for ring in rings:
		var t: float = ring.age / ring.life
		var eased := 1.0 - pow(1.0 - t, 3.0)
		var radius: float = lerpf(ring.from, ring.to, eased if motion() else 0.0) * (game.dish_scale() if game.has_method("dish_scale") else 1.0)
		glow.draw_arc(screen(ring.at), radius, 0.0, TAU, 48, Color(ring.color, 0.55 * (1.0 - t)), ring.width, true)
	draw_membrane_light()
	for flash in flashes:
		var t: float = flash.age / flash.life
		var fade := (1.0 - t) * (1.0 - t)
		var width := lerpf(7.0, 1.5, t) if motion() else 2.0
		var count: int = flash.polygon.size()
		for i in count:
			# Edges stop at the tissue surface, like the membrane bonds themselves.
			var a := screen(flash.polygon[i])
			var b := screen(flash.polygon[(i + 1) % count])
			var direction := (b - a).normalized()
			a += direction * 24.0
			b -= direction * 24.0
			glow.draw_line(a, b, Color(flash.color, 0.30 * fade), width + 6.0, true)
			glow.draw_line(a, b, Color(flash.color, 0.85 * fade), width * 0.45, true)
		if motion():
			for point in flash.polygon:
				var p := screen(point)
				var r := 18.0 + t * 30.0
				glow.draw_texture_rect(dot, Rect2(p - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, Color(flash.color, 0.55 * fade))
	for spark in sparks:
		var life: float = 1.0 - spark.age / spark.life
		var p: Vector2 = spark.at if spark.screen else screen(spark.at)
		var size: float = spark.size * (0.6 + 0.4 * life) * 3.2
		glow.draw_texture_rect(dot, Rect2(p - Vector2.ONE * size, Vector2.ONE * size * 2.0), false, Color(spark.color, life * 0.85))
	for mote in motes:
		if mote.age < mote.delay:
			continue
		var p := mote_position(mote)
		var t: float = clampf((mote.age - mote.delay) / MOTE_FLIGHT, 0.0, 1.0)
		# A short luminous trail reads as motion even at low frame rates.
		for k in 4:
			var back: Dictionary = mote.duplicate()
			back.age = maxf(mote.delay, mote.age - 0.018 * (k + 1))
			var q := mote_position(back)
			var r := 9.0 - k * 1.8
			glow.draw_texture_rect(dot, Rect2(q - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, Color(mote.color, 0.32 - k * 0.07))
		var size := lerpf(13.0, 9.0, t)
		glow.draw_texture_rect(dot, Rect2(p - Vector2.ONE * size, Vector2.ONE * size * 2.0), false, Color(mote.color, 0.95))
		glow.draw_texture_rect(dot, Rect2(p - Vector2.ONE * 4.0, Vector2.ONE * 8.0), false, Color(1, 1, 1, 0.9))

## Light travels along the membrane being drawn, toward the newest cell.
func draw_membrane_light() -> void:
	var run = game.run
	var selection = run.selection
	if run.state != "active" or not selection.active or selection.path.size() < 2 or not motion():
		return
	var points: Array = []
	for id in selection.path:
		points.append(run.board.anchors[id])
	if selection.closed:
		points.append(points[0])
	var scale_factor: float = game.dish_scale() if game.has_method("dish_scale") else 1.0
	# The light takes the membrane's own warning colors.
	var tint := PEARL
	if selection.mother_blocked():
		tint = WARM
	elif int(game.capture_feedback.outcome.get("poison", 0)) > 0:
		tint = DANGER
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var direction: Vector2 = (b - a).normalized()
		a += direction * 27.0
		b -= direction * 27.0
		var length := a.distance_to(b)
		if length < 4.0:
			continue
		var pulses := maxi(1, int(length / 90.0))
		for k in pulses:
			var phase := fmod(clock * (1.6 if selection.closed else 1.1) + float(k) / pulses + i * 0.37, 1.0)
			var p := screen(a.lerp(b, phase))
			var size := (7.0 if selection.closed else 5.5) * scale_factor
			var alpha := sin(phase * PI) * (0.55 if selection.closed else 0.38)
			glow.draw_texture_rect(dot, Rect2(p - Vector2.ONE * size, Vector2.ONE * size * 2.0), false, Color(tint, alpha))

func draw_ink() -> void:
	draw_card()
	for number in numbers:
		var t: float = number.age / number.life
		var rise := (1.0 - pow(1.0 - minf(1.0, t * 1.4), 3.0)) * (42.0 if motion() else 0.0)
		var alpha := 1.0 - smoothstep(0.62, 1.0, t)
		var appear := minf(1.0, number.age / 0.22)
		var scale := 1.0
		if motion():
			# Overshoot pop: 0.6 → 1.12 → 1.0
			scale = lerpf(0.6, 1.0, appear) + sin(appear * PI) * 0.18
		var at: Vector2 = screen(number.at) + Vector2(0, -28.0 - rise)
		var size_px: int = int(number.size)
		var font: Font = UI.font(UI.SEMIBOLD, true)
		var width := font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		ink.draw_set_transform(at, 0.0, Vector2.ONE * scale)
		ink.draw_string_outline(font, Vector2(-width * 0.5, 0), number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 6, Color(0.01, 0.04, 0.05, 0.55 * alpha))
		ink.draw_string(font, Vector2(-width * 0.5, 0), number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(number.color, alpha))
		if not str(number.detail).is_empty():
			var caption: String = str(number.detail).to_upper()
			var small: Font = UI.font(UI.SEMIBOLD)
			var caption_width := small.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			ink.draw_string_outline(small, Vector2(-caption_width * 0.5, 22), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 5, Color(0.01, 0.04, 0.05, 0.6 * alpha))
			ink.draw_string(small, Vector2(-caption_width * 0.5, 22), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(PEARL, alpha))
		ink.draw_set_transform(Vector2.ZERO)

func draw_card() -> void:
	if card.is_empty() or game.run.state != "active":
		return
	var t: float = card.age
	var life: float = card.life
	var alpha: float = smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(life - 0.8, life, t))
	if alpha <= 0.0:
		return
	var center := screen(game.run.board.center) + Vector2(0, -150.0 * (game.dish_scale() if game.has_method("dish_scale") else 1.0))
	var drift := 0.0 if not motion() else (1.0 - smoothstep(0.0, 0.6, t)) * 10.0
	# A soft dark well keeps the words legible over living tissue.
	var well := Color(0.004, 0.02, 0.026, 0.55 * alpha)
	ink.draw_texture_rect(dot, Rect2(center - Vector2(330, 120), Vector2(660, 240)), false, well)
	if card.boss:
		ink.draw_texture_rect(rim, Rect2(screen(game.run.board.center) - Vector2.ONE * 404.0 * game.dish_scale(), Vector2.ONE * 808.0 * game.dish_scale()), false, Color(0.0, 0.0, 0.0, 0.35 * alpha))
	var caption: String = card.caption
	var caption_width := tracked.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	ink.draw_string(tracked, center + Vector2(-caption_width * 0.5, -34 + drift), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(card.color, 0.9 * alpha))
	var title: String = card.title
	var size_px := 40 if card.caption == "A NEW DISH" else 34
	var font: Font = UI.font(UI.SEMIBOLD, true)
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	ink.draw_string_outline(font, center + Vector2(-width * 0.5, 8 + drift), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 8, Color(0.01, 0.04, 0.05, 0.45 * alpha))
	ink.draw_string(font, center + Vector2(-width * 0.5, 8 + drift), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(UI.INK, alpha))
	var rule_width := 46.0 + 40.0 * smoothstep(0.1, 0.9, t)
	ink.draw_line(center + Vector2(-rule_width * 0.5, 26 + drift), center + Vector2(rule_width * 0.5, 26 + drift), Color(card.color, 0.6 * alpha), 1.0, true)
	if not str(card.detail).is_empty():
		var detail: String = card.detail
		var small: Font = UI.font(UI.REGULAR)
		var detail_width := small.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		ink.draw_string(small, center + Vector2(-detail_width * 0.5, 54 + drift), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UI.MUTED.lerp(UI.INK, 0.4), alpha))
