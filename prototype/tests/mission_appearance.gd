extends "res://tests/harvest_visual.gd"
const Appearance = preload("res://scripts/mission_appearance.gd")
const Save = preload("res://scripts/journey_save.gd")

func exercise() -> void:
	var first := Appearance.make(73,5)
	expect(first==Appearance.make(73,5),"Same journey and mission give exactly the same appearance")
	expect(first!=Appearance.make(74,5) and first!=Appearance.make(73,6),"New journeys and new missions produce different recipes")
	var keys: Array = []
	for stage in 12:
		var look := Appearance.make(73,stage)
		keys.append(look.key)
		expect(look.life_count>=40 and look.life_count<=46 and look.dust_count<=264 and look.cells.size()==24,"Full-detail appearance fills the dish with small life within the bounded 46-specimen budget")
		expect(look.colony_grade.z>=look.colony_grade.x and look.colony_grade.y>=look.colony_grade.x,"Controllable cells retain a cool blue/cyan identity")
	expect(keys.size()==12 and keys.count(first.key)==1,"Each mission has its own stable visual identity")
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-appearance-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-appearance-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	root.content_scale_size = Vector2i(1280,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280,900)
	RenderingServer.render_loop_enabled = false
	var run = game.run
	run.run_seed = 73
	for stage in [1,2,5,6,9,10]:
		run.stage_index = stage
		run.start_stage()
		run.begin_encounter()
		run.step(5.0)
		game.visual_time = run.elapsed
		game.last_discovery = run.discovery_serial
		game.toast_time = 0.0
		var rng_before: int = run.rng.state
		var geometry: PackedVector2Array = run.board.anchors.duplicate()
		await capture("mission-appearance-%02d" % (stage+1))
		var view = game.microscope
		expect(run.rng.state==rng_before and run.board.anchors==geometry,"Procedural presentation does not change simulation or its random stream")
		expect(view.appearance==Appearance.make(73,stage),"Renderer uses this mission's appearance")
		expect(view.pond.specimens.size()==view.appearance.life_count and view.pond.suspension.multimesh.instance_count==view.appearance.dust_count,"Background population uses seeded variety")
		expect(view.cells[0].material.get_shader_parameter("phenotype")==view.appearance.cells[0],"Player membrane shape reaches the native shader")
		var roles_unchanged := true
		for body in view.enemies.values():
			for lobe in body.get_meta("lobes"):
				var grade = lobe.material.get_shader_parameter("colony_grade")
				# Unset overrides return null; the shader's default is neutral.
				roles_unchanged = roles_unchanged and (grade==null or grade==Vector3.ONE) and lobe.material.get_shader_parameter("kind")>=1.5
		expect(roles_unchanged,"Food, poison and enemies retain their role colors")
		var native_id: int = view.pond.specimens[0].get_instance_id()
		await refresh()
		expect(view.pond.specimens[0].get_instance_id()==native_id,"Appearance does not regenerate every frame")
		game.visual_quality = 0
		await refresh()
		expect(view.pond.specimens.filter(func(s): return s.visible).size()==10 and view.pond.suspension.multimesh.visible_instance_count==80,"Reduced detail respects the generated population")
		game.visual_quality = 2
		await refresh()
		expect(view.pond.suspension.multimesh.visible_instance_count==view.appearance.dust_count,"Full detail restores only the available particles")
	# Changing membrane shapes must retain the held polygon and fused tissue.
	run.enemies.clear()
	var path: Array = [0,8,9]
	var center: Vector2 = (run.board.anchors[0]+run.board.anchors[8]+run.board.anchors[9])/3.0
	run.enemies.append(run.Harvest.Organism.new(700,"food",center,Vector2.ZERO,0.0))
	run.selection.start(run.board.anchors[0])
	for id in [8,9,0]:
		run.selection.visit(id)
	var held: PackedVector2Array = run.Geometry.polygon_for(path,run.board.anchors)
	run.step(1.2)
	expect(run.Geometry.polygon_for(path,run.board.anchors)==held,"Shaped blue cells hold their exact capture polygon while selected")
	var meal: Dictionary = run.release()
	expect(meal.valid and meal.food==1,"The visible held shape captures correctly with stronger drift")
	run.step(1.1)
	game.visual_time += 2.3
	await capture("mission-appearance-absorption")
	expect(game.microscope.pulses[0].get_meta("surface").material.get_shader_parameter("colony_grade")==game.microscope.appearance.colony_grade,"Fused absorption keeps the mission's colony appearance")
	# Appearance and native ambient positions must survive a save/resume.
	var look: Dictionary = game.microscope.appearance.duplicate(true)
	var resting: Vector2 = game.microscope.pond.specimens[0].get_meta("rest_position")
	var clone := Run.new(true,4,true,true)
	expect(Save.restore(clone,Save.capture(run)),"Journey with procedural appearance restores")
	expect(Appearance.make(clone.run_seed,clone.stage_index)==look,"Resume reconstructs the identical appearance without saving images")
	clone.dispose()
	run.state = Run.PAUSED
	var time: float = game.visual_time
	var pose: Transform2D = game.microscope.pond.specimens[0].transform
	game._process(3.0)
	expect(game.visual_time==time and game.microscope.pond.specimens[0].transform==pose,"Pause freezes the generated environment")
	game.reduced_motion = true
	await refresh()
	expect(game.microscope.pond.specimens[0].position==resting and game.microscope.field.material.get_shader_parameter("motion")==0.0,"Reduced motion preserves appearance while stopping ambient movement")
	game.reduced_motion = false
	# A legacy orbit snapshot keeps its saved positions as independent wandering
	# begins, including the first frame; no rotation back to the initial layout.
	var old := Run.new(true,73,true,true)
	old.begin_encounter()
	for i in 24:
		old.board.anchors[i] = old.board.center+(old.board.anchors[i]-old.board.center).rotated(0.9)
	old.board.motion_times.fill(37.0)
	var saved := Save.capture(old)
	saved.erase("wander")
	saved.motion_rate = 0.09
	saved.current_angle = 0.9
	clone = Run.new(true,83,true,true)
	expect(Save.restore(clone,saved) and clone.board.anchors==old.board.anchors,"An older orbit save restores exact positions without wandering metadata")
	var previous: PackedVector2Array = clone.board.anchors.duplicate()
	clone.board.step_motion(1.0/60.0)
	var continuous := true
	for i in 24:
		continuous = continuous and clone.board.anchors[i].distance_to(previous[i])<=15.0/60.0
	expect(continuous,"Cells in older saves begin independent wandering without teleporting")
	old.dispose()
	clone.dispose()
	game.queue_free()
	await process_frame
	print("MISSION APPEARANCE: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
