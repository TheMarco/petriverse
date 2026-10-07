extends "res://tests/harvest_visual.gd"
const Labels = preload("res://scripts/dish_labels.gd")
const Guide = preload("res://scripts/journey_guidance.gd")

func _initialize() -> void:
	root.unfocusable = true
	super._initialize()

func clear_action() -> bool:
	for box in game.hud.marker_boxes:
		for obstacle in game.hud.dish_labels.obstacles:
			if box.intersects(obstacle): return false
	return true

func exercise() -> void:
	game = Main.new()
	game.audio_enabled = false
	game.save_records = false
	game.preferences_enabled = false
	game.pause_on_focus_loss = false
	root.gui_disable_input = true
	root.size = Vector2i(1280,900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	var run = game.run
	run.route_plan = run.JourneyRoute.make(73)
	run.route_position = 4
	run.stage_index = 2
	run.start_stage()
	run.begin_encounter()
	run.enemies.clear()
	run.phages.reset()
	run.harvest.next_bloom = 9999
	run.harvest.ecology.next_wave = 9999
	run.harvest.ecology.pending.clear()
	var body = run.harvest.ecology.add(run,"bacterium",0,Vector2(828,495))
	body.age = 4
	body.spawning = 0
	body.heading = Vector2(0.06,1).normalized()
	body.infection_age = 7.0
	body.stored_food = 2
	var group = run.phages.add(run,body.nucleus)
	group.host_id = body.id
	group.age = 4
	run.phages.learned = true
	game.last_discovery = run.discovery_serial
	game.toast_time = 0
	RenderingServer.render_loop_enabled = false
	await capture("dish-labels-phages")
	expect(clear_action(),"Vertical infected host, attached phages and blue cells remain unobscured")
	expect(not game.hud.marker_boxes.is_empty(),"Status remains visible when clear water is available")
	expect(game.hud.marker_boxes.all(func(box): return box.size.y<30),"Every field label is one compact line")
	var guide: Dictionary = Guide.next_action(run)
	expect(guide.title.contains("2s") and guide.detail.contains("food it releases"),"Infection countdown and full instructions remain in the side panel")
	game.large_text = true
	await capture("dish-labels-large")
	expect(clear_action(),"Larger text uses its real width and avoids the action")
	var key := "body:%d" % body.get_instance_id()
	var old: Vector2 = game.hud.dish_labels.placements.get(key,Vector2.INF)
	body.nucleus += Vector2(0.2,0.2)
	await refresh()
	RenderingServer.force_draw(false)
	expect(old!=Vector2.INF and game.hud.dish_labels.placements.get(key)==old,"Gentle drift keeps the same label position relative to its specimen")
	run.selection.start(run.board.anchors[0])
	await capture("dish-labels-drawing")
	expect(run.selection.active and game.hud.marker_boxes.is_empty(),"Starting a loop immediately clears all floating text")
	expect(not Guide.next_action(run).title.is_empty(),"Loop instructions stay available while labels are hidden")
	run.selection.cancel()
	group.host_id = -1
	group.nucleus = Vector2(828,415)
	expect(run.nudge.begin(run,group.nucleus),"Phage nudge can start in the fixture")
	await refresh()
	RenderingServer.force_draw(false)
	expect(game.hud.marker_boxes.is_empty(),"Nudging also clears floating labels")
	run.nudge.cancel()
	# A completely crowded dish must omit a label, never use an unsafe fallback.
	var layout = Labels.new()
	var filled: Array[Rect2] = [Labels.AREA]
	layout.begin(filled,false)
	expect(not layout.place("crowded",Rect2(700,400,80,80),Vector2(130,24)).has_area(),"No-space fallback preserves gameplay instead of drawing over it")
	var clear: Array[Rect2] = []
	layout.begin(clear,false)
	var first: Rect2 = layout.place("one",Rect2(700,400,80,80),Vector2(130,24))
	var second: Rect2 = layout.place("two",Rect2(700,400,80,80),Vector2(130,24))
	expect(first.has_area() and second.has_area() and not first.grow(8).intersects(second),"Labels also avoid each other")
	print("DISH LABELS: %d checks; %d failures" % [checks,failures.size()])
	game.queue_free()
	quit(0 if failures.is_empty() else 1)
