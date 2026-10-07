extends "res://scripts/conjoined.gd"
## Three different patterns share charged polygon captures, not an input trick.
const BREATH_CYCLE := 24.0
const INHALE := 8.0
const SHIELD_WINDOW := 18.0
var variant := 0
var open_remaining := 0.0
var reset_remaining := 0.0
var round_index := 0
var pattern_time := 0.0
var juvenile := false

func _init(number: int, board_data: RefCounted, which: int) -> void:
	super(number,board_data)
	variant = which
	kind = ["bellwether","regent","conjoined"][variant]

func is_boss() -> bool:
	return not juvenile

func nuclei() -> PackedVector2Array:
	if variant<2:
		return PackedVector2Array([nucleus])
	var current := round_index%axes.size()
	var axis: Vector2 = axes[current]
	if reset_remaining>0.0:
		axis = axes[posmod(current-1,axes.size())].lerp(axis,smoothstep(0.0,3.0,4.0-reset_remaining)).normalized()
	# Each lost layer opens a wider spatial problem. The tight opportunity
	# remains the same size, so deliberate small-loop play still works.
	var separation := lerpf(78.0+16.0*mini(round_index,2),27.0,contraction())
	return PackedVector2Array([nucleus-axis*separation,nucleus+axis*separation])

func can_take_pulse() -> bool:
	if health<=0 or reset_remaining>0.0:
		return false
	return variant==2 or open_remaining>0.0

func seconds_until_open() -> float:
	if reset_remaining>0.0:
		return reset_remaining
	return maxf(0.0,INHALE-fmod(pattern_time,BREATH_CYCLE)) if variant==0 else 0.0

func seconds_until_close() -> float:
	return open_remaining

func current_strength() -> float:
	if variant!=0 or reset_remaining>0.0:
		return 0.0
	var cycle := fmod(pattern_time,BREATH_CYCLE)
	return sin(cycle/INHALE*PI) if cycle<INHALE else 0.0

func status_text() -> String:
	if reset_remaining>0.0:
		return "REFORMING · %ds" % ceili(reset_remaining)
	if variant==2:
		return "HEARTS TOGETHER" if contraction()>0.8 else "HEARTS APART"
	if can_take_pulse():
		return "OPEN · %ds LEFT" % ceili(open_remaining)
	if variant==0:
		return "INHALING · OPENS IN %ds" % ceili(seconds_until_open())
	if shield_remaining>0.0:
		return "LAST SHIELD · %ds" % ceili(shield_remaining)
	return "CAPTURE %d SHIELDS" % gate_ids.size()

func cycle_index() -> int:
	return round_index

func phase() -> float:
	return fmod(pattern_time,BREATH_CYCLE)

func contraction() -> float:
	if variant==2:
		var phase_number := mini(round_index,2)
		return smoothstep(1.0,6.0+phase_number,phase())*(1.0-smoothstep(18.0-phase_number,23.0,phase()))
	if variant==0:
		return current_strength()
	return 0.0

func apply_pulse(_damage: int) -> bool:
	if not can_take_pulse():
		return false
	health = maxi(0,health-1)
	hit_flash = 1.3
	open_remaining = 0.0
	reset_remaining = 4.0
	pattern_time = 0.0
	round_index += 1
	return health==0

func step(delta: float, _center: Vector2) -> void:
	age += delta
	hit_flash = maxf(0.0,hit_flash-delta)
	shield_flash = maxf(0.0,shield_flash-delta)
	var remaining := maxf(0.0,delta-reset_remaining)
	reset_remaining = maxf(0.0,reset_remaining-delta)
	pattern_time += remaining
	if variant==0:
		var cycle := phase()
		open_remaining = BREATH_CYCLE-cycle if cycle>=INHALE and reset_remaining<=0.0 else 0.0
	elif variant==1:
		open_remaining = maxf(0.0,open_remaining-delta)
	# Targets relocate only during the four-second recovery after a hit.
	if not juvenile:
		nucleus = nucleus.move_toward(centers[round_index%centers.size()],delta*90.0)
