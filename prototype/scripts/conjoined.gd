extends "res://scripts/drifter.gd"
## Two living hearts visit three authored capture routes; no mutation is required.

const ROUTES := [[0, 8, 9, 1], [3, 11, 12, 4], [5, 13, 14, 6]]
const CYCLE := 13.0
var board: RefCounted
var hit_cycle := -1
var attack_count := 0
var centers := PackedVector2Array()
var axes := PackedVector2Array()

func _init(enemy_id: int, board_data: RefCounted) -> void:
	super(enemy_id, Vector2.ZERO, 0.0, "conjoined")
	board = board_data
	health = 3
	for route in ROUTES:
		var center := Vector2.ZERO
		for node in route:
			center += board.rest_anchors[node]
		center /= route.size()
		centers.append(center)
		axes.append((board.rest_anchors[route[2]] - board.rest_anchors[route[1]]).normalized())
	nucleus = centers[0]

func cycle_index() -> int:
	return floori(age / CYCLE)

func phase() -> float:
	return fmod(age, CYCLE)

func contraction() -> float:
	return smoothstep(3.0, 5.0, phase()) * (1.0 - smoothstep(10.0, 12.5, phase()))

func can_take_pulse() -> bool:
	return health > 0 and hit_cycle != cycle_index()

func nuclei() -> PackedVector2Array:
	var current := cycle_index() % centers.size()
	var previous := (current + centers.size() - 1) % centers.size()
	var travel := smoothstep(0.0, 3.0, phase()) if age >= CYCLE else 1.0
	var axis := axes[previous].lerp(axes[current], travel).normalized()
	var separation := lerpf(82.0, 27.0, contraction())
	return PackedVector2Array([nucleus - axis * separation, nucleus + axis * separation])

func step(delta: float, _center: Vector2) -> void:
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	shield_flash = maxf(0.0, shield_flash - delta)
	var current := cycle_index() % centers.size()
	var previous := (current + centers.size() - 1) % centers.size()
	var travel := smoothstep(0.0, 3.0, phase()) if age >= CYCLE else 1.0
	nucleus = centers[previous].lerp(centers[current], travel)

func apply_pulse(_damage: int) -> bool:
	if not can_take_pulse():
		return false
	health = maxi(0, health - 1)
	hit_cycle = cycle_index()
	hit_flash = 1.3
	return health == 0

func attack_due() -> bool:
	# A quiet two-Drifter release at each expansion. It is never a speed test.
	var due := floori(age / CYCLE) + 1
	if due <= attack_count:
		return false
	attack_count = due
	return true

func is_boss() -> bool:
	return true

func body_count() -> int:
	return 0
