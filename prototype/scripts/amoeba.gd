extends "res://scripts/drifter.gd"
## The gold nucleus is always the capture target, including while holding a cell.
const REACH_TIME := 2.8
const RESCUE_TIME := 15.0
var phase := "seeking"
var target_node := -1
var captive_node := -1
var site_nodes: Array = []
var destination := Vector2.ZERO
var reach_point := Vector2.ZERO
var ingest_axis := Vector2.RIGHT
var reach_age := 0.0
var digestion_age := 0.0
var rest_age := 0.0
var arm_extension := 0.0
var victim_home := Vector2.ZERO
var search_after := 3.2

func _init(number: int, at: Vector2) -> void:
	super(number,at,6.0,"amoeba")
	destination = at
	reach_point = at+Vector2(60,0)

func step(delta: float, _center: Vector2) -> void:
	var previous_crawl := crawl_phase()
	age += delta
	hit_flash = maxf(0.0,hit_flash-delta)
	stunned = maxf(0.0,stunned-delta)
	heading = (destination-nucleus).normalized()
	if phase in ["seeking","approaching"] and stunned<=0.0:
		# Extension leads the body by a beat. Integrating the speed cycle keeps
		# the average pace and saved age deterministic across frame rates.
		var distance := speed*(delta+0.5/0.85*(cos(previous_crawl-1.2)-cos(crawl_phase()-1.2)))
		nucleus = nucleus.move_toward(destination,maxf(0.0,distance))
	var extension := 1.0 if phase=="reaching" else maxf(0.0,1.0-digestion_age/1.1) if phase=="digesting" else 0.0
	arm_extension = move_toward(arm_extension,extension,delta*1.5)

func crawl_phase() -> float:
	return age*0.85+id*0.71

func rescue_remaining() -> float:
	return maxf(0.0,RESCUE_TIME-digestion_age) if captive_node>=0 else 0.0

func meal_progress() -> float:
	return clampf(digestion_age/RESCUE_TIME,0.0,1.0)

func captive_position(reduced: bool = false) -> Vector2:
	var inside := nucleus+ingest_axis*22.0
	if not reduced:
		inside += ingest_axis.orthogonal()*sin(digestion_age*1.1+id)*2.2
	return inside if reduced else victim_home.lerp(inside,smoothstep(0.0,1.1,digestion_age))

func opacity() -> float:
	return 1.0
