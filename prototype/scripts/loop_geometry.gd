extends RefCounted
## All capture decisions, including boundary preview, use this predicate.

const EPS := 0.001
const BOUNDARY_TOLERANCE := 2.0
const MIN_AREA := 4.0

static func distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	if ab.length_squared() <= EPS * EPS:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0))

static func segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var u := ab.cross(c - a)
	var v := ab.cross(d - a)
	var w := cd.cross(a - c)
	var z := cd.cross(b - c)
	if ((u > EPS and v < -EPS) or (u < -EPS and v > EPS)) and ((w > EPS and z < -EPS) or (w < -EPS and z > EPS)):
		return true
	return distance_to_segment(a, c, d) <= EPS or distance_to_segment(b, c, d) <= EPS or distance_to_segment(c, a, b) <= EPS or distance_to_segment(d, a, b) <= EPS

static func area(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size():
		total += points[i].cross(points[(i + 1) % points.size()])
	return absf(total) * 0.5

static func simple_polygon(points: PackedVector2Array) -> bool:
	if points.size() < 3 or area(points) < MIN_AREA:
		return false
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var c := points[(i + 2) % points.size()]
		if a.distance_to(b) < EPS:
			return false
		# Adjacent edges can touch at their shared vertex, but must not fold back.
		if absf((b - a).cross(c - b)) <= EPS and (b - a).dot(c - b) < 0.0:
			return false
		for j in range(i + 1, points.size()):
			if j == i + 1 or (i == 0 and j == points.size() - 1):
				continue
			if segments_intersect(a, b, points[j], points[(j + 1) % points.size()]):
				return false
	return true

static func contains(p: Vector2, points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	var inside := false
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		if distance_to_segment(p, a, b) <= BOUNDARY_TOLERANCE:
			return true
		if (a.y > p.y) != (b.y > p.y):
			var intersect_x := (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x
			if p.x < intersect_x:
				inside = not inside
	return inside

static func polygon_for(path: Array, anchors: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for id in path:
		result.append(anchors[id])
	return result

static func touches_mother(points: PackedVector2Array, center: Vector2, radius: float) -> bool:
	if contains(center, points):
		return true
	for i in points.size():
		if distance_to_segment(center, points[i], points[(i + 1) % points.size()]) <= radius + BOUNDARY_TOLERANCE:
			return true
	return false

static func capture_valid(path: Array, board: RefCounted, ready: Callable, max_vertices: int = 8) -> bool:
	return validate(path, board.anchors, ready, max_vertices) and not touches_mother(polygon_for(path, board.anchors), board.center, board.mother_radius)

static func validate(path: Array, anchors: PackedVector2Array, ready: Callable, max_vertices: int = 8) -> bool:
	if path.size() < 3 or path.size() > max_vertices:
		return false
	var seen := {}
	for i in path.size():
		var id: int = path[i]
		if id < 0 or id >= anchors.size() or seen.has(id) or not ready.call(id):
			return false
		seen[id] = true
	return simple_polygon(polygon_for(path, anchors))

static func can_append(path: Array, id: int, anchors: PackedVector2Array, ready: Callable, max_vertices: int = 8) -> bool:
	if path.is_empty() or id < 0 or id >= anchors.size() or path.size() >= max_vertices or path.has(id) or not ready.call(id):
		return false
	var a := anchors[path[-1]]
	var b := anchors[id]
	if path.size() > 1:
		var previous := anchors[path[-2]]
		if absf((a - previous).cross(b - a)) <= EPS and (a - previous).dot(b - a) < 0.0:
			return false
	for i in range(path.size() - 2):
		if segments_intersect(a, b, anchors[path[i]], anchors[path[i + 1]]):
			return false
	return true
