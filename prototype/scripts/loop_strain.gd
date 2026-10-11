extends RefCounted
## Long links stay legal, but tie up their cells for longer after a capture.
const COMFORT_LENGTH := 130.0
const LENGTH_STEP := 90.0
const SECONDS_PER_STEP := 0.38
const MAX_PENALTY := 2.4

static func edge_amount(a: Vector2, b: Vector2) -> float:
	return maxf(0.0, a.distance_to(b) - COMFORT_LENGTH) / LENGTH_STEP

static func penalty(path: Array, anchors: PackedVector2Array, closed: bool = true) -> float:
	if path.size() < 2:
		return 0.0
	var total := 0.0
	for i in range(path.size() - 1):
		total += edge_amount(anchors[path[i]], anchors[path[i + 1]])
	if closed and path.size() >= 3:
		total += edge_amount(anchors[path[-1]], anchors[path[0]])
	return minf(MAX_PENALTY, total * SECONDS_PER_STEP)

static func edge_tint(a: Vector2, b: Vector2) -> float:
	return clampf(edge_amount(a, b) / 1.5, 0.0, 1.0)
