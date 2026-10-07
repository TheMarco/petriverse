extends RefCounted

var budget: int
var max_active: int
var interval: float
var spawned := 0
var resolved := 0
var next_spawn: float
var timeline: Array = []
var clock := 0.0
var last_spawn: Dictionary = {}

func _init(tuning: Dictionary, plan: Array = []) -> void:
	budget = int(tuning.enemy_budget)
	max_active = int(tuning.max_active)
	interval = tuning.spawn_interval
	next_spawn = tuning.first_spawn_delay
	timeline = plan.duplicate(true)
	if not timeline.is_empty():
		budget = timeline.size()
		next_spawn = timeline[0].at

func step(delta: float, active_count: int) -> bool:
	clock += delta
	next_spawn = maxf(0.0, next_spawn - delta)
	if not timeline.is_empty() and spawned < budget:
		next_spawn = maxf(0.0, timeline[spawned].at - clock)
	if spawned >= budget or active_count >= max_active or next_spawn > 0.0:
		return false
	last_spawn = timeline[spawned] if not timeline.is_empty() else {}
	spawned += 1
	next_spawn = interval
	return true

func is_complete() -> bool:
	return spawned == budget and resolved == budget
