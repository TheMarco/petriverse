extends "res://tests/harvest_visual.gd"
const Save = preload("res://scripts/journey_save.gd")
const Geometry = preload("res://scripts/loop_geometry.gd")
var cyst: RefCounted
var food: RefCounted
var away := Vector2.ZERO

func capture(name: String) -> void:
	game.set_process_unhandled_input(false)
	await super.capture(name)
	game.set_process_unhandled_input(true)

func prepare() -> void:
	var run = game.run
	run.stage_index = 1
	run.start_stage()
	run.begin_encounter()
	run.enemies.clear()
	run.integrity = 5
	run.biomass = 0
	run.nudge.learned = false
	run.harvest.next_bloom = 999.0
	run.harvest.next_spore = 999.0
	run.harvest.ecology.next_wave = 999.0
	var p: PackedVector2Array = Geometry.polygon_for([0,8,9],run.board.anchors)
	var center: Vector2 = (p[0]+p[1]+p[2])/3.0
	food = run.Harvest.Organism.new(9001,"food",center+Vector2(8,0),Vector2.ZERO,0.0)
	var second = run.Harvest.Organism.new(9002,"food",center-Vector2(8,0),Vector2.ZERO,1.0)
	cyst = run.Harvest.Organism.new(9003,"cyst",center,Vector2.ZERO,2.0)
	for body in [food,second,cyst]:
		body.age = 5.0
		run.enemies.append(body)
	var distance := INF
	for i in 3:
		var edge: Vector2 = p[(i+1)%3]-p[i]
		var closest: Vector2 = p[i]+edge*clampf((center-p[i]).dot(edge)/edge.length_squared(),0.0,1.0)
		if closest.distance_to(center)<distance:
			distance = closest.distance_to(center)
			away = (closest-center).normalized()
	game.toast_time = 0.0
	game.last_discovery = run.discovery_serial
	game._process(0.0)

func select_meal() -> void:
	var run = game.run
	run.selection.start(run.board.anchors[0])
	for id in [8,9,0]:
		run.selection.visit(id)

