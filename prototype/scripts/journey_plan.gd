extends RefCounted
## Authored journey data. Goals introduce new decisions, never faster input.
const DISHES := [
	{"name": "Stillwater", "subtitle": "A colony learns to feed", "rule": "Quiet currents. Learn which organisms nourish and which poison.", "color": Color("a1ddd5")},
	{"name": "Glassgarden", "subtitle": "Life between the reeds", "rule": "The tide reverses every 18 seconds. Linked glass shields can regrow.", "color": Color("bdd6b0")},
	{"name": "Blue Deep", "subtitle": "A light in the dark", "rule": "Linked predators arrive in pairs. Fit both nuclei inside one membrane.", "color": Color("b4bde8")},
]
const STAGES := [
	{"name": "First nourishment", "mode": "feed", "food": 9, "duration": 180.0, "target": 0, "threats": 0, "lesson": "Green lobed desmids are food. Purple spiked cysts poison. Drag through any ready blue cells, return to the first, then release."},
	{"name": "New life", "mode": "rescue", "food": 18, "duration": 180.0, "target": 2, "threats": 2, "lesson": "Enclose the small pearl-colored spores to bring them home. Gather food as well. Orange hunters must not reach the mother."},
	{"name": "The nursery", "mode": "defend", "food": 18, "duration": 180.0, "target": 3, "threats": 3, "lesson": "Feed the mother and remove three threats. Food thieves and hunters both count. The small bell bud inhales, then opens its gold center for capture. Watch its breath."},
	{"name": "The Bellwether", "mode": "boss", "food": 3, "duration": 240.0, "target": 3, "threats": 0, "lesson": "Like the bell bud, it draws food and poison inward, then opens for 16 seconds. Charge with three food and capture its gold center during the exhale. Repeat three times."},
	{"name": "Clear a passage", "mode": "purify", "food": 20, "duration": 180.0, "target": 4, "threats": 2, "lesson": "A membrane containing ONLY cysts neutralizes them safely in this encounter. Separate the poison from food; mixed meals still hurt."},
	{"name": "Turning tide", "mode": "sectors", "food": 22, "duration": 180.0, "target": 3, "threats": 3, "lesson": "Feed from three different sectors. Amoebas can swallow a blue cell: loop around their gold nucleus within 15 seconds to rescue it. An eaten cell regrows next encounter."},
	{"name": "Glass cradles", "mode": "rescue", "food": 20, "duration": 180.0, "target": 3, "threats": 3, "lesson": "A glass cradle protects the first pearl. Capture both linked shields together, or the second within 18 seconds, then rescue the pearl. Rescue three spores in all."},
	{"name": "The Glass Regent", "mode": "boss", "food": 3, "duration": 240.0, "target": 3, "threats": 0, "lesson": "Use what the glass cradle taught you: break both shields together, or the second within 18 seconds. Spend three food charge to hit the exposed nucleus."},
	{"name": "Shared shelter", "mode": "defend", "food": 22, "duration": 210.0, "target": 4, "threats": 4, "lesson": "Remove four threats and gather food. Linked Twinspores share a membrane: both hearts must fit in your loop."},
	{"name": "A clean current", "mode": "purify", "food": 22, "duration": 210.0, "target": 6, "threats": 3, "lesson": "Neutralize six cysts in poison-only loops. Keep a safe feeding route open while the deep current moves the colony."},
	{"name": "Seeds of tomorrow", "mode": "rescue", "food": 24, "duration": 210.0, "target": 4, "threats": 4, "lesson": "Bring four pearl spores home. Your evolved colony must balance feeding, protection, and rescue."},
	{"name": "The Conjoined", "mode": "boss", "food": 3, "duration": 270.0, "target": 3, "threats": 0, "lesson": "Spend three food charge to enclose BOTH hearts. They spread farther after each hit; wait for them to meet, or draw a wider loop. Young pairs hatch nearby. Capture them before they reach Mother."},
]
const COLONIES := [
	{"id": "wanderer", "name": "The Wanderer", "trait": "", "detail": "An adaptable beginning. Eight-cell membranes, no tradeoffs.", "unlock": "Available from the beginning"},
	{"id": "weaver", "name": "The Weaver", "trait": "fission", "detail": "Starts with Rapid Fission. Small loops recover in two seconds.", "unlock": "Guide a colony out of Stillwater"},
	{"id": "symbiont", "name": "The Symbiont", "trait": "symbiosis", "detail": "Starts with Symbiosis. Captured predators also nourish the colony.", "unlock": "Guide a colony out of Glassgarden"},
]
const BASE_SPECIES := [
	{"id":"bacterium","name":"Copper bacterium","detail":"A rod-shaped bacterial food thief. Loop around its center to recover stolen food immediately, or nudge silver phages close. Infection ruptures it after 9s, releasing food to collect. Harmless to Mother."},
	{"id":"phage","name":"Silver bacteriophages","detail":"Tiny helpers with faceted heads, tails and delicate legs. Drag a cluster toward a copper bacterium; they attach and rupture it after 9s. Each cluster treats one host. Never infect Mother, blue cells or amoebas."},
	{"id":"amoeba", "name":"Amber amoeba", "detail":"Swallows one blue cell into a clear vacuole. Enclose its gold nucleus with other cells within 15 seconds to rescue it. If digested, the cell is lost until the next encounter. Never harms Mother."},
	{"id":"bell_bud", "name":"Bell bud", "detail":"A young Bellwether. Draws food inward while inhaling, then opens its gold center for sixteen seconds. Capture while OPEN. Counts as one removed threat."},
	{"id": "food", "name": "Desmid", "detail": "Lobed green algae. Every captured desmid gives one food."},
	{"id": "cyst", "name": "Toxic cyst", "detail": "Spiked violet husk. Drag it aside with Nudge, ready every 6s. Eating one costs a health core. Purification encounters allow cyst-only loops."},
	{"id": "spore", "name": "Pearl spore", "detail": "A young colony. Enclose its bright center to rescue it. Every rescued spore lives on in your home pond; rescues also advance nursery goals."},
	{"id": "drifter", "name": "Drifter", "detail": "Amber hunter. Pursues nearby food or spores before Mother. Capture during its six-second meal to intervene; a fed hunter slows and gives stolen food back when captured."},
	{"id": "shellback", "name": "Shellback", "detail": "A ridged glass shell protects its nucleus. Two pulses, or one wide Enzyme membrane."},
	{"id": "twinspore", "name": "Twinspore", "detail": "Two linked violet bodies. Both nuclei must be inside the same membrane."},
	{"id": "bellwether", "name": "Bellwether", "detail": "Draws nearby food and poison inward while inhaling. Its gold center then opens for sixteen seconds. Each hit uses three food charge."},
	{"id": "regent", "name": "Glass Regent", "detail": "Break both linked shields together, or finish the second within eighteen seconds before they regrow. It then opens for fourteen seconds. Each hit uses three food charge."},
	{"id": "conjoined", "name": "The Conjoined", "detail": "Both hearts must fit in one loop. Each lost layer spreads them farther apart, then they meet again. Young pairs hatch nearby after each hit; catch them before they reach Mother."},
	{"id": "grazer", "name": "Fan grazer", "detail": "Steals nearby green food. Capture its fan-shaped body to recover everything still in its stomach."},
	{"id": "parasite", "name": "Coral parasite", "detail": "A pink tether blocks one blue cell. Capture the curled parasite using the other cells around its body."},
	{"id": "divider", "name": "Divider", "detail": "A ribbed rod that splits after twenty seconds. Stop it early, or catch both young hunters in one wider loop."},
	{"id": "warden", "name": "Shield organism", "detail": "Pale strands connect it to a protected organism. Break both together, or finish the second within eighteen seconds, to expose what lies inside."},
]

