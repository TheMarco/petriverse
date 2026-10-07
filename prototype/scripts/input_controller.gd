extends RefCounted

const Geometry = preload("res://scripts/loop_geometry.gd")
const MOTHER_WARNING := "Keep the mother outside the loop. Backtrack or right-click to cancel."
var board: RefCounted
var ready: Callable
var path: Array = []
var closed := false
var active := false
var rejected_id := -1
var rejection_reason := ""
var max_vertices := 8

func _init(board_data: RefCounted, readiness: Callable) -> void:
	board = board_data
	ready = readiness

func cancel() -> void:
	path.clear()
	closed = false
	active = false
	rejected_id = -1
	rejection_reason = ""

func start(point: Vector2) -> void:
	cancel()
	var id: int = board.hit_test(point)
	if id >= 0 and ready.call(id):
		path.append(id)
		active = true
	elif id >= 0:
		rejected_id = id
		rejection_reason = "This cell is busy. Start from a ready blue cell."

func visit(id: int) -> bool:
	if not active or id < 0:
		return false
	rejected_id = -1
	rejection_reason = ""
	if closed:
		# After closure, returning to the last distinct node reopens the loop.
		if id == path[-1]:
			closed = false
			return true
		return false
	if id == path[-1]:
		return false
	if path.size() >= 2 and id == path[-2]:
		path.pop_back()
		return true
	if id == path[0] and can_close():
		closed = true
		return true
	if id == path[0] and mother_blocked():
		rejected_id = id
		rejection_reason = MOTHER_WARNING
		return false
	if Geometry.can_append(path, id, board.anchors, ready, max_vertices):
		path.append(id)
		return true
	rejected_id = id
	if not ready.call(id):
		rejection_reason = "This cell is busy. Wait for it to return, or use another."
	elif id == path[0] and path.size() < 3:
		rejection_reason = "Use at least 3 blue cells before returning to START."
	elif path.has(id) and id != path[0]:
		rejection_reason = "Already in your loop. Backtrack to undo, or return to START."
	elif path.size() >= max_vertices and id != path[0]:
		rejection_reason = "Limit: %d cells. Return to START or backtrack." % max_vertices
	else:
		rejection_reason = "A loop cannot cross itself. Backtrack along your last line."
	return false

func drag(from: Vector2, to: Vector2) -> void:
	if not active or from.is_equal_approx(to):
		return
	# Swept hit circles preserve intentional node visits across sparse mouse events.
	var hits: Array = []
	var movement := to - from
	for id in board.anchors.size():
		var offset: Vector2 = from - board.anchors[id]
		if offset.length() <= board.hit_radius:
			continue
		var a := movement.length_squared()
		var b := 2.0 * offset.dot(movement)
		var c: float = offset.length_squared() - board.hit_radius * board.hit_radius
		var discriminant := b * b - 4.0 * a * c
		if discriminant < 0.0:
			continue
		var t := (-b - sqrt(discriminant)) / (2.0 * a)
		if t >= 0.0 and t <= 1.0:
			hits.append({"id": id, "t": t})
	hits.sort_custom(func(a, b): return a.t < b.t)
	for hit in hits:
		visit(hit.id)

func can_close() -> bool:
	return active and Geometry.capture_valid(path, board, ready, max_vertices)

func mother_blocked() -> bool:
	if not active or path.size() < 2:
		return false
	var points := Geometry.polygon_for(path, board.anchors)
	# Existing strokes warn immediately. Include the proposed closing edge only
	# when the path is a simple polygon; the player can still backtrack for free.
	for i in range(points.size() - 1):
		if Geometry.distance_to_segment(board.center, points[i], points[i + 1]) <= board.mother_radius + Geometry.BOUNDARY_TOLERANCE:
			return true
	return Geometry.simple_polygon(points) and Geometry.touches_mother(points, board.center, board.mother_radius)

func legal_next() -> Array:
	var result: Array = []
	if not active or closed:
		return result
	for id in board.anchors.size():
		if Geometry.can_append(path, id, board.anchors, ready, max_vertices):
			result.append(id)
	return result

func release() -> Array:
	var result: Array = path.duplicate() if closed and can_close() else []
	cancel()
	return result
