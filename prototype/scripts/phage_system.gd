extends RefCounted
## A nudge is the only input. A cluster treats one bacterium; released progeny
## are a visual aftermath, preventing unattended chain-clearing of the dish.
const Cluster = preload("res://scripts/phage_cluster.gd")
const Bacterium = preload("res://scripts/bacterium.gd")
const CONTACT_RADIUS := 36.0
var clusters: Array = []
var bursts: Array = []
var burst_serial := 0
var learned := false

func reset() -> void:
	clusters.clear()
	bursts.clear()
	burst_serial = 0

func host(run: RefCounted, number: int) -> RefCounted:
	for body in run.enemies:
		if body.id==number and body.kind=="bacterium": return body
	return null

func add(run: RefCounted, at: Vector2) -> RefCounted:
	if clusters.size()>=2: return null
	run.next_enemy_id += 1
	var group := Cluster.new(run.next_enemy_id,at)
	clusters.append(group)
	run.discover("phage")
	return group

func pair(run: RefCounted, body: RefCounted) -> void:
	# A short push can bridge the gap; spawning never infects automatically.
	# Prefer a patch away from blue cells so their drawing priority is intact.
	var at: Vector2 = body.nucleus+Vector2(0,-72)
	var clearance := -INF
	for i in 16:
		var candidate: Vector2 = body.nucleus+Vector2.from_angle(i*TAU/16.0)*72.0
		if candidate.distance_to(run.board.center)>run.board.dish_radius-40.0: continue
		var distance := INF
		for cell in run.board.anchors: distance = minf(distance,candidate.distance_to(cell))
		if distance>clearance:
			clearance = distance
			at = candidate
	add(run,at)

func free_cluster() -> RefCounted:
	for group in clusters:
		if group.host_id<0 and group.age>2.5 and group.opacity()>0.4: return group
	return null

func nearest_host(run: RefCounted, at: Vector2, radius: float = INF) -> RefCounted:
	var chosen: RefCounted
	for body in run.enemies:
		if body.kind!="bacterium" or body.infection_age>=0.0 or body.age<2.5: continue
		var distance: float = body.nucleus.distance_to(at)
		if distance<radius:
			chosen = body
			radius = distance
	return chosen

func aftermath(delta: float) -> void:
	for burst in bursts: burst.age += delta
	bursts = bursts.filter(func(b): return b.age<3.2)

func step(run: RefCounted, delta: float) -> void:
	aftermath(delta)
	var consumed: Array = []
	for group in clusters:
		if group.host_id>=0:
			var body := host(run,group.host_id)
			if body==null:
				consumed.append(group.id) # A direct capture has already resolved it.
				continue
			group.age += delta
			group.nucleus = body.nucleus
			if body.infection_remaining()<=0.0:
				rupture(run,body)
				consumed.append(group.id)
			continue
		group.step(delta,run.board.center)
		group.advect((run.fluid.sample(group.nucleus)*0.2).limit_length(1.2)*delta)
		var bound: Vector2 = run.board.center+(group.nucleus-run.board.center).limit_length(run.board.dish_radius-30.0)
		group.advect(bound-group.nucleus)
		if group.age>=group.lifetime():
			consumed.append(group.id)
			continue
		if group.age<2.5: continue
		var body := nearest_host(run,group.nucleus,CONTACT_RADIUS)
		if body!=null:
			group.host_id = body.id
			group.attached_from = group.nucleus
			body.infection_age = 0.0
			learned = true
			run.harvest.ecology.announce("Phages attached · bacterium ruptures in 9s. You can keep feeding.")
	clusters = clusters.filter(func(g): return not consumed.has(g.id))

func rupture(run: RefCounted, body: RefCounted) -> void:
	if not run.enemies.has(body): return
	burst_serial += 1
	bursts.append({"at":body.nucleus,"age":0.0,"angle":body.heading.angle(),"serial":burst_serial})
	run.enemies.erase(body)
	run.harvest.defended += 1
	run.kills += 1
	for i in body.stored_food:
		run.next_enemy_id += 1
		var offset := Vector2.from_angle(i*TAU/maxi(1,body.stored_food)+body.id)*20.0
		var food = run.Harvest.Organism.new(run.next_enemy_id,"food",body.nucleus+offset,Vector2(4,3),float(i))
		food.story = "phage_salvage"
		run.enemies.append(food)
	var detail := " · loop around the %d released food" % body.stored_food if body.stored_food>0 else " · one threat removed"
	run.harvest.ecology.announce("Bacterium ruptured"+detail)

func water_sources(run: RefCounted) -> void:
	for burst in bursts:
		if burst.age<1.8:
			var strength: float = sin(burst.age/1.8*PI)
			run.fluid.sources.append(Vector4(burst.at.x,burst.at.y,28.0*strength,5.0*strength))

func snapshot() -> Dictionary:
	var groups: Array = []
	for group in clusters:
		var data := {}
		for key in ["id","nucleus","origin","drift","phase","age","host_id","attached_from","nudge_vector","nudge_elapsed"]:
			data[key] = group.get(key)
		groups.append(data)
	return {"clusters":groups,"bursts":bursts.duplicate(true),"serial":burst_serial,"learned":learned}

func restore(data: Dictionary) -> void:
	reset()
	learned = data.get("learned",false)
	burst_serial = data.get("serial",0)
	bursts = data.get("bursts",[]).duplicate(true)
	for value in data.get("clusters",[]):
		var group := Cluster.new(value.id,value.nucleus)
		for key in ["nucleus","origin","drift","phase","age","host_id","attached_from","nudge_vector","nudge_elapsed"]:
			if value.has(key): group.set(key,value[key])
		clusters.append(group)
