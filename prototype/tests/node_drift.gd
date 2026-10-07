extends SceneTree
## Independent wandering, live capture geometry, and held-cell contracts.
const Board = preload("res://scripts/board.gd")
const Run = preload("res://scripts/run_controller.gd")
const Drifter = preload("res://scripts/drifter.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("exercise")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func select(run: RefCounted, ids: Array) -> void:
	run.selection.start(run.board.anchors[ids[0]])
	for i in range(1, ids.size()):
		run.selection.drag(run.board.anchors[ids[i - 1]], run.board.anchors[ids[i]])
	run.selection.drag(run.board.anchors[ids[-1]], run.board.anchors[ids[0]])

func exercise() -> void:
	var board = Board.new()
	var visible = Board.new()
	visible.step_motion(5.0)
	var distances: Array[float] = []
	for i in 24:
		distances.append(visible.anchors[i].distance_to(visible.rest_anchors[i]))
	distances.sort()
	expect(distances[0] >= 8.0 and distances[12] >= 25.0, "Within five seconds every cell travels at least 8 pixels and the median exceeds 25 pixels")
	print("VISIBLE TRAVEL (5s): minimum=%.2fpx, median=%.2fpx, maximum=%.2fpx" % [distances[0],distances[12],distances[-1]])
	var clockwise := 0
	var anticlockwise := 0
	var inward := 0
	var outward := 0
	for i in 24:
		var direction: Vector2 = visible.anchors[i]-visible.rest_anchors[i]
		var radial: Vector2 = visible.rest_anchors[i]-visible.center
		clockwise += int(radial.cross(direction)>100.0)
		anticlockwise += int(radial.cross(direction)<-100.0)
		inward += int(radial.dot(direction)<-100.0)
		outward += int(radial.dot(direction)>100.0)
	expect(clockwise>=6 and anticlockwise>=6 and inward>=6 and outward>=6,"Cells travel in both angular and radial directions instead of sharing an orbit")
	board.step_motion(12.0)
	var all_moved := true
	for i in 24:
		all_moved = all_moved and board.anchors[i].distance_to(board.rest_anchors[i]) > 0.5
		expect(board.hit_test(board.anchors[i]) == i, "Current position of node %d is its hit target" % i)
	expect(all_moved, "All 24 gameplay nodes drift")
	var held: PackedVector2Array = board.anchors.duplicate()
	board.step_motion(8.0, [0, 8, 9])
	expect(board.anchors[0] == held[0] and board.anchors[8] == held[8] and board.anchors[9] == held[9], "Selected positions stay exact while other nodes move")
	expect(board.anchors[5].distance_to(held[5]) > 15.0, "An unselected cell keeps wandering while other cells are held")
	board.step_motion(1.0 / 60.0)
	expect(board.anchors[8].distance_to(held[8]) <= 15.0 / 60.0, "Released node resumes its own motion without teleport or catch-up")
	var planar := true
	var minimum_spacing := INF
	var minimum_area := INF
	var minimum_clearance := INF
	var maximum_radius := 0.0
	var maximum_speed := 0.0
	for dish in 3:
		var stress = Board.new()
		stress.configure_dish(dish)
		for frame in 1200:
			var previous: PackedVector2Array = stress.anchors.duplicate()
			var pinned: Array = [[0,8,9],[3,11,12],[],[0,3,6,18]][(frame/60)%4]
			stress.step_motion(0.25,pinned)
			for i in 24:
				maximum_speed = maxf(maximum_speed,stress.anchors[i].distance_to(previous[i])/0.25)
				maximum_radius = maxf(maximum_radius,stress.anchors[i].distance_to(stress.center))
				for j in i:
					minimum_spacing = minf(minimum_spacing,stress.anchors[i].distance_to(stress.anchors[j]))
			if frame%40==0:
				planar = planar and stress.validate_board().is_empty()
				for tri in stress.triangles:
					minimum_area = minf(minimum_area,Geometry.area(Geometry.polygon_for(tri,stress.anchors)))
				for edge in stress.edges:
					minimum_clearance = minf(minimum_clearance,Geometry.distance_to_segment(stress.center,stress.anchors[edge.x],stress.anchors[edge.y]))
	expect(planar,"Independent motion preserves planar capture routes during five minutes of holds in each biome")
	expect(minimum_spacing>=59.99,"Independently held nodes retain separated hit targets")
	expect(maximum_radius<=board.dish_radius-34.99,"Every cell's tissue remains inside the dish")
	expect(minimum_area>=299.99,"Legal capture triangles never collapse")
	expect(minimum_clearance>=board.mother_radius+17.99,"Connecting bonds remain outside the mother")
	expect(maximum_speed<=12.01,"Independent wandering stays within twelve pixels per second")
	var slower = Board.new()
	var faster = Board.new()
	for i in 300:
		slower.step_motion(1.0 / 30.0)
	for i in 1440:
		faster.step_motion(1.0 / 144.0)
	var matched := true
	for i in 24:
		matched = matched and slower.anchors[i].distance_to(faster.anchors[i]) < 0.001
	expect(matched, "Node trajectories depend on elapsed time at 30 and 144 Hz")
	var run = Run.new(false)
	run.board.step_motion(30.0)
	var path := [0, 8, 9]
	var polygon := Geometry.polygon_for(path, run.board.anchors)
	var original := Geometry.polygon_for(path, run.board.rest_anchors)
	var probe := Vector2.ZERO
	for a in range(1, 20):
		for b in range(1, 20 - a):
			var p: Vector2 = polygon[0] * a / 20.0 + polygon[1] * b / 20.0 + polygon[2] * (20 - a - b) / 20.0
			if Geometry.contains(p, polygon) and not Geometry.contains(p, original):
				probe = p
	expect(probe != Vector2.ZERO, "Drift changes actual capture coverage from the authored layout")
	run.enemies = [Drifter.new(101, probe, 0.0)]
	select(run, path)
	expect(run.selection.closed and run.preview() == [101], "Swept input and preview use current moving positions")
	run.step(0.75)
	expect(Geometry.polygon_for(path, run.board.anchors) == polygon, "Completed polygon holds still before release")
	var result: Dictionary = run.release()
	expect(result.valid and result.ids == [101] and result.polygon == polygon, "Atomic capture uses the exact displayed held polygon")
	var before: PackedVector2Array = run.board.anchors.duplicate()
	run.toggle_pause()
	run.step(10.0)
	expect(run.board.anchors == before, "Pause freezes gameplay node drift")
	run.toggle_pause()
	run.step(1.0 / 60.0)
	expect(run.board.anchors[0] == before[0], "Recovery preserves the pre-capture return position")
	run.step(run.cells[0].remaining)
	expect(run.board.anchors[0] == before[0] and run.is_ready(0), "Node becomes ready exactly at its return position")
	run.step(1.0 / 60.0)
	expect(run.board.anchors[0] != before[0] and run.board.anchors[0].distance_to(before[0]) <= 15.0/60.0, "Drift resumes smoothly after the clot returns")
	run.state = Run.LOSS
	before = run.board.anchors.duplicate()
	run.step(10.0)
	expect(run.board.anchors == before, "End state freezes the field")
	run.restart()
	expect(run.board.anchors == run.board.rest_anchors and run.board.motion_times[0] == 0.0 and run.board.velocities[0]==Vector2.ZERO, "Restart restores positions and all drift phases")
	run.dispose()
	print("WANDER BOUNDS: separation=%.2fpx, triangle area=%.2f, mother clearance=%.2fpx, max radius=%.2fpx, max speed=%.3fpx/s" % [minimum_spacing,minimum_area,minimum_clearance,maximum_radius,maximum_speed])
	print("NODE DRIFT: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
