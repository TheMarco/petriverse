extends RefCounted

const Geometry = preload("res://scripts/loop_geometry.gd")
const Mutations = preload("res://scripts/mutations.gd")
const LoopStrain = preload("res://scripts/loop_strain.gd")

static func enclosed(target: Dictionary, polygon: PackedVector2Array) -> bool:
	if not target.get("eligible", true):
		return false
	for nucleus in target.get("nuclei", [target.position]):
		if not Geometry.contains(nucleus, polygon):
			return false
	return target.health > 0

static func targets(path: Array, board: RefCounted, ready: Callable, snapshot: Array, maximum: int = 8) -> Array:
	var found: Array = []
	if not Geometry.capture_valid(path, board, ready, maximum):
		return found
	var polygon := Geometry.polygon_for(path, board.anchors)
	for target in snapshot:
		if enclosed(target, polygon):
			found.append(target.id)
	return found

static func commit(path: Array, run: RefCounted) -> Dictionary:
	if run.state != run.ACTIVE or not Geometry.capture_valid(path, run.board, run.is_ready, run.selection.max_vertices):
		return {"valid": false, "ids": [], "points": 0}
	# One atomic pulse. Paired nuclei share this predicate with the preview.
	var snapshot: Array = run.target_snapshot()
	var polygon := Geometry.polygon_for(path, run.board.anchors)
	var ids := targets(path, run.board, run.is_ready, snapshot, run.selection.max_vertices)
	var strain: float = LoopStrain.penalty(path, run.board.anchors) if run.journey else 0.0
	var recovery := Mutations.recovery(run.mutations, path.size(), run.board.tuning.recovery_seconds) + strain
	for id in path:
		run.cells[id].spend(recovery)
	if run.harvest != null:
		var harvest_result: Dictionary = run.harvest.commit(path, polygon, ids, recovery, run)
		harvest_result["strain"] = strain
		return harvest_result
	var positions: Array = []
	var prey_kinds: Array = []
	var kills := 0
	var bodies := 0
	var base_points := 0
	var armor_hits := 0
	var boss_layers := 0
	var boss_points := 0
	for target in run.enemies:
		if ids.has(target.id) and target.health > 0:
			var killed: bool = target.apply_pulse(Mutations.damage(run.mutations, path.size()))
			if target.is_boss():
				boss_layers += 1
				if killed:
					boss_points += 1500
					run.boss_defeated = true
					for nucleus in target.nuclei():
						positions.append(nucleus)
						prey_kinds.append("conjoined")
			elif killed:
				for nucleus in target.nuclei():
					positions.append(nucleus)
					prey_kinds.append(target.kind)
				kills += 1
				bodies += target.body_count()
				base_points += target.point_value()
			else:
				armor_hits += 1
		elif target.nuclei().size() > 1:
			for nucleus in target.nuclei():
				if Geometry.contains(nucleus, polygon):
					target.shield_flash = 0.8
	var points := roundi(base_points * (1.0 + minf(1.0, maxf(0.0, kills - 1) * 0.25))) + boss_points
	run.enemies = run.enemies.filter(func(enemy): return enemy.health > 0)
	run.score += points
	run.kills += kills
	run.encounter.resolved += kills
	run.best_capture = maxi(run.best_capture, kills)
	run.loops_drawn += 1
	var restored_node := -1
	if run.mutations.has("frenzy") and bodies >= 3:
		restored_node = path[0]
		run.cells[restored_node].remaining = 0.0
	if run.mutations.has("lure"):
		var center := Vector2.ZERO
		for point in polygon:
			center += point
		center /= polygon.size()
		for target in run.enemies:
			if target.is_boss() or ids.has(target.id):
				continue
			var distance := INF
			for nucleus in target.nuclei():
				for i in polygon.size():
					distance = minf(distance, Geometry.distance_to_segment(nucleus, polygon[i], polygon[(i + 1) % polygon.size()]))
			if distance <= 120.0:
				target.pull_toward(center, minf(45.0, (120.0 - distance) * 0.5))
	if run.mutations.has("residual"):
		run.residuals.append({"polygon": polygon.duplicate(), "remaining": 1.5})
	return {"valid": true, "ids": ids, "points": points, "polygon": polygon,
		"positions": positions, "prey_kinds": prey_kinds, "nodes": path.duplicate(),
		"kills": kills, "bodies": bodies, "armor_hits": armor_hits, "boss_layers": boss_layers,
		"restored_node": restored_node, "recovery": recovery}
