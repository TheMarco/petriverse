extends RefCounted
## Nucleus is the logical position. Only the outer membrane undulates.

var id: int
var nucleus: Vector2
var speed: float
var heading := Vector2.ZERO
var health := 1
var age := 0.0
var kind := "drifter"
var form := "" # Saved visual identity; kind remains the gameplay role.
var gate_ids: Array = []
var shield_remaining := 0.0
var cradle := false
var cradle_open_age := -1.0
var story := ""
var visitor := false
var bloom_releases := 0
var bloom_id := -1 # Food's original bloom; retained through drifting and saves.
var hunt_target := -1
var hunt_time := 0.0
var forage_remaining := 0.0
var foraging_done := false
var fed_remaining := 0.0
var carried_food := 0
var stunned := 0.0
var slowed := 0.0
var hit_flash := 0.0
var shield_flash := 0.0
var pair_angle := 0.0
var pair_span := 30.0
var lure_vector := Vector2.ZERO
var lure_elapsed := 0.7

func _init(enemy_id: int, position: Vector2, movement_speed: float, species: String = "drifter") -> void:
	id = enemy_id
	nucleus = position
	speed = movement_speed
	kind = species
	health = 2 if kind == "shellback" else 1
	pair_angle = float(id) * 2.399

func nuclei() -> PackedVector2Array:
	if kind == "twinspore":
		var axis := Vector2.from_angle(pair_angle + sin(age * 0.35 + id) * 0.22)
		var span := pair_span + sin(age * 0.65 + id) * 3.0
		return PackedVector2Array([nucleus - axis * span, nucleus + axis * span])
	return PackedVector2Array([nucleus])

func body_count() -> int:
	return 2 if kind == "twinspore" else 1

func point_value() -> int:
	return 200 if kind == "shellback" else (250 if kind == "twinspore" else 100)

func apply_pulse(damage: int) -> bool:
	health = maxi(0, health - damage)
	stunned = 1.1 if health > 0 else 0.0
	hit_flash = 0.8
	return health == 0

func is_boss() -> bool:
	return false

func can_take_pulse() -> bool:
	return health > 0 and gate_ids.is_empty()

func pull_toward(center: Vector2, distance: float) -> void:
	lure_vector = nucleus.move_toward(center, distance) - nucleus
	lure_elapsed = 0.0

func advect(displacement: Vector2) -> void:
	nucleus += displacement

func step(delta: float, center: Vector2) -> void:
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	shield_flash = maxf(0.0, shield_flash - delta)
	var movement_time := maxf(0.0, delta - stunned)
	stunned = maxf(0.0, stunned - delta)
	var slow_time := minf(slowed, movement_time)
	slowed = maxf(0.0, slowed - delta)
	heading = (center - nucleus).normalized()
	var feeding_time := minf(fed_remaining,movement_time)
	fed_remaining = maxf(0.0,fed_remaining-delta)
	nucleus = nucleus.move_toward(center, speed * (movement_time - slow_time * 0.4) * (0.35 if feeding_time>0.0 else 1.0))
	if lure_elapsed < 0.7:
		var old := smoothstep(0.0, 0.7, lure_elapsed)
		lure_elapsed = minf(0.7, lure_elapsed + delta)
		nucleus += lure_vector * (smoothstep(0.0, 0.7, lure_elapsed) - old)
