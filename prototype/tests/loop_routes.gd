extends RefCounted
## Shared by fixtures that need loops a player could draw: simple cycles of
## neighboring cells, each listed once, optionally keeping Mother outside.
const Geometry = preload("res://scripts/loop_geometry.gd")

static func loops(board: RefCounted, min_size: int, max_size: int, mother_outside: bool = true, cap: int = 0) -> Array:
	var found: Array = []
	var walk := func(walk: Callable, path: Array) -> void:
		if cap > 0 and found.size() >= cap:
			return
		# path[1] < path[-1] lists each cycle once, not once per direction.
		if path.size() >= min_size and board.neighbors[path[-1]].has(path[0]) and path[1] < path[-1]:
			if not mother_outside or Geometry.capture_valid(path, board, func(_id): return true, max_size):
				found.append(path.duplicate())
		if path.size() >= max_size:
			return
		for id in board.neighbors[path[-1]]:
			if id > path[0] and not path.has(id):
				walk.call(walk, path + [id])
	for start in board.anchors.size():
		walk.call(walk, [start])
	return found
