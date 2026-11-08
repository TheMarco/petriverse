extends RefCounted
## Pure before/after comparison for one offered mutation.
## Reads the live run but never writes to it: both sides are evaluated on the
## same synthetic sample with trait arrays, mirroring JourneyHarvest.outcome
## and Mutations.recovery. Recovery assumes short links; actual link strain
## (LoopStrain) varies with link length and is excluded on both sides.

const Mutations = preload("res://scripts/mutations.gd")

const ASSUMPTION := "Example assumes short links; actual link strain varies."
const PLAYSTYLES := {
	"fission": "frequent small clean captures", "grazer": "frequent small clean captures",
	"frenzy": "frequent small clean captures", "nursery": "frequent small clean captures",
	"elastic": "broad feasts", "feast": "broad feasts", "filter": "broad feasts",
	"catalyst": "broad feasts", "symbiosis": "hunting for food", "enzyme": "hunting for food",
	"lure": "hunting for food", "residual": "hunting for food",
}

static func sample_for(offered: String) -> Dictionary:
	match offered:
		"elastic": return {"loop": 6, "bodies": ["food", "food", "food"], "label": "3 desmids in a 6-cell loop"}
		"enzyme": return {"loop": 6, "bodies": ["shellback"], "label": "1 Shellback (2 armor) in a 6-cell loop"}
		"frenzy": return {"loop": 3, "bodies": ["food", "food", "food"], "label": "3 desmids in a 3-cell loop"}
		"lure": return {"loop": 3, "bodies": ["food", "food"], "label": "2 desmids in a 3-cell loop, 1 more nearby"}
		"residual": return {"loop": 3, "bodies": ["food", "food"], "label": "2 desmids in a 3-cell loop, then a hunter crosses it"}
		"filter": return {"loop": 3, "bodies": ["food", "cyst", "cyst"], "label": "1 desmid + 2 cysts in a 3-cell loop"}
		"feast": return {"loop": 6, "bodies": ["food", "food", "food", "food"], "label": "4 desmids in a 6-cell loop"}
		"grazer": return {"loop": 3, "bodies": ["food", "food"], "label": "2 desmids in a 3-cell loop"}
		"symbiosis": return {"loop": 3, "bodies": ["drifter"], "label": "1 hunter in a 3-cell loop"}
		"catalyst": return {"loop": 3, "bodies": ["food", "cyst", "cyst"], "label": "1 desmid + 2 cysts in a 3-cell loop"}
		"nursery": return {"loop": 3, "bodies": ["food", "food"], "label": "2 clean desmids in a 3-cell loop"}
		_: return {"loop": 3, "bodies": ["food", "food", "food"], "label": "3 desmids in a 3-cell loop"}

static func _health_of(kind: String) -> int:
	return 2 if kind == "shellback" else 1

## Mirrors JourneyHarvest.outcome for the sample bodies (feed mode, no boss).
static func evaluate(traits: Array, sample: Dictionary, feeder: int = 0) -> Dictionary:
	var loop_size: int = sample.loop
	var raw := 0
	var cysts := 0
	var threats := 0
	for kind in sample.bodies:
		if kind == "food":
			raw += 1
		elif kind == "cyst":
			cysts += 1
		elif _health_of(kind) <= Mutations.damage(traits, loop_size):
			threats += 1
	var poison := cysts
	var filtered := 0
	if traits.has("filter"):
		filtered = mini(1, cysts)
		poison -= filtered
	var bonuses := {}
	if traits.has("fission") and loop_size <= 4 and raw > 0 and poison == 0:
		bonuses.fission = 1
	if traits.has("elastic") and loop_size >= 6 and raw > 0:
		bonuses.elastic = raw
	if traits.has("feast") and raw >= 4:
		bonuses.feast = 2
	if traits.has("grazer") and raw in [1, 2] and poison == 0:
		bonuses.grazer = 1
	if traits.has("symbiosis") and threats > 0:
		bonuses.symbiosis = threats * 2
	if traits.has("catalyst") and cysts > 0:
		bonuses.catalyst = cysts * 2
	if feeder > 0 and raw >= 4 and poison == 0:
		bonuses.feeder = feeder
	var food := raw
	for amount in bonuses.values():
		food += int(amount)
	return {"food": food, "raw_food": raw, "poison": poison, "filtered": filtered,
		"threats": threats, "food_bonuses": bonuses,
		"recovery": Mutations.recovery(traits, loop_size),
		"capacity": Mutations.maximum(traits), "damage": Mutations.damage(traits, loop_size)}

