extends "res://scripts/harvest_organism.gd"
## Friendly virions live outside the capturable enemy list.
var host_id := -1
var attached_from := Vector2.ZERO

func _init(number: int, position: Vector2) -> void:
	super(number,"phage",position,Vector2(5,4),float(number)*0.71)

func lifetime() -> float:
	return 72.0 if host_id<0 else 9999.0
