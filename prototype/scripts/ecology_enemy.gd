extends "res://scripts/drifter.gd"
## Behavioral enemies retain the same capture geometry as other organisms.
var destination := Vector2.ZERO
var target_id := -1
var target_node := -1
var site_nodes: Array = []
var latched := false
var action_clock := 0.0
var stored_food := 0
var daughter := false
var sector := 0
var spawning := 2.5

func _init(number: int, species: String, position: Vector2, area: int = 0) -> void:
	super(number, position, 7.0, species)
	destination = position
	sector = area
	speed = {"grazer": 8.0, "parasite": 7.0, "divider": 5.5, "warden": 0.0}.get(kind, 7.0)

func step(delta: float, center: Vector2) -> void:
	age += delta
	hit_flash = maxf(0.0, hit_flash-delta)
	shield_flash = maxf(0.0, shield_flash-delta)
	var live_time := maxf(0.0, delta-spawning)
	spawning = maxf(0.0, spawning-delta)
	stunned = maxf(0.0, stunned-delta)
	slowed = maxf(0.0, slowed-delta)
	if live_time <= 0.0 or stunned > 0.0:
		return
	if kind == "divider":
		destination = center
	elif kind == "warden" or latched:
		return
	if nucleus.distance_squared_to(destination)>0.01:
		heading = (destination-nucleus).normalized()
	nucleus = nucleus.move_toward(destination, speed*live_time*(0.6 if slowed > 0.0 else 1.0))

func split_remaining() -> float:
	return maxf(0.0, 20.0-age)

func opacity() -> float:
	# The shared tissue emergence owns the fade; do not dim it a second time.
	return 1.0
