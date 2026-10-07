extends SceneTree
const Run = preload("res://scripts/run_controller.gd")
const Drifter = preload("res://scripts/drifter.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("exercise")

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)

func center(run: RefCounted, ids: Array) -> Vector2:
	var result := Vector2.ZERO
	for id in ids:
		result += run.board.anchors[id]
	return result / ids.size()

func capture(run: RefCounted, ids: Array) -> Dictionary:
	run.selection.start(run.board.anchors[ids[0]])
	for id in ids.slice(1):
		run.selection.visit(id)
	run.selection.visit(ids[0])
	return run.release()

func mean_home_distance(clot: RefCounted) -> float:
	var result := 0.0
	for i in clot.nodes.size():
		result += clot.cell_position(i).distance_to(clot.polygon[i])
	return result / clot.nodes.size()

func exercise() -> void:
	var run = Run.new(false)
	run.board.step_motion(11.0)
	var path := [0, 8, 9]
	var homes := Geometry.polygon_for(path, run.board.anchors)
	var prey := center(run, path)
	run.enemies = [Drifter.new(101, prey, 0.0)]
	var result := capture(run, path)
	expect(result.valid and result.ids == [101] and run.score == 100 and run.enemies.is_empty(), "Capture and scoring remain immediate")
	var clot = run.clots[0]
	expect(clot.nodes == path and clot.polygon == homes and clot.positions == [prey], "Clot retains exact members, return positions, and captured prey")
	expect(clot.cell_positions() == homes and clot.progress() == 0.0, "Gather begins at the current node positions")
	var outside: Vector2 = run.board.anchors[5]
	run.step(0.9)
	expect(not run.is_ready(0) and not run.is_ready(8) and not run.is_ready(9), "Gathering cells remain unavailable")
	expect(Geometry.polygon_for(path, run.board.anchors) == homes, "Return positions stay frozen throughout recovery")
	expect(run.board.anchors[5] != outside, "Other gameplay nodes continue drifting")
	var gathered_distance := mean_home_distance(clot)
	expect(gathered_distance > 20.0 and clot.amount() > 0.99, "Capturing cells gather into a compact clot")
	expect(clot.prey_position(0).distance_to(clot.center) < 0.001, "The clot gathers captured prey into its center")
	run.selection.start(homes[0])
	expect(not run.selection.active, "Recovering home positions cannot be selected")
	run.step(0.6)
	expect(clot.digestion() > 0.99, "Absorption occurs after gathering and before release")
	expect(clot.cell_positions(true) == homes and clot.prey_position(0, true) == prey, "Reduced motion keeps recovery tissue and prey in place")
	var pose: PackedVector2Array = clot.cell_positions()
	var age: float = clot.age
	run.toggle_pause()
	run.step(4.0)
	expect(clot.cell_positions() == pose and clot.age == age, "Pause freezes the entire clot cycle")
	run.toggle_pause()
	run.step(0.9)
	expect(mean_home_distance(clot) < gathered_distance and not run.is_ready(0), "Declotting visibly returns cells while they remain unavailable")
	run.step(0.6)
	expect(run.is_ready(0) and run.is_ready(8) and run.is_ready(9), "All members become ready at exactly three seconds")
	expect(clot.cell_positions() == homes and Geometry.polygon_for(path, run.board.anchors) == homes, "Readiness coincides with exact arrival at the saved positions")
	expect(run.clots.is_empty(), "Completed recovery releases the clot")
	run.step(1.0 / 60.0)
	expect(run.board.anchors[0] != homes[0] and run.board.anchors[0].distance_to(homes[0]) <= 15.0/60.0, "Independent drift resumes smoothly after arrival")
	# Independent groups may digest different numbers of prey concurrently.
	run.restart()
	run.enemies = [Drifter.new(1, center(run, path), 0.0)]
	capture(run, path)
	run.step(1.0)
	var other := [3, 11, 12]
	var at := center(run, other)
	run.enemies = [Drifter.new(2, at, 0.0), Drifter.new(3, at + Vector2(3, 0), 0.0)]
	capture(run, other)
	expect(run.clots.size() == 2 and run.clots[1].positions.size() == 2, "Separate captures form independent clots")
	run.step(2.0)
	expect(run.clots.size() == 1 and run.clots[0].nodes == other and run.is_ready(0) and not run.is_ready(3), "First clot returns without releasing the later group")
	run.step(1.0)
	expect(run.clots.is_empty() and run.is_ready(3), "Later clot finishes on its own recovery boundary")
	# Empty loops still spend cells, and every legal size returns correctly.
	var loops := [[0, 8, 9], [0, 8, 9, 1], [0, 8, 16, 17, 9], [0, 8, 16, 17, 9, 1], [0, 8, 16, 17, 18, 10, 1], [0, 8, 16, 17, 18, 10, 2, 1]]
	var sizes_work := true
	for ids in loops:
		run.restart()
		result = capture(run, ids)
		if not result.valid:
			sizes_work = false
			continue
		clot = run.clots[0]
		run.step(1.2)
		sizes_work = sizes_work and clot.positions.is_empty() and clot.cell_positions().size() == ids.size() and not run.is_ready(ids[0])
		run.step(1.8)
		sizes_work = sizes_work and run.is_ready(ids[0]) and clot.cell_positions() == clot.polygon
	expect(sizes_work, "Empty loops of three through eight cells clot and return without inventing prey")
	run.restart()
	run.encounter.spawned = 20
	run.encounter.resolved = 19
	run.enemies = [Drifter.new(20, center(run, path), 0.0)]
	capture(run, path)
	expect(run.state == Run.SUCCESS and not run.clots.is_empty(), "Winning capture resolves immediately while its final meal remains visible")
	var frozen: PackedVector2Array = run.board.anchors.duplicate()
	run.step(3.0)
	expect(run.clots.is_empty() and run.is_ready(0) and run.board.anchors == frozen and run.elapsed == 0.0, "Final clot finishes beneath results without restarting combat or drift")
	run.restart()
	capture(run, path)
	run.step(1.0)
	run.restart()
	expect(run.clots.is_empty() and run.is_ready(0) and run.board.anchors == run.board.rest_anchors, "Restart discards an unfinished clot and restores the dish")
	run.dispose()
	print("CLOT RECOVERY: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