const SPECIES = BASE_SPECIES + preload("res://scripts/creature_forms.gd").ENTRIES

static func stage(index: int) -> Dictionary:
	var result: Dictionary = STAGES[clampi(index,0,STAGES.size()-1)].duplicate(true)
	result.featured = ["food","grazer","grazer","bellwether","parasite","amoeba","divider","regent","divider","parasite","divider","conjoined"][clampi(index,0,11)]
	return result

static func dish(index: int) -> Dictionary:
	return DISHES[clampi(index / 4, 0, 2)]

static func search_hint(entry: Dictionary) -> String:
	if entry.get("expedition",false):
		return "Rare in %s. Each new journey hosts one of four local forms, favoring discoveries missing from your journal." % dish(int(entry.first_stage)).name
	if entry.get("rare",false):
		return "Look in %s. Choose the sheltered route to guarantee a visitor, then rescue its pearl before it leaves." % dish(int(entry.first_stage)).name
	if entry.has("first_stage"):
		return "May appear in %s. Watch the new arrivals; its form varies between journeys." % dish(int(entry.first_stage)).name
	var introductions := {"bacterium":2,"phage":2,"amoeba":5,"food":0,"cyst":0,"spore":1,"drifter":1,"shellback":4,"twinspore":8,"bell_bud":2,"bellwether":3,"regent":7,"conjoined":11,"grazer":1,"parasite":4,"divider":6,"warden":6}
	var stage_index: int = introductions.get(entry.id,0)
	return "Look in %s. The encounter briefing explains what to do when you meet it." % dish(stage_index).name
