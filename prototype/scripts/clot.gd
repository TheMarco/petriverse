extends RefCounted
## A recovery group. Cell timers are the single clock for both readiness and pose.
var serial: int
var nodes: Array
var polygon: PackedVector2Array
var positions: Array
var members: Array = []
var duration: float
var center: Vector2
var destinations := PackedVector2Array()
var prey_kinds: Array = []
var prey_forms: Array = []
var food := 0
var poison := 0
var mastery: Array = []
var restored_node := -1
var age: float:
	get:
		return duration - members[0].remaining

func _init(number: int, result: Dictionary, cells: Array, mother: Vector2) -> void:
	food = result.get("food", 0)
	poison = result.get("poison", 0)
	mastery = result.get("mastery",[]).duplicate()
	serial = number
	nodes = result.nodes.duplicate()
	polygon = result.polygon.duplicate()
	positions = result.positions.duplicate()
	prey_kinds = result.get("prey_kinds", []).duplicate()
	prey_forms = result.get("prey_forms", []).duplicate()
	restored_node = result.get("restored_node", -1)
	if nodes.has(restored_node):
		var index := nodes.find(restored_node)
		nodes.remove_at(index)
		polygon.remove_at(index)
	for id in nodes:
		members.append(cells[id])
	duration = members[0].duration
	var total := Vector2.ZERO
	for p in (positions if not positions.is_empty() else Array(polygon)):
		total += p
	center = total / (positions.size() if not positions.is_empty() else polygon.size())
	# Keep the resulting mass away from the mother, even for loops around her.
	var outward := center - mother
	if outward.length() < 112.0:
		if outward.length_squared() < 1.0:
			outward = polygon[0] - mother
		center = mother + outward.normalized() * 112.0
	var winding := 0.0
	for i in polygon.size():
		winding += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	var start := (polygon[0] - center).angle()
	# The members converge inside one body instead of keeping separate lobes.
	var radius := nodes.size() * 0.75
	for i in nodes.size():
		destinations.append(center + Vector2.from_angle(start + signf(winding) * TAU * i / nodes.size()) * radius)

func progress() -> float:
	return members[0].progress()

func finished() -> bool:
	return members[0].is_ready()

func ease_in_fluid(start: float, finish: float, value: float) -> float:
	var u := clampf((value-start)/(finish-start),0.0,1.0)
	return u*u*u*(u*(u*6.0-15.0)+10.0)

func amount() -> float:
	var t := progress()
	return ease_in_fluid(0.0,0.27,t)*(1.0-ease_in_fluid(0.56,1.0,t))

func digestion() -> float:
	var t := progress()
	return smoothstep(0.22, 0.36, t) * (1.0 - smoothstep(0.53, 0.66, t))

func cell_position(index: int, reduced_motion: bool = false) -> Vector2:
	if reduced_motion:
		return polygon[index]
	var t := progress()
	# Each membrane yields a fraction later, then all settle at the same exact
	# readiness boundary. Position, velocity and acceleration meet smoothly.
	var lag := float(posmod(nodes[index]*7,5))*0.006
	var pull := ease_in_fluid(lag,0.27,t)*(1.0-ease_in_fluid(0.56+lag,1.0,t))
	var origin := polygon[index]
	var goal := destinations[index]
	var curl := 1.0 if posmod(nodes[index],2)==0 else -1.0
	var curve := (goal-origin).orthogonal().normalized()*sin(pull*PI)*curl*(6.0+float(index%3)*2.0)
	var pulse := (goal - center).normalized() * sin(age * 5.0 + index * 0.8) * 1.2 * digestion()
	return origin.lerp(goal + pulse, pull) + curve

func cell_positions(reduced_motion: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in nodes.size():
		points.append(cell_position(i, reduced_motion))
	return points

func prey_position(index: int, reduced_motion: bool = false) -> Vector2:
	if reduced_motion:
		return positions[index]
	return positions[index].lerp(center, smoothstep(0.0, 0.30, progress()))
