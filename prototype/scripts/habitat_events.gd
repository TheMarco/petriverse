extends RefCounted
## One authored ecological moment per biome. Saved world state, ordinary
## organisms and bounded currents; no bonus input speed or hidden capture rule.
const KINDS := {2:"migration",5:"hatching",9:"traveller"}

static func begin(run: RefCounted) -> void:
	var kind: String = run.harvest.spec.get("event",KINDS.get(run.stage_index,""))
	if kind.is_empty():
		return
	run.harvest.event_state = {"kind":kind,"at":run.harvest.spec.get("event_at",46.0),"born":false,"warned":false,"woken":false,"wake_warned":false,"food":[],"sites":[]}

static func sample(run: RefCounted) -> Dictionary:
	if not run.journey or run.harvest.event_state.is_empty():
		return {}
	var event: Dictionary = run.harvest.event_state
	var age: float = run.stage_elapsed-float(event.at)
	if age< -8.0 or age>32.0:
		return {}
	var names := {"migration":"A drifting bloom", "hatching":"A sleeping garden", "traveller":"A giant in the deep"}
	var result := {"kind":event.kind,"age":age,"title":names[event.kind],"warning":age<0.0,"position":traveller_position(run),"strength":smoothstep(0.0,5.0,age)*(1.0-smoothstep(24.0,32.0,age))}
	if age<0.0:
		result.detail = "Arrives in %ds · watch the water" % ceili(-age)
	elif event.kind=="hatching":
		result.detail = "Cysts hatch in %ds · gather the green food first" % ceili(22.0-age) if age<22.0 else "The garden has woken · leave purple cysts outside"
	elif event.kind=="migration":
		result.detail = "A food bloom is drifting past · its grazer follows"
	else:
		result.detail = "Harmless, far below · its current separates food and poison"
	return result

static func traveller_position(run: RefCounted) -> Vector2:
	var age: float = run.stage_elapsed-float(run.harvest.event_state.get("at",46.0))
	return run.board.center+Vector2(lerpf(-315.0,315.0,clampf(age/32.0,0.0,1.0)),96.0+sin(age*0.09)*23.0)

static func add_food(run: RefCounted, at: Vector2, phase: float) -> void:
	run.next_enemy_id += 1
	var food = run.Harvest.Organism.new(run.next_enemy_id,"food",at,Vector2(5,4),phase)
	food.bloom_id = 100000+run.stage_index
	run.enemies.append(food)
	run.harvest.event_state.food.append(food.id)
	preload("res://scripts/creature_forms.gd").assign(run,food)

static func step(run: RefCounted, delta: float) -> void:
	var event: Dictionary = run.harvest.event_state
	if event.is_empty():
		return
	var age: float = run.stage_elapsed-float(event.at)
	if age>=-8.0 and not event.warned:
		event.warned = true
		run.harvest.ecology.announce(sample(run).title+" · arrives in 8s")
	if age<0.0 or age>32.0:
		return
	if not event.born:
		event.born = true
		if event.kind in ["migration","hatching"]:
			var area: int = (run.harvest.rotation+2)%8
			for i in 3:
				var at: Vector2 = run.harvest.ecology.pocket(run,(area+i)%8)
				event.sites.append(at)
				for j in 2:
					add_food(run,at+Vector2((j-0.5)*20,0),float(i+j))
			if event.kind=="migration":
				run.harvest.ecology.pending.append({"at":run.stage_elapsed+8.0,"kind":"grazer","area":area})
	if event.kind=="migration":
		for body in run.enemies:
			if event.food.has(body.id):
				var next: Vector2 = body.origin+Vector2(2.6,-0.9)*delta
				if next.distance_to(run.board.center)<330.0:
					body.origin = next
	elif event.kind=="hatching":
		if age>=14.0 and not event.wake_warned:
			event.wake_warned = true
			run.harvest.ecology.announce("The garden is waking · cysts hatch at the marked sites in 8s")
		if age>=22.0 and not event.woken:
			event.woken = true
			for at in event.sites:
				run.next_enemy_id += 1
				var cyst = run.Harvest.Organism.new(run.next_enemy_id,"cyst",at,Vector2(6,4),float(run.next_enemy_id))
				run.enemies.append(cyst)
				preload("res://scripts/creature_forms.gd").assign(run,cyst)
	elif event.kind=="traveller":
		var center := traveller_position(run)
		var strength: float = sample(run).strength
		for body in run.enemies:
			if body.kind not in ["food","cyst"] or body.nucleus.distance_to(center)>180.0:
				continue
			var direction := Vector2(0,-1) if body.kind=="food" else Vector2(0,1)
			var next: Vector2 = body.origin+direction*2.8*strength*delta
			if next.distance_to(run.board.center)<334.0:
				body.origin = next