func right_click(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = at
	root.push_input(event,true)

func exercise() -> void:
	root.size = Vector2i(1280,900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	RenderingServer.render_loop_enabled = false
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-nudge-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-nudge-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.run.fixed_seed = 73
	game.run.restart()
	prepare()
	var run = game.run
	select_meal()
	expect(run.harvest_preview().food==2 and run.harvest_preview().poison==1,"The representative meal starts contaminated")
	run.selection.cancel()
	expect(run.nudge.teaching_target(run)==cyst,"The first mixed pocket teaches Nudge beside the actual cyst")
	await capture("nudge-teaching")
	var start: Vector2 = cyst.nucleus
	var destination := start+away*120.0
	mouse(start,true)
	drag(start,destination)
	expect(run.nudge.target_id==cyst.id and not run.selection.active,"A real cyst drag aims a nudge without drawing a membrane")
	expect(is_equal_approx(run.nudge.displacement(run).length(),60.0),"The visible arrow caps the push at sixty pixels")
	expect(cyst.nucleus==start and run.nudge.cooldown==0.0,"Aiming spends nothing and does not teleport the cyst")
	game.large_text = true
	await capture("nudge-aim-large")
	game.large_text = false
	mouse(destination,false)
	expect(run.nudge.cooldown==6.0 and run.nudge.learned and run.nudge.target_id<0,"Release begins one push and the shared cooldown")
	expect(run.integrity==5 and run.biomass==0 and run.cells.all(func(c): return c.is_ready()),"Nudge costs no health, food, or drawing cells")
	expect(food.nucleus==food.origin and cyst.nucleus==start,"Release only starts the physical push; food is untouched")
	expect(not run.nudge.begin(run,start),"Another nudge cannot bypass the cooldown")
	run.step(0.25)
	game._process(0.25)
	expect(cyst.nucleus.distance_to(start)>10.0 and cyst.nucleus.distance_to(start)<60.0,"The cyst visibly coasts partway before settling")
	var impulses: PackedVector4Array = game.microscope.field.material.get_shader_parameter("impulses")
	expect(impulses[0].w>0.0 and absf(cyst.nudge_roll())>0.1,"The push supplies a visible water ripple and a gentle tumble")
	await capture("nudge-ripple")
	var before_pause: Vector2 = cyst.nucleus
	var remaining: float = run.nudge.cooldown
	game.pause()
	run.step(3.0)
	game._process(3.0)
	expect(cyst.nucleus==before_pause and run.nudge.cooldown==remaining,"Pause freezes the push and cooldown")
	game.pause()
	var save_path := "/tmp/microverse-nudge-roundtrip.cfg"
	expect(Save.write(run,save_path)==OK,"An in-flight nudge writes through the real save format")
	var data: Dictionary = Save.read(save_path)
	var restored := Run.new(true,73,true,true)
	expect(Save.restore(restored,data.snapshot),"The in-flight push restores")
	expect(restored.nudge.cooldown==run.nudge.cooldown and restored.nudge.learned,"Cooldown and learned controls survive resume")
	var resumed = restored.enemies.filter(func(e): return e.id==cyst.id)[0]
	for i in 60:
		run.step(1.0/60.0)
		restored.step(1.0/60.0)
	expect(resumed.nucleus.distance_to(cyst.nucleus)<0.0001 and is_equal_approx(restored.nudge.cooldown,run.nudge.cooldown),"Save/resume follows the same continuous trajectory")
	# Shared currents continue carrying the cyst during its 1.25-second push.
	# It must still settle within 1.5 pixels of the intended new location.
	expect(cyst.nucleus.distance_to(start+away*60.0)<=1.501,"The cyst settles at its new location within the gentle current allowance")
	var legacy: Dictionary = data.snapshot.duplicate(true)
	legacy.erase("nudge")
	for body in legacy.enemies:
		if body.has("organism"):
			body.organism.erase("nudge_vector")
			body.organism.erase("nudge_elapsed")
	expect(Save.restore(restored,legacy) and restored.nudge.cooldown==0.0 and not restored.nudge.learned,"Older saves receive Nudge ready without losing the encounter")
	restored.dispose()
	var pointer: Vector2 = run.board.anchors[0]
	mouse(pointer,true)
	for id in [8,9,0]:
		var origin := pointer
		for frame in 30:
			run.step(1.0/60.0)
			var next: Vector2 = origin.lerp(run.board.anchors[id],float(frame+1)/30.0)
			drag(pointer,next)
			pointer = next
	var meal: Dictionary = run.harvest_preview()
	expect(run.selection.closed and meal.food==2 and meal.poison==0,"At two segments/s the cleared pocket now contains food without poison: %s" % meal)
	await capture("nudge-clean-meal")
	mouse(pointer,false)
	expect(run.integrity==5 and run.harvest.nourishment==2 and run.enemies.has(cyst),"The clean meal feeds Mother while the cyst remains a hazard")
	prepare()
	mouse(cyst.nucleus,true)
	drag(cyst.nucleus,cyst.nucleus+away*40.0)
	right_click(cyst.nucleus)
	expect(run.nudge.target_id<0 and run.nudge.cooldown==0.0,"Right-click cancels a nudge for free")
	mouse(cyst.nucleus,true)
	key(KEY_ESCAPE)
	expect(run.nudge.target_id<0 and run.nudge.cooldown==0.0,"Escape cancels for free")
	mouse(cyst.nucleus,true)
	mouse(cyst.nucleus+Vector2.ONE,false)
	expect(run.nudge.target_id<0 and run.nudge.cooldown==0.0,"An accidental click or tiny drag spends nothing")
	mouse(cyst.nucleus,true)
	game.pause()
	expect(run.nudge.target_id<0,"Pausing cancels an uncommitted drag")
	game.pause()
	game.click_mode = true
	mouse(cyst.nucleus,true)
	mouse(cyst.nucleus,false)
	expect(run.nudge.target_id==cyst.id,"Click controls select a cyst without holding the mouse")
	mouse(cyst.nucleus+away*60.0,true)
	mouse(cyst.nucleus+away*60.0,false)
	expect(run.nudge.cooldown==6.0 and not run.selection.active,"A second click pushes without starting a loop")
	run.step(5.9)
	expect(run.nudge.cooldown>0.09 and run.nudge.cooldown<0.11,"The shared cooldown lasts six simulation seconds")
	run.step(0.11)
	expect(run.nudge.cooldown==0.0,"Nudge becomes ready again when the cooldown ends")
	prepare()
	game.click_mode = false
	cyst.nucleus = run.board.anchors[0]
	cyst.origin = cyst.nucleus
	mouse(cyst.nucleus,true)
	expect(run.selection.active and run.nudge.target_id<0,"A blue cell retains priority when a cyst overlaps it")
	run.selection.cancel()
	run.cells[0].spend(2.0)
	mouse(cyst.nucleus,true)
	expect(run.nudge.target_id==cyst.id,"An unavailable digesting cell does not block a visible cyst")
	run.nudge.cancel()
	cyst.nucleus = run.board.center+Vector2(365,0)
	cyst.origin = cyst.nucleus
	if run.nudge.begin(run,cyst.nucleus):
		run.nudge.point(cyst.nucleus+Vector2(100,0))
		var endpoint: Vector2 = cyst.nucleus+run.nudge.displacement(run)
		expect(endpoint.distance_to(run.board.center)<=run.board.dish_radius-24.0,"The preview cannot eject cysts through the dish wall")
	else:
		expect(false,"The rim fixture is reachable")
	run.nudge.cancel()
	prepare()
	game.reduced_motion = true
	var reduced_start: Vector2 = cyst.nucleus
	mouse(cyst.nucleus,true)
	mouse(cyst.nucleus+away*60.0,false)
	run.step(0.4)
	game._process(0.4)
	expect(cyst.nucleus.distance_to(reduced_start)>10.0 and run.nudge.cooldown>5.0 and run.nudge.cooldown<6.0,"Reduced motion retains the actual displacement and cooldown")
	expect(game.microscope.water.wakes.is_empty(),"Reduced motion omits the decorative water wake")
	var drifting = run.Harvest.Organism.new(9500,"cyst",Vector2(650,550),Vector2(7,3),1.0)
	var control = run.Harvest.Organism.new(9500,"cyst",Vector2(650,550),Vector2(7,3),1.0)
	drifting.start_nudge(Vector2(60,0))
	for frame in 240:
		drifting.step(1.0/60.0,run.board.center)
		control.step(1.0/60.0,run.board.center)
	expect((drifting.nucleus-control.nucleus).distance_to(Vector2(60,0))<0.001,"Normal drifting resumes around the shifted origin without springing back")
	prepare()
	mouse(cyst.nucleus,true)
	game.toggle_mode()
	expect(run.nudge.target_id<0 and run.nudge.cooldown==0.0,"Changing input mode cancels the pending gesture")
	game.click_mode = false
	mouse(cyst.nucleus,true)
	var pending: Dictionary = Save.capture(run)
	var clone := Run.new(true,73,true,true)
	expect(Save.restore(clone,pending) and clone.nudge.target_id<0 and clone.nudge.cooldown==0.0,"Saving while aiming never commits or restores a held gesture")
	clone.dispose()
	run.enemies.erase(cyst)
	mouse(cyst.nucleus+away*60.0,false)
	expect(run.nudge.cooldown==0.0 and run.nudge.target_id<0,"A disappearing target cancels without spending the ability")
	game.large_text = true
	game.toggle_help()
	await capture("nudge-help-large")
	game.queue_free()
	await process_frame
	print("CYST NUDGE: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
