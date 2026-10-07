extends RefCounted
const Guidance = preload("res://scripts/journey_guidance.gd")

static func sample(run: RefCounted) -> Dictionary:
	var result := {"strength":0.0,"direction":Vector2.ZERO,"position":run.board.center,"seconds":INF,"id":-1}
	if run.integrity <= 0 or run.state in ["home","brief","success","loss","evolve"]:
		return result
	for body in run.enemies:
		var seconds := Guidance.contact_seconds(run,body)
		if seconds < 22.0 and seconds < result.seconds:
			result = {"strength":1.0-smoothstep(1.0,22.0,seconds),"direction":(body.nucleus-run.board.center).normalized(),"position":body.nucleus,"seconds":seconds,"id":body.id}
	return result
