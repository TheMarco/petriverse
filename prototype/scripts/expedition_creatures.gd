extends RefCounted
## Rare tissue forms retain familiar gameplay roles. A journey can host only
## one from each biome; selection favors entries missing from the field journal.
const ENTRIES := [
	{"id":"chalice_grazer","kind":"grazer","name":"Chalice grazer","detail":"A rare trumpet-shaped food thief. Capture its golden center to recover stolen algae before it leaves.","first_stage":2,"rare":true,"expedition":true,"uv":Vector2(0.49,0.47)},
	{"id":"sundial_alga","kind":"food","name":"Sundial alga","detail":"Edible green algae with spiralling glass leaves. Enclose its golden center in a clean loop to feed Mother.","first_stage":2,"rare":true,"expedition":true,"uv":Vector2(0.502,0.51)},
	{"id":"glasswing_spore","kind":"spore","name":"Glasswing spore","detail":"A pearl spore with three glass wings. Rescue its golden center before it fades; it will live in your home pond.","first_stage":2,"rare":true,"expedition":true,"uv":Vector2(0.503,0.563)},
	{"id":"trident_hunter","kind":"drifter","name":"Trident hunter","detail":"A three-pronged amber hunter. One capture of its golden center stops it before it reaches Mother.","first_stage":2,"rare":true,"expedition":true,"uv":Vector2(0.50,0.464)},
	{"id":"crown_rotifer","kind":"grazer","name":"Crown rotifer","detail":"Twin filtering wheels steal nearby food. Capture its golden center to reclaim the algae in its stomach.","first_stage":4,"rare":true,"expedition":true,"uv":Vector2(0.494,0.50)},
	{"id":"amber_nautilus","kind":"shellback","name":"Amber nautilus","detail":"A hunter inside a spiral silica shell. Capture its golden center twice: first crack the shell, then finish it.","first_stage":4,"rare":true,"expedition":true,"uv":Vector2(0.453,0.487)},
	{"id":"veil_parasite","kind":"parasite","name":"Veil parasite","detail":"Pink lace clings to a blue cell and blocks it. Use other blue cells to enclose the parasite's golden center.","first_stage":4,"rare":true,"expedition":true,"uv":Vector2(0.508,0.51)},
	{"id":"thistle_capsule","kind":"cyst","name":"Thistle capsule","detail":"A violet poison pod. Nudge it out of a meal, or capture it alone when clearing poison. Mixing it with food hurts Mother.","first_stage":4,"rare":true,"expedition":true,"uv":Vector2(0.50,0.504)},
	{"id":"ribbon_divider","kind":"divider","name":"Ribbon divider","detail":"A ribbon-shaped hunter that divides if ignored. Capture its golden center early, or catch both daughters after the split.","first_stage":8,"rare":true,"expedition":true,"uv":Vector2(0.503,0.50)},
	{"id":"comet_spore","kind":"spore","name":"Comet spore","detail":"A pearl spore trailing silver filaments. Rescue its golden center before it fades to bring it into your home pond.","first_stage":8,"rare":true,"expedition":true,"uv":Vector2(0.52,0.335)},
	{"id":"prism_hunter","kind":"shellback","name":"Prism hunter","detail":"An amber hunter inside a pointed glass lattice. Enclose its golden center twice before it reaches Mother.","first_stage":8,"rare":true,"expedition":true,"uv":Vector2(0.53,0.493)},
	{"id":"sieve_alga","kind":"food","name":"Sieve alga","detail":"Edible green lace with a golden center suspended on a living bridge. Capture the center in a clean meal.","first_stage":8,"rare":true,"expedition":true,"uv":Vector2(0.50,0.493)},
]

