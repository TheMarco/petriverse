extends RefCounted
const Expedition = preload("res://scripts/expedition_creatures.gd")
## Visual forms share an established role. No extra RNG draws or balance changes.
const ENTRIES := [
	{"id":"glowdrift", "kind":"spore", "name":"Glowdrift", "detail":"Rare shelter organism. When its chambers shine, nearby ordinary hunters slow down. Leave it as shelter, or rescue its central pearl for your pond.", "first_stage":8, "rare":true, "uv":Vector2(0.574,0.419)},
	{"id":"glass_harp", "kind":"spore", "name":"Glass Harp", "detail":"Rare filter feeder. Draws nearby green food inward and gently pushes purple cysts away. Leave it to separate a meal, or rescue its pearl for your pond.", "first_stage":4, "rare":true, "uv":Vector2(0.521,0.497)},
	{"id":"moonlace", "kind":"spore", "name":"Moonlace", "detail":"Rare visitor. Releases green food as its petals open. Leave it to feed the water, or loop around its pearl to bring it home.", "first_stage":2, "rare":true, "uv":Vector2(0.485,0.499)},
	{"id": "lantern_grazer", "kind": "grazer", "name": "Lantern grazer", "detail": "Pale-gold food thief. Capture its center to recover all food still in its stomach before it swims away.", "first_stage": 1, "uv": Vector2(0.491,0.487)},
	{"id": "fern_desmid", "kind": "food", "name": "Fern desmid", "detail": "Green food. Enclose its bright center for one nourishment. Its shape changes; the feeding rule stays the same.", "first_stage": 1, "uv": Vector2(0.49,0.485)},
	{"id": "spiral_alga", "kind": "food", "name": "Spiral alga", "detail": "Green food. Enclose its bright center for one nourishment. Its shape changes; the feeding rule stays the same.", "first_stage": 4, "uv": Vector2(0.489,0.484)},
	{"id": "crown_cyst", "kind": "cyst", "name": "Crown cyst", "detail": "Purple poison. A mixed meal costs one health. In purification missions, capture cysts alone to clear them safely.", "first_stage": 2, "uv": Vector2(0.49,0.49)},
	{"id": "bramble_cyst", "kind": "cyst", "name": "Bramble cyst", "detail": "Purple poison. A mixed meal costs one health. In purification missions, capture cysts alone to clear them safely.", "first_stage": 5, "uv": Vector2(0.492,0.481)},
	{"id": "snow_spore", "kind": "spore", "name": "Snow spore", "detail": "Pearl-white rescue spore. Enclose its center before it fades away. Counts toward your rescue goal.", "first_stage": 1, "uv": Vector2(0.491,0.486)},
	{"id": "sail_spore", "kind": "spore", "name": "Sail spore", "detail": "Pearl-white rescue spore. Enclose its center before it fades away. Counts toward your rescue goal.", "first_stage": 6, "uv": Vector2(0.5,0.629)},
	{"id": "needle_hunter", "kind": "drifter", "name": "Needle hunter", "detail": "Amber hunter. Enclose its gold center before it reaches the mother. One capture absorbs it.", "first_stage": 2, "uv": Vector2(0.515,0.483)},
	{"id": "ribbon_hunter", "kind": "drifter", "name": "Ribbon hunter", "detail": "Amber hunter. Enclose its gold center before it reaches the mother. One capture absorbs it.", "first_stage": 6, "uv": Vector2(0.49,0.489)},
	{"id": "comb_grazer", "kind": "grazer", "name": "Comb grazer", "detail": "Pale-gold food thief. Capture its center to recover all food still in its stomach before it swims away.", "first_stage": 5, "uv": Vector2(0.49,0.492)},
	{"id": "lace_parasite", "kind": "parasite", "name": "Lace parasite", "detail": "Pink cell parasite. Follow its tether and capture the body to free the blocked blue cell.", "first_stage": 5, "uv": Vector2(0.49,0.498)},
	{"id": "hourglass_divider", "kind": "divider", "name": "Hourglass divider", "detail": "Blue divider. Capture its central gold nucleus before it splits at twenty seconds, or catch its two young.", "first_stage": 8, "uv": Vector2(0.49,0.49)},
] + Expedition.ENTRIES
static var textures: Dictionary = {}

static func definition(id: String) -> Dictionary:
	for entry in ENTRIES:
		if entry.id == id:
			return entry
	return {}

static func texture(id: String) -> Texture2D:
	if definition(id).is_empty():
		return null
	if not textures.has(id):
		textures[id] = load("res://assets/organisms/" + id + ".png")
	return textures[id]

static func assign(run: RefCounted, body: RefCounted) -> void:
	if not run.journey:
		return
	var pool: Array[String] = [""]
	for entry in ENTRIES:
		if entry.kind == body.kind and entry.first_stage <= run.stage_index and not entry.get("rare",false):
			pool.append(entry.id)
	# A separate cosmetic stream avoids repeating the same form whenever a
	# wave happens to contain a multiple of the pool size.
	var variation := RandomNumberGenerator.new()
	variation.seed = run.run_seed ^ (body.id * 0x45d9f3b) ^ (run.stage_index * 0x119de1f3)
	body.form = pool[variation.randi_range(0, pool.size()-1)]
	if not body.form.is_empty():
		run.discover(body.form)

static func valid_form(form: String, kind: String) -> bool:
	var entry := definition(form)
	return not entry.is_empty() and entry.kind == kind
