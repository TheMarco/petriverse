extends RefCounted
## Deterministic, engine-light rules for the Producer Lab experiments.
## No scene, save or profile access here so tests can assert pure outcomes.

const BROOD_TOTAL := 3
const BROOD_SAFE_NEEDED := 2
const ESCORT_SECONDS := 90.0
const CURRENT_GOAL := 8
const CURRENT_SECONDS := 75.0
const BOSS_HEALTH := 3

# --- Experiment 1: Safe passage -------------------------------------------
class Escort:
	var arrived := 0
	var rescued := 0 # brood enclosed by a player loop counts as safely rescued
	var lost := 0
	func safe_count() -> int: return arrived + rescued
	func remaining() -> int: return BROOD_TOTAL - arrived - rescued - lost
	func record_arrival() -> void: arrived += 1
	func record_rescued() -> void: rescued += 1
	func record_lost() -> void: lost += 1
	# At least one brood must truly travel the arc; loop-rescue alone cannot win.
	func is_won() -> bool: return arrived >= 1 and safe_count() >= BROOD_SAFE_NEEDED
	func is_doomed() -> bool: return safe_count() + remaining() < BROOD_SAFE_NEEDED or (arrived == 0 and remaining() == 0)

static func escort_arc(center: Vector2) -> PackedVector2Array:
	var a := center + Vector2(-262, -118)
	var c := center + Vector2(0, -238)
	var b := center + Vector2(262, -142)
	var pts := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return pts

static func arc_point(center: Vector2, t: float) -> Vector2:
	var a := center + Vector2(-262, -118)
	var c := center + Vector2(0, -238)
	var b := center + Vector2(262, -142)
	var u := clampf(t, 0.0, 1.0)
	return a.lerp(c, u).lerp(c.lerp(b, u), u)

# --- Experiment 2: Choose the current --------------------------------------
# Same seed, two mechanically different layouts. Channel: food concentrated
# in one moving horizontal lane, cysts clustered beside it. Shelter: food in
# three separated pockets, cysts kept far from pockets, gentle eddies.
static func current_layout(choice: String, center: Vector2, seed_value: int = 12345) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var food: Array = []
	var cysts: Array = []
	var pockets: Array = []
	if choice == "channel":
		var lane_y := center.y - 150.0
		for i in 9:
			food.append(center + Vector2(-270.0 + i * 62.0 + rng.randf_range(-9, 9), -150.0 + rng.randf_range(-16, 16)))
		for i in 4:
			cysts.append(center + Vector2([-230.0, -155.0, 155.0, 230.0][i] + rng.randf_range(-8, 8), -92.0 + rng.randf_range(-8, 8)))
		pockets = [center + Vector2(0, -150)]
	else:
		var centers := [center + Vector2(-205, -135), center + Vector2(15, -215), center + Vector2(215, -105)]
		pockets = centers
		for p in centers:
			for i in 3:
				food.append(p + Vector2(rng.randf_range(-30, 30), rng.randf_range(-22, 22)))
		for i in 4:
			cysts.append(center + Vector2(-150.0 + i * 95.0, 175.0 + rng.randf_range(-10, 10)))
	return {"food": food, "cysts": cysts, "pockets": pockets,
		"lane_y": center.y - 150.0, "choice": choice}

static func current_velocity(choice: String, at: Vector2, center: Vector2, time: float) -> Vector2:
	var rel := at - center
	if rel.length() < 135.0:
		return Vector2.ZERO # Mother is never transported by either current.
	if choice == "channel":
		var lane_y := center.y - 150.0
		if absf(at.y - lane_y) < 52.0:
			return Vector2(30.0, sin(time * 0.7 + at.x * 0.01) * 3.0)
		return Vector2(2.0, 0.0)
	# Sheltered eddies: slow rotation around the nearest pocket, no lane jet.
	var pockets := [center + Vector2(-205, -135), center + Vector2(15, -215), center + Vector2(215, -105)]
	var best: Vector2 = pockets[0]
	for p in pockets:
		if at.distance_squared_to(p) < at.distance_squared_to(best): best = p
	var offset := at - best
	if offset.length() > 95.0:
		return Vector2.ZERO
	return offset.orthogonal().normalized() * 6.0

static func inside_dish(at: Vector2, center: Vector2, radius: float = 392.0) -> bool:
	return at.distance_to(center) < radius - 28.0 and at.distance_to(center) > 118.0

# --- Experiment 3: The Regent breaks ---------------------------------------
class BossPhase:
	var health := BOSS_HEALTH
	var phase_broken := false
	var break_count := 0
	var opening_created := false
	func shield_anchors(boss_at: Vector2) -> Array:
		if not phase_broken:
			return [boss_at + Vector2(-72, -52), boss_at + Vector2(72, -52)]
		# After the break the anchors swing to opposite (lower) flanks.
		return [boss_at + Vector2(-118, 62), boss_at + Vector2(118, 62)]
	# Returns true only on the hit that defeats the boss.
	func apply_hit() -> bool:
		if health <= 0: return true
		health -= 1
		if not phase_broken:
			phase_broken = true
			break_count += 1
			opening_created = true
		return health == 0
	func defeated() -> bool: return health <= 0
