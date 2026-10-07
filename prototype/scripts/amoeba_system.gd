extends RefCounted
const Body = preload("res://scripts/amoeba.gd")
const RETURN_TIME := 1.25
const MAX_MISSING := 4
var releases: Array = []

func reset() -> void:
	releases.clear()

func owner(run: RefCounted, node: int) -> RefCounted:
	for body in run.enemies:
		if body.kind=="amoeba" and body.captive_node==node: return body
	return null

func missing(run: RefCounted) -> int:
	return run.cells.filter(func(cell): return cell.lost or cell.captor>=0).size()

func reserved(run: RefCounted, node: int, except_id: int) -> bool:
	for body in run.enemies:
		if body.kind=="amoeba" and body.id!=except_id and body.phase in ["approaching","reaching","digesting"]:
			if body.target_node==node or body.site_nodes.has(node): return true
		if body.kind=="parasite" and body.id!=except_id and body.target_node==node: return true
	return false

func eligible(run: RefCounted, body: RefCounted, node: int) -> bool:
	return node>=0 and run.is_ready(node) and not run.selection.path.has(node) and not reserved(run,node,body.id)

func site_for(run: RefCounted, body: RefCounted, victim: int) -> Dictionary:
	var best := INF
	var result := {}
	for triangle in run.board.triangles:
		if triangle.has(victim): continue
		var available := true
		for node in triangle:
			if not run.is_ready(node) or reserved(run,node,body.id): available = false
		if not available: continue
		var polygon: PackedVector2Array = run.Geometry.polygon_for(triangle,run.board.anchors)
		if not run.Geometry.capture_valid(triangle,run.board,run.is_ready,run.selection.max_vertices): continue
		var at: Vector2 = (polygon[0]+polygon[1]+polygon[2])/3.0
		var distance := at.distance_to(run.board.anchors[victim])
		if distance<35.0 or distance>115.0: continue
		if run.enemies.any(func(e): return e.kind=="cyst" and run.Geometry.contains(e.nucleus,polygon)): continue
		var cost := distance+at.distance_to(body.nucleus)*0.65
		if cost<best:
			best = cost
			result = {"nodes":triangle.duplicate(),"position":at}
	return result

func choose_target(run: RefCounted, body: RefCounted) -> void:
	if missing(run)>=MAX_MISSING or run.cells.filter(func(cell): return cell.is_ready()).size()<9: return
	var choices: Array = range(run.cells.size())
	choices.sort_custom(func(a,b): return run.board.anchors[a].distance_to(body.nucleus)<run.board.anchors[b].distance_to(body.nucleus))
	for node in choices:
		if not eligible(run,body,node): continue
		var site := site_for(run,body,node)
		if site.is_empty(): continue
		body.target_node = node
		body.site_nodes = site.nodes
		body.destination = site.position
		body.phase = "approaching"
		body.reach_age = 0.0
		return

func site_center(run: RefCounted, body: RefCounted) -> Vector2:
	var center := Vector2.ZERO
	for node in body.site_nodes: center += run.board.anchors[node]/float(body.site_nodes.size())
	return center

func cancel_reach(body: RefCounted) -> void:
	body.phase = "seeking"
	body.target_node = -1
	body.site_nodes.clear()
	body.reach_age = 0.0
	body.search_after = body.age+2.0
	body.destination = body.nucleus

func step(run: RefCounted, delta: float) -> void:
	step_returns(delta)
	for body in run.enemies:
		if body.kind!="amoeba": continue
		if body.phase=="sated":
			body.rest_age += delta
			if body.rest_age>=7.0: cancel_reach(body)
			continue
		if body.phase=="digesting":
			# The carrier stays within the triangle reserved for its rescue. These
			# nodes may recover from another loop, but another amoeba cannot take them.
			body.nucleus = site_center(run,body)
			body.digestion_age = minf(Body.RESCUE_TIME,body.digestion_age+delta)
			if body.digestion_age>=Body.RESCUE_TIME:
				var cell = run.cells[body.captive_node]
				cell.lost = true
				cell.captor = -1
				body.captive_node = -1
				body.phase = "sated"
				body.rest_age = 0.0
				run.harvest.ecology.announce("A cell was digested · it regrows at the next encounter")
			continue
		if body.age<body.search_after: continue
		if body.phase=="seeking":
			choose_target(run,body)
			body.search_after = body.age+1.0
			continue
		if not eligible(run,body,body.target_node) or missing(run)>=MAX_MISSING or body.site_nodes.any(func(n): return run.cells[n].lost or run.cells[n].captor>=0):
			cancel_reach(body)
			continue
		body.destination = site_center(run,body)
		body.reach_point = run.board.anchors[body.target_node]
		body.ingest_axis = (body.reach_point-body.nucleus).normalized()
		if body.phase=="approaching":
			if body.nucleus.distance_to(body.destination)<4.0:
				body.phase = "reaching"
				body.reach_age = 0.0
			continue
		body.nucleus = body.destination
		body.reach_age += delta
		if body.reach_age<Body.REACH_TIME: continue
		var safe := true
		for node in body.site_nodes:
			if not run.is_ready(node): safe = false
		var staggered: bool = not run.enemies.any(func(e): return e.kind=="amoeba" and e.captive_node>=0 and e.digestion_age<5.0)
		if not safe or not staggered or run.cells.filter(func(c): return c.is_ready()).size()<9: continue
		body.captive_node = body.target_node
		body.victim_home = run.board.anchors[body.captive_node]
		body.digestion_age = 0.0
		body.phase = "digesting"
		run.cells[body.captive_node].captor = body.id
		run.harvest.ecology.announce("Cell swallowed · loop around the amoeba's gold nucleus within 15s")

func step_returns(delta: float) -> void:
	for release in releases: release.age = minf(RETURN_TIME,release.age+delta)
	releases = releases.filter(func(r): return r.age<RETURN_TIME)

func rescue(run: RefCounted, body: RefCounted) -> bool:
	if body.captive_node<0: return false
	var node: int = body.captive_node
	var cell = run.cells[node]
	cell.captor = -1
	cell.spend(RETURN_TIME)
	releases.append({"node":node,"age":0.0,"from":body.captive_position(),"gate":body.nucleus+body.ingest_axis*58.0,"home":run.board.anchors[node],"origin":body.nucleus})
	body.captive_node = -1
	body.phase = "sated"
	body.rest_age = 0.0
	run.harvest.ecology.announce("Cell rescued · returning to your colony")
	return true

func release_all(run: RefCounted) -> void:
	for body in run.enemies:
		if body.kind=="amoeba": rescue(run,body)

func return_for(node: int) -> Dictionary:
	for release in releases:
		if release.node==node: return release
	return {}

func return_position(release: Dictionary, reduced: bool = false) -> Vector2:
	if reduced: return release.home
	var t := smoothstep(0.0,1.0,release.age/RETURN_TIME)
	var a: Vector2 = release.from.lerp(release.gate,t)
	var b: Vector2 = release.gate.lerp(release.home,t)
	return a.lerp(b,t)
