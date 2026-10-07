extends "res://tests/harvest_visual.gd"
## Native pixels catch shader/CPU clock drift that uniform-only checks miss.

func photo() -> Image:
	game._process(0.0)
	game.hovered = -1
	game.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()

func difference(a: Image, b: Image, region: Rect2i) -> float:
	var total := 0.0
	var count := 0
	for y in range(region.position.y,region.end.y,4):
		for x in range(region.position.x,region.end.x,4):
			var first := a.get_pixel(x,y)
			var second := b.get_pixel(x,y)
			total += absf(first.r-second.r)+absf(first.g-second.g)+absf(first.b-second.b)
			count += 1
	return total/maxi(count,1)

func isolated_tissue_pixels() -> void:
	# The surrounding membrane also moves; isolate each new GPU layer so that
	# a frozen shader cannot pass by borrowing motion from the parent sprite.
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	var background := ColorRect.new()
	background.size = Vector2(1280,900)
	background.color = Color(0.02,0.04,0.05)
	overlay.add_child(background)
	var details := preload("res://scripts/tissue_motion.gd").new()
	details.kind = 1
	details.phase = 0.73
	details.display_extent = 240.0
	details.position = Vector2(640,450)
	details.scale = Vector2.ONE*details.display_extent/details.texture_extent
	overlay.add_child(details)
	var region := Rect2i(490,300,300,300)
	details.cilia_cloud.hide()
	details.animate(0.0,1.0,1.0)
	var before := await photo()
	details.animate(2.0,1.0,1.0)
	var after := await photo()
	expect(difference(before,after,region)>0.00001,"Isolated GPU cytoplasm visibly circulates")
	details.granule_cloud.hide()
	details.cilia_cloud.show()
	details.lure = 1.0
	details.animate(0.0,1.0,1.0)
	before = await photo()
	details.animate(0.8,1.0,1.0)
	after = await photo()
	expect(difference(before,after,region)>0.00001,"Isolated GPU cilia visibly beat and bend")
	details.granule_cloud.show()
	details.animate(2.0,1.0,1.0)
	before = await photo()
	details.animate(2.0,1.0,1.0)
	expect(difference(before,await photo(),region)<0.000001,"GPU details remain identical at a frozen presentation clock")
	details.animate(2.0,0.0,1.0)
	before = await photo()
	details.animate(8.0,0.0,1.0)
	expect(difference(before,await photo(),region)<0.000001,"Reduced motion fixes both isolated GPU detail layers")
	details.modulate.a = 0.0
	var empty := await photo()
	details.modulate.a = 1.0
	details.self_modulate.a = 0.0
	details.animate(8.0,0.0,1.0)
	expect(difference(empty,await photo(),region)<0.000001,"Self tint and parent fading both hide the complete GPU tissue")
	overlay.queue_free()
	await process_frame

