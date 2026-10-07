extends SceneTree
## Film actual simulation and input at 30 fps, independently of wall-clock speed.
## All saves and profiles are isolated in /tmp. No shipping game rules change.
const Main = preload("res://scripts/main.gd")
const Drifter = preload("res://scripts/drifter.gd")
const Expedition = preload("res://scripts/expedition_creatures.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
const FPS := 30
const LENGTHS := {"hook":5,"reveal":4,"loop":10,"fluid":6,"amoeba":12,"phages":12,"evolve":7,"world_a":3,"world_b":3,"world_c":3,"rare_a":3,"rare_b":3,"boss_a":3,"boss_b":3,"boss_c":3,"home":4,"end":6}
var game
var shot := "hook"
var duration := 8.0
var focus := Vector2(640,450)
var zoom := 3.5
var pointer := Vector2.ZERO
var pointer_visible := false
var pointer_down := false
var subject
var cyst
var away := Vector2.ZERO
var gesture_origin := Vector2.ZERO
var gesture_previous := Vector2.ZERO
var gesture_segment := -1
var released := false
var events: Array = []
var failures: Array = []
var overlay
var sample_only := false
var cluster
var rescue_path: Array = []
var rescued_node := -1
var witnessed_swallow := false
var witnessed_infection := false
var witnessed_rupture := false

class Titles extends Node2D:
	var film
	var time := 0.0
	var font := SystemFont.new()
	var small := SystemFont.new()
	var logo = preload("res://assets/branding/petriverse-title-v2.png")
	func _init() -> void:
		font.font_names = PackedStringArray(["Inter","Avenir Next","Helvetica Neue"])
		font.font_weight = 500
		small.font_names = PackedStringArray(["Avenir Next","Helvetica Neue"])
		small.font_weight = 400
	func line(text: String, at: Vector2, size: int, color: Color, centered: bool = true) -> void:
		var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		draw_string(font,at-Vector2(width*0.5 if centered else 0,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
	func tracked(text: String, at: Vector2, size: int, space: float, color: Color) -> void:
		var width := float(text.length()-1)*space
		for character in text: width += font.get_string_size(character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var x := at.x-width*0.5
		for character in text:
			draw_string(font,Vector2(x,at.y),character,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
			x += font.get_string_size(character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x+space
	func caption(kicker: String, title: String, detail: String = "") -> void:
		var alpha := smoothstep(0.25,1.0,time)*(1.0-smoothstep(film.duration-0.5,film.duration,time))
		var ink := Color(0.88,0.96,0.94,alpha)
		# A restrained lower scrim keeps every instruction readable over gameplay.
		for i in 280:
			var a := pow(float(i)/280.0,1.8)*0.58*alpha
			draw_rect(Rect2(0,800+i,1920,1),Color(0.01,0.04,0.045,a))
		tracked(kicker,Vector2(960,889),19,4.0,Color(0.66,0.84,0.8,alpha))
		line(title,Vector2(960,948),42,ink)
		if not detail.is_empty(): line(detail,Vector2(960,992),24,Color(0.73,0.83,0.83,alpha))
	func _draw() -> void:
		var alpha := smoothstep(0.3,1.8,time)
		match film.shot:
			"hook":
				tracked("BENEATH THE SURFACE",Vector2(960,114),21,6,Color(0.78,0.9,0.88,alpha))
			"reveal":
				draw_rect(Rect2(0,0,1920,1080),Color(0.01,0.03,0.04,0.42))
				draw_texture_rect(logo,Rect2(440,100,1040,693),false,Color(1,1,1,alpha))
				tracked("A SMALL LIFE. A WHOLE WORLD.",Vector2(960,858),24,4.0,Color(0.82,0.94,0.91,alpha))
				line("A living strategy game in a drop of water.",Vector2(960,926),30,Color(0.83,0.89,0.89,alpha))
			"loop":
				if time<3.5: caption("HOW TO PLAY", "Drag through three or more blue cells.")
				elif time<6.4: caption("CLOSE YOUR LOOP", "Enclose the green food.","Keep Mother outside.")
				else: caption("RELEASE TO ABSORB", "Feed Mother. Let your cells recover.")
			"fluid": caption("EVERY MOVEMENT LEAVES A WAKE", "Nudge poison. Stir the living water.")
			"amoeba":
				if time<4.7: caption("SOMETHING IS HUNGRY", "An amoeba can swallow your cells.")
				elif time<9.0: caption("15 SECONDS TO SAVE A LIFE", "Loop around its golden nucleus.")
				else: caption("BRING YOUR CELL HOME", "Rescue it before it is digested.")
			"phages":
				if time<2.5: caption("TINY ALLIES", "Nudge phages toward a bacterium.")
				elif time<9.8: caption("NATURE HAS ITS OWN WEAPONS", "Watch them attach, infect and multiply.")
				else: caption("A BURST OF NEW LIFE", "Recover the food it stole.")
			"danger": caption("YOU ARE NOT ALONE", "Hunters are closing in.")
			"defend": caption("PROTECT YOUR COLONY", "Catch the hunter. Save a life.")
			"evolve": caption("TURN FOOD INTO EVOLUTION", "Grow a colony that plays your way.")
			"world_a": caption("THREE LIVING WATERS", "Stillwater")
			"world_b": caption("THREE LIVING WATERS", "Glassgarden")
			"world_c": caption("THREE LIVING WATERS", "Blue Deep")
			"rare_a": caption("KEEP DISCOVERING", "Rare life. New encounters.")
			"rare_b": caption("KEEP DISCOVERING", "Every journey holds a surprise.")
			"boss_a": caption("LEARN THEIR RHYTHM", "The Bellwether")
			"boss_b": caption("BREAK THEIR DEFENSES", "The Glass Regent")
			"boss_c": caption("FIND YOUR MOMENT", "The Conjoined")
			"home": caption("EVERY RESCUE LEAVES A LEGACY", "Bring new life to your home pond.")
			"end":
				draw_rect(Rect2(0,0,1920,1080),Color(0.005,0.02,0.03,0.60))
				draw_texture_rect(logo,Rect2(440,70,1040,693),false,Color(1,1,1,alpha))
				tracked("FEED.  PROTECT.  EVOLVE.",Vector2(960,828),28,4.5,Color(0.81,0.95,0.90,alpha))
				line("One more journey into the unknown.",Vector2(960,911),30,Color(0.84,0.91,0.89,alpha))
				tracked("MAC  /  WINDOWS  /  LINUX",Vector2(960,994),19,3.0,Color(0.63,0.80,0.77,alpha))
		if film.pointer_visible:
			var at: Vector2 = film.root.canvas_transform*film.pointer
			draw_circle(at,17,Color(0.65,1.0,0.92,0.09))
			draw_arc(at,11 if film.pointer_down else 15,0,TAU,48,Color(0.89,1,0.97,0.9),2,true)
			draw_circle(at,3,Color(0.96,1,0.99,0.95))
		# Gentle entrance and final fade, no strobing transitions.
		if film.shot=="hook": draw_rect(Rect2(0,0,1920,1080),Color(0,0,0,1-smoothstep(0.0,1.2,time)))
		if film.shot=="end": draw_rect(Rect2(0,0,1920,1080),Color(0,0,0,smoothstep(film.duration-1.2,film.duration,time)))

func _initialize() -> void:
	root.unfocusable = true
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty(): shot = arguments[0]
	sample_only = arguments.has("sample")
	duration = float(LENGTHS.get(shot,8))
	call_deferred("render")

func prepare(stage: int, keep_enemies: bool = false) -> void:
	game.run.fixed_seed = 73
	game.run.long_journey = false
	game.run.restart()
	game.run.stage_index = stage
	game.run.start_stage()
	game.run.begin_encounter()
	game.run.harvest.next_bloom = 9999.0
	game.run.harvest.next_spore = 9999.0
	game.run.harvest.ecology.next_wave = 9999.0
	game.run.harvest.ecology.pending.clear()
	game.run.harvest.visitor_at = -1.0
	game.run.harvest.spec.duration = 999.0
	game.run.harvest.spec.target = 999
	game.run.integrity = 5
	if not keep_enemies: game.run.enemies.clear()
	game.reset_presentation()
	game.last_discovery = game.run.discovery_serial
	game.toast_time = 0.0

func food(at: Vector2, kind: String = "food", form: String = "", phase: float = 0.0):
	game.run.next_enemy_id += 1
	var body = game.run.Harvest.Organism.new(game.run.next_enemy_id,kind,at,Vector2.ZERO,phase)
	body.form = form
	body.age = 4.0
	game.run.enemies.append(body)
	return body

func pocket(path: Array) -> Vector2:
	var result := Vector2.ZERO
	for id in path: result += game.run.board.anchors[id]
	return result/path.size()

func setup() -> void:
	match shot:
		"hook","reveal":
			prepare(1)
			food(Vector2(770,300),"food","fern_desmid")
			food(Vector2(470,570),"spore","snow_spore")
			focus = Vector2(640,440)
		"loop","fluid":
			prepare(1)
			focus = pocket([0,8,9])
			food(focus+Vector2(8,0))
			food(focus-Vector2(8,0),"food","",1.0)
			if shot=="fluid":
				cyst = food(focus,"cyst","",2.0)
				var polygon: PackedVector2Array = Geometry.polygon_for([0,8,9],game.run.board.anchors)
				var nearest := INF
				for i in 3:
					var edge: Vector2 = polygon[(i+1)%3]-polygon[i]
					var point: Vector2 = polygon[i]+edge*clampf((focus-polygon[i]).dot(edge)/edge.length_squared(),0,1)
					if point.distance_to(focus)<nearest:
						nearest = point.distance_to(focus)
						away = (point-focus).normalized()
		"amoeba":
			prepare(5)
			subject = game.run.harvest.ecology.add(game.run,"amoeba",0,game.run.harvest.ecology.pocket(game.run,0))
			subject.age = 4.0
			game.run.amoebas.choose_target(game.run,subject)
			subject.nucleus = subject.destination
			subject.search_after = subject.age+0.4
			rescue_path = subject.site_nodes.duplicate()
			rescued_node = subject.target_node
			if rescue_path.size()!=3: failures.append("Amoeba has no genuine rescue triangle")
			focus = subject.nucleus.lerp(game.run.board.anchors[rescued_node],0.3)
		"phages":
			prepare(2)
			game.run.phages.reset()
			subject = game.run.harvest.ecology.add(game.run,"bacterium",0,Vector2(828,495))
			subject.age = 4.0
			subject.spawning = 0.0
			subject.speed = 0.0
			subject.heading = Vector2(1,0.18).normalized()
			subject.stored_food = 2
			cluster = game.run.phages.add(game.run,Vector2(820,425))
			cluster.age = 4.0
			focus = Vector2(824,478)
		"danger":
			prepare(5)
			focus = game.run.board.center
			var origin: Vector2 = focus+Vector2.from_angle(-0.55)*74.0
			subject = Drifter.new(901,origin,8.0)
			subject.form = "trident_hunter"
			subject.age = 4.0
			game.run.enemies.append(subject)
			food(focus+Vector2(150,90),"cyst","thistle_capsule")
		"defend":
			prepare(2)
			focus = pocket([8,16,17])
			food(focus,"spore","glasswing_spore")
			subject = Drifter.new(902,focus+Vector2(14,0),5.4)
			subject.age = 3.0
			game.run.enemies.append(subject)
		"evolve":
			prepare(5)
			focus = game.run.board.center+Vector2(0,-22)
			game.run.mutations = ["elastic","enzyme","filter"]
		"world_a","world_b","world_c":
			var stage: int = {"world_a":2,"world_b":6,"world_c":10}[shot]
			prepare(stage,true)
			game.run.mutations = ["elastic","enzyme","filter","nursery"]
			for entry in Expedition.ENTRIES:
				if int(entry.first_stage)/4==stage/4 and entry.kind in ["food","grazer","spore"]:
					var body = Expedition.spawn(game.run,entry)
					body.age = 4.0
					game.run.harvest.rotation += 2
			focus = Vector2(640,435)
		"rare_a","rare_b":
			prepare(6 if shot=="rare_a" else 10)
			var form: String = "amber_nautilus" if shot=="rare_a" else "comet_spore"
			for entry in Expedition.ENTRIES:
				if entry.id==form:
					subject = Expedition.spawn(game.run,entry)
					subject.age = 4.0
			focus = subject.nucleus
		"boss_a","boss_b","boss_c":
			var stage: int = {"boss_a":3,"boss_b":7,"boss_c":11}[shot]
			prepare(stage,true)
			subject = game.run.boss()
			game.run.enemies = game.run.enemies.filter(func(e): return e.is_boss() or e.kind=="warden")
			game.run.harvest.nourishment = 6
			for i in (180 if shot=="boss_a" else 90): game.run.step(1.0/FPS)
			focus = subject.nucleus
		"home","end":
			prepare(2)
			game.run.mutations = ["elastic","enzyme","feast","nursery","filter"]
			# Populate the habitat using real captures, as in home_pond_visual.gd.
			for batch in 4:
				game.run.enemies.clear()
				for i in 3:
					var form: String = ["snow_spore","sail_spore","glasswing_spore","comet_spore"][(batch+i)%4]
					food(pocket([0,8,9])+Vector2((i-1)*13,0),"spore",form)
				game.run.selection.start(game.run.board.anchors[0])
				for id in [8,9,0]: game.run.selection.visit(id)
				var outcome: Dictionary = game.run.release()
				if outcome.get("rescued",0)!=3: failures.append("Home habitat rescue batch failed")
				game.run.step_recovery(8.0)
			game.journey_profile.observe(game.run)
			game.return_home()
			focus = Vector2(640,450)
	game.last_discovery = game.run.discovery_serial
	game._process(0.0)

func drag_loop(time: float, start: float, path: Array, seconds_per_edge: float, hold: float = 0.4) -> void:
	var total: float = path.size()*seconds_per_edge
	pointer_visible = time>=start-0.6 and time<start+total+hold+0.35
	if time<start:
		pointer = game.run.board.anchors[path[0]]
		return
	if gesture_segment<0:
		pointer_down = true
		pointer = game.run.board.anchors[path[0]]
		game.run.selection.start(pointer)
		gesture_previous = pointer
		gesture_origin = pointer
		gesture_segment = 0
		events.append({"time":time,"sound":"connect"})
	var local: float = time-start
	if local<total:
		var segment: int = mini(path.size()-1,int(local/seconds_per_edge))
		if segment!=gesture_segment:
			gesture_segment = segment
			gesture_origin = gesture_previous
			events.append({"time":time,"sound":"connect"})
		var target: Vector2 = game.run.board.anchors[path[(segment+1)%path.size()]]
		var p: float = clampf(fmod(local,seconds_per_edge)/seconds_per_edge,0,1)
		pointer = gesture_origin.lerp(target,smoothstep(0,1,p))
		game.microscope.disturb_water(gesture_previous,pointer)
		game.run.selection.drag(gesture_previous,pointer)
		gesture_previous = pointer
	elif not released:
		pointer = game.run.board.anchors[path[0]]
		game.run.selection.drag(gesture_previous,pointer)
		gesture_previous = pointer
		if local>=total+hold:
			var outcome: Dictionary = game.run.release()
			events.append({"time":time,"sound":"close","capture":outcome})
			events.append({"time":time+0.7,"sound":"absorb"})
			if not outcome.get("valid",false): failures.append("Invalid actual gesture: "+shot)
			if shot=="loop" and (outcome.get("food",0)!=2 or outcome.get("poison",0)!=0): failures.append("Feeding shot did not produce a clean two-food meal")
			if shot=="defend" and (outcome.get("rescued",0)!=1 or outcome.get("threats",0)<1): failures.append("Defence shot did not rescue prey and catch hunter")
			if shot=="amoeba" and game.run.cells[rescued_node].captor>=0: failures.append("Amoeba capture did not rescue the swallowed cell")
			released = true
			pointer_down = false
	game.last_pointer = pointer

func animate(time: float, frame: int) -> void:
	var fraction: float = time/duration
	match shot:
		"hook": zoom = lerpf(4.6,3.5,smoothstep(0,1,fraction))
		"reveal": zoom = lerpf(2.1,1.6,smoothstep(0,1,fraction))
		"loop":
			zoom = 3.6
			drag_loop(time,1.5,[0,8,9],1.2,1.15)
		"fluid":
			zoom = 4.6
			if frame==30:
				pointer = cyst.nucleus
				game.run.nudge.begin(game.run,pointer)
				pointer_down = true
			if time>=1.0 and time<1.9:
				pointer_visible = true
				pointer = cyst.nucleus+away*80.0*smoothstep(1,1.9,time)
				game.run.nudge.point(pointer)
			if frame==57:
				game.commit_nudge(pointer)
				pointer_down = false
				events.append({"time":time,"sound":"close"})
			if time>=2.1: pointer_visible = false
			if time>=3.0:
				var current: Vector2 = focus+Vector2(cos(time*1.1)*90,sin(time*1.1)*55)
				game.microscope.disturb_water(pointer,current)
				pointer = current
				pointer_visible = time<5.0
		"amoeba":
			zoom = 4.0
			if subject.captive_node>=0: witnessed_swallow = true
			if time>=4.5: drag_loop(time,5.0,rescue_path,1.0,0.45)
		"phages":
			zoom = lerpf(5.3,5.8,fraction)
			if frame==9:
				pointer = cluster.nucleus
				if not game.run.nudge.begin(game.run,pointer): failures.append("Phages could not be nudged")
				gesture_origin = pointer
				pointer_down = true
			if time>=0.3 and time<=0.8:
				pointer_visible = true
				pointer = gesture_origin+(subject.nucleus-gesture_origin).normalized()*60.0*smoothstep(0.3,0.8,time)
				game.run.nudge.point(pointer)
			if frame==24:
				game.commit_nudge(pointer)
				pointer_down = false
				events.append({"time":time,"sound":"close"})
			if time>1.2: pointer_visible = false
			if subject.infection_age>=0.0: witnessed_infection = true
			if game.run.phages.burst_serial>0 and not witnessed_rupture:
				witnessed_rupture = true
				events.append({"time":time,"sound":"fracture"})
		"danger":
			zoom = lerpf(3.6,4.9,smoothstep(0,1,fraction))
			if game.run.integrity<5 and events.is_empty(): events.append({"time":time,"sound":"injury"})
		"defend":
			zoom = 4.0
			drag_loop(time,1.15,[8,16,17],0.5,0.2)
		"evolve":
			zoom = lerpf(3.6,2.9,smoothstep(0,1,fraction))
			if frame==24:
				game.run.add_mutation("nursery")
				game.microscope.start_growth("nursery")
				events.append({"time":time,"sound":"evolve"})
			if frame==138:
				game.run.add_mutation("feast")
				game.microscope.start_growth("feast")
				events.append({"time":time,"sound":"evolve"})
		"world_a","world_b","world_c": zoom = lerpf(1.72,1.86,fraction)
		"rare_a","rare_b":
			zoom = lerpf(5.4,5.9,fraction)
			focus = focus.lerp(subject.nucleus,0.05)
		"boss_a","boss_b","boss_c":
			zoom = lerpf(3.4,3.8,fraction)
			focus = focus.lerp(subject.nucleus,0.06)
		"home","end": zoom = lerpf(1.7,1.5,fraction)
	var offset := Vector2(960,470)-focus*zoom
	root.canvas_transform = Transform2D(0.0,Vector2.ONE*zoom,0.0,offset)
	overlay.time = time
	overlay.queue_redraw()

func render() -> void:
	var output := "/tmp/petriverse-trailer-frames/"+shot
	DirAccess.make_dir_recursive_absolute(output)
	root.gui_disable_input = true
	root.size = Vector2i(1920,1080)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.render_loop_enabled = false
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/petriverse-trailer-unused.cfg"
	game.journey_profile.path = "/tmp/petriverse-trailer-profile-"+shot+".cfg"
	root.add_child(game)
	game.journey_profile.residents.clear()
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	setup()
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	overlay = Titles.new()
	overlay.film = self
	layer.add_child(overlay)
	for frame in int(duration*FPS):
		var time := float(frame)/FPS
		animate(time,frame)
		game.run.step(1.0/FPS)
		game._process(1.0/FPS)
		game.hud.hide()
		game.hovered = -1
		game.toast_time = 0
		await process_frame
		RenderingServer.force_draw(false)
		if not sample_only or frame in [45,int(duration*FPS/2),int(duration*FPS)-30]:
			var picture := root.get_texture().get_image()
			if picture.save_jpg(output+"/frame-%04d.jpg" % frame,0.98)!=OK:
				failures.append("Could not write captured frame")
				break
		if frame%60==0: print("TRAILER ",shot," ",frame,"/",int(duration*FPS))
	if shot=="amoeba":
		if not witnessed_swallow: failures.append("Amoeba never swallowed a cell")
		if not released or not game.run.cells[rescued_node].is_ready(): failures.append("Rescued cell did not recover")
	if shot=="phages":
		if not witnessed_infection or not witnessed_rupture: failures.append("Phage infection lifecycle did not complete")
		if game.run.enemies.filter(func(e): return e.kind=="food" and e.story=="phage_salvage").size()!=2: failures.append("Phage rupture did not release two stolen food")
	var report := {"shot":shot,"duration":duration,"frames":int(duration*FPS),"events":events,"failures":failures,"integrity":game.run.integrity,"nourishment":game.run.harvest.nourishment,"source":"Native Godot simulation, camera and title overlays only; staged isolated encounters"}
	var file := FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("TRAILER COMPLETE ",shot," ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
