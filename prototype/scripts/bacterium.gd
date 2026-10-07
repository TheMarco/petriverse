extends "res://scripts/ecology_enemy.gd"
## A bacterial food competitor: phages cannot infect any other organism.
const INFECTION_TIME := 9.0
var infection_age := -1.0

func _init(number: int, position: Vector2, area: int = 0) -> void:
	super(number,"bacterium",position,area)
	speed = 7.0

func step(delta: float, center: Vector2) -> void:
	super(delta,center)
	if infection_age>=0.0:
		infection_age += delta
		slowed = 0.5

func infection_remaining() -> float:
	return maxf(0.0,INFECTION_TIME-infection_age)
