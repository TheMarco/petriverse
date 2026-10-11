extends RefCounted
## Rules and player-facing descriptions share this small, fixed catalogue.

const CATALOG := [
	{"id": "fission", "name": "Rapid Fission", "mark": "I", "role": "PRECISION", "summary": "Small loops return sooner.", "detail": "3–4 cell loops recover in 2 seconds.\nKeep a nimble route near the mother.", "tradeoff": "Larger loops keep their usual recovery."},
	{"id": "elastic", "name": "Elastic Membranes", "mark": "II", "role": "REACH", "summary": "Reach across the whole colony.", "detail": "Connect up to 10 cells in one loop.\nCatch pairs or distant groups together.", "tradeoff": "Every loop takes 0.6s longer to return."},
	{"id": "enzyme", "name": "Enzyme Sacs", "mark": "III", "role": "POWER", "summary": "Wide loops dissolve armor.", "detail": "Loops of 6+ cells deal two damage.\nDigest a Shellback in a single capture.", "tradeoff": "Those loops take 1.2s longer to return."},
	{"id": "frenzy", "name": "Feeding Frenzy", "mark": "IV", "role": "FLOW", "summary": "A feast keeps your start alive.", "detail": "Digest 3+ bodies in one loop and its\nstarting cell stays immediately ready.", "tradeoff": "Twinspores count as two bodies."},
	{"id": "lure", "name": "Osmotic Lure", "mark": "V", "role": "GATHER", "summary": "Bring the next meal closer.", "detail": "Each loop gently draws nearby enemies\ntoward it. Prepare your next capture.", "tradeoff": "The Conjoined resists this current."},
	{"id": "residual", "name": "Residual Membrane", "mark": "VI", "role": "CONTROL", "summary": "Leave a little time behind.", "detail": "A loop leaves a brief membrane.\nCrossing enemies slow by 40% for 1s.", "tradeoff": "The Conjoined passes through freely."},
]

const JOURNEY_CATALOG := [
	{"id": "filter", "name": "Filter Veil", "mark": "VII", "role": "TOLERANCE", "summary": "One cyst becomes harmless.", "detail": "Filter the first cyst in each meal.\nChoose richer, contaminated pockets.", "tradeoff": "Every membrane returns 1.2s later."},
	{"id": "feast", "name": "Feast Chambers", "mark": "VIII", "role": "ABUNDANCE", "summary": "Large meals feed twice more.", "detail": "Four or more desmids give +2 food.\nPlan a generous enclosure.", "tradeoff": "Wide loops return 1 second later."},
	{"id": "grazer", "name": "Delicate Grazer", "mark": "IX", "role": "PRECISION", "summary": "Small clean meals go further.", "detail": "One or two desmids give +1 food\nif the membrane causes no poison.", "tradeoff": "Large meals gain no bonus."},
	{"id": "symbiosis", "name": "Symbiosis", "mark": "X", "role": "DEFENSE", "summary": "Protection becomes nourishment.", "detail": "Each captured threat gives +2 food.\nGuard the mother while she feeds.", "tradeoff": "Cracking armor alone gives no food."},
	{"id": "catalyst", "name": "Bitter Catalyst", "mark": "XI", "role": "RISK", "summary": "Turn swallowed cysts into food.", "detail": "Each cyst in a meal gives +2 food.\nCombines with the Filter Veil.", "tradeoff": "Unfiltered cysts still cost an organelle."},
	{"id": "nursery", "name": "Living Nursery", "mark": "XII", "role": "RENEWAL", "summary": "Clean feeding grows new life.", "detail": "Every 12 clean desmids regrow\none of the mother's organelles.", "tradeoff": "Progress resets each encounter."},
]

static func definition(id: String) -> Dictionary:
	for item in CATALOG + JOURNEY_CATALOG:
		if item.id == id:
			return item
	return {}

static func recovery(selected: Array, size: int, base: float = 3.0) -> float:
	var seconds := maxf(1.0, base - 1.0) if selected.has("fission") and size <= 4 else base
	if selected.has("elastic"):
		seconds += 0.6
	if selected.has("enzyme") and size >= 6:
		seconds += 1.2
	if selected.has("filter"):
		seconds += 1.2
	if selected.has("feast") and size >= 6:
		seconds += 1.0
	return maxf(1.0, seconds)

