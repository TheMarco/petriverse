extends RefCounted
## Seeded compositions around authored teaching beats. Stored in full in saves,
## so a balance/content update never rerolls a journey already in progress.
const Plan = preload("res://scripts/journey_plan.gd")
const EXTRA := {2:1,5:1,8:1}
const TOTAL := 15
const LEGACY_TOTAL := 30
const MAX_TRAITS := 6
const NAMES := {
	"feed":["Algae orchard","A generous current","Gathering season","Drifting banquet"],
	"rescue":["Pearl migration","Lost hatchlings","A scattered nursery","Carrying new life"],
	"defend":["Hungry neighbours","The living perimeter","Between two hunters","Guarding the garden"],
	"purify":["Violet shallows","Clearing the nursery","Poison in the reeds","A cleaner home"],
	"sectors":["Across the current","Many little gardens","The wandering harvest","Food on every shore"],
}
const DETAILS := {
	"feed":"Gather green food. Nudge purple cysts aside to keep meals clean.",
	"rescue":"Rescue pearl spores while gathering food. A hunter may try to eat them first.",
	"defend":"Capture threats while feeding. Catch hunters before they reach Mother.",
	"purify":"Capture purple cysts in poison-only loops. Feed using separate clean loops.",
	"sectors":"Collect food in the marked sectors around the dish. Move between feeding pockets.",
}
const FAMILY_DETAILS := {
	"bacterium":"Copper bacteria steal food. Push silver phages toward them; infected bacteria rupture after 9s, releasing stolen food.",
	"amoeba":"Amoebas swallow blue cells. Loop around their gold nucleus within 15s to rescue the cell.",
	"grazer":"Food thieves compete for algae; catching them returns what they ate.",
	"parasite":"Parasites block blue cells; capture their bodies using other cells.",
	"divider":"Dividers split if ignored; catch the parent early or both young later.",
}

static func make(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x2c716e49
	var result: Array = []
	var previous := ""
	var names_used: Dictionary = {}
	for stage in 12:
		var authored: Dictionary = Plan.stage(stage)
		authored.stage = stage
		authored.generated = false
		result.append(authored)
		previous = authored.mode
		for _visit in int(EXTRA.get(stage,0)):
			var biome := stage/4
			var pool := ["feed","rescue"]
			if stage>=2: pool.append("defend")
			if stage>=4: pool.append("purify")
			if stage>=5: pool.append("sectors")
			pool.erase(previous)
			var mode: String = pool[rng.randi_range(0,pool.size()-1)]
			if stage==2 and _visit==0: mode = "feed"
			previous = mode
			var families := ["grazer"]
			if stage>=4: families.append_array(["parasite","bacterium"])
			if stage>=6: families.append("divider")
			if stage>=5: families.append("amoeba")
			var family: String = families[rng.randi_range(0,families.size()-1)]
			var companion: String = families[rng.randi_range(0,families.size()-1)]
			var title_pool: Array = NAMES[mode].filter(func(n): return not names_used.has(n))
			if title_pool.is_empty(): title_pool = NAMES[mode].duplicate()
			var title: String = title_pool[rng.randi_range(0,title_pool.size()-1)]
			names_used[title] = true
			var event_pool := ["migration"]
			if stage>=5: event_pool.append("hatching")
			if stage>=8: event_pool.append("traveller")
			var target: int = {"feed":0,"rescue":3+int(biome==2),"defend":3+biome,"purify":4+biome,"sectors":4}[mode]
			result.append({"stage":stage,"generated":true,"name":title,"mode":mode,
				"food":(24 if mode=="feed" else 18)+biome*4+rng.randi_range(0,2)*2,
				"target":target,"duration":330.0+biome*30.0,"threats":4+biome,
				"featured":family,"families":[family,companion],
				"hunter":"drifter" if stage<4 else ["drifter","shellback"][rng.randi_range(0,1)] if stage<8 else ["drifter","shellback","twinspore"][rng.randi_range(0,2)],
				"event":event_pool[rng.randi_range(0,event_pool.size()-1)],"event_at":float(rng.randi_range(34,52)),
				"sector_step":[3,5,7][rng.randi_range(0,2)],"lesson":DETAILS[mode]+" "+FAMILY_DETAILS[family]})
	# A quiet, guaranteed introduction before phages join the procedural pool.
	for spec in result:
		if spec.stage==2 and spec.generated:
			spec.merge({"name":"Small allies","mode":"feed","food":20,"target":0,"featured":"bacterium","families":["bacterium"],"phage_lesson":true,"lesson":"Silver phages are helpers. Drag their cluster toward the copper bacterium. It ruptures after 9 seconds and releases stolen food. You can also capture the bacterium yourself."},true)
			break
	return result

static func valid(route: Array) -> bool:
	# The full recipe is saved, so existing 30-encounter journeys can finish.
	if route.size() not in [TOTAL,LEGACY_TOTAL]:
		return false
	var previous := 0
	var milestones: Array = []
	for spec in route:
		if not spec is Dictionary:
			return false
		for key in ["stage","generated","name","mode","food","target","duration","threats","featured","lesson"]:
			if not spec.has(key): return false
		var stage := int(spec.stage)
		if stage<previous or stage not in range(12) or spec.mode not in ["feed","rescue","defend","purify","sectors","boss"]:
			return false
		if int(spec.food)<1 or int(spec.target)<0 or float(spec.duration)<60 or float(spec.duration)>600:
			return false
		if not spec.generated:
			milestones.append(stage)
		elif stage%4==3 or spec.mode=="boss":
			return false
		previous = stage
	return milestones==range(12) and route[0].stage==0 and route[-1].stage==11