static func plan(seed_value: int, route: Array, known: Array) -> Array:
	var variation := RandomNumberGenerator.new()
	variation.seed = seed_value ^ 0x72c9a341
	var result: Array = []
	for biome in 3:
		var pool: Array = ENTRIES.filter(func(e): return int(e.first_stage)/4==biome)
		var unseen: Array = pool.filter(func(e): return not known.has(e.id))
		if not unseen.is_empty(): pool = unseen
		if pool.is_empty(): continue
		var entry: Dictionary = pool[variation.randi_range(0,pool.size()-1)]
		var visits: Array = []
		for index in route.size():
			var spec: Dictionary = route[index]
			if int(spec.stage)/4==biome and int(spec.stage)>=int(entry.first_stage) and spec.get("generated",false):
				visits.append(index)
		if not visits.is_empty():
			result.append({"form":entry.id,"encounter":visits[variation.randi_range(0,visits.size()-1)],"spawned":false})
	return result

static func step(run: RefCounted) -> void:
	if run.stage_elapsed<8.0: return
	for visit in run.expedition_roster:
		if visit.spawned or int(visit.encounter)!=run.encounter_index(): continue
		var matches: Array = ENTRIES.filter(func(e): return e.id==visit.form)
		if matches.is_empty(): continue
		var entry: Dictionary = matches[0]
		# Keep the ordinary director's crowd limits. The visitor waits for space.
		if entry.kind in ["drifter","shellback","divider"] and run.enemies.filter(func(e): return e.kind in ["drifter","shellback","twinspore","divider"]).size()>=4: continue
		if entry.kind in ["grazer","parasite"] and run.enemies.filter(func(e): return e.kind==entry.kind).size()>=2: continue
		spawn(run,entry)
		visit.spawned = true

static func valid(roster: Variant, route: Array) -> bool:
	if not roster is Array or roster.size()>3: return false
	var biomes: Array = []
	for visit in roster:
		if not visit is Dictionary or not visit.get("spawned") is bool: return false
		var entries: Array = ENTRIES.filter(func(e): return e.id==visit.get("form",""))
		var index := int(visit.get("encounter",-1))
		if entries.is_empty() or index not in range(route.size()): return false
		var entry: Dictionary = entries[0]
		var biome := int(entry.first_stage)/4
		if biomes.has(biome) or int(route[index].stage)/4!=biome or int(route[index].stage)<int(entry.first_stage) or not route[index].get("generated",false): return false
		biomes.append(biome)
	return true

static func spawn(run: RefCounted, entry: Dictionary) -> RefCounted:
	var area: int = (run.harvest.rotation+5)%8
	var ecology = run.harvest.ecology
	var body: RefCounted
	if entry.kind in ["food","cyst","spore"]:
		run.next_enemy_id += 1
		body = run.Harvest.Organism.new(run.next_enemy_id,entry.kind,ecology.pocket(run,area,true),Vector2(9,7),float(area))
		body.form = entry.id
		run.enemies.append(body)
	elif entry.kind in ["grazer","parasite","divider"]:
		var site: Dictionary = ecology.arrival_site(run,{"area":area,"kind":entry.kind})
		body = ecology.add(run,entry.kind,area,site.position,entry.id)
		body.destination = site.destination
		if entry.kind=="parasite":
			body.target_node = site.target
			body.site_nodes = site.nodes
	else:
		var at: Vector2 = ecology.pocket(run,area,true)
		run.spawn_enemy({"angle":rad_to_deg((at-run.board.center).angle()),"radius":310.0,"position":at,"speed":5.4,"kind":entry.kind,"form":entry.id})
		body = run.enemies[-1]
	run.discover(entry.kind)
	run.discover(entry.id)
	var action: String = {"food":"green food · gather it", "cyst":"purple poison · keep it out of meals", "spore":"pearl spore · rescue it", "grazer":"food thief · capture its golden center", "parasite":"cell blocker · capture its body", "divider":"splitting hunter · capture it early", "drifter":"hunter · protect Mother", "shellback":"armored hunter · capture twice"}.get(entry.kind,"")
	ecology.announce("Rare discovery: %s · %s" % [entry.name,action])
	return body
