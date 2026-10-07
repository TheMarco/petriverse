extends RefCounted
## A safe opening encounter, using the actual input, capture and recovery rules.
const SMALL := [0, 8, 9]
const WIDE := [0, 1, 2, 10, 9, 8]

static func active(run: RefCounted) -> bool:
	return run.journey and run.stage_index == 0 and run.lesson_step in range(4)

static func route(run: RefCounted) -> Array:
	return SMALL if run.lesson_step < 2 else WIDE

static func begin(run: RefCounted) -> void:
	run.lesson_step = 0
	run.lesson_nodes.clear()
	run.enemies.clear()
	run.harvest.nourishment = 0
	seed_food(run)
	run.checkpoint = run.JourneySave.capture(run)

static func seed_food(run: RefCounted) -> void:
	run.enemies.clear()
	var a: PackedVector2Array = run.board.anchors
	var centers := [(a[0] + a[8] + a[9]) / 3.0]
	if run.lesson_step == 2:
		centers.append((a[1] + a[2] + a[10]) / 3.0)
	for center in centers:
		for i in 3:
			run.next_enemy_id += 1
			var body = run.Harvest.Organism.new(run.next_enemy_id, "food", center + Vector2((i - 1) * 16, 0), Vector2.ZERO, float(i))
			run.enemies.append(body)

static func record(run: RefCounted, result: Dictionary) -> void:
	if not active(run) or result.get("raw_food", 0) == 0 or not run.enemies.is_empty():
		return
	var count: int = result.nodes.size()
	if (run.lesson_step == 0 and count in [3, 4]) or (run.lesson_step == 2 and count >= 6):
		run.lesson_nodes = result.nodes.duplicate()
		run.lesson_step += 1

static func step(run: RefCounted) -> void:
	# Practice food stays in focus while the player thinks; no expiry or waves.
	for body in run.enemies:
		body.age = minf(body.age, 3.0)
	if run.lesson_step in [1, 3] and run.lesson_nodes.all(func(id): return run.is_ready(id)):
		run.lesson_step += 1
		run.lesson_nodes.clear()
		if run.lesson_step == 2:
			seed_food(run)
	elif run.lesson_step in [0, 2] and run.enemies.is_empty() and run.clots.is_empty():
		seed_food(run)

static func instruction(run: RefCounted, clicks: bool) -> Dictionary:
	var title := "Try a small capture"
	var detail := "Drag 1 → 2 → 3 → 1, then release. Any ready blue cells can connect."
	if run.lesson_step in [1, 3]:
		title = "Watch your cells return"
		detail = "They merge to digest the food. In 3 seconds they separate and can capture again."
	elif run.lesson_step == 2:
		title = "Try a wider capture"
		detail = "Drag through 1 to 6 to surround both food clusters. Return to 1, then release."
	if clicks:
		detail = detail.replace("Drag", "Click").replace("then release", "then press Enter")
	return {"title":title, "detail":detail, "target":-1, "urgent":false}
