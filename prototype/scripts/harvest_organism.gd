extends "res://scripts/drifter.gd"
## A plankton bloom shares a current, while individual bodies separate slowly.
## Motion is gameplay state: preview, drawing and capture see these same nuclei.
const LIFETIME := 27.0
var origin := Vector2.ZERO
var drift := Vector2.ZERO
var phase := 0.0
const NUDGE_DURATION := 1.25
var nudge_vector := Vector2.ZERO
var nudge_elapsed := NUDGE_DURATION

func start_nudge(displacement: Vector2) -> void:
	nudge_vector = displacement
	nudge_elapsed = 0.0

func nudge_ease(seconds: float) -> float:
	return 1.0-pow(1.0-clampf(seconds/NUDGE_DURATION,0.0,1.0),3.0)

func nudge_roll() -> float:
	var progress := clampf(nudge_elapsed/NUDGE_DURATION,0.0,1.0)
	return sin(progress*PI)*0.75*(1.0 if nudge_vector.y>=0.0 else -1.0)

func _init(number: int, species: String, position: Vector2, drift_extent: Vector2, seed_phase: float) -> void:
	super(number, position, 0.0, species)
	origin = position
	drift = drift_extent
	phase = seed_phase

func position_at(seconds: float, _center: Vector2) -> Vector2:
	# Start exactly in the authored pocket. Both fields stay alive, but a safe
	# snack moves only a few pixels while someone thinks and draws its triangle.
	var flow := Vector2(sin(seconds * 0.12 + phase) - sin(phase),
		sin(seconds * 0.16 + phase * 1.7) - sin(phase * 1.7))
	return origin + flow * drift

func advect(displacement: Vector2) -> void:
	origin += displacement
	super.advect(displacement)

func step(delta: float, center: Vector2) -> void:
	age += delta
	if nudge_elapsed<NUDGE_DURATION:
		var previous := nudge_ease(nudge_elapsed)
		nudge_elapsed = minf(NUDGE_DURATION,nudge_elapsed+delta)
		origin += nudge_vector*(nudge_ease(nudge_elapsed)-previous)
	if lure_elapsed < 0.7:
		var old := smoothstep(0.0, 0.7, lure_elapsed)
		lure_elapsed = minf(0.7, lure_elapsed + delta)
		origin += lure_vector * (smoothstep(0.0, 0.7, lure_elapsed) - old)
	var destination := position_at(age, center)
	heading = (destination - nucleus).normalized()
	nucleus = destination

func lifetime() -> float:
	return maxf(90.0,cradle_open_age+16.0) if cradle else 72.0 if visitor else 40.0 if story=="hatchling" else LIFETIME

func hatch_remaining() -> float:
	return maxf(0.0,12.0-(age-cradle_open_age)) if cradle and cradle_open_age>=0.0 and gate_ids.is_empty() else -1.0

func opening() -> float:
	var cycle := fmod(age,18.0)
	return smoothstep(0.0,4.0,cycle)*(1.0-smoothstep(11.0,17.0,cycle))

func opacity() -> float:
	# Fade into the deeper focal plane before the current carries this bloom out.
	return 1.0 - smoothstep(lifetime() - 3.0, lifetime(), age)