static func synergy_for(owned: Array, offered: String) -> String:
	var pairs := {
		"catalyst|filter": "Filter Veil neutralises the first cyst while Catalyst turns both cysts into food.",
		"filter|catalyst": "Catalyst pays +2 per cyst; Filter Veil removes the first cyst's poison.",
		"grazer|fission": "Both reward the same clean 3-cell loop, and their bonuses stack.",
		"fission|grazer": "Delicate Grazer stacks on the same small clean loops Fission speeds up.",
		"feast|elastic": "Elastic Membranes doubles desmids in the wide loops Feast Chambers rewards.",
		"elastic|feast": "Feast Chambers adds +2 on top of Elastic's doubled wide-loop desmids.",
		"enzyme|elastic": "Wide loops can both double food with Elastic and break armor with Enzyme Sacs.",
		"enzyme|symbiosis": "Enzyme Sacs kills the Shellback; Symbiosis then pays +2 food for it.",
		"symbiosis|enzyme": "Enzyme Sacs makes wide-loop hunter kills reliable food for Symbiosis.",
		"nursery|fission": "Fission's quick clean loops fill the Nursery's 12-desmid regrowth faster.",
		"nursery|grazer": "Grazer's small clean meals count fully toward Nursery regrowth.",
		"lure|fission": "Lure gathers desmids into the small loops Fission recovers fastest.",
		"frenzy|fission": "Frenzy frees the starting cell of the small loops Fission already speeds up.",
		"filter|elastic": "Elastic catches cyst-rich pockets; Filter Veil makes the first cyst harmless.",
		"residual|symbiosis": "Slowed hunters are easier to enclose for Symbiosis food.",
	}
	for id in owned:
		var key := "%s|%s" % [offered, id]
		if pairs.has(key):
			return pairs[key]
	if owned.is_empty():
		return "First trait: it sets your colony's direction."
	var names: Array = []
	for id in owned:
		names.append(Mutations.definition(id).name)
	return "No direct synergy with %s; it opens a different option." % ", ".join(names)

static func compare(run: RefCounted, offered: String) -> Dictionary:
	var owned: Array = (run.get("mutations") as Array).duplicate()
	var after_traits := owned.duplicate()
	if not after_traits.has(offered):
		after_traits.append(offered)
	var feeder := 0
	if bool(run.get("journey")) and run.has_method("growth_active"):
		feeder = int(run.call("growth_active", "feeder"))
	var sample := sample_for(offered)
	var before := evaluate(owned, sample, feeder)
	var after := evaluate(after_traits, sample, feeder)
	var clean_now := 0
	var harvest = run.get("harvest")
	if harvest != null:
		clean_now = int(harvest.get("clean_food"))
	var effect := ""
	match offered:
		"enzyme":
			effect = "Armor damage %d -> %d: the Shellback is captured, not just cracked." % [before.damage, after.damage]
		"residual":
			effect = "A crossing hunter moves 40% slower for 1.0s; the membrane lasts 4s."
		"lure":
			effect = "The nearby desmid is pulled 22 pixels toward the loop, ready for the next capture."
		"frenzy":
			effect = "3+ bodies in one loop: the starting cell is ready again at once."
		"nursery":
			var total := clean_now + int(after.raw_food)
			effect = "Clean-desmid regrowth: %d/12 -> %d/12%s." % [clean_now, total % 12 if total >= 12 else total, ": +1 organelle regrown" if total >= 12 and int(run.get("integrity")) < int(run.get("max_integrity")) else ""]
		"filter":
			effect = "The first cyst is filtered: poison %d -> %d." % [before.poison, after.poison]
		"catalyst":
			effect = "Each cyst pays +2 food; unfiltered cysts still poison."
		"symbiosis":
			effect = "Each captured hunter also pays +2 food."
	var lines: Array = ["Example: %s." % sample.label,
		"Food %d -> %d" % [before.food, after.food],
		"Cells ready in %.1fs -> %.1fs · loop up to %d -> %d cells" % [before.recovery, after.recovery, before.capacity, after.capacity]]
	if int(before.poison) != int(after.poison) or int(after.poison) > 0:
		lines.append("Poison %d -> %d (each unfiltered cyst costs 1 organelle)" % [before.poison, after.poison])
	if not effect.is_empty():
		lines.append(effect)
	var synergy := synergy_for(owned, offered)
	lines.append(synergy)
	lines.append(ASSUMPTION)
	var definition: Dictionary = Mutations.journey_definition(offered)
	var detail_summary := "%s: %s. %s %s Tradeoff: %s %s" % [definition.get("name", offered), PLAYSTYLES.get(offered, ""), " · ".join(lines.slice(0, lines.size() - 1)), ASSUMPTION, definition.get("tradeoff", ""), synergy]
	return {"offered": offered, "playstyle": PLAYSTYLES.get(offered, ""),
		"sample": sample.label, "assumption": ASSUMPTION, "before": before, "after": after,
		"synergy": synergy, "effect": effect, "lines": lines, "detail_summary": detail_summary}
