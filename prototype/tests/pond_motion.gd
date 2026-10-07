extends SceneTree
## Native pixels, not just clock uniforms: isolate the background and prove it
## visibly changes, then remains still on pause and in reduced-motion mode.
class PondScene:
	extends "res://scripts/main.gd"
	var background_only := true
	func _init() -> void:
		pause_on_focus_loss = false
	func _draw() -> void:
		if not background_only:
			super._draw()
var game: Node2D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("review")

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func photograph() -> Image:
	game._process(0.0)
	# Sync restores gameplay sprites' visibility; isolate after it, not before.
	for child in game.microscope.get_children():
		if child != game.microscope.field and child != game.microscope.pond:
			child.visible = false
	await process_frame
	await process_frame
	RenderingServer.force_draw(false, 0.0)
	return root.get_texture().get_image()

func comparison(a: Image, b: Image) -> Dictionary:
	var samples := 0
	var changed := 0
	var total := 0.0
	for y in range(150, 750, 4):
		for x in range(340, 940, 4):
			if Vector2(x, y).distance_to(Vector2(640, 450)) > 300.0:
				continue
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var difference := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			total += difference
			samples += 1
			if difference > 2.0 / 255.0:
				changed += 1
	return {"changed_fraction": float(changed) / samples, "mean_difference": total / samples}

func review() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("POND PIXELS: requires a native renderer")
		quit(1)
		return
	root.gui_disable_input = true
	root.size = Vector2i(1280, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.render_loop_enabled = false
	game = PondScene.new()
	game.save_records = false
	game.preferences_enabled = false
	game.audio_enabled = false
	game.journey_path = "/tmp/microverse-pond-motion-unused.cfg"
	game.journey_profile.path = "/tmp/microverse-pond-motion-profile.cfg"
	game.run.journey = false # This fixture exercises the isolated enclosure rules.
	game.run.harvest_mode = false
	game.run.full_run = false
	game.run.restart()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.hud.visible = false
	for child in game.microscope.get_children():
		if child != game.microscope.field and child != game.microscope.pond:
			child.visible = false
	var initial: Image = await photograph()
	initial.save_png("res://artifacts/pond-motion-before.png")
	var pond = game.microscope.pond
	var poses: Array = pond.specimens.map(func(s): return s.position)
	pond.visible = false
	var settled_before: Image = await photograph()
	pond.visible = true
	game._process(4.0)
	var moved: Image = await photograph()
	moved.save_png("res://artifacts/pond-motion-after.png")
	var motion := comparison(initial, moved)
	print("POND PIXELS: four-second background difference ", JSON.stringify(motion))
	pond.visible = false
	var settled_after: Image = await photograph()
	pond.visible = true
	var sediment := comparison(settled_before,settled_after)
	print("POND PIXELS: settled sediment difference ", JSON.stringify(sediment))
	expect(motion.mean_difference>sediment.mean_difference*1.75 and motion.changed_fraction>0.035,"Suspended life produces readily visible motion in the native background, beyond lighting drift")
	var movements: Array[Vector2] = []
	for i in pond.specimens.size():
		movements.append(pond.specimens[i].position-poses[i])
	var distances: Array = movements.map(func(v): return v.length())
	distances.sort()
	print("POND TRAVEL: four-second median ",distances[distances.size()/2]," px; range ",distances.front(),"–",distances.back()," px")
	var moving := movements.filter(func(v): return v.length()>6.0).size()
	var direction_changes := 0
	for i in range(1,movements.size()):
		if movements[i].normalized().dot(movements[0].normalized())<0.5:
			direction_changes += 1
	expect(moving>=pond.specimens.size()*0.7 and distances[distances.size()/2]>10.0 and direction_changes>=6,"Most background specimens move at least six screen pixels, with median travel over ten pixels in four seconds")
	var smooth_routes := true
	var distinct_depths := {}
	for sprite in pond.specimens:
		distinct_depths[snappedf(sprite.material.get_shader_parameter("depth"),0.1)] = true
		var swim: Vector4 = sprite.get_meta("swim")
		# Sample every frame across several route joins, including a long session.
		for start in [0.0,swim.x-swim.y,900.0]:
			var previous: Vector2 = pond.swimming_position(sprite,start)
			for frame in 120:
				var next: Vector2 = pond.swimming_position(sprite,start+(frame+1)/60.0)
				smooth_routes = smooth_routes and next.distance_to(previous)<0.65 and next.distance_to(pond.CENTER)<382.0
				previous = next
	expect(smooth_routes,"Independent routes remain continuous, slow and inside the dish across route joins and long sessions")
	expect(distinct_depths.size()>=4,"The live scene contains several distinct focal depths")
	var live_poses: Array = pond.specimens.map(func(s): return s.transform)
	pond.sync(70.0,1.0)
	pond.sync(game.visual_time,1.0)
	expect(pond.specimens.map(func(s): return s.transform)==live_poses,"Ambient poses reconstruct from the presentation clock without integration history")
	moved = await photograph()
	game.pause()
	game._process(3.0)
	var paused: Image = await photograph()
	expect(comparison(moved, paused).mean_difference < 0.0001, "Pause freezes actual background pixels")
	game.pause()
	game.reduced_motion = true
	var reduced: Image = await photograph()
	game._process(3.0)
	var reduced_later: Image = await photograph()
	expect(comparison(reduced, reduced_later).mean_difference < 0.0001, "Reduced motion keeps all background pixels still")
	game.reduced_motion = false
	game.restart()
	var restarted: Image = await photograph()
	expect(comparison(initial, restarted).mean_difference < 0.0001, "Restart restores the same background image and currents")
	game.queue_free()
	print("POND PIXELS: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
