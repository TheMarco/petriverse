extends SceneTree
## No addons or network access required. Exit status is nonzero on any failure.

const Geometry = preload("res://scripts/loop_geometry.gd")
const Board = preload("res://scripts/board.gd")
const Run = preload("res://scripts/run_controller.gd")
const Drifter = preload("res://scripts/drifter.gd")
const Cell = preload("res://scripts/cell.gd")
const Resolver = preload("res://scripts/loop_resolver.gd")
var checks := 0
var failures: Array[String] = []
var runs: Array = []

func _initialize() -> void:
	call_deferred("test_all")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func fresh() -> RefCounted:
	var result = Run.new(false)
	runs.append(result)
	return result

func select(run: RefCounted, ids: Array, close: bool = true) -> void:
	run.selection.start(run.board.anchors[ids[0]])
	for i in range(1, ids.size()):
		run.selection.visit(ids[i])
	if close:
		run.selection.visit(ids[0])

func all_ready(run: RefCounted) -> bool:
	for cell in run.cells:
		if not cell.is_ready():
			return false
	return true

func centroid(run: RefCounted, ids: Array) -> Vector2:
	var total := Vector2.ZERO
	for id in ids:
		total += run.board.anchors[id]
	return total / ids.size()

func test_all() -> void:
	var board = Board.new()
	expect(board.validate_board().is_empty(), "Authored graph: planar, connected, 24 anchors, mother clearance")
	expect(board.triangles.size() >= 24, "Authored graph offers many small loops")
	var yes := func(_id): return true
	# 1. Valid triangle and larger loop.
	expect(Geometry.validate([0, 8, 9], board.anchors, yes), "01: triangle")
	expect(Geometry.validate([0, 8, 16, 17, 18, 10, 2, 1], board.anchors, yes), "01: eight-cell alternative route")
	# 2. Counts and degeneracy; 3. Free connections and closure.
	expect(not Geometry.validate([0, 1], board.anchors, yes), "02: too few")
	expect(not Geometry.validate([0, 1, 2, 3, 4, 5, 6, 7, 8], board.anchors, yes), "02: too many")
	expect(not Geometry.simple_polygon(PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(40, 0)])), "02: zero area")
	expect(Geometry.validate([0, 16, 17], board.anchors, yes), "03: formerly disconnected cells form a valid triangle")
	expect(Geometry.validate([0, 1, 2], board.anchors, yes), "03: closing edge need not belong to the old network")
	expect(Geometry.validate([16, 20, 23], board.anchors, yes), "03: long edges across the dish have no distance limit")
	expect(not Geometry.validate([0, 1, 2, 1], board.anchors, yes), "03: duplicate vertices remain invalid")
	# 4. Crossings and overlaps, including adjacent backfolds.
	expect(not Geometry.simple_polygon(PackedVector2Array([Vector2(0, 0), Vector2(50, 50), Vector2(0, 40), Vector2(40, 0)])), "04: self-intersection")
	expect(Geometry.segments_intersect(Vector2(0, 0), Vector2(30, 0), Vector2(10, 0), Vector2(40, 0)), "04: overlapping segments detected")
	expect(not Geometry.simple_polygon(PackedVector2Array([Vector2(0, 0), Vector2(50, 0), Vector2(20, 0), Vector2(20, 40)])), "04: adjacent overlap rejected")
	# 5–6. Nucleus inclusion and winding.
	var square := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	var reversed := square.duplicate()
	reversed.reverse()
	var probes := [Vector2(50, 50), Vector2(120, 50), Vector2(50, 0), Vector2.ZERO, Vector2(-1.9, 50), Vector2(-2.1, 50)]
	var answers := [true, false, true, true, true, false]
	for i in probes.size():
		expect(Geometry.contains(probes[i], square) == answers[i], "05: containment probe %d" % i)
		expect(Geometry.contains(probes[i], reversed) == answers[i], "06: reversed winding probe %d" % i)
	# 7. Open release, explicit cancel, empty-space start.
	var run = fresh()
	select(run, [0, 8, 9], false)
	expect(not run.release().valid and all_ready(run), "07: open release costs nothing")
	select(run, [0, 8, 9])
	run.selection.cancel()
	expect(not run.release().valid and all_ready(run), "07: explicit cancel costs nothing")
	run.selection.start(Vector2(5, 5))
	expect(not run.selection.active, "07: empty-space start does nothing")
	# 8. Recovering cells at start, append, and a stale commit.
	run.cells[0].spend(6)
	run.selection.start(board.anchors[0])
	expect(not run.selection.active, "08: cannot start at recovering cell")
	run.selection.start(board.anchors[8])
	expect(not run.selection.visit(0) and run.selection.path == [8], "08: cannot append recovering cell")
	run.restart()
	select(run, [0, 8, 9])
	run.cells[8].spend(6)
	expect(not run.release().valid and run.is_ready(0) and run.is_ready(9), "08: stale commit revalidates readiness atomically")
	# 9. Backtracking, repeated nodes, and closure/reopening.
	run.restart()
	select(run, [0, 8, 16, 17], false)
	run.selection.visit(16)
	expect(run.selection.path == [0, 8, 16], "09: only most recent node removed")
	run.selection.visit(0)
	expect(run.selection.path == [0, 8, 16] and run.selection.closed, "09: a non-neighbor closing edge is allowed")
	run.selection.visit(16) # Reopen before continuing the backtracking checks.
	run.selection.visit(17)
	run.selection.visit(8)
	expect(run.selection.path == [0, 8, 16, 17], "09: older repeated node rejected")
	select(run, [0, 8, 9])
	run.selection.visit(9)
	expect(not run.selection.closed and run.selection.path == [0, 8, 9], "09: closed loop can reopen at its predecessor")
	# Every ready cell is initially available, then geometry narrows the choices.
	run.selection.start(board.anchors[16])
	expect(run.selection.legal_next().size() == 23, "09: all other ready cells are highlighted at the start")
	run.selection.visit(20)
	run.selection.visit(18)
	expect(not run.selection.legal_next().has(22), "09: a crossing append is not highlighted")
	expect(not run.selection.visit(22) and run.selection.rejection_reason.contains("cross"), "09: crossing append is rejected with an explanation")
	select(run, [16, 18, 22, 20], false)
	expect(not run.selection.can_close(), "09: a crossing closing edge is rejected")
	run.selection.cancel()
	run.cells[17].spend(2)
	run.selection.start(board.anchors[0])
	expect(not run.selection.legal_next().has(17), "09: distant recovering cells remain unavailable")
	run.restart()
	# Capture across a formerly missing edge must agree with its preview and
	# spend exactly the chosen vertices, not invisible intermediate neighbors.
	var free_path := [0, 17, 9]
	run.enemies = [Drifter.new(200, centroid(run, free_path), 0)]
	select(run, free_path)
	var free_preview: Array = run.preview()
	var free_capture: Dictionary = run.release()
	expect(free_capture.valid and free_preview == [200] and free_capture.ids == free_preview, "09: free-edge preview and actual capture agree")
	expect(not run.is_ready(0) and not run.is_ready(17) and not run.is_ready(9) and run.is_ready(8), "09: only chosen free-polygon cells digest")
	# 10. The exact same snapshot and predicate drive preview and resolution.
	run.restart()
	var tri := [0, 8, 9]
	run.enemies = [Drifter.new(101, centroid(run, tri), 19), Drifter.new(102, board.anchors[0], 19), Drifter.new(103, Vector2(30, 30), 19)]
	select(run, tri)
	var preview: Array = run.preview()
	var result: Dictionary = run.release()
	expect(preview == [101, 102] and result.ids == preview, "10: preview and atomic capture agree including vertex boundary")
	expect(run.score == 250 and run.enemies.size() == 1, "10: simultaneous kills resolve before animation with the multi-capture bonus")
	select(run, [3, 4, 5], false)
	expect(run.preview().is_empty(), "10: no false preview without closing edge")
	# 11. Empty loops and interior friendly cells.
	run.restart()
	select(run, tri)
	result = run.release()
	expect(result.valid and run.score == 0 and not run.is_ready(0) and not run.is_ready(8) and not run.is_ready(9), "11: empty valid loop spends its vertices without score")
	expect(run.is_ready(1) and run.is_ready(16), "11: unused cells unaffected")
	var recovery: float = run.board.tuning.recovery_seconds
	run.cells[0].step(recovery - 0.01)
	expect(not run.is_ready(0), "11: configured recovery does not finish early")
	run.cells[0].step(0.01)
	expect(run.is_ready(0), "11: configured recovery restores cell immediately")
	run.restart()
	var large := [0, 8, 16, 17, 18, 10, 2, 1]
	expect(Geometry.contains(board.anchors[9], Geometry.polygon_for(large, board.anchors)), "11: larger fixture encloses unused cell 9")
	select(run, large)
	expect(run.release().valid and run.is_ready(9), "11: interior friendly cell remains ready")
	# 12. Duplicate score prevention, including after recovery.
	run.restart()
	run.enemies = [Drifter.new(7, centroid(run, tri), 19)]
	select(run, tri)
	run.release()
	for cell in run.cells:
		cell.step(6)
	select(run, tri)
	run.release()
	expect(run.score == 100 and run.kills == 1, "12: one enemy cannot score twice")
	# 13. Recovery depends on elapsed time, not frame count.
	for fps in [30, 60, 144]:
		var cell = Cell.new()
		cell.spend(6)
		for _frame in 6 * fps - 1:
			cell.step(1.0 / fps)
		expect(not cell.is_ready(), "13: no early readiness at %d fps" % fps)
		cell.step(1.0 / fps)
		expect(cell.is_ready() and cell.remaining == 0.0, "13: exact six-second recovery at %d fps" % fps)
	# 14. Restart clears every piece of encounter state.
	run.score = 300
	run.integrity = 1
	run.elapsed = 19
	run.encounter.spawned = 12
	run.encounter.resolved = 8
	run.enemies.append(Drifter.new(30, Vector2.ZERO, 19))
	select(run, [3, 4, 12], false)
	run.last_contacts = [99]
	run.restart()
	expect(run.score == 0 and run.kills == 0 and run.integrity == 5 and run.state == Run.ACTIVE, "14: restart scores and integrity")
	expect(run.enemies.is_empty() and run.selection.path.is_empty() and all_ready(run), "14: restart enemies selection recovery")
	expect(run.elapsed == 0 and run.encounter.spawned == 0 and run.encounter.resolved == 0 and run.encounter.next_spawn == board.tuning.first_spawn_delay, "14: restart timers and budget")
	expect(run.last_contacts.is_empty() and run.last_capture.is_empty() and run.capture_serial == 0, "14: restart feedback")
	# 15. Pause cancels input, freezes timers, and never commits on release.
	select(run, tri)
	run.cells[2].spend(6)
	run.enemies = [Drifter.new(1, Vector2(640, 100), 19)]
	var before: Array = run.target_snapshot()
	run.toggle_pause()
	run.step(9)
	expect(run.elapsed == 0 and run.cells[2].remaining == 6 and run.encounter.next_spawn == board.tuning.first_spawn_delay, "15: pause freezes simulation and recovery")
	expect(run.target_snapshot() == before and not run.release().valid and run.is_ready(0), "15: pause freezes movement and cancels input")
	run.toggle_pause()
	run.step(0.5)
	expect(is_equal_approx(run.cells[2].remaining, 5.5), "15: recovery resumes")
	# 16. Simultaneous contacts resolve independently of storage order.
	var outcomes: Array = []
	for ids in [[3, 1, 2], [2, 1, 3]]:
		var contact_run = fresh()
		contact_run.integrity = 2
		for id in ids:
			contact_run.enemies.append(Drifter.new(id, board.center + Vector2(49, 0), 19))
		contact_run.step(1.0 / 60)
		outcomes.append([contact_run.integrity, contact_run.enemies.size(), contact_run.encounter.resolved, contact_run.state, contact_run.last_contacts])
	expect(outcomes[0] == outcomes[1] and outcomes[0] == [0, 0, 3, Run.LOSS, [1, 2, 3]], "16: all simultaneous contacts resolve once with clamped integrity")
	# 17. Project policy; real viewport transforms are exercised by integration.gd.
	expect(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "17: logical canvas stretch enabled")
	expect(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "17: aspect is preserved with letterboxing")
	expect(ProjectSettings.get_setting("display/window/size/viewport_width") == 1280 and ProjectSettings.get_setting("display/window/size/viewport_height") == 900, "17: 1280 by 900 logical canvas")
	# Sparse pointer events: a single motion event can enter a neighboring cell.
	run.restart()
	run.selection.start(board.anchors[0])
	run.selection.drag(board.anchors[0], board.anchors[8])
	run.selection.drag(board.anchors[8], board.anchors[9])
	run.selection.drag(board.anchors[9], board.anchors[0])
	expect(run.selection.closed and run.selection.path == tri, "Swept mouse motion closes triangle")
	expect(run.release().valid, "Swept mouse triangle commits")
	# Finite encounter limit, loss stopping combat, and successful final capture.
	run.restart()
	var encounter_timeout := int(ceil(board.tuning.first_spawn_delay + board.tuning.enemy_budget * board.tuning.spawn_interval + board.dish_radius / board.tuning.enemy_speed + 10.0))
	for _frame in encounter_timeout * 60:
		run.step(1.0 / 60)
		expect_cap(run)
		if run.state != Run.ACTIVE:
			break
	expect(run.state == Run.LOSS and run.integrity == 0, "Idle encounter reaches loss")
	var stopped: float = run.elapsed
	run.step(20)
	expect(run.elapsed == stopped, "Loss stops combat")
	run.restart()
	run.encounter.spawned = 20
	run.encounter.resolved = 19
	run.enemies = [Drifter.new(20, centroid(run, tri), 19)]
	select(run, tri)
	run.release()
	expect(run.state == Run.SUCCESS and run.integrity == 5 and run.score == 100, "Final enemy triggers success immediately")
	# Full deterministic encounter, captured by a simple triangle-or-inner-ring policy.
	run.restart()
	var peak := 0
	for _frame in encounter_timeout * 60:
		run.step(1.0 / 60)
		peak = maxi(peak, run.enemies.size())
		if run.state != Run.ACTIVE:
			break
		var candidates: Array = board.triangles.duplicate()
		candidates.append([0, 1, 2, 3, 4, 5, 6, 7])
		for candidate in candidates:
			if not Resolver.targets(candidate, run.board, run.is_ready, run.target_snapshot()).is_empty():
				select(run, candidate)
				run.release()
				break
	expect(run.state == Run.SUCCESS and run.encounter.spawned == 20 and run.encounter.resolved == 20 and peak <= 6, "Full finite encounter can be won on authored board")
	print("AUTOMATED ENCOUNTER: state=%s, score=%d, integrity=%d, elapsed=%.2fs, peak=%d" % [run.state, run.score, run.integrity, run.elapsed, peak])
	for item in runs:
		item.dispose()
	runs.clear()
	print("RESULT: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func expect_cap(run: RefCounted) -> void:
	# Report only a violation, rather than thousands of redundant assertions.
	if run.enemies.size() > 6 or run.encounter.spawned > 20:
		expect(false, "Encounter cap or budget exceeded")
