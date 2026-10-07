extends RefCounted
## Labels occupy clear water only. Failure to find room never covers a specimen.
const AREA := Rect2(258, 105, 786, 665)
var obstacles: Array[Rect2] = []
var boxes: Array[Rect2] = []
var placements: Dictionary = {}
var previous: Dictionary = {}
var hidden := false

func begin(occupied: Array[Rect2], suppress: bool) -> void:
	obstacles = occupied
	hidden = suppress
	previous = placements
	placements = {}
	boxes.clear()

func clear_water(box: Rect2) -> bool:
	if not AREA.encloses(box): return false
	for obstacle in obstacles:
		if obstacle.intersects(box): return false
	for other in boxes:
		if other.grow(8).intersects(box): return false
	return true

func place(key: String, anchor: Rect2, size: Vector2) -> Rect2:
	if hidden or placements.has(key): return Rect2()
	var center := anchor.get_center()
	var candidates: Array[Vector2] = []
	# Retain a safe relative position as the specimen drifts or its timer changes.
	if previous.has(key): candidates.append(center+previous[key])
	for gap in [12.0, 32.0]:
		candidates.append(Vector2(center.x-size.x/2.0,anchor.position.y-gap-size.y))
		candidates.append(Vector2(center.x-size.x/2.0,anchor.end.y+gap))
		candidates.append(Vector2(anchor.end.x+gap,center.y-size.y/2.0))
		candidates.append(Vector2(anchor.position.x-gap-size.x,center.y-size.y/2.0))
		for side in [-1, 1]:
			var x: float = anchor.position.x-gap-size.x if side<0 else anchor.end.x+gap
			candidates.append(Vector2(x,anchor.position.y-gap-size.y))
			candidates.append(Vector2(x,anchor.end.y+gap))
	for at in candidates:
		var box := Rect2(at,size)
		if not clear_water(box): continue
		boxes.append(box)
		placements[key] = at-center
		return box
	return Rect2()

func clear_leader(from: Vector2, to: Vector2) -> bool:
	for obstacle in obstacles+boxes:
		obstacle = obstacle.grow(-0.5)
		var corners := [obstacle.position,Vector2(obstacle.end.x,obstacle.position.y),obstacle.end,Vector2(obstacle.position.x,obstacle.end.y)]
		for i in 4:
			if Geometry2D.segment_intersects_segment(from,to,corners[i],corners[(i+1)%4])!=null:
				return false
	return true
