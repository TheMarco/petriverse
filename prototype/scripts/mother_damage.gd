extends RefCounted
## Five organelles in mother.png. Damage is immediate; each bite has its own
## simulation-driven aftermath so simultaneous hits, pause and loss stay exact.
const DURATION := 2.2
const CORE_UVS := [Vector2(0.389, 0.258), Vector2(0.707, 0.364), Vector2(0.673, 0.632), Vector2(0.477, 0.722), Vector2(0.246, 0.550)]
const CORE_RADII := [0.061, 0.063, 0.060, 0.065, 0.061]
const EXTENT := 120.0
var lost := [false, false, false, false, false]
var bites: Array = []
var serial := 0

func core_offset(index: int) -> Vector2:
	return (CORE_UVS[index] - Vector2.ONE * 0.5) * EXTENT

func prepare_integrity(integrity: int) -> void:
	# Keep direct test/debug setups consistent with their starting health.
	var missing := 5 - clampi(integrity, 0, 5) - lost.count(true)
	for i in 5:
		if missing > 0 and not lost[i]:
			lost[i] = true
			missing -= 1

func record(enemy_id: int, origin: Vector2, center: Vector2, kind: String = "drifter", nuclei: PackedVector2Array = PackedVector2Array(), health: int = 1, form: String = "") -> void:
	var nearest := -1
	var distance := INF
	for i in 5:
		if lost[i]:
			continue
		var d := origin.distance_squared_to(center + core_offset(i))
		if d < distance:
			distance = d
			nearest = i
	if nearest < 0:
		return
	lost[nearest] = true
	serial += 1
	bites.append({"serial": serial, "enemy_id": enemy_id, "core": nearest, "origin": origin, "age": 0.0, "kind": kind, "nuclei": nuclei, "health": health, "form": form})

func step(delta: float) -> void:
	for bite in bites:
		bite.age += delta
	bites = bites.filter(func(bite): return bite.age < DURATION)

func active() -> bool:
	return not bites.is_empty()

func core_progress(index: int) -> float:
	if not lost[index]:
		return 0.0
	for bite in bites:
		if bite.core == index:
			return smoothstep(0.54, 1.56, bite.age)
	return 1.0

func progress_values() -> PackedFloat32Array:
	var values := PackedFloat32Array()
	for i in 5:
		values.append(core_progress(i))
	return values

func recoil() -> float:
	var amount := 0.0
	for bite in bites:
		var a: float = bite.age
		var impact := sin(clampf(a / 0.46, 0.0, 1.0) * PI)
		var strain := sin(clampf((a - 0.4) / 1.1, 0.0, 1.0) * PI) * 0.55
		amount = maxf(amount, maxf(impact, strain))
	return amount