static func damage(selected: Array, size: int) -> int:
	return 2 if selected.has("enzyme") and size >= 6 else 1

static func maximum(selected: Array) -> int:
	return 10 if selected.has("elastic") else 8

static func food_bonus_text(meal: Dictionary) -> String:
	var bonuses: Dictionary = meal.get("food_bonuses",{})
	if bonuses.is_empty():
		return ""
	var traits: Array = bonuses.keys()
	# Dot-assigned dictionary keys can be StringName values; compare their
	# text so equal bonuses do not depend on intern allocation order.
	traits.sort_custom(func(a,b): return bonuses[a]>bonuses[b] or (bonuses[a]==bonuses[b] and str(a)<str(b)))
	var first_name: String = "Feeder organelle" if str(traits[0])=="feeder" else definition(traits[0]).name
	var text := "%s +%d" % [first_name,bonuses[traits[0]]]
	var other := 0
	for id in traits.slice(1):
		other += int(bonuses[id])
	if other>0:
		text += " · other bonuses +%d" % other
	return text

static func offers(selected: Array, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for item in CATALOG:
		if not selected.has(item.id):
			pool.append(item.id)
	var result: Array = []
	while result.size() < 3 and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		result.append(pool.pop_at(index))
	return result

const BUILD_PATHS := {
	"fission": {"name":"NIMBLE COLONY", "synergy":["grazer","frenzy","lure","nursery"]},
	"elastic": {"name":"FEAST COLONY", "synergy":["feast","enzyme","filter","catalyst"]},
	"symbiosis": {"name":"HUNTER COLONY", "synergy":["enzyme","residual","frenzy","nursery"]}
}

static func build_anchor(selected: Array) -> String:
	for id in selected:
		if BUILD_PATHS.has(id):
			return id
	return ""

static func build_name(selected: Array) -> String:
	var anchor := build_anchor(selected)
	return BUILD_PATHS[anchor].name if not anchor.is_empty() else "AN ADAPTABLE COLONY"

static func journey_offers(selected: Array, rng: RandomNumberGenerator, defense_learned: bool = true) -> Array:
	if selected.is_empty():
		return ["fission","elastic"]
	var pool: Array = []
	for item in CATALOG+JOURNEY_CATALOG:
		if not selected.has(item.id) and (defense_learned or item.id not in ["symbiosis", "enzyme", "residual"]):
			pool.append(item.id)
	var result: Array = []
	var anchor := build_anchor(selected)
	if not anchor.is_empty():
		var related: Array = pool.filter(func(id): return BUILD_PATHS[anchor].synergy.has(id))
		while result.size()<2 and not related.is_empty():
			var id: String = related.pop_at(rng.randi_range(0,related.size()-1))
			result.append(id)
			pool.erase(id)
	# One offer always permits experimentation outside the favored family.
	if not anchor.is_empty() and result.size()==2:
		var alternatives: Array = pool.filter(func(id): return not BUILD_PATHS[anchor].synergy.has(id))
		if not alternatives.is_empty():
			result.append(alternatives[rng.randi_range(0,alternatives.size()-1)])
	while result.size()<3 and not pool.is_empty():
		result.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))
	return result

static func journey_definition(id: String) -> Dictionary:
	var item := definition(id).duplicate(true)
	if id == "fission":
		item.role = "NIMBLE COLONY"
		item.summary = "Quick, precise meals feed more."
		item.detail = "Clean 3–4-cell meals give +1 food.\nThose cells recover in 2 seconds."
		item.tradeoff = "Larger loops get neither bonus."
	elif id == "elastic":
		item.role = "FEAST COLONY"
		item.summary = "Wider membranes gather more food."
		item.detail = "6+ cell loops give double desmid food.\nConnect up to 10 cells."
	elif id == "symbiosis":
		item.role = "HUNTER COLONY"
	if id == "lure":
		item.detail = "A membrane draws nearby desmids\ntoward it. Prepare the next meal."
		item.tradeoff = "Food moves; cysts stay in their current."
	elif id == "residual":
		item.detail = "A membrane lingers for 4 seconds.\nCrossing hunters slow by 40% for 1s."
	return item