func exercise() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("MOTION PIXELS requires a native renderer")
		quit(1)
		return
	root.gui_disable_input = true
	root.size = Vector2i(1280,900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.render_loop_enabled = false
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	game.journey_path = "/tmp/microverse-motion-pixels-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-motion-pixels-profile.cfg"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.run.fixed_seed = 73
	game.run.restart()
	game.run.begin_encounter()
	game.run.enemies.clear()
	for id in ["fission","enzyme","lure"]:
		game.run.add_mutation(id)
	game.hud.visible = false
	var dish := Rect2i(248,58,784,784)
	var mother := Rect2i(575,385,130,130)
	var before := await photo()
	game._process(2.0)
	var alive := await photo()
	expect(difference(before,alive,mother)>0.001,"The evolved Mother's tissue, cilia, and buds visibly move")
	expect(difference(before,alive,dish)>0.001,"The complete dish visibly changes without advancing gameplay")
	game.run.state = Run.PAUSED
	game._process(3.0)
	var paused := await photo()
	expect(difference(alive,paused,dish)<0.0001,"Pause freezes actual foreground and background pixels")
	game.run.state = Run.ACTIVE
	game.reduced_motion = true
	var reduced := await photo()
	game._process(4.0)
	expect(difference(reduced,await photo(),dish)<0.0001,"Reduced motion freezes all decorative tissue and water pixels")
	game.reduced_motion = false
	var b = game.run.board
	game.run.selection.start(b.anchors[0])
	game.last_pointer = b.anchors[0]
	var gesture := InputEventMouseMotion.new()
	gesture.position = b.anchors[0].lerp(b.anchors[8],0.65)
	game._unhandled_input(gesture)
	await photo()
	var wake = game.microscope.water.sample(game.visual_time,false)
	expect(wake.strengths[0]>0.0,"Actual drawing emits a water wake")
	var wake_frame := root.get_texture().get_image()
	game.run.state = Run.PAUSED
	game._process(1.0)
	expect(difference(wake_frame,await photo(),dish)<0.0001,"Paused drawing freezes the particle wake")
	game.run.selection.cancel()
	game.run.state = Run.ACTIVE
	game._process(2.5)
	expect(game.microscope.water.wakes.is_empty(),"Drawing wakes expire without a persistent particle pool")
	var prey: Vector2 = (b.anchors[0]+b.anchors[8]+b.anchors[9])/3.0
	game.run.enemies.append(game.run.Harvest.Organism.new(900,"food",prey,Vector2.ZERO,0.0))
	game.run.selection.start(b.anchors[0])
	for id in [8,9,0]:
		game.run.selection.visit(id)
	game.commit_selection()
	game.run.step_recovery(0.8)
	var feeding := await photo()
	var impulses: PackedVector4Array = game.microscope.field.material.get_shader_parameter("impulses")
	expect(impulses.size()==4 and impulses[0].w>0.0,"A real meal disturbs nearby water within a fixed four-event budget")
	var pond = game.microscope.pond
	var curled: Array = pond.specimens.map(func(s): return s.position)
	var currents: PackedVector4Array = pond.currents
	var empty_currents := PackedVector4Array()
	empty_currents.resize(4)
	pond.set_flow(empty_currents,pond.strokes,pond.stroke_strengths)
	pond.sync(game.visual_time,1.0)
	var travel := 0.0
	for i in curled.size():
		travel = maxf(travel,curled[i].distance_to(pond.specimens[i].position))
	expect(travel>1.0 and travel<28.0,"Real absorption gently displaces background specimens")
	RenderingServer.force_draw(false)
	expect(difference(feeding,root.get_texture().get_image(),dish)>0.0000005,"The instanced debris and specimen current changes actual pixels")
	pond.set_flow(currents,pond.strokes,pond.stroke_strengths)
	pond.sync(game.visual_time,1.0)
	# Isolate the pressure front from all the existing background motion.
	var no_impulses := PackedVector4Array()
	no_impulses.resize(4)
	game.microscope.field.material.set_shader_parameter("impulses",no_impulses)
	RenderingServer.force_draw(false)
	var still_water := root.get_texture().get_image()
	expect(difference(feeding,still_water,dish)>0.000005,"The event actually refracts the water pixels")
	game.microscope.field.material.set_shader_parameter("impulses",impulses)
	game.run.state = Run.PAUSED
	game._process(4.0)
	expect(difference(feeding,await photo(),dish)<0.0001,"Pausing mid-meal freezes fluid pressure, erosion, and nutrient trails")
	game.reduced_motion = true
	await photo()
	expect(game.microscope.field.material.get_shader_parameter("impulses")==no_impulses,"Reduced motion removes event-driven water distortion")
	expect(pond.currents==empty_currents,"Reduced motion removes particle currents too")
	game.reduced_motion = false
	game.run.state = Run.ACTIVE
	game.run.step_recovery(10.0)
	game.run.enemies.clear()
	var hunter := Drifter.new(901,b.center+Vector2(110,0),5.4)
	game.run.enemies.append(hunter)
	var threatened := await photo()
	var warning: Dictionary = game.microscope.alert
	expect(warning.id==901 and warning.strength>0.5 and warning.direction.x>0.9,"A close hunter makes Mother brace toward the actual danger")
	var core_positions: Array = []
	for i in 5:
		core_positions.append(game.microscope.core_position(i))
	game.microscope.mother.material.set_shader_parameter("threat_strength",0.0)
	RenderingServer.force_draw(false)
	expect(difference(threatened,root.get_texture().get_image(),mother)>0.0003,"Mother's directional warning is visible at gameplay scale")
	for i in 5:
		expect(core_positions[i]==game.microscope.core_position(i),"Danger animation preserves damage-core registration %d" % i)
	await capture("water-and-mother-warning")
	game.run.enemies.clear()
	await photo()
	expect(game.microscope.alert.strength==0.0,"Removing the threat releases Mother's protective tension")
	await isolated_tissue_pixels()
	game.queue_free()
	await process_frame
	print("MOTION PIXELS: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
