extends Node2D
## An isolated, real simulation photographed like the promo reel. Never owns a save.
const Run = preload("res://scripts/run_controller.gd")
const Microscope = preload("res://scripts/microscope.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
var run = Run.new(true,73,true,true)
var microscope: Node2D
var visual_time := 0.0
var reduced_motion := false
var visual_quality := 2
var render_enabled := true
var home_pond = null
var home_pond_open := false
var effects: Array:
	get: return run.clots
var entry := {}
var subject: RefCounted
var companion: RefCounted
var focus := Vector2(640,350)
var zoom := 4.0
var camera_target := Vector2.ZERO
var elapsed := 0.0
var duration := 12.0
var cue := ""
var events: Array = []
var milestones := {}
var gesture: Array = []
var gesture_time := 0.0
var pointer := Vector2.ZERO
var previous_pointer := Vector2.ZERO
var pointer_visible := false
var done_actions := {}

func _ready() -> void:
	microscope = Microscope.new()
	add_child(microscope)

func _exit_tree() -> void:
	run.dispose()

func prepare(data: Dictionary, motion_reduced: bool = false, quality: int = 2) -> void:
	entry = data
	reduced_motion = motion_reduced
	visual_quality = quality
	elapsed = 0.0
	visual_time = 0.0
	events.clear()
	milestones.clear()
	done_actions.clear()
	gesture.clear()
	pointer_visible = false
	var scene: String = entry.scene
	var stage := 2
	if scene in ["amoeba","parasite","shellback","glass_harp"]: stage = 5
	if scene in ["divider","conjoined","glowdrift"]: stage = 8
	if scene in ["regent","warden"]: stage = 7
	if scene=="bellwether": stage = 3
	run.long_journey = false
	run.restart()
	run.route_plan.clear()
	run.stage_index = stage
	run.start_stage()
	run.begin_encounter()
	run.enemies.clear()
	run.phages.reset()
	run.expedition_roster.clear()
	run.harvest.next_bloom = 9999.0
	run.harvest.next_spore = 9999.0
	run.harvest.ecology.next_wave = 9999.0
	run.harvest.ecology.pending.clear()
	run.harvest.visitor_at = -1.0
	run.harvest.spec.duration = 999.0
	run.harvest.spec.target = 999
	run.harvest.spec.food = 999
	run.harvest.nourishment = 9
	duration = {"amoeba":16.8,"phage":14.0,"shellback":16.0,"parasite":15.0,"regent":19.0,"warden":15.0,"bellwether":16.0,"conjoined":16.0}.get(scene,12.0)
	focus = pocket([0,8,9])
	zoom = 4.0
	cue = "Watch its bright center."
	match scene:
		"food","cyst","spore","moonlace","glass_harp","glowdrift":
			subject = organism(entry.kind,focus,entry.get("form",""))
			if scene in ["moonlace","glass_harp","glowdrift"]:
				subject.visitor = true
			if scene=="cyst":
				organism("food",focus+Vector2(28,4))
				cue = "Keep purple poison out of green meals."
			if scene=="glass_harp":
				organism("food",focus+Vector2(68,10))
				organism("cyst",focus+Vector2(-68,10))
				cue = "Food drifts in. Poison drifts away."
			if scene=="glowdrift":
				companion = hunter("drifter",focus+Vector2(78,0))
				cue = "Its glowing chambers slow nearby hunters."
			if scene=="moonlace": cue = "Its opening petals release food."
		"hunter","shellback","twinspore":
			subject = hunter(entry.kind,focus,entry.get("form",""))
			if scene=="hunter": companion = organism("food",focus+Vector2(10,0))
			cue = "Catch the hunter before it reaches Mother."
			if scene=="shellback": cue = "First loop: crack the shell. Second loop: capture."
			if scene=="twinspore": cue = "Both bright nuclei belong inside the same loop."
		"grazer","divider":
			subject = ecology(entry.kind,focus,entry.get("form",""))
			subject.speed = 2.0
			if scene=="grazer":
				companion = organism("food",focus+Vector2(10,0))
				cue = "A food thief. Capture it to recover its meal."
			else:
				# Start with an older specimen; the actual twenty-second split runs normally.
				subject.age = 16.0
				cue = "An older divider is about to split."
		"parasite":
			var site: Dictionary = run.harvest.ecology.arrival_site(run,{"kind":"parasite","area":0})
			subject = ecology("parasite",site.destination,entry.get("form",""))
			subject.target_node = site.target
			subject.site_nodes = site.nodes
			subject.action_clock = 4.0
			focus = subject.nucleus
			cue = "Follow the tether. Capture the parasite with other cells."
		"amoeba":
			subject = ecology("amoeba",focus)
			run.amoebas.choose_target(run,subject)
			subject.nucleus = subject.destination
			subject.search_after = subject.age+0.4
			focus = subject.nucleus.lerp(run.board.anchors[subject.target_node],0.3)
			cue = "One membrane reaches out to swallow a cell."
		"phage":
			subject = ecology("bacterium",Vector2(828,495))
			subject.speed = 0.0
			subject.heading = Vector2(1,0.18).normalized()
			subject.stored_food = 2
			companion = run.phages.add(run,Vector2(820,425))
			companion.age = 4.0
			focus = Vector2(824,478)
			zoom = 5.3
			cue = "Nudge the silver cluster toward the bacterium."
		"bellwether","regent","conjoined","warden":
			var variant := 0 if scene=="bellwether" else 2 if scene=="conjoined" else 1
			subject = run.JourneyHarvest.Predator.new(901,run.board,variant)
			if entry.kind=="bell_bud":
				subject.juvenile = true
				subject.kind = "bell_bud"
				subject.health = 1
				subject.nucleus = focus
			run.enemies.append(subject)
			if variant==1: run.harvest.ecology.spawn_gates(run,subject)
			if variant==0:
				organism("food",subject.nucleus+Vector2(100,10))
				organism("cyst",subject.nucleus+Vector2(-90,10))
			focus = subject.nucleus
			zoom = 3.8 if scene=="warden" else 3.4
			cue = "Gather food to charge a hit. Wait for its opening."
			if variant==1: cue = "Break the linked shields to expose the center."
			if variant==2: cue = "Wait for both hearts to come together."
	if scene=="warden":
		var guards: Array = run.enemies.filter(func(e): return e.kind=="warden")
		if not guards.is_empty(): focus = guards[0].nucleus
	camera_target = focus
	# Never create progress or new encounters from a filmed capture.
	run.harvest.spec.mode = "feed"
	if render_enabled: microscope.sync()
	update_camera()

func organism(kind: String, at: Vector2, form: String = "") -> RefCounted:
	run.next_enemy_id += 1
	var body = run.Harvest.Organism.new(run.next_enemy_id,kind,at,Vector2.ZERO,0.7)
	body.form = form
	body.age = 4.0
	run.enemies.append(body)
	return body

func hunter(kind: String, at: Vector2, form: String = "") -> RefCounted:
	run.next_enemy_id += 1
	var body = run.Drifter.new(run.next_enemy_id,at,2.0,kind)
	body.form = form
	body.age = 4.0
	run.enemies.append(body)
	return body

func ecology(kind: String, at: Vector2, form: String = "") -> RefCounted:
	var body = run.harvest.ecology.add(run,kind,0,at,form)
	body.age = 4.0
	if kind!="amoeba": body.spawning = 0.0
	return body

func pocket(nodes: Array) -> Vector2:
	var at := Vector2.ZERO
	for node in nodes: at += run.board.anchors[node]/float(nodes.size())
	return at

func once(key: String, after: float) -> bool:
	if elapsed<after or done_actions.has(key): return false
	done_actions[key] = true
	return true

func find_loop(points: PackedVector2Array, padding: float = 0.0) -> Array:
	var center := Vector2.ZERO
	for point in points: center += point/float(points.size())
	var closest: Array = range(run.cells.size()).filter(func(i): return run.is_ready(i))
	closest.sort_custom(func(a,b): return run.board.anchors[a].distance_squared_to(center)<run.board.anchors[b].distance_squared_to(center))
	closest = closest.slice(0,12)
	for size in [3,4]:
		for a in closest.size():
			for b in range(a+1,closest.size()):
				for c in range(b+1,closest.size()):
					for d in ([-1] if size==3 else range(c+1,closest.size())):
						var path: Array = [closest[a],closest[b],closest[c]]
						if d>=0: path.append(closest[d])
						path.sort_custom(func(i,j): return (run.board.anchors[i]-center).angle()<(run.board.anchors[j]-center).angle())
						if not Geometry.capture_valid(path,run.board,run.is_ready,8): continue
						var poly: PackedVector2Array = Geometry.polygon_for(path,run.board.anchors)
						if not Array(points).all(func(p): return Geometry.contains(p,poly)): continue
						var clear := true
						for point in points:
							for edge in poly.size():
								if Geometry2D.get_closest_point_to_segment(point,poly[edge],poly[(edge+1)%poly.size()]).distance_to(point)<padding: clear = false
						if clear: return path
	return []

func start_capture(points: PackedVector2Array, padding: float = 0.0) -> void:
	if not gesture.is_empty(): return
	gesture = find_loop(points,padding)
	if gesture.is_empty():
		events.append({"error":"No legal demonstration loop","scene":entry.scene})
		return
	gesture_time = 0.0
	pointer = run.board.anchors[gesture[0]]
	previous_pointer = pointer
	run.selection.start(pointer)
	pointer_visible = true

func step_gesture(delta: float) -> void:
	if gesture.is_empty(): return
	gesture_time += delta
	var edge_time := 0.65
	var segment := int(gesture_time/edge_time)
	if segment>=gesture.size():
		pointer = run.board.anchors[gesture[0]]
		run.selection.drag(previous_pointer,pointer)
		var result: Dictionary = run.release()
		events.append(result)
		gesture.clear()
		pointer_visible = false
		if result.get("cells_rescued",0)>0: cue = "Cell rescued. It returns to your colony."
		elif result.get("armor_hits",0)>0 and result.get("kills",0)==0: cue = "Shell cracked. Let the cells recover, then capture again."
		elif result.get("rescued",0)>0: cue = "Rescued. A new resident for your home pond."
		elif result.get("food",0)>0: cue = "Food recovered. Your colony grows stronger."
		elif result.get("boss_layers",0)>0: cue = "A protective layer dissolves."
		elif result.get("valid",false): cue = "Captured. The blue cells return to their places."
		return
	var from: Vector2 = run.board.anchors[gesture[segment]]
	var to: Vector2 = run.board.anchors[gesture[(segment+1)%gesture.size()]]
	pointer = from.lerp(to,smoothstep(0,1,fmod(gesture_time,edge_time)/edge_time))
	microscope.disturb_water(previous_pointer,pointer)
	run.selection.drag(previous_pointer,pointer)
	previous_pointer = pointer

func advance(delta: float) -> void:
	elapsed += delta
	visual_time += delta
	var scene: String = entry.scene
	match scene:
		"food","spore","twinspore":
			if once("capture",4.0): start_capture(subject.nuclei())
		"hunter","grazer":
			if subject.get("stored_food")!=null and subject.stored_food>0: milestones.ate = true
			if subject.carried_food>0: milestones.ate = true
			if once("capture",6.4): start_capture(subject.nuclei(),18.0 if scene=="grazer" else 0.0)
		"shellback":
			if once("crack",3.0): start_capture(subject.nuclei())
			if once("capture",9.0): start_capture(subject.nuclei())
		"cyst":
			if once("nudge",3.0):
				pointer = subject.nucleus
				if run.nudge.begin(run,pointer):
					var result: Dictionary = run.nudge.release(run,pointer+Vector2(-80,-40))
					events.append(result)
					milestones.nudged = not result.is_empty()
				cue = "The poison floats clear of the food."
		"amoeba":
			if subject.captive_node>=0:
				milestones.swallowed = true
				cue = "A blue cell is trapped. You have 15 seconds to save it."
			if once("rescue",8.0): start_capture(subject.nuclei())
		"parasite":
			if subject.latched: milestones.latched = true
			if once("capture",8.0): start_capture(subject.nuclei())
		"divider":
			if not run.enemies.has(subject):
				milestones.split = true
				cue = "One becomes two. Both young hunters can be captured."
			if once("capture",6.0):
				var points := PackedVector2Array()
				for body in run.enemies: points.append(body.nucleus)
				start_capture(points)
		"phage":
			if once("nudge",1.0):
				if run.nudge.begin(run,companion.nucleus): run.nudge.release(run,companion.nucleus+(subject.nucleus-companion.nucleus).normalized()*60)
			if subject.infection_age>=0.0:
				milestones.infected = true
				cue = "Attached. The bacterium will rupture after 9 seconds."
			if run.phages.burst_serial>0:
				milestones.ruptured = true
				cue = "The stolen food is released. Loop around it to collect it."
		"bellwether":
			if subject.can_take_pulse(): milestones.opened = true
			if once("capture",9.0): start_capture(subject.nuclei())
		"regent","warden":
			if once("first_shield",2.0) or once("second_shield",8.0):
				var guards: Array = run.enemies.filter(func(e): return e.kind=="warden")
				if not guards.is_empty():
					camera_target = guards[0].nucleus
					start_capture(guards[0].nuclei())
			if subject.can_take_pulse():
				milestones.opened = true
				cue = "Shields removed. The golden center is open."
			if scene=="regent" and once("capture",14.0):
				camera_target = subject.nucleus
				start_capture(subject.nuclei())
		"conjoined":
			if once("capture",7.0): start_capture(subject.nuclei())
		"moonlace":
			if subject.bloom_releases>0: milestones.bloomed = true
		"glowdrift":
			if companion.slowed>0: milestones.sheltered = true
	step_gesture(delta)
	run.step(delta)
	if render_enabled: microscope.sync()
	update_camera()
	queue_redraw()

func update_camera() -> void:
	focus = camera_target if reduced_motion else focus.lerp(camera_target,0.035)
	var camera_zoom := zoom
	if not reduced_motion: camera_zoom *= 1.0+0.04*smoothstep(0,duration,elapsed)
	get_viewport().canvas_transform = Transform2D(0,Vector2.ONE*camera_zoom,0,Vector2(960,510)-focus*camera_zoom)

func _draw() -> void:
	if run.selection.active:
		var points: PackedVector2Array = Geometry.polygon_for(run.selection.path,run.board.anchors)
		if points.size()>1: draw_polyline(points,Color(0.75,0.96,0.91,0.9),1.0,true)
		if points.size()>2 and run.selection.closed: draw_line(points[-1],points[0],Color(0.75,0.96,0.91,0.9),1.0,true)
	if pointer_visible:
		draw_arc(pointer,4,0,TAU,32,Color(0.88,1,0.96),0.8,true)
