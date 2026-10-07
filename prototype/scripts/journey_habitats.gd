extends RefCounted
## A destination is chosen before an encounter, never while a meal is moving.
## The ordinary route preserves the authored encounter; shelter trades food
## density for fewer hunter arrivals and a guaranteed optional rare visitor.
const NAMES := [
	["Blooming banks", "Quiet shallows"],
	["Sunlit reeds", "Glass grotto"],
	["Luminous current", "Midnight refuge"],
]
const IDS := ["bloom", "refuge"]

static func available(run: RefCounted) -> bool:
	return run.journey and run.stage_index>=2 and run.stage_index%4!=3

static func pending(run: RefCounted) -> bool:
	return available(run) and run.state=="brief" and not run.habitat_confirmed

static func name_for(stage: int, id: String) -> String:
	return NAMES[clampi(stage/4,0,2)][1 if id=="refuge" else 0]

static func choose(run: RefCounted, id: String) -> bool:
	if not pending(run) or id not in IDS:
		return false
	run.habitat_choice = id
	run.habitat_confirmed = true
	run.journey_serial += 1
	run.checkpoint = run.JourneySave.capture(run)
	return true

static func trim_bloom(run: RefCounted, bodies: Array) -> void:
	if run.habitat_choice!="refuge" or not available(run):
		return
	# Remove the fifth food, retaining the three clearly separated snacks.
	var food: Array = bodies.filter(func(body): return body.kind=="food")
	if food.size()>4:
		run.enemies.erase(food[-1])

static func enter(run: RefCounted) -> void:
	if run.habitat_applied:
		return
	run.habitat_confirmed = true
	run.habitat_applied = true
	if not available(run):
		return
	run.habitat_history[run.encounter_key()] = run.habitat_choice
	if run.habitat_choice=="refuge":
		var blooms := {}
		for body in run.enemies:
			if body.kind=="food":
				if not blooms.has(body.bloom_id):
					blooms[body.bloom_id] = []
				blooms[body.bloom_id].append(body)
		for bodies in blooms.values():
			trim_bloom(run,bodies)
		run.harvest.visitor_at = 36.0

static func hunter_arrives(run: RefCounted, wave: int) -> bool:
	return not available(run) or run.habitat_choice!="refuge" or wave%2==0
