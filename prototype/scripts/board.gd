extends RefCounted

const Geometry = preload("res://scripts/loop_geometry.gd")
# All consumers use anchors: these are the current simulation positions.
var anchors := PackedVector2Array()
var rest_anchors := PackedVector2Array()
var motion_times := PackedFloat64Array()
var motion_homes := PackedVector2Array()
var velocities := PackedVector2Array()
var motion_accumulator := 0.0
const MOTION_STEP := 1.0 / 60.0
const MAX_SPEED := 12.0
const CELL_SPACING := 60.0
var local_triangles: Array = []
var local_edges: Array = []
var neighbors: Array = []
var edges: Array = []
var triangles: Array = []
var spawn_angles: Array = []
var tuning: Dictionary
var center: Vector2
var dish_radius: float
var mother_radius: float
var hit_radius: float

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/board.json"))
	center = Vector2(data.center[0], data.center[1])
	dish_radius = data.dish_radius
	mother_radius = data.mother_radius
	hit_radius = data.hit_radius
	tuning = data.tuning
	spawn_angles = data.spawn_angles_degrees
	for p in data.anchors:
		anchors.append(Vector2(p[0], p[1]))
		neighbors.append([])
		local_triangles.append([])
		local_edges.append([])
	rest_anchors = anchors.duplicate()
	motion_times.resize(anchors.size())
	for pair in data.edges:
		var edge := Vector2i(int(pair[0]), int(pair[1]))
		edges.append(edge)
		neighbors[edge.x].append(edge.y)
		neighbors[edge.y].append(edge.x)
		local_edges[edge.x].append(edge)
		local_edges[edge.y].append(edge)
	for a in anchors.size():
		for b in neighbors[a]:
			for c in neighbors[b]:
				if a < b and b < c and neighbors[c].has(a):
					triangles.append([a, b, c])
					var winding := signf((anchors[b]-anchors[a]).cross(anchors[c]-anchors[a]))
					for id in [a,b,c]:
						local_triangles[id].append([a,b,c,winding])
	reset_motion()

func reset_motion() -> void:
	anchors = rest_anchors.duplicate()
	motion_times.fill(0.0)
	motion_homes = anchors.duplicate()
	velocities.resize(anchors.size())
	velocities.fill(Vector2.ZERO)
	motion_accumulator = 0.0

func step_motion(delta: float, held: Array = [], fluid: RefCounted = null) -> void:
	if delta <= 0.0:
		return
	# Fixed simulation steps make steering and obstacle avoidance independent
	# of render rate. Only selected/recovering cells stop; there is no group phase.
	motion_accumulator += delta
	while motion_accumulator >= MOTION_STEP - 0.000000001:
		motion_accumulator = maxf(0.0,motion_accumulator-MOTION_STEP)
		wander_step(held,fluid)

func wander_step(held: Array, fluid: RefCounted = null) -> void:
	for id in anchors.size():
		if held.has(id):
			continue
		motion_times[id] += MOTION_STEP
		var t: float = motion_times[id] * (0.85 + (id%7)*0.07)
		var phase := id*2.399963 + 0.7
		var heading := phase + sin(t*0.13+phase*0.17)*1.35 + sin(t*0.047+phase*0.81)*2.1
		var desired := Vector2.from_angle(heading) * (10.0+2.0*sin(t*0.09+phase))
		var position := anchors[id]
		if fluid != null:
			desired += fluid.sample(position)*0.32
		# Broad, soft territory preserves familiar connections, without pinning a
		# cell to a tiny wobble or imposing a direction around the mother.
		var home := motion_homes[id]-position
		desired += home.normalized()*maxf(0.0,home.length()-55.0)*0.16
		for other in anchors.size():
			if other == id:
				continue
			var away := position-anchors[other]
			var distance := away.length()
			if distance < 92.0:
				desired += away/maxf(distance,0.01)*pow((92.0-distance)/32.0,2.0)*16.0
		var radial := position-center
		var radius := radial.length()
		desired -= radial.normalized()*maxf(0.0,radius-(dish_radius-70.0))*0.65
		desired += radial.normalized()*maxf(0.0,112.0-radius)*0.75
		# Edge lengths and triangle altitude provide an early, gentle response
		# before the exact geometry guard would need to stop a crossing.
		for other in neighbors[id]:
			var toward: Vector2 = anchors[other]-position
			var rest_length := motion_homes[id].distance_to(motion_homes[other])
			desired += toward.normalized()*maxf(0.0,toward.length()-rest_length-28.0)*0.3
		for tri in local_triangles[id]:
			var a: int = tri[1] if tri[0]==id else tri[0]
			var b: int = tri[1] if tri[2]==id else tri[2]
			var edge: Vector2 = anchors[b]-anchors[a]
			var normal := edge.orthogonal().normalized()
			normal *= signf((position-anchors[a]).dot(normal))
			var altitude := absf((position-anchors[a]).dot(normal))
			desired += normal*maxf(0.0,42.0-altitude)*0.65
		velocities[id] = velocities[id].lerp(desired.limit_length(MAX_SPEED),1.0-exp(-MOTION_STEP/0.7))
		var candidate := position+velocities[id]*MOTION_STEP
		if can_move(id,candidate):
			anchors[id] = candidate
		else:
			# Deflect gradually instead of teleporting or pushing a held neighbor.
			velocities[id] = velocities[id].rotated(0.08 if id%2==0 else -0.08)*0.92

