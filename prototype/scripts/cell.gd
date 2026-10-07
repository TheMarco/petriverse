extends RefCounted

var remaining := 0.0
var duration := 6.0
var captor := -1
var lost := false

func is_ready() -> bool:
	return remaining <= 0.000001 and captor<0 and not lost

func spend(seconds: float) -> void:
	duration = seconds
	remaining = seconds

func step(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	if remaining < 0.000001:
		remaining = 0.0

func progress() -> float:
	return 1.0 if is_ready() else 1.0 - remaining / duration
