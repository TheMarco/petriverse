extends RefCounted
## Appearance follows saved simulation age: pausing and resuming never replay it.
static func progress(body: RefCounted) -> float:
	var duration := 2.2 + posmod(body.id, 5) * 0.09
	if body.is_boss():
		duration = 2.8
	return clampf(body.age / duration, 0.0, 1.0)
