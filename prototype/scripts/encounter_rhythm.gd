extends RefCounted
## Later encounters shorten the lull and occasionally approach from two sides.
## Arrival warnings, movement speeds and capture windows stay human-readable.
const CYCLE := 48.0
const WARNING := 12.0
const ARRIVAL := 20.0
const REST := 34.0
const WAVE_CYCLES := [48.0,48.0,48.0,48.0,46.0,44.0,42.0,42.0,40.0,38.0,36.0,36.0]

static func legacy_pacing() -> Dictionary:
	return {"cycle":CYCLE,"warning":WARNING,"arrival":ARRIVAL,"rest":REST,"extra_every":0}

static func pacing(stage: int) -> Dictionary:
	var index := clampi(stage,0,11)
	var quiet := 12.0 if index<4 else 10.0 if index<8 else 8.0
	# Bosses already demand timed captures and can create their own hunters.
	var extra := 0 if index<5 or index%4==3 else 2 if index<10 else 1
	return {"cycle":WAVE_CYCLES[index],"warning":quiet,"arrival":quiet+8.0,"rest":quiet+22.0,"extra_every":extra}

static func sample(run: RefCounted) -> Dictionary:
	if run.stage_index == 0:
		return {"id":"practice", "title":"A quiet beginning", "detail":"Take your time. Learn the shape of a capture.", "remaining":0.0, "energy":0.0, "cycle":0}
	var pace: Dictionary = run.harvest.ecology.pace
	var local_time: float = run.stage_elapsed-run.harvest.ecology.rhythm_origin
	var t := fposmod(local_time, pace.cycle)
	var cycle := int(local_time/pace.cycle)
	if t < pace.warning:
		return {"id":"feed", "title":"A feeding current", "detail":"Gather food and prepare your cells.", "remaining":pace.warning-t, "energy":0.12, "cycle":cycle}
	if t < pace.arrival:
		return {"id":"warning", "title":"Life is approaching", "detail":"Watch the marked water. New organisms emerge there.", "remaining":pace.arrival-t, "energy":lerpf(0.15,0.65,(t-pace.warning)/(pace.arrival-pace.warning)), "cycle":cycle}
	if t < pace.rest:
		return {"id":"surge", "title":"The pond stirs", "detail":"Protect the mother while the bloom draws visitors.", "remaining":pace.rest-t, "energy":0.72, "cycle":cycle}
	return {"id":"rest", "title":"A moment of stillness", "detail":"The next wave is resting. Finish your captures and let the colony recover.", "remaining":pace.cycle-t, "energy":lerpf(0.3,0.05,(t-pace.rest)/(pace.cycle-pace.rest)), "cycle":cycle}

static func sector(run: RefCounted, cycle: int) -> int:
	return posmod(run.harvest.rotation+cycle*int(run.harvest.spec.get("sector_step",3)),8)

static func warning_sites(run: RefCounted) -> Array:
	var result: Array = []
	for event in run.harvest.ecology.pending:
		var remaining: float = event.at-run.stage_elapsed
		if remaining <= 0.0 or remaining > 8.0 or event.kind in ["bloom", "spore"]:
			continue
		var point: Vector2 = run.harvest.ecology.arrival_site(run,event).position
		result.append({"position":point,"remaining":remaining,"kind":event.kind})
	return result