func can_move(id: int, candidate: Vector2) -> bool:
	if candidate.distance_squared_to(center) > pow(dish_radius-35.0,2.0):
		return false
	for other in anchors.size():
		# A legacy snapshot may already have slightly closer hit targets. Permit
		# separation to improve instead of trapping both cells in that old state.
		if other!=id and candidate.distance_squared_to(anchors[other]) < minf(CELL_SPACING*CELL_SPACING,anchors[id].distance_squared_to(anchors[other]))-0.0001:
			return false
	var old := anchors[id]
	anchors[id] = candidate
	var safe := true
	for tri in local_triangles[id]:
		if (anchors[tri[1]]-anchors[tri[0]]).cross(anchors[tri[2]]-anchors[tri[0]])*tri[3] < 600.0:
			safe = false
			break
	if safe:
		for e in local_edges[id]:
			var a := anchors[e.x]
			var b := anchors[e.y]
			if Geometry.distance_to_segment(center,a,b) < mother_radius+18.0:
				safe = false
				break
			for f in edges:
				if e.x==f.x or e.x==f.y or e.y==f.x or e.y==f.y:
					continue
				var c := anchors[f.x]
				var d := anchors[f.y]
				# Cheap broad phase: nearly all other bonds are far away.
				if maxf(a.x,b.x)<minf(c.x,d.x) or maxf(c.x,d.x)<minf(a.x,b.x) or maxf(a.y,b.y)<minf(c.y,d.y) or maxf(c.y,d.y)<minf(a.y,b.y):
					continue
				if Geometry.segments_intersect(a,b,c,d):
					safe = false
					break
			if not safe:
				break
	anchors[id] = old
	return safe

func hit_test(point: Vector2) -> int:
	var closest := -1
	var distance := hit_radius
	for i in anchors.size():
		var d := point.distance_to(anchors[i])
		if d <= distance:
			distance = d
			closest = i
	return closest

func available_triangles(ready: Callable) -> int:
	var count := 0
	for triangle in triangles:
		if ready.call(triangle[0]) and ready.call(triangle[1]) and ready.call(triangle[2]):
			count += 1
	return count

func validate_board() -> Array[String]:
	var errors: Array[String] = []
	if anchors.size() != 24:
		errors.append("Expected 24 anchors")
	var visited := {0: true}
	var frontier := [0]
	while not frontier.is_empty():
		for neighbor in neighbors[frontier.pop_back()]:
			if not visited.has(neighbor):
				visited[neighbor] = true
				frontier.append(neighbor)
	if visited.size() != anchors.size():
		errors.append("Disconnected board")
	for i in edges.size():
		var e: Vector2i = edges[i]
		if Geometry.distance_to_segment(center, anchors[e.x], anchors[e.y]) < mother_radius + 18.0:
			errors.append("Edge occludes mother: %s" % e)
		for j in range(i + 1, edges.size()):
			var f: Vector2i = edges[j]
			if e.x == f.x or e.x == f.y or e.y == f.x or e.y == f.y:
				continue
			if Geometry.segments_intersect(anchors[e.x], anchors[e.y], anchors[f.x], anchors[f.y]):
				errors.append("Crossing edges: %s / %s" % [e, f])
	return errors

func configure_dish(index: int) -> void:
	# Positive affine transforms preserve every edge and legal capture route.
	# New water has a genuinely different layout without erasing learned input.
	for i in rest_anchors.size():
		var relative := rest_anchors[i] - center
		if index == 1:
			relative = Vector2(relative.x * 0.90, relative.y * 1.02).rotated(0.12)
		elif index == 2:
			relative = Vector2(relative.x * 1.02, relative.y * 0.91).rotated(-0.16)
		rest_anchors[i] = center + relative
	reset_motion()
